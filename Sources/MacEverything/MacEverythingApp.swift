import AppKit
import SwiftUI

@main
@MainActor
struct MacEverythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup("MacEverything", id: "search") {
            ContentView(model: model)
        }
        .defaultSize(width: 920, height: 620)
        .windowResizability(.contentMinSize)
        .commands {
            MacEverythingCommands(model: model)
        }

        MenuBarExtra("MacEverything", systemImage: "magnifyingglass.circle.fill") {
            Button("显示搜索窗口") {
                AppDelegate.showSearchWindow()
            }
            .keyboardShortcut("f")

            Divider()

            Text(model.statusText)
            Button("重建索引") {
                model.rebuildIndex()
            }
            Button("完全磁盘访问设置") {
                model.openFullDiskAccessSettings()
            }
            Button("检查更新") {
                model.openLatestReleasePage()
            }

            Divider()

            Button("退出 MacEverything") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        globalHotKey = GlobalHotKey {
            Task { @MainActor in
                AppDelegate.showSearchWindow()
            }
        }
        let registeredShortcut = globalHotKey?.registerFirstAvailable()
        let shortcutLabel = registeredShortcut ?? "未注册"
        AppModel.shared.hotKeyDisplay = shortcutLabel
        UserDefaults.standard.set(shortcutLabel, forKey: "activeHotKey")
        AppModel.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static var fallbackWindow: NSWindow?

    static func showSearchWindow() {
        NSApp.activate(ignoringOtherApps: true)

        let existingWindow = NSApp.windows.first {
            $0.canBecomeMain && !($0 is NSPanel) && $0.title == "MacEverything"
        }

        let window: NSWindow
        if let existingWindow {
            window = existingWindow
        } else if let fallbackWindow {
            window = fallbackWindow
        } else {
            let controller = NSHostingController(rootView: ContentView(model: AppModel.shared))
            let newWindow = NSWindow(contentViewController: controller)
            newWindow.title = "MacEverything"
            newWindow.setContentSize(NSSize(width: 920, height: 620))
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            fallbackWindow = newWindow
            window = newWindow
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NotificationCenter.default.post(name: .focusMacEverythingSearch, object: nil)
    }
}

struct MacEverythingCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("打开所选项目") {
                model.openSelected()
            }
            .keyboardShortcut(.return, modifiers: [])

            Button("在 Finder 中显示") {
                model.revealSelected()
            }
            .keyboardShortcut(.return, modifiers: [.command])

            Button("快速预览") {
                model.previewSelected()
            }
            .keyboardShortcut("y", modifiers: [.command])

            Button("复制路径") {
                model.copySelectedPath()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }

        CommandMenu("索引") {
            Button("重建索引") {
                model.rebuildIndex()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("完全磁盘访问设置") {
                model.openFullDiskAccessSettings()
            }

            Divider()

            Button("检查更新") {
                model.openLatestReleasePage()
            }
        }
    }
}
