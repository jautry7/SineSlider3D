import Foundation

struct CSSGradientStop {
    let position: Double
    let components: RGBComponents
}

enum CSSGradientExporter {
    private static let candidateIntervalCount = 4096

    static func stops(count: Int, colorFactory: ColorFactory) -> [CSSGradientStop] {
        let requestedCount = min(20, max(2, count))
        var stops = [
            CSSGradientStop(position: 0, components: colorFactory.components(at: 0)),
            CSSGradientStop(position: 1, components: colorFactory.components(at: 1))
        ]

        while stops.count < requestedCount {
            stops.sort { $0.position < $1.position }

            var greatestError = -Double.infinity
            var nextStop: CSSGradientStop?

            for pairIndex in 0..<(stops.count - 1) {
                let start = stops[pairIndex]
                let end = stops[pairIndex + 1]
                let firstCandidate = Int(ceil(start.position * Double(candidateIntervalCount))) + 1
                let lastCandidate = Int(floor(end.position * Double(candidateIntervalCount))) - 1

                guard firstCandidate <= lastCandidate else {
                    continue
                }

                for candidateIndex in firstCandidate...lastCandidate {
                    let position = Double(candidateIndex) / Double(candidateIntervalCount)
                    let fraction = (position - start.position) / (end.position - start.position)
                    let approximated = start.components.interpolated(
                        to: end.components,
                        fraction: fraction
                    )
                    let actual = colorFactory.components(at: position)
                    let error = actual.maximumDifference(from: approximated)

                    if error > greatestError {
                        greatestError = error
                        nextStop = CSSGradientStop(position: position, components: actual)
                    }
                }
            }

            guard let nextStop else {
                break
            }
            stops.append(nextStop)
        }

        return stops.sorted { $0.position < $1.position }
    }

    static func css(count: Int, colorFactory: ColorFactory) -> String {
        let colorStops = stops(count: count, colorFactory: colorFactory).map { stop in
            let red = stop.components.eightBitValue(for: .red)
            let green = stop.components.eightBitValue(for: .green)
            let blue = stop.components.eightBitValue(for: .blue)
            return "rgb(\(red) \(green) \(blue)) \(percentageString(stop.position))"
        }

        return "linear-gradient(to right, \(colorStops.joined(separator: ", ")))"
    }

    static func components(at position: Double, stops: [CSSGradientStop]) -> RGBComponents {
        guard let first = stops.first, let last = stops.last else {
            return RGBComponents(red: 0, green: 0, blue: 0)
        }

        let clampedPosition = min(1.0, max(0.0, position))
        if clampedPosition <= first.position {
            return first.components
        }
        if clampedPosition >= last.position {
            return last.components
        }

        for index in 1..<stops.count where clampedPosition <= stops[index].position {
            let start = stops[index - 1]
            let end = stops[index]
            let fraction = (clampedPosition - start.position) / (end.position - start.position)
            return start.components.interpolated(to: end.components, fraction: fraction)
        }

        return last.components
    }

    private static func percentageString(_ position: Double) -> String {
        let percentage = position * 100.0
        let formatted = String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            percentage
        )
        let trimmed = formatted
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
        return "\(trimmed)%"
    }
}
