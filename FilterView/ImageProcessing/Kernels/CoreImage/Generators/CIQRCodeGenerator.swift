//
//  CIQRCodeGenerator.swift
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

/// Makes a QR code. Options: `TEXT` (the text to hold) and `LEVEL` (error correction: `L`, `M`, `Q` or `H`; default `M`). The code is
/// as large as it can be in the image, centered on white.
class CIQRCodeGenerator: ImageFilter
{
    static let FilterName = "CI QR Code Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = try GeneratorSupport.Message(Options)
        let Level = FilterOptionValues.Text(Options, "LEVEL", Default: "M")
        filter.correctionLevel = ["L", "M", "Q", "H"].contains(Level) ? Level : "M"
        guard let Code = filter.outputImage,
              let Final = ImageUtility.CIImageToCGImage(GeneratorSupport.Fit(Code, in: ci)) else
        {
            throw FilterException(Message: "Error from CIQRCodeGenerator.")
        }
        return Final
    }
}
