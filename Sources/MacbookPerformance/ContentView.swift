import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var monitor = SystemMonitor()
    
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
            
            OptimizationView()
                .tabItem {
                    Label("Optimization", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct MonitorView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MetricChart(title: "CPU Usage", value: monitor.cpuUsage, data: monitor.cpuHistory)
                MetricChart(title: "Memory Usage", value: monitor.memoryUsage, data: monitor.memoryHistory)
                
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
                
                MetricChart(title: "GPU Usage", value: monitor.gpuUsage, data: monitor.gpuHistory)
            }
            .padding()
        }
    }
}

// ... MetricChart ...

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
            Text("App Launcher")
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
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("System Optimization")
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
                
                Text("Note: 'Force Dedicated GPU' and 'Purge Memory' require Admin privileges (sudo) and may verify via Terminal or prompt.")
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
        // sudo pmset -a gpuswitch <arg>
        // 0 = Force Integrated
        // 1 = Force Dedicated
        // 2 = Auto
        
        let script = "do shell script \"pmset -a gpuswitch \(arg)\" with administrator privileges"
        let task = NSAppleScript(source: script)
        var error: NSDictionary?
        
        DispatchQueue.global(qos: .userInitiated).async {
            task?.executeAndReturnError(&error)
            
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = "Failed to set graphics mode: \(error)"
                } else {
                    alertMessage = "Graphics mode updated successfully."
                }
                showingAlert = true
            }
        }
    }
    
    func purgeMemory() {
        // Using AppleScript to request privileges for purge if needed, or just try run
        // 'purge' usually requires root.
        let script = "do shell script \"purge\" with administrator privileges"
        let task = NSAppleScript(source: script)
        var error: NSDictionary?
        
        DispatchQueue.global(qos: .userInitiated).async {
            task?.executeAndReturnError(&error)
            
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = "Error running purge: \(error)"
                } else {
                    alertMessage = "Memory purged successfully."
                }
                showingAlert = true
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
