//
//  OpenCVImage.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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

#if os(macOS)
import Foundation
import CoreGraphics
import opencv2

/// Moves an image between Core Graphics and OpenCV and runs an OpenCV operation on it. OpenCV is only linked on macOS.
nonisolated enum OpenCVImage
{
    /// The kind of image the operation wants.
    enum Layout
    {
        /// Three channels: red, green, blue.
        case Color
        /// One channel: how bright each pixel is.
        case Gray
    }

    /// Runs an OpenCV operation on an image. The image is drawn in the sRGB color space, and the alpha of every pixel is kept as it was.
    /// - Parameter Input: The image.
    /// - Parameter Layout: Whether the operation gets color or gray pixels.
    /// - Parameter Operation: Does the work. It gets 8 bit pixels in the layout asked for, and returns 8 bit pixels of one channel (gray)
    ///   or three (red, green, blue), the same size.
    /// - Returns: The new image.
    /// - Throws: `FilterException` if the image cannot be read, or the operation returns something that cannot be shown.
    static func Process(_ Input: CGImage, _ Layout: Layout, _ Operation: (Mat) throws -> Mat) throws -> CGImage
    {
        let Width = Input.width
        let Height = Input.height
        let Straight = try StraightPixels(Input)
        let Source = Mat(rows: Int32(Height), cols: Int32(Width), type: CvType.CV_8UC(4))
        let SourceBytes = Source.dataPointer()
        Straight.withUnsafeBytes
        {
            SourceBytes.update(from: $0.bindMemory(to: UInt8.self).baseAddress!, count: Width * Height * 4)
        }
        let Working = Mat()
        Imgproc.cvtColor(src: Source, dst: Working, code: Layout == .Color ? .COLOR_RGBA2RGB : .COLOR_RGBA2GRAY)
        let Result = try Operation(Working)
        let Channels = Int(Result.channels())
        guard Int(Result.cols()) == Width,
              Int(Result.rows()) == Height,
              Result.depth() == CvType.CV_8U,
              Channels == 1 || Channels == 3 else
        {
            throw FilterException(Message: "OpenCV returned an image that cannot be shown")
        }
        // The pixels have to be in one block to be read directly.
        let Flat = Result.isContinuous() ? Result : Result.clone()
        let ResultBytes = Flat.dataPointer()
        var Output = [UInt8](repeating: 0, count: Width * Height * 4)
        for Pixel in 0 ..< Width * Height
        {
            let Alpha = Int(Straight[Pixel * 4 + 3])
            for Component in 0 ..< 3
            {
                let Value = Int(ResultBytes[Pixel * Channels + (Channels == 1 ? 0 : Component)])
                // Premultiplied, as Core Graphics wants it.
                Output[Pixel * 4 + Component] = UInt8((Value * Alpha + 127) / 255)
            }
            Output[Pixel * 4 + 3] = UInt8(Alpha)
        }
        return try MakeImage(Output, Width, Height)
    }

    /// The pixels of an image as red, green, blue, alpha bytes, with the color not multiplied by the alpha.
    private static func StraightPixels(_ Image: CGImage) throws -> [UInt8]
    {
        let Width = Image.width
        let Height = Image.height
        var Pixels = [UInt8](repeating: 0, count: Width * Height * 4)
        guard let Space = CGColorSpace(name: CGColorSpace.sRGB),
              let Context = CGContext(data: &Pixels, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: Width * 4,
                                      space: Space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
        {
            throw FilterException(Message: "Cannot read the image for OpenCV")
        }
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Width, height: Height))
        for Pixel in 0 ..< Width * Height
        {
            let Alpha = Int(Pixels[Pixel * 4 + 3])
            if Alpha != 0 && Alpha != 255
            {
                for Component in 0 ..< 3
                {
                    Pixels[Pixel * 4 + Component] = UInt8(min((Int(Pixels[Pixel * 4 + Component]) * 255 + Alpha / 2) / Alpha, 255))
                }
            }
        }
        return Pixels
    }

    /// Makes an image from premultiplied red, green, blue, alpha bytes.
    private static func MakeImage(_ Pixels: [UInt8], _ Width: Int, _ Height: Int) throws -> CGImage
    {
        guard let Space = CGColorSpace(name: CGColorSpace.sRGB),
              let Provider = CGDataProvider(data: Data(Pixels) as CFData),
              let Made = CGImage(width: Width, height: Height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Width * 4,
                                 space: Space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider: Provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else
        {
            throw FilterException(Message: "Cannot make the image from the OpenCV result")
        }
        return Made
    }

    /// An odd whole number of at least `Minimum`, as several OpenCV window sizes must be.
    /// - Parameter Value: The number, which may have a fraction or be even.
    static func OddSize(_ Value: Double, Minimum: Int = 1) -> Int32
    {
        var Size = max(Int(Value.rounded()), Minimum)
        if Size % 2 == 0
        {
            Size += 1
        }
        return Int32(Size)
    }
}
#endif
