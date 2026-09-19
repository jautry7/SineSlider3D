import AppKit
import MetalKit
import simd

final class RGBVisualizationView: NSView {
    static let size: CGFloat = 512

    private let metalView: MTKView
    private var renderer: RGBRenderer?
    private let axisLabels: [NSTextField]

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    override init(frame frameRect: NSRect) {
        let device = MTLCreateSystemDefaultDevice()
        metalView = MTKView(frame: .zero, device: device)
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
        layer?.masksToBounds = true

        configureMetalView(device: device)
        configureAxisLabels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        positionAxisLabels()
    }

    func updateCurve(using colorFactory: ColorFactory) {
        let sampleCount = 1024
        let components = (0..<sampleCount).map { index in
            colorFactory.components(at: Double(index) / Double(sampleCount - 1))
        }
        renderer?.updateCurve(components)
        metalView.setNeedsDisplay(metalView.bounds)
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

    private func positionAxisLabels() {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let labelCoordinates = [
            SIMD3<Float>(-146, -146, -146),
            SIMD3<Float>(137, -146, -146),
            SIMD3<Float>(-146, 137, -146),
            SIMD3<Float>(-146, -146, 137)
        ]

        for (label, coordinate) in zip(axisLabels, labelCoordinates) {
            let normalized = ColorInspectorProjection.project(coordinate)
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
        NSColor.tertiarySystemFill
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
    private let cubeBuffer: MTLBuffer
    private let cubeVertexCount: Int
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

        let cubeVertices = Self.makeCubeVertices()
        guard let cubeBuffer = device.makeBuffer(
            bytes: cubeVertices,
            length: MemoryLayout<Vertex>.stride * cubeVertices.count
        ) else {
            throw RendererError.bufferUnavailable
        }
        self.cubeBuffer = cubeBuffer
        cubeVertexCount = cubeVertices.count

        super.init()
    }

    func updateCurve(_ components: [RGBComponents]) {
        let vertices = components.map { components in
            let coordinate = SIMD3<Float>(
                Float(components.red * 255.0 - 128.0),
                Float(components.green * 255.0 - 128.0),
                Float(components.blue * 255.0 - 128.0)
            )
            let projected = ColorInspectorProjection.clipPosition(coordinate)
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
        encoder.setVertexBuffer(cubeBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: cubeVertexCount)

        if let curveBuffer, curveVertexCount > 1 {
            encoder.setVertexBuffer(curveBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: curveVertexCount)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static func makeCubeVertices() -> [Vertex] {
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
                    let projected = ColorInspectorProjection.clipPosition(corners[cornerIndex])
                    vertices.append(
                        Vertex(
                            position: SIMD4<Float>(projected.x, projected.y, 0, 1),
                            color: edgeColor
                        )
                    )
                }
            }
        }

        return vertices
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

private enum ColorInspectorProjection {
    private static let angleB: Float = -0.6125
    private static let angleR: Float = 2.0
    private static let distance: Float = 33 * 33

    static func project(_ coordinate: SIMD3<Float>) -> SIMD2<Float> {
        let cosB = cos(angleB)
        let sinB = sin(angleB)
        let cosR = cos(angleR)
        let sinR = sin(angleR)

        let intermediateY = sinB * coordinate.x + cosB * coordinate.y
        let projectedY = cosR * intermediateY - sinR * coordinate.z
        let depth = sinR * intermediateY + cosR * coordinate.z
        let perspectiveScale = distance / (depth + distance)
        let projectedX = (cosB * coordinate.x - sinB * coordinate.y) * perspectiveScale

        return SIMD2<Float>(
            (projectedX + 256.5) / 512.0,
            1.0 - ((projectedY * perspectiveScale + 256.5) / 512.0)
        )
    }

    static func clipPosition(_ coordinate: SIMD3<Float>) -> SIMD2<Float> {
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
