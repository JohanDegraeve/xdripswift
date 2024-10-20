//
//  TreatmentTableViewCell.swift
//  xdrip
//
//  Created by Eduardo Pietre on 24/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation

class TreatmentTableViewCell: UITableViewCell {
	@IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var unitLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    
    public func setupWithTreatment(_ treatment: TreatmentEntry) {
        
        // date label - formatted as per the user's locale and region settings
        let formatter = DateFormatter()
        formatter.amSymbol = ConstantsUI.timeFormatAM
        formatter.pmSymbol = ConstantsUI.timeFormatPM
        formatter.setLocalizedDateFormatFromTemplate(ConstantsUI.timeFormatHoursMins)
        self.dateLabel.text = formatter.string(from: treatment.date)
        
        
        // treatment type icon
        switch treatment.treatmentType {
            
        case .Insulin:
            self.iconImageView.tintColor =  ConstantsGlucoseChart.bolusTreatmentColor
            
        case .Carbs:
            self.iconImageView.tintColor =  ConstantsGlucoseChart.carbsTreatmentColor
            
        case .Exercise:
            self.iconImageView.tintColor =  UIColor.magenta
            
        case .BgCheck:
            self.iconImageView.tintColor =  ConstantsGlucoseChart.bgCheckTreatmentColorInner
            
        default:
            self.iconImageView.tintColor =  nil
            
        }
        
        switch treatment.treatmentType {
            
        case .Insulin:
            self.iconImageView.image =  UIImage(systemName: "arrowtriangle.down.fill")!
            
        case .Carbs:
            self.iconImageView.image =  UIImage(systemName: "circle.fill")!
            
        case .Exercise:
            self.iconImageView.image =  UIImage(systemName: "heart.fill")!
            
        case .BgCheck:
            self.iconImageView.image =  UIImage(systemName: "drop.fill") ?? nil
            
        default:
            self.iconImageView.tintColor =  nil
            
        }
        
        // treatment type label
        self.typeLabel.text = treatment.treatmentType.asString()
        
        // treatment value label
        if treatment.treatmentType == .BgCheck {
            
            // save typing
            let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
            
            // convert to mmol/l if needed, round accordingly and add the correct units
            self.valueLabel.text = treatment.value.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl).stringWithoutTrailingZeroes
            
        } else {
            
            self.valueLabel.text = treatment.value.stringWithoutTrailingZeroes
            
        }
        
        
        // treatment unit label
        if treatment.treatmentType == .BgCheck {
            
            // convert to mmol/l if needed, round accordingly and add the correct units
            self.unitLabel.text =  String(UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
            
        } else {
            
            self.unitLabel.text = treatment.treatmentType.unit()
            
        }
        
    }
    
}
