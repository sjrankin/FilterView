//
//  CIAztecCodeGenerator.swift
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

/// Makes an Aztec code. Options: `TEXT`, `CORRECTION` (percent of error correction, 5 to 95; default 23), `LAYERS` (1 to 32, or 0 to
/// let the filter choose; default 0), and `COMPACT` (`true` for the compact style; default `false`).
class CIAztecCodeGenerator: ImageFilter
{
    static let FilterName = "CI Aztec Code Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.aztecCodeGenerator()
        filter.message = try GeneratorSupport.Message(Options)
        filter.correctionLevel = Float(FilterOptionValues.Number(Options, "CORRECTION", Default: 23))
        let Layers = Float(FilterOptionValues.Number(Options, "LAYERS", Default: 0))
        if Layers >= 1
        {
            filter.layers = Layers
        }
        if FilterOptionValues.Flag(Options, "COMPACT")
        {
            filter.compactStyle = 1
        }
        guard let Code = filter.outputImage,
              let Final = ImageUtility.CIImageToCGImage(GeneratorSupport.Fit(Code, in: ci)) else
        {
            throw FilterException(Message: "Error from CIAztecCodeGenerator. The text may be too long for the settings.")
        }
        return Final
    }
}
