import Foundation
import os
import Contacts

class ContactImageManager: NSObject {
    
    // MARK: - private properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager

    /// BgReadingsAccessor instance
    private let bgReadingsAccessor:BgReadingsAccessor

    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryContactImageManager)
    
    /// to work with contacts
    let contactStore = CNContactStore()
    
    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.contactImageContactId.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.displayTrendInContactImage.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.rangeIndicatorInContactImage.rawValue, options: .new, context: nil)
    }
    
    // MARK: - public functions
    
    /// process new readings
    public func processNewReading() {
        updateContact()
    }
    
    // MARK: - private functions
    
    /// used by observevalue for UserDefaults.Key
    private func evaluateUserDefaultsChange(keyPathEnum: UserDefaults.Key) {
        switch keyPathEnum {
        
        case UserDefaults.Key.contactImageContactId, UserDefaults.Key.displayTrendInContactImage, UserDefaults.Key.rangeIndicatorInContactImage:
            updateContact()

        default:
            break

        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else {return}
        
        if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
            
            evaluateUserDefaultsChange(keyPathEnum: keyPathEnum)
            
        }
        
    }
    
    
    private var queue = DispatchQueue(label: "PhoneContactUpdater")
    
    private let debouncer = Debouncer(delay: 3.0) // 3-second debounce
    
    private var workItem: DispatchWorkItem?
    
    private func updateContact() {
        debouncer.debounce {
            self.workItem?.cancel()
            self.workItem = nil
            
            if !UserDefaults.standard.enableContactImage {
                return
            }
            
            // check that access to contacts is authorized by the user
            guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
                trace("in updateContact, enableContactImage is enabled but access to contacts is not authorized, setting UserDefaults.standard.enableContactImage to false", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info)
                UserDefaults.standard.enableContactImage = false
                return
            }
            
            if UserDefaults.standard.contactImageContactId == nil {
                return
            }
            
            
            let keysToFetch = [CNContactImageDataKey] as [CNKeyDescriptor]
            
            let contact: CNContact
            do {
                contact = try self.contactStore.unifiedContact(withIdentifier: UserDefaults.standard.contactImageContactId!, keysToFetch: keysToFetch)
            } catch {
                trace("in updateContact, an error has been thrown while fetching the selected contact", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error)
                return
            }
            
            // get 2 last Readings, with a calculatedValue
            let lastReading = self.bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
            
            guard let mutableContact = contact.mutableCopy() as? CNMutableContact else { return }
            
            let rangeIndicator = UserDefaults.standard.rangeIndicatorInContactImage
            
            if lastReading.count > 0  {
                let reading = lastReading[0].unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).description
                let rangeDescription = lastReading[0].bgRangeDescription()
                let slopeArrow = UserDefaults.standard.displayTrendInContactImage ? lastReading[0].slopeArrow() : nil
                let valueIsUpToDate = abs(lastReading[0].timeStamp.timeIntervalSinceNow) < 5 * 60
                
                mutableContact.imageData = ContactImageView.getImage(
                    value: reading,
                    range: rangeDescription,
                    slopeArrow: slopeArrow,
                    valueIsUpToDate: valueIsUpToDate,
                    rangeIndicator: rangeIndicator
                ).pngData()
                
                // schedule an update in 5 min 15 seconds - if no new data is received until then, the empty value will get rendered into the contact (this update will be canceled if new data is received)
                self.workItem = DispatchWorkItem(block: {
                    trace("in updateContact, no updates received for more than 5 minutes", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error)
                    self.updateContact()
                })
                DispatchQueue.main.asyncAfter(deadline: .now() + 5 * 60 + 15, execute: self.workItem!)
                
            } else {
                mutableContact.imageData = ContactImageView.getImage(
                    value: nil,
                    range: nil,
                    slopeArrow: nil,
                    valueIsUpToDate: false,
                    rangeIndicator: rangeIndicator
                ).pngData()
            }
            
            let saveRequest = CNSaveRequest()
            saveRequest.update(mutableContact)
            do {
                try self.contactStore.execute(saveRequest)
            } catch let error as NSError {
                var details: String?
                if error.domain == CNErrorDomain {
                    switch error.code {
                    case CNError.authorizationDenied.rawValue:
                        details = "Authorization denied"
                    case CNError.communicationError.rawValue:
                        details = "Communication error"
                    case CNError.insertedRecordAlreadyExists.rawValue:
                        details = "Record already exists"
                    case CNError.dataAccessError.rawValue:
                        details = "Data access error"
                    default:
                        details = "Code \(error.code)"
                    }
                }
                trace("in updateContact, failed to update the contact - %{public}@: %{public}@", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, details ?? "no details", error.localizedDescription)

            } catch {
                trace("in updateContact, failed to update the contact: %{public}@", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, error.localizedDescription)
            }
        }
    }
    
}

class Debouncer {
    
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private let delay: TimeInterval
    private var lastExecutedAt: Date?
    
    init(delay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
        self.delay = delay
        self.queue = queue
    }
    
    func debounce(_ block: @escaping () -> Void) {
        workItem?.cancel()

        let workItem = DispatchWorkItem(block: {
            block()
            self.lastExecutedAt = .now
        })
        
        self.workItem = workItem

        let thisDelay: TimeInterval
        if lastExecutedAt == nil {
            thisDelay = 0
        } else {
            let sinceLast = Date.now.timeIntervalSince(lastExecutedAt!)
            if sinceLast > delay {
                thisDelay = 0
            } else {
                thisDelay = delay - sinceLast
            }
        }

        queue.asyncAfter(deadline: .now() + thisDelay, execute: workItem)
    }
}
