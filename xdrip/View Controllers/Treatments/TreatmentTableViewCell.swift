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
    @IBOutlet weak var valueSecondaryLabel: UILabel!
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
        
        // save typing
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // treatment type icon
        switch treatment.treatmentType {
        case .Insulin:
            self.iconImageView.image =  UIImage(systemName: "arrowtriangle.down.fill")!
            self.iconImageView.tintColor =  ConstantsGlucoseChart.bolusTreatmentColor
            
        case .Carbs:
            self.iconImageView.image =  UIImage(systemName: "circle.fill")!
            self.iconImageView.tintColor =  ConstantsGlucoseChart.carbsTreatmentColor
            
        case .Exercise:
            self.iconImageView.image =  UIImage(systemName: "heart.fill")!
            self.iconImageView.tintColor =  UIColor.magenta
            
        case .BgCheck:
            self.iconImageView.image =  UIImage(systemName: "drop.fill") ?? nil
            self.iconImageView.tintColor =  ConstantsGlucoseChart.bgCheckTreatmentColorInner
            
        case .Basal:
            self.iconImageView.image = UIImage(systemName: "chart.bar.fill")!
            self.iconImageView.tintColor =  ConstantsGlucoseChart.basalTreatmentColor
            
        default:
            self.iconImageView.tintColor =  nil
        }
        
        // treatment type label
        self.typeLabel.text = treatment.treatmentType.asString()
        
        // treatment value label
        switch treatment.treatmentType {
        case .BgCheck:
            // convert to mmol/l if needed, round accordingly and add the correct units
            self.valueLabel.text = treatment.value.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl).stringWithoutTrailingZeroes
        case .Basal:
            // convert to mmol/l if needed, round accordingly and add the correct units
            self.valueLabel.text = (round(treatment.value * 100)/100).stringWithoutTrailingZeroes
        default:
            self.valueLabel.text = treatment.value.stringWithoutTrailingZeroes
        }
        
        // treatment unit label
        switch treatment.treatmentType {
        case .BgCheck:
            // convert to mmol/l if needed, round accordingly and add the correct units
            self.unitLabel.text =  String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
        default:
            self.unitLabel.text = treatment.treatmentType.unit()
        }
        
        if treatment.treatmentType == .Basal {
            self.valueSecondaryLabel.isHidden = false
            self.valueSecondaryLabel.text = "(\(Int(treatment.valueSecondary)) mins)"
        } else {
            self.valueSecondaryLabel.isHidden = true
        }
        
    }
    
}
