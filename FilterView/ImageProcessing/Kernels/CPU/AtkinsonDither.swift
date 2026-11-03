//
//  AtkinsonDither.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/30/26.
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

/// Black and white Atkinson error-diffusion dither. Runs on the CPU because each pixel depends on the results of its
/// neighbors, which does not map well to a GPU.
class AtkinsonDither: ImageFilter
{
    static let FilterName = "Atkinson Dither"

    /// Option key for the black/white threshold, a `Float` in 0.0 to 1.0. Default is 0.5.
    static let ThresholdKey = "Threshold"

    /// Option key for using the faster `AtkinsonDitherFast` instead. The value is `true` or `false`; the default is `false`.
    static let OptimizedKey = "OPTIMIZED"

    var FilterType: ImageFilterTypes
    {
        .CPU
    }

    /// Dither the passed image to black and white using Atkinson error diffusion.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Optional dictionary. Recognized keys are `ThresholdKey` and `OptimizedKey`.
    /// - Returns: An 8-bit grayscale image containing only black and white pixels.
    /// - Throws: `FilterException` if the image cannot be read or written, `CancellationError` if cancelled.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        if Options?[AtkinsonDither.OptimizedKey] as? String == "true"
        {
            return try await AtkinsonDitherFast().ProcessImage(Input, Options)
        }
        try Task.checkCancellation()

        let Width = Input.width
        let Height = Input.height
        guard Width > 0, Height > 0 else
        {
            throw FilterException(Message: "Empty image passed to AtkinsonDither.")
        }
        let Threshold = (Options?[AtkinsonDither.ThresholdKey] as? Float) ?? 0.5

        // Let CoreGraphics do the color to gray conversion.
        var Gray = [UInt8](repeating: 0, count: Width * Height)
        let DrawOK = Gray.withUnsafeMutableBytes
        {
            Buffer -> Bool in
            guard let Context = CGContext(data: Buffer.baseAddress,
                                          width: Width,
                                          height: Height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: Width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else
            {
                return false
            }
            Context.draw(Input, in: CGRect(x: 0, y: 0, width: Width, height: Height))
            return true
        }
        guard DrawOK else
        {
            throw FilterException(Message: "Could not create gray context in AtkinsonDither.")
        }

        var Work = Gray.map{Float($0) / 255.0}
        var Result = [UInt8](repeating: 0, count: Width * Height)

        // Neighbors that receive 1/8 of the error each.
        let Offsets: [(Int, Int)] = [(1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)]

        for Y in 0 ..< Height
        {
            try Task.checkCancellation()
            for X in 0 ..< Width
            {
                let Index = Y * Width + X
                let Old = Work[Index]
                let New: Float = Old >= Threshold ? 1.0 : 0.0
                Result[Index] = New > 0 ? 255 : 0
                let Share = (Old - New) / 8.0
                for (DX, DY) in Offsets
                {
                    let NX = X + DX
                    let NY = Y + DY
                    if NX >= 0 && NX < Width && NY < Height
                    {
                        Work[NY * Width + NX] += Share
                    }
                }
            }
        }

        guard let Provider = CGDataProvider(data: Data(Result) as CFData),
              let Output = CGImage(width: Width,
                                   height: Height,
                                   bitsPerComponent: 8,
                                   bitsPerPixel: 8,
                                   bytesPerRow: Width,
                                   space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                   provider: Provider,
                                   decode: nil,
                                   shouldInterpolate: false,
                                   intent: .defaultIntent) else
        {
            throw FilterException(Message: "Error from AtkinsonDither.")
        }
        return Output
    }
}
