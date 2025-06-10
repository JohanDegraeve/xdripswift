import Foundation

// MARK: - Mathematical Extensions for Array

extension Array where Element == Double {
    
    /// Calculates the mean (average) of the array values
    func mean() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }
    
    /// Calculates the standard deviation of the array values
    func standardDeviation() -> Double {
        guard count > 1 else { return 0.0 }
        let mean = self.mean()
        let variance = map { pow($0 - mean, 2) }.reduce(0, +) / Double(count - 1)
        return sqrt(variance)
    }
    
    /// Performs simple linear regression with corresponding time points
    /// Returns (slope, intercept) for y = slope * x + intercept
    func linearRegression(with timePoints: [Double]) -> (slope: Double, intercept: Double) {
        guard count == timePoints.count && count > 1 else {
            return (slope: 0.0, intercept: mean())
        }
        
        let n = Double(count)
        let sumX = timePoints.reduce(0, +)
        let sumY = reduce(0, +)
        let sumXY = zip(timePoints, self).map(*).reduce(0, +)
        let sumXX = timePoints.map { $0 * $0 }.reduce(0, +)
        
        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else {
            return (slope: 0.0, intercept: sumY / n)
        }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        
        return (slope: slope, intercept: intercept)
    }
    
    /// Calculates the correlation coefficient with time points
    func correlationCoefficient(with timePoints: [Double]) -> Double {
        guard count == timePoints.count && count > 1 else { return 0.0 }
        
        let meanX = timePoints.mean()
        let meanY = mean()
        
        let numerator = zip(timePoints, self).map { (x, y) in
            (x - meanX) * (y - meanY)
        }.reduce(0, +)
        
        let denominator = sqrt(
            timePoints.map { pow($0 - meanX, 2) }.reduce(0, +) *
            map { pow($0 - meanY, 2) }.reduce(0, +)
        )
        
        guard denominator != 0 else { return 0.0 }
        return numerator / denominator
    }
    
    /// Calculates polynomial regression coefficients for given degree
    /// Uses normal equations: (X'X)⁻¹X'Y
    /// Returns coefficients for polynomial: a₀ + a₁x + a₂x² + ... + aₙxⁿ
    func polynomialRegression(with timePoints: [Double], degree: Int) -> [Double] {
        guard count == timePoints.count && count > degree else {
            return [mean()] // Return mean as fallback
        }
        
        let n = count
        let degreeCount = degree + 1
        
        // Create design matrix X where each row is [1, x, x², x³, ...]
        var designMatrix: [[Double]] = []
        for x in timePoints {
            var row: [Double] = []
            for power in 0...degree {
                row.append(pow(x, Double(power)))
            }
            designMatrix.append(row)
        }
        
        // Calculate X'X (transpose of X multiplied by X)
        var xtx: [[Double]] = (0..<degreeCount).map { _ in Array(repeating: 0.0, count: degreeCount) }
        for i in 0..<degreeCount {
            for j in 0..<degreeCount {
                for k in 0..<n {
                    xtx[i][j] += designMatrix[k][i] * designMatrix[k][j]
                }
            }
        }
        
        // Calculate X'Y (transpose of X multiplied by Y)
        var xty: [Double] = Array(repeating: 0.0, count: degreeCount)
        for i in 0..<degreeCount {
            for k in 0..<n {
                xty[i] += designMatrix[k][i] * self[k]
            }
        }
        
        // Solve the system (X'X)β = X'Y using Gaussian elimination
        let coefficients = solveLinearSystem(matrix: xtx, vector: xty)
        return coefficients
    }
    
    /// Solves a linear system Ax = b using Gaussian elimination with partial pivoting
    private func solveLinearSystem(matrix: [[Double]], vector: [Double]) -> [Double] {
        let n = matrix.count
        var a = matrix
        var b = vector
        
        // Forward elimination with partial pivoting
        for i in 0..<n {
            // Find pivot
            var maxRow = i
            for k in (i+1)..<n {
                if abs(a[k][i]) > abs(a[maxRow][i]) {
                    maxRow = k
                }
            }
            
            // Swap rows
            if maxRow != i {
                a.swapAt(i, maxRow)
                b.swapAt(i, maxRow)
            }
            
            // Make all rows below this one 0 in current column
            for k in (i+1)..<n {
                if a[i][i] != 0 {
                    let factor = a[k][i] / a[i][i]
                    for j in i..<n {
                        a[k][j] -= factor * a[i][j]
                    }
                    b[k] -= factor * b[i]
                }
            }
        }
        
        // Back substitution
        var x = Array(repeating: 0.0, count: n)
        for i in stride(from: n-1, through: 0, by: -1) {
            x[i] = b[i]
            for j in (i+1)..<n {
                x[i] -= a[i][j] * x[j]
            }
            if a[i][i] != 0 {
                x[i] /= a[i][i]
            }
        }
        
        return x
    }
    
    /// Evaluates a polynomial with given coefficients at point x
    /// coefficients[0] + coefficients[1]*x + coefficients[2]*x² + ...
    static func evaluatePolynomial(coefficients: [Double], at x: Double) -> Double {
        var result = 0.0
        for (power, coefficient) in coefficients.enumerated() {
            result += coefficient * pow(x, Double(power))
        }
        return result
    }
    
    /// Calculates error variance for a model given actual vs predicted values
    func errorVariance(predicted: [Double]) -> Double {
        guard count == predicted.count && count > 1 else { return Double.infinity }
        
        let errors = zip(self, predicted).map { actual, pred in
            pow(actual - pred, 2)
        }
        
        return errors.reduce(0, +) / Double(count - 1)
    }
}

// MARK: - Utility Extensions

extension Array where Element == Double {
    
    /// Removes outliers using interquartile range method
    func removeOutliers() -> [Double] {
        let sorted = self.sorted()
        let count = sorted.count
        
        guard count > 4 else { return self }
        
        let q1Index = count / 4
        let q3Index = (3 * count) / 4
        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr
        
        return self.filter { $0 >= lowerBound && $0 <= upperBound }
    }
    
    /// Applies simple moving average smoothing
    func movingAverage(windowSize: Int) -> [Double] {
        guard count >= windowSize && windowSize > 0 else { return self }
        
        var smoothed: [Double] = []
        for i in 0..<count {
            let start = Swift.max(0, i - windowSize / 2)
            let end = Swift.min(count - 1, i + windowSize / 2)
            let window = Array(self[start...end])
            smoothed.append(window.mean())
        }
        
        return smoothed
    }
}