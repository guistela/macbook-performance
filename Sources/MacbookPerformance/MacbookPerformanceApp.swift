import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?
    @ObservedObject var monitor = SystemMonitor()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Initialize menu bar
        menuBarManager = MenuBarManager(monitor: monitor)
        menuBarManager?.setupMenuBar()
        
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct MacbookPerformanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(monitor: appDelegate.monitor)
        }
        .windowStyle(.hiddenTitleBar) 
    }
}
