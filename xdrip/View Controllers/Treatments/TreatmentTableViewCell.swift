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
        // save typing
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // date label - formatted as per the user's locale and region settings
        let formatter = DateFormatter()
        formatter.amSymbol = ConstantsUI.timeFormatAM
        formatter.pmSymbol = ConstantsUI.timeFormatPM
        formatter.setLocalizedDateFormatFromTemplate(ConstantsUI.timeFormatHoursMins)
        
        self.dateLabel.text = formatter.string(from: treatment.date)
        self.dateLabel.textColor = treatment.date > Date() ? UIColor(resource: .colorTertiary) : UIColor(resource: .colorPrimary)
        
        // treatment type icon
        switch treatment.treatmentType {
        case .Insulin:
            self.iconImageView.image = UIImage(systemName: "arrowtriangle.down.fill")!
            self.iconImageView.tintColor = ConstantsGlucoseChart.bolusTreatmentColor
            
        case .Carbs:
            self.iconImageView.image = UIImage(systemName: "circle.fill")!
            self.iconImageView.tintColor = ConstantsGlucoseChart.carbsTreatmentColor
            
        case .Exercise:
            self.iconImageView.image = UIImage(systemName: "heart.fill")!
            self.iconImageView.tintColor = UIColor.magenta
            
        case .BgCheck:
            self.iconImageView.image = UIImage(systemName: "drop.fill") ?? nil
            self.iconImageView.tintColor = ConstantsGlucoseChart.bgCheckTreatmentColorInner
            
        case .Basal:
            self.iconImageView.image = UIImage(systemName: "chart.bar.fill")!
            self.iconImageView.tintColor = ConstantsGlucoseChart.basalTreatmentColor
            
        case .SiteChange:
            self.iconImageView.image = UIImage(systemName: "cross.vial.fill")!
            self.iconImageView.tintColor = .systemYellow
            
        case .SensorStart:
            self.iconImageView.image = UIImage(systemName: "sensor.tag.radiowaves.forward.fill")!
            self.iconImageView.tintColor = .systemYellow
            
        case .PumpBatteryChange:
            self.iconImageView.image = UIImage(systemName: "battery.100percent")!
            self.iconImageView.tintColor = .systemYellow
            
        default:
            self.iconImageView.tintColor = nil
        }
        
        if treatment.date > Date() {
            self.iconImageView.tintColor = self.iconImageView.tintColor.withAlphaComponent(0.5)
        }
        
        // treatment type label
        self.typeLabel.text = treatment.treatmentType.asString()
        self.typeLabel.textColor = treatment.date > Date() ? UIColor(resource: .colorTertiary) : UIColor(resource: .colorPrimary)
        
        // treatment value and unit labels
        switch treatment.treatmentType {
        case .BgCheck:
            // convert to mmol/l if needed, round accordingly and add the correct units
            self.valueLabel.text = treatment.value.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl).stringWithoutTrailingZeroes
            self.unitLabel.text = String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
        case .SiteChange, .SensorStart, .PumpBatteryChange:
            self.valueLabel.text = nil
            self.unitLabel.text = nil
        default:
            self.valueLabel.text = (round(treatment.value * 100) / 100).stringWithoutTrailingZeroes
            self.unitLabel.text = treatment.treatmentType.unit()
        }
        
        self.valueLabel.textColor = treatment.date > Date() ? UIColor(resource: .colorTertiary) : UIColor(resource: .colorPrimary)
        self.unitLabel.textColor = treatment.date > Date() ? UIColor(resource: .colorTertiary) : UIColor(resource: .colorSecondary)
        
        // if a basal rate, show the duration which is stored as valueSecondary
        if treatment.treatmentType == .Basal {
            self.valueSecondaryLabel.text = "(\(Int(treatment.valueSecondary)) mins)"
            self.valueSecondaryLabel.isHidden = false
        } else {
            self.valueSecondaryLabel.isHidden = true
        }
        
        self.valueSecondaryLabel.textColor = UIColor(resource: .colorSecondary)
    }
}
