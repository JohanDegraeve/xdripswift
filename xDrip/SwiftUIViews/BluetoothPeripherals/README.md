# Dexcom setup UI flow

This describes the SwiftUI flow for adding G6 and G7 CGMs. It follows the code in this folder and the sensor management screen. Adding a Bluetooth peripheral and starting a sensor session are separate actions.

## Main paths

All four paths start at Bluetooth > Add > CGM > the Dexcom family > Connection Mode.

| Family and mode | Before the peripheral screen | On the peripheral screen | Sensor code |
| --- | --- | --- | --- |
| G6 Primary | Enter the six-character transmitter ID, then Continue | Check the settings, then tap Scan | Enter the four-digit sensor code through Start Sensor when a new session is needed |
| G6 Coexistence | Enter the six-character transmitter ID, then Continue | Keep the other app running, then tap Scan | No code is requested by Add CGM. Sensor management is a separate flow |
| G7 Primary | Enter or scan the four-digit pairing code, review it, then Continue. Enter an optional Bluetooth name, then Continue | Check the settings, then tap Scan | The reviewed pairing code is used by the first connection attempt |
| G7 Coexistence | Enter an optional Bluetooth name, then Continue | Keep the other app running, then tap Scan | This mode does not request a pairing code |

The optional G7 Bluetooth name is a scan filter. It is not the four-digit pairing code. Leaving it blank allows automatic discovery. A supplied name must start with DX and can be a partial name up to six characters long.

The G6 ID is validated and converted to uppercase. It identifies the transmitter, not the sensor session. The same family route also handles older Dexcom transmitters, so sensor management checks the actual transmitter before deciding whether to ask for a code or a start date.

## Connection Mode screen

The chooser starts with two rows and no selected mode. Each row has its coloured P or C symbol before the title and a trailing `colorQuaternary` checkmark circle at half opacity that becomes filled and green when selected. Selecting a row shows its diagram and explanation in a separate section below. Changing the selection replaces that section. The yellow toolbar OK button is enabled after a selection and starts the chosen setup flow. Only G6 shows a footer below the selected diagram explaining that its connection mode can be changed later in transmitter settings.

The primary app stays on the top row with an arrow at each end of its connection. In Primary mode this is xDrip4iOS. In Coexistence it is Other App, with xDrip4iOS on the second row. Its thicker dotted line points only into xDrip4iOS, while the primary connection uses a thinner solid gray line matching the Other App border. The Primary mode panel keeps its solid connection. Dexcom stays on the right.

Primary uses cyan and Coexistence uses purple from `ConstantsAppColors`. The sensor stays green. App frames have a dark gray background. The xDrip frame border uses the selected mode colour and Other App keeps a light gray border. App names and connection labels use the same light gray. The diagrams have 12 points of padding on each side. App names use 14 point text, connection labels 10.5 and the Dexcom label 12.8.

The xDrip frame uses `ConstantsHomeView.applicationName`, which reads `CFBundleDisplayName`. It also uses the existing `AppIconPreview` asset at 22 points with rounded corners. Other App uses a gray `apps.iphone` symbol, slightly darker than its label. Both app frames are up to 136 points wide to allow for instance names. The xDrip border is 2 points thick, with 3.5 point connection lines and arrows. Dexcom also has a 2 point border. Other App keeps its 1 point border. Names shrink to 80 percent if needed, then truncate at the end. In Coexistence the sensor frame spans both app rows so both connections stay horizontal.

The P and C symbols also appear in the Bluetooth list, Home footer, sensor management, peripheral status footer and G6 mode footer. All use the same mode colours. Activation warnings take priority over the normal mode footer.

The arrows explain which app owns the normal connection. They are not a complete description of Bluetooth traffic. In particular, the G6 implementation can send session-start and calibration commands while using Coexistence.

## Code entry and review

`SensorStartCodeView` is shared by G6 sensor start and G7 Primary setup.

1. Choose manual entry, camera scan or a photo.
2. Manual entry opens a separate numeric entry screen. Accepting a code returns to the review screen.
3. A successful camera scan or photo decode also returns the result to the review screen. Scanned labels can include additional sensor details.
4. Review the code and any label details, then tap Continue.

Neither a scan nor manual entry skips the review. Continue is disabled until there is a valid four-digit code and photo decoding has finished. Invalid labels show an error and leave the user in code entry.

G6 also offers Use Without Code. This selects `0000` for review. After Continue, sensor management asks for confirmation before sending that request. Entering `0000` does not by itself prove that a new session started or that calibration is due.

G7 does not offer Use Without Code. Its Primary setup must carry a valid pairing code before scanning starts.

## From Continue to Scan

`BluetoothPeripheralsRouter.showDexcomTransmitterID` collects the identifier before the peripheral detail state is created. Continue adds the detail screen to the current navigation path. It does not pop the entry screen first.

`DexcomAddConfiguration` carries the selected mode, optional scanned label, identifier and Bluetooth slots. A blank G7 name is stored as the existing scan placeholder so the detail screen can distinguish it from an identifier that has not been entered yet.

`BluetoothPeripheralDetailState` takes the supplied identifier during initialization. Its `start()` method only asks for an identifier when one is still missing. This prevents the detail screen from appearing briefly and then opening another entry screen.

Arriving at the detail screen does not start scanning. The user taps Scan. The current Dexcom routes start scanning directly and do not show the preparation alert used by Libre 2 and Medtrum.

Before discovery, compatible G6 Primary transmitters expose the Bluetooth channel setting. G6 Coexistence disables that setting. G7 Primary also exposes its channel setting before discovery. G7 Coexistence does not.

The Scan action is blocked in follower mode or while another CGM is enabled. These are checked again when activating the peripheral, not only when entering the Add flow.

## Discovery and connection

`scanForBluetoothPeripheral` passes the current mode, code and channel settings to `BluetoothPeripheralManager.startScanningForNewDevice`. The manager creates a temporary transmitter with that configuration and starts discovery.

G6 receives `useOtherApp` and the selected channel. G7 receives `useOtherApp`, the pairing code when present, and its channel. These settings are supplied before authentication, rather than changed after a device connects.

Scanning, Bluetooth connection, authentication and receiving a glucose reading are separate stages. A successful request to start scanning is not proof of a connection or a reading. Bluetooth being unavailable or unauthorized is reported on the detail screen.

When the manager reports the discovered peripheral, `handleFound` updates the existing detail state. It saves the identifier and mode, the selected channel, and the G7 label when present. It does not navigate to another detail screen.

After the device is saved, the action button follows its connection state. An enabled device offers Stop Scanning, which asks for disconnect confirmation. A disabled saved device offers Connect. These labels also cover Dexcom's intermittent connections between readings.

## Sensor session after adding the peripheral

### G6

Sensor management offers Start Sensor when manual sensor management is allowed and there is no active local sensor. For a G6 transmitter that needs a code, it opens the shared code-entry sheet. Older transmitters can request a start date instead.

Submitting the reviewed code goes through `RootApplicationCoordinator.startSensorFromManagementView`. This creates the local sensor request and passes it to the transmitter. `CGMG5Transmitter.startSensor` queues the start information for a connection. It does not complete the Bluetooth exchange synchronously with the button tap.

The Add CGM path is the same up to Scan for both G6 modes. Choosing Coexistence does not remove the separate G6 sensor management actions in the current code. A running sensor reported by the transmitter can also be adopted without starting another session. Session state and calibration prompts must follow transmitter evidence.

### G7

G7 does not offer manual Start Sensor in sensor management. The app follows the session reported by the sensor. The four-digit code collected in Primary setup is an authentication code, not a request to start a session.

The saved G7 detail screen shows the pairing code only in Primary mode. G7 has no mode-change picker after adding the sensor. Remove and add it again to choose another mode. G6 exposes a mode picker on its saved transmitter screen.

## Cancel and Back

- Before the detail screen, Back returns to the preceding setup step.
- Cancelling identifier entry returns to the mode chooser, or to code review for G7 Primary.
- Returning to code review resets its submission guard so Continue can be used again. The reviewed code remains selected.
- Manual code entry returns to review. Camera and photo entry do not bypass review.
- Identifier entry validates before calling its action. The submission guard ignores repeated taps while opening the next screen.
- Normal text-entry screens close after submitting. Setup sets `dismissAfterSubmit` to false because its action opens the next screen.
- The onboarding detail screen has its own Back button. It clears the setup path and returns to the Bluetooth list.
- Leaving the detail screen stops discovery for a new device. A saved device remains governed by its persisted connection setting.

## Source map

| Code | Responsibility |
| --- | --- |
| [BluetoothPeripheralsView.swift](BluetoothPeripheralsView.swift) | Chooser, diagram, code-review route and detail container |
| [BluetoothPeripheralsViewModel.swift](BluetoothPeripheralsViewModel.swift) | Navigation path and setup configuration |
| [BluetoothPeripheralDetailState.swift](BluetoothPeripheralDetailState.swift) | Scan action, activation checks, temporary settings and discovered peripheral |
| [BluetoothPeripheralDetailView.swift](BluetoothPeripheralDetailView.swift) | Status, mode footers and text entry |
| [SensorStartView.swift](../Sensor/SensorStartView.swift) | Shared code-entry and review UI |
| [SensorManagementView.swift](../Sensor/SensorManagementView.swift) | Start Sensor, no-code confirmation and session summary |
| [BluetoothPeripheralManager.swift](../../Managers/BluetoothPeripheral/BluetoothPeripheralManager.swift) | Temporary transmitter creation and discovery |
| [RootApplicationCoordinator.swift](../../Managers/Application/RootApplicationCoordinator.swift) | Local sensor request and handoff to the transmitter |
| [ConstantsAppColors.swift](../../Constants/ConstantsAppColors.swift) | Mode colours and the shared mode colour lookup |

## Checks when changing this flow

- Walk through both modes for both families. Verify the final detail appears once and Scan still needs a tap.
- Cancel identifier entry, return to code review, edit the code and continue again.
- Check manual entry, camera, photo, invalid input and G6 Use Without Code.
- Check blank and partial G7 Bluetooth names, plus lowercase G6 IDs.
- Verify the initial transmitter receives the selected mode, pairing code and channel.
- Check blocked activation, Bluetooth off and Bluetooth permission denied separately from discovery.
- Check the six P/C symbol locations, including both peripheral detail footers.
- Check the chooser on a narrow phone, iPad and with larger text. Diagrams must not overlap the explanation, and the whole card must remain tappable.

Syntax checks, standalone rendering and router checks do not verify camera permissions, Bluetooth pairing, animation timing or device behaviour. Those require the corresponding simulator or device checks.
