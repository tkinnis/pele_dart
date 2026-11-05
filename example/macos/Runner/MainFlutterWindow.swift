import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "pele_dart — 3-Way Mermaid Comparison Studio & Playground"
    self.minSize = NSSize(width: 960, height: 620)

    if let screen = self.screen ?? NSScreen.main {
      let visible = screen.visibleFrame
      let targetWidth = min(max(visible.width * 0.86, 1280), 1680)
      let targetHeight = min(max(visible.height * 0.86, 820), 1060)
      let originX = visible.origin.x + (visible.width - targetWidth) / 2.0
      let originY = visible.origin.y + (visible.height - targetHeight) / 2.0
      let frame = NSRect(x: originX, y: originY, width: targetWidth, height: targetHeight)
      self.setFrame(frame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
