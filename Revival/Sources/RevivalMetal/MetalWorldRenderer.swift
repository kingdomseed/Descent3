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

func fullDrawableMetalViewport(
    drawableWidth: Double,
    drawableHeight: Double
) -> MTLViewport {
    return MTLViewport(
        originX: 0,
        originY: 0,
        width: drawableWidth,
        height: drawableHeight,
        znear: 0,
        zfar: 1
    )
}

func cameraMonitorMetalViewport(
    drawableWidth: Double,
    drawableHeight: Double
) -> MTLViewport {
    let normalSize = drawableHeight / 4
    let spacing = (drawableWidth - 3 * normalSize) / 3
    let centerX = (spacing + normalSize) / 2
    let centerY = drawableHeight - normalSize / 2 - drawableHeight / 24
    let popupSize = normalSize + normalSize / 4
    return MTLViewport(
        originX: centerX - popupSize / 2,
        originY: centerY - popupSize / 2,
        width: popupSize,
        height: popupSize,
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
    private let coronaDepthState: any MTLDepthStencilState
    private let argumentTable: any MTL4ArgumentTable
    private let baseSampler: any MTLSamplerState
    private let lightmapSampler: any MTLSamplerState
    private let frameResidency: any MTLResidencySet
    private let completionEvent: any MTLSharedEvent
    private let frameSlots: [MetalFrameSlot]

    private var presentation: MetalLevelPresentation?
    private var nextSlotIndex = 0
    private var submittedValue: UInt64 = 0
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
        coronaDepthState = try makeCoronaDepthState(device: device)

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
                    length: 2 * metalWorldUniformStride,
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
            camera: cameraWithDrawableAspect(camera),
            startRoomSourceIndex: startRoomSourceIndex
        )
        try install(candidate)
    }

    func replace(level: Level, playerView: PlayerView) throws {
        try install(
            try makeMetalWorldPlan(
                level: level,
                playerView: playerViewWithDrawableAspect(playerView)
            )
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
                playerView: playerViewWithDrawableAspect(playerView)
            )
        )
    }

    func update(level: Level, frame: PlayerSimulationFrame) throws {
        guard let presentation else {
            try replace(level: level, playerView: frame.playerView)
            return
        }
        presentation.update(
            try updateMetalWorldPlan(
                presentation.plan,
                level: level,
                playerView: playerViewWithDrawableAspect(frame.playerView),
                presentationFrame: .init(
                    systemsFrameDuration: frame.systemsFrameDuration,
                    systemsGameTime: frame.systemsGameTime
                ),
                trainingCameraMonitor: frame.trainingCameraMonitor,
                trainingCloak: frame.trainingCloak,
                    trainingDodgeTurretAngles:
                        frame.trainingDodgeTurretAngles,
                    trainingDodgeProjectiles:
                        frame.trainingDodgeProjectiles,
                    trainingPrimaryProjectiles:
                        frame.trainingPrimaryProjectiles,
                    trainingGuidebotYellowFlares:
                        frame.trainingGuidebotYellowFlares,
                    trainingGuidebotYellowFlareParticles:
                        frame.trainingGuidebotYellowFlareParticles,
                    trainingGuidebotYellowFlareTimeoutExplosions:
                        frame.trainingGuidebotYellowFlareTimeoutExplosions,
                    trainingGuidebotYellowFlareTimeoutSparks:
                        frame.trainingGuidebotYellowFlareTimeoutSparks,
                    trainingGuidebotYellowFlareTimeoutSparkParticles:
                        frame.trainingGuidebotYellowFlareTimeoutSparkParticles,
                    trainingDodgeMarkerLightDistance:
                        frame.trainingDodgeMarkerLightDistance,
                trainingGuidebotReturnMarkerLightDistance:
                    frame.trainingGuidebotReturnMarkerLightDistance,
                trainingLastRoomMarkerLightDistance:
                    frame.trainingLastRoomMarkerLightDistance,
                trainingFinalBotsMarkerLightDistance:
                    frame.trainingFinalBotsMarkerLightDistance
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
        guard presentation != nil,
              let slotIndex = availableFrameSlotIndex(),
              let drawable = view.currentDrawable,
              let renderPass = view.currentMTL4RenderPassDescriptor else {
            return
        }
        frameUpdate?(CACurrentMediaTime())
        guard let presentation else { return }
        let slot = frameSlots[slotIndex]
        guard let depthTexture = makeDepthTextureIfNeeded(
            for: slot,
            drawableSize: view.drawableSize
        ) else {
            return
        }

        presentation.updateWorldVertices(frameSlotIndex: slotIndex)
        presentation.updateProceduralTextures(
            frameSlotIndex: slotIndex,
            visualTick: presentation.plan.presentationVisualTick
        )
        presentation.updateCoronaDraws(frameSlotIndex: slotIndex)
        writeWorldUniforms(
            camera: presentation.plan.camera,
            to: slot.uniformBuffer,
            offset: 0
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
            fullDrawableMetalViewport(
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
                presentation.worldVertexBuffer(
                    frameSlotIndex: slotIndex
                ).gpuAddress + UInt64(draw.vertexByteOffset),
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
        if !presentation.coronaDraws.isEmpty {
            encoder.setRenderPipelineState(additivePipeline)
            encoder.setDepthStencilState(coronaDepthState)
            for draw in presentation.coronaDraws {
                argumentTable.setAddress(
                    presentation.coronaVertexBuffer(
                        frameSlotIndex: slotIndex
                    ).gpuAddress + UInt64(draw.vertexByteOffset),
                    index: 0
                )
                argumentTable.setTexture(
                    presentation.coronaTexture(
                        assetIndex: draw.assetIndex
                    ).gpuResourceID,
                    index: 0
                )
                argumentTable.setTexture(
                    presentation.whiteLightmap.gpuResourceID,
                    index: 1
                )
                encoder.drawIndexedPrimitives(
                    primitiveType: .triangle,
                    indexCount: draw.indexCount,
                    indexType: .uint32,
                    indexBuffer: presentation.coronaIndexBuffer.gpuAddress
                        + UInt64(draw.indexByteOffset),
                    indexBufferLength: presentation.coronaIndexBuffer.length
                        - draw.indexByteOffset
                )
            }
        }
        encoder.endEncoding()

        if let auxiliaryCamera = presentation.plan.auxiliaryCamera,
           !presentation.auxiliaryDraws.isEmpty {
            let viewport = cameraMonitorMetalViewport(
                drawableWidth: Double(view.drawableSize.width),
                drawableHeight: Double(view.drawableSize.height)
            )
            writeWorldUniforms(
                camera: RoomCamera(
                    position: auxiliaryCamera.position,
                    target: auxiliaryCamera.target,
                    up: auxiliaryCamera.up,
                    projection: auxiliaryCamera.projection.withAspectRatio(
                        Float(viewport.width / viewport.height)
                    )
                ),
                to: slot.uniformBuffer,
                offset: metalWorldUniformStride
            )
            renderPass.colorAttachments[0]?.loadAction = .load
            renderPass.depthAttachment.loadAction = .clear
            renderPass.depthAttachment.clearDepth = 1
            guard let auxiliaryEncoder =
                    slot.commandBuffer.makeRenderCommandEncoder(
                        descriptor: renderPass
                    ) else {
                slot.commandBuffer.endCommandBuffer()
                return
            }
            auxiliaryEncoder.setViewport(viewport)
            auxiliaryEncoder.setCullMode(.none)
            argumentTable.setAddress(
                slot.uniformBuffer.gpuAddress
                    + UInt64(metalWorldUniformStride),
                index: 1
            )
            auxiliaryEncoder.setArgumentTable(
                argumentTable,
                stages: [.vertex, .fragment]
            )
            var auxiliaryBlend: MetalWorldBlendMode?
            var auxiliaryDepthWrite: Bool?
            for draw in presentation.auxiliaryDraws {
                let blend: MetalWorldBlendMode
                switch draw.blend {
                case .opaque: blend = .opaque
                case .sourceAlpha: blend = .sourceAlpha
                case .additiveSourceAlpha:
                    blend = .additiveSourceAlpha
                }
                if auxiliaryBlend != blend {
                    switch blend {
                    case .opaque:
                        auxiliaryEncoder.setRenderPipelineState(
                            opaquePipeline
                        )
                    case .sourceAlpha:
                        auxiliaryEncoder.setRenderPipelineState(
                            sourceAlphaPipeline
                        )
                    case .additiveSourceAlpha:
                        auxiliaryEncoder.setRenderPipelineState(
                            additivePipeline
                        )
                    }
                    auxiliaryBlend = blend
                }
                if auxiliaryDepthWrite != draw.writesDepth {
                    auxiliaryEncoder.setDepthStencilState(
                        draw.writesDepth
                            ? opaqueDepthState
                            : translucentDepthState
                    )
                    auxiliaryDepthWrite = draw.writesDepth
                }
                argumentTable.setAddress(
                    presentation.worldVertexBuffer(
                        frameSlotIndex: slotIndex
                    ).gpuAddress + UInt64(draw.vertexByteOffset),
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
                auxiliaryEncoder.drawIndexedPrimitives(
                    primitiveType: .triangle,
                    indexCount: draw.indexCount,
                    indexType: .uint32,
                    indexBuffer: presentation.indexBuffer.gpuAddress
                        + UInt64(draw.indexByteOffset),
                    indexBufferLength: presentation.indexBuffer.length
                        - draw.indexByteOffset
                )
            }
            auxiliaryEncoder.endEncoding()
        }
        slot.commandBuffer.endCommandBuffer()

        submittedValue += 1
        queue.waitForDrawable(drawable)
        queue.commit([slot.commandBuffer])
        queue.signalEvent(completionEvent, value: submittedValue)
        queue.signalDrawable(drawable)
        drawable.present()

        slot.completionValue = submittedValue
        nextSlotIndex = (slotIndex + 1) % frameSlots.count
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drainFinalGPUUse()
        for slot in frameSlots {
            slot.depthTexture = nil
            slot.depthSize = .zero
        }
        guard let presentation else { return }
        do {
            presentation.update(
                try updateMetalWorldPlan(
                    presentation.plan,
                    camera: cameraWithDrawableAspect(presentation.plan.camera)
                )
            )
        } catch {
            preconditionFailure(
                "A validated retained presentation must survive drawable resize: \(error)"
            )
        }
    }

    private func cameraWithDrawableAspect(_ camera: RoomCamera) -> RoomCamera {
        let width = Float(view.drawableSize.width)
        let height = Float(view.drawableSize.height)
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return camera
        }
        return RoomCamera(
            position: camera.position,
            target: camera.target,
            up: camera.up,
            projection: camera.projection.withAspectRatio(width / height)
        )
    }

    private func playerViewWithDrawableAspect(_ playerView: PlayerView) -> PlayerView {
        PlayerView(
            playerID: playerView.playerID,
            objectHandle: playerView.objectHandle,
            roomSourceIndex: playerView.roomSourceIndex,
            camera: cameraWithDrawableAspect(playerView.camera),
            collisionRadius: playerView.collisionRadius
        )
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

private let metalWorldUniformStride = 256

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

private struct MetalEncodedCoronaDraw {
    let assetIndex: Int
    let vertexByteOffset: Int
    let indexByteOffset: Int
    let indexCount: Int
}

@MainActor
private final class MetalLevelPresentation {
    private(set) var plan: MetalWorldPlan
    let residencySet: any MTLResidencySet
    let indexBuffer: any MTLBuffer
    private(set) var draws: [MetalEncodedDraw]
    private(set) var auxiliaryDraws: [MetalEncodedDraw]
    private(set) var coronaDraws: [MetalEncodedCoronaDraw] = []
    let coronaIndexBuffer: any MTLBuffer
    let whiteLightmap: any MTLTexture

    private let preparedDraws: [MetalEncodedDraw]
    private let vertexBuffers: [any MTLBuffer]
    private let materials: [SourceResource: MetalMaterialResources]
    private let lightmaps: [Int: any MTLTexture]
    private let coronaVertexBuffers: [any MTLBuffer]
    private let coronaTextures: [any MTLTexture]

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
        var vertexBuffers: [any MTLBuffer] = []
        for _ in 0..<frameSlotCount {
            guard let buffer = makeBuffer(
                device: device,
                values: packedVertices
            ) else {
                throw MetalWorldRendererError.allocationFailed(
                    "world geometry"
                )
            }
            vertexBuffers.append(buffer)
        }
        guard let indexBuffer = makeBuffer(
            device: device,
            values: packedIndices
        ) else {
            throw MetalWorldRendererError.allocationFailed("world geometry")
        }
        self.vertexBuffers = vertexBuffers
        self.indexBuffer = indexBuffer
        preparedDraws = encodedDraws
        draws = plan.activeDrawIndices.map { encodedDraws[$0] }
        auxiliaryDraws = plan.auxiliaryActiveDrawIndices.map {
            encodedDraws[$0]
        }

        let coronaCapacity = max(
            1,
            plan.level.rooms.reduce(0) { count, room in
                count + room.faces.filter(\.allowsLightCorona).count
            }
        )
        var coronaVertexBuffers: [any MTLBuffer] = []
        for _ in 0..<frameSlotCount {
            guard let buffer = device.makeBuffer(
                length: coronaCapacity * 4 * MemoryLayout<MetalWorldVertex>.stride,
                options: .storageModeShared
            ) else {
                throw MetalWorldRendererError.allocationFailed("corona geometry")
            }
            coronaVertexBuffers.append(buffer)
        }
        self.coronaVertexBuffers = coronaVertexBuffers
        let coronaIndices = makeMetalLightCoronaIndices(
            drawCapacity: coronaCapacity
        )
        guard let coronaIndexBuffer = makeBuffer(
            device: device,
            values: coronaIndices
        ) else {
            throw MetalWorldRendererError.allocationFailed("corona indices")
        }
        self.coronaIndexBuffer = coronaIndexBuffer
        coronaTextures = try plan.level.presentationCoronaAssets.map {
            try makeRGBA8Texture(device: device, image: $0.image)
        }

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
        descriptor.initialCapacity = 2 + vertexBuffers.count
            + materialResources.values.reduce(0) { $0 + $1.textures.count }
            + lightmapTextures.count
            + coronaVertexBuffers.count
            + coronaTextures.count
            + 1
        residencySet = try device.makeResidencySet(descriptor: descriptor)
        for buffer in vertexBuffers {
            residencySet.addAllocation(buffer)
        }
        residencySet.addAllocation(indexBuffer)
        residencySet.addAllocation(coronaIndexBuffer)
        for buffer in coronaVertexBuffers {
            residencySet.addAllocation(buffer)
        }
        for texture in coronaTextures {
            residencySet.addAllocation(texture)
        }
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
        precondition(
            plan.preparedDraws.count == self.plan.preparedDraws.count
                && zip(plan.preparedDraws, self.plan.preparedDraws)
                    .allSatisfy {
                        $0.vertices.count == $1.vertices.count
                            && $0.indices == $1.indices
                            && $0.texture == $1.texture
                            && $0.blend == $1.blend
                            && $0.lightmapPageIndex
                                == $1.lightmapPageIndex
                    }
        )
        self.plan = plan
        draws = plan.activeDrawIndices.map { preparedDraws[$0] }
        auxiliaryDraws = plan.auxiliaryActiveDrawIndices.map {
            preparedDraws[$0]
        }
    }

    func updateWorldVertices(frameSlotIndex: Int) {
        let vertices = plan.preparedDraws.flatMap(\.vertices)
        let buffer = vertexBuffers[frameSlotIndex]
        vertices.withUnsafeBytes { bytes in
            precondition(bytes.count == buffer.length)
            buffer.contents().copyMemory(
                from: bytes.baseAddress!,
                byteCount: bytes.count
            )
        }
    }

    func worldVertexBuffer(
        frameSlotIndex: Int
    ) -> any MTLBuffer {
        vertexBuffers[frameSlotIndex]
    }

    func updateProceduralTextures(
        frameSlotIndex: Int,
        visualTick: Int
    ) {
        for material in materials.values {
            material.updateProceduralTexture(
                frameSlotIndex: frameSlotIndex,
                visualTick: visualTick
            )
        }
    }

    func updateCoronaDraws(frameSlotIndex: Int) {
        var vertices: [MetalWorldVertex] = []
        var encoded: [MetalEncodedCoronaDraw] = []
        for (index, draw) in plan.lightCoronaDraws.enumerated() {
            let asset = plan.level.presentationCoronaAssets[draw.corona.assetIndex]
            vertices += makeMetalLightCoronaVertices(
                draw.corona,
                camera: plan.camera,
                imageWidth: asset.image.width,
                imageHeight: asset.image.height,
                opacity: draw.opacity
            )
            encoded.append(
                MetalEncodedCoronaDraw(
                    assetIndex: draw.corona.assetIndex,
                    vertexByteOffset: index * 4
                        * MemoryLayout<MetalWorldVertex>.stride,
                    indexByteOffset: index * 6 * MemoryLayout<UInt32>.stride,
                    indexCount: 6
                )
            )
        }
        vertices.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress else { return }
            coronaVertexBuffers[frameSlotIndex].contents().copyMemory(
                from: source,
                byteCount: bytes.count
            )
        }
        coronaDraws = encoded
    }

    func coronaVertexBuffer(frameSlotIndex: Int) -> any MTLBuffer {
        coronaVertexBuffers[frameSlotIndex]
    }

    func coronaTexture(assetIndex: Int) -> any MTLTexture {
        coronaTextures[assetIndex]
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
        visualTick: Int
    ) {
        guard var evaluator else { return }
        let rgba8 = evaluator.rgba8(visualTick: visualTick)
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

private func makeCoronaDepthState(
    device: any MTLDevice
) throws -> any MTLDepthStencilState {
    let descriptor = MTLDepthStencilDescriptor()
    descriptor.depthCompareFunction = .always
    descriptor.isDepthWriteEnabled = false
    guard let state = device.makeDepthStencilState(descriptor: descriptor) else {
        throw MetalWorldRendererError.allocationFailed("corona depth state")
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

func makeMetalLightCoronaIndices(drawCapacity: Int) -> [UInt32] {
    precondition(drawCapacity >= 0)
    return (0..<drawCapacity).flatMap { _ in
        [0, 1, 2, 0, 2, 3]
    }
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
    to buffer: any MTLBuffer,
    offset: Int
) {
    var uniforms = MetalWorldUniforms(worldToClip: worldToClip(camera))
    withUnsafeBytes(of: &uniforms) { bytes in
        buffer.contents().advanced(by: offset).copyMemory(
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
