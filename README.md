# xDrip4iOS

xDrip4iOS (`xdripswift`) is a community-developed, open-source iOS app for displaying and managing real-time continuous glucose monitor (CGM) data. It can connect directly to a compatible CGM in **Master** mode or retrieve remote readings from an online service in **Follower** mode.

xDrip4iOS is not related to the xDrip+ project for Android.

> [!IMPORTANT]
> xDrip4iOS is experimental software. It is not a regulated medical device and is not approved for making treatment decisions. Never rely on it as the only source of glucose information; use it at your own risk and confirm readings with approved equipment when necessary.

## Current capabilities

### Glucose data sources

Master mode currently includes:

- Dexcom G5, G6, Anubis and ONE
- Dexcom G7, ONE+ and Stelo
- Libre 2 and Libre 2 Plus EU sensors over direct Bluetooth
- Compatible Libre sensors through MiaoMiao or Nano/Bubble/Bubble Mini transmitters

Follower mode supports:

- Nightscout, including Loop and OpenAPS/AAPS status data
- LibreLinkUp and LibreLinkUp Russia
- Dexcom Share
- Medtrum EasyView

Sensor support depends on the exact model, region, transmitter firmware and whether an official CGM app must run alongside xDrip4iOS. Check the [compatibility guide](https://xdrip4ios.readthedocs.io/en/latest/#compatible-sensors) before choosing hardware or changing your setup.

### App features

- Configurable glucose charts with optional sensor-noise bands, reading history, treatments, statistics and time-in-range views
- Custom glucose, missed-reading, device and battery alerts, with spoken readings and trends
- Nightscout upload and synchronization, Dexcom Share upload and Apple Health integration
- Apple Watch app and complications
- Home Screen and Lock Screen widgets, StandBy support, Live Activities and Dynamic Island layouts
- Siri and Shortcuts access to the latest reading
- Optional calendar events and contact-image displays
- Open-source AID sharing with Loop/iAPS and Trio
- Bluetooth output to M5Stack and M5StickC companion displays

## Requirements

- iPhone 7 or newer running iOS 16.2 or later
- Apple Watch Series 4 or newer running watchOS 10 or later for Watch features
- An internet connection for follower modes and cloud services
- A compatible CGM setup for Master mode

Some extensions and system features require newer hardware or iOS versions.

## Installation

xDrip4iOS is primarily a do-it-yourself app and does not have an open public TestFlight. See the maintained [installation guide](https://xdrip4ios.readthedocs.io/en/latest/install/install/) for the currently available options.

You can install it by:

- Building from source with Xcode on a Mac
- Creating a personal TestFlight build with GitHub Actions and Fastlane

The repository includes detailed [personal TestFlight instructions](fastlane/testflight.md). A paid Apple Developer account is strongly recommended for either method.

## Building from source

The current project is configured for Xcode 26, Swift 5, iOS 16.2 and watchOS 10. Use the stable `master` branch for normal installs; ongoing work is merged through `develop`.

```sh
git clone --branch master https://github.com/JohanDegraeve/xdripswift.git
cd xdripswift
open xdrip.xcworkspace
```

Before building, configure your Apple development team in `xDripConfigOverride.xcconfig` as described in the full [Xcode build guide](https://xdrip4ios.readthedocs.io/en/latest/install/build/). Open the workspace rather than the project file so Xcode can resolve all package dependencies and targets correctly.

## Documentation and support

- [User documentation](https://xdrip4ios.readthedocs.io/en/latest/)
- [Installation and setup](https://xdrip4ios.readthedocs.io/en/latest/install/install/)
- [Troubleshooting](https://xdrip4ios.readthedocs.io/en/latest/troubleshoot/)
- [GitHub issues](https://github.com/JohanDegraeve/xdripswift/issues) for verified, reproducible bugs

Please use the community support channels linked from the documentation for general setup help rather than opening a bug report or contacting maintainers privately.

## Contributing

Bug fixes, translations, documentation improvements and new features are welcome. Base development work on the `develop` branch and open a pull request with a clear description of the change and how it was tested.

## License

xDrip4iOS is released under the [GNU General Public License v3.0](LICENSE).
