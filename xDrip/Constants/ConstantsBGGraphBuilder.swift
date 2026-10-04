enum ConstantsBGGraphBuilder {
    /// minimum time needed to describe a glucose trend instead of sensor noise between readings
    static let minSlopeInMinutes = 4
    static let maxSlopeInMinutes = 21
    static let defaultUrgentHighMarkInMgdl = 230.0
    static let defaultHighMarkInMgdl = 180.0
    static let defaultTargetMarkInMgdl = 100.0
    static let defaultLowMarkInMgdl = 70.0
    static let defaultUrgentLowMarkInMgdl = 50.0
}
