// MARK: Double as Kalman input
extension Double: KalmanInput {
    public var transposed: Double { self }
    public var inversed: Double { 1 / self }
    public var additionToUnit: Double { 1 - self }
}
