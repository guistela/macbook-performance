import Foundation
import Combine
import Darwin
import IOKit

struct MetricPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

@MainActor
class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var memoryUsed: String = ""
    @Published var memoryTotal: String = ""
    @Published var diskReadSpeed: String = "0 B/s"
    @Published var diskWriteSpeed: String = "0 B/s"
    @Published var gpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var fanSpeed: Int = 0
    @Published var isTurboModeByte: Bool = false // Tracks if manual mode is on
    
    // History for Charts
    @Published var cpuHistory: [MetricPoint] = []
    @Published var memoryHistory: [MetricPoint] = []
    @Published var diskReadHistory: [MetricPoint] = []
    @Published var diskWriteHistory: [MetricPoint] = []
    @Published var gpuHistory: [MetricPoint] = []
    @Published var cpuTempHistory: [MetricPoint] = []
    
    private let maxHistoryPoints = 60
    private var timer: Timer?
    
    // Previous CPU info for calculation
    private var previousInfo = host_cpu_load_info()
    
    // Disk I/O Tracking
    private var previousDiskRead: UInt64 = 0
    private var previousDiskWrite: UInt64 = 0
    private var lastDiskCheckTime: TimeInterval = 0
    
    private let smc = SMC()
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // Initial fetch
        updateCPUUsage()
        updateMemoryUsage()
        updateDiskIO()
        updateGPUUsage()
        updateCPUTemperature()
        updateFanSpeed()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCPUUsage()
                self?.updateMemoryUsage()
                self?.updateDiskIO()
                self?.updateGPUUsage()
                self?.updateCPUTemperature()
                self?.updateFanSpeed()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func addToHistory(_ history: inout [MetricPoint], value: Double) {
        let now = Date()
        history.append(MetricPoint(date: now, value: value))
        if history.count > maxHistoryPoints {
            history.removeFirst()
        }
    }
    
    private func updateCPUUsage() {
        var count: mach_msg_type_number_t = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
        var info = host_cpu_load_info()
        
        // Get host port
        let hostPort = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let userDiff = Double(info.cpu_ticks.0 - previousInfo.cpu_ticks.0)
            let sysDiff = Double(info.cpu_ticks.1 - previousInfo.cpu_ticks.1)
            let idleDiff = Double(info.cpu_ticks.2 - previousInfo.cpu_ticks.2)
            let niceDiff = Double(info.cpu_ticks.3 - previousInfo.cpu_ticks.3)
            
            let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
            
            if totalTicks > 0 {
                let usage = (userDiff + sysDiff + niceDiff) / totalTicks
                let usagePercent = usage * 100.0
                DispatchQueue.main.async {
                    self.cpuUsage = usagePercent
                    self.addToHistory(&self.cpuHistory, value: usagePercent)
                }
            }
            
            previousInfo = info
        }
    }
    
    private func updateMemoryUsage() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            // Use sysconf to safely get page size in Swift 6 concurrency context
            let pageSize = UInt64(sysconf(_SC_PAGESIZE))
            // Approximate "App Memory" + "Wired Memory" which is roughly what users think of as "Used"
            // macOS memory accounting is complex (active, inactive, wired, speculative, compressed...)
            // A simple approximation: Active + Wired
            let active = UInt64(stats.active_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let used = active + wired
            
            let total = ProcessInfo.processInfo.physicalMemory
            let percent = Double(used) / Double(total) * 100.0
            
            let usedFormatter = ByteCountFormatter()
            usedFormatter.countStyle = .memory
            let usedStr = usedFormatter.string(fromByteCount: Int64(used))
            
            let totalFormatter = ByteCountFormatter()
            totalFormatter.countStyle = .memory
            let totalStr = totalFormatter.string(fromByteCount: Int64(total))
            
            DispatchQueue.main.async {
                self.memoryUsage = percent
                self.memoryUsed = usedStr
                self.memoryTotal = totalStr
                self.addToHistory(&self.memoryHistory, value: percent)
            }
        }
    }
    
    private func updateDiskIO() {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOBlockStorageDriver")
        
        // kIOMainPortDefault is the modern replacement for kIOMasterPortDefault (deprecated)
        // However, kIOMainPortDefault is available macOS 12+. If we target older, we might need #available.
        // Package.swift says .macOS(.v13), so kIOMainPortDefault is safe.
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        
        if result == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess {
                    if let properties = props?.takeRetainedValue() as? [String: Any] {
                        if let statistics = properties["Statistics"] as? [String: Any] {
                            if let read = statistics["Bytes (Read)"] as? Int64 {
                                totalRead += UInt64(read)
                            }
                            if let write = statistics["Bytes (Write)"] as? Int64 {
                                totalWrite += UInt64(write)
                            }
                        }
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        
        let currentTime = Date().timeIntervalSince1970
        let timeDiff = currentTime - lastDiskCheckTime
        
        if lastDiskCheckTime > 0 && timeDiff > 0 {
            let readDiff = totalRead > previousDiskRead ? totalRead - previousDiskRead : 0
            let writeDiff = totalWrite > previousDiskWrite ? totalWrite - previousDiskWrite : 0
            
            let readSpeed = Double(readDiff) / timeDiff
            let writeSpeed = Double(writeDiff) / timeDiff
            
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
            
            DispatchQueue.main.async {
                self.diskReadSpeed = formatter.string(fromByteCount: Int64(readSpeed)) + "/s"
                self.diskWriteSpeed = formatter.string(fromByteCount: Int64(writeSpeed)) + "/s"
                
                // Store in MB/s for chart readability, or raw bytes? 
                // Let's store raw bytes and format in Chart.
                self.addToHistory(&self.diskReadHistory, value: readSpeed)
                self.addToHistory(&self.diskWriteHistory, value: writeSpeed)
            }
        }
        
        previousDiskRead = totalRead
        previousDiskWrite = totalWrite
        lastDiskCheckTime = currentTime
    }
    
    private func updateGPUUsage() {
        // GPU Usage logic is tricky on macOS across different architectures.
        // We will try to find IOAccelerator services and look for PerformanceStatistics.
        
        var iterator: io_iterator_t = 0
        // "IOAccelerator" is the general class for GPUs
        let matchDict = IOServiceMatching("IOAccelerator")
        
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        
        var maxUsage: Double = 0.0
        
        if result == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess {
                    if let properties = props?.takeRetainedValue() as? [String: Any] {
                        // Attempt to find utilization in PerformanceStatistics
                        if let perfStats = properties["PerformanceStatistics"] as? [String: Any] {
                            // Common key for utilization is "Device Utilization %" or similar
                            // It might be an integer 0-100 or something else.
                            // On Apple Silicon, it might be different, but let's try standard keys.
                            
                            if let utilization = perfStats["Device Utilization %"] as? Int {
                                maxUsage = max(maxUsage, Double(utilization))
                            } else if let utilization = perfStats["GPU Activity"] as? Int {
                                 // Some drivers might use this
                                maxUsage = max(maxUsage, Double(utilization))

                            }
                        }
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        
        DispatchQueue.main.async {
            self.gpuUsage = maxUsage
            self.addToHistory(&self.gpuHistory, value: maxUsage)
        }
    }
    
    private func updateCPUTemperature() {
        if let temp = smc.getCpuTemperature() {
            DispatchQueue.main.async {
                self.cpuTemperature = temp
                self.addToHistory(&self.cpuTempHistory, value: temp)
            }
        }
    }
    
    private func updateFanSpeed() {
        if let speed = smc.getFanSpeed() {
            DispatchQueue.main.async {
                self.fanSpeed = speed
            }
        }
    }
    
    @MainActor
    func toggleTurboMode() {
        isTurboModeByte.toggle()
        smc.setFanTurbo(isTurboModeByte)
    }
    
    deinit {
        // Timer is destroyed automatically as it's not strongly held if we invalidate it.
        // But since we can't touch it here safely, we rely on the fact that the closure captures 'self' weakly.
        // So when 'self' is deallocated, the timer closure will just do nothing (or we can invalidate it in stopMonitoring which usually should be called).
    }
}

// Constants if not available directly
let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
