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
    private let applicationManagerKeySaveChangesWhenAppTerminates = "applicationManagerKeySaveChangesWhenAppTerminates"

    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillTerminate
    private let applicationManagerKeySaveChangesWhenAppGoesToBackground = "applicationManagerKeySaveChangesWhenAppGoesToBackground"
    

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
    
    private(set) lazy var privateManagedObjectContext: NSManagedObjectContext = {
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
        
        // when app terminates, call saveChangesAtTermination, just in case that somewhere in the code saveChanges is not called when needed
        ApplicationManager.shared.addClosureToRunWhenAppWillTerminate(key: applicationManagerKeySaveChangesWhenAppTerminates, closure: {self.saveChangesAtTermination()})
        
        // when app goes to background, call saveChanges, just in case that somewhere in the code saveChanges is not called when needed
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeySaveChangesWhenAppGoesToBackground, closure: {self.saveChanges()})
        
    }

    // MARK: -
    
    public func saveChanges() {

        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                trace("in savechanges,  Unable to Save Changes of Main Managed Object Context, error.localizedDescription  = %{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .info, error.localizedDescription)
                
                let error = error as NSError
                for (key,errors) in error.userInfo {
                    if key == "NSDetailedErrors" {
                        if let errors = (errors as? NSArray) {
                            for error in errors {
                                if let error = (error as? NSError) {
                                    
                                    trace("   error.localizedDescription = %{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .info, error.localizedDescription)
                                    
                                }
                            }
                            
                        }
                    }
                }
            }
        }
        
        privateManagedObjectContext.perform {
            
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }
            } catch {
                trace("in savechanges,  Unable to Save Changes of Private Managed Object Context, error.localizedDescription  = %{public}@", log: self.log, category: ConstantsLog.categoryCoreDataManager, type: .info, error.localizedDescription)
            }
            
        }
        
    }
    
    /// creates an NSManagedObjectContext with concurrencyType = privateQueueConcurrencyType and parent = mainManagedObjectContext
    public func privateChildManagedObjectContext() -> NSManagedObjectContext {
        // Initialize Managed Object Context
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)

        // Configure Managed Object Context
        managedObjectContext.parent = mainManagedObjectContext

        return managedObjectContext
    }

    /// to be used when app terminates, difference with savechanges is that it calls privateManagedObjectContext.save synchronously
    private func saveChangesAtTermination() {
        
        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                trace("in saveChangesAtTermination,  Unable to Save Changes of Main Managed Object Context, error.localizedDescription  = %{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .info, error.localizedDescription)
            }
        }
        
        privateManagedObjectContext.performAndWait {
            if self.privateManagedObjectContext.hasChanges {
                do {
                    try self.privateManagedObjectContext.save()
                } catch {
                    trace("in saveChangesAtTermination, failed to save private context: %{public}@", log: self.log, category: ConstantsLog.categoryCoreDataManager, type: .error, error.localizedDescription)
                }
            }
        }
    }

}
