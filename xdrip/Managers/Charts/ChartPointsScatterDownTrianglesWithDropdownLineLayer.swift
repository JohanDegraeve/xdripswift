//
//  ChartPointsScatterDownTrianglesLayer.swift
//  Loop
//
//  Created by Nate Racklyeft on 9/28/16.
//  Edited by Paul Plant on 4/04/22.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import SwiftCharts


public class ChartPointsScatterDownTrianglesWithDropdownLineLayer<T: ChartPoint>: ChartPointsScatterLayer<T> {
    public required init(
        xAxis: ChartAxis,
        yAxis: ChartAxis,
        chartPoints: [T],
        displayDelay: Float,
        itemSize: CGSize,
        itemFillColor: UIColor,
        optimized: Bool = false,
        tapSettings: ChartPointsTapSettings<T>? = nil
    ) {
        // optimized must be set to false because `generateCGLayer` isn't public and can't be overridden
        super.init(
            xAxis: xAxis,
            yAxis: yAxis,
            chartPoints: chartPoints,
            displayDelay: displayDelay,
            itemSize: itemSize,
            itemFillColor: itemFillColor,
            optimized: false,
            tapSettings: tapSettings
        )
    }

    public override func drawChartPointModel(_ context: CGContext, chartPointModel: ChartPointLayerModel<T>, view: UIView) {
        let w = self.itemSize.width
        let h = self.itemSize.height

        let path = CGMutablePath()
        path.move(to: CGPoint(x: chartPointModel.screenLoc.x, y: chartPointModel.screenLoc.y + h / 2))
        path.addLine(to: CGPoint(x: chartPointModel.screenLoc.x + w / 2, y: chartPointModel.screenLoc.y - h / 2))
        path.addLine(to: CGPoint(x: chartPointModel.screenLoc.x - w / 2, y: chartPointModel.screenLoc.y - h / 2))
        
        // add a drop down line from the bottom point of the triangle. Make it long enough so that it will always get hidden beyond the bottom edge of the chart view
        path.addRect(CGRect(x: chartPointModel.screenLoc.x - 0.25, y: (chartPointModel.screenLoc.y + h / 2), width: 0.5, height: 200))
        
        path.closeSubpath()
        
        context.setFillColor(self.itemFillColor.cgColor)
        context.addPath(path)
        context.fillPath()
    }
}
