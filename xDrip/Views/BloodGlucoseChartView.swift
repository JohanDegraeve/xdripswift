import UIKit
import SwiftCharts

// source used : https://github.com/LoopKit/Loop

/// a SwiftChart to be added 
public class BloodGlucoseChartView: UIView {
    
    // MARK: - public properties
    
    public var chartGenerator: ((CGRect) -> UIView?)? {
        didSet {
            chartView = nil
            setNeedsLayout()
        }
    }
    
    // MARK: - private properties
    
    private var chartView: UIView? {
        didSet {
            if let view = oldValue {
                view.removeFromSuperview()
            }
            
            if let view = chartView {
                self.addSubview(view)
            }
        }
    }
    
    // MARK: public functions
    
    public func reloadChart() {
        chartView = nil
        setNeedsLayout()
    }
    
    // MARK: overriden functions
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if chartView == nil || chartView!.frame != bounds {
            // 50 is the smallest height in which we should attempt to redraw a chart.
            // Smaller sizes might be requested mid-animation, so ignore them.
            if bounds.height > 50 {
                chartView = chartGenerator?(bounds)
            }
        } else if chartView!.superview == nil {
            addSubview(chartView!)
        }
    }
    

    
}
