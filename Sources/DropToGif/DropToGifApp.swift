import AppKit
import SwiftUI

@main
struct DropToGifApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var queue = ConversionQueue()

    var body: some Scene {
        Window("Drop to GIF", id: "main") {
            ContentView(queue: queue)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
