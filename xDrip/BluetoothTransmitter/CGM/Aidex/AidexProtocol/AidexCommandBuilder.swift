import Foundation

/// Построение зашифрованных F002-команд.
/// Каждая команда: opcode + params → CRC-16 → AES-128-CFB(sessionKey, SN IV).
final class AidexCommandBuilder {
    private let keyExchange: AidexKeyExchange

    init(keyExchange: AidexKeyExchange) {
        self.keyExchange = keyExchange
    }

    // MARK: - Core

    func buildEncrypted(opcode: UInt8, _ params: UInt8...) -> Data? {
        buildEncrypted(opcode: opcode, params: params)
    }

    func buildEncrypted(opcode: UInt8, params: [UInt8]) -> Data? {
        var plaintext = Data([opcode])
        plaintext.append(contentsOf: params)
        plaintext = CRC16.append(plaintext)
        return keyExchange.encrypt(plaintext)
    }

    func buildPlain(opcode: UInt8, _ params: UInt8...) -> Data {
        buildPlain(opcode: opcode, params: params)
    }

    func buildPlain(opcode: UInt8, params: [UInt8]) -> Data {
        var data = Data([opcode])
        data.append(contentsOf: params)
        return CRC16.append(data)
    }

    // MARK: - Convenience

    func getStartupDeviceInfo() -> Data? {
        buildEncrypted(opcode: AidexOpcode.getStartupDeviceInfo.rawValue)
    }

    func getBroadcastData() -> Data? {
        buildEncrypted(opcode: AidexOpcode.getBroadcastData.rawValue)
    }

    func getLegacyStartTime() -> Data? {
        buildEncrypted(opcode: AidexOpcode.getLocalStartTime.rawValue)
    }

    func getHistoryRange() -> Data? {
        buildEncrypted(opcode: AidexOpcode.getHistoryRange.rawValue)
    }

    func getHistoriesRaw(offset: Int) -> Data? {
        buildEncrypted(opcode: AidexOpcode.getHistoriesRaw.rawValue,
                       params: [UInt8(offset & 0xFF), UInt8((offset >> 8) & 0xFF)])
    }

    func getHistories(offset: Int) -> Data? {
        buildEncrypted(opcode: AidexOpcode.getHistories.rawValue,
                       params: [UInt8(offset & 0xFF), UInt8((offset >> 8) & 0xFF)])
    }

    func getCalibrationRange() -> Data? {
        buildEncrypted(opcode: AidexOpcode.getCalibrationRange.rawValue)
    }

    func getCalibration(index: Int) -> Data? {
        buildEncrypted(opcode: AidexOpcode.getCalibration.rawValue,
                       params: [UInt8(index & 0xFF), UInt8((index >> 8) & 0xFF)])
    }

    func getDefaultParam(startIndex: Int = 1) -> Data? {
        buildEncrypted(opcode: AidexOpcode.getDefaultParam.rawValue,
                       params: [UInt8(startIndex & 0xFF)])
    }

    /// SET_NEW_SENSOR (0x20) — активация сенсора.
    func setNewSensor(
        year: Int, month: Int, day: Int,
        hour: Int, minute: Int, second: Int,
        tzQuarters: Int, dstQuarters: Int
    ) -> Data? {
        buildEncrypted(opcode: AidexOpcode.setNewSensor.rawValue, params: [
            UInt8(year & 0xFF), UInt8((year >> 8) & 0xFF),
            UInt8(month), UInt8(day),
            UInt8(hour), UInt8(minute), UInt8(second),
            UInt8(tzQuarters & 0xFF), UInt8(dstQuarters & 0xFF)
        ])
    }

    /// SET_CALIBRATION (0x25) — отправка калибровочного значения.
    func setCalibration(offsetMinutes: Int, glucoseMgDl: Int) -> Data? {
        buildEncrypted(opcode: AidexOpcode.setCalibration.rawValue, params: [
            UInt8(offsetMinutes & 0xFF), UInt8((offsetMinutes >> 8) & 0xFF),
            UInt8(glucoseMgDl & 0xFF), UInt8((glucoseMgDl >> 8) & 0xFF)
        ])
    }

    func setAutoUpdateStatus(enabled: Bool = true) -> Data? {
        buildEncrypted(opcode: AidexOpcode.setAutoUpdateStatus.rawValue,
                       params: [enabled ? 0x01 : 0x00])
    }

    func setDynamicAdvMode(_ mode: UInt8) -> Data? {
        buildEncrypted(opcode: AidexOpcode.setDynamicAdvMode.rawValue, params: [mode])
    }

    func setDefaultParamChunk(totalWords: Int, startIndex: Int, payload: Data) -> Data? {
        var params = [UInt8(totalWords & 0xFF), UInt8(startIndex & 0xFF)]
        params.append(contentsOf: payload)
        return buildEncrypted(opcode: AidexOpcode.setDefaultParam.rawValue, params: params)
    }

    func deleteBond() -> Data? {
        buildEncrypted(opcode: AidexOpcode.deleteBond.rawValue)
    }

    func resetSensor() -> Data? {
        buildEncrypted(opcode: AidexOpcode.reset.rawValue)
    }

    func clearStorage() -> Data? {
        buildEncrypted(opcode: AidexOpcode.clearStorage.rawValue)
    }

    func shelfMode() -> Data? {
        buildEncrypted(opcode: AidexOpcode.shelfMode.rawValue)
    }

    func getSensorCheck(index: UInt8 = 1) -> Data? {
        buildEncrypted(opcode: AidexOpcode.getSensorCheck.rawValue, params: [index])
    }

    func getAutoUpdateStatus() -> Data? {
        buildEncrypted(opcode: AidexOpcode.getAutoUpdateStatus.rawValue)
    }
}