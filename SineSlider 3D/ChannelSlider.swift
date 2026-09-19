import AppKit

private final class ChannelSliderCell: NSSliderCell {
    var channelColor: NSColor = .systemRed

    override func drawBar(inside rect: NSRect, flipped: Bool) {
        super.drawBar(inside: rect, flipped: flipped)

        guard sliderType == .linear else {
            return
        }

        let trackRect = barRect(flipped: flipped)
        let knobFrame = knobRect(flipped: flipped)
        let fillWidth = max(0, min(trackRect.width, knobFrame.midX - trackRect.minX))

        guard fillWidth > 0 else {
            return
        }

        let fillRect = NSRect(
            x: trackRect.minX,
            y: trackRect.minY,
            width: fillWidth,
            height: trackRect.height
        )
        channelColor.setFill()
        let cornerRadius = trackRect.height / 2
        NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }
}

final class ChannelSlider: NSSlider {
    var channelColor: NSColor {
        get { channelSliderCell.channelColor }
        set {
            channelSliderCell.channelColor = newValue
            needsDisplay = true
        }
    }

    private var channelSliderCell: ChannelSliderCell {
        guard let channelSliderCell = cell as? ChannelSliderCell else {
            fatalError("ChannelSlider requires a ChannelSliderCell")
        }
        return channelSliderCell
    }

    init(
        value: Double,
        minValue: Double,
        maxValue: Double,
        target: AnyObject?,
        action: Selector?
    ) {
        super.init(frame: .zero)
        cell = ChannelSliderCell()
        self.minValue = minValue
        self.maxValue = maxValue
        doubleValue = value
        self.target = target
        self.action = action
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
