//
//  CIAztecCodeGenerator.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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
