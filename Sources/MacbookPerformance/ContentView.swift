import SwiftUI
import Charts

struct ContentView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        TabView {
            MonitorView(monitor: monitor)
                .tabItem {
                    Label("Monitor", systemImage: "chart.xyaxis.line")
                }
            
            LauncherView()
                .tabItem {
                    Label("Launcher", systemImage: "app.dashed")
                }
            
            OptimizationView(monitor: monitor)
                .tabItem {
                    Label("Optimization", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
    }
}

struct MonitorView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        ScrollView {
            let columns = [
                GridItem(.adaptive(minimum: 350, maximum: .infinity), spacing: 20)
            ]
            
            LazyVGrid(columns: columns, spacing: 20) {
                MetricChart(title: "CPU Usage", value: monitor.cpuUsage, data: monitor.cpuHistory, topApps: monitor.topCPUApps)
                MetricChart(title: "Memory Usage", value: monitor.memoryUsage, data: monitor.memoryHistory, topApps: monitor.topMemoryApps)
                MetricChart(title: "GPU Usage", value: monitor.gpuUsage, data: monitor.gpuHistory)
                MetricChart(title: "CPU Temperature", value: monitor.cpuTemperature, data: monitor.cpuTempHistory, unit: "°C", maxValue: 110)
                
                if monitor.fanSpeeds.isEmpty {
                     MetricChart(title: "Fan Speed", value: 0, data: [], unit: " RPM", maxValue: 7000)
                } else {
                    ForEach(Array(monitor.fanSpeeds.enumerated()), id: \.offset) { index, speed in
                        MetricChart(title: "Fan \(index + 1) Speed", value: Double(speed), data: [], unit: " RPM", maxValue: 7000)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Disk I/O")
                        .font(.headline)
                    HStack {
                        DiskChart(title: "Read", currentSpeed: monitor.diskReadSpeed, data: monitor.diskReadHistory)
                        DiskChart(title: "Write", currentSpeed: monitor.diskWriteSpeed, data: monitor.diskWriteHistory)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding()
        }
    }
}


struct MetricChart: View {
    let title: String
    let value: Double
    let data: [MetricPoint]
    var unit: String = "%"
    var maxValue: Double = 100
    var topApps: [(String, Double)] = []
    
    var statusColor: Color {
        if unit == "°C" {
            switch value {
            case 0..<75: return .green
            case 75..<90: return .yellow
            default: return .red
            }
        } else {
            switch value {
            case 0..<60: return .green
            case 60..<85: return .yellow
            default: return .red
            }
        }
    }
    
    var statusText: String {
        if unit == "°C" {
            switch value {
            case 0..<75: return "OK"
            case 75..<90: return "WARM"
            default: return "HOT"
            }
        } else {
            switch value {
            case 0..<60: return "OK"
            case 60..<85: return "MED"
            default: return "BAD"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
                
                if unit == " RPM" {
                    Text("\(Int(value))\(unit)")
                        .font(.title2)
                        .monospacedDigit()
                } else {
                    Text(unit == "°C" ? String(format: "%.1f%@", value, unit) : "\(Int(value))\(unit)")
                        .font(.title2)
                        .monospacedDigit()
                }
            }
            
            Chart(data) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(statusColor)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(LinearGradient(colors: [statusColor.opacity(0.5), statusColor.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...maxValue)
            .chartXAxis(.hidden)
            .opacity(data.isEmpty ? 0 : 1) // Hide chart if no data (e.g. for Fan Speed)
            .frame(height: data.isEmpty ? 0 : 100)
            
            if !topApps.isEmpty {
                Divider()
                VStack(spacing: 4) {
                    ForEach(topApps, id: \.0) { app in
                        HStack {
                            Text(app.0)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", app.1))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}


struct DiskChart: View {
    let title: String
    let currentSpeed: String
    let data: [MetricPoint]
    
    var latestValue: Double {
        data.last?.value ?? 0
    }
    
    var statusColor: Color {
        let mb = latestValue / 1_048_576 // Bytes to MB
        switch mb {
        case 0..<10: return .green
        case 10..<100: return .yellow
        default: return .red
        }
    }
    
    var statusText: String {
        let mb = latestValue / 1_048_576
        switch mb {
        case 0..<10: return "OK"
        case 10..<100: return "MED"
        default: return "BAD"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(title): \(currentSpeed)")
                    .font(.subheadline)
                    .monospacedDigit()
                
                Spacer()
                
                Text(statusText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(3)
            }
            
            Chart(data) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Speed", point.value)
                )
                .foregroundStyle(statusColor)
                .interpolationMethod(.monotone)
                
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Speed", point.value)
                )
                .foregroundStyle(LinearGradient(colors: [statusColor.opacity(0.5), statusColor.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 60)
        }
    }
}

struct LauncherView: View {
    @StateObject private var launcher = ProcessLauncher()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Activity Mon + Launcher")
                .font(.title)
            
            if let app = launcher.selectedApp {
                HStack(spacing: 20) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                    
                    VStack(alignment: .leading) {
                        Text(app.name)
                            .font(.headline)
                        
                        if app.supportsAutoGraphicsSwitching {
                            Text("Prefers Integrated GPU (Auto Switch Enabled)")
                                .foregroundColor(.orange)
                        } else {
                            Text("Prefers Dedicated GPU (High Performance)")
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                
                Button("Launch Application") {
                    launcher.launchSelectedApp()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                
            } else {
                Text("Select an application to inspect its GPU preference and launch it.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Button("Select Application...") {
                launcher.selectApp()
            }
            
            if !launcher.launchMessage.isEmpty {
                Text(launcher.launchMessage)
                    .foregroundColor(launcher.isError ? .red : .green)
                    .padding()
            }
        }
        .padding()
    }
}

struct OptimizationView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Activity Mon + Optimization")
                    .font(.title)
                
                GroupBox(label: Label("Graphics Switching", systemImage: "display")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Control global graphics switching behavior. Use with caution.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button("Force Dedicated GPU") {
                                runPmset(arg: "1")
                            }
                            .help("Disables automatic switching. Forces high performance.")
                            
                            Button("Reset (Auto Switch)") {
                                runPmset(arg: "2")
                            }
                            .help("Restores default automatic graphics switching.")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
                
                GroupBox(label: Label("Maintenance", systemImage: "hammer")) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Button(action: purgeMemory) {
                                Label("Purge Inactive Memory", systemImage: "memorychip")
                            }
                            .frame(maxWidth: .infinity)
                            
                            Button(action: cleanDerivedData) {
                                Label("Clean Xcode Derived Data", systemImage: "trash")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
                
                GroupBox(label: Label("Thermal & Performance Management", systemImage: "thermometer.sun")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Enabling Performance Boost allows the i9 to use its full Turbo frequency. Disabling it (Low Power) significantly reduces heat.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("CPU Performance Boost (Turbo)")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { monitor.isTurboModeByte },
                                set: { _ in monitor.toggleTurboMode() }
                            ))
                            .toggleStyle(.switch)
                        }
                    }
                    .padding()
                }
                
                Text("Note: 'Force Dedicated GPU', 'Thermal Controls' and 'Purge Memory' require Admin privileges (sudo) and may verify via Terminal or prompt.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .alert("Optimization", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func runPmset(arg: String) {
        // Run on background to avoid blocking. Create NSAppleScript INSIDE the block to avoid capturing non-Sendable types.
        let scriptSource = "do shell script \"pmset -a gpuswitch \(arg)\" with administrator privileges"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = NSAppleScript(source: scriptSource)
            var errorDict: NSDictionary?
            let success = task?.executeAndReturnError(&errorDict) != nil
            let errorMessage = errorDict?.description
            
            DispatchQueue.main.async {
                if success {
                    self.alertMessage = "Graphics mode updated successfully."
                } else {
                    self.alertMessage = "Failed to set graphics mode: \(errorMessage ?? "Unknown error")"
                }
                self.showingAlert = true
            }
        }
    }
    
    func purgeMemory() {
        let scriptSource = "do shell script \"purge\" with administrator privileges"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = NSAppleScript(source: scriptSource)
            var errorDict: NSDictionary?
            let success = task?.executeAndReturnError(&errorDict) != nil
            let errorMessage = errorDict?.description
            
            DispatchQueue.main.async {
                if success {
                    self.alertMessage = "Memory purged successfully."
                } else {
                    self.alertMessage = "Error running purge: \(errorMessage ?? "Unknown error")"
                }
                self.showingAlert = true
            }
        }
    }
    
    func cleanDerivedData() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let derivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        
        do {
            if FileManager.default.fileExists(atPath: derivedData.path) {
                try FileManager.default.removeItem(at: derivedData)
                alertMessage = "Derived Data cleaned successfully."
            } else {
                alertMessage = "No Derived Data found."
            }
        } catch {
            alertMessage = "Error cleaning Derived Data: \(error.localizedDescription)"
        }
        showingAlert = true
    }
}
