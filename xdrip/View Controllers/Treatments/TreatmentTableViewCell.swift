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
	
	public func setupWithTreatment(_ treatment: TreatmentEntry) {
		self.typeLabel.text = treatment.treatmentType.asString()
		self.valueLabel.text = treatment.displayValue()
		
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm"

		self.dateLabel.text = formatter.string(from: treatment.date)
	}
}
