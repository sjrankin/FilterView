//
//  CICode128BarcodeGenerator.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Makes a Code 128 barcode. Options: `TEXT` (ASCII characters only), `QUIET` (the empty space on each side, in modules; default 7), and
/// `HEIGHT` (height of the bars in pixels; default 32).
class CICode128BarcodeGenerator: ImageFilter
{
    static let FilterName = "CI Code 128 Barcode Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = try GeneratorSupport.Message(Options, ASCIIOnly: true)
        filter.quietSpace = Float(FilterOptionValues.Number(Options, "QUIET", Default: 7))
        filter.barcodeHeight = Float(FilterOptionValues.Number(Options, "HEIGHT", Default: 32))
        guard let Code = filter.outputImage,
              let Final = ImageUtility.CIImageToCGImage(GeneratorSupport.Fit(Code, in: ci)) else
        {
            throw FilterException(Message: "Error from CICode128BarcodeGenerator.")
        }
        return Final
    }
}
