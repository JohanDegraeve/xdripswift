import Foundation

/// allowed values are 0, 1, 2 or 3. It's the index in coefficients
fileprivate var coefficientsRowToUse = 3

/// Savitzky Golay coefficients
fileprivate let coefficients =  [[ -3.0, 12.0, 17.0, 12.0, -3.0],
                                 [ -2.0, 3.0, 6.0, 7.0, 6.0, 3.0, -2.0],
                                 [ -21.0, 14.0, 39.0, 54.0, 59.0, 54.0, 39.0, 14.0, -21.0],
                                 [ -36.0, 9.0, 44.0, 69.0, 84.0, 89.0, 84.0, 69.0, 44.0, 9.0, -36.0]]

/// an array with elements of a type that conforms to Smoothable, can be filtered using  the Savitzky Golay algorithm
protocol SavitzkyGolaySmoothable {
    
    /// value to be smoothed
    var value: Double { get set }
    
}

/// local help class
fileprivate class IsSmoothable: SavitzkyGolaySmoothable {
    
    var value: Double = 0.0
    
    init(withValue value: Double = 0.0) {
        self.value = value
    }
    
}

extension Array where Element: SavitzkyGolaySmoothable {
    
    /// - apply Savitzky Golay filter
    /// - before applying the filter, the array will be prepended and append with a number of elements equal to the filterwidth, filterWidth default 5. Allowed values are 5, 4, 3, 2. If any other value is assigned, then 5 will be used
    /// - ...continue with 5 here in the explanation ...
    /// - for the 5 last elements and 5 first elements, a regression is done. This regression is done used to give values to the 5 prepended and appended values. Which means it's as if we draw a line through the first 5 and 5 last original values, and use this line to give values to the 5 prepended and appended values
    /// - the 5 prepended and appended values are then used in the filter algorithm, which means we can also filter the original 5 first and last elements
    /// see also example https://github.com/JohanDegraeve/xdripswift/wiki/Libre-value-smoothing
    mutating func smoothSavitzkyGolayQuaDratic(withFilterWidth filterWidth: Int = 5) {
        
        // filterWidthToUse is the value of filterWidth to use in the algorithm. By default filterWidthToUse = parameter value filterWidth
        var filterWidthToUse = filterWidth
        
        // calculate coefficientsRowToUse based on filterWdith
        switch filterWidth {
        case 5:
            coefficientsRowToUse = 3
            
        case 4:
            coefficientsRowToUse = 2
            
        case 3:
            coefficientsRowToUse = 1
            
        case 2:
            coefficientsRowToUse = 0
            
        default:
            // invalid filterWidth was given in parameterList, use default value
            coefficientsRowToUse = 3
            
            filterWidthToUse = 5
            
        }
        
        // using 5 here in the comments as value for filterWidthToUse
        
        // the amount of elements must be at least 5. If that's not the case then don't apply any smoothing
        guard self.count >= filterWidthToUse else {return}
        
        // create a new array, to which we will prepend and append 5 elements so that we can do also smoothing for the 5 last and 5 first values of the input array (which is self)
        // the 5 elements will be estimated by doing linear regression of the first 5 and last 5 elements of the original input array respectively
        // this is only a temporary array, but it will hold the elements of the original array, those elements will get a new value when doing the smoothing
        var tempArray = [SavitzkyGolaySmoothable]()
        for element in self {
            tempArray.append(element)
        }
        
        // now prepend and append with 5 elements, each with a default value 0.0
        for _ in 0..<filterWidthToUse {
            tempArray.insert(IsSmoothable(), at: 0)
            tempArray.append(IsSmoothable())
        }
        
        // so now we have tempArray, of length size of original array + 2 * 5
        // the first 5 and the last 5 elements are of type IsSmoothable with value 0
        
        // - indicesArray is a help array needed for the function linearRegressionCreator
        // - this will be the first parameter in the call to the linearRegression function, in fact it's an array of IsSmoothable with length = length of tempArray
        // - we give each IsSmoothable the value of the index, meaning from 0 up to (length of tempArray) - 1
        // - in fact it's not really smoothable, it's just because we use isSmoothable in function linearRegressionCreator
        var indicesArray = [SavitzkyGolaySmoothable]()
        for index in 0..<(self.count + (filterWidthToUse * 2)) {
            indicesArray.append(IsSmoothable(withValue: Double(index)))
        }
        
        /// - this is a piece of code that we will execute two times, once for the firs 5 elements, then for the last 5, so we put it in a closure variable
        /// - it calculates the regression function (which is nothing else but doing y = intercept + slope*x) for range defined by predictorRange in tempArray. It will be used for the 5 first and 5 last real values, ie the 5 first and 5 last real glucose values
        /// - then executes the regression for every element in the range defined by targetRange, again in tempArray
        let doRegression = { (predictorRange: Range<Int>, targetRange: Range<Int>) in
            
            // calculate the linearRegression function
            let linearRegression = linearRegressionCreator(indicesArray[predictorRange], tempArray[predictorRange])
            
            // ready to do the linear regression for the targetRange in tempArray
            for index in targetRange {
                
                tempArray[index].value = linearRegression(indicesArray[index].value)
                
            }
            
        }
        
        // now do the regression for the 5 first elements
        doRegression(filterWidthToUse..<(filterWidthToUse * 2), 0..<filterWidthToUse)
        
        // now do the regression for the 5 last elements
        doRegression((tempArray.count - filterWidthToUse * 2)..<(tempArray.count - filterWidthToUse), (tempArray.count - filterWidthToUse)..<tempArray.count)
        
        // now start filtering
        
        // initialize array that will hold the resulting filtered values
        var filteredValues = [Double]()
        
        // calculate divider
        let divider = coefficients[coefficientsRowToUse].reduce(0, { x, y in
            x + y
        })
        
        // filter each original value
        for _ in 0..<self.count {
            
            // add a new element to filteredValues, start value is 0.0
            // this new value will be the last element, so we access it with index filteredValues.count - 1
            filteredValues.append(0.0)
            
            // iterate through the coefficients
            for (index, coefficient) in coefficients[coefficientsRowToUse].enumerated() {
                
                filteredValues[filteredValues.count - 1] = filteredValues[filteredValues.count - 1] +  coefficient * tempArray[index + filteredValues.count - 1].value
                
            }
            
            filteredValues[filteredValues.count - 1] = filteredValues[filteredValues.count - 1] / divider
            
        }
        
        // now assign the new values to the original objects
        for (index, _) in self.enumerated() {
            
            self[index].value = filteredValues[index]
            
        }
        
    }
    
}

/// source https://github.com/raywenderlich/swift-algorithm-club/tree/master/Linear%20Regression
fileprivate func multiply(_ a: ArraySlice<SavitzkyGolaySmoothable>, _ b: ArraySlice<SavitzkyGolaySmoothable>) -> ArraySlice<SavitzkyGolaySmoothable> {
    return zip(a,b).map({IsSmoothable(withValue: $0.value * $1.value)})[0..<a.count]
}

/// source https://github.com/raywenderlich/swift-algorithm-club/tree/master/Linear%20Regression
fileprivate func average(_ input: ArraySlice<SavitzkyGolaySmoothable>) -> Double {
    
    return (input.reduce(IsSmoothable(), { (x: SavitzkyGolaySmoothable, y:SavitzkyGolaySmoothable) in
                            IsSmoothable(withValue: x.value + y.value)})).value / Double(input.count)
}

/// source https://github.com/raywenderlich/swift-algorithm-club/tree/master/Linear%20Regression
fileprivate func linearRegressionCreator(_ xs: ArraySlice<SavitzkyGolaySmoothable>, _ ys: ArraySlice<SavitzkyGolaySmoothable>) -> (Double) -> Double {
    
    let sum1 = average(multiply(ys, xs)) - average(xs) * average(ys)
    let sum2 = average(multiply(xs, xs)) - pow(average(xs), 2)
    let slope = sum1 / sum2
    let intercept = average(ys) - slope * average(xs)
    
    return { x in intercept + slope * x }
    
}
