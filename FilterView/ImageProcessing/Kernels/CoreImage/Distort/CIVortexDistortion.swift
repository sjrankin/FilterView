//
//  CIVortexDistortion.swift
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

/// Rotates the image around a point in a vortex, turning it more the closer it is to the point. Options: `CENTERX`, `CENTERY` (percent of the width and height, measured from the top; default 50), `RADIUS` (pixels;
/// default 300), and `ANGLE` (degrees, -5400 to 5400; default 3240).
class CIVortexDistortion: ImageFilter
{
    static let FilterName = "CI Vortex Distortion"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.vortexDistortion()
        filter.inputImage = ci
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 300))
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 3240))
        return try DistortSupport.Finish(filter.outputImage, Source: ci, Name: "CIVortexDistortion", OverSource: true)
    }
}
