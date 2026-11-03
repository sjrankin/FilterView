//
//  CIBarcodeGenerator.swift
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

/// Makes a barcode from a barcode descriptor, which gives control over details the QR Code generator does not. This one builds a QR
/// code descriptor. Options: `TEXT`, `LEVEL` (error correction: `L`, `M`, `Q` or `H`; default `M`), `VERSION` (symbol size, 1 to 40, or 0 to
/// use the smallest that holds the text; default 0), and `MASK` (mask pattern, 0 to 7; default 0).
class CIBarcodeGenerator: ImageFilter
{
    static let FilterName = "CI Barcode Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let Message = try GeneratorSupport.Message(Options)
        let Levels: [String: CIQRCodeDescriptor.ErrorCorrectionLevel] = ["L": .levelL, "M": .levelM, "Q": .levelQ, "H": .levelH]
        let Level = Levels[FilterOptionValues.Text(Options, "LEVEL", Default: "M")] ?? .levelM
        let Mask = UInt8(min(max(FilterOptionValues.Number(Options, "MASK", Default: 0), 0), 7))
        let Chosen = Int(FilterOptionValues.Number(Options, "VERSION", Default: 0))
        // A version too small for the text makes no descriptor, so with no version chosen the smallest that works is used.
        let Versions = Chosen >= 1 ? [min(Chosen, 40)] : Array(1 ... 40)
        var Descriptor: CIQRCodeDescriptor? = nil
        for Version in Versions
        {
            Descriptor = CIQRCodeDescriptor(payload: Message, symbolVersion: Version, maskPattern: Mask, errorCorrectionLevel: Level)
            if Descriptor != nil
            {
                break
            }
        }
        guard let Found = Descriptor else
        {
            throw FilterException(Message: "The text does not fit in a QR code of that version.")
        }
        let filter = CIFilter.barcodeGenerator()
        filter.barcodeDescriptor = Found
        guard let Code = filter.outputImage,
              let Final = ImageUtility.CIImageToCGImage(GeneratorSupport.Fit(Code, in: ci)) else
        {
            throw FilterException(Message: "Error from CIBarcodeGenerator.")
        }
        return Final
    }
}
