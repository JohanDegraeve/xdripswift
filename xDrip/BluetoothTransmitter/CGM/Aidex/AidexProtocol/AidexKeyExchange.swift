import Foundation

/// Управление крипто-рукопожатием для одного соединения с сенсором AiDex.
///
/// Протокол:
/// 1. snSecret → F001 (challenge)
/// 2. F001 notify → PAIR key (16 байт)
/// 3. Read F002 → BOND data (17 байт)
/// 4. AES-CFB(pairKey, snIV) → session key (+ CRC-8 проверка)
/// 5. Post-BOND config в F001: AES-CFB([0x10, 0xC1, 0xF3], sessionKey, snIV)
final class AidexKeyExchange {
    let bareSerial: String
    let snSecret: Data          // 16 байт — F001 challenge
    let snIV: Data              // 16 байт — IV для всех шифров

    private(set) var pairKey: Data?
    private(set) var sessionKey: Data?

    var isComplete: Bool { sessionKey != nil }

    init(bareSerial: String) {
        self.bareSerial = bareSerial
        self.snSecret = SerialCrypto.deriveSecret(bareSerial)
        self.snIV = SerialCrypto.deriveIV(bareSerial)
    }

    /// Шаг 1: challenge для записи в F001.
    var challenge: Data { snSecret }

    /// Шаг 2: сохранить PAIR key из F001 notify.
    func onPairKeyReceived(_ data: Data) {
        pairKey = Data(data)
    }

    /// Шаг 4: дешифровать BOND данные (17 байт) в session key.
    func decryptBond(_ bondData: Data) -> Bool {
        guard let pk = pairKey else { return false }
        guard let sk = AESCFB.decryptBondData(bondData, pairKey: pk, iv: snIV) else { return false }
        sessionKey = sk
        return true
    }

    /// Шаг 5: получить зашифрованный post-BOND config.
    var postBondConfig: Data? {
        guard let sk = sessionKey else { return nil }
        let plaintext = Data([0x10, 0xC1, 0xF3])
        return AESCFB.encrypt(plaintext, key: sk, iv: snIV)
    }

    /// Зашифровать plaintext для F002-команды.
    func encrypt(_ plaintext: Data) -> Data? {
        guard let sk = sessionKey else { return nil }
        return AESCFB.encrypt(plaintext, key: sk, iv: snIV)
    }

    /// Дешифровать ответ F002 или F003.
    func decrypt(_ ciphertext: Data) -> Data? {
        guard let sk = sessionKey else { return nil }
        return AESCFB.decrypt(ciphertext, key: sk, iv: snIV)
    }

    /// Сброс для нового соединения.
    func reset() {
        pairKey = nil
        sessionKey = nil
    }
}