import AppKit
import TeleprompterCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusMenu: StatusMenuController!
    private var autoTest: AutoTest?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = LaunchArguments(ProcessInfo.processInfo.arguments)
        let store = Store(directory: args.dataDirectory ?? Store.defaultDirectory)
        model = AppModel(store: store)
        statusMenu = StatusMenuController(model: model)
        MainMenuBuilder.install(model: model)

        model.start()

        if let output = args.autoTestOutput {
            autoTest = AutoTest(model: model, output: output, quitWhenDone: args.quitAfterTest)
            if let front = args.frontApp { autoTest?.frontAppBundleID = front }
            autoTest?.snapshotDirectory = args.snapshotDirectory
            autoTest?.run()
        } else {
            model.windows.showEditor()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.windows.showEditor()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        model.prepareForTermination()
    }
}

/// Argumentos de linha de comando usados apenas para testes automatizados.
struct LaunchArguments {
    var dataDirectory: URL?
    var autoTestOutput: URL?
    var quitAfterTest = true
    var frontApp: String?
    var snapshotDirectory: URL?

    init(_ args: [String]) {
        var it = args.dropFirst().makeIterator()
        while let a = it.next() {
            switch a {
            case "--data-dir": if let p = it.next() { dataDirectory = URL(fileURLWithPath: p) }
            case "--autotest": if let p = it.next() { autoTestOutput = URL(fileURLWithPath: p) }
            case "--keep-running": quitAfterTest = false
            case "--front-app": frontApp = it.next()
            case "--snapshots": if let p = it.next() { snapshotDirectory = URL(fileURLWithPath: p) }
            default: break
            }
        }
    }
}
