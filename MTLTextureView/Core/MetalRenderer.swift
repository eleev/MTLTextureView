//
//  MetalRenderer.swift
//  TextureView
//
//  Created by Astemir Eleev on 02.04.2023.
//

import Foundation
import Metal
import MetalKit

/// Bare-bones metal renderer implementation. By default it's lazy e.g. draws only when data changes. The shaders are pretty straightforward, however you can use it create additional shader transitions and adjust for your needs.
final class MetalRenderer: NSObject, MTKViewDelegate {
   
    // MARK: - Properties
    
    private weak var mtkView: MTKView?
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let renderPipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private var texture: MTLTexture
    
    private let defaultImageScaleFactor: CGFloat = 1.0
    private let vertexShaderName: String = "vertex_passthrough"
    private let fragmentShaderName: String = "sampling_linear"
    
    // MARK: - Initializers
    
    init?(mtkView: MTKView, imageName name: String, in bundle: Bundle = .main) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
        
        self.mtkView = mtkView
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.autoResizeDrawable = true
        
        let layer = mtkView.layer as? CAMetalLayer
        layer?.framebufferOnly = true
        layer?.isOpaque = false
        layer?.maximumDrawableCount = 2
        
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: vertexShaderName),
              let fragmentFunction = library.makeFunction(name: fragmentShaderName) else {
            return nil
        }
        
        func pipelineDescriptor() -> MTLRenderPipelineDescriptor {
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false
            return pipelineDescriptor
        }
        
        func vertexDescriptor() -> MTLVertexDescriptor {
            let vertexDescriptor = MTLVertexDescriptor()
            
            // Position attribute
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            
            // Texture coordinates attribute
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float2>.stride
            vertexDescriptor.attributes[1].bufferIndex = 0
            
            vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex
            
            return vertexDescriptor
        }

        let pipelineDescriptor = pipelineDescriptor()
        pipelineDescriptor.vertexDescriptor = vertexDescriptor()

        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
            return nil
        }

        func samplerDescriptor() -> MTLSamplerDescriptor {
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.mipFilter = .linear
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge

            return samplerDescriptor
        }

        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor()) else {
            print("Failed to create sampler state")
            return nil
        }
        samplerState = sampler

        let textureLoader = MTKTextureLoader(device: device)
        guard let texture = try? textureLoader.newTexture(
            name: name,
            scaleFactor: defaultImageScaleFactor,
            bundle: bundle
        ) else {
            print("Failed to load texture")
            return nil
        }
        self.texture = texture
        
        super.init()

        mtkView.delegate = self
    }
     
    // MARK: - Delegates
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle any necessary updates due to a drawable size change
        _draw(in: view)
    }
    
    func draw(in view: MTKView) {
        // If you need to redraw each update cycle
        /*
        _draw(in: view)
         */
    }
    
    // MARK: - Methods
    
    func setImage(named name: String, in bundle: Bundle = .main) {
        guard let mtkView else {
            fatalError("Attempted to assign an image while the view has been released")
        }
        let textureLoader = MTKTextureLoader(device: device)
        
        guard let texture = try? textureLoader.newTexture(
            name: name,
            scaleFactor: defaultImageScaleFactor,
            bundle: bundle
        ) else {
            print("Failed to load texture")
            return
        }
        
        self.texture = texture
        _draw(in: mtkView)
    }
    
    // MARK: - Implmentation Details
    
    private func _draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        func aspectFit() -> [Vertex] {
            let imageAspect = Float(texture.width) / Float(texture.height)
            let viewAspect = Float(view.bounds.width) / Float(view.bounds.height)

            var scaleX: Float = 1.0
            var scaleY: Float = 1.0

            if viewAspect > imageAspect {
                scaleY = imageAspect / viewAspect
            } else {
                scaleX = viewAspect / imageAspect
            }

            let quadVertices = [
                Vertex(position: [-scaleY, -scaleX], texCoord: [0, 1]),
                Vertex(position: [-scaleY,  scaleX], texCoord: [0, 0]),
                Vertex(position: [ scaleY, -scaleX], texCoord: [1, 1]),
                Vertex(position: [ scaleY,  scaleX], texCoord: [1, 0])
            ]
            return quadVertices
        }
        
        let quadVertices = aspectFit()
       
        guard let vertexBuffer = device.makeBuffer(bytes: quadVertices, length: MemoryLayout<Vertex>.stride * quadVertices.count, options: []) else {
            print("Failed to create vertex buffer")
            return
        }
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

struct Vertex {
    var position: simd_float2
    var texCoord: simd_float2
}
