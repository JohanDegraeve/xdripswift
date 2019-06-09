import CoreData
import UIKit
import os

/// development as explained in cocoacasts.com https://cocoacasts.com/bring-your-own
final class CoreDataManager {
    
    // MARK: - Type Aliases
    
    public typealias CoreDataManagerCompletion = () -> ()
    
    // MARK: - Properties
    
    private let modelName: String
    
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryCoreDataManager)
    
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
        let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // URL Persistent Store
        let persistentStoreURL = documentsDirectoryURL.appendingPathComponent(storeName)
        
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
                os_log("in savechanges,  Unable to Save Changes of Main Managed Object Context, error.localizedDescription  = %{public}@", log: log, type: .info, error.localizedDescription)
            }
        }
        
        privateManagedObjectContext.perform {
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }
            } catch {
                os_log("in savechanges,  Unable to Save Changes of Private Managed Object Context, error.localizedDescription  = %{public}@", log: self.log, type: .info, error.localizedDescription)
            }
        }
    }

    /// to be used when app terminates, difference with savechanges is that it calls privateManagedObjectContext.save synchronously
    private func saveChangesAtTermination() {
        
        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                os_log("in saveChangesAtTermination,  Unable to Save Changes of Main Managed Object Context, error.localizedDescription  = %{public}@", log: log, type: .info, error.localizedDescription)
            }
        }
        
        privateManagedObjectContext.performAndWait {
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }
            } catch {
                os_log("in saveChangesAtTermination,  Unable to Save Changes of Private Managed Object Context, error.localizedDescription  = %{public}@", log: self.log, type: .info, error.localizedDescription)
            }
        }
    }

}
