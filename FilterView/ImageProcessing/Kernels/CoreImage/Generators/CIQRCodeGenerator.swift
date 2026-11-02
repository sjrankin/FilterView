//
//  CIQRCodeGenerator.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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
