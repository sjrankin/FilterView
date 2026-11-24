//
//  PixelBuffer.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/23/26.
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

/// Converts between `CGImage` and plain 8-bit RGBA bytes, for filters that work on the CPU.
nonisolated enum PixelBuffer
{
    /// The pixels of an image as 8-bit premultiplied RGBA, row by row from the top, drawn at the given size.
    /// - Parameter Source: The image.
    /// - Parameter Width: Width to draw it at.
    /// - Parameter Height: Height to draw it at.
    /// - Returns: `Width * Height * 4` bytes, or `nil` if the bitmap cannot be made.
    static func Bytes(_ Source: CGImage, Width: Int, Height: Int) -> [UInt8]?
    {
        guard Width > 0,
              Height > 0 else
        {
            return nil
        }
        var Pixels = [UInt8](repeating: 0, count: Width * Height * 4)
        let Drawn = Pixels.withUnsafeMutableBytes
        {
            Buffer -> Bool in
            guard let Context = CGContext(data: Buffer.baseAddress, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: Width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
            {
                return false
            }
            Context.draw(Source, in: CGRect(x: 0, y: 0, width: Width, height: Height))
            return true
        }
        return Drawn ? Pixels : nil
    }

    /// An image made from 8-bit premultiplied RGBA pixels.
    /// - Parameter Pixels: `Width * Height * 4` bytes, row by row from the top.
    /// - Returns: The image, or `nil` if the bytes do not fit the size.
    static func Image(_ Pixels: [UInt8], Width: Int, Height: Int) -> CGImage?
    {
        guard Pixels.count == Width * Height * 4,
              let Provider = CGDataProvider(data: Data(Pixels) as CFData) else
        {
            return nil
        }
        return CGImage(width: Width, height: Height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: Provider,
                       decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
