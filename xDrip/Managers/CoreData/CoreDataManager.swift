import CoreData
import os

/// development as explained in cocoacasts.com https://cocoacasts.com/bring-your-own
public final class CoreDataManager {
    
    // MARK: - Type Aliases
    
    public typealias CoreDataManagerCompletion = (CoreDataManager) -> Void
    
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
            let nsError = error as NSError
            trace("addPersistentStore failed domain=%{public}@ code=%{public}d desc=%{public}@ info=%{public}@", log: self.log, category: ConstantsLog.categoryCoreDataManager, type: .error, nsError.domain, nsError.code, nsError.localizedDescription, nsError.userInfo)
            fatalError("Unable to Add Persistent Store: \(nsError.domain) \(nsError.code) \(nsError.localizedDescription)")
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

    /// Creates a synchronous in-memory Core Data stack for deterministic manager integration tests.
    ///
    /// Production callers continue to use `init(modelName:completion:)`, which opens the normal
    /// SQLite store and installs application lifecycle saves. This initializer deliberately does
    /// neither: its only purpose is to let tests instantiate real managers without touching the
    /// user's application database or waiting for asynchronous persistent-store setup.
    ///
    /// - Parameter inMemoryModelName: The bundled managed-object model to load into memory.
    init(inMemoryModelName: String) {
        self.modelName = inMemoryModelName
        self.completion = { _ in }

        do {
            try persistentStoreCoordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: nil
            )
        } catch {
            fatalError("Unable to Add In-Memory Persistent Store: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupCoreDataStack() {
        // Fetch Persistent Store Coordinator directly to avoid nil when using parent/child contexts
        let persistentStoreCoordinator = self.persistentStoreCoordinator
        
        DispatchQueue.global().async {
            // Add Persistent Store
            self.addPersistentStore(to: persistentStoreCoordinator)
            
            // Invoke Completion On Main Queue
            DispatchQueue.main.async { self.completion(self) }
        }
        
        // when app terminates, call saveChangesAtTermination, just in case that somewhere in the code saveChanges is not called when needed
        ApplicationManager.shared.addClosureToRunWhenAppWillTerminate(key: applicationManagerKeySaveChangesWhenAppTerminates, closure: {self.saveChangesAtTermination()})
        
        // when app goes to background, call saveChanges, just in case that somewhere in the code saveChanges is not called when needed
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeySaveChangesWhenAppGoesToBackground, closure: { _ = self.saveChanges() })
        
    }

    // MARK: -
    
    /// Saves pending main-context changes and schedules the existing private-context save.
    ///
    /// Most callers intentionally ignore the result. User-facing audit paths can use it to avoid
    /// claiming that a treatment or reading change completed when the synchronous main save failed.
    /// Private-context work remains asynchronous and independent, matching the existing behavior.
    @discardableResult
    public func saveChanges() -> Bool {

        var mainContextSaveSucceeded = true

        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                mainContextSaveSucceeded = false
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

        return mainContextSaveSucceeded
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
