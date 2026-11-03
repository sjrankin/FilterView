//
//  CIBumpDistortion.swift
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

/// Pushes the image out from a point, like a bump, or pulls it in. Options: `CENTERX`, `CENTERY` (percent of the width and height, measured from the top; default 50), `RADIUS` (pixels; default 300), and `SCALE` (-1 to 1; negative
/// pulls in; default 0.5).
class CIBumpDistortion: ImageFilter
{
    static let FilterName = "CI Bump Distortion"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.bumpDistortion()
        filter.inputImage = ci
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 300))
        filter.scale = Float(FilterOptionValues.Number(Options, "SCALE", Default: 0.5))
        return try DistortSupport.Finish(filter.outputImage, Source: ci, Name: "CIBumpDistortion", OverSource: true)
    }
}
