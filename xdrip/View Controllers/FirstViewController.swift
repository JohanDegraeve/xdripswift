import UIKit
import CoreData

class FirstViewController: UIViewController {

    // MARK: - Properties
    
    private var coreDataManager = CoreDataManager(modelName: "xdrip")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize Managed Object
        let bgReading = BgReading(timeStamp: Date(), sensor: nil, calibration: nil, rawData: 1.0, filteredData: 0.5, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        print(bgReading)
        
        do {
            try coreDataManager.mainManagedObjectContext.save()
        } catch {
            print("Unable to Save Managed Object Context")
            print("\(error), \(error.localizedDescription)")
        }

    }
    
}


