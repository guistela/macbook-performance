import SwiftUI
import AppKit

@MainActor
class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private let monitor: SystemMonitor
    
    init(monitor: SystemMonitor) {
        self.monitor = monitor
        super.init()
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "Performance")
            updateTitle()
        }
        
        setupMenu()
        
        // Update menu bar title periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTitle()
            }
        }
    }
    
    private func updateTitle() {
        guard let button = statusItem?.button else { return }
        
        let cpu = Int(monitor.cpuUsage)
        let temp = Int(monitor.cpuTemperature)
        let ram = Int(monitor.memoryUsage)
        let fan = monitor.fanSpeed
        let disk = monitor.diskReadSpeed.replacingOccurrences(of: " bytes/s", with: "B/s").replacingOccurrences(of: " KB/s", with: "K").replacingOccurrences(of: " MB/s", with: "M")
        
        // Compact Format: C:12% T:65° R:50% F:4k D:1.2M
        let fanK = fan >= 1000 ? "\(fan/1000)k" : "\(fan)"
        let title = "􀧓 \(cpu)%  􀇬 \(temp)°  􀤐 \(ram)%  􀜚 \(fanK)  􀤈 \(disk)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium)
        ]
        button.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show Dashboard", action: #selector(showDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        
        // Info items (disabled)
        let cpuItem = NSMenuItem(title: "CPU: \(Int(monitor.cpuUsage))%", action: nil, keyEquivalent: "")
        cpuItem.isEnabled = false
        menu.addItem(cpuItem)
        
        let tempItem = NSMenuItem(title: "Temp: \(Int(monitor.cpuTemperature))°C", action: nil, keyEquivalent: "")
        tempItem.isEnabled = false
        menu.addItem(tempItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Actions
        let turboItem = NSMenuItem(title: "Turbo Mode", action: #selector(toggleTurbo), keyEquivalent: "t")
        turboItem.state = monitor.isTurboModeByte ? .on : .off
        menu.addItem(turboItem)
        
        menu.addItem(NSMenuItem(title: "Purge Memory", action: #selector(purgeMemory), keyEquivalent: "p"))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // Update menu state when it opens
        menu.delegate = self
    }
    
    @objc func showDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func toggleTurbo() {
        monitor.toggleTurboMode()
    }
    
    @objc func purgeMemory() {
        let scriptSource = "do shell script \"purge\" with administrator privileges"
        let script = NSAppleScript(source: scriptSource)
        script?.executeAndReturnError(nil)
    }
}

extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update states before showing
        if let turboItem = menu.items.first(where: { $0.title == "Turbo Mode" }) {
            turboItem.state = monitor.isTurboModeByte ? .on : .off
        }
        
        if let cpuItem = menu.items.first(where: { $0.title.hasPrefix("CPU:") }) {
            cpuItem.title = "CPU Usage: \(Int(monitor.cpuUsage))%"
        }
        
        if let tempItem = menu.items.first(where: { $0.title.hasPrefix("Temp:") }) {
            tempItem.title = "Temperature: \(Int(monitor.cpuTemperature))°C"
        }
    }
}
