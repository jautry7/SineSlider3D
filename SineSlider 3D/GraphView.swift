import AppKit

final class GraphView: NSView {
    static let plotSize: CGFloat = 256
    private static let axisLabelSpacing: CGFloat = 8
    private static let axisLabelFont = NSFont.monospacedDigitSystemFont(
        ofSize: 12,
        weight: .regular
    )
    private static let axisLabelWidth = ceil(
        ("255" as NSString).size(withAttributes: [.font: axisLabelFont]).width
    )

    let colorFactory: ColorFactory
    var cursorX = 0
    var onCursorChange: ((Int) -> Void)?

    private var cursorTrackingArea: NSTrackingArea?
    private let gradientHeight: CGFloat = 24
    private let graphToGradientSpacing: CGFloat = 18

    private var gradientRect: NSRect {
        NSRect(
            x: bounds.maxX - Self.plotSize,
            y: 0,
            width: Self.plotSize,
            height: gradientHeight
        )
    }

    private var plotRect: NSRect {
        NSRect(
            x: bounds.maxX - Self.plotSize,
            y: gradientRect.maxY + graphToGradientSpacing,
            width: Self.plotSize,
            height: Self.plotSize
        )
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: Self.axisLabelWidth + Self.axisLabelSpacing + Self.plotSize,
            height: plotRect.maxY
        )
    }

    init(colorFactory: ColorFactory) {
        self.colorFactory = colorFactory
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        cursorTrackingArea = trackingArea

        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateCursor(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        updateCursor(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.textBackgroundColor.setFill()
        plotRect.fill()

        drawGrid(in: plotRect)
        drawCurves(in: plotRect)
        drawCursor(in: plotRect)
        drawGradient()
        drawAxisLabels(around: plotRect)
    }

    private func updateCursor(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        cursorX = min(255, max(0, Int(location.x - plotRect.minX)))
        onCursorChange?(cursorX)
        needsDisplay = true
    }

    private func drawGrid(in rect: NSRect) {
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 1

        for step in 1..<8 {
            let y = rect.minY + CGFloat(step) * 32 + 0.5
            gridPath.move(to: CGPoint(x: rect.minX, y: y))
            gridPath.line(to: CGPoint(x: rect.maxX, y: y))
        }

        NSColor.separatorColor.setStroke()
        gridPath.stroke()

        NSColor.quaternaryLabelColor.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
    }

    private func drawCurves(in rect: NSRect) {
        for channel in ColorChannel.allCases {
            let curve = NSBezierPath()
            curve.lineWidth = 1.75

            for x in 0..<256 {
                let point = CGPoint(
                    x: rect.minX + CGFloat(x),
                    y: rect.minY + CGFloat(colorFactory.value(for: channel, at: x))
                )
                x == 0 ? curve.move(to: point) : curve.line(to: point)
            }

            channel.displayColor.setStroke()
            curve.stroke()
        }
    }

    private func drawCursor(in rect: NSRect) {
        let x = rect.minX + CGFloat(cursorX) + 0.5
        let cursorLine = NSBezierPath()
        cursorLine.move(to: CGPoint(x: x, y: rect.minY))
        cursorLine.line(to: CGPoint(x: x, y: rect.maxY))
        cursorLine.lineWidth = 2
        NSColor.labelColor.withAlphaComponent(0.72).setStroke()
        cursorLine.stroke()

        for channel in ColorChannel.allCases {
            let y = rect.minY + CGFloat(colorFactory.value(for: channel, at: cursorX))
            let marker = NSBezierPath(
                ovalIn: NSRect(x: x - 4.5, y: y - 4.5, width: 9, height: 9)
            )
            NSColor.windowBackgroundColor.setFill()
            marker.fill()
            channel.displayColor.setStroke()
            marker.lineWidth = 2
            marker.stroke()
        }
    }

    private func drawGradient() {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: gradientRect, xRadius: 4, yRadius: 4).addClip()

        for x in 0..<256 {
            colorFactory.color(at: x).setFill()
            NSRect(
                x: gradientRect.minX + CGFloat(x),
                y: gradientRect.minY,
                width: 1,
                height: gradientRect.height
            ).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawAxisLabels(around rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.axisLabelFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        drawAxisLabel(0, y: rect.minY, rect: rect, attributes: attributes)
        drawAxisLabel(63, y: rect.minY + 64, rect: rect, attributes: attributes)
        drawAxisLabel(127, y: rect.minY + 128, rect: rect, attributes: attributes)
        drawAxisLabel(191, y: rect.minY + 192, rect: rect, attributes: attributes)
        drawAxisLabel(255, y: rect.maxY, rect: rect, attributes: attributes)
    }

    private func drawAxisLabel(
        _ value: Int,
        y: CGFloat,
        rect: NSRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let label = "\(value)" as NSString
        let labelSize = label.size(withAttributes: attributes)
        label.draw(
            at: CGPoint(
                x: rect.minX - labelSize.width - Self.axisLabelSpacing,
                y: y - labelSize.height / 2
            ),
            withAttributes: attributes
        )
    }
}
