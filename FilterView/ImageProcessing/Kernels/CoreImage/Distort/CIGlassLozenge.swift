//
//  CIGlassLozenge.swift
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

/// Puts a pill-shaped piece of glass over the image, which bends what is under it. Options: `POINT0X`, `POINT0Y`, `POINT1X`, `POINT1Y` (the
/// two ends of the lozenge, as percent of the width and height from the top left; default 30, 50 and 70, 50), `RADIUS` (pixels;
/// default 100), and `REFRACTION` (default 1.7).
class CIGlassLozenge: ImageFilter
{
    static let FilterName = "CI Glass Lozenge"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.glassLozenge()
        filter.inputImage = ci
        filter.point0 = FilterOptionValues.Point(Options, "POINT0X", "POINT0Y", Input, DefaultX: 30, DefaultY: 50)
        filter.point1 = FilterOptionValues.Point(Options, "POINT1X", "POINT1Y", Input, DefaultX: 70, DefaultY: 50)
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 100))
        filter.refraction = Float(FilterOptionValues.Number(Options, "REFRACTION", Default: 1.7))
        return try DistortSupport.Finish(filter.outputImage, Source: ci, Name: "CIGlassLozenge", OverSource: true)
    }
}
