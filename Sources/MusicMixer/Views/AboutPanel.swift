import AppKit

/// Standardized About panel shared across the richardogcc utilities fleet.
/// A small floating borderless panel centered on screen showing a card with
/// the app icon, name, version, description and license line.
/// Clicking the card (or pressing Esc) dismisses it.
@MainActor
final class AboutPanelController {

    static let shared = AboutPanelController()

    private var panel: NSPanel?

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let card = AboutCardView()
        card.onDismiss = { [weak self] in self?.close() }

        let panel = AboutPanel(
            contentRect: card.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = card
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private func close() {
        panel?.close()
        panel = nil
    }
}

/// Borderless panel that can become key so Esc reaches `cancelOperation`.
private final class AboutPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

/// About card: app icon, name, version and license. Any click dismisses it.
private final class AboutCardView: NSView {
    var onDismiss: (() -> Void)?

    private let card = NSVisualEffectView()

    init() {
        super.init(frame: .zero)

        card.material = .hudWindow
        card.blendingMode = .behindWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.masksToBounds = true

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "dev"

        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.frame = NSRect(x: 0, y: 0, width: 72, height: 72)

        let lines: [(String, NSFont, NSColor)] = [
            ("Music Mixer", .systemFont(ofSize: 20, weight: .bold), .labelColor),
            ("Version \(version)", .systemFont(ofSize: 12), .secondaryLabelColor),
            ("Per-application volume mixer for the macOS menu bar",
             .systemFont(ofSize: 12), .secondaryLabelColor),
            ("github.com/richardogcc/Music-Mixer  ·  MIT License",
             .systemFont(ofSize: 11), .tertiaryLabelColor),
        ]
        let labels: [NSTextField] = lines.map { text, font, color in
            let label = NSTextField(labelWithString: text)
            label.font = font
            label.textColor = color
            label.alignment = .center
            label.sizeToFit()
            return label
        }

        let padding: CGFloat = 32
        let spacing: CGFloat = 8
        let contentWidth = max(labels.map { $0.frame.width }.max() ?? 0, 220)
        let textHeight = labels.reduce(0) { $0 + $1.frame.height } +
            spacing * CGFloat(labels.count - 1)
        let width = contentWidth + padding * 2
        let height = padding + icon.frame.height + 14 + textHeight + padding
        card.frame = NSRect(x: 0, y: 0, width: width, height: height)
        frame = card.frame

        icon.setFrameOrigin(NSPoint(x: (width - icon.frame.width) / 2,
                                    y: height - padding - icon.frame.height))
        var y = height - padding - icon.frame.height - 14
        for label in labels {
            y -= label.frame.height
            label.frame = NSRect(x: padding, y: y, width: contentWidth,
                                 height: label.frame.height)
            card.addSubview(label)
            y -= spacing
        }
        card.addSubview(icon)
        addSubview(card)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        card.frame = bounds
    }

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }
}
