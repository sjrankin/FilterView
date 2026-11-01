//
//  MetalProcessor+MPS.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
//

import Foundation
import Metal
import MetalKit
import MetalPerformanceShaders

/// Metal Performance Shaders support. MPS kernels encode themselves onto a command buffer, so they cannot
/// go through `Run`, which only dispatches named compute kernels from the default library.
extension MetalProcessor
{
    /// Runs one or more MPS kernels on an image.
    /// - Parameter Input: The image to process.
    /// - Parameter ResultLevel: Mip level of the destination texture to return. Anything above 0 makes the destination
    /// texture mipmapped (for `MPSImagePyramid`), and the result is that level, which is smaller than `Input`.
    /// - Parameter Opaque: If true, the alpha channel of the result is ignored. Needed for kernels (such as Laplacian) that
    /// also process alpha and so can return a fully transparent image.
    /// - Parameter KeepSourceFormat: If true, the destination texture has the same pixel format as the source (usually BGRA)
    /// instead of RGBA. Needed when the encoder blits the source into the destination, since a blit copies bytes and
    /// would swap red and blue.
    /// - Parameter Encode: Encodes the kernels. Receives the device, the command buffer, the source texture, and the
    /// destination texture. Throw `FilterException` from here if setup fails.
    /// - Returns: The processed image. The same size as `Input` when `ResultLevel` is 0.
    /// - Throws: `FilterException` if Metal Performance Shaders are unavailable, `Encode` throws, or the image cannot be converted.
    func RunMPS(On Input: CGImage,
                ResultLevel: Int = 0,
                Opaque: Bool = false,
                KeepSourceFormat: Bool = false,
                Encode: (MTLDevice, MTLCommandBuffer, MTLTexture, MTLTexture) throws -> Void) async throws -> CGImage
    {
        guard let Device = Device,
              let Queue = Queue,
              MPSSupportsMTLDevice(Device) else
        {
            throw FilterException(Message: "Metal Performance Shaders are not available")
        }

        let Source = try MakeSourceTexture(From: Input)
        let Descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: KeepSourceFormat ? Source.pixelFormat : .rgba8Unorm,
                                                                  width: Source.width,
                                                                  height: Source.height,
                                                                  mipmapped: ResultLevel > 0)
        Descriptor.usage = [.shaderRead, .shaderWrite]
        guard let Destination = Device.makeTexture(descriptor: Descriptor),
              let Buffer = Queue.makeCommandBuffer() else
        {
            throw FilterException(Message: "Metal setup failed")
        }
        guard ResultLevel < Destination.mipmapLevelCount else
        {
            throw FilterException(Message: "Image is too small for pyramid level \(ResultLevel)")
        }

        try Encode(Device, Buffer, Source, Destination)

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

        return try MakeImage(From: Destination, Level: ResultLevel, Opaque: Opaque)
    }
}
