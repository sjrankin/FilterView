//
//  MetalProcessor.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

import Foundation
import Metal
import MetalKit

/// Runs any compute kernel from the app's default Metal library on a `CGImage`.
/// Kernels must use this signature:
///
/// - `texture(0)`: the input image, `access::read`.
/// - `texture(1)`: the output image, `access::write`.
/// - `thread_position_in_grid`: the pixel being processed.
/// - Optionally, `buffer(0)`: `constant float*` (or a `constant float&` for one value) holding `Parameters`.
actor MetalProcessor
{
    /// Shared instance. Device, queue, library, and compiled kernels are created once and reused.
    static let Shared = MetalProcessor()

    private let Device: MTLDevice?
    private let Queue: MTLCommandQueue?
    private let Library: MTLLibrary?
    private let Loader: MTKTextureLoader?
    private var Pipelines = [String: MTLComputePipelineState]()

    init()
    {
        let Gpu = MTLCreateSystemDefaultDevice()
        Device = Gpu
        Queue = Gpu?.makeCommandQueue()
        Library = Gpu?.makeDefaultLibrary()
        Loader = Gpu.map{MTKTextureLoader(device: $0)}
    }

    /// Returns the compiled pipeline for a kernel, compiling and caching it on first use.
    /// - Parameter Kernel: Name of the kernel function in the default library.
    /// - Returns: The pipeline state for the kernel.
    /// - Throws: `FilterException` if Metal is unavailable or the kernel does not exist.
    private func Pipeline(For Kernel: String) throws -> MTLComputePipelineState
    {
        if let Cached = Pipelines[Kernel]
        {
            return Cached
        }
        guard let Device = Device,
              let Library = Library else
        {
            throw FilterException(Message: "Metal is not available")
        }
        guard let Function = Library.makeFunction(name: Kernel) else
        {
            throw FilterException(Message: "Metal kernel \(Kernel) not found")
        }
        let State = try Device.makeComputePipelineState(function: Function)
        Pipelines[Kernel] = State
        return State
    }

    /// Runs a kernel on an image.
    /// - Parameter Kernel: Name of the kernel function in the default Metal library.
    /// - Parameter Input: The image to process.
    /// - Parameter Parameters: Values passed to the kernel at `buffer(0)`. Pass nothing if the kernel takes none.
    /// - Returns: The processed image, the same size as `Input`.
    /// - Throws: `FilterException` if Metal is unavailable, the kernel does not exist, or the image cannot be converted.
    func Run(Kernel: String, On Input: CGImage, Parameters: [Float] = []) async throws -> CGImage
    {
        let State = try Pipeline(For: Kernel)
        guard let Device = Device,
              let Queue = Queue,
              let Loader = Loader else
        {
            throw FilterException(Message: "Metal is not available")
        }

        let Source = try await Loader.newTexture(cgImage: Input, options: [.SRGB: false])
        let Width = Source.width
        let Height = Source.height

        let Descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                  width: Width,
                                                                  height: Height,
                                                                  mipmapped: false)
        Descriptor.usage = [.shaderRead, .shaderWrite]
        guard let Destination = Device.makeTexture(descriptor: Descriptor),
              let Buffer = Queue.makeCommandBuffer(),
              let Encoder = Buffer.makeComputeCommandEncoder() else
        {
            throw FilterException(Message: "Metal setup failed")
        }

        Encoder.setComputePipelineState(State)
        Encoder.setTexture(Source, index: 0)
        Encoder.setTexture(Destination, index: 1)
        if !Parameters.isEmpty
        {
            Encoder.setBytes(Parameters, length: MemoryLayout<Float>.stride * Parameters.count, index: 0)
        }
        let GroupWidth = State.threadExecutionWidth
        let GroupHeight = State.maxTotalThreadsPerThreadgroup / GroupWidth
        Encoder.dispatchThreads(MTLSize(width: Width, height: Height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: GroupWidth, height: GroupHeight, depth: 1))
        Encoder.endEncoding()

        await withCheckedContinuation
        {
            Continuation in
            Buffer.addCompletedHandler
            {
                _ in
                Continuation.resume()
            }
            Buffer.commit()
        }

        return try MakeImage(From: Destination)
    }

    /// Copies the pixels of an `rgba8Unorm` texture into a `CGImage`.
    /// - Parameter Texture: The texture to read.
    /// - Returns: The image.
    /// - Throws: `FilterException` if the image cannot be created.
    private func MakeImage(From Texture: MTLTexture) throws -> CGImage
    {
        let Width = Texture.width
        let Height = Texture.height
        let BytesPerRow = Width * 4
        var Pixels = [UInt8](repeating: 0, count: BytesPerRow * Height)
        Texture.getBytes(&Pixels,
                         bytesPerRow: BytesPerRow,
                         from: MTLRegionMake2D(0, 0, Width, Height),
                         mipmapLevel: 0)
        guard let Provider = CGDataProvider(data: Data(Pixels) as CFData),
              let Result = CGImage(width: Width,
                                   height: Height,
                                   bitsPerComponent: 8,
                                   bitsPerPixel: 32,
                                   bytesPerRow: BytesPerRow,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                   provider: Provider,
                                   decode: nil,
                                   shouldInterpolate: false,
                                   intent: .defaultIntent) else
        {
            throw FilterException(Message: "Could not make image from Metal texture")
        }
        return Result
    }
}
