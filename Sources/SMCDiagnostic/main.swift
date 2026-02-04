import Foundation
import IOKit
import CSMC_T2

@main
struct SMCDiagnostic {
    static func main() {
        print("--------------------------------------------------")
        print("   SMC T2 Discovery Tool - Activity Mon +        ")
        print("--------------------------------------------------")

        var connection: io_connect_t = 0
        let result = CSMC_T2.open(&connection)

        if result != kIOReturnSuccess {
            print("[-] Failed to open SMC: \(result)")
            return
        }

        print("[+] SMC Connection Successful!")

        func testKey(_ keyStr: String, _ selector: UInt32) {
            print("\n[*] Testing key \(keyStr) on Selector \(selector)...")
            var input = [UInt8](repeating: 0, count: 80)
            
            // Key name to bytes
            let keyBytes = Array(keyStr.utf8)
            for i in 0..<min(4, keyBytes.count) {
                input[i] = keyBytes[i]
            }
            
            input[24] = 1 // size
            input[64] = 5 // command READ
            
            var output = [UInt8](repeating: 0, count: 80)
            var outputSize = 80
            
            let res = IOConnectCallStructMethod(connection, selector, &input, 80, &output, &outputSize)
            
            if res == 0 {
                print("[+] Success! Data: ", terminator: "")
                for i in 32..<40 {
                    print(String(format: "%02X ", output[i]), terminator: "")
                }
                print("")
            } else {
                print("[!] Failed with code: \(res)")
            }
        }

        // Test common fan keys
        testKey("F0Md", 1)
        testKey("F0Tg", 1)
        testKey("FS! ", 1)
        
        testKey("F0Md", 2)
        testKey("F0Tg", 2)
        testKey("FS! ", 2)

        CSMC_T2.close(connection)
        print("\nComplete.")
    }
}
