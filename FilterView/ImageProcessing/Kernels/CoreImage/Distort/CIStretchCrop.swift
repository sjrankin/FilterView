//
//  CIStretchCrop.swift
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

/// Makes the image another size by cropping it, stretching it, or both. Unlike the other distortions the result may not be the size of
/// the image it is given. Options: `WIDTH` and `HEIGHT` (the size of the result, as percent of the size of the image; default 100),
/// `CROPAMOUNT` (0 is all stretch and 1 is all crop; default 0.25), and `CENTERSTRETCH` (how much of the stretch is kept in the middle
/// of the image, 0 to 1; default 0.25).
class CIStretchCrop: ImageFilter
{
    static let FilterName = "CI Stretch Crop"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.stretchCrop()
        filter.inputImage = ci
        let Width = max(FilterOptionValues.Number(Options, "WIDTH", Default: 100), 1) / 100.0
        let Height = max(FilterOptionValues.Number(Options, "HEIGHT", Default: 100), 1) / 100.0
        filter.size = CGPoint(x: Double(Input.width) * Width, y: Double(Input.height) * Height)
        filter.cropAmount = Float(min(max(FilterOptionValues.Number(Options, "CROPAMOUNT", Default: 0.25), 0), 1))
        filter.centerStretchAmount = Float(min(max(FilterOptionValues.Number(Options, "CENTERSTRETCH", Default: 0.25), 0), 1))
        return try DistortSupport.Finish(filter.outputImage, Source: ci, Name: "CIStretchCrop", KeepSize: false)
    }
}
