# Optional Watch runtime support

Configure these options only in **Advanced Settings → Direct Libre (Experimental)
→ Background connection**. They support the existing collector; they do not change
Bluetooth recovery, authentication, sensor selection or reading delivery.

## Background location

1. Open xDrip on both devices and switch collection to Watch.
2. Enable **Background location** on the phone. Allow location access on the Watch.
3. Press **Refresh runtime status** after permission is granted. The last Watch
   status distinguishes waiting for permission, starting and receiving updates.
4. Return to the Watch face and test whether new readings continue. Test phone
   delivery separately: collecting on Watch does not guarantee immediate delivery.

The Watch remembers the opt-in and requested accuracy. Fresh installations default
to off and 100 m. The three buttons request 100 m, 1 km or 3 km accuracy, not a polling
interval. Coarser requests may reduce energy use; compare battery use and collection
reliability on a device. The app neither stores nor shares location coordinates.

An enabled session starts only with Watch collection selected and the Watch app
active. It then requests ongoing updates in the background. Returning collection to
the phone, receiving an NFC reset, revoking permission or disabling the option stops
updates. The opt-in stays saved across sensor changes. After relaunch, open the Watch
app to restart it. A failed location fix does not restart Bluetooth or alter ownership.

The page shows the last confirmed Watch reply, not a live runtime guarantee. It
refreshes on entry, foreground/reachability/selection changes or an explicit refresh;
there is no polling, queued enable command or automatic retry. If confirmation is
lost, reopen both apps and refresh before changing the setting again.

Implementation: `Libre2WatchLocationSession` owns one `CLLocationManager`; the shared
selection store publishes changes after its lock is released. `WatchStateModel`
owns the helper and routes only live requests with replies to it. The Watch declares
`UIBackgroundModes` values `location` and `bluetooth-central` and the location usage
description. No phone location manager, workout session or restricted entitlement
is added. These are experimental runtime aids, not guaranteed continuous monitoring.
See Apple's [background location guidance](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
and [`allowsBackgroundLocationUpdates`](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).

## Device checkpoint

- With location off, verify ordinary phone scanning and both transfer directions.
- Enable on Watch, grant permission, refresh status, then background both apps and
  confirm genuinely new values/timestamps on Watch and phone.
- Switch between all three accuracies; confirm the sensor connection remains intact.
- Disable while connected; confirm collection continues when the Watch is open.
- Re-enable, return collection to phone, then refresh: location must be waiting for
  Watch selection, rather than receiving updates. Repeat with a phone NFC reset
  delivered to the Watch.
- Relaunch Watch with the option enabled. Confirm foreground restart; also test
  denied permission and recovery after restoring permission in Settings.

Physical runtime, radio recovery, battery consumption and phone delivery timing
remain device tests; host tests and SDK type-checks cannot establish them.
