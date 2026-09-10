import Foundation
import CoreBluetooth

// MARK: - CBCentralManagerDelegate

extension AidexSensor: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[AidexSensor] centralManagerDidUpdateState: \(central.state.rawValue), shouldReconnect=\(shouldReconnect), phase=\(connectionPhase), hasPeripheral=\(peripheral != nil)")
        if central.state == .poweredOn {
            if shouldReconnect {
                // If we already have a pending peripheral (from connectToDiscovered or
                // doConnectToIdentifier), connect directly. Otherwise start scanning.
                // Don't start scanning when the phase is already .connecting — that
                // conflicts with a pending doConnectToIdentifier() call.
                if let p = peripheral {
                    print("[AidexSensor] centralManagerDidUpdateState: pending peripheral, calling central.connect()")
                    central.connect(p, options: nil)
                } else if case .connecting = connectionPhase {
                    // doConnectToIdentifier is already polling for .poweredOn —
                    // don't start a competing scan.
                    print("[AidexSensor] centralManagerDidUpdateState: already connecting, waiting for doConnectToIdentifier")
                } else {
                    print("[AidexSensor] centralManagerDidUpdateState: starting scan")
                    startScan()
                }
            }
        } else {
            connectionPhase = .disconnected
            isStreaming = false
        }
    }

    public func centralManager(_ central: CBCentralManager,
                                didDiscover peripheral: CBPeripheral,
                                advertisementData: [String: Any],
                                rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        let candidate = config.deviceName

        if config.scanOnly {
            // In scan-only mode, accept any device whose name matches
            // one of the known Aidex/Linx/Lumiflex prefixes.
            let matchesKnownPrefix = AidexUUID.knownNamePrefixes.contains { prefix in
                name.localizedCaseInsensitiveContains(prefix)
            }
            guard matchesKnownPrefix else {
                print("[AidexSensor] didDiscover: name=\(name) does NOT match any known Aidex prefix — skipping")
                return
            }
        } else {
            guard name.localizedCaseInsensitiveContains(SerialCrypto.stripPrefix(candidate))
                  || candidate.localizedCaseInsensitiveContains(SerialCrypto.stripPrefix(name))
            else {
                print("[AidexSensor] didDiscover: name=\(name) does NOT match candidate=\(candidate) — skipping")
                return
            }
        }

        print("[AidexSensor] didDiscover MATCH: name=\(name) rssi=\(RSSI.intValue) scanOnly=\(config.scanOnly)")

        // Scan-only mode: collect all discovered sensors, don't connect yet
        if config.scanOnly {
            let discovered = DiscoveredAidexSensor(
                peripheral: peripheral,
                name: name,
                rssi: RSSI.intValue,
                advertisementData: advertisementData
            )
            discoveredSensors[peripheral.identifier] = discovered
            return
        }

        self.peripheral = peripheral
        self.rssi = RSSI.intValue
        central.stopScan()

        // Post-reset: отключаем авто-переподключение чтобы iOS не использовала
        // кешированные bonding-ключи (сенсор уже сбросил свои через CLEAR_STORAGE).
        var connectOptions: [String: Any]? = nil
        if postResetRescanActive {
            if #available(iOS 17.0, macOS 14.0, *) {
                connectOptions = [CBConnectPeripheralOptionEnableAutoReconnect: false]
            }
        }

        central.connect(peripheral, options: connectOptions)
        connectionPhase = .connecting(peripheral.identifier.uuidString)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[Aidex-DEBUG] ═══ DID_CONNECT: \(peripheral.name ?? "unnamed") id=\(peripheral.identifier.uuidString.prefix(8))...")
        print("[Aidex-DEBUG]   pendingResetReconnect=\(pendingResetReconnect) needsPostResetActivation=\(needsPostResetActivation) postResetRescanActive=\(postResetRescanActive)")
        peripheral.delegate = self
        print("[AidexSensor] didConnect: delegate set, calling onConnected()")
        onConnected()
        print("[AidexSensor] didConnect: onConnected() returned")
    }

    public func centralManager(_ central: CBCentralManager,
                                didDisconnectPeripheral peripheral: CBPeripheral,
                                error: Error?) {
        let reason = error?.localizedDescription ?? "normal"
        let errCode = (error as NSError?)?.code ?? 0
        print("[Aidex-DEBUG] ═══ DID_DISCONNECT: \(peripheral.name ?? "unnamed") reason=\(reason) errCode=\(errCode) pendingResetReconnect=\(pendingResetReconnect) shouldReconnect=\(shouldReconnect) clearStorageQuietWindowActive=\(clearStorageQuietWindowActive) pendingUnpair=\(pendingUnpairDisconnect) stop=\(stop)")
        connectionPhase = .disconnected
        isStreaming = false

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidexDidDisconnect(self, reason: reason)
        }

        // ---- POST-PROCESSING DISCONNECT ----

        if pendingResetReconnect {
            print("[AidexSensor] didDisconnectPeripheral pendingResetReconnect=true → handlePostResetDisconnect")
            handlePostResetDisconnect(peripheral: peripheral)
            return
        }

        if pendingUnpairDisconnect {
            print("[AidexSensor] didDisconnectPeripheral pendingUnpairDisconnect=true → reset")
            pendingUnpairDisconnect = false
            keyExchange.reset()
            shouldReconnect = false
            statusMessage = "Unpaired"
            return
        }

        if shouldReconnect {
            print("[AidexSensor] didDisconnectPeripheral shouldReconnect=true → scheduleReconnect")
            scheduleReconnect(status: errCode)
        } else {
            print("[AidexSensor] didDisconnectPeripheral shouldReconnect=false → NO reconnect")
        }
    }

    public func centralManager(_ central: CBCentralManager,
                                didFailToConnect peripheral: CBPeripheral,
                                error: Error?) {
        let code = (error as NSError?)?.code ?? 0
        print("[AidexSensor] didFailToConnect: \(peripheral.name ?? "unnamed") (\(peripheral.identifier)) error=\(error?.localizedDescription ?? "nil") code=\(code)")
        connectionPhase = .disconnected

        // CBError.Code 14 = Peer removed pairing information.
        // CBError.Code 1  = invalid parameters — CoreBluetooth returns this when
        //                     the bond no longer matches (post-reset / Forget This
        //                     Device) and the peripheral rejects the stale LTK.
        // Both mean the same thing after CLEAR_STORAGE: the sensor has deleted its
        // bonding keys and iOS still holds the old pairing. The link needs a fresh
        // SMP pairing, which is handled by handlePostResetDisconnect → clean re-scan.
        if (code == 14 || code == 1), postResetRescanActive {
            print("[AidexSensor] didFailToConnect: code \(code) after reset — bond stale, requesting re-pair")
            postResetRescanActive = false
            postResetFailCount += 1

            // After CLEAR_STORAGE the sensor has deleted its LTK, but iOS still
            // holds the old bond. CoreBluetooth returns code 1 on connect() because
            // the peripheral rejects the stale encryption. We retry a few times with
            // a fresh scan (which gives iOS a chance to detect the mismatch and
            // present the pairing dialog), but if it keeps failing the bond is
            // irretrievably broken — the user MUST forget the device in iOS Settings.
            if postResetFailCount > Self.maxPostResetFailures {
                print("[AidexSensor] didFailToConnect: exceeded maxPostResetFailures (\(Self.maxPostResetFailures)) — giving up, user must forget device in iOS Settings")
                shouldReconnect = false
                stop = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.statusMessage = "Forget device in iOS Settings"
                    self.delegate?.aidexNeedsPairing(self)
                }
                return
            }

            if code == 14 {
                // iOS may still think it is paired when it returns code 14 only.
                // Keep the reconnect path single-sourced: hand off to the post-reset
                // handler which does a clean scan + connect without auto-reconnect.
                shouldReconnect = false
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.statusMessage = "Pairing required — accept dialog"
                self.delegate?.aidexNeedsPairing(self)
            }
            // Re-arm a clean scan (no auto-reconnect) so iOS triggers a fresh SMP
            // security request from the sensor and presents the system dialog.
            let delay = Int(AidexTimeout.postResetReconnect)
            bleQueue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
                guard let self else { return }
                self.postResetRescanActive = true
                self.shouldReconnect = true
                self.keyExchange.reset()
                self.stop = false
                self.startScan()
            }
            return
        }

        if shouldReconnect {
            print("[AidexSensor] didFailToConnect shouldReconnect=true → scheduleReconnect")
            scheduleReconnect(status: code)
        } else {
            print("[AidexSensor] didFailToConnect shouldReconnect=false → NO reconnect")
        }
    }
}

// MARK: - Post-Reset Disconnect Handler

extension AidexSensor {

    /// Обработка disconnect после CLEAR_STORAGE (0xF3).
    ///
    /// Сенсор уже очистил всю внутреннюю память включая ключи спаривания.
    /// Старый BLE-бонд на iOS невалиден. Чтобы iOS заново выполнила SMP pairing,
    /// НЕ используем авто-переподключение при следующем connect.
    ///
    /// При записи в CCCD F001 (защищённая характеристика) iOS обнаружит, что
    /// сенсор отвергает старый LTK, и покажет системный диалог спаривания.
    /// После принятия пароля пользователем — свежий key exchange → streaming.
    /// При обнаружении all-zeros в CGM Session Start Time (0x2AAA) драйвер
    /// автоматически отправит SET_NEW_SENSOR (0x20) и начнёт warmup.
    func handlePostResetDisconnect(peripheral: CBPeripheral) {
        pendingResetReconnect = false
        clearStorageQuietWindowActive = false
        keyExchange.reset()
        shouldReconnect = true
        postResetRescanActive = true

        print("[Aidex-DEBUG] POST_RESET_DISCONNECT: \(peripheral.identifier.uuidString.prefix(8))... → \(AidexTimeout.postResetReconnect)ms пауза → fresh scan")

        // Drop the stale bond at the OS level so the next connect performs a clean
        // SMP pairing instead of reusing an invalid LTK. Cancel the connection is
        // already called by the disconnect handler; here we force a fresh retrieve.
        if let p = self.peripheral, p.identifier == peripheral.identifier {
            self.peripheral = nil
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusMessage = "Pairing required — accept dialog"
            self.delegate?.aidexNeedsPairing(self)
        }

        let delay = Int(AidexTimeout.postResetReconnect)
        bleQueue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            guard let self, self.shouldReconnect, self.postResetRescanActive else { return }
            self.stop = false
            self.startScan()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension AidexSensor: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("[AidexSensor] didDiscoverServices error=\(error?.localizedDescription ?? "nil") count=\(peripheral.services?.count ?? 0)")
        guard error == nil else { return }
        discoverCharacteristicsForServices()
    }

    public func peripheral(_ peripheral: CBPeripheral,
                            didDiscoverCharacteristicsFor service: CBService,
                            error: Error?) {
        print("[AidexSensor] didDiscoverCharacteristicsFor service=\(service.uuid.uuidString) error=\(error?.localizedDescription ?? "nil") chars=\(service.characteristics?.count ?? 0)")
        guard error == nil else { return }
        if service.uuid == CBUUID(string: AidexUUID.service) {
            print("[AidexSensor] didDiscoverCharacteristicsFor: calling onCharacteristicsDiscovered()")
            onCharacteristicsDiscovered()
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                            didUpdateNotificationStateFor characteristic: CBCharacteristic,
                            error: Error?) {
        let charName = characteristic.uuid.uuidString
        if let err = error as NSError? {
            let cbError = CBATTError.Code(rawValue: err.code)
            print("[AidexSensor] didUpdateNotificationStateFor \(charName) ERROR=\(err.code) \(err.localizedDescription)")
            if cbError == .insufficientAuthentication || err.code == CBATTError.Code.insufficientAuthentication.rawValue {
                // F001 (auth char) hit security wall before bonding — request pairing.
                if characteristic.uuid == CBUUID(string: AidexUUID.charF001) {
                    keyExchangePendingBond = true
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.delegate?.aidexNeedsPairing(self)
                    }
                }
                // Do NOT advance the CCCD chain on error for F001 — the auth gate
                // must succeed before key exchange. Just retry after a short settle.
                if characteristic.uuid == CBUUID(string: AidexUUID.charF001) {
                    bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.bondingSettle))) { [weak self] in
                        guard let self else { return }
                        // Re-attempt notify; once bonded this will succeed.
                        self.peripheral?.setNotifyValue(true, for: characteristic)
                    }
                    return
                }
                // For non-auth characteristics, fall through to normal advancement.
            } else {
                // A CCCD write to F003/F002 failed with a non-auth error — most
                // commonly during the post-bond re-registration, where iOS briefly
                // rejects the notify subscribe while the security level transitions.
                // Falling through here would silently drop the subscription and leave
                // the streaming path dead (the exact "no glucose data" bug). Re-issue
                // setNotifyValue once the link settles, and keep the retry budget
                // driven by startCCCDChain's timeout instead of advancing blindly.
                if characteristic.uuid == CBUUID(string: AidexUUID.charF003)
                    || characteristic.uuid == CBUUID(string: AidexUUID.charF002) {
                    bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.bondingSettle))) { [weak self] in
                        guard let self else { return }
                        self.peripheral?.setNotifyValue(true, for: characteristic)
                    }
                    return
                }
            }
        }

        let expected = cccdIndex < pendingCCCD.count ? pendingCCCD[cccdIndex].uuid.uuidString : "none"
        print("[AidexSensor] didUpdateNotificationStateFor \(charName) SUCCESS cccdIndex=\(cccdIndex)/\(pendingCCCD.count) expected=\(expected)")
        guard cccdIndex < pendingCCCD.count,
              pendingCCCD[cccdIndex] == characteristic else { return }

        // CCCD confirmed for this characteristic — clear the retry budget and advance.
        cccdRetryCount = 0
        cccdIndex += 1
        startCCCDChain()
    }

    public func peripheral(_ peripheral: CBPeripheral,
                            didUpdateValueFor characteristic: CBCharacteristic,
                            error: Error?) {
        guard error == nil, let data = characteristic.value else { return }

        switch characteristic.uuid {
        case CBUUID(string: AidexUUID.charF003):
            handleF003(data: data)

        case CBUUID(string: AidexUUID.charF002):
            // Distinguish BOND data (17 bytes during key exchange, from readValue)
            // from regular F002 notifications (command responses, streaming).
            //
            // The 17-byte BOND data arrives as the result of peripheral.readValue(for: f002),
            // which on iOS lands in didUpdateValueFor (same as notify). We track bondDataRead
            // to avoid misinterpreting a 17-byte F002 notify as BOND.
            if case .keyExchange = connectionPhase, data.count == 17, !bondDataRead, !keyExchange.isComplete {
                bondDataRead = true
                print("[AidexSensor] F002 BOND data (17 bytes, read response), decrypting...")
                if keyExchange.decryptBond(data) {
                    onKeyExchangeComplete()
                } else {
                    print("[AidexSensor] BOND decryption/CRC failed — reconnecting")
                    reconnect()
                }
            } else {
                handleF002(response: data)
            }

        case CBUUID(string: AidexUUID.charF001):
            // F001 notification delivers the 16-byte PAIR key (after challenge write).
            // Guard: challenge must be written, PAIR key not yet received, key exchange
            // not yet complete, and data must be at least 16 bytes.
            guard !keyExchange.isComplete, challengeWritten, keyExchange.pairKey == nil, data.count >= 16 else {
                print("[AidexSensor] F001 notify: wrong state — keComplete=\(keyExchange.isComplete) challengeWritten=\(challengeWritten) hasPairKey=\(keyExchange.pairKey != nil) len=\(data.count)")
                return
            }
            let pairKeyData = data.prefix(16)
            keyExchange.onPairKeyReceived(pairKeyData)
            print("[AidexSensor] PAIR key received (16 bytes)")

            // Read BOND data from F002 (17 bytes, encrypted). Force-unwrap is safe here
            // because onCharacteristicsDiscovered() must have run before we reach key exchange.
            guard let f2 = f002 else {
                print("[AidexSensor] F002 not discovered yet — cannot read BOND")
                return
            }
            peripheral.readValue(for: f2)

        case CBUUID(string: AidexUUID.charSessionStart):
            let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            let isZ = data.allSatisfy { $0 == 0x00 }
            print("[Aidex-DEBUG] ═══ 0x2AAA READ: \(hex) len=\(data.count) isAllZeros=\(isZ)")
            if !isZ, let st = AidexParser.parseLocalStartTimePayload(data) {
                let m = st.toEpochMs() ?? 0
                print("[Aidex-DEBUG]   parsed epochMs=\(m) date=\(Date(timeIntervalSince1970: Double(m)/1000))")
            }
            if let st = AidexParser.parseLocalStartTimePayload(data) {
                applySessionStartTime(st, source: "0x2AAA")
            }

        case CBUUID(string: AidexUUID.charModelNumber):
            if let s = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters.union(.whitespaces)) {
                modelName = s
            }

        case CBUUID(string: AidexUUID.charSoftwareRev):
            if let s = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters.union(.whitespaces)) {
                firmwareVersion = s
            }

        case CBUUID(string: AidexUUID.charManufacturer):
            break

        default:
            break
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        rssi = RSSI.intValue
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("[Aidex-DEBUG] ═══ DID_WRITE: char=\(characteristic.uuid.uuidString) error=\(error?.localizedDescription ?? "nil") clearStorageQuietWindowActive=\(clearStorageQuietWindowActive)")
        if let err = error as NSError? {
            let cb = CBATTError.Code(rawValue: err.code)
            print("[Aidex-DEBUG]   CBATTError=\(String(describing: cb)) rawCode=\(err.code)")
            // Challenge write to F001 hit insufficient-authentication (pre-bond) —
            // same handling as CCCD: surface pairing, retry once encrypted.
            if characteristic.uuid == CBUUID(string: AidexUUID.charF001),
               cb == .insufficientAuthentication {
                keyExchangePendingBond = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.aidexNeedsPairing(self)
                }
                // Clear the failed write flag; startKeyExchange will re-run once bonded.
                bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.bondingSettle))) { [weak self] in
                    guard let self, case .keyExchange = self.connectionPhase else { return }
                    self.challengeWritten = false
                    self.startKeyExchange()
                }
                return
            }
        }

        // Challenge successfully written to F001 — mark it.
        if characteristic.uuid == CBUUID(string: AidexUUID.charF001), case .keyExchange = connectionPhase {
            challengeWritten = true
        }
    }
}

// MARK: - Reset Logic

extension AidexSensor {

    /// Полный перезапуск сенсора через CLEAR_STORAGE (0xF3).
    ///
    /// **Сценарий:**
    /// ```
    /// 1. CLEAR_STORAGE (0xF3)  →  сенсор стирает память, калибровки, LTK
    /// 2. 12 с тишины            →  сенсор завершает внутреннюю очистку
    /// 3. disconnect             →  iOS теряет GATT, НО кеш bond остаётся
    /// 4. 5 с пауза              →  postResetRescanActive = true
    /// 5. fresh scan + connect   →  без авто-переподключения
    /// 6. CCCD F001 write        →  iOS видит reject → диалог спаривания
    /// 7. Пользователь accept    →  новый SMP обмен
    /// 8. key exchange            →  session key установлен
    /// 9. 0x2AAA = all-zeros     →  авто SET_NEW_SENSOR (0x20)
    /// 10. 7 мин warmup          →  первые показания
    /// ```
    func triggerReset() {
        guard let cmd = commandBuilder.clearStorage(), let f002 else { return }

        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // Полный сброс локального состояния.
        historyRawNextIndex = 0
        historyBriefNextIndex = 0
        liveOffsetCutoff = 0
        calibratedGlucoseCache.removeAll()
        calibrations.removeAll()
        hasAuthoritativeSessionStart = false
        sensorStartTimeMs = 0
        sensorReportedWearDays = false
        wearDays = 0
        lastOffsetMinutes = 0
        lastGlucoseTime = nil
        lastGlucose = nil
        sensorExpired = false
        cancelAllTimers()
        historyDownloading = false

        // Флаги перезапуска.
        pendingResetReconnect = true
        clearStorageQuietWindowActive = true
        needsPostResetActivation = true
        postResetRequestedAtMs = now
        autoActivationAttempted = false
        postResetFailCount = 0

        statusMessage = "Clearing sensor..."
        print("[Aidex-DEBUG] ══════════════════════════════════════════════")
        print("[Aidex-DEBUG] TRIGGER_RESET: sending CLEAR_STORAGE (0xF3) \(cmd.count) bytes withResponse")
        print("[Aidex-DEBUG]   postResetRequestedAtMs=\(now) f002=\(f002 != nil ? "OK" : "NIL") peripheral=\(peripheral != nil ? "OK" : "NIL")")

        // CLEAR_STORAGE is sent withoutResponse — F002 does NOT support
        // write-with-response (returns "Writing is not permitted" / CBATTError 3).
        // All F002 command writes use .withoutResponse, and CLEAR_STORAGE must
        // follow the same contract.
        peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)

        // 12 секунд тишины → disconnect.
        bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.clearStorageQuietWindow))) { [weak self] in
            guard let self, self.pendingResetReconnect else { return }
            print("[AidexSensor] triggerReset: quiet window expired, disconnecting for post-reset reconnect")
            self.clearStorageQuietWindowActive = false
            if let p = self.peripheral {
                self.centralManager.cancelPeripheralConnection(p)
            }
        }
    }

    func triggerUnpair() {
        guard let cmd = commandBuilder.deleteBond(), let f002 else { return }
        pendingUnpairDisconnect = true
        shouldReconnect = false
        // F002 does NOT support write-with-response — the sensor does not ACK
        // command writes to F002 and returns "Writing is not permitted" for
        // .withResponse. Use .withoutResponse like every other F002 command.
        peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
        statusMessage = "Unpairing..."
    }

    /// Активирует сенсор текущим временем (SET_NEW_SENSOR 0x20).
    /// Вызывается автоматически при all-zeros 0x2AAA после перезапуска,
    /// или вручную через `startNewSensor()`.
    func activateSensorNow() {
        autoActivationAttempted = true
        hasAuthoritativeSessionStart = false
        print("[Aidex-DEBUG] ACTIVATE_SENSOR_NOW: отправка SET_NEW_SENSOR (0x20) postResetRequestedAtMs=\(postResetRequestedAtMs)")

        let cal = Calendar.current
        let now = Date()
        let tz = cal.timeZone
        let qMs = 15 * 60 * 1000
        let tzQuarters = tz.secondsFromGMT() * 1000 / qMs
        let dstQuarters = tz.isDaylightSavingTime(for: now)
            ? (Int(tz.daylightSavingTimeOffset()) / qMs) : 0

        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)

        guard let cmd = commandBuilder.setNewSensor(
            year: c.year!, month: c.month!, day: c.day!,
            hour: c.hour!, minute: c.minute!, second: c.second!,
            tzQuarters: tzQuarters, dstQuarters: dstQuarters
        ), let f002 else { return }

        postResetRequestedAtMs = Int64(now.timeIntervalSince1970 * 1000)
        // SET_NEW_SENSOR must be written withoutResponse — same as other F002 commands.
        // The sensor does not ACK command writes to F002.
        peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
        statusMessage = "Warming up (7 min)..."
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, didActivateSensorAtMs: postResetRequestedAtMs)
        }
    }

    /// DELETE_BOND (0xF2) acknowledged — sensor erased its vendor pairing keys.
    /// The BLE link will drop shortly. After disconnect, update status and inform
    /// the UI that the user should "Forget This Device" in iOS Settings to complete
    /// the unpair (remove SMP-bond at OS level).
    func handleDeleteBondAck() {
        print("[AidexSensor] handleDeleteBondAck: sensor vendor bond erased")
        keyExchange.reset()
        pendingUnpairDisconnect = true
        shouldReconnect = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusMessage = "Unpaired — Forget in iOS Settings"
            self.delegate?.aidexNeedsPairing(self)
        }
    }

    func handleClearStorageAck() {
        clearStorageAckReceived = true
        print("[Aidex-DEBUG] CLEAR_STORAGE ACK: cенсор подтвердил приём 0xF3")
    }

    /// SET_NEW_SENSOR (0x20) acknowledged — mark activation complete.
    func handleNewSensorAck() {
        print("[AidexSensor] handleNewSensorAck: SET_NEW_SENSOR accepted")
        hasAuthoritativeSessionStart = true
        print("[Aidex-DEBUG] SET_NEW_SENSOR ACK: сенсор подтвердил активацию")
        if startupControlStage == .failed { startupControlStage = .idle }
    }

    /// SET_DYNAMIC_ADV_MODE (0x35) acknowledged — advance startup control to
    /// SET_AUTO_UPDATE_STATUS (0x34).
    func handleDynamicAdvModeAck() {
        print("[AidexSensor] handleDynamicAdvModeAck: dynamic adv mode enabled")
        guard startupControlStage == .waitDynamicAdvAck else { return }
        startupControlStage = .waitAutoUpdateAck
        if let cmd = commandBuilder.setAutoUpdateStatus(enabled: true), let f002 {
            print("[AidexSensor] handleDynamicAdvModeAck: writing setAutoUpdateStatus(true) to F002")
            peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
        } else {
            startupControlStage = .failed
        }
    }

    /// SET_AUTO_UPDATE_STATUS (0x34) acknowledged — startup control complete.
    /// Start polling connected broadcast (0x11) every 3s until F003 live streaming
    /// kicks in or the poll budget is exhausted.
    func handleAutoUpdateStatusAck() {
        print("[AidexSensor] handleAutoUpdateStatusAck: auto-update enabled")
        guard startupControlStage == .waitAutoUpdateAck else { return }
        startupControlStage = .complete
        // Startup control is complete — F003 live streaming should begin shortly.
        // Broadcast polling (0x11) is intentionally NOT used here because on GX-01S
        // constant 0x11 requests prevent the sensor from transitioning into F003 mode.
    }
}

// MARK: - Session Start Time

extension AidexSensor {

    func applySessionStartTime(_ st: LocalStartTime, source: String) {
        let ms = st.toEpochMs() ?? 0
        let date = ms > 0 ? Date(timeIntervalSince1970: Double(ms)/1000) : Date.distantPast
        print("[Aidex-DEBUG] ═══ APPLY_SESSION_START: source=\(source) epochMs=\(ms) date=\(date) isAllZeros=\(st.isAllZeros)")
        print("[Aidex-DEBUG]   needsPostResetActivation=\(needsPostResetActivation) autoActivationAttempted=\(autoActivationAttempted) postResetRequestedAtMs=\(postResetRequestedAtMs)")
        if st.isAllZeros {
            hasAuthoritativeSessionStart = false
            // All-zeros means the sensor has never been activated (new sensor) or
            // was reset via CLEAR_STORAGE. Auto-activate regardless of
            // needsPostResetActivation — new sensors need SET_NEW_SENSOR too.
            if !autoActivationAttempted {
                autoActivationAttempted = true
                needsPostResetActivation = false
                print("[AidexSensor] applySessionStartTime: 0x2AAA all-zeros, auto-activating sensor via SET_NEW_SENSOR")
                activateSensorNow()
                bleQueue.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                    guard let self, let c = self.cgmSessionStartChar else { return }
                    self.peripheral?.readValue(for: c)
                }
            }
            return
        }

        guard let startMs = st.toEpochMs(),
              startMs > 0,
              startMs < Int64(Date().timeIntervalSince1970 * 1000) + 86_400_000
        else { return }

        // Форсируем SET_NEW_SENSOR если время старта предшествует reset.
        if needsPostResetActivation, postResetRequestedAtMs > 0,
           startMs < postResetRequestedAtMs - 2 * 60_000 {
            needsPostResetActivation = false
            activateSensorNow()
            return
        }

        hasAuthoritativeSessionStart = true
        sensorStartTimeMs = startMs
        print("[AidexSensor] applySessionStartTime: SET sensorStartTimeMs=\(startMs) startDate=\(Date(timeIntervalSince1970: Double(startMs)/1000)) source=\(source)")
        // Update statusMessage with warmup state for user visibility
        let ws = warmupState
        statusMessage = "\(ws)"
        print("[Aidex-DEBUG]   warmupState=\(ws)")
        checkSensorExpiry()

        // Notify the upstream delegate (CGMAidexTransmitter) that the real
        // start time has been resolved. Without this, CGMAidexTransmitter has
        // no way to know the actual sensor activation time and reports a wrong
        // sensorAge (e.g. 336h for a fresh sensor).
        notifySensorStateChange()
    }

    /// Sends a didUpdateState snapshot to the delegate so CGMAidexTransmitter
    /// can pick up the latest sensorStartTimeMs, wearDays, and other metadata.
    private func notifySensorStateChange() {
        guard let delegate else { return }
        let snapshot = SensorSnapshot(
            serial: serial,
            displayName: serial,
            deviceAddress: config.peripheralIdentifier?.uuidString ?? "",
            uiFamily: .aidex,
            connectionStatus: "\(connectionPhase)",
            detailedStatus: statusMessage,
            subtitleStatus: "",
            startTimeMs: sensorStartTimeMs,
            officialEndMs: sensorStartTimeMs > 0 && wearDays > 0
                ? sensorStartTimeMs + Int64(wearDays) * 86_400_000 : 0,
            isActive: connectionPhase == .streaming,
            isVendorPaired: isVendorPaired,
            isVendorConnected: peripheral?.state == .connected,
            rssi: rssi,
            batteryMillivolts: batteryMV,
            isSensorExpired: sensorExpired,
            sensorRemainingHours: sensorStartTimeMs > 0 && wearDays > 0
                ? max(0, Int((sensorStartTimeMs + Int64(wearDays) * 86_400_000
                    - Int64(Date().timeIntervalSince1970 * 1000)) / 3_600_000))
                : 0,
            sensorAgeHours: sensorStartTimeMs > 0
                ? max(0, Int((Int64(Date().timeIntervalSince1970 * 1000) - sensorStartTimeMs) / 3_600_000))
                : 0,
            vendorFirmware: firmwareVersion,
            vendorHardware: hardwareVersion,
            vendorModel: modelName,
            calibrations: calibrations
        )
        DispatchQueue.main.async {
            delegate.aidex(self, didUpdateState: snapshot)
        }
    }

    func checkSensorExpiry() {
        guard sensorReportedWearDays, wearDays > 0, sensorStartTimeMs > 0 else { return }
        let expiryMs = sensorStartTimeMs + Int64(wearDays) * 86_400_000
        sensorExpired = Int64(Date().timeIntervalSince1970 * 1000) > expiryMs
    }
}

// MARK: - Timestamps / Reconnect

extension AidexSensor {

    func resolveTimestamp(now: Date, offsetMinutes: Int) -> Date {
        if sensorStartTimeMs > 0 {
            return Date(timeIntervalSince1970: Double(sensorStartTimeMs) / 1000 + Double(offsetMinutes) * 60)
        }
        return now
    }

    func scheduleReconnect(status: Int) {
        print("[AidexSensor] scheduleReconnect status=\(status) shouldReconnect=\(shouldReconnect) attempts=\(reconnectAttempts)")
        cancelAllTimers()

        let delay: Int
        switch status {
        case 5:   // GATT_INSUFFICIENT_AUTHENTICATION
            reconnectAttempts += 1
            delay = min(2000 * reconnectAttempts, 30_000)
        case 133: // CONNECTION_FAILED_ESTABLISHMENT
            consecutiveConnectFailures += 1
            delay = min(3000 * consecutiveConnectFailures, 30_000)
        default:
            reconnectAttempts += 1
            delay = min(1000 * reconnectAttempts, 30_000)
        }

        print("[AidexSensor] scheduleReconnect: will reconnect in \(delay)ms")

        bleQueue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            guard let self, self.shouldReconnect else {
                print("[AidexSensor] scheduleReconnect: SKIPPED shouldReconnect=\(self?.shouldReconnect ?? false)")
                return
            }
            print("[AidexSensor] scheduleReconnect: timeout fired, state=\(self.centralManager.state.rawValue), starting connectForce")
            self.connectForce()
        }
    }

    func reconnect() {
        guard let p = peripheral, shouldReconnect else { return }
        centralManager.cancelPeripheralConnection(p)
    }

    func cancelAllTimers() {
        keyExchangeWatchdog?.cancel()
        historyPageWatchdog?.cancel()
        initialHistoryRequestWork?.cancel()
    }

    func requestCalibrationPage(index: Int) {
        guard let cmd = commandBuilder.getCalibration(index: index), let f002 else { return }
        peripheral?.writeValue(cmd, for: f002, type: .withResponse)
    }
}
