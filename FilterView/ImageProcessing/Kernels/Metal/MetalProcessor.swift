//
//  MetalProcessor.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/28/26.
//
//  Copyright 2026 Stuart Rankin
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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

    /// Internal (not private) so `MetalProcessor+MPS.swift` can use it.
    let Device: MTLDevice?
    /// Internal (not private) so `MetalProcessor+MPS.swift` can use it.
    let Queue: MTLCommandQueue?
    private let Library: MTLLibrary?
    private var Pipelines = [String: MTLComputePipelineState]()

    init()
    {
        let GPU = MTLCreateSystemDefaultDevice()
        Device = GPU
        Queue = GPU?.makeCommandQueue()
        Library = GPU?.makeDefaultLibrary()
    }

    /// Returns the compiled pipeline (from `Run`) for a kernel, compiling and caching it on first use.
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
    /// - Note: Currently no kernels take any parameters but in the future, some will.
    func Run(Kernel: String, On Input: CGImage, Parameters: [Float] = []) async throws -> CGImage
    {
        let State = try Pipeline(For: Kernel)
        guard let Device = Device,
              let Queue = Queue else
        {
            throw FilterException(Message: "Metal is not available")
        }

        // Create a texture from the image.
        let Source = try MakeSourceTexture(From: Input)
        let Width = Source.width
        let Height = Source.height

        let Descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                  width: Width,
                                                                  height: Height,
                                                                  mipmapped: false)
        Descriptor.usage = [.shaderRead, .shaderWrite]
        // Create the destination buffer for the results.
        guard let Destination = Device.makeTexture(descriptor: Descriptor),
              let Buffer = Queue.makeCommandBuffer(),
              let Encoder = Buffer.makeComputeCommandEncoder() else
        {
            throw FilterException(Message: "Metal setup failed")
        }

        // Create the compute pipeline.
        // Add the pipeline state - set the kernel to run.
        Encoder.setComputePipelineState(State)
        // Set the source image. It will not be changed.
        Encoder.setTexture(Source, index: 0)
        // Set the destination. It will be changed.
        Encoder.setTexture(Destination, index: 1)
        if !Parameters.isEmpty
        {
            // Save parameters as Floats. The parameters are context sensitive for each kernel.
            Encoder.setBytes(Parameters, length: MemoryLayout<Float>.stride * Parameters.count, index: 0)
        }
        // Calculate the thread count.
        let GroupWidth = State.threadExecutionWidth
        let GroupHeight = State.maxTotalThreadsPerThreadgroup / GroupWidth
        // Set the number of threads.
        Encoder.dispatchThreads(MTLSize(width: Width, height: Height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: GroupWidth, height: GroupHeight, depth: 1))
        // Mark the end of encoder data.
        Encoder.endEncoding()

        await withCheckedContinuation
        {
            Continuation in
            // Set the completion handler for the command buffer.
            Buffer.addCompletedHandler
            {
                _ in
                Continuation.resume()
            }
            
            // Run the kernel on the GPU.
            Buffer.commit()
        }

        // Return the resultant image. Throws an exception on error.
        return try MakeImage(From: Destination)
    }

    /// Copies the pixels of an `rgba8Unorm` or `bgra8Unorm` texture into a `CGImage`.
    /// - Parameter Texture: The texture to read.
    /// - Parameter Level: Mip level to read. The image is the size of that level.
    /// - Parameter Opaque: If true, the alpha channel is ignored and the image is fully opaque.
    /// - Returns: The converted image.
    /// - Throws: `FilterException` if the image cannot be created.
    func MakeImage(From Texture: MTLTexture, Level: Int = 0, Opaque: Bool = false) throws -> CGImage
    {
        let Width = max(Texture.width >> Level, 1)
        let Height = max(Texture.height >> Level, 1)
        let BytesPerRow = Width * 4
        var Pixels = [UInt8](repeating: 0, count: BytesPerRow * Height)
        Texture.getBytes(&Pixels,
                         bytesPerRow: BytesPerRow,
                         from: MTLRegionMake2D(0, 0, Width, Height),
                         mipmapLevel: Level)
        // Textures from `MTKTextureLoader` are usually BGRA, which CoreGraphics reads as little-endian alpha-first.
        let IsBGRA = Texture.pixelFormat == .bgra8Unorm
        let Alpha: CGImageAlphaInfo = Opaque ? (IsBGRA ? .noneSkipFirst : .noneSkipLast) : (IsBGRA ? .premultipliedFirst : .premultipliedLast)
        let Info = CGBitmapInfo(rawValue: Alpha.rawValue | (IsBGRA ? CGBitmapInfo.byteOrder32Little.rawValue : 0))
        guard let Provider = CGDataProvider(data: Data(Pixels) as CFData),
              let Result = CGImage(width: Width,
                                   height: Height,
                                   bitsPerComponent: 8,
                                   bitsPerPixel: 32,
                                   bytesPerRow: BytesPerRow,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: Info,
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
