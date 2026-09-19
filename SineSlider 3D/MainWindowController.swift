import AppKit

final class MainWindowController: NSWindowController {
    convenience init() {
        let contentViewController = MainViewController()
        let contentSize = contentViewController.view.fittingSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.init(window: window)

        window.title = "SineSlider 3D"
        window.contentViewController = contentViewController
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.center()
    }
}
