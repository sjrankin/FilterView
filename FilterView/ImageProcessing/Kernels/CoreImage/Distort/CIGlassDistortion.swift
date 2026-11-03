//
//  CIGlassDistortion.swift
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

/// Bends the image as if seen through a textured piece of glass. The texture is the image itself or random noise. Options: `TEXTURE`
/// (`SOURCE` or `NOISE`; default `SOURCE`), `SMOOTHING` (blur of the noise, so the glass is not rough; default 3), `CENTERX`, `CENTERY` (percent of the width and height, measured from the top; default 50),
/// and `SCALE` (how far the glass bends the image; default 200).
class CIGlassDistortion: ImageFilter
{
    static let FilterName = "CI Glass Distortion"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.glassDistortion()
        filter.inputImage = ci
        var Texture = ci
        if FilterOptionValues.Text(Options, "TEXTURE", Default: "SOURCE") == "NOISE",
           let Noise = CIFilter.randomGenerator().outputImage
        {
            Texture = Noise.cropped(to: ci.extent)
            let Smoothing = max(FilterOptionValues.Number(Options, "SMOOTHING", Default: 3), 0)
            if Smoothing > 0
            {
                Texture = Texture.clampedToExtent().applyingGaussianBlur(sigma: Smoothing).cropped(to: ci.extent)
            }
        }
        filter.textureImage = Texture
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.scale = Float(FilterOptionValues.Number(Options, "SCALE", Default: 200))
        return try DistortSupport.Finish(filter.outputImage, Source: ci, Name: "CIGlassDistortion")
    }
}
