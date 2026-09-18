#if canImport(CoreNFC)
import CoreNFC
import Foundation
import os

// Phone provisioning is separate from the transmitter's BLE lifecycle.
extension CGMLibre2Transmitter {
    func startNFCScanning() -> BluetoothTransmitter.startScanningResult {
        // For Libre 2, a user-requested scan starts with NFC because the NFC read enables
        // Bluetooth streaming and refreshes the unlock state before BLE reconnects.

        // create libreNFC instance and start session
        if NFCTagReaderSession.readingAvailable {
            // startScanning is getting called several times, but we must restrict launch of nfc scan to one single time, therefore check if libreNFC == nil
            if libreNFC == nil {
                // One explicit Libre Connect/Add request creates one NFC session. Log that user-level
                // milestone here, where the session is actually created, rather than in the repeated
                // Bluetooth scanning callbacks that can occur while iOS changes radio state.
                trace(
                    "starting Libre NFC sensor scan",
                    log: log,
                    category: ConstantsLog.categoryCGMLibre2,
                    type: .info,
                    troubleshooting: .standard(.cgm(source: .libre2, activity: .nfcScanStarted))
                )

                // NFC session creation must be on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let libreNFC = LibreNFC(libreNFCDelegate: self)
                    self.libreNFC = libreNFC
                    libreNFC.startSession()
                }
            }

        } else {
            trace(
                "Libre NFC sensor scanning is unavailable on this device",
                log: log,
                category: ConstantsLog.categoryCGMLibre2,
                type: .error,
                troubleshooting: .standard(.cgm(source: .libre2, activity: .nfcUnavailable))
            )

            // delegate may touch UI/Core Data → ensure main thread
            DispatchQueue.main.async { [weak self] in
                self?.bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.deviceMustSupportNFC)
            }
        }

        // start the NFC scan (not BLE scanning)
        return .nfcScanNeeded
    }
}

// MARK: - LibreNFCDelegate functions

extension CGMLibre2Transmitter: LibreNFCDelegate {
    func received(fram: Data) {
        trace("received fram :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, fram.hexEncodedString())

        // if we already know the patchinfo (which we should because normally received(sensorUID: Data, patchInfo: Data) gets called before received(fram: Data), then patchInfo should not be nil
        // same for sensorUID
        if let patchInfo = UserDefaults.standard.librePatchInfo, let sensorUID = UserDefaults.standard.libreSensorUID, let libreSensorType = LibreSensorType.type(patchInfo: patchInfo.hexEncodedString().uppercased()), let serialNumber = sensorSerialNumber {
            self.libreSensorType = libreSensorType

            var framCopy = fram

            if libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &framCopy, headerLength: 0, log: log, patchInfo: patchInfo.hexEncodedString().uppercased(), uid: Array(sensorUID)) {
                // we have all date to create libre1DerivedAlgorithmParameters
                UserDefaults.standard.libre1DerivedAlgorithmParameters = Libre1DerivedAlgorithmParameters(bytes: framCopy, serialNumber: serialNumber, libreSensorType: libreSensorType)
            }
        }
    }

    func received(sensorUID: Data, patchInfo: Data) {
        // store sensorUID as data in UserDefaults
        UserDefaults.standard.libreSensorUID = sensorUID

        // store the sensorUID as tempSensorSerialNumber (as LibreSensorSerialNumber)
        let receivedSensorSerialNumber = LibreSensorSerialNumber(withUID: sensorUID, with: LibreSensorType.type(patchInfo: patchInfo.hexEncodedString()))
        if let receivedSensorSerialNumber = receivedSensorSerialNumber {
            tempSensorSerialNumber = receivedSensorSerialNumber
        }

        // sensor serial number as String
        let receivedSensorSerialNumberAsString = receivedSensorSerialNumber?.serialNumber

        if let receivedSensorSerialNumberAsString = receivedSensorSerialNumberAsString {
            // is it a new value ?
            if sensorSerialNumber != receivedSensorSerialNumberAsString {
                trace("new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, receivedSensorSerialNumberAsString)

                sensorSerialNumber = receivedSensorSerialNumberAsString

                // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)
                    self.cGMLibre2TransmitterDelegate?.received(serialNumber: receivedSensorSerialNumberAsString, from: self)
                }
            }

        } else {
            trace("could not created sensor serial number from received sensorUID, sensorUID = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, sensorUID.hexEncodedString())
        }

        trace("patchInfo received :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, patchInfo.hexEncodedString())

        UserDefaults.standard.librePatchInfo = patchInfo
    }

    func streamingEnabled(successful: Bool, unlockCode: UInt32) {
        if successful {
            trace("received streaming enabled message from NFC with result successful, setting unlockCount to 0", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)

            // A previous installation may have saved a different code. Adopt the one
            // that this NFC scan actually provisioned before BLE sends its next unlock.
            UserDefaults.standard.libreActiveSensorUnlockCode = unlockCode
            UserDefaults.standard.libreActiveSensorUnlockCount = 0

        } else {
            trace("received streaming enabled message from NFC with result unsuccessful", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
        }
    }

    func nfcScanResult(_ result: LibreNFCScanResult) {
        // Keep the Core NFC error and sensor payload in the developer trace. Only this closed result
        // crosses into the shareable Activity Log, so cancellation and timeout remain distinct from
        // an actual scan failure without exposing a sensor serial number or raw NFC response.
        let activity: TroubleshootingCGMActivity
        let developerResult: String
        switch result {
        case .succeeded:
            activity = .nfcScanSucceeded
            developerResult = "successful"
        case .failed:
            activity = .nfcScanFailed
            developerResult = "failed"
        case .cancelled:
            activity = .nfcScanCancelled
            developerResult = "cancelled"
        case .timedOut:
            activity = .nfcScanTimedOut
            developerResult = "timed out"
        }

        trace(
            "received NFC scan result from NFC with result %{public}@",
            log: log,
            category: ConstantsLog.categoryCGMLibre2,
            type: result == .succeeded ? .info : .error,
            troubleshooting: .standard(.cgm(source: .libre2, activity: activity)),
            developerResult
        )

        if result == .succeeded {
            // Avoid triggering the success observer more than once for the same scan.
            if !UserDefaults.standard.nfcScanSuccessful {
                UserDefaults.standard.nfcScanSuccessful = true
            }
        } else if !UserDefaults.standard.nfcScanFailed {
            // The current UI offers the same retry sheet for failure, cancellation and timeout. The
            // Activity Log has already retained the more accurate reason above.
            UserDefaults.standard.nfcScanFailed = true
        }
    }

    func nfcScanExpectedDevice(serialNumber: String, macAddress: String) {
        let expectedBluetoothName = libreSensorType?.usesMacAddressAsBluetoothName == true
            ? macAddress
            : "ABBOTT" + serialNumber

        expectedBluetoothNameFromNFC = expectedBluetoothName
        updateExpectedDeviceName(name: expectedBluetoothName)
    }
}
#endif
