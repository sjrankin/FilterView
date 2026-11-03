//
//  CIStripesGenerator.swift
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

/// Makes stripes. Options: `CENTERX`, `CENTERY` (percent of the width and height; default 50), `COLOR0` and `COLOR1` (the two stripe
/// colors, hexadecimal; default black `000000FF` and white `FFFFFFFF`), `WIDTH` (pixels; default 80), and `SHARPNESS` (0 to 1; default 1).
class CIStripesGenerator: ImageFilter
{
    static let FilterName = "CI Stripes Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let First = FilterOptionValues.Color(Options, "COLOR0", Default: [0, 0, 0, 1])
        let Second = FilterOptionValues.Color(Options, "COLOR1", Default: [1, 1, 1, 1])
        let filter = CIFilter.stripesGenerator()
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.color0 = CIColor(red: CGFloat(First[0]), green: CGFloat(First[1]), blue: CGFloat(First[2]), alpha: CGFloat(First[3]))
        filter.color1 = CIColor(red: CGFloat(Second[0]), green: CGFloat(Second[1]), blue: CGFloat(Second[2]), alpha: CGFloat(Second[3]))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 80))
        filter.sharpness = Float(FilterOptionValues.Number(Options, "SHARPNESS", Default: 1))
        guard let Result = filter.outputImage else
        {
            throw FilterException(Message: "Error from CIStripesGenerator.")
        }
        return try GeneratorSupport.Finish(Result, Source: ci, OverImage: false, Name: "CIStripesGenerator")
    }
}
