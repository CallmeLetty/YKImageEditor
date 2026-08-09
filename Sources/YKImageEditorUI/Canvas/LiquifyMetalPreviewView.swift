import MetalKit
import UIKit
import YKImageEditorCore

/// 使用 GPU 采样形变网格的液化预览层。
///
/// 该视图只承担交互预览；确认应用时仍由 `LiquifyProcessor` 输出全分辨率位图。
final class LiquifyMetalPreviewView: MTKView {
    private struct GridUniforms {
        var columns: UInt32
        var rows: UInt32
    }

    private static let shaderSource = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct LiquifyVertexOut {
        float4 position [[position]];
        float2 textureCoordinate;
    };

    struct LiquifyGridUniforms {
        uint columns;
        uint rows;
    };

    vertex LiquifyVertexOut liquifyVertex(uint vertexID [[vertex_id]]) {
        const float2 positions[] = {
            float2(-1.0,  1.0),
            float2( 1.0,  1.0),
            float2(-1.0, -1.0),
            float2( 1.0, -1.0)
        };
        const float2 textureCoordinates[] = {
            float2(0.0, 0.0),
            float2(1.0, 0.0),
            float2(0.0, 1.0),
            float2(1.0, 1.0)
        };

        LiquifyVertexOut output;
        output.position = float4(positions[vertexID], 0.0, 1.0);
        output.textureCoordinate = textureCoordinates[vertexID];
        return output;
    }

    fragment float4 liquifyFragment(
        LiquifyVertexOut input [[stage_in]],
        texture2d<float> sourceTexture [[texture(0)]],
        const device float2 *displacements [[buffer(0)]],
        constant LiquifyGridUniforms &grid [[buffer(1)]]) {
        constexpr sampler textureSampler(
            mag_filter::linear,
            min_filter::linear,
            address::clamp_to_edge
        );

        float2 gridPosition = input.textureCoordinate * float2(grid.columns, grid.rows);
        uint2 lower = uint2(floor(gridPosition));
        uint2 upper = min(lower + 1, uint2(grid.columns, grid.rows));
        float2 amount = fract(gridPosition);
        uint stride = grid.columns + 1;

        float2 top = mix(
            displacements[lower.y * stride + lower.x],
            displacements[lower.y * stride + upper.x],
            amount.x
        );
        float2 bottom = mix(
            displacements[upper.y * stride + lower.x],
            displacements[upper.y * stride + upper.x],
            amount.x
        );
        float2 sourceCoordinate = clamp(
            input.textureCoordinate + mix(top, bottom, amount.y),
            float2(0.0),
            float2(1.0)
        );
        return sourceTexture.sample(textureSampler, sourceCoordinate);
    }
    """#

    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var sourceTexture: MTLTexture?
    private var displacementVectors: [SIMD2<Float>] = []
    private var gridUniforms = GridUniforms(columns: 0, rows: 0)
    private var reusableGridBuffers: [MTLBuffer] = []

    var isAvailable: Bool {
        device != nil && commandQueue != nil && pipelineState != nil
    }

    init() {
        let metalDevice = MTLCreateSystemDefaultDevice()
        super.init(frame: .zero, device: metalDevice)
        isHidden = true
        isUserInteractionEnabled = false
        isPaused = true
        enableSetNeedsDisplay = true
        framebufferOnly = true
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColorMake(0, 0, 0, 1)
        preferredFramesPerSecond = max(UIScreen.main.maximumFramesPerSecond, 60)

        guard let metalDevice else { return }
        commandQueue = metalDevice.makeCommandQueue()
        pipelineState = makePipelineState(device: metalDevice)
        delegate = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func begin(image: UIImage, deformer: LiquifyDeformer) {
        end()
        guard isAvailable, let cgImage = resolvedCGImage(from: image), let device else { return }
        let loader = MTKTextureLoader(device: device)
        sourceTexture = try? loader.newTexture(
            cgImage: cgImage,
            options: [
                .origin: MTKTextureLoader.Origin.topLeft,
                .SRGB: false,
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue)
            ]
        )
        guard sourceTexture != nil else { return }
        isHidden = false
        update(deformer: deformer)
    }

    func update(deformer: LiquifyDeformer) {
        guard !isHidden else { return }
        displacementVectors = deformer.displacementVectors()
        gridUniforms = GridUniforms(
            columns: UInt32(deformer.columns),
            rows: UInt32(deformer.rows)
        )
        setNeedsDisplay()
    }

    func end() {
        isHidden = true
        sourceTexture = nil
        displacementVectors.removeAll(keepingCapacity: true)
        reusableGridBuffers.removeAll(keepingCapacity: true)
    }

    private func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState? {
        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "liquifyVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "liquifyFragment")
            descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }
    }

    private func resolvedCGImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    private func makeGridBuffer() -> MTLBuffer? {
        guard let device else { return nil }
        let length = displacementVectors.count * MemoryLayout<SIMD2<Float>>.stride
        guard length > 0 else { return nil }
        let buffer = reusableGridBuffers.popLast()
            ?? device.makeBuffer(length: length, options: .storageModeShared)
        guard let buffer, buffer.length >= length else {
            return device.makeBuffer(length: length, options: .storageModeShared)
        }
        displacementVectors.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            buffer.contents().copyMemory(from: baseAddress, byteCount: length)
        }
        return buffer
    }
}

extension LiquifyMetalPreviewView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pipelineState,
              let commandQueue,
              let sourceTexture,
              let gridBuffer = makeGridBuffer(),
              let renderPassDescriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentBuffer(gridBuffer, offset: 0, index: 0)
        encoder.setFragmentBytes(
            &gridUniforms,
            length: MemoryLayout<GridUniforms>.stride,
            index: 1
        )
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.reusableGridBuffers.count < 3 else { return }
                self.reusableGridBuffers.append(gridBuffer)
            }
        }
        commandBuffer.commit()
    }
}
