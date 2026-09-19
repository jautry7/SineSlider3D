import AppKit

final class MainViewController: NSViewController {
    private enum WindowLayout {
        static let topPadding: CGFloat = 36
        static let bottomPadding: CGFloat = 36
        static let leadingPadding: CGFloat = 36
        static let trailingPadding: CGFloat = 36
        static let columnSpacing: CGFloat = 28
        static let inspectorWidth: CGFloat = 300
    }

    private let colorFactory = ColorFactory()
    private let visualizationView = RGBVisualizationView()
    private lazy var gradientView = GradientView(colorFactory: colorFactory)
    private let channelSelector = NSSegmentedControl(
        labels: ColorChannel.allCases.map(\.name),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let controlsStack = NSStackView()
    private let sampleStack = NSStackView()
    private let sampleContainer = NSView()
    private let leftColumn = NSStackView()
    private let rightColumn = NSStackView()
    private let stopCountLabel = NSTextField(labelWithString: "5 stops")
    private let stopCountSlider = ChannelSlider(
        value: 5,
        minValue: 2,
        maxValue: 10,
        target: nil,
        action: nil
    )

    private var selectedChannel: ColorChannel = .red
    private var selectedPosition = 0.0
    private var stopCount = 5
    private var showsLinearApproximation = false
    private var approximationStops: [CSSGradientStop]?
    private var sliders: [CurveTransform: ChannelSlider] = [:]
    private var percentageLabels: [CurveTransform: NSTextField] = [:]
    private var sampleValueLabels: [NSTextField] = []

    override func loadView() {
        view = NSView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        selectChannel(nil)
        refreshGradientPresentation()
        updateSample(at: 0)
    }

    private func configureLayout() {
        configureLeftColumn()

        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = 24
        rightColumn.translatesAutoresizingMaskIntoConstraints = false

        let controlsInspector = makeControlsInspector()
        let cssInspector = makeCSSInspector()
        rightColumn.addArrangedSubview(controlsInspector)
        rightColumn.addArrangedSubview(cssInspector)

        let contentStack = NSStackView(views: [leftColumn, rightColumn])
        contentStack.orientation = .horizontal
        contentStack.alignment = .top
        contentStack.spacing = WindowLayout.columnSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: WindowLayout.leadingPadding
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -WindowLayout.trailingPadding
            ),
            contentStack.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: WindowLayout.topPadding
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -WindowLayout.bottomPadding
            ),

            visualizationView.widthAnchor.constraint(equalToConstant: RGBVisualizationView.size),
            visualizationView.heightAnchor.constraint(equalToConstant: RGBVisualizationView.size),
            gradientView.widthAnchor.constraint(equalToConstant: GradientView.width),
            sampleContainer.widthAnchor.constraint(equalToConstant: GradientView.width),
            sampleContainer.heightAnchor.constraint(equalToConstant: 24),
            sampleStack.leadingAnchor.constraint(equalTo: sampleContainer.leadingAnchor),
            sampleStack.trailingAnchor.constraint(equalTo: sampleContainer.trailingAnchor),
            sampleStack.topAnchor.constraint(equalTo: sampleContainer.topAnchor),
            sampleStack.bottomAnchor.constraint(equalTo: sampleContainer.bottomAnchor),

            rightColumn.widthAnchor.constraint(equalToConstant: WindowLayout.inspectorWidth),
            controlsInspector.widthAnchor.constraint(equalTo: rightColumn.widthAnchor),
            cssInspector.widthAnchor.constraint(equalTo: rightColumn.widthAnchor)
        ])
    }

    private func configureLeftColumn() {
        visualizationView.translatesAutoresizingMaskIntoConstraints = false

        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.onPositionChange = { [weak self] position in
            guard let self else {
                return
            }
            updateSample(at: position)
            visualizationView.showMarker(
                at: position,
                components: displayedComponents(at: position)
            )
        }
        gradientView.onHoverStateChange = { [weak self] isHovering in
            guard let self else {
                return
            }
            if isHovering {
                visualizationView.showMarker(
                    at: selectedPosition,
                    components: displayedComponents(at: selectedPosition)
                )
            } else {
                visualizationView.hideMarker()
            }
        }

        configureSampleReadout()
        sampleContainer.translatesAutoresizingMaskIntoConstraints = false
        sampleContainer.addSubview(sampleStack)

        leftColumn.orientation = .vertical
        leftColumn.alignment = .leading
        leftColumn.spacing = 6
        leftColumn.translatesAutoresizingMaskIntoConstraints = false
        leftColumn.addArrangedSubview(visualizationView)
        leftColumn.addArrangedSubview(gradientView)
        leftColumn.addArrangedSubview(sampleContainer)
    }

    private func makeControlsInspector() -> NSBox {
        let inspector = makeInspectorBox()
        let inspectorContent = inspector.contentView!

        channelSelector.selectedSegment = ColorChannel.red.rawValue
        channelSelector.selectedSegmentBezelColor = .darkGray
        channelSelector.target = self
        channelSelector.action = #selector(selectChannel(_:))
        channelSelector.translatesAutoresizingMaskIntoConstraints = false
        inspectorContent.addSubview(channelSelector)

        controlsStack.orientation = .vertical
        controlsStack.alignment = .leading
        controlsStack.distribution = .fill
        controlsStack.spacing = 24
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        inspectorContent.addSubview(controlsStack)

        for transform in CurveTransform.allCases {
            let row = makeSliderRow(for: transform)
            controlsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: controlsStack.widthAnchor).isActive = true
            row.heightAnchor.constraint(equalToConstant: 38).isActive = true
        }

        NSLayoutConstraint.activate([
            channelSelector.topAnchor.constraint(equalTo: inspectorContent.topAnchor, constant: 20),
            channelSelector.leadingAnchor.constraint(equalTo: inspectorContent.leadingAnchor, constant: 20),
            channelSelector.trailingAnchor.constraint(equalTo: inspectorContent.trailingAnchor, constant: -20),

            controlsStack.topAnchor.constraint(equalTo: channelSelector.bottomAnchor, constant: 28),
            controlsStack.leadingAnchor.constraint(equalTo: inspectorContent.leadingAnchor, constant: 28),
            controlsStack.trailingAnchor.constraint(equalTo: inspectorContent.trailingAnchor, constant: -28),
            controlsStack.bottomAnchor.constraint(equalTo: inspectorContent.bottomAnchor, constant: -28)
        ])

        return inspector
    }

    private func makeCSSInspector() -> NSBox {
        let inspector = makeInspectorBox()
        let inspectorContent = inspector.contentView!

        let titleLabel = NSTextField(labelWithString: "Linear approximation")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        let descriptionLabel = NSTextField(
            wrappingLabelWithString: "Approximate the sinusoidal gradient with\na standard stopped gradient."
        )
        descriptionLabel.font = .systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor

        let approximationCheckbox = NSButton(
            checkboxWithTitle: "Show linear approximation",
            target: self,
            action: #selector(approximationVisibilityChanged(_:))
        )
        approximationCheckbox.state = .off

        let separator = NSBox()
        separator.boxType = .separator

        let fidelityLabel = NSTextField(labelWithString: "Fidelity")
        fidelityLabel.font = .systemFont(ofSize: 13)

        stopCountLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        stopCountLabel.textColor = .secondaryLabelColor
        stopCountLabel.alignment = .right
        stopCountLabel.alphaValue = 0

        let fidelityHeading = NSStackView(views: [fidelityLabel, stopCountLabel])
        fidelityHeading.orientation = .horizontal
        fidelityHeading.alignment = .centerY
        fidelityHeading.distribution = .fill

        stopCountSlider.isContinuous = true
        stopCountSlider.channelColor = .controlAccentColor
        stopCountSlider.isEnabled = false
        stopCountSlider.alphaValue = 0.3
        stopCountSlider.target = self
        stopCountSlider.action = #selector(stopCountChanged(_:))

        let copyButton = NSButton(
            title: "Copy CSS",
            target: self,
            action: #selector(copyCSS(_:))
        )
        copyButton.bezelStyle = .rounded

        let contentStack = NSStackView(
            views: [
                titleLabel,
                descriptionLabel,
                approximationCheckbox,
                separator,
                fidelityHeading,
                stopCountSlider,
                copyButton
            ]
        )
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.setCustomSpacing(4, after: titleLabel)
        contentStack.setCustomSpacing(22, after: approximationCheckbox)
        contentStack.setCustomSpacing(18, after: separator)
        contentStack.setCustomSpacing(8, after: fidelityHeading)
        contentStack.setCustomSpacing(20, after: stopCountSlider)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        inspectorContent.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: inspectorContent.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: inspectorContent.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(equalTo: inspectorContent.trailingAnchor, constant: -28),
            contentStack.bottomAnchor.constraint(equalTo: inspectorContent.bottomAnchor, constant: -24),
            descriptionLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            approximationCheckbox.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            separator.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            fidelityHeading.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            stopCountSlider.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])

        return inspector
    }

    private func makeInspectorBox() -> NSBox {
        let inspector = NSBox()
        inspector.boxType = .custom
        inspector.titlePosition = .noTitle
        inspector.borderWidth = 0
        inspector.cornerRadius = 10
        inspector.fillColor = .tertiarySystemFill
        inspector.contentViewMargins = .zero
        inspector.translatesAutoresizingMaskIntoConstraints = false
        return inspector
    }

    private func configureSampleReadout() {
        sampleStack.orientation = .horizontal
        sampleStack.alignment = .centerY
        sampleStack.distribution = .fill
        sampleStack.translatesAutoresizingMaskIntoConstraints = false

        let percentageValue = makeSampleValueLabel(width: 40)
        let percentageSuffix = NSTextField(labelWithString: "%")
        percentageSuffix.textColor = .secondaryLabelColor
        let percentagePair = NSStackView(views: [percentageValue, percentageSuffix])
        percentagePair.orientation = .horizontal
        percentagePair.alignment = .centerY
        percentagePair.spacing = 5
        sampleValueLabels.append(percentageValue)

        var rgbPairs: [NSStackView] = []
        for name in ["R", "G", "B"] {
            let nameLabel = NSTextField(labelWithString: name)
            nameLabel.textColor = .secondaryLabelColor
            nameLabel.alignment = .right

            let valueLabel = makeSampleValueLabel(width: 38)
            sampleValueLabels.append(valueLabel)

            let pair = NSStackView(views: [nameLabel, valueLabel])
            pair.orientation = .horizontal
            pair.alignment = .centerY
            pair.spacing = 6
            rgbPairs.append(pair)
        }

        let rgbStack = NSStackView(views: rgbPairs)
        rgbStack.orientation = .horizontal
        rgbStack.alignment = .centerY
        rgbStack.spacing = 14

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        sampleStack.addArrangedSubview(percentagePair)
        sampleStack.addArrangedSubview(spacer)
        sampleStack.addArrangedSubview(rgbStack)
    }

    private func makeSampleValueLabel(width: CGFloat) -> NSTextField {
        let valueLabel = NSTextField(string: "0")
        valueLabel.isEditable = false
        valueLabel.isSelectable = false
        valueLabel.isBezeled = true
        valueLabel.bezelStyle = .roundedBezel
        valueLabel.drawsBackground = true
        valueLabel.backgroundColor = .controlBackgroundColor
        valueLabel.alignment = .center
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        valueLabel.widthAnchor.constraint(equalToConstant: width).isActive = true
        return valueLabel
    }

    private func makeSliderRow(for transform: CurveTransform) -> NSView {
        let titleLabel = NSTextField(labelWithString: transform.title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let percentageLabel = NSTextField(labelWithString: "0%")
        percentageLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        percentageLabel.textColor = .secondaryLabelColor
        percentageLabel.alignment = .right
        percentageLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        percentageLabels[transform] = percentageLabel

        let heading = NSStackView(views: [titleLabel, percentageLabel])
        heading.orientation = .horizontal
        heading.distribution = .fill
        heading.alignment = .centerY

        let slider = ChannelSlider(
            value: 0,
            minValue: 0,
            maxValue: 100,
            target: self,
            action: #selector(sliderChanged(_:))
        )
        slider.isContinuous = true
        slider.tag = transform.rawValue
        sliders[transform] = slider

        let row = NSStackView(views: [heading, slider])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 6
        heading.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true
        slider.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true

        return row
    }

    @objc private func selectChannel(_ sender: NSSegmentedControl?) {
        selectedChannel = ColorChannel(rawValue: channelSelector.selectedSegment) ?? .red

        for transform in CurveTransform.allCases {
            let percentage = Int(
                (colorFactory.factor(for: selectedChannel, transform: transform) * 100).rounded()
            )
            sliders[transform]?.integerValue = percentage
            sliders[transform]?.channelColor = selectedChannel.displayColor
            percentageLabels[transform]?.stringValue = "\(percentage)%"
        }
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        guard let transform = CurveTransform(rawValue: sender.tag) else {
            return
        }

        colorFactory.setFactor(
            sender.doubleValue / 100.0,
            for: selectedChannel,
            transform: transform
        )
        percentageLabels[transform]?.stringValue = "\(sender.integerValue)%"
        refreshGradientPresentation()
        updateSample(at: selectedPosition)
    }

    @objc private func stopCountChanged(_ sender: NSSlider) {
        stopCount = min(10, max(2, sender.integerValue))
        sender.integerValue = stopCount
        stopCountLabel.stringValue = "\(stopCount) stops"
        if showsLinearApproximation {
            refreshGradientPresentation()
            updateSample(at: selectedPosition)
        }
    }

    @objc private func approximationVisibilityChanged(_ sender: NSButton) {
        showsLinearApproximation = sender.state == .on
        stopCountSlider.isEnabled = showsLinearApproximation
        stopCountSlider.alphaValue = showsLinearApproximation ? 1 : 0.3
        stopCountLabel.alphaValue = showsLinearApproximation ? 1 : 0
        refreshGradientPresentation()
        updateSample(at: selectedPosition)
    }

    @objc private func copyCSS(_ sender: NSButton) {
        let css = CSSGradientExporter.css(count: stopCount, colorFactory: colorFactory)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(css, forType: .string)
    }

    @objc func resetVisualizationZoom(_ sender: Any?) {
        visualizationView.resetZoom()
    }

    private func updateSample(at position: Double) {
        guard sampleValueLabels.count == 4 else {
            return
        }

        selectedPosition = min(1.0, max(0.0, position))
        sampleValueLabels[0].stringValue = "\(Int((selectedPosition * 100).rounded()))"
        let components = displayedComponents(at: selectedPosition)
        for channel in ColorChannel.allCases {
            let value = components.eightBitValue(for: channel)
            sampleValueLabels[channel.rawValue + 1].stringValue = "\(value)"
        }
    }

    private func refreshGradientPresentation() {
        approximationStops = showsLinearApproximation
            ? CSSGradientExporter.stops(count: stopCount, colorFactory: colorFactory)
            : nil
        gradientView.approximationStops = approximationStops
        visualizationView.updateCurve(
            using: colorFactory,
            approximationStops: approximationStops
        )
    }

    private func displayedComponents(at position: Double) -> RGBComponents {
        guard let approximationStops else {
            return colorFactory.components(at: position)
        }
        return CSSGradientExporter.components(at: position, stops: approximationStops)
    }
}
