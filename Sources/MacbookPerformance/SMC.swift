import Foundation
import IOKit

/// A robust wrapper for AppleSMC on Intel Macs.
/// Uses Manual byte mapping to avoid Swift struct alignment/padding issues.
class SMC {
    private var connection: io_connect_t = 0
    
    // Command Selectors
    static let KERNEL_INDEX_SMC: UInt32 = 2
    static let SMC_CMD_READ_BYTES: UInt8 = 5
    static let SMC_CMD_WRITE_BYTES: UInt8 = 6
    static let SMC_CMD_READ_KEYINFO: UInt8 = 9
    
    // Key Info Types
    static let TYPE_FPE2 = "fpe2" // Unsigned 14.2 fixed point
    static let TYPE_SP78 = "sp78" // Signed 7.8 fixed point
    static let TYPE_UI8  = "ui8 "
    static let TYPE_UI32 = "ui32"

    init() {
        _ = open()
    }

    deinit {
        _ = close()
    }

    func open() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service == 0 { return false }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        return result == kIOReturnSuccess
    }

    func close() -> Bool {
        if connection != 0 {
            let result = IOServiceClose(connection)
            connection = 0
            return result == kIOReturnSuccess
        }
        return true
    }

    private func makeFourCharCode(_ string: String) -> UInt32 {
        var res: UInt32 = 0
        for char in string.utf8 {
            res = (res << 8) | UInt32(char)
        }
        return res
    }
    
    /// Low-level call to SMC using raw bytes to ensure alignment.
    /// The structure expected by the kernel is exactly 80 bytes for Intel Macs.
    private func callSMC(input: Data) -> Data? {
        guard connection != 0 else { return nil }
        
        var inputBytes = [UInt8](input)
        if inputBytes.count < 80 {
            inputBytes.append(contentsOf: [UInt8](repeating: 0, count: 80 - inputBytes.count))
        }
        
        var outputBytes = [UInt8](repeating: 0, count: 80)
        var outputSize = 80
        
        let result = IOConnectCallStructMethod(connection, SMC.KERNEL_INDEX_SMC, &inputBytes, 80, &outputBytes, &outputSize)
        
        return result == kIOReturnSuccess ? Data(outputBytes) : nil
    }

    // MARK: - Temperature Reading
    
    func getCpuTemperature() -> Double? {
        let keys = ["TC0D", "TC0P", "TC0c", "TC0h", "TC0E", "TCGC", "TCAD"]
        for key in keys {
            if let val = readKey(key), val > 1 && val < 125 {
                return val
            }
        }
        return nil
    }

    // MARK: - Fan Control
    
    func getFanSpeed() -> Int? {
        // F0Ac is actual RPM for fan 0
        return readKey("F0Ac").map { Int($0) }
    }
    
    func setFanTurbo(_ enabled: Bool) {
        // F0Md: Fan mode. 0 = Auto, 1 = Manual.
        // F0Tg: Target RPM.
        
        if enabled {
            // Set to manual (1)
            writeKey("F0Md", value: 1)
            // Set to a high RPM (e.g. 6000)
            // We need to convert 6000 to fpe2 if that's the type
            writeKey("F0Tg", value: 6000) 
        } else {
            // Restore to Auto (0)
            writeKey("F0Md", value: 0)
        }
    }

    // MARK: - Key IO Logic
    
    private func readKey(_ key: String) -> Double? {
        let keyU32 = makeFourCharCode(key)
        
        // 1. Get Key Info
        var input = Data(repeating: 0, count: 80)
        input.replaceSubrange(0..<4, with: withUnsafeBytes(of: keyU32.bigEndian) { Data($0) })
        input[71] = SMC.SMC_CMD_READ_KEYINFO
        
        guard let output = callSMC(input: input) else { return nil }
        
        // Data size is at offset 24 (4 bytes)
        let dataSize = output.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self) }
        // Data type is at offset 28 (4 bytes)
        let dataTypeStr = String(data: output.subdata(in: 28..<32), encoding: .ascii) ?? ""

        if dataSize == 0 { return nil }
        
        // 2. Read Bytes
        var input2 = Data(repeating: 0, count: 80)
        input2.replaceSubrange(0..<4, with: withUnsafeBytes(of: keyU32.bigEndian) { Data($0) })
        input2[71] = SMC.SMC_CMD_READ_BYTES
        input2[24] = UInt8(dataSize & 0xFF) // Only need lowest byte usually
        
        guard let output2 = callSMC(input: input2) else { return nil }
        
        // Bytes are at offset 33 (32 bytes)
        let bytes = output2.subdata(in: 33..<33+Int(dataSize))
        
        return convertToDouble(bytes, type: dataTypeStr)
    }

    private func writeKey(_ key: String, value: Double) {
        // Writing is more complex as it requires knowing the exact type and data size.
        // For simplicity in this tool, we'll implement just enough for Fan controls.
        // This usually involves reading key info first.
        
        let keyU32 = makeFourCharCode(key)
        
        // Read info first
        var infoInput = Data(repeating: 0, count: 80)
        infoInput.replaceSubrange(0..<4, with: withUnsafeBytes(of: keyU32.bigEndian) { Data($0) })
        infoInput[71] = SMC.SMC_CMD_READ_KEYINFO
        guard let infoOutput = callSMC(input: infoInput) else { return }
        
        let dataSize = infoOutput.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self) }
        let dataTypeStr = String(data: infoOutput.subdata(in: 28..<32), encoding: .ascii) ?? ""
        
        if dataSize == 0 { return }
        
        // Convert double to bytes
        guard let dataToWrite = convertToBytes(value, type: dataTypeStr, size: Int(dataSize)) else { return }
        
        var writeInput = Data(repeating: 0, count: 80)
        writeInput.replaceSubrange(0..<4, with: withUnsafeBytes(of: keyU32.bigEndian) { Data($0) })
        writeInput[71] = SMC.SMC_CMD_WRITE_BYTES
        writeInput[24] = UInt8(dataSize & 0xFF)
        writeInput.replaceSubrange(33..<33+dataToWrite.count, with: dataToWrite)
        
        _ = callSMC(input: writeInput)
    }

    private func convertToDouble(_ data: Data, type: String) -> Double? {
        if type.hasPrefix("sp78") && data.count == 2 {
            // Signed 7.8 fixed point
            return Double(data[0]) + Double(data[1]) / 256.0
        } else if type.hasPrefix("fpe2") && data.count == 2 {
            // Unsigned 14.2 fixed point
            let val = UInt16(data[0]) << 8 | UInt16(data[1])
            return Double(val) / 4.0
        } else if type.hasPrefix("ui8") && data.count == 1 {
            return Double(data[0])
        } else if type.hasPrefix("ui16") && data.count == 2 {
            let val = UInt16(data[0]) << 8 | UInt16(data[1])
            return Double(val)
        }
        return nil
    }
    
    private func convertToBytes(_ value: Double, type: String, size: Int) -> Data? {
        if type.hasPrefix("ui8") {
            return Data([UInt8(clamping: Int(value))])
        } else if type.hasPrefix("fpe2") {
            let val = UInt16(value * 4.0)
            return Data([UInt8((val >> 8) & 0xFF), UInt8(val & 0xFF)])
        }
        return nil
    }
}
