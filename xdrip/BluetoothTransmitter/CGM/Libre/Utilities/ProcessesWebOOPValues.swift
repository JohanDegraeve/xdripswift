import Foundation

/// to allow passing web oop values
protocol ProcessesWebOOPValues: AnyObject {
    
    /// updates Web OOP value
    func updateWebOOPValue(site: String?)

    /// updates Web OOP token
    func updateWebOOPValue(token: String?)
    
    /// updates status of web oop value
    func updateWebOOPValue(enabled: Bool)
    
}
