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
		self.typeLabel.text = treatment.treatmentType.asString()
		self.valueLabel.text = treatment.displayValue()
        self.unitLabel.text = treatment.displayUnit()
        self.iconImageView.tintColor = treatment.treatmentType.iconColor()
        self.iconImageView.image = treatment.treatmentType.iconImage()
		
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm"

		self.dateLabel.text = formatter.string(from: treatment.date)
	}
}
