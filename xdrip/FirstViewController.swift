import UIKit
import CoreData

class FirstViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        loadData(managedContext: managedContext)
        
        var testSensor:Sensor?
        var testCalibration:Calibration?
        var testReading = BgReading(timeStamp: Date(), sensor: testSensor, calibration: testCalibration, rawData: 100.2, filteredData: 110.1, nsManagedObjectContext: managedContext)
        
        appDelegate.saveContext()
        
    }
    
    func loadData(managedContext:NSManagedObjectContext) {
        let bgReadingLoadRequest:NSFetchRequest<BgReading> = BgReading.fetchRequest()
        
        var bgReadings:Array<BgReading> = []
        
        do {
            try  bgReadings = managedContext.fetch(bgReadingLoadRequest)
            
            for (index, reading) in bgReadings.enumerated() {
                print("Reading nr  \(index) has uniqueid \(reading.id)")
            }
        }catch {
            print("Could not load data")
        }
    }

    
}


