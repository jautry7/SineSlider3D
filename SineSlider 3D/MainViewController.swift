import AppKit

final class MainViewController: NSViewController {
    private enum WindowLayout {
        static let topPadding: CGFloat = 36
        static let bottomPadding: CGFloat = 36
        static let leadingPadding: CGFloat = 36
        static let trailingPadding: CGFloat = 36
        static let columnSpacing: CGFloat = 40
    }

    private let colorFactory = ColorFactory()
    private lazy var graphView = GraphView(colorFactory: colorFactory)
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
    private let leftColumnContainer = NSView()
    private let gradientToValuesSpacing: CGFloat = 16

    private var selectedChannel: ColorChannel = .red
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
        updateSample(at: 0)
    }

    private func configureLayout() {
        graphView.translatesAutoresizingMaskIntoConstraints = false
        graphView.onCursorChange = { [weak self] x in
            self?.updateSample(at: x)
        }
        configureSampleReadout()
        sampleContainer.translatesAutoresizingMaskIntoConstraints = false
        sampleContainer.addSubview(sampleStack)

        leftColumn.orientation = .vertical
        leftColumn.alignment = .leading
        leftColumn.spacing = gradientToValuesSpacing
        leftColumn.translatesAutoresizingMaskIntoConstraints = false
        leftColumn.addArrangedSubview(graphView)
        leftColumn.addArrangedSubview(sampleContainer)

        leftColumnContainer.translatesAutoresizingMaskIntoConstraints = false
        leftColumnContainer.addSubview(leftColumn)

        let inspector = NSBox()
        inspector.boxType = .custom
        inspector.titlePosition = .noTitle
        inspector.borderWidth = 0
        inspector.cornerRadius = 10
        inspector.fillColor = .tertiarySystemFill
        inspector.contentViewMargins = .zero
        inspector.translatesAutoresizingMaskIntoConstraints = false
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
        controlsStack.spacing = 30
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        inspectorContent.addSubview(controlsStack)

        for transform in CurveTransform.allCases {
            let row = makeSliderRow(for: transform)
            controlsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: controlsStack.widthAnchor).isActive = true
        }

        let contentStack = NSStackView(views: [leftColumnContainer, inspector])
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
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

            leftColumnContainer.heightAnchor.constraint(equalTo: inspector.heightAnchor),
            leftColumn.leadingAnchor.constraint(equalTo: leftColumnContainer.leadingAnchor),
            leftColumn.trailingAnchor.constraint(equalTo: leftColumnContainer.trailingAnchor),
            leftColumn.centerYAnchor.constraint(
                equalTo: leftColumnContainer.centerYAnchor,
                constant: 2
            ),

            sampleContainer.widthAnchor.constraint(equalTo: graphView.widthAnchor),
            sampleContainer.heightAnchor.constraint(equalToConstant: 22),
            sampleStack.widthAnchor.constraint(
                equalToConstant: GraphView.plotSize + 12
            ),
            sampleStack.trailingAnchor.constraint(
                equalTo: sampleContainer.trailingAnchor
            ),
            sampleStack.topAnchor.constraint(equalTo: sampleContainer.topAnchor),
            sampleStack.bottomAnchor.constraint(equalTo: sampleContainer.bottomAnchor),

            inspector.widthAnchor.constraint(equalToConstant: 300),

            channelSelector.topAnchor.constraint(equalTo: inspectorContent.topAnchor, constant: 20),
            channelSelector.leadingAnchor.constraint(equalTo: inspectorContent.leadingAnchor, constant: 20),
            channelSelector.trailingAnchor.constraint(equalTo: inspectorContent.trailingAnchor, constant: -20),

            controlsStack.topAnchor.constraint(equalTo: channelSelector.bottomAnchor, constant: 30),
            controlsStack.leadingAnchor.constraint(equalTo: inspectorContent.leadingAnchor, constant: 28),
            controlsStack.trailingAnchor.constraint(equalTo: inspectorContent.trailingAnchor, constant: -28),
            controlsStack.bottomAnchor.constraint(equalTo: inspectorContent.bottomAnchor, constant: -28)
        ])
    }

    private func configureSampleReadout() {
        sampleStack.orientation = .horizontal
        sampleStack.alignment = .centerY
        sampleStack.distribution = .fill
        sampleStack.translatesAutoresizingMaskIntoConstraints = false

        var pairs: [NSStackView] = []
        for name in ["x", "R", "G", "B"] {
            let valueLabel = NSTextField(string: "0")
            valueLabel.isEditable = false
            valueLabel.isSelectable = false
            valueLabel.isBezeled = true
            valueLabel.bezelStyle = .roundedBezel
            valueLabel.drawsBackground = true
            valueLabel.backgroundColor = .controlBackgroundColor
            valueLabel.alignment = .center
            valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            valueLabel.widthAnchor.constraint(equalToConstant: 38).isActive = true

            let nameLabel = NSTextField(labelWithString: name)
            nameLabel.textColor = .secondaryLabelColor
            nameLabel.alignment = .right

            let pair = NSStackView(views: [nameLabel, valueLabel])
            pair.orientation = .horizontal
            pair.alignment = .centerY
            pair.spacing = 6
            pairs.append(pair)
            sampleValueLabels.append(valueLabel)
        }

        let rgbStack = NSStackView(views: Array(pairs.dropFirst()))
        rgbStack.orientation = .horizontal
        rgbStack.alignment = .centerY
        rgbStack.spacing = 14

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        sampleStack.addArrangedSubview(pairs[0])
        sampleStack.addArrangedSubview(spacer)
        sampleStack.addArrangedSubview(rgbStack)
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
        graphView.needsDisplay = true
        updateSample(at: graphView.cursorX)
    }

    private func updateSample(at x: Int) {
        guard sampleValueLabels.count == 4 else {
            return
        }

        sampleValueLabels[0].stringValue = "\(x)"
        for channel in ColorChannel.allCases {
            sampleValueLabels[channel.rawValue + 1].stringValue = "\(colorFactory.value(for: channel, at: x))"
        }
    }
}
