import AppKit

struct RGBComponents {
    let red: Double
    let green: Double
    let blue: Double

    subscript(_ channel: ColorChannel) -> Double {
        switch channel {
        case .red: red
        case .green: green
        case .blue: blue
        }
    }

    func interpolated(to other: RGBComponents, fraction: Double) -> RGBComponents {
        RGBComponents(
            red: red + (other.red - red) * fraction,
            green: green + (other.green - green) * fraction,
            blue: blue + (other.blue - blue) * fraction
        )
    }

    func maximumDifference(from other: RGBComponents) -> Double {
        max(
            abs(red - other.red),
            abs(green - other.green),
            abs(blue - other.blue)
        )
    }

    func eightBitValue(for channel: ColorChannel) -> Int {
        Int((self[channel] * 255.0).rounded())
    }
}

enum ColorChannel: Int, CaseIterable {
    case red
    case green
    case blue

    var name: String {
        switch self {
        case .red: "Red"
        case .green: "Green"
        case .blue: "Blue"
        }
    }

    var displayColor: NSColor {
        switch self {
        case .red: .systemRed
        case .green: .systemGreen
        case .blue: .systemBlue
        }
    }
}

enum CurveTransform: Int, CaseIterable {
    case horizontalTranslation
    case horizontalScale
    case verticalTranslation
    case verticalScale

    var title: String {
        switch self {
        case .horizontalTranslation: "Horizontal Translation"
        case .horizontalScale: "Horizontal Scale"
        case .verticalTranslation: "Vertical Translation"
        case .verticalScale: "Vertical Scale"
        }
    }
}

private struct ChannelFactors {
    var factors: [Double]

    subscript(_ transform: CurveTransform) -> Double {
        get { factors[transform.rawValue] }
        set { factors[transform.rawValue] = newValue }
    }
}

final class ColorFactory {
    private var channelFactors = [
        ChannelFactors(factors: [1.0, 0.5, 0.5, 1.0]),
        ChannelFactors(factors: [0.8333, 0.5, 0.5, 1.0]),
        ChannelFactors(factors: [0.6666, 0.5, 0.5, 1.0])
    ]

    func factor(for channel: ColorChannel, transform: CurveTransform) -> Double {
        channelFactors[channel.rawValue][transform]
    }

    func setFactor(_ factor: Double, for channel: ColorChannel, transform: CurveTransform) {
        channelFactors[channel.rawValue][transform] = factor
    }

    /// Returns a normalized channel intensity for a position across the gradient.
    /// The cosine equation and 0...255 domain match the original SineSlider model,
    /// while the public position is independent of the rendered pixel width.
    func normalizedValue(for channel: ColorChannel, at position: Double) -> Double {
        let factors = channelFactors[channel.rawValue]
        let horizontalTranslation = 510.0 * factors[.horizontalTranslation]
        let safeHorizontalScale = factors[.horizontalScale] == 0 ? 0.01 : factors[.horizontalScale]
        let horizontalScale = 1.0 / (1020.0 * safeHorizontalScale)
        let verticalTranslation = 255.0 * factors[.verticalTranslation]
        let verticalScale = 127.5 * factors[.verticalScale]
        let x = min(1.0, max(0.0, position)) * 255.0

        let graphValue = verticalScale
            * cos(horizontalScale * 2.0 * .pi * (x + horizontalTranslation))
            + verticalTranslation
        let clampedGraphValue = min(255.0, max(0.0, graphValue))

        return (255.0 - clampedGraphValue) / 255.0
    }

    func components(at position: Double) -> RGBComponents {
        RGBComponents(
            red: normalizedValue(for: .red, at: position),
            green: normalizedValue(for: .green, at: position),
            blue: normalizedValue(for: .blue, at: position)
        )
    }

    func value(for channel: ColorChannel, at position: Double) -> Int {
        components(at: position).eightBitValue(for: channel)
    }

    func color(at position: Double) -> NSColor {
        let components = components(at: position)
        return NSColor(
            calibratedRed: CGFloat(components.red),
            green: CGFloat(components.green),
            blue: CGFloat(components.blue),
            alpha: 1.0
        )
    }
}
