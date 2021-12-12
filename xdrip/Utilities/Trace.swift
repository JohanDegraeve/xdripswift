import Foundation
import os

/// application version
fileprivate var applicationVersion:String = {
    
    if let dictionary = Bundle.main.infoDictionary {

        if let version = dictionary["CFBundleShortVersionString"] as? String  {
            return version
        }
    }
    
    return "unknown"
    
}()

/// build number
fileprivate var buildNumber:String = {
    
    if let dictionary = Bundle.main.infoDictionary {
        
        if let buildnumber = dictionary["CFBundleVersion"] as? String  {
            return buildnumber
        }
        
    }
    
    return "unknown"
    
}()

/// log only used for debuglogging
fileprivate var log:OSLog = {
    let log:OSLog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.debuglogging)
    return log
}()

/// dateformatter for nslog
fileprivate let dateFormatNSLog: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = ConstantsLog.dateFormatNSLog
    
    return dateFormatter
}()

/// will only be used during development
func debuglogging(_ logtext:String) {
    os_log("%{public}@", log: log, type: .debug, logtext)
}

/// finds the path to where xdrip can save files
fileprivate func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

/// trace file currently in use, in case tracing needs to be stored on file
fileprivate var traceFileName:URL?

/// function to be used for logging, takes same parameters as os_log but in a next phase also NSLog can be added, or writing to disk to send later via e-mail ..
/// - message : the text, same format as in os_log with %{private} and %{public} to either keep variables private or public , for NSLog, only 3 String formatters are suppored "@" for String, "d" for Int, "f" for double.
/// - log : is the name of the category that will be used in OSLog
/// - category is the same as used for creating the log (see class ConstantsLog), it's repeated here to use in NSLog
/// - args : optional list of parameters that will be used. MAXIMUM 10 !
///
/// Example 
func trace(_ message: StaticString, log:OSLog, category: String, type: OSLogType, _ args: CVarArg...) {

    // initialize traceFileName if needed
    if traceFileName ==  nil {
        traceFileName = getDocumentsDirectory().appendingPathComponent(ConstantsTrace.traceFileName + ".0.log")
    }
    guard let traceFileName = traceFileName else {return}
    
    // if oslog is enabled in settings, then do os_log
    if UserDefaults.standard.OSLogEnabled {

        switch args.count {
            
        case 0:
            os_log(message, log: log, type: type)
        case 1:
            os_log(message, log: log, type: type, args[0])
        case 2:
            os_log(message, log: log, type: type, args[0], args[1])
        case 3:
            os_log(message, log: log, type: type, args[0], args[1], args[2])
        case 4:
            os_log(message, log: log, type: type, args[0], args[1], args[2], args[3])
        case 5:
            os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4])
        case 6:
            os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5])
        case 7:
            os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5], args[6])
        case 8:
            os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])
        case 9:
            os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
        case 10:
            os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])
        default:
            os_log(message, log: log, type: type)
            
        }

    }
    
    // calculate string to log, replacing arguments
    
    var argumentsCounter: Int = 0
    
    var actualMessage = message.description
   
    // try to find the publicMark as long as argumentsCounter is less than the number of arguments
    while argumentsCounter < args.count {
        
        // mark to replace
        let publicMark = "%{public}"
        
        // get array of indexes of location of publicMark
        let indexesOfPublicMark = actualMessage.indexes(of: "%{public}")
        
        if indexesOfPublicMark.count > 0 {
            
            // range starts from first character until just before the publicMark
            let startOfMessageRange = actualMessage.startIndex..<indexesOfPublicMark[0]
            // text as String, until just before the publicMark
            let startOfMessage = String(actualMessage[startOfMessageRange])
            
            // range starts from just after the publicMark till the end
            var endOfMessageRange = actualMessage.index(indexesOfPublicMark[0], offsetBy: publicMark.count)..<actualMessage.endIndex
            // text as String, from just after the publicMark till the end
            var endOfMessage = String(actualMessage[endOfMessageRange])
            
            // no start looking for String Format Specifiers
            // possible formatting see https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFStrings/formatSpecifiers.html#//apple_ref/doc/uid/TP40004265
            // not doing them all
            
            if endOfMessage.starts(with: "@") {
                let indexOfAt = endOfMessage.indexes(of: "@")
                endOfMessageRange = endOfMessage.index(after: indexOfAt[0])..<endOfMessage.endIndex
                endOfMessage = String(endOfMessage[endOfMessageRange])
                if let argValue = args[argumentsCounter] as? String {
                    endOfMessage = argValue + endOfMessage
                }
            } else if endOfMessage.starts(with: "d") || endOfMessage.starts(with: "D") {
                let indexOfAt = endOfMessage.indexes(of: "d", options: [NSString.CompareOptions.caseInsensitive])
                endOfMessageRange = endOfMessage.index(after: indexOfAt[0])..<endOfMessage.endIndex
                endOfMessage = String(endOfMessage[endOfMessageRange])
                if let argValue = args[argumentsCounter] as? Int {
                    endOfMessage = argValue.description + endOfMessage
                }
            } else if endOfMessage.starts(with: "f") || endOfMessage.starts(with: "F") {
                let indexOfAt = endOfMessage.indexes(of: "f", options: [NSString.CompareOptions.caseInsensitive])
                endOfMessageRange = endOfMessage.index(after: indexOfAt[0])..<endOfMessage.endIndex
                endOfMessage = String(endOfMessage[endOfMessageRange])
                if let argValue = args[argumentsCounter] as? Double {
                    endOfMessage = argValue.description + endOfMessage
                }
            }
            
            actualMessage = startOfMessage + endOfMessage
            
        } else {
            // there's no more occurrences of the publicMark, no need to continue
            break
        }
        
        argumentsCounter += 1
        
    }
    
    // create timeStamp to use in NSLog and tracefile
    let timeStamp = dateFormatNSLog.string(from: Date())
    
    // nslog if enabled and if type = debug, then check also if debug logging is required
    if UserDefaults.standard.NSLogEnabled && (type != .debug || (type == .debug && UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog)) {
        
        NSLog("%@", ConstantsLog.tracePrefix + " " + timeStamp + " " + applicationVersion + " " + buildNumber + " " + category + " " + Date().toString(timeStyle: .medium, dateStyle: .none) + " " + actualMessage)
        
    }
    
    // write trace to file, only if type is not .debug or type is .debug and addDebugLevelLogsInTraceFileAndNSLog is true
    if type != .debug || (type == .debug && UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog) {
       
        do {
            
            let textToWrite = timeStamp + " " + applicationVersion + " " + buildNumber + " " + category + " " + actualMessage + "\n"
            
            if let fileHandle = FileHandle(forWritingAtPath: traceFileName.path) {
                
                // file already exists, go to end of file and append text
                fileHandle.seekToEndOfFile()
                fileHandle.write(textToWrite.data(using: .utf8)!)
                
            } else {
                
                // file doesn't exist yet
                try textToWrite.write(to: traceFileName, atomically: true, encoding: String.Encoding.utf8)
                
            }
            
        } catch {
            NSLog("%@", ConstantsLog.tracePrefix + " " + dateFormatNSLog.string(from: Date()) + " write trace to file failed")
        }
        
    }
   
    
    // check if tracefile has reached limit size and if yes rotate the files
    if traceFileName.fileSize > ConstantsTrace.maximumFileSizeInMB * 1024 * 1024 {
        
        rotateTraceFiles()
        
    }
    
}

fileprivate func rotateTraceFiles() {

    // assign fileManager
    let fileManager = FileManager.default
    
    // first check if last trace file exists
    let lastFile = getDocumentsDirectory().appendingPathComponent(ConstantsTrace.traceFileName + "." + (ConstantsTrace.maximumAmountOfTraceFiles - 1).description + ".log")
    if FileHandle(forWritingAtPath: lastFile.path) != nil {
        
        do {
            try fileManager.removeItem(at: lastFile)
        } catch {
            debuglogging("failed to delete file " + lastFile.absoluteString)
        }
        
    }
    
    // now rename trace files if they exist,
    for indexFrom0ToMax in 0...(ConstantsTrace.maximumAmountOfTraceFiles - 2) {
        
        let index = (ConstantsTrace.maximumAmountOfTraceFiles - 2) - indexFrom0ToMax
        
        let file = getDocumentsDirectory().appendingPathComponent(ConstantsTrace.traceFileName + "." + index.description + ".log")
        let newFile = getDocumentsDirectory().appendingPathComponent(ConstantsTrace.traceFileName + "." + (index + 1).description + ".log")
        
        if FileHandle(forWritingAtPath: file.path) != nil {

            do {
                try fileManager.moveItem(at: file, to: newFile)
            } catch {
                debuglogging("failed to rename file " + lastFile.absoluteString)
            }
            
        }
    }
    
    // now set tracefilename to nil, it will be reassigned to correct name, ie the one with index 0, at next usage
    traceFileName = nil
    
}

class Trace {
    
    // MARK: - private properties
    
    /// CoreDataManager to use
    private static var coreDataManager:CoreDataManager?
    
    /// BluetoothPeripheralManager to use
    private static var bluetoothPeripheralManager: BluetoothPeripheralManager?
    
    private static let paragraphSeperator = "\n\n===================================================\n\n"
    
    // MARK: - initializer
    
    static func initialize(coreDataManager: CoreDataManager?) {
        
        self.coreDataManager = coreDataManager
        
    }
    
    // MARK: - public static functions
    
    /// creates file on disk with app info, and returns the file as Data and the filename
    static func getAppInfoFileAsData() -> (Data?, String) {
        
        var traceInfo = ""

        // app version and build
        traceInfo.appendStringAndNewLine("Version " + applicationVersion)
        traceInfo.appendStringAndNewLine("Build number " + buildNumber)
        
        // Info from UserDefaults
        
        // timestamp app launch
        // unwrap timeStampAppLaunch
        if let timeStampAppLaunch = UserDefaults.standard.timeStampAppLaunch {
            traceInfo.appendStringAndNewLine("App launched at " + timeStampAppLaunch.toString(timeStyle: .short, dateStyle: .short) + " local time.")
        }

        // cgm transmitter type from UserDefaults
        if let cgmTransmitterTypeAsString = UserDefaults.standard.cgmTransmitterTypeAsString {
            traceInfo.appendStringAndNewLine("Transmitter type = " + cgmTransmitterTypeAsString + "\n")
            traceInfo.appendStringAndNewLine(paragraphSeperator)
        }
        
        // is showReadingInNotification on or off
        traceInfo.appendStringAndNewLine("bgReading in notification is on = " + UserDefaults.standard.showReadingInNotification.description + "\n")
        
        // Info from coredata
        
        if let coreDataManager = coreDataManager {

            // accessors
            let bLEPeripheralAccessor = BLEPeripheralAccessor(coreDataManager: coreDataManager)
            let alertEntriesAccessor = AlertEntriesAccessor(coreDataManager: coreDataManager)
            let alertTypesAccessor = AlertTypesAccessor(coreDataManager: coreDataManager)

            // all bluetooth transmitters
            traceInfo.appendStringAndNewLine("List of bluetooth peripherals:\n")
            
            for blePeripheral in bLEPeripheralAccessor.getBLEPeripherals() {
                traceInfo.appendStringAndNewLine("    Name : " + blePeripheral.name)
                traceInfo.appendStringAndNewLine("    Address : " + blePeripheral.address)
                if let alias = blePeripheral.alias {
                    traceInfo.appendStringAndNewLine("    Alias : " + alias)
                }
                traceInfo.appendStringAndNewLine("    xDrip will " + (blePeripheral.shouldconnect ? "try ":"not try") + " to connect to this peripheral")
                
                if let libreSensorType = blePeripheral.libreSensorType {
                    traceInfo.appendStringAndNewLine("last known libreSensorType = " + libreSensorType.description)
                }

                for bluetoothPeripheralType in BluetoothPeripheralType.allCases {
                    
                    switch bluetoothPeripheralType {
                        
                    case .M5StackType:
                        if let m5Stack = blePeripheral.m5Stack, !m5Stack.isM5StickC {

                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            traceInfo.appendStringAndNewLine("    battery level = " + m5Stack.batteryLevel.description)
                            
                            // if needed additional specific info can be added
      
                        }
                        
                    case .M5StickCType:
                        if let m5Stack = blePeripheral.m5Stack, m5Stack.isM5StickC {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            traceInfo.appendStringAndNewLine("    battery level = " + m5Stack.batteryLevel.description)
                            
                        }
                        
                    case .DexcomG4Type:
                        if let dexcomG4 = blePeripheral.dexcomG4 {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            
                            // if needed additional specific info can be added
                            traceInfo.appendStringAndNewLine("    batterylevel : " + dexcomG4.batteryLevel.description)
                            
                        }
                        
                    case .DexcomType:
                        if let dexcomG5 = blePeripheral.dexcomG5 {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            
                            // if needed additional specific info can be added
                            traceInfo.appendStringAndNewLine("    voltageA : " + dexcomG5.voltageA.description)
                            traceInfo.appendStringAndNewLine("    voltageB : " + dexcomG5.voltageB.description)
                            
                        }
                        
                    case .BluconType:
                        if let blucon = blePeripheral.blucon {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            
                            // if needed additional specific info can be added
                            traceInfo.appendStringAndNewLine("    batteryLevel : " + blucon.batteryLevel.description)
                            
                        }
                        
                    case .BlueReaderType:
                        if blePeripheral.blueReader != nil {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            
                        }
                        
                    case .BubbleType:
                        if let bubble = blePeripheral.bubble {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            traceInfo.appendStringAndNewLine("    batteryLevel : " + bubble.batteryLevel.description)
                            
                        }
                        
                    case .DropletType:
                        if let droplet = blePeripheral.droplet {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            traceInfo.appendStringAndNewLine("    batteryLevel : " + droplet.batteryLevel.description)
                            
                        }

                    case .GNSentryType:
                        if let gNSEntry = blePeripheral.gNSEntry {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            traceInfo.appendStringAndNewLine("    batteryLevel : " + gNSEntry.batteryLevel.description)
                            
                        }

                    case .MiaoMiaoType:
                        if let miaoMiao = blePeripheral.miaoMiao {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            traceInfo.appendStringAndNewLine("    batteryLevel : " + miaoMiao.batteryLevel.description)
                            
                        }
                        
                    case .AtomType:
                        if let miaoMiao = blePeripheral.atom {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            traceInfo.appendStringAndNewLine("    batteryLevel : " + miaoMiao.batteryLevel.description)
                            
                        }
                        
                    case .WatlaaType:
                        if let watlaa = blePeripheral.watlaa {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            traceInfo.appendStringAndNewLine("    batteryLevel : " + watlaa.watlaaBatteryLevel.description)
                            
                        }
                        
                    case .Libre2Type:
                        if let libre2 = blePeripheral.libre2 {
                            
                            traceInfo.appendStringAndNewLine("    type = " + bluetoothPeripheralType.rawValue)
                            
                        }
                        
                    }
                }
                
                traceInfo.appendStringAndNewLine("")
                
            }
            
            // all alertentries
            traceInfo.appendStringAndNewLine("List of alerts:\n")
            
            for alertKind in AlertKind.allCases {
                
                traceInfo.appendStringAndNewLine("    alert kind : " + alertKind.descriptionForLogging())
                
                let alertEntries = alertEntriesAccessor.getAllEntries(forAlertKind: alertKind, alertTypesAccessor: alertTypesAccessor)
                
                for alertEntry in alertEntries {
                    traceInfo.appendStringAndNewLine("        start " + alertEntry.start.convertMinutesToTimeAsString() + " - value " + alertEntry.value.description + " - alert type : " + alertEntry.alertType.description)
                    
                }
                
                traceInfo.appendStringAndNewLine("")
                
            }
        
            // all alert types
            traceInfo.appendStringAndNewLine("List of alert types:\n")
            
            for alertType in alertTypesAccessor.getAllAlertTypes() {
                
                traceInfo.appendStringAndNewLine("    alert type : " + alertType.description)
                traceInfo.appendStringAndNewLine("        name : " + alertType.name)
                traceInfo.appendStringAndNewLine("        enabled : " + alertType.enabled.description)
                traceInfo.appendStringAndNewLine("        overridemute : " + alertType.overridemute.description)
                traceInfo.appendStringAndNewLine("        snooze via notification : " + alertType.snooze.description)
                traceInfo.appendStringAndNewLine("        default snooze period : " + alertType.snoozeperiod.description)
                if let soundname = alertType.soundname {
                    traceInfo.appendStringAndNewLine("        sound : " + soundname)
                } else {
                    traceInfo.appendStringAndNewLine("        sound : " + "default iOS sound")
                }
                

                traceInfo.appendStringAndNewLine("")
                
            }
        }
        
        return (traceInfo.data(using: .utf8), ConstantsTrace.appInfoFileName)
        
    }
    
    /// returns tuple, first type is an array of Data, each element is a tracefile converted to Data, second type is String, each element is the name of the tracefile
    static func getTraceFilesInData() -> ([Data], [String]) {
        
        var traceFilesInData = [Data]()
        var traceFileNames = [String]()
        
        for index in 0..<ConstantsTrace.maximumAmountOfTraceFiles {
            
            let filename = ConstantsTrace.traceFileName + "." + index.description + ".log"
            
            let file = getDocumentsDirectory().appendingPathComponent(filename)
            
            if FileHandle(forWritingAtPath: file.path) != nil {

                do {
                    // create traceFile info as data
                    let fileData = try Data(contentsOf: file)
                    traceFilesInData.append(fileData)
                    traceFileNames.append(filename)
                } catch {
                    debuglogging("failed to create data from  " + filename)
                }
                
            }
        }
        
        return (traceFilesInData, traceFileNames)
        
    }
    
}
