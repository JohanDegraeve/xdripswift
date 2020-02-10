import CoreData
import UIKit
import os

/// development as explained in cocoacasts.com https://cocoacasts.com/bring-your-own
public final class CoreDataManager {
    
    // MARK: - Type Aliases
    
    public typealias CoreDataManagerCompletion = () -> ()
    
    // MARK: - Properties
    
    private let modelName: String
    
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCoreDataManager)
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillTerminate
    private let applicationManagerKeySaveChanges = "coredatamanagersavechanges"

    // MARK: -
    
    private let completion: CoreDataManagerCompletion
    
    // MARK: -
    
    private(set) lazy var mainManagedObjectContext: NSManagedObjectContext = {
        // Initialize Managed Object Context
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        // Configure Managed Object Context
        managedObjectContext.parent = self.privateManagedObjectContext
        
        return managedObjectContext
    }()
    
    private lazy var privateManagedObjectContext: NSManagedObjectContext = {
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        
        return managedObjectContext
    }()
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        // Fetch Model URL
        guard let modelURL = Bundle.main.url(forResource: self.modelName, withExtension: "momd") else {
            fatalError("Unable to Find Data Model")
        }
        
        // Initialize Managed Object Model
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to Load Data Model")
        }
        
        return managedObjectModel
    }()
    
    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        return NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
    }()
    
    private func addPersistentStore(to persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        // Helpers
        let fileManager = FileManager.default
        let storeName = "\(self.modelName).sqlite"
        
        // URL Documents Directory
        //let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Shared App Groups URL
        let sharedAppGroupsURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: ConstantsAppGroups.AppGroupIdentifier)
        
        // URL Persistent Store
        let persistentStoreURL = sharedAppGroupsURL!.appendingPathComponent(storeName)
         //print("persistentStoreURL: \(persistentStoreURL)")
        
        do {
            let options = [
                NSMigratePersistentStoresAutomaticallyOption : true,
                NSInferMappingModelAutomaticallyOption : true
            ]
            
            // Add Persistent Store
            try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                              configurationName: nil,
                                                              at: persistentStoreURL,
                                                              options: options)
            
        } catch {
            fatalError("Unable to Add Persistent Store")
        }
    }
    
    // MARK: - Initialization
    
    init(modelName: String, completion: @escaping CoreDataManagerCompletion) {
        // Set Properties
        self.modelName = modelName
        self.completion = completion
        
        // Setup Core Data Stack
        setupCoreDataStack()
    }
    
    // MARK: - Helper Methods
    
    private func setupCoreDataStack() {
        // Fetch Persistent Store Coordinator
        guard let persistentStoreCoordinator = mainManagedObjectContext.persistentStoreCoordinator else {
            fatalError("Unable to Set Up Core Data Stack")
        }
        
        // Shared CoreData with App Groups
        NotificationCenter.default.addObserver(self, selector: #selector(sendUpdatesFromContextSaved(saveNotification:)), name: .NSManagedObjectContextDidSave, object: mainManagedObjectContext)

        DispatchQueue.global().async {
            // Add Persistent Store
            self.addPersistentStore(to: persistentStoreCoordinator)
            
            // Invoke Completion On Main Queue
            DispatchQueue.main.async { self.completion() }
        }
        
        // when app terminates, call saveChanges, just in case that somewhere in the code
        ApplicationManager.shared.addClosureToRunWhenAppWillTerminate(key: applicationManagerKeySaveChanges, closure: {self.saveChangesAtTermination()})
    }

    // MARK: -
    
    public func saveChanges() {

        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                trace("in savechanges,  Unable to Save Changes of Main Managed Object Context, error.localizedDescription  = %{public}@", log: log, type: .info, error.localizedDescription)
            }
        }
        
        privateManagedObjectContext.perform {
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }
            } catch {
                trace("in savechanges,  Unable to Save Changes of Private Managed Object Context, error.localizedDescription  = %{public}@", log: self.log, type: .info, error.localizedDescription)
            }
        }
    }

    /// to be used when app terminates, difference with savechanges is that it calls privateManagedObjectContext.save synchronously
    private func saveChangesAtTermination() {
        
        // Shared CoreData with App Groups
        NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: mainManagedObjectContext)
        
        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                trace("in saveChangesAtTermination,  Unable to Save Changes of Main Managed Object Context, error.localizedDescription  = %{public}@", log: log, type: .info, error.localizedDescription)
            }
        }
        
        privateManagedObjectContext.performAndWait {
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }
            } catch {
                trace("in saveChangesAtTermination,  Unable to Save Changes of Private Managed Object Context, error.localizedDescription  = %{public}@", log: self.log, type: .info, error.localizedDescription)
            }
        }
    }

     // MARK: - Sending updates to other apps in the app group
     
    private func tickleURL() -> URL? {
        var tickleURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ConstantsAppGroups.AppGroupIdentifier)
        tickleURL = tickleURL?.appendingPathComponent(ConstantsAppGroups.TickleFolderPath, isDirectory: true)
        return tickleURL
    }

    // fake iCloud notification
     @objc private func sendUpdatesFromContextSaved(saveNotification: NSNotification) {
         var tickleURL = self.tickleURL()
         do {
             if let tickleURL = tickleURL {
                 try FileManager.default.createDirectory(at: tickleURL, withIntermediateDirectories: true, attributes: nil)
             }
         } catch { }
         let filename = UUID().uuidString
         tickleURL = tickleURL?.appendingPathComponent(filename)
         print("tickleURL: \(String(describing: tickleURL?.description))")
         
         let saveInfo = serializableDictionaryFromSaveNotification(saveNotification: saveNotification)

         if let tickleURL = tickleURL {
             let ret = (saveInfo! as NSDictionary).write(to: tickleURL, atomically: true)
             print("Write Value: \(ret)")
         }
     }
     
    private func serializableDictionaryFromSaveNotification(saveNotification: NSNotification) -> [AnyHashable : Any]? {
         var saveInfo: [AnyHashable : Any] = [:]
         
         guard let userInfo = saveNotification.userInfo else { return saveInfo }
         
         if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, inserts.count > 0 {
             var objectIDRepresentations: [AnyHashable] = []
             for e in inserts {
                 let objectID = e.objectID
                 let URIRepresentation = objectID.uriRepresentation()
                 let objectIDValue = URIRepresentation.absoluteString
                 objectIDRepresentations.append(objectIDValue)
             }
             saveInfo[NSInsertedObjectsKey] = objectIDRepresentations
         }
         return saveInfo
     }

}
