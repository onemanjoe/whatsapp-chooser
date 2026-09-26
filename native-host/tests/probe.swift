import AppKit

// Stand-in app for the host tests. It writes every URL it is opened with to
// received.txt, next to its own bundle, and quits after a few idle seconds.
// It declares no URL schemes on purpose: the host always names the app with
// `open -a`, so the target app does not have to claim the scheme.
final class Probe: NSObject, NSApplicationDelegate {
    private var quit: DispatchWorkItem?
    private let out = Bundle.main.bundleURL.deletingLastPathComponent()
        .appendingPathComponent("received.txt")

    func applicationDidFinishLaunching(_ notification: Notification) { armQuit() }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let line = Data((url.absoluteString + "\n").utf8)
            if let handle = try? FileHandle(forWritingTo: out) {
                handle.seekToEndOfFile()
                handle.write(line)
                handle.closeFile()
            } else {
                try? line.write(to: out)
            }
        }
        armQuit()
    }

    private func armQuit() {
        quit?.cancel()
        let work = DispatchWorkItem { NSApp.terminate(nil) }
        quit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}

let app = NSApplication.shared
let probe = Probe()
app.delegate = probe
app.run()
