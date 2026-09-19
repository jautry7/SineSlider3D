import AppKit

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

    /// Returns the visible channel intensity while preserving the original Java
    /// cosine equation, clamping, integer truncation, and graph-axis inversion.
    func value(for channel: ColorChannel, at x: Int) -> Int {
        let factors = channelFactors[channel.rawValue]
        let horizontalTranslation = 510.0 * factors[.horizontalTranslation]
        let safeHorizontalScale = factors[.horizontalScale] == 0 ? 0.01 : factors[.horizontalScale]
        let horizontalScale = 1.0 / (1020.0 * safeHorizontalScale)
        let verticalTranslation = 255.0 * factors[.verticalTranslation]
        let verticalScale = 127.5 * factors[.verticalScale]

        let graphValue = verticalScale
            * cos(horizontalScale * 2.0 * .pi * (Double(x) + horizontalTranslation))
            + verticalTranslation
        let clampedGraphValue = min(255.0, max(0.0, graphValue))

        return 255 - Int(clampedGraphValue)
    }

    func color(at x: Int) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(value(for: .red, at: x)) / 255.0,
            green: CGFloat(value(for: .green, at: x)) / 255.0,
            blue: CGFloat(value(for: .blue, at: x)) / 255.0,
            alpha: 1.0
        )
    }
}
