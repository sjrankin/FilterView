//
//  CISunBeamsGenerator.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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

/// Makes a sun with beams radiating from it. This is a generator, so it does not use the image's pixels, only its size, which the
/// result is cut to. In a pipeline, a sunbeams stage merged onto another stage is made on a canvas the size of that stage (see
/// `PipelineCanvas`), so the sun and beams keep their size and the center options place them on the target. Options:
///   - `CENTERX`, `CENTERY`: where the sun is, as percentages of the width and height (default 50, the middle). Y is measured from the
///   top of the image.
///   - `COLOR`: the color of the sun and beams, as hexadecimal text (default orange, `FF8000FF`).
///   - `SUNRADIUS`: radius of the sun in pixels (default 40).
///   - `MAXSTRIATION`: how far the beams reach, from the sun (default 2.58).
///   - `STRENGTH`: strength of the beams (default 0.5).
///   - `CONTRAST`: contrast of the beams (default 1.375).
///   - `TIME`: moves the beams, 0.0 to 1.0, so they can be animated (default 0).
///   - `OVERIMAGE`: `true` puts the beams over the image; the default `false` shows only the beams.
class CISunBeamsGenerator: OverlayGenerator
{
    static let FilterName = "CI Sunbeams Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let Orange: [Float] = [1.0, 0.5, 0.0, 1.0]
        let Beams = FilterOptionValues.Color(Options, "COLOR", Default: Orange)
        let filter = CIFilter.sunbeamsGenerator()
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.color = CIColor(red: CGFloat(Beams[0]), green: CGFloat(Beams[1]), blue: CGFloat(Beams[2]), alpha: CGFloat(Beams[3]))
        filter.sunRadius = Float(FilterOptionValues.Number(Options, "SUNRADIUS", Default: 40))
        filter.maxStriationRadius = Float(FilterOptionValues.Number(Options, "MAXSTRIATION", Default: 2.58))
        filter.striationStrength = Float(FilterOptionValues.Number(Options, "STRENGTH", Default: 0.5))
        filter.striationContrast = Float(FilterOptionValues.Number(Options, "CONTRAST", Default: 1.375))
        filter.time = Float(FilterOptionValues.Number(Options, "TIME", Default: 0))
        // The generator's image goes on forever, so it is cut to the size of the input.
        guard var result = filter.outputImage?.cropped(to: ci.extent) else
        {
            throw FilterException(Message: "Error from CISunBeamsGenerator.")
        }
        if FilterOptionValues.Flag(Options, "OVERIMAGE")
        {
            result = result.composited(over: ci)
        }
        guard let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CISunBeamsGenerator.")
        }
        return final
    }
}
