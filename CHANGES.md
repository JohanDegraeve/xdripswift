#  Main changes by Todd Dalton

Added custom BGView to take of displaying the main blood glucode level.
This consists of:

A more strictly formatted number (so that when user is panning, the number doesn't bounce left and right as the text is centred in the screen) for the level.

A re-designed time stamp view that displays the current time and nothing else when the use is not panning the graph and the level displayed is the latest one.

A re-designed delta view that has a guage with an arrow. The arrow is angled according to the rate of change (also displayed in text next to it) and as the rate becomes more severe, a secondary arrow will begin to appear behind it to emphasise the rate to the user.

The current BlueTooth status; connected, connecting, disconnecting, and dosconnected (seen from left to right under the BG level digits). This is designed to reflect what is shown in the BlueTooth view.

The level view is colour-coded rather than using strikethrough text. I felt this has a clearer visual interpretation than using struck through numbers as this always appeared to represent some sort of 'invalid' reading.

The view goes light grey when the user is panning through the chart and when they are displaying the current level it is colourised according to the level (green, yellow or red).

Also fixed a bug where the bottom of the stackview on the home screen would disappear behind the tab controller. This appears to be because the safe area of the main view disappears somehow when the device is rotated back to portrait.


# Other changes

In `RootViewController` added computed iVar for `UserDefaults.standard.bloodGlucoseUnitIsMgDl` for purposes of ease of reading.

In `BgReading+CoreDataClass` tidied documentation (during reverse engineering to understand slope values)
Moved the logic of `unitizedString(_:)` to a static func `_unitizedString(_:)` to make it available to all modules.
`unitizedString(_:)` now calls this static member (left in place to minimise rewriting)

Extended the enum BgRangeDescriptor to include the cases:
ugentLow
urgentHigh

Added to String extensions:

mgDl = "mg/dL"
mmolL = "mmol/L"


Changed passed in parameter of `mgdlToMmolAndToString(_ :)` to `thisIsMgdL` for ease of reading

Changed `viewWillAppear(_ animated: Bool)` in `TreatmentsViewController` to update black, translucent settings for ios 13.0+

Changed String extension, `hexStringToUIColor()` to use UInt64 and `scanHexInt64(_:)`as per deprecated warning for ios 13.0+

Modified unitizedDeltaString(previousBgReading:BgReading?, showUnit:Bool, highGranularity:Bool, mgdl:Bool) to return a Tuple of the string and the Double value.
This is used by the new delta view in my code.

Added

    static let UsersUnits = {
        return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
    }()
    
To Texts_Common

Added extensions for:

`Bool` - now you can obtain a '1' or '0' according to the bool state, useful for alpha animations.

`UIFont` - static's to allow for easier change of fonts.

`Double` - now MMOL and MGDL are numeric types akin to Double. This helps with reading of code and logic flow. Only used in my changes, at some point - if desired - it could be rolled out across the app)

`NSLayoutContraint` - added convenience functions to make instantiating constraints shorter in code.

`NSParagraphStyle` - added convenience functions for justifying text.

`UIView` - added convenience function for adding and activating constraints.
