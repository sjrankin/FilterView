//
//  CILenticularHaloGenerator.swift
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

/// Makes a halo with a lenticular look. Options: `CENTERX`, `CENTERY` (percent of the width and height; default 50), `COLOR` (hexadecimal;
/// default `FFE6CCFF`), `RADIUS` (pixels; default 70), `WIDTH` (pixels; default 87), `OVERLAP` (0 to 1; default 0.77), `STRENGTH` (default
/// 0.5), `CONTRAST` (default 1), `TIME` (0 to 1; default 0), and `OVERIMAGE` (`true` puts the halo over the image).
class CILenticularHaloGenerator: ImageFilter
{
    static let FilterName = "CI Lenticular Halo Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let HaloColor = FilterOptionValues.Color(Options, "COLOR", Default: [1.0, 0.9, 0.8, 1.0])
        let filter = CIFilter.lenticularHaloGenerator()
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.color = CIColor(red: CGFloat(HaloColor[0]), green: CGFloat(HaloColor[1]), blue: CGFloat(HaloColor[2]), alpha: CGFloat(HaloColor[3]))
        filter.haloRadius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 70))
        filter.haloWidth = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 87))
        filter.haloOverlap = Float(FilterOptionValues.Number(Options, "OVERLAP", Default: 0.77))
        filter.striationStrength = Float(FilterOptionValues.Number(Options, "STRENGTH", Default: 0.5))
        filter.striationContrast = Float(FilterOptionValues.Number(Options, "CONTRAST", Default: 1))
        filter.time = Float(FilterOptionValues.Number(Options, "TIME", Default: 0))
        guard let Result = filter.outputImage else
        {
            throw FilterException(Message: "Error from CILenticularHaloGenerator.")
        }
        return try GeneratorSupport.Finish(Result, Source: ci, OverImage: FilterOptionValues.Flag(Options, "OVERIMAGE"), Name: "CILenticularHaloGenerator")
    }
}
