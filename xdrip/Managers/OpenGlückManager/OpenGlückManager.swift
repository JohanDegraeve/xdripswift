import Foundation
import OG
import os

public class OpenGlückManager: NSObject, OpenGluckSyncClientDelegate {
    // MARK: - public properties

    // MARK: - private properties

    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper: KeyValueObserverTimeKeeper = .init()

    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryOpenGlückManager)

    /// reference to coredatamanager
    private var coreDataManager: CoreDataManager

    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor

    /// is OpenGlück fully initiazed or not, that includes checking if OpenGlück is available, created successfully bloodGlucoseType, user authorized - value will get changed
    private var openGlückInitialized = false

    /// reference to the OpenGlück client, should be used only if we're sure OpenGlück is supported on the device
    private var openGlückClient: OpenGluckClient?
    private var openGlückSyncClient: OpenGluckSyncClient?
    
    /// dismisses low notifications 30m after low record
    private let dismissLowAfter: TimeInterval = 30 * 60 // 30m
    private var lastLowRecordAt: Date? = nil

    // MARK: - intialization

    init(coreDataManager: CoreDataManager) {
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)

        // call super.init
        super.init()

        // listen for changes to userdefaults
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.openGlückEnabled.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.openGlückUploadEnabled.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.openGlückHostname.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.openGlückToken.rawValue, options: .new, context: nil)

        // call initializeOpenGlück, set openGlückInitialized according to result of initialization
        openGlückInitialized = initializeOpenGlück()

        // do first store
        storeBgReadings()
    }

    // MARK: - private functions

    /// checks if OpenGlück enabled, creates client
    /// - returns:
    ///     - result which indicates if initialize was successful or not
    ///
    /// the return value of the function does not depend on UserDefaults.standard.openGlückEnabled - this setting needs to be verified each time there's  an new reading to store
    private func initializeOpenGlück() -> Bool {
        openGlückClient = nil
        openGlückSyncClient = nil
        guard UserDefaults.standard.openGlückEnabled, let openGlückHostname =  UserDefaults.standard.openGlückHostname, let openGlückToken = UserDefaults.standard.openGlückToken else { return false }

        openGlückClient = OpenGluckClient(hostname: openGlückHostname, token: openGlückToken, target: "xdripswift")
        Task {
            let openGlückSyncClient = OpenGluckSyncClient()
            await openGlückSyncClient.setDelegate(self)
            self.openGlückSyncClient = openGlückSyncClient
        }

        // all checks ok , return true
        return true
    }
    
    public func getClient() -> OpenGluckClient? {
        openGlückClient
    }
    
    let intervalBetweenHistoricRecords: TimeInterval =  5 * 60 // 5m
    let historicScanTipoffInterval: TimeInterval = 20 * 60 // 20m
    private func splitRecordsByHistoricScan(_ readings: [BgReading]) -> ([BgReading], [BgReading]) {
        guard !readings.isEmpty else { return ([], []); }
        let historicScanTipoffDate = Date().addingTimeInterval(-historicScanTipoffInterval)
        print("historicScanTipoffDate=\(historicScanTipoffDate)")
        let readings = readings.sorted(by: { $0.timeStamp < $1.timeStamp })
        let earliest = readings.first!.timeStamp
        let latest = readings.last!.timeStamp
        let base = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: earliest)!
        var usedTimeStamps: Set<Date> = Set()
        var d = base
        var historics = [BgReading]()
        while d < latest {
            if let match = readings
                .filter({ $0.timeStamp <= historicScanTipoffDate })
                .filter({ $0.timeStamp > d }).first, match.timeStamp.timeIntervalSince(d) < intervalBetweenHistoricRecords, !usedTimeStamps.contains(match.timeStamp) {
                usedTimeStamps.insert(match.timeStamp)
                historics.append(match)
            }
            d = d.addingTimeInterval(intervalBetweenHistoricRecords)
        }
        let lastHistoricAt = historics.map { $0.timeStamp }.max() ?? historicScanTipoffDate
        let scans = readings.filter { $0.timeStamp > lastHistoricAt }
        return (historics, scans)
    }

    /// stores latest readings in OpenGlück, only if OG supported, authorized, enabled in settings
    public func storeBgReadings() {
        // OpenGlück setting must be on, and OG must be initialized successfully
        if !UserDefaults.standard.openGlückEnabled || !openGlückInitialized { return }

        guard let openGlückClient = openGlückClient else { return }

        // get readings to store, limit to 15 = maximum 1 week - just to avoid a huge array is being returned here, applying minimumTimeBetweenTwoReadingsInMinutes filter
        let bgReadingsToStore = bgReadingsAccessor.getLatestBgReadings(limit: 2016, fromDate: UserDefaults.standard.timeStampLatestOpenGlückBgReading, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).filter(minimumTimeBetweenTwoReadingsInMinutes: 1, lastConnectionStatusChangeTimeStamp: nil, timeStampLastProcessedBgReading: UserDefaults.standard.timeStampLatestOpenGlückBgReading)
        
        let loadLastRecordsSince = Date().addingTimeInterval(-86400)
        let bgRecentRecords = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: loadLastRecordsSince, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).filter(minimumTimeBetweenTwoReadingsInMinutes: 1, lastConnectionStatusChangeTimeStamp: nil, timeStampLastProcessedBgReading: loadLastRecordsSince)
        let (historics, scans) = splitRecordsByHistoricScan(bgRecentRecords)
        print("Historic", historics.map {  "\($0.timeStamp) \($0.calculatedValue)"}.joined(separator: "\n"))
        print("Scans", scans.map { "\($0.timeStamp) \($0.calculatedValue)"}.joined(separator: "\n"))
        // NOTE: when Libre smoothing is enabled, we kind of lose scan records and only have one available; if we don't want this
        // we should store scan readings and re-upload them later -- though not sure this is a feature we'd want

        // reupload at least 4 historic records + scans
        let uploadHistoricAfter = (UserDefaults.standard.timeStampLatestOpenGlückBgReading ?? Date().addingTimeInterval(-86400)).addingTimeInterval(-historicScanTipoffInterval)
        let glucoseRecordsToUpload: [OpenGluckGlucoseRecord] = (
            historics.map ({
                OpenGluckGlucoseRecord(timestamp: $0.timeStamp, mgDl: Int(round($0.calculatedValue)), recordType: "historic")
            }) + scans.map ({
                OpenGluckGlucoseRecord(timestamp: $0.timeStamp, mgDl: Int(round($0.calculatedValue)), recordType: "scan")
            })
        ).filter {
            $0.timestamp >= uploadHistoricAfter
        }
        let modelName = "xdripswift"
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "(unknown-ifv)"
        let instantGlucoseRecords = bgReadingsToStore.map { bgReading in
            OpenGluckInstantGlucoseRecord(timestamp: bgReading.timeStamp, mgDl: Int(round(bgReading.calculatedValue)), modelName: modelName, deviceId: deviceId)
        }
        Task {
            if UserDefaults.standard.openGlückUploadEnabled {
                if !glucoseRecordsToUpload.isEmpty {
                    // we don't need to specifically upload instant glucose records as this will update the latest scan record,
                    // and all records uploaded here also end up in the instant glucose records
                    do {
                        let timeStampLastReadingToUpload = glucoseRecordsToUpload.filter { $0.recordType == "historic" }.map { $0.timestamp }.max()!
                        let device = OpenGluckDevice(modelName: modelName, deviceId: deviceId)
                        _ = try await openGlückClient.upload(currentCgmProperties: CgmCurrentDeviceProperties(hasRealTime: true, realTimeInterval: 60), device: device, glucoseRecords: glucoseRecordsToUpload)
                        await MainActor.run {
                            let currentLatest = UserDefaults.standard.timeStampLatestOpenGlückBgReading
                            if currentLatest == nil || timeStampLastReadingToUpload > currentLatest! {
                                UserDefaults.standard.timeStampLatestOpenGlückBgReading = timeStampLastReadingToUpload
                            }
                        }
                    } catch {
                        trace("Could not upload to OpenGlück", log: self.log, category: ConstantsLog.categoryOpenGlückManager, type: .error, error.localizedDescription)
                    }
                }
            } else {
                if !bgReadingsToStore.isEmpty {
                    let timeStampLastReadingToUpload = instantGlucoseRecords.map { $0.timestamp }.max()!
                    do {
                        let result = try await openGlückClient.upload(instantGlucoseRecords: instantGlucoseRecords)
                        if result.success {
                            UserDefaults.standard.timeStampLatestOpenGlückBgReading = timeStampLastReadingToUpload
                        }
                    } catch {
                        return
                    }
                }
            }
        }
    }
    
    public func getClient() -> OpenGluckClient {
        return openGlückClient!
    }
    
    /// whether we should dismiss a low notification — typically this happens when a low has been recorded in the last 30 minutes
    public func shouldDismissLow(at: Date) async -> Bool {
        guard let openGlückSyncClient else { return false }

        if let lastLowRecordAt, at >= lastLowRecordAt && at <= lastLowRecordAt.addingTimeInterval(dismissLowAfter) {
            trace("shouldDismissLow => true (cache)", log: self.log, category: ConstantsLog.categoryOpenGlückManager, type: .info, "Low bg reading at \(at) should be dismissed because of a low at \(lastLowRecordAt)")
            return true
        }
        
        // get the latest low
        do {
            if let latest = try await openGlückSyncClient.getLastData(), let lows = latest.lowRecords {
                lastLowRecordAt = lows
                    .filter { !$0.deleted }
                    .filter {at >= $0.timestamp && at <= $0.timestamp.addingTimeInterval(dismissLowAfter) }
                    .sorted(by: { $0.timestamp > $1.timestamp })
                    .first?.timestamp
            }
            if let lastLowRecordAt, at >= lastLowRecordAt && at <= lastLowRecordAt.addingTimeInterval(dismissLowAfter) {
                trace("shouldDismissLow => true (sync)", log: self.log, category: ConstantsLog.categoryOpenGlückManager, type: .info, "Low bg reading at \(at) should be dismissed because of a low at \(lastLowRecordAt)")
                return true
            }
        } catch {
            // ignore errors
            trace("Caught error while syncing OpenGlück, ignoring", log: self.log, category: ConstantsLog.categoryOpenGlückManager, type: .error, error.localizedDescription)
        }
        
        return false
    }

    // MARK: - observe function

    /// when UserDefaults openGlückEnabled, openGlückUploadEnabled or openGlückToken changes, then reinitialize the property openGlückInitialized
    override public func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                case UserDefaults.Key.openGlückEnabled, UserDefaults.Key.openGlückUploadEnabled, UserDefaults.Key.openGlückHostname, UserDefaults.Key.openGlückToken:
                    openGlückInitialized = initializeOpenGlück()
                    storeBgReadings()

                default:
                    break
                }
            }
        }
    }
}
