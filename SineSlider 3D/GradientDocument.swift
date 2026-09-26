import Foundation

struct GradientChannelParameters: Codable {
    let horizontalTranslation: Double
    let horizontalScale: Double
    let verticalTranslation: Double
    let verticalScale: Double

    init(colorFactory: ColorFactory, channel: ColorChannel) {
        horizontalTranslation = colorFactory.factor(
            for: channel,
            transform: .horizontalTranslation
        )
        horizontalScale = colorFactory.factor(for: channel, transform: .horizontalScale)
        verticalTranslation = colorFactory.factor(for: channel, transform: .verticalTranslation)
        verticalScale = colorFactory.factor(for: channel, transform: .verticalScale)
    }

    func value(for transform: CurveTransform) -> Double {
        switch transform {
        case .horizontalTranslation: horizontalTranslation
        case .horizontalScale: horizontalScale
        case .verticalTranslation: verticalTranslation
        case .verticalScale: verticalScale
        }
    }

    var isValid: Bool {
        [horizontalTranslation, horizontalScale, verticalTranslation, verticalScale]
            .allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

struct GradientDocument: Codable {
    static let formatIdentifier = "sineslider3d"

    let format: String
    let red: GradientChannelParameters
    let green: GradientChannelParameters
    let blue: GradientChannelParameters

    init(colorFactory: ColorFactory) {
        format = Self.formatIdentifier
        red = GradientChannelParameters(colorFactory: colorFactory, channel: .red)
        green = GradientChannelParameters(colorFactory: colorFactory, channel: .green)
        blue = GradientChannelParameters(colorFactory: colorFactory, channel: .blue)
    }

    func encodedData() throws -> Data {
        guard red.isValid, green.isValid, blue.isValid else {
            throw GradientDocumentError.invalidDocument
        }

        let json = """
        {
          "format": "\(Self.formatIdentifier)",
          "red": {
            "horizontalTranslation": \(red.horizontalTranslation),
            "horizontalScale": \(red.horizontalScale),
            "verticalTranslation": \(red.verticalTranslation),
            "verticalScale": \(red.verticalScale)
          },
          "green": {
            "horizontalTranslation": \(green.horizontalTranslation),
            "horizontalScale": \(green.horizontalScale),
            "verticalTranslation": \(green.verticalTranslation),
            "verticalScale": \(green.verticalScale)
          },
          "blue": {
            "horizontalTranslation": \(blue.horizontalTranslation),
            "horizontalScale": \(blue.horizontalScale),
            "verticalTranslation": \(blue.verticalTranslation),
            "verticalScale": \(blue.verticalScale)
          }
        }

        """
        return Data(json.utf8)
    }

    func apply(to colorFactory: ColorFactory) throws {
        guard format == Self.formatIdentifier, red.isValid, green.isValid, blue.isValid else {
            throw GradientDocumentError.invalidDocument
        }

        for channel in ColorChannel.allCases {
            let parameters = switch channel {
            case .red: red
            case .green: green
            case .blue: blue
            }

            for transform in CurveTransform.allCases {
                colorFactory.setFactor(
                    parameters.value(for: transform),
                    for: channel,
                    transform: transform
                )
            }
        }
    }
}

enum GradientDocumentError: Error {
    case invalidDocument
}
