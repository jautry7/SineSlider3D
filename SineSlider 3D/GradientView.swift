import AppKit

final class GradientView: NSView {
    static let width: CGFloat = 512
    static let gradientHeight: CGFloat = 32

    let colorFactory: ColorFactory
    var position = 0.0
    var onPositionChange: ((Double) -> Void)?
    var onHoverStateChange: ((Bool) -> Void)?
    var approximationStops: [CSSGradientStop]? {
        didSet {
            needsDisplay = true
        }
    }

    private var trackingArea: NSTrackingArea?

    private var gradientRect: NSRect {
        NSRect(
            x: 0,
            y: (bounds.height - Self.gradientHeight) / 2,
            width: bounds.width,
            height: Self.gradientHeight
        )
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: 62)
    }

    init(colorFactory: ColorFactory) {
        self.colorFactory = colorFactory
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let newTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea

        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        updatePosition(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverStateChange?(true)
        updatePosition(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverStateChange?(false)
    }

    override func mouseDragged(with event: NSEvent) {
        updatePosition(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        updatePosition(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: gradientRect, xRadius: 5, yRadius: 5).addClip()

        let columnCount = max(2, Int(bounds.width.rounded()))
        for column in 0..<columnCount {
            let samplePosition = Double(column) / Double(columnCount - 1)
            color(at: samplePosition).setFill()
            NSRect(
                x: gradientRect.minX + CGFloat(column),
                y: gradientRect.minY,
                width: 1,
                height: gradientRect.height
            ).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        drawStopMarkers()
        drawPositionIndicators()
    }

    private func color(at position: Double) -> NSColor {
        guard let approximationStops else {
            return colorFactory.color(at: position)
        }

        let components = CSSGradientExporter.components(at: position, stops: approximationStops)
        return NSColor(
            calibratedRed: CGFloat(components.red),
            green: CGFloat(components.green),
            blue: CGFloat(components.blue),
            alpha: 1
        )
    }

    private func updatePosition(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let relativeX = min(gradientRect.maxX, max(gradientRect.minX, location.x))
        position = Double((relativeX - gradientRect.minX) / gradientRect.width)
        onPositionChange?(position)
        needsDisplay = true
    }

    private func drawStopMarkers() {
        guard let approximationStops else {
            return
        }

        let diameter: CGFloat = 12
        let radius = diameter / 2
        let edgeInset: CGFloat = 0

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: gradientRect, xRadius: 5, yRadius: 5).addClip()

        for stop in approximationStops {
            let unclampedX = gradientRect.minX + CGFloat(stop.position) * gradientRect.width
            let centerX = min(
                gradientRect.maxX - radius - edgeInset,
                max(gradientRect.minX + radius + edgeInset, unclampedX)
            )
            let markerRect = NSRect(
                x: centerX - radius,
                y: gradientRect.midY - radius,
                width: diameter,
                height: diameter
            )

            NSColor.black.setFill()
            NSBezierPath(ovalIn: markerRect).fill()

            NSColor.white.setFill()
            NSBezierPath(ovalIn: markerRect.insetBy(dx: 1, dy: 1)).fill()

            NSColor(
                calibratedRed: CGFloat(stop.components.red),
                green: CGFloat(stop.components.green),
                blue: CGFloat(stop.components.blue),
                alpha: 1
            ).setFill()
            NSBezierPath(ovalIn: markerRect.insetBy(dx: 2, dy: 2)).fill()
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawPositionIndicators() {
        let unclampedX = gradientRect.minX + CGFloat(position) * gradientRect.width
        let indicatorX = min(gradientRect.maxX - 4, max(gradientRect.minX + 4, unclampedX))
        let color = NSColor(calibratedWhite: 0.6, alpha: 1)

        let upperIndicator = NSBezierPath()
        upperIndicator.move(to: CGPoint(x: indicatorX - 4, y: gradientRect.maxY + 8.8))
        upperIndicator.line(to: CGPoint(x: indicatorX + 4, y: gradientRect.maxY + 8.8))
        upperIndicator.line(to: CGPoint(x: indicatorX, y: gradientRect.maxY + 4))
        upperIndicator.close()
        upperIndicator.lineWidth = 1.2
        upperIndicator.lineJoinStyle = .round

        let lowerIndicator = NSBezierPath()
        lowerIndicator.move(to: CGPoint(x: indicatorX - 4, y: gradientRect.minY - 8.8))
        lowerIndicator.line(to: CGPoint(x: indicatorX + 4, y: gradientRect.minY - 8.8))
        lowerIndicator.line(to: CGPoint(x: indicatorX, y: gradientRect.minY - 4))
        lowerIndicator.close()
        lowerIndicator.lineWidth = 1.2
        lowerIndicator.lineJoinStyle = .round

        color.setFill()
        color.setStroke()
        upperIndicator.fill()
        upperIndicator.stroke()
        lowerIndicator.fill()
        lowerIndicator.stroke()
    }
}
