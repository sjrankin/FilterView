//
//  MetalProcessor+Texture.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
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
import CoreGraphics
import Metal

extension MetalProcessor
{
    /// Makes a texture from an image. The image is first redrawn into a standard 8-bit sRGB RGBA layout, so the texture is
    /// right no matter how the `CGImage` stores its pixels (alpha first or last, no alpha, gray, CMYK, 16 bit, wide gamut).
    /// - Note: `MTKTextureLoader` is not used because it misreads some pixel layouts, such as the alpha-first layout that
    /// ImageIO returns for thumbnails. The result was garbled, tinted colors.
    /// - Parameter Input: The image.
    /// - Returns: An `rgba8Unorm` texture the size of `Input`, readable by shaders.
    /// - Throws: `FilterException` if Metal is unavailable or the image cannot be converted.
    func MakeSourceTexture(From Input: CGImage) throws -> MTLTexture
    {
        guard let Device = Device,
              let Space = CGColorSpace(name: CGColorSpace.sRGB) else
        {
            throw FilterException(Message: "Metal is not available")
        }
        let Width = Input.width
        let Height = Input.height
        let BytesPerRow = Width * 4
        let Descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                  width: Width,
                                                                  height: Height,
                                                                  mipmapped: false)
        Descriptor.usage = [.shaderRead]
        guard let Texture = Device.makeTexture(descriptor: Descriptor) else
        {
            throw FilterException(Message: "Could not make a texture for the image")
        }
        var Pixels = [UInt8](repeating: 0, count: BytesPerRow * Height)
        let Drawn = Pixels.withUnsafeMutableBytes
        {
            Buffer -> Bool in
            guard let Context = CGContext(data: Buffer.baseAddress,
                                          width: Width,
                                          height: Height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: BytesPerRow,
                                          space: Space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
            {
                return false
            }
            Context.draw(Input, in: CGRect(x: 0, y: 0, width: Width, height: Height))
            return true
        }
        guard Drawn else
        {
            throw FilterException(Message: "Could not convert the image for Metal")
        }
        Texture.replace(region: MTLRegionMake2D(0, 0, Width, Height), mipmapLevel: 0, withBytes: Pixels, bytesPerRow: BytesPerRow)
        return Texture
    }
}
