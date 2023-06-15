#  Changes by Todd Dalton

Added custom BGView to take of displaying the main blood glucode level.

In RootViewController added computed iVar for UserDefaults.standard.bloodGlucoseUnitIsMgDl for purposes of code golf and ease of reading.

In BgReading+CoreDataClass tidied documentation (during reverse engineering to understand slope values)
Moved the logic of `unitizedString(_:)` to a static func `_unitizaedString(_:)` to make it available to all modules.
`unitizedString(_:)` now calls this static member (left in place to minimise rewriting)


Extended the enum BgRangeDescriptor to include the cases:
ugentLow
urgentHigh

Added to String extensions:

mgDl = "mg/dL"
mmolL = "mmol/L"


Changed passed in parameter of mgdlToMmolAndToString(_ :) to thisIsMgdL for ease of reading

Changed viewWillAppear(_ animated: Bool) in TreatmentsViewController to update black, translucent settings for ios 13.0+

Changed String extension, hexStringToUIColor() to use UInt64 and scanHexInt64(_:) as per deprecated warning for ios 13.0+
