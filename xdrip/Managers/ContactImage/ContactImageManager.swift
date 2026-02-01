import Foundation
import os
import Contacts

class ContactImageManager: NSObject {
    // Store the identifier key for UserDefaults
    private let contactIdentifierKey = "ContactImageManager.contactIdentifier"
    
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
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.displayTrendInContactImage.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.useHighContrastContactImage.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue, options: .new, context: nil)
    }
    
    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.enableContactImage.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.displayTrendInContactImage.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.useHighContrastContactImage.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue)
        workItem?.cancel()
    }
    
    // MARK: - public functions
    
    /// process new readings
    public func processNewReading() {
        updateContact()
    }
    
    // MARK: - overriden functions
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
            evaluateUserDefaultsChange(keyPathEnum: keyPathEnum)
        }
    }
    
    // MARK: - private functions
    
    /// used by observevalue for UserDefaults.Key
    private func evaluateUserDefaultsChange(keyPathEnum: UserDefaults.Key) {
        updateContact()
    }
    
    /// this function will perform the following actions:
    /// - first check that it should do something and the user has given access/authorization to the app to work with the device contacts
    /// - create an image view based upon the recent glucose value(s)
    /// - check if a valid contact (with the same name as the app) exists. If so, update it with a png image of the image view
    /// - if a valid contact doesn't yet exist, create one with the app name and add a png image of the image view
    /// - schedule a 5-6 minute timer to repeat the above (just in case the function isn't updated again by the root view controller)
    private func updateContact() {
        guard UserDefaults.standard.enableContactImage else { return }
        // make sure we're in master mode OR in (follower mode WITHOUT keep-alive disabled)
        guard UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType != .disabled) else { return }
        
        debouncer.debounce {
            self.workItem?.cancel()
            self.workItem = nil
            
            let status = CNContactStore.authorizationStatus(for: .contacts)
            if status == .notDetermined {
                self.contactStore.requestAccess(for: .contacts) { granted, error in
                    DispatchQueue.main.async {
                        if granted {
                            self.updateContact() // try again now that we have permission
                        } else {
                            trace("in updateContact, user denied contacts access (requestAccess)", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error)
                            if UserDefaults.standard.enableContactImage {
                                UserDefaults.standard.enableContactImage = false
                            }
                        }
                    }
                }
                return
            }
            
            guard status == .authorized else {
                // if it isn't, and the user has enabled the feature, then disable it
                if UserDefaults.standard.enableContactImage {
                    trace("in updateContact, access to contacts is not authorized so setting enableContactImage to false", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info)
                    UserDefaults.standard.enableContactImage = false
                }
                return
            }
            
            // create a contact image view
            // get 2 last Readings, with a calculatedValue
            let lastReading = self.bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
            var contactImageView: ContactImageView
            
            // disable the image (show "OFF") if the function is disabled or if the user is in follower mode with background keep-alive disabled
            // as otherwise it would always be out of date
            let disableContactImage: Bool = !UserDefaults.standard.enableContactImage || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled)
            
            if lastReading.count > 0  {
                let valueIsUpToDate = abs(lastReading[0].timeStamp.timeIntervalSinceNow) < 7 * 60
                
                contactImageView = ContactImageView(bgValue: lastReading[0].calculatedValue, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, slopeArrow: UserDefaults.standard.displayTrendInContactImage ? lastReading[0].slopeArrow() : "", bgRangeDescription: lastReading[0].bgRangeDescription(), valueIsUpToDate: valueIsUpToDate, useHighContrastContactImage: UserDefaults.standard.useHighContrastContactImage, disableContactImage:  disableContactImage)
                
                // schedule an update in 5 min 15 seconds - if no new data is received until then, the empty value will get rendered into the contact (this update will be canceled if new data is received)
                self.workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    trace("in updateContact, no updates received for more than 5 minutes", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error)
                    self.updateContact()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (5 * 60) + 15, execute: self.workItem!)
            } else {
                // create an 'empty' image view if there is no BG data to show
                contactImageView = ContactImageView(bgValue: 0, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, slopeArrow: "", bgRangeDescription: .inRange, valueIsUpToDate: false, useHighContrastContactImage: false, disableContactImage:  disableContactImage)
            }
            
            // we're going to use the app name as the given name of the contact we want to use/create/update
            let keyToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey, CNContactImageDataKey] as [CNKeyDescriptor]
            let updatedString = (UserDefaults.standard.isMaster ? UserDefaults.standard.activeSensorDescription ?? "Updated" : UserDefaults.standard.followerDataSourceType.fullDescription) + ": \(Date().formatted(date: .omitted, time: .shortened))"

            // 1) Try identifier match first
            let storedIdentifier = UserDefaults.standard.string(forKey: self.contactIdentifierKey)

            if let storedIdentifier = storedIdentifier, !storedIdentifier.isEmpty {
                let identifierPredicate = CNContact.predicateForContacts(withIdentifiers: [storedIdentifier])
                let identifierMatches = (try? self.contactStore.unifiedContacts(matching: identifierPredicate, keysToFetch: keyToFetch)) ?? []

                if let identifierMatchedContact = identifierMatches.first {
                    if identifierMatchedContact.givenName != ConstantsHomeView.applicationName {
                        trace("in updateContact, stored identifier matched a contact but givenName '%{public}@' did not match '%{public}@'. Updating anyway to preserve contact complication sync.", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, identifierMatchedContact.givenName, ConstantsHomeView.applicationName)
                    }

                    if lastReading.count > 0 {
                        trace("in updateContact, contact found using stored identifier. Updating the contact image to %{public}@%{public}@", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info, lastReading[0].calculatedValue.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl), UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
                    } else {
                        trace("in updateContact, contact found using stored identifier. Updating the contact image (no BG data)", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info)
                    }

                    let saveRequest = CNSaveRequest()
                    guard let mutableContact = identifierMatchedContact.mutableCopy() as? CNMutableContact else { return }
                    mutableContact.imageData = contactImageView.getImage().pngData()
                    mutableContact.organizationName = updatedString
                    saveRequest.update(mutableContact)
                    self.executeSaveRequest(saveRequest: saveRequest)

                    // Re-store identifier to keep the fast path stable
                    UserDefaults.standard.set(identifierMatchedContact.identifier, forKey: self.contactIdentifierKey)

                    return
                } else {
                    trace("in updateContact, no contact found for stored identifier '%{public}@'. Falling back to name search.", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, storedIdentifier)
                }
            } else {
                trace("in updateContact, no stored contact identifier (or empty). Falling back to name search.", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info)
            }

            // 2) Fallback: match by application name
            let namePredicate = CNContact.predicateForContacts(matchingName: ConstantsHomeView.applicationName)
            let nameMatches = (try? self.contactStore.unifiedContacts(matching: namePredicate, keysToFetch: keyToFetch)) ?? []

            if let nameMatchedContact = nameMatches.first {
                if nameMatches.count > 1 {
                    trace("in updateContact, found %{public}d contacts matching '%{public}@'. Updating the first and leaving duplicates untouched.", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, nameMatches.count, ConstantsHomeView.applicationName)
                } else {
                    trace("in updateContact, '%{public}@' contact found using application name. Updating.", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info, ConstantsHomeView.applicationName)
                }

                let saveRequest = CNSaveRequest()

                guard let mutableContact = nameMatchedContact.mutableCopy() as? CNMutableContact else { return }
                mutableContact.imageData = contactImageView.getImage().pngData()
                mutableContact.organizationName = updatedString
                saveRequest.update(mutableContact)

                self.executeSaveRequest(saveRequest: saveRequest)

                // Store identifier for future updates (this is a real identifier from an existing unified contact)
                UserDefaults.standard.set(nameMatchedContact.identifier, forKey: self.contactIdentifierKey)

                return
            }

            // 3) No match by identifier or name: create a new contact
            if lastReading.count > 0 {
                trace("in updateContact, no existing contact found. Creating a new contact called '%{public}@' and adding a contact image with %{public}@ %{public}@", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info, ConstantsHomeView.applicationName, lastReading[0].calculatedValue.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl), UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
            } else {
                trace("in updateContact, no existing contact found. Creating a new contact called '%{public}@' with empty contact image (no BG data)", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .info, ConstantsHomeView.applicationName)
            }

            let contactToCreate = CNMutableContact()
            contactToCreate.givenName = ConstantsHomeView.applicationName
            contactToCreate.imageData = contactImageView.getImage().pngData()
            contactToCreate.organizationName = updatedString

            let saveRequest = CNSaveRequest()
            saveRequest.add(contactToCreate, toContainerWithIdentifier: nil)
            self.executeSaveRequest(saveRequest: saveRequest)

            // After creating, fetch by name once and store the resulting identifier (avoid storing empty identifier before save)
            let postCreateMatches = (try? self.contactStore.unifiedContacts(matching: namePredicate, keysToFetch: keyToFetch)) ?? []
            if let postCreateContact = postCreateMatches.first {
                UserDefaults.standard.set(postCreateContact.identifier, forKey: self.contactIdentifierKey)

                if postCreateMatches.count > 1 {
                    // If duplicates exist even after create, clean them up on the next cycle
                    trace("in updateContact, after creating contact found %{public}d matches for '%{public}@'. Duplicates may exist.", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, postCreateMatches.count, ConstantsHomeView.applicationName)
                }
            } else {
                trace("in updateContact, after creating contact could not re-fetch '%{public}@' by name to store identifier.", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, ConstantsHomeView.applicationName)
            }
        }
    }
    
    
    private func executeSaveRequest(saveRequest: CNSaveRequest) {
        // now execute the saveRequest - to delete the existing contact
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
            trace("in executeSaveRequest, failed to update/add/delete the contact - %{public}@: %{public}@", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, details ?? "no details", error.localizedDescription)
        } catch {
            trace("in executeSaveRequest, failed to update/add/delete the contact: %{public}@", log: self.log, category: ConstantsLog.categoryContactImageManager, type: .error, error.localizedDescription)
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
