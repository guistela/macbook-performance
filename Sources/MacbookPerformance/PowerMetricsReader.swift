import Foundation

public class PowerMetricsReader {
    public struct ThermalData {
        public let cpuTemp: Double
        public let fanSpeeds: [Int]
        public let gpuTemp: Double?
    }

    public static func read() -> ThermalData? {
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["/usr/bin/powermetrics", "-n", "1", "--samplers", "smc"]

        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            let parsed = parse(output)
            return parsed
        } catch {
            return nil
        }
    }

    private static func parse(_ output: String) -> ThermalData? {
        var cpuTemp: Double = 0
        var fanSpeeds: [Int] = []
        var gpuTemp: Double? = nil

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("CPU die temperature:") {
                let parts = line.split(separator: ":")
                if parts.count > 1 {
                    let valStr = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " C", with: "")
                    cpuTemp = Double(valStr) ?? 0
                }
            } else if line.contains("Fan:") || line.trimmingCharacters(in: .whitespaces).hasPrefix("Fan") {
                // Handle "Fan: 1234 rpm" or "Fan 0: 1234 rpm"
                let parts = line.split(separator: ":")
                if parts.count > 1 {
                    let valStr = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " rpm", with: "")
                    if let speed = Int(Double(valStr) ?? 0) as Int? {
                        fanSpeeds.append(speed)
                    }
                }
            } else if line.contains("GPU die temperature:") {
                let parts = line.split(separator: ":")
                if parts.count > 1 {
                    let valStr = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " C", with: "")
                    gpuTemp = Double(valStr)
                }
            }
        }

        if cpuTemp > 0 {
            return ThermalData(cpuTemp: cpuTemp, fanSpeeds: fanSpeeds, gpuTemp: gpuTemp)
        }
        return nil
    }
}
