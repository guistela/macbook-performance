import SwiftUI
import AppKit

struct LauncherApp: Identifiable {
    let id = UUID()
    let name: String
    let icon: NSImage
    let url: URL
    let supportsAutoGraphicsSwitching: Bool
}

@MainActor
class ProcessLauncher: ObservableObject {
    @Published var selectedApp: LauncherApp?
    @Published var launchMessage: String = ""
    @Published var isError: Bool = false
    
    func selectApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.inspectApp(at: url)
            }
        }
    }
    
    private func inspectApp(at url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        
        // Run IO on background task to avoid blocking main thread, 
        // but since we are MainActor, we must be careful.
        // Actually, reading a plist is fast, but let's be correct.
        
        Task.detached {
            var supportsAutoSwitching = false
            
            // Inspect Info.plist
            let plistURL = url.appendingPathComponent("Contents/Info.plist")
            if let plistData = try? Data(contentsOf: plistURL),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                
                // Key: NSSupportsAutomaticGraphicsSwitching
                if let value = plist["NSSupportsAutomaticGraphicsSwitching"] as? Bool {
                    supportsAutoSwitching = value
                }
            }
            
            let app = LauncherApp(
                name: name,
                icon: icon,
                url: url,
                supportsAutoGraphicsSwitching: supportsAutoSwitching
            )
            
            await MainActor.run { [weak self] in
                self?.selectedApp = app
                self?.launchMessage = ""
            }
        }
    }
    
    func launchSelectedApp() {
        guard let app = selectedApp else { return }
        
        let workspace = NSWorkspace.shared
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        workspace.openApplication(at: app.url, configuration: config) { [weak self] runningApp, error in
            Task { @MainActor in
                if let error = error {
                    self?.launchMessage = "Failed to launch: \(error.localizedDescription)"
                    self?.isError = true
                } else {
                    self?.launchMessage = "Launched \(app.name) successfully."
                    self?.isError = false
                }
            }
        }
    }
}
