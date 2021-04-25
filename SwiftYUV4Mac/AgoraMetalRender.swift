//
//  AgoraMetalRender.swift
//  Agora-Custom-Media-Device
//
//  Created by GongYuhua on 2017/11/15.
//  Copyright © 2017年 Agora.io All rights reserved.
//

import CoreMedia
import Metal
#if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
    import MetalKit
#endif
//import AgoraRtcKit

protocol AgoraMetalRenderMirrorDataSource: NSObjectProtocol {
    func renderViewShouldMirror(renderView: AgoraMetalRender) -> Bool
}

enum AgoraVideoRotation: Int {
    case rotationNone = 0
    case rotation90
    case rotation180
    case rotation270
}

enum AgoraVideoBufferType: Int {
    case pixelBuffer = 1
    case rawData = 2
}

enum AgoraVideoPixelFormat: Int {
    case I420 = 1
    case BGRA = 2
    case NV12 = 8
}

class AgoraMetalRender: NSView {
    weak var mirrorDataSource: AgoraMetalRenderMirrorDataSource?
    
    fileprivate var initialized: Bool = false
    fileprivate var textures: [MTLTexture]?
    fileprivate var vertexBuffer: MTLBuffer?
    fileprivate var viewSize = CGSize.zero

    fileprivate var device = MTLCreateSystemDefaultDevice()
    fileprivate var renderPipelineState: MTLRenderPipelineState?
    fileprivate let semaphore = DispatchSemaphore(value: 1)
    fileprivate var metalDevice = MTLCreateSystemDefaultDevice()
#if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
    fileprivate var metalView: MTKView!
    fileprivate var textureCache: CVMetalTextureCache?
#endif
    fileprivate var commandQueue: MTLCommandQueue?
    
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        viewSize = NSMakeSize(100, 100)
        initializeMetalView()
        initializeTextureCache()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initializeMetalView()
        initializeTextureCache()
    }
    
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        viewSize = frameRect.size
        initializeMetalView()
        initializeTextureCache()
    }
    
    
    override func layout() {
        super.layout()
        viewSize = bounds.size
    }
}

extension AgoraMetalRender {
    func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer, rotation: AgoraVideoRotation) {
    #if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess else {
            return
        }
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        let isPlanar = CVPixelBufferIsPlanar(pixelBuffer)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) : CVPixelBufferGetWidth(pixelBuffer)
            let height = isPlanar ? CVPixelBufferGetHeightOfPlane(pixelBuffer, 0) : CVPixelBufferGetHeight(pixelBuffer)
            let size = CGSize(width: width, height: height)
        if let renderedCoordinates = rotation.renderedCoordinates(mirror: false,
                                                                  videoSize: size,
                                                                  viewSize: viewSize) {
            let byteLength = 4 * MemoryLayout.size(ofValue: renderedCoordinates[0])
            vertexBuffer = device?.makeBuffer(bytes: renderedCoordinates, length: byteLength, options: [.storageModeShared])
        }
        
        if let yTexture = texture(pixelBuffer: pixelBuffer, textureCache: textureCache, planeIndex: 0, pixelFormat: .r8Unorm),
           let uTexture = texture(pixelBuffer: pixelBuffer, textureCache: textureCache, planeIndex: 1, pixelFormat: .r8Unorm) ,
           let vTexture = texture(pixelBuffer: pixelBuffer, textureCache: textureCache, planeIndex: 2, pixelFormat: .r8Unorm) {
           self.textures = [yTexture, uTexture,vTexture]

        }
    #endif
    }
}

extension AgoraMetalRender {
    func initializeMetalView() {
    #if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
        metalView = MTKView(frame: bounds, device: device)
        metalView.framebufferOnly = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.autoresizingMask = [.width, .height]
        addSubview(metalView)
        commandQueue = device?.makeCommandQueue()
    #endif
    }
    
    func initializeRenderPipelineState() {
        guard !initialized else {
            return
        }
        
        guard let device = device, let library = device.makeDefaultLibrary() else {
            return
        }
        initialized = true
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayNV12Texture")
        
        renderPipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
       
    }
    
    func initializeTextureCache() {
    #if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
        guard let metalDevice = metalDevice,
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache) == kCVReturnSuccess else {
            return
        }
    #endif
    }
    
#if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
    func texture(pixelBuffer: CVPixelBuffer, textureCache: CVMetalTextureCache?, planeIndex: Int = 0, pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture? {
        guard let textureCache = textureCache, CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess else {
            return nil
        }
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        let isPlanar = CVPixelBufferIsPlanar(pixelBuffer)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex) : CVPixelBufferGetWidth(pixelBuffer)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex) : CVPixelBufferGetHeight(pixelBuffer)
        
        var imageTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &imageTexture)
        
        guard let unwrappedImageTexture = imageTexture,
            let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
            result == kCVReturnSuccess
            else {
                return nil
        }
        
        return texture
    }
#endif
    
    func bindDelegate() {
        metalView.delegate = self
    }
    
    func unbindDelegate() {
        metalView.delegate = nil
    }
    
    func dispose() {
        _ = semaphore.wait(timeout: .distantFuture)
        textures = nil
        initialized = false
        vertexBuffer = nil
        #if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
        metalView.delegate = nil
        #endif
        semaphore.signal()
    }
}

#if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
extension AgoraMetalRender: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    public func draw(in: MTKView) {
        guard viewSize.width > 0 && viewSize.height > 0 else {
            return
        }
    
        _ = semaphore.wait(timeout: .distantFuture)
        guard let textures = textures, let device = device,
            let commandBuffer = commandQueue?.makeCommandBuffer(), let vertexBuffer = vertexBuffer  else {
            _ = semaphore.signal()
            return
        }
        
        render(textures: textures, withCommandBuffer: commandBuffer, device: device, vertexBuffer: vertexBuffer)
    }
    
    private func render(textures: [MTLTexture], withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice, vertexBuffer: MTLBuffer) {
        guard let currentRenderPassDescriptor = metalView.currentRenderPassDescriptor,
            let currentDrawable = metalView.currentDrawable,
            let renderPipelineState = renderPipelineState,
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor) else {
                semaphore.signal()
                return
        }
        
        encoder.pushDebugGroup("Agora-Custom-Render-Frame")
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        encoder.setFragmentTexture(textures[0], index: 0)
        encoder.setFragmentTexture(textures[1], index: 1)
        encoder.setFragmentTexture(textures[2], index: 2)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        
        encoder.popDebugGroup()
        encoder.endEncoding()
        
        commandBuffer.addScheduledHandler { [weak self] (buffer) in
            self?.semaphore.signal()
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
#endif

extension AgoraVideoRotation {
    func renderedCoordinates(mirror: Bool, videoSize: CGSize, viewSize: CGSize) -> [float4]? {
        guard viewSize.width > 0, viewSize.height > 0, videoSize.width > 0, videoSize.height > 0 else {
            return nil
        }
        
        let widthAspito: Float
        let heightAspito: Float
        if self == .rotation90 || self == .rotation270 {
            widthAspito = Float(videoSize.height / viewSize.width)
            heightAspito = Float(videoSize.width / viewSize.height)
        } else {
            widthAspito = Float(videoSize.width / viewSize.width)
            heightAspito = Float(videoSize.height / viewSize.height)
        }
        
        let x: Float
        let y: Float
        if widthAspito > heightAspito {
            x = 1
            y = heightAspito / widthAspito
        } else {
            x = widthAspito / heightAspito
            y = 1
        }
        
        let A = float4(  x, -y, 0.0, 1.0 )
        let B = float4( -x, -y, 0.0, 1.0 )
        let C = float4(  x,  y, 0.0, 1.0 )
        let D = float4( -x,  y, 0.0, 1.0 )
        
        switch self {
        case .rotationNone:
            if mirror {
                return [A, B, C, D]
            } else {
                return [B, A, D, C]
            }
        case .rotation90:
            if mirror {
                return [C, A, D, B]
            } else {
                return [D, B, C, A]
            }
        case .rotation180:
            if mirror {
                return [D, C, B, A]
            } else {
                return [C, D, A, B]
            }
        case .rotation270:
            if mirror {
                return [B, D, A, C]
            } else {
                return [A, C, B, D]
            }
        }
    }
}


class VMultiViewRender: NSObject {
    private var renderViews: [AgoraMetalRender] = []
    
    func addRenderView(view: AgoraMetalRender) {
        if renderViews.contains(view) {
            return
        }
        renderViews.append(view)
        view.initializeRenderPipelineState()
        view.bindDelegate()
        
    }
    
    func removeRenderView(view: AgoraMetalRender) {
        renderViews.removeAll { (renderView) -> Bool in
            return renderView == view
        }
    }
}

protocol AgoraVideoSinkProtocol {
    func shouldInitialize() -> Bool
    func shouldStart()
    func shouldStop()
    func shouldDispose()
    func bufferType() -> AgoraVideoBufferType
    func pixelFormat() -> AgoraVideoPixelFormat
    func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer, rotation: AgoraVideoRotation)
}

extension VMultiViewRender: AgoraVideoSinkProtocol {
    func shouldInitialize() -> Bool {
        for renderView in renderViews {
            renderView.initializeRenderPipelineState()
        }
        return true
    }
    
    func shouldStart() {
    #if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
        for renderView in renderViews {
            renderView.bindDelegate()
        }
    #endif
    }
    
    func shouldStop() {
    #if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
        for renderView in renderViews {
            renderView.unbindDelegate()
        }
    #endif
    }
    
    func shouldDispose() {
        for renderView in renderViews {
            renderView.dispose()
        }
    }
    
    func bufferType() -> AgoraVideoBufferType {
        return .pixelBuffer
    }
    
    func pixelFormat() -> AgoraVideoPixelFormat {
        return .NV12
    }
    
    func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer, rotation: AgoraVideoRotation) {
    #if os(macOS) || (os(iOS) && (!arch(i386) && !arch(x86_64)))
        for renderView in renderViews {
            if renderView.metalView.delegate == nil {
                renderView.bindDelegate()
            }
            renderView.renderPixelBuffer(pixelBuffer, rotation: rotation)
        }
    #endif
    }
}
