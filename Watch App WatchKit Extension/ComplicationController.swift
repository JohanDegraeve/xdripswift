//
//  ComplicationController.swift
//  Watch App WatchKit Extension
//
//  Created by Paul Plant on 5/10/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import ClockKit
import WatchKit


class ComplicationController: NSObject, CLKComplicationDataSource {
    
    
    // MARK: - Complication Configuration

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(identifier: "complication", displayName: "xDrip4iO5", supportedFamilies: CLKComplicationFamily.allCases)
            // Multiple complication support can be added here with more descriptors
        ]
        
        // Call the handler with the currently supported complication descriptors
        handler(descriptors)
    }
    
    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Do any necessary work to support these newly shared complication descriptors
    }

    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Call the handler with the last entry date you can currently provide or nil if you can't support future timelines
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Call the handler with your desired behavior when the device is locked
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        
        var entry: CLKComplicationTimelineEntry? = nil
        
        let myDelegate = WKExtension.shared().delegate as! ExtensionDelegate
        
        let valueTextFull = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: myDelegate.currentBGValueTextFull)
        let valueText = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: myDelegate.currentBGValueText)
        let valueTrend = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: myDelegate.currentBGValueTrend)
        let minsAgoText = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: myDelegate.minsAgoText)
        let statusColor = myDelegate.currentBGValueStatus
        
        switch complication.family {
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleText.init(textProvider: valueText)
            entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        case .extraLarge:
            valueTextFull.tintColor = statusColor
            let template = CLKComplicationTemplateExtraLargeStackText.init(line1TextProvider: valueTextFull, line2TextProvider: minsAgoText)
            entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        case .graphicCircular:
            let gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: statusColor, fillFraction: 1)
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText.init(gaugeProvider: gaugeProvider, bottomTextProvider: valueTrend, centerTextProvider: valueText)
            entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallSimpleText.init(textProvider: valueTextFull)
            template.textProvider.tintColor = statusColor
            entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeTallBody.init(headerTextProvider: minsAgoText, bodyTextProvider: valueTextFull)
            entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
         default:
            break
        }
        handler(entry)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after the given date
        handler(nil)
    }

    // MARK: - Sample Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = getLocalizableSampleTemplate(for: complication.family)
        handler(template)
    }

    // basic templates copied from LoopKit and updated for WatchOS 7.0
    func getLocalizableSampleTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        
        let valueTextFull = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: "124↘︎")
        let valueText = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: "124")
        let valueTrend = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: "↘︎")
        let minsAgoText = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: "3 mins")
        let statusColor = UIColor.gray

        switch family {
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleText.init(textProvider: valueText)
            return template
        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeStackText.init(line1TextProvider: valueTextFull, line2TextProvider: minsAgoText)
            return template
        case .graphicCircular:
            let gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: statusColor, fillFraction: 1)
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText.init(gaugeProvider: gaugeProvider, bottomTextProvider: valueTrend, centerTextProvider: valueText)
            return template
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallSimpleText.init(textProvider: valueTextFull)
            return template
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeTallBody.init(headerTextProvider: minsAgoText, bodyTextProvider: valueTextFull)
            return template
        case .graphicRectangular, .graphicCorner, .graphicBezel, .graphicExtraLarge, .utilitarianLarge, .utilitarianSmall, .utilitarianSmallFlat:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
}
