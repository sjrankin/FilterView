//
//  CIPersonSegmentation.swift
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
import CoreImage.CIFilterBuiltins

/// Finds the people in an image with Core Image's `CIPersonSegmentation` and either shows the mask it makes or uses it to cut the people
/// out. Options:
///   - `QUALITY`: `ACCURATE`, `BALANCED` (default), or `FAST`. Faster is rougher; live video wants `FAST`.
///   - `OUTPUT`: `PERSON` (default) keeps the people and makes the rest transparent. `BACKGROUND` removes the people and keeps the rest.
///   `MASK` shows the mask itself, white where there is a person.
class CIPersonSegmentation: ImageFilter
{
    static let FilterName = "CI Person Segmentation"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.personSegmentation()
        filter.inputImage = ci
        filter.qualityLevel = CIPersonSegmentation.Quality(FilterOptionValues.Text(Options, "QUALITY", Default: "BALANCED"))
        guard let Found = filter.outputImage,
              !Found.extent.isInfinite,
              Found.extent.width > 0,
              Found.extent.height > 0 else
        {
            throw FilterException(Message: "Error from CIPersonSegmentation.")
        }
        // The mask is made at its own size, so it is stretched to the size of the image. It is in the red channel only, so the red is
        // copied to all three to make a plain gray mask, which is what the rest of Core Image expects of one.
        let Gray = CIFilter.colorMatrix()
        Gray.inputImage = Found
        Gray.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        Gray.gVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        Gray.bVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        Gray.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        Gray.biasVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        let Flat = Gray.outputImage ?? Found
        let Mask = Flat.transformed(by: CGAffineTransform(translationX: -Found.extent.minX, y: -Found.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: ci.extent.width / Found.extent.width, y: ci.extent.height / Found.extent.height))
            .transformed(by: CGAffineTransform(translationX: ci.extent.minX, y: ci.extent.minY))
            .cropped(to: ci.extent)
        let Result: CIImage
        switch FilterOptionValues.Text(Options, "OUTPUT", Default: "PERSON")
        {
            case "MASK":
                Result = Mask

            case "BACKGROUND":
                Result = CIPersonSegmentation.Blend(Kept: Mask, Over: ci, Cut: true)

            default:
                Result = CIPersonSegmentation.Blend(Kept: Mask, Over: ci, Cut: false)
        }
        guard let Final = ImageUtility.CIImageToCGImage(Result.cropped(to: ci.extent)) else
        {
            throw FilterException(Message: "Error from CIPersonSegmentation.")
        }
        return Final
    }

    /// The number Core Image uses for a quality: 0 is accurate, 1 balanced, and 2 fast.
    static func Quality(_ Name: String) -> Int
    {
        switch Name
        {
            case "ACCURATE": return 0
            case "FAST": return 2
            default: return 1
        }
    }

    /// Keeps the part of the image the mask covers, or everything else, and makes the rest transparent.
    /// - Parameter Kept: The mask, white where there is a person.
    /// - Parameter Over: The image.
    /// - Parameter Cut: True to remove the people and keep the rest; false to keep the people.
    static func Blend(Kept Mask: CIImage, Over Source: CIImage, Cut: Bool) -> CIImage
    {
        let Clear = CIImage(color: .clear).cropped(to: Source.extent)
        let Blender = CIFilter.blendWithMask()
        Blender.inputImage = Cut ? Clear : Source
        Blender.backgroundImage = Cut ? Source : Clear
        Blender.maskImage = Mask
        return Blender.outputImage ?? Source
    }
}
