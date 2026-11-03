//
//  CIPDF417BarcodeGenerator.swift
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

/// Makes a PDF417 barcode. Options: `TEXT`, `COLUMNS` (1 to 30, or 0 for automatic; default 0), `ROWS` (3 to 90, or 0 for automatic;
/// default 0), `CORRECTION` (error correction level, 0 to 8; default 2), `ASPECT` (preferred width to height ratio, or 0 for automatic;
/// default 0), `COMPACTION` (`0` automatic, `1` numeric, `2` text, `3` byte; default 0), and `COMPACT` (`true` for the compact style).
class CIPDF417BarcodeGenerator: ImageFilter
{
    static let FilterName = "CI PDF417 Barcode Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.pdf417BarcodeGenerator()
        filter.message = try GeneratorSupport.Message(Options)
        let Columns = Float(FilterOptionValues.Number(Options, "COLUMNS", Default: 0))
        if Columns >= 1
        {
            filter.dataColumns = Columns
        }
        let Rows = Float(FilterOptionValues.Number(Options, "ROWS", Default: 0))
        if Rows >= 3
        {
            filter.rows = Rows
        }
        filter.correctionLevel = Float(FilterOptionValues.Number(Options, "CORRECTION", Default: 2))
        let Aspect = Float(FilterOptionValues.Number(Options, "ASPECT", Default: 0))
        if Aspect > 0
        {
            filter.preferredAspectRatio = Aspect
        }
        let Compaction = Float(FilterOptionValues.Number(Options, "COMPACTION", Default: 0))
        if Compaction >= 1
        {
            filter.compactionMode = Compaction
            filter.alwaysSpecifyCompaction = 1
        }
        if FilterOptionValues.Flag(Options, "COMPACT")
        {
            filter.compactStyle = 1
        }
        guard let Code = filter.outputImage,
              let Final = ImageUtility.CIImageToCGImage(GeneratorSupport.Fit(Code, in: ci)) else
        {
            throw FilterException(Message: "Error from CIPDF417BarcodeGenerator. The text may be too long for the settings.")
        }
        return Final
    }
}
