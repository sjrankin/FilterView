//
//  MetalProcessor+MPS.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
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
    /// - Parameter Monochrome: If true, the destination texture has one channel, so a kernel that can make a monochrome result (such as
    /// Canny) converts the source to gray first. The result is made opaque gray, as an RGBA image.
    /// - Parameter Encode: Encodes the kernels. Receives the device, the command buffer, the source texture, and the
    /// destination texture. Throw `FilterException` from here if setup fails.
    /// - Returns: The processed image. The same size as `Input` when `ResultLevel` is 0.
    /// - Throws: `FilterException` if Metal Performance Shaders are unavailable, `Encode` throws, or the image cannot be converted.
    func RunMPS(On Input: CGImage,
                ResultLevel: Int = 0,
                Opaque: Bool = false,
                KeepSourceFormat: Bool = false,
                Monochrome: Bool = false,
                Encode: (MTLDevice, MTLCommandBuffer, MTLTexture, MTLTexture) throws -> Void) async throws -> CGImage
    {
        guard let Device = Device,
              let Queue = Queue,
              MPSSupportsMTLDevice(Device) else
        {
            throw FilterException(Message: "Metal Performance Shaders are not available")
        }

        let Source = try MakeSourceTexture(From: Input)
        let Format: MTLPixelFormat = Monochrome ? .r8Unorm : (KeepSourceFormat ? Source.pixelFormat : .rgba8Unorm)
        let Descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Format,
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

        if Monochrome
        {
            return try MakeGrayImage(From: Destination)
        }
        return try MakeImage(From: Destination, Level: ResultLevel, Opaque: Opaque)
    }

    /// Copies a one-channel `r8Unorm` texture into an opaque gray `CGImage` (stored as RGBA, so the rest of the app treats it like any image).
    /// - Parameter Texture: The texture to read.
    /// - Returns: The converted image.
    /// - Throws: `FilterException` if the image cannot be created.
    private func MakeGrayImage(From Texture: MTLTexture) throws -> CGImage
    {
        let Width = Texture.width
        let Height = Texture.height
        var Gray = [UInt8](repeating: 0, count: Width * Height)
        Texture.getBytes(&Gray, bytesPerRow: Width, from: MTLRegionMake2D(0, 0, Width, Height), mipmapLevel: 0)
        var Pixels = [UInt8](repeating: 255, count: Width * Height * 4)
        for Index in 0 ..< Gray.count
        {
            Pixels[Index * 4] = Gray[Index]
            Pixels[Index * 4 + 1] = Gray[Index]
            Pixels[Index * 4 + 2] = Gray[Index]
        }
        guard let Provider = CGDataProvider(data: Data(Pixels) as CFData),
              let Result = CGImage(width: Width,
                                   height: Height,
                                   bitsPerComponent: 8,
                                   bitsPerPixel: 32,
                                   bytesPerRow: Width * 4,
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
