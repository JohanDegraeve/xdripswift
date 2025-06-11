# Development Setup

## Prerequisites
- Xcode 14.0 or later
- iOS 15.0+ deployment target
- Apple Developer account (free or paid)
- CocoaPods or Swift Package Manager

## Initial Setup

### 1. Clone the repository
```bash
git clone https://github.com/JohanDegraeve/xdripswift.git
cd xdripswift
```

### 2. Configure your development team
Copy the example override configuration file:
```bash
cp xdrip/xDripOverride.xcconfig.example xdrip/xDripOverride.xcconfig
```

Edit `xdrip/xDripOverride.xcconfig` and add your Apple Developer Team ID:
```
XDRIP_DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE
```

You can find your Team ID in Xcode:
- Open Xcode Preferences (Cmd+,)
- Go to Accounts tab
- Select your Apple ID
- Your Team ID is shown in the team details

### 3. Open the project
```bash
open xdrip.xcworkspace
```

**Important**: Always use the `.xcworkspace` file, not the `.xcodeproj` file.

### 4. Select your development team in Xcode
The override configuration should automatically apply your team ID, but you may need to:
1. Select the xdrip project in the navigator
2. Go to "Signing & Capabilities" tab
3. Ensure your team is selected for all targets

## Configuration Files

### xDrip.xcconfig
This is the main configuration file with default settings. **Do not modify this file** as it's tracked in git and shared across all developers.

### xDripOverride.xcconfig
This is your personal override file that is ignored by git. Use this for:
- Your development team ID
- Custom bundle identifiers for testing
- Any other personal build settings

### Example override settings:
```
// Your Apple Developer Team ID
XDRIP_DEVELOPMENT_TEAM = ABC123DEF4

// Custom bundle identifier for testing
// PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.xdripswift

// Manual code signing (if needed)
// CODE_SIGN_STYLE = Manual
// PROVISIONING_PROFILE_SPECIFIER = your-provisioning-profile-name
```

## Building and Running

1. Select your target device or simulator
2. Build and run (Cmd+R)

## Troubleshooting

### Code signing issues
- Ensure your Apple ID is added to Xcode
- Check that your development team is correctly set in xDripOverride.xcconfig
- For free developer accounts, you may need to change the bundle identifier

### Build errors
- Clean build folder (Cmd+Shift+K)
- Delete derived data
- Ensure you're using the .xcworkspace file

## Contributing

Please read the [Wiki](https://github.com/JohanDegraeve/xdripswift/wiki) for detailed contribution guidelines.