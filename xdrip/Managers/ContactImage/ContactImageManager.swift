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
    
    private var queue = DispatchQueue(label: "PhoneContactUpdater")
    
    private let debouncer = Debouncer(delay: 3.0) // 3-second debounce
    
    private var workItem: DispatchWorkItem?
    
    /// to work with contacts
    let contactStore = CNContactStore()
    
    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        super.init()
        
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.enableContactImage.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.contactImageContactId.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.displayTrendInContactImage.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)
    }
    
    // MARK: - public functions
    
    /// process new readings
    public func processNewReading() {
        updateContact()
    }
    
    // MARK: - overriden functions
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else {return}
        
        if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
            evaluateUserDefaultsChange(keyPathEnum: keyPathEnum)
        }
        
    }
    
    // MARK: - private functions
    
    /// used by observevalue for UserDefaults.Key
    private func evaluateUserDefaultsChange(keyPathEnum: UserDefaults.Key) {
        switch keyPathEnum {
        
        case UserDefaults.Key.enableContactImage, UserDefaults.Key.contactImageContactId, UserDefaults.Key.displayTrendInContactImage, UserDefaults.Key.bloodGlucoseUnitIsMgDl:
            updateContact()

        default:
            break

        }
    }
    
    private func updateContact() {
        debouncer.debounce {
            self.workItem?.cancel()
            self.workItem = nil
            
            guard UserDefaults.standard.enableContactImage else { return }
            
            // check that access to contacts is authorized by the user
            guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
                trace("in updateContact, access to contacts is not authorized, setting enableContactImage to false", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info)
                
                UserDefaults.standard.enableContactImage = false
                return
            }
            
            // if the user hasn't selected a contact to use, then there's nothing to do yet
            guard (UserDefaults.standard.contactImageContactId != nil) else { return }
            
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
            
            let valueIsUpToDate = abs(lastReading[0].timeStamp.timeIntervalSinceNow) < 7 * 60
            
            if lastReading.count > 0  {
                let contactImageView = ContactImageView(bgValue: lastReading[0].calculatedValue, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, slopeArrow: UserDefaults.standard.displayTrendInContactImage ? lastReading[0].slopeArrow() : "", bgRangeDescription: lastReading[0].bgRangeDescription(), valueIsUpToDate: valueIsUpToDate)
                
                mutableContact.imageData = contactImageView.getImage().pngData()
                
                // schedule an update in 5 min 15 seconds - if no new data is received until then, the empty value will get rendered into the contact (this update will be canceled if new data is received)
                self.workItem = DispatchWorkItem(block: {
                    trace("in updateContact, no updates received for more than 5 minutes", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error)
                    self.updateContact()
                })
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (5 * 60) + 15, execute: self.workItem!)
                
            } else {
                let contactImageView = ContactImageView(bgValue: 0, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, slopeArrow: "", bgRangeDescription: .inRange, valueIsUpToDate: valueIsUpToDate)
                
                mutableContact.imageData = contactImageView.getImage().pngData()
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

extension ContactImageManager {
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
    
}
