//
//  ColorHistogram.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
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

import CoreGraphics
import Foundation

/// How many pixels of an image have each value, from 0 to 255, of each color channel.
nonisolated struct ColorHistogram: Equatable, Sendable
{
    var Red = [Int](repeating: 0, count: 256)
    var Green = [Int](repeating: 0, count: 256)
    var Blue = [Int](repeating: 0, count: 256)

    /// Counts the pixels of an image. A large image is first drawn smaller, which keeps this quick and changes the shape little.
    /// Fully transparent pixels are not counted.
    /// - Parameter Image: The image to count.
    init?(Image: CGImage)
    {
        let Longest = 512.0
        let Scale = min(1.0, Longest / Double(max(Image.width, Image.height, 1)))
        let Width = max(Int(Double(Image.width) * Scale), 1)
        let Height = max(Int(Double(Image.height) * Scale), 1)
        var Bytes = [UInt8](repeating: 0, count: Width * Height * 4)
        let Made = Bytes.withUnsafeMutableBytes
        {
            Buffer -> Bool in
            guard let Context = CGContext(data: Buffer.baseAddress, width: Width, height: Height, bitsPerComponent: 8,
                                          bytesPerRow: Width * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
            {
                return false
            }
            Context.interpolationQuality = .low
            Context.draw(Image, in: CGRect(x: 0, y: 0, width: Width, height: Height))
            return true
        }
        guard Made else
        {
            return nil
        }
        for Index in stride(from: 0, to: Bytes.count, by: 4)
        {
            let Alpha = Int(Bytes[Index + 3])
            guard Alpha > 0 else
            {
                continue
            }
            // The context holds colors multiplied by alpha, so they are divided back out.
            func Plain(_ Value: UInt8) -> Int
            {
                min(Int(Value) * 255 / Alpha, 255)
            }
            Red[Plain(Bytes[Index])] += 1
            Green[Plain(Bytes[Index + 1])] += 1
            Blue[Plain(Bytes[Index + 2])] += 1
        }
    }
}
