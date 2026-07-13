import Cocoa
import FlutterMacOS
import window_manager

private struct WindowedState {
  let absoluteFrame: NSRect
  let frameRelativeToScreen: NSRect
  let screenFrame: NSRect
  let screenNumber: NSNumber?
  let styleMask: NSWindow.StyleMask
  let presentationOptions: NSApplication.PresentationOptions
  let isMovable: Bool
  let isMovableByWindowBackground: Bool
  let hasShadow: Bool
  let titleVisibility: NSWindow.TitleVisibility
  let titlebarAppearsTransparent: Bool
  let toolbarVisible: Bool?
}

class BlurryContainerViewController: NSViewController {
  let flutterViewController = FlutterViewController()

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError()
  }

  override func loadView() {
    let blurView = NSVisualEffectView()
    blurView.autoresizingMask = [.width, .height]
    blurView.blendingMode = .behindWindow
    blurView.state = .active
    if #available(macOS 10.14, *) {
        blurView.material = .sidebar
    }
    self.view = blurView
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.addChild(flutterViewController)

    flutterViewController.view.frame = self.view.bounds
    flutterViewController.view.autoresizingMask = [.width, .height]
    self.view.addSubview(flutterViewController.view)
  }
}

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var windowedState: WindowedState?

  override var canBecomeKey: Bool {
    windowedState != nil || super.canBecomeKey
  }

  override var canBecomeMain: Bool {
    windowedState != nil || super.canBecomeMain
  }

  override func awakeFromNib() {
    delegate = self
    let blurryContainerViewController = BlurryContainerViewController()
    let windowFrame = self.frame
    self.contentViewController = blurryContainerViewController
    self.setFrame(windowFrame, display: true)

    /*if #available(macOS 10.13, *) {
      let customToolbar = NSToolbar()
      customToolbar.showsBaselineSeparator = false
      self.toolbar = customToolbar
    }*/
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    if #available(macOS 11.0, *) {
      // Use .expanded if the app will have a title bar, else use .unified
      self.toolbarStyle = .unified
    }

    self.isMovableByWindowBackground = true
    self.styleMask.insert(NSWindow.StyleMask.fullSizeContentView)

    self.isOpaque = false
    self.backgroundColor = .clear

    RegisterGeneratedPlugins(registry: blurryContainerViewController.flutterViewController)

    super.awakeFromNib()
  }

  override func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }

  // Hides the toolbar when in fullscreen mode
  func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
    return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
  }

  func windowWillEnterFullScreen(_ notification: Notification) {
    self.toolbar?.isVisible = false
  }
  
  func windowDidExitFullScreen(_ notification: Notification) {
    self.toolbar?.isVisible = true
  }

  @discardableResult
  func enterInstantFullScreen() -> Bool {
    if windowedState != nil {
      return true
    }
    if styleMask.contains(.fullScreen) {
      return true
    }
    guard let targetScreen = screen ?? NSScreen.main else {
      return false
    }

    windowedState = WindowedState(
      absoluteFrame: frame,
      frameRelativeToScreen: NSRect(
        x: frame.origin.x - targetScreen.frame.origin.x,
        y: frame.origin.y - targetScreen.frame.origin.y,
        width: frame.width,
        height: frame.height
      ),
      screenFrame: targetScreen.frame,
      screenNumber: screenNumber(for: targetScreen),
      styleMask: styleMask,
      presentationOptions: NSApp.presentationOptions,
      isMovable: isMovable,
      isMovableByWindowBackground: isMovableByWindowBackground,
      hasShadow: hasShadow,
      titleVisibility: titleVisibility,
      titlebarAppearsTransparent: titlebarAppearsTransparent,
      toolbarVisible: toolbar?.isVisible
    )

    var presentationOptions = NSApp.presentationOptions
    if presentationOptions.contains(.hideDock) {
      presentationOptions.remove(.autoHideDock)
    } else {
      presentationOptions.insert(.autoHideDock)
    }
    if presentationOptions.contains(.hideMenuBar) {
      presentationOptions.remove(.autoHideMenuBar)
    } else {
      presentationOptions.insert(.autoHideMenuBar)
    }
    NSApp.presentationOptions = presentationOptions
    toolbar?.isVisible = false
    isMovable = false
    isMovableByWindowBackground = false
    hasShadow = false
    styleMask = [.borderless]
    setFrame(targetScreen.frame, display: true, animate: false)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    makeKeyAndOrderFront(nil)
    if let flutterView = (contentViewController as? BlurryContainerViewController)?.flutterViewController.view {
      makeFirstResponder(flutterView)
    }
    return true
  }

  override func toggleFullScreen(_ sender: Any?) {
    if windowedState != nil {
      return
    }
    super.toggleFullScreen(sender)
  }

  @discardableResult
  func exitInstantFullScreen() -> Bool {
    guard let state = windowedState else {
      return true
    }
    windowedState = nil

    NSApp.presentationOptions = state.presentationOptions
    styleMask = state.styleMask
    titleVisibility = state.titleVisibility
    titlebarAppearsTransparent = state.titlebarAppearsTransparent
    isMovable = state.isMovable
    isMovableByWindowBackground = state.isMovableByWindowBackground
    hasShadow = state.hasShadow
    if let toolbarVisible = state.toolbarVisible {
      toolbar?.isVisible = toolbarVisible
    }
    let targetScreen = state.screenNumber.flatMap { savedNumber in
      NSScreen.screens.first { screenNumber(for: $0) == savedNumber }
    } ?? screen ?? NSScreen.main
    let restoredFrame: NSRect
    if let targetScreen, targetScreen.frame == state.screenFrame {
      restoredFrame = state.absoluteFrame
    } else if let targetScreen {
      let relativeFrame = state.frameRelativeToScreen
      let desiredFrame = NSRect(
        x: targetScreen.frame.origin.x + relativeFrame.origin.x,
        y: targetScreen.frame.origin.y + relativeFrame.origin.y,
        width: relativeFrame.width,
        height: relativeFrame.height
      )
      restoredFrame = clamp(desiredFrame, to: targetScreen.visibleFrame)
    } else {
      restoredFrame = state.absoluteFrame
    }
    setFrame(restoredFrame, display: true, animate: false)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    makeKeyAndOrderFront(nil)
    if let flutterView = (contentViewController as? BlurryContainerViewController)?.flutterViewController.view {
      makeFirstResponder(flutterView)
    }
    return true
  }

  private func screenNumber(for screen: NSScreen) -> NSNumber? {
    screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
  }

  private func clamp(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
    var result = frame
    result.size.width = min(result.width, visibleFrame.width)
    result.size.height = min(result.height, visibleFrame.height)
    result.origin.x = max(
      visibleFrame.minX,
      min(result.origin.x, visibleFrame.maxX - result.width)
    )
    result.origin.y = max(
      visibleFrame.minY,
      min(result.origin.y, visibleFrame.maxY - result.height)
    )
    return result
  }

}
