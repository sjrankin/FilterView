//
//  CIFaceDetector.swift
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

import Foundation
import CoreGraphics
import CoreImage

/// Finds faces with a `CIDetector` of type `CIDetectorTypeFace` and marks them on the image. An image with no faces is returned as it is.
/// Options:
///   - `MODE`: `OUTLINE` (default) draws a rectangle around each face. `FILL` tints it. `BLUR` and `PIXELATE` hide it.
///   - `ACCURACY`: `HIGH` (default) or `LOW`, which is faster and less sure.
///   - `PADDING`: how far the marked area goes past the face, as a percentage of the size of the face (default 10).
///   - `COLOR`: the color of the outline or tint, as hexadecimal text (default green, `00FF00FF`).
///   - `LINEWIDTH`: width of the outline in pixels (default 4).
///   - `LANDMARKS`: `true` also marks the eyes and the mouth, for `OUTLINE` and `FILL`. Default `false`.
class CIFaceDetector: ImageFilter
{
    static let FilterName = "CI Face Detector"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    /// Detectors are slow to make, so each accuracy has one that is kept.
    private var Detectors = [String: CIDetector]()

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let Accuracy = FilterOptionValues.Text(Options, "ACCURACY", Default: "HIGH") == "LOW" ? CIDetectorAccuracyLow : CIDetectorAccuracyHigh
        guard let Detector = Detector(Accuracy) else
        {
            throw FilterException(Message: "Cannot make a face detector.")
        }
        let Faces = Detector.features(in: ci).compactMap{$0 as? CIFaceFeature}.map
        {
            FaceMark(Bounds: $0.bounds,
                     LeftEye: $0.hasLeftEyePosition ? $0.leftEyePosition : nil,
                     RightEye: $0.hasRightEyePosition ? $0.rightEyePosition : nil,
                     Mouth: $0.hasMouthPosition ? $0.mouthPosition : nil)
        }
        if Faces.isEmpty
        {
            return Input
        }
        let Marked = CIFaceDetector.Mark(ci, Faces: Faces, Options: Options)
        guard let Final = ImageUtility.CIImageToCGImage(Marked.cropped(to: ci.extent)) else
        {
            throw FilterException(Message: "Error from CIFaceDetector.")
        }
        return Final
    }

    private func Detector(_ Accuracy: String) -> CIDetector?
    {
        if let Known = Detectors[Accuracy]
        {
            return Known
        }
        let Made = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: Accuracy])
        Detectors[Accuracy] = Made
        return Made
    }

    /// Marks faces on an image.
    /// - Parameter Source: The image.
    /// - Parameter Faces: The faces, in the image's coordinates.
    /// - Parameter Options: The filter's options.
    /// - Returns: The image with the faces marked.
    static func Mark(_ Source: CIImage, Faces: [FaceMark], Options: [String: Any]?) -> CIImage
    {
        let Padding = max(FilterOptionValues.Number(Options, "PADDING", Default: 10), 0) / 100.0
        let Mode = FilterOptionValues.Text(Options, "MODE", Default: "OUTLINE")
        var Result = Source
        switch Mode
        {
            case "BLUR":
                for Face in Faces
                {
                    let Area = Padded(Face.Bounds, Padding).intersection(Source.extent)
                    guard !Area.isNull else
                    {
                        continue
                    }
                    let Soft = Source.clampedToExtent().applyingGaussianBlur(sigma: max(Area.width / 6, 1)).cropped(to: Area)
                    Result = Soft.composited(over: Result)
                }

            case "PIXELATE":
                for Face in Faces
                {
                    let Area = Padded(Face.Bounds, Padding).intersection(Source.extent)
                    guard !Area.isNull else
                    {
                        continue
                    }
                    let Blocks = Source.applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(Area.width / 10, 2),
                                                                                  kCIInputCenterKey: CIVector(x: Area.minX, y: Area.minY)])
                    Result = Blocks.cropped(to: Area).composited(over: Result)
                }

            default:
                if let Overlay = Drawing(Source.extent, Faces: Faces, Padding: Padding, Fill: Mode == "FILL", Options: Options)
                {
                    Result = Overlay.composited(over: Source)
                }
        }
        return Result
    }

    /// A face's rectangle made bigger on every side by a fraction of its size.
    static func Padded(_ Bounds: CGRect, _ Fraction: Double) -> CGRect
    {
        Bounds.insetBy(dx: -Bounds.width * Fraction, dy: -Bounds.height * Fraction)
    }

    /// The outlines (or tinted rectangles) and landmarks, on a transparent image the size of the source.
    private static func Drawing(_ Area: CGRect, Faces: [FaceMark], Padding: Double, Fill: Bool, Options: [String: Any]?) -> CIImage?
    {
        let Width = Int(Area.width.rounded())
        let Height = Int(Area.height.rounded())
        guard Width > 0, Height > 0,
              let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
        {
            return nil
        }
        let Tint = FilterOptionValues.Color(Options, "COLOR", Default: [0, 1, 0, 1])
        let Line = max(FilterOptionValues.Number(Options, "LINEWIDTH", Default: 4), 1)
        let Landmarks = FilterOptionValues.Flag(Options, "LANDMARKS")
        let Solid = CGColor(red: CGFloat(Tint[0]), green: CGFloat(Tint[1]), blue: CGFloat(Tint[2]), alpha: CGFloat(Tint[3]))
        let Faint = CGColor(red: CGFloat(Tint[0]), green: CGFloat(Tint[1]), blue: CGFloat(Tint[2]), alpha: CGFloat(Tint[3]) * 0.4)
        Context.setStrokeColor(Solid)
        Context.setLineWidth(CGFloat(Line))
        for Face in Faces
        {
            let Box = Padded(Face.Bounds, Padding).offsetBy(dx: -Area.minX, dy: -Area.minY)
            if Fill
            {
                Context.setFillColor(Faint)
                Context.fill(Box)
            }
            else
            {
                Context.stroke(Box)
            }
            if Landmarks
            {
                Context.setFillColor(Solid)
                let Radius = max(Face.Bounds.width * 0.04, CGFloat(Line))
                for Point in [Face.LeftEye, Face.RightEye, Face.Mouth].compactMap({$0})
                {
                    Context.fillEllipse(in: CGRect(x: Point.x - Area.minX - Radius, y: Point.y - Area.minY - Radius,
                                                   width: Radius * 2, height: Radius * 2))
                }
            }
        }
        guard let Picture = Context.makeImage() else
        {
            return nil
        }
        return CIImage(cgImage: Picture).transformed(by: CGAffineTransform(translationX: Area.minX, y: Area.minY))
    }
}
