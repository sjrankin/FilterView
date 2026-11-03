//
//  CITorusLensDistortion.swift
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

/// Bends the image through a ring-shaped lens. Options: `CENTERX`, `CENTERY` (percent of the width and height, measured from the top; default 50), `RADIUS` (pixels, to the middle of the ring; default 160), `WIDTH`
/// (pixels, of the ring; default 80), and `REFRACTION` (default 1.7).
class CITorusLensDistortion: ImageFilter
{
    static let FilterName = "CI Torus Lens Distortion"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.torusLensDistortion()
        filter.inputImage = ci
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 160))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 80))
        filter.refraction = Float(FilterOptionValues.Number(Options, "REFRACTION", Default: 1.7))
        return try DistortSupport.Finish(filter.outputImage, Source: ci, Name: "CITorusLensDistortion", OverSource: true)
    }
}
