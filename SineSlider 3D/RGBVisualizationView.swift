import AppKit
import MetalKit
import simd

final class RGBVisualizationView: NSView {
    static let size: CGFloat = 512

    private let metalView: CameraMetalView
    private var renderer: RGBRenderer?
    private let axisLabels: [NSTextField]
    private let markerView = ColorMarkerView()
    private var camera = VisualizationCamera()
    private var curveComponents: [RGBComponents] = []
    private var markerPosition: Double?
    private var markerCoordinate: SIMD3<Float>?

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    override init(frame frameRect: NSRect) {
        let device = MTLCreateSystemDefaultDevice()
        metalView = CameraMetalView(frame: .zero, device: device)
        axisLabels = ["0", "R", "G", "B"].map { text in
            let label = NSTextField(labelWithString: text)
            label.font = .systemFont(ofSize: 15, weight: .semibold)
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = true
            return label
        }

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = Self.backgroundColor.cgColor
        layer?.cornerRadius = 10
        layer?.borderColor = Self.borderColor.cgColor
        layer?.borderWidth = 1
        layer?.masksToBounds = true

        configureMetalView(device: device)
        configureAxisLabels()
        configureMarker()
        configureCameraInteraction()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        positionAxisLabels()
        positionMarker()
    }

    func updateCurve(using colorFactory: ColorFactory) {
        let sampleCount = 1024
        let components = (0..<sampleCount).map { index in
            colorFactory.components(at: Double(index) / Double(sampleCount - 1))
        }
        curveComponents = components
        if let markerPosition {
            updateMarker(at: markerPosition, using: colorFactory)
        }
        updateScene()
    }

    func showMarker(at position: Double, using colorFactory: ColorFactory) {
        let clampedPosition = min(1.0, max(0.0, position))
        markerPosition = clampedPosition
        updateMarker(at: clampedPosition, using: colorFactory)
        markerView.isHidden = false
        positionMarker()
    }

    func hideMarker() {
        markerView.isHidden = true
        markerPosition = nil
        markerCoordinate = nil
    }

    func resetZoom() {
        camera.zoom = VisualizationCamera.defaultZoom
        updateScene()
    }

    private func configureMetalView(device: MTLDevice?) {
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = Self.backgroundColor.metalClearColor
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true
        metalView.framebufferOnly = true
        addSubview(metalView)

        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        guard let device else {
            return
        }

        do {
            let renderer = try RGBRenderer(device: device)
            self.renderer = renderer
            metalView.delegate = renderer
        } catch {
            assertionFailure("Unable to create RGB renderer: \(error)")
        }
    }

    private func configureAxisLabels() {
        axisLabels[0].textColor = .secondaryLabelColor
        axisLabels[1].textColor = .systemRed
        axisLabels[2].textColor = .systemGreen
        axisLabels[3].textColor = .systemBlue

        for label in axisLabels {
            label.sizeToFit()
            addSubview(label)
        }
    }

    private func configureMarker() {
        markerView.isHidden = true
        addSubview(markerView)
    }

    private func configureCameraInteraction() {
        metalView.onDrag = { [weak self] deltaX, deltaY in
            guard let self else {
                return
            }
            camera.angleB += Float(deltaX) / 100.0
            camera.angleR += Float(deltaY) / 100.0
            updateScene()
        }

        metalView.onZoom = { [weak self] zoomFactor in
            guard let self else {
                return
            }
            camera.zoom = min(3.0, max(0.35, camera.zoom * zoomFactor))
            updateScene()
        }
    }

    private func updateScene() {
        renderer?.updateScene(curveComponents, camera: camera)
        positionAxisLabels()
        positionMarker()
        metalView.setNeedsDisplay(metalView.bounds)
    }

    private func updateMarker(at position: Double, using colorFactory: ColorFactory) {
        let components = colorFactory.components(at: position)
        markerCoordinate = SIMD3<Float>(
            Float(components.red * 255.0 - 128.0),
            Float(components.green * 255.0 - 128.0),
            Float(components.blue * 255.0 - 128.0)
        )
        markerView.fillColor = NSColor(
            calibratedRed: CGFloat(components.red),
            green: CGFloat(components.green),
            blue: CGFloat(components.blue),
            alpha: 1
        )
    }

    private func positionMarker() {
        guard let markerCoordinate, !markerView.isHidden else {
            return
        }

        let normalized = camera.project(markerCoordinate)
        markerView.frame.origin = NSPoint(
            x: CGFloat(normalized.x) * bounds.width - ColorMarkerView.size / 2,
            y: CGFloat(normalized.y) * bounds.height - ColorMarkerView.size / 2
        )
    }

    private func positionAxisLabels() {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let labelCoordinates = [
            SIMD3<Float>(-141.5, -141.5, -141.5),
            SIMD3<Float>(134.5, -141.5, -141.5),
            SIMD3<Float>(-141.5, 134.5, -141.5),
            SIMD3<Float>(-141.5, -141.5, 134.5)
        ]

        for (label, coordinate) in zip(axisLabels, labelCoordinates) {
            let normalized = camera.project(coordinate)
            let center = NSPoint(
                x: bounds.minX + CGFloat(normalized.x) * bounds.width,
                y: bounds.minY + CGFloat(normalized.y) * bounds.height
            )
            label.sizeToFit()
            label.frame.origin = NSPoint(
                x: center.x - label.frame.width / 2,
                y: center.y - label.frame.height / 2
            )
        }
    }

    private static var backgroundColor: NSColor {
        NSColor(calibratedWhite: 0.2, alpha: 1)
    }

    private static var borderColor: NSColor {
        NSColor(calibratedWhite: 0.3, alpha: 1)
    }
}

private final class ColorMarkerView: NSView {
    static let size: CGFloat = 15

    var fillColor: NSColor = .clear {
        didSet {
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.setFill()
        NSBezierPath(ovalIn: bounds).fill()

        NSColor.white.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()

        fillColor.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).fill()
    }
}

private final class CameraMetalView: MTKView {
    var onDrag: ((CGFloat, CGFloat) -> Void)?
    var onZoom: ((Float) -> Void)?

    private var isDraggingCamera = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        isDraggingCamera = true
        window?.makeFirstResponder(self)
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingCamera else {
            return
        }
        onDrag?(event.deltaX, event.deltaY)
    }

    override func mouseUp(with event: NSEvent) {
        if isDraggingCamera {
            NSCursor.pop()
        }
        isDraggingCamera = false
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = min(20.0, max(-20.0, event.scrollingDeltaY))
        onZoom?(Float(exp(delta * 0.012)))
    }

    override func magnify(with event: NSEvent) {
        onZoom?(Float(max(0.1, 1.0 + event.magnification)))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

private final class RGBRenderer: NSObject, MTKViewDelegate {
    private struct Vertex {
        let position: SIMD4<Float>
        let color: SIMD4<Float>
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var cubeBuffer: MTLBuffer?
    private var cubeVertexCount = 0
    private var curveBuffer: MTLBuffer?
    private var curveVertexCount = 0

    init(device: MTLDevice) throws {
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueueUnavailable
        }
        self.commandQueue = commandQueue

        let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        guard
            let vertexFunction = library.makeFunction(name: "rgbVisualizationVertex"),
            let fragmentFunction = library.makeFunction(name: "rgbVisualizationFragment")
        else {
            throw RendererError.shaderUnavailable
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        super.init()
    }

    func updateScene(_ components: [RGBComponents], camera: VisualizationCamera) {
        let cubeVertices = Self.makeCubeVertices(camera: camera)
        cubeVertexCount = cubeVertices.count
        cubeBuffer = device.makeBuffer(
            bytes: cubeVertices,
            length: MemoryLayout<Vertex>.stride * cubeVertices.count
        )

        let centerlineVertices = components.map { components in
            let coordinate = SIMD3<Float>(
                Float(components.red * 255.0 - 128.0),
                Float(components.green * 255.0 - 128.0),
                Float(components.blue * 255.0 - 128.0)
            )
            let projected = camera.clipPosition(coordinate)
            return Vertex(
                position: SIMD4<Float>(projected.x, projected.y, 0, 1),
                color: SIMD4<Float>(
                    Float(components.red),
                    Float(components.green),
                    Float(components.blue),
                    1
                )
            )
        }
        let vertices = Self.makeLineStripVertices(from: centerlineVertices, width: 3)

        curveVertexCount = vertices.count
        curveBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<Vertex>.stride * vertices.count
        )
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        if let cubeBuffer {
            encoder.setVertexBuffer(cubeBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: cubeVertexCount)
        }

        if let curveBuffer, curveVertexCount > 1 {
            encoder.setVertexBuffer(curveBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: curveVertexCount)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static func makeCubeVertices(camera: VisualizationCamera) -> [Vertex] {
        let corners = [
            SIMD3<Float>(-128, -128, -128),
            SIMD3<Float>(-128, 127, 127),
            SIMD3<Float>(127, -128, 127),
            SIMD3<Float>(127, 127, -128),
            SIMD3<Float>(-128, -128, 127),
            SIMD3<Float>(-128, 127, -128),
            SIMD3<Float>(127, -128, -128),
            SIMD3<Float>(127, 127, 127)
        ]
        let edgeColor = SIMD4<Float>(repeating: 0.72) + SIMD4<Float>(0, 0, 0, -0.12)
        var vertices: [Vertex] = []

        for nearIndex in 0..<4 {
            for farIndex in 4..<8 where nearIndex + farIndex != 7 {
                for cornerIndex in [nearIndex, farIndex] {
                    let projected = camera.clipPosition(corners[cornerIndex])
                    if cornerIndex == nearIndex {
                        let farProjected = camera.clipPosition(corners[farIndex])
                        vertices.append(
                            contentsOf: makeSegmentVertices(
                                from: projected,
                                to: farProjected,
                                width: 1,
                                color: edgeColor
                            )
                        )
                    }
                }
            }
        }

        return vertices
    }

    private static func makeSegmentVertices(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        width: Float,
        color: SIMD4<Float>
    ) -> [Vertex] {
        let direction = normalized(end - start)
        let halfWidth = width / Float(RGBVisualizationView.size)
        let offset = SIMD2<Float>(-direction.y, direction.x) * halfWidth
        let startLeft = start + offset
        let startRight = start - offset
        let endLeft = end + offset
        let endRight = end - offset

        return [
            Vertex(position: clipPosition(startLeft), color: color),
            Vertex(position: clipPosition(startRight), color: color),
            Vertex(position: clipPosition(endLeft), color: color),
            Vertex(position: clipPosition(endLeft), color: color),
            Vertex(position: clipPosition(startRight), color: color),
            Vertex(position: clipPosition(endRight), color: color)
        ]
    }

    private static func makeLineStripVertices(from centerline: [Vertex], width: Float) -> [Vertex] {
        guard centerline.count > 1 else {
            return centerline
        }

        let halfWidth = width / Float(RGBVisualizationView.size)
        var vertices: [Vertex] = []
        vertices.reserveCapacity(centerline.count * 2)

        for index in centerline.indices {
            let current = centerline[index]
            let currentPoint = SIMD2<Float>(current.position.x, current.position.y)
            let offset: SIMD2<Float>

            if index == centerline.startIndex {
                let next = centerline[centerline.index(after: index)]
                let direction = normalized(
                    SIMD2<Float>(next.position.x, next.position.y) - currentPoint
                )
                offset = SIMD2<Float>(-direction.y, direction.x) * halfWidth
            } else if index == centerline.index(before: centerline.endIndex) {
                let previous = centerline[centerline.index(before: index)]
                let direction = normalized(
                    currentPoint - SIMD2<Float>(previous.position.x, previous.position.y)
                )
                offset = SIMD2<Float>(-direction.y, direction.x) * halfWidth
            } else {
                let previous = centerline[centerline.index(before: index)]
                let next = centerline[centerline.index(after: index)]
                let incoming = normalized(
                    currentPoint - SIMD2<Float>(previous.position.x, previous.position.y)
                )
                let outgoing = normalized(
                    SIMD2<Float>(next.position.x, next.position.y) - currentPoint
                )
                let incomingNormal = SIMD2<Float>(-incoming.y, incoming.x)
                let outgoingNormal = SIMD2<Float>(-outgoing.y, outgoing.x)
                let normalSum = incomingNormal + outgoingNormal
                let miter = simd_length(normalSum) > 0.000_001
                    ? normalized(normalSum)
                    : outgoingNormal
                let miterScale = halfWidth / max(0.25, simd_dot(miter, outgoingNormal))
                offset = miter * min(miterScale, halfWidth * 2)
            }

            vertices.append(
                Vertex(
                    position: clipPosition(currentPoint + offset),
                    color: current.color
                )
            )
            vertices.append(
                Vertex(
                    position: clipPosition(currentPoint - offset),
                    color: current.color
                )
            )
        }

        return vertices
    }

    private static func normalized(_ vector: SIMD2<Float>) -> SIMD2<Float> {
        let length = simd_length(vector)
        return length > 0.000_001 ? vector / length : SIMD2<Float>(1, 0)
    }

    private static func clipPosition(_ point: SIMD2<Float>) -> SIMD4<Float> {
        SIMD4<Float>(point.x, point.y, 0, 1)
    }

    private enum RendererError: Error {
        case commandQueueUnavailable
        case shaderUnavailable
        case bufferUnavailable
    }

    private static let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct RGBVisualizationVertex {
            float4 position;
            float4 color;
        };

        struct RGBVisualizationRasterData {
            float4 position [[position]];
            float4 color;
        };

        vertex RGBVisualizationRasterData rgbVisualizationVertex(
            const device RGBVisualizationVertex *vertices [[buffer(0)]],
            uint vertexID [[vertex_id]]
        ) {
            RGBVisualizationRasterData output;
            output.position = vertices[vertexID].position;
            output.color = vertices[vertexID].color;
            return output;
        }

        fragment float4 rgbVisualizationFragment(
            RGBVisualizationRasterData input [[stage_in]]
        ) {
            return input.color;
        }
        """
}

private struct VisualizationCamera {
    static let defaultZoom: Float = 0.95

    var angleB: Float = -0.6125
    var angleR: Float = 2.0
    var zoom: Float = Self.defaultZoom

    private static let distance: Float = 33 * 33

    func project(_ coordinate: SIMD3<Float>) -> SIMD2<Float> {
        let cosB = cos(angleB)
        let sinB = sin(angleB)
        let cosR = cos(angleR)
        let sinR = sin(angleR)

        let intermediateY = sinB * coordinate.x + cosB * coordinate.y
        let projectedY = cosR * intermediateY - sinR * coordinate.z
        let depth = sinR * intermediateY + cosR * coordinate.z
        let perspectiveScale = Self.distance / (depth + Self.distance)
        let projectedX = (cosB * coordinate.x - sinB * coordinate.y) * perspectiveScale

        return SIMD2<Float>(
            (projectedX * zoom + 256.5) / 512.0,
            1.0 - ((projectedY * perspectiveScale * zoom + 256.5) / 512.0)
        )
    }

    func clipPosition(_ coordinate: SIMD3<Float>) -> SIMD2<Float> {
        let normalized = project(coordinate)
        return SIMD2<Float>(normalized.x * 2.0 - 1.0, normalized.y * 2.0 - 1.0)
    }
}

private extension NSColor {
    var metalClearColor: MTLClearColor {
        let color = usingColorSpace(.deviceRGB) ?? self
        return MTLClearColor(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }
}
