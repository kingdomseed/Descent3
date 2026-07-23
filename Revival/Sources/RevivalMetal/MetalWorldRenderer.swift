// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Metal
import MetalKit
import QuartzCore
import simd

#if !targetEnvironment(simulator)
enum MetalWorldRendererError: Error, LocalizedError {
    case metalUnavailable
    case metal4Unavailable
    case missingShaderLibrary
    case allocationFailed(String)

    var errorDescription: String? {
        switch self {
        case .metalUnavailable:
            "No Metal device is available."
        case .metal4Unavailable:
            "The selected Metal device does not support Metal 4."
        case .missingShaderLibrary:
            "The Revival Metal shader library is missing."
        case let .allocationFailed(name):
            "Metal could not prepare \(name)."
        }
    }
}

func centeredSquareMetalViewport(
    drawableWidth: Double,
    drawableHeight: Double
) -> MTLViewport {
    let side = min(drawableWidth, drawableHeight)
    return MTLViewport(
        originX: (drawableWidth - side) / 2,
        originY: (drawableHeight - side) / 2,
        width: side,
        height: side,
        znear: 0,
        zfar: 1
    )
}

@MainActor
final class MetalWorldRenderer: NSObject, MTKViewDelegate {
    private let view: MTKView
    private let device: any MTLDevice
    private let queue: any MTL4CommandQueue
    private let opaquePipeline: any MTLRenderPipelineState
    private let sourceAlphaPipeline: any MTLRenderPipelineState
    private let additivePipeline: any MTLRenderPipelineState
    private let opaqueDepthState: any MTLDepthStencilState
    private let translucentDepthState: any MTLDepthStencilState
    private let argumentTable: any MTL4ArgumentTable
    private let baseSampler: any MTLSamplerState
    private let lightmapSampler: any MTLSamplerState
    private let frameResidency: any MTLResidencySet
    private let completionEvent: any MTLSharedEvent
    private let frameSlots: [MetalFrameSlot]

    private var presentation: MetalLevelPresentation?
    private var nextSlotIndex = 0
    private var submittedValue: UInt64 = 0
    private var submittedFrameCount = 0
    private var firstFrameTime = CACurrentMediaTime()
    private var frameUpdate: ((Double) -> Void)?

    var hasPresentation: Bool {
        presentation != nil
    }

    init(view: MTKView) throws {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice() else {
            throw MetalWorldRendererError.metalUnavailable
        }
        guard device.supportsFamily(.metal4) else {
            throw MetalWorldRendererError.metal4Unavailable
        }

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .invalid
        view.sampleCount = 1
        view.framebufferOnly = true
        view.clearColor = MTLClearColorMake(0.006, 0.008, 0.012, 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        let layer = view.layer as! CAMetalLayer

        guard let queue = device.makeMTL4CommandQueue(),
              let completionEvent = device.makeSharedEvent() else {
            throw MetalWorldRendererError.allocationFailed("command submission state")
        }
        guard let library = device.makeDefaultLibrary() else {
            throw MetalWorldRendererError.missingShaderLibrary
        }

        self.view = view
        self.device = device
        self.queue = queue
        self.completionEvent = completionEvent

        let compiler = try device.makeCompiler(descriptor: MTL4CompilerDescriptor())
        opaquePipeline = try makeWorldPipeline(
            compiler: compiler,
            library: library,
            blend: .opaque
        )
        sourceAlphaPipeline = try makeWorldPipeline(
            compiler: compiler,
            library: library,
            blend: .sourceAlpha
        )
        additivePipeline = try makeWorldPipeline(
            compiler: compiler,
            library: library,
            blend: .additiveSourceAlpha
        )
        opaqueDepthState = try makeDepthState(device: device, writesDepth: true)
        translucentDepthState = try makeDepthState(device: device, writesDepth: false)

        let argumentDescriptor = MTL4ArgumentTableDescriptor()
        argumentDescriptor.maxBufferBindCount = 2
        argumentDescriptor.maxTextureBindCount = 2
        argumentDescriptor.maxSamplerStateBindCount = 2
        argumentDescriptor.initializeBindings = true
        argumentTable = try device.makeArgumentTable(descriptor: argumentDescriptor)

        guard let baseSampler = makeSampler(device: device, addressMode: .repeat),
              let lightmapSampler = makeSampler(device: device, addressMode: .clampToEdge) else {
            throw MetalWorldRendererError.allocationFailed("texture samplers")
        }
        self.baseSampler = baseSampler
        self.lightmapSampler = lightmapSampler
        argumentTable.setSamplerState(baseSampler.gpuResourceID, index: 0)
        argumentTable.setSamplerState(lightmapSampler.gpuResourceID, index: 1)

        let slotCount = max(1, layer.maximumDrawableCount)
        var slots: [MetalFrameSlot] = []
        slots.reserveCapacity(slotCount)
        for _ in 0..<slotCount {
            guard let allocator = device.makeCommandAllocator(),
                  let commandBuffer = device.makeCommandBuffer(),
                  let uniformBuffer = device.makeBuffer(
                    length: MemoryLayout<MetalWorldUniforms>.stride,
                    options: .storageModeShared
                  ) else {
                throw MetalWorldRendererError.allocationFailed("frame resources")
            }
            slots.append(
                MetalFrameSlot(
                    allocator: allocator,
                    commandBuffer: commandBuffer,
                    uniformBuffer: uniformBuffer
                )
            )
        }
        frameSlots = slots

        let residencyDescriptor = MTLResidencySetDescriptor()
        residencyDescriptor.initialCapacity = slotCount
        frameResidency = try device.makeResidencySet(descriptor: residencyDescriptor)
        for slot in slots {
            frameResidency.addAllocation(slot.uniformBuffer)
        }
        frameResidency.commit()
        frameResidency.requestResidency()
        queue.addResidencySet(frameResidency)
        queue.addResidencySet(layer.residencySet)
        if #available(macOS 26.4, iOS 26.4, *) {
            queue.addResidencySet(view.residencySet)
        }

        super.init()

        view.delegate = self
    }

    func replace(
        level: Level,
        camera: RoomCamera,
        startRoomSourceIndex: Int
    ) throws {
        let candidate = try makeMetalWorldPlan(
            level: level,
            camera: camera,
            startRoomSourceIndex: startRoomSourceIndex
        )
        try install(candidate)
    }

    func replace(level: Level, playerView: PlayerView) throws {
        try install(
            try makeMetalWorldPlan(level: level, playerView: playerView)
        )
    }

    func update(level: Level, playerView: PlayerView) throws {
        guard let presentation else {
            try replace(level: level, playerView: playerView)
            return
        }
        presentation.update(
            try updateMetalWorldPlan(
                presentation.plan,
                level: level,
                playerView: playerView
            )
        )
    }

    func setFrameUpdate(_ update: ((Double) -> Void)?) {
        frameUpdate = update
    }

    private func install(_ candidate: MetalWorldPlan) throws {
        drainFinalGPUUse()
        presentation = nil

        let prepared = try MetalLevelPresentation(
            device: device,
            plan: candidate,
            frameSlotCount: frameSlots.count
        )
        presentation = prepared
        submittedFrameCount = 0
        firstFrameTime = CACurrentMediaTime()
    }

    func drawNow() {
        view.draw()
    }

    func unload() {
        drainFinalGPUUse()
        presentation = nil
    }

    func shutdown() {
        frameUpdate = nil
        view.delegate = nil
        unload()
    }

    func draw(in view: MTKView) {
        frameUpdate?(CACurrentMediaTime())
        guard let presentation,
              let slotIndex = availableFrameSlotIndex(),
              let drawable = view.currentDrawable,
              let renderPass = view.currentMTL4RenderPassDescriptor else {
            return
        }
        let slot = frameSlots[slotIndex]
        guard let depthTexture = makeDepthTextureIfNeeded(
            for: slot,
            drawableSize: view.drawableSize
        ) else {
            return
        }

        presentation.updateProceduralTextures(
            frameSlotIndex: slotIndex,
            frameCount: submittedFrameCount,
            timeSeconds: Float(CACurrentMediaTime() - firstFrameTime)
        )
        writeWorldUniforms(
            camera: presentation.plan.camera,
            to: slot.uniformBuffer
        )

        renderPass.depthAttachment.texture = depthTexture
        renderPass.depthAttachment.loadAction = .clear
        renderPass.depthAttachment.storeAction = .dontCare
        renderPass.depthAttachment.clearDepth = 1

        slot.allocator.reset()
        slot.commandBuffer.beginCommandBuffer(allocator: slot.allocator)
        slot.commandBuffer.useResidencySet(presentation.residencySet)
        guard let encoder = slot.commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPass
        ) else {
            slot.commandBuffer.endCommandBuffer()
            return
        }

        encoder.setViewport(
            centeredSquareMetalViewport(
                drawableWidth: Double(view.drawableSize.width),
                drawableHeight: Double(view.drawableSize.height)
            )
        )
        encoder.setCullMode(.none)
        argumentTable.setAddress(slot.uniformBuffer.gpuAddress, index: 1)
        encoder.setArgumentTable(argumentTable, stages: [.vertex, .fragment])

        var encodingBlend: MetalWorldBlendMode?
        var encodingDepthWrite: Bool?
        for draw in presentation.draws {
            let blend: MetalWorldBlendMode
            switch draw.blend {
            case .opaque: blend = .opaque
            case .sourceAlpha: blend = .sourceAlpha
            case .additiveSourceAlpha: blend = .additiveSourceAlpha
            }
            if encodingBlend != blend {
                switch blend {
                case .opaque:
                    encoder.setRenderPipelineState(opaquePipeline)
                case .sourceAlpha:
                    encoder.setRenderPipelineState(sourceAlphaPipeline)
                case .additiveSourceAlpha:
                    encoder.setRenderPipelineState(additivePipeline)
                }
                encodingBlend = blend
            }
            if encodingDepthWrite != draw.writesDepth {
                encoder.setDepthStencilState(
                    draw.writesDepth ? opaqueDepthState : translucentDepthState
                )
                encodingDepthWrite = draw.writesDepth
            }
            argumentTable.setAddress(
                presentation.vertexBuffer.gpuAddress + UInt64(draw.vertexByteOffset),
                index: 0
            )
            argumentTable.setTexture(
                presentation.baseTexture(
                    for: draw,
                    frameSlotIndex: slotIndex
                ).gpuResourceID,
                index: 0
            )
            argumentTable.setTexture(
                presentation.lightmapTexture(for: draw).gpuResourceID,
                index: 1
            )
            encoder.drawIndexedPrimitives(
                primitiveType: .triangle,
                indexCount: draw.indexCount,
                indexType: .uint32,
                indexBuffer: presentation.indexBuffer.gpuAddress
                    + UInt64(draw.indexByteOffset),
                indexBufferLength: presentation.indexBuffer.length
                    - draw.indexByteOffset
            )
        }
        encoder.endEncoding()
        slot.commandBuffer.endCommandBuffer()

        submittedValue += 1
        queue.waitForDrawable(drawable)
        queue.commit([slot.commandBuffer])
        queue.signalEvent(completionEvent, value: submittedValue)
        queue.signalDrawable(drawable)
        drawable.present()

        slot.completionValue = submittedValue
        submittedFrameCount += 1
        nextSlotIndex = (slotIndex + 1) % frameSlots.count
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drainFinalGPUUse()
        for slot in frameSlots {
            slot.depthTexture = nil
            slot.depthSize = .zero
        }
    }

    private func availableFrameSlotIndex() -> Int? {
        for offset in frameSlots.indices {
            let index = (nextSlotIndex + offset) % frameSlots.count
            let completion = frameSlots[index].completionValue
            if completion == 0 || completionEvent.signaledValue >= completion {
                return index
            }
        }
        return nil
    }

    private func drainFinalGPUUse() {
        guard submittedValue > 0,
              completionEvent.signaledValue < submittedValue else {
            return
        }
        _ = completionEvent.wait(
            untilSignaledValue: submittedValue,
            timeoutMS: .max
        )
    }

    private func makeDepthTextureIfNeeded(
        for slot: MetalFrameSlot,
        drawableSize: CGSize
    ) -> (any MTLTexture)? {
        let size = CGSize(
            width: max(1, drawableSize.width.rounded(.up)),
            height: max(1, drawableSize.height.rounded(.up))
        )
        if slot.depthSize == size { return slot.depthTexture }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.storageMode = .memoryless
        descriptor.usage = .renderTarget
        guard let depthTexture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        slot.depthTexture = depthTexture
        slot.depthSize = size
        return depthTexture
    }
}

private final class MetalFrameSlot {
    let allocator: any MTL4CommandAllocator
    let commandBuffer: any MTL4CommandBuffer
    let uniformBuffer: any MTLBuffer
    var completionValue: UInt64 = 0
    var depthTexture: (any MTLTexture)?
    var depthSize: CGSize = .zero

    init(
        allocator: any MTL4CommandAllocator,
        commandBuffer: any MTL4CommandBuffer,
        uniformBuffer: any MTLBuffer
    ) {
        self.allocator = allocator
        self.commandBuffer = commandBuffer
        self.uniformBuffer = uniformBuffer
    }
}

private struct MetalWorldUniforms {
    var worldToClip: simd_float4x4
}

private struct MetalEncodedDraw {
    let texture: SourceResource?
    let blend: PresentationBlend
    let writesDepth: Bool
    let lightmapBlend: PresentationLightmapBlend
    let lightmapPageIndex: Int?
    let vertexByteOffset: Int
    let indexByteOffset: Int
    let indexCount: Int
}

@MainActor
private final class MetalLevelPresentation {
    private(set) var plan: MetalWorldPlan
    let residencySet: any MTLResidencySet
    let vertexBuffer: any MTLBuffer
    let indexBuffer: any MTLBuffer
    private(set) var draws: [MetalEncodedDraw]

    private let preparedDraws: [MetalEncodedDraw]
    private let materials: [SourceResource: MetalMaterialResources]
    private let lightmaps: [Int: any MTLTexture]
    private let whiteLightmap: any MTLTexture

    init(
        device: any MTLDevice,
        plan: MetalWorldPlan,
        frameSlotCount: Int
    ) throws {
        self.plan = plan

        var packedVertices: [MetalWorldVertex] = []
        var packedIndices: [UInt32] = []
        var encodedDraws: [MetalEncodedDraw] = []
        for draw in plan.preparedDraws {
            let vertexByteOffset = packedVertices.count
                * MemoryLayout<MetalWorldVertex>.stride
            let indexByteOffset = packedIndices.count * MemoryLayout<UInt32>.stride
            packedVertices.append(contentsOf: draw.vertices)
            packedIndices.append(contentsOf: draw.indices)
            encodedDraws.append(
                MetalEncodedDraw(
                    texture: draw.texture,
                    blend: draw.blend,
                    writesDepth: draw.writesDepth,
                    lightmapBlend: draw.lightmapBlend,
                    lightmapPageIndex: draw.lightmapPageIndex,
                    vertexByteOffset: vertexByteOffset,
                    indexByteOffset: indexByteOffset,
                    indexCount: draw.indices.count
                )
            )
        }
        guard let vertexBuffer = makeBuffer(device: device, values: packedVertices),
              let indexBuffer = makeBuffer(device: device, values: packedIndices) else {
            throw MetalWorldRendererError.allocationFailed("world geometry")
        }
        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
        preparedDraws = encodedDraws
        draws = plan.activeDrawIndices.map { encodedDraws[$0] }

        var materialResources: [SourceResource: MetalMaterialResources] = [:]
        for material in plan.level.presentationMaterials {
            materialResources[material.texture] = try MetalMaterialResources(
                device: device,
                material: material,
                frameSlotCount: frameSlotCount
            )
        }
        materials = materialResources

        var lightmapTextures: [Int: any MTLTexture] = [:]
        for (index, page) in plan.level.lightmaps.pages.enumerated() {
            guard let rgba8 = page.rgba8 else { continue }
            lightmapTextures[index] = try makeRGBA8Texture(
                device: device,
                image: .init(width: page.width, height: page.height, rgba8: rgba8)
            )
        }
        lightmaps = lightmapTextures
        whiteLightmap = try makeRGBA8Texture(
            device: device,
            image: .init(
                width: 1,
                height: 1,
                rgba8: Data([255, 255, 255, 255])
            )
        )

        let descriptor = MTLResidencySetDescriptor()
        descriptor.initialCapacity = 2
            + materialResources.values.reduce(0) { $0 + $1.textures.count }
            + lightmapTextures.count
            + 1
        residencySet = try device.makeResidencySet(descriptor: descriptor)
        residencySet.addAllocation(vertexBuffer)
        residencySet.addAllocation(indexBuffer)
        for material in materialResources.values {
            for texture in material.textures {
                residencySet.addAllocation(texture)
            }
        }
        for texture in lightmapTextures.values {
            residencySet.addAllocation(texture)
        }
        residencySet.addAllocation(whiteLightmap)
        residencySet.commit()
        residencySet.requestResidency()
    }

    func update(_ plan: MetalWorldPlan) {
        precondition(plan.preparedDraws == self.plan.preparedDraws)
        self.plan = plan
        draws = plan.activeDrawIndices.map { preparedDraws[$0] }
    }

    func updateProceduralTextures(
        frameSlotIndex: Int,
        frameCount: Int,
        timeSeconds: Float
    ) {
        for material in materials.values {
            material.updateProceduralTexture(
                frameSlotIndex: frameSlotIndex,
                frameCount: frameCount,
                timeSeconds: timeSeconds
            )
        }
    }

    func baseTexture(
        for draw: MetalEncodedDraw,
        frameSlotIndex: Int
    ) -> any MTLTexture {
        guard let texture = draw.texture else { return whiteLightmap }
        return materials[texture]!.texture(frameSlotIndex: frameSlotIndex)
    }

    func lightmapTexture(for draw: MetalEncodedDraw) -> any MTLTexture {
        guard draw.lightmapBlend == .multiply,
              let pageIndex = draw.lightmapPageIndex else {
            return whiteLightmap
        }
        return lightmaps[pageIndex]!
    }
}

@MainActor
private final class MetalMaterialResources {
    let textures: [any MTLTexture]
    private var evaluator: WaterProceduralEvaluator?

    init(
        device: any MTLDevice,
        material: PresentationMaterial,
        frameSlotCount: Int
    ) throws {
        if let water = material.waterProcedural {
            evaluator = WaterProceduralEvaluator(
                image: material.image,
                definition: water
            )
            var dynamicTextures: [any MTLTexture] = []
            dynamicTextures.reserveCapacity(frameSlotCount)
            for _ in 0..<frameSlotCount {
                dynamicTextures.append(
                    try makeRGBA8Texture(device: device, image: material.image)
                )
            }
            textures = dynamicTextures
        } else {
            evaluator = nil
            textures = [try makeRGBA8Texture(device: device, image: material.image)]
        }
    }

    func texture(frameSlotIndex: Int) -> any MTLTexture {
        textures.count == 1 ? textures[0] : textures[frameSlotIndex]
    }

    func updateProceduralTexture(
        frameSlotIndex: Int,
        frameCount: Int,
        timeSeconds: Float
    ) {
        guard var evaluator else { return }
        let rgba8 = evaluator.rgba8(
            frameCount: frameCount,
            timeSeconds: timeSeconds
        )
        self.evaluator = evaluator
        replaceRGBA8(
            texture: textures[frameSlotIndex],
            rgba8: rgba8
        )
    }
}

private enum MetalWorldBlendMode: Equatable {
    case opaque
    case sourceAlpha
    case additiveSourceAlpha
}

private func makeWorldPipeline(
    compiler: any MTL4Compiler,
    library: any MTLLibrary,
    blend: MetalWorldBlendMode
) throws -> any MTLRenderPipelineState {
    let vertex = MTL4LibraryFunctionDescriptor()
    vertex.library = library
    vertex.name = "revivalWorldVertex"
    let fragment = MTL4LibraryFunctionDescriptor()
    fragment.library = library
    fragment.name = "revivalWorldFragment"

    let descriptor = MTL4RenderPipelineDescriptor()
    switch blend {
    case .opaque: descriptor.label = "Revival opaque world"
    case .sourceAlpha: descriptor.label = "Revival source-alpha world"
    case .additiveSourceAlpha: descriptor.label = "Revival additive world"
    }
    descriptor.vertexFunctionDescriptor = vertex
    descriptor.fragmentFunctionDescriptor = fragment
    descriptor.inputPrimitiveTopology = .triangle
    let attachment = descriptor.colorAttachments[0]!
    attachment.pixelFormat = .bgra8Unorm
    if blend != .opaque {
        attachment.blendingState = .enabled
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = blend == .additiveSourceAlpha
            ? .one
            : .oneMinusSourceAlpha
        attachment.rgbBlendOperation = .add
        attachment.sourceAlphaBlendFactor = .sourceAlpha
        attachment.destinationAlphaBlendFactor = blend == .additiveSourceAlpha
            ? .one
            : .oneMinusSourceAlpha
        attachment.alphaBlendOperation = .add
    }
    return try compiler.makeRenderPipelineState(
        descriptor: descriptor,
        compilerTaskOptions: nil
    )
}

private func makeDepthState(
    device: any MTLDevice,
    writesDepth: Bool
) throws -> any MTLDepthStencilState {
    let descriptor = MTLDepthStencilDescriptor()
    descriptor.depthCompareFunction = .lessEqual
    descriptor.isDepthWriteEnabled = writesDepth
    guard let state = device.makeDepthStencilState(descriptor: descriptor) else {
        throw MetalWorldRendererError.allocationFailed("depth state")
    }
    return state
}

private func makeSampler(
    device: any MTLDevice,
    addressMode: MTLSamplerAddressMode
) -> (any MTLSamplerState)? {
    let descriptor = MTLSamplerDescriptor()
    descriptor.minFilter = .linear
    descriptor.magFilter = .linear
    descriptor.mipFilter = .notMipmapped
    descriptor.sAddressMode = addressMode
    descriptor.tAddressMode = addressMode
    return device.makeSamplerState(descriptor: descriptor)
}

private func makeBuffer<Value>(
    device: any MTLDevice,
    values: [Value]
) -> (any MTLBuffer)? {
    values.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress, !bytes.isEmpty else { return nil }
        return device.makeBuffer(
            bytes: baseAddress,
            length: bytes.count,
            options: .storageModeShared
        )
    }
}

private func makeRGBA8Texture(
    device: any MTLDevice,
    image: CanonicalRGBA8Image
) throws -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: image.width,
        height: image.height,
        mipmapped: false
    )
    descriptor.storageMode = .shared
    descriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: descriptor) else {
        throw MetalWorldRendererError.allocationFailed("RGBA texture")
    }
    replaceRGBA8(texture: texture, rgba8: image.rgba8)
    return texture
}

private func replaceRGBA8(
    texture: any MTLTexture,
    rgba8: Data
) {
    rgba8.withUnsafeBytes { bytes in
        texture.replace(
            region: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0,
            withBytes: bytes.baseAddress!,
            bytesPerRow: texture.width * 4
        )
    }
}

private func writeWorldUniforms(
    camera: RoomCamera,
    to buffer: any MTLBuffer
) {
    var uniforms = MetalWorldUniforms(worldToClip: worldToClip(camera))
    withUnsafeBytes(of: &uniforms) { bytes in
        buffer.contents().copyMemory(
            from: bytes.baseAddress!,
            byteCount: bytes.count
        )
    }
}

private func worldToClip(_ camera: RoomCamera) -> simd_float4x4 {
    let eye = SIMD3<Float>(camera.position.x, camera.position.y, camera.position.z)
    let target = SIMD3<Float>(camera.target.x, camera.target.y, camera.target.z)
    let suppliedUp = SIMD3<Float>(camera.up.x, camera.up.y, camera.up.z)
    let forward = simd_normalize(target - eye)
    let right = simd_normalize(simd_cross(forward, suppliedUp))
    let up = simd_cross(right, forward)

    let view = simd_float4x4(columns: (
        SIMD4<Float>(right.x, up.x, forward.x, 0),
        SIMD4<Float>(right.y, up.y, forward.y, 0),
        SIMD4<Float>(right.z, up.z, forward.z, 0),
        SIMD4<Float>(
            -simd_dot(eye, right),
            -simd_dot(eye, up),
            -simd_dot(eye, forward),
            1
        )
    ))
    let horizontalScale = 1 / tan(
        camera.projection.horizontalFieldOfViewRadians / 2
    )
    let verticalScale = horizontalScale * camera.projection.aspectRatio
    let projection = simd_float4x4(columns: (
        SIMD4<Float>(horizontalScale, 0, 0, 0),
        SIMD4<Float>(0, verticalScale, 0, 0),
        SIMD4<Float>(0, 0, 1, 1),
        SIMD4<Float>(0, 0, -0.5, 0)
    ))
    return projection * view
}
#endif
