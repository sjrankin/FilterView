//
//  CIColorControls.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Adjusts brightness, contrast, and saturation. Options: `BRIGHTNESS` (-1.0 to 1.0, default 0), `CONTRAST` (0 to 4, default 1),
/// and `SATURATION` (0 to 2, default 1). The defaults leave the image unchanged.
class CIColorControls: ImageFilter
{
    static let FilterName = "CI Color Controls"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.colorControls()
        filter.inputImage = ci
        filter.brightness = Float(FilterOptionValues.Number(Options, "BRIGHTNESS", Default: 0))
        filter.contrast = Float(FilterOptionValues.Number(Options, "CONTRAST", Default: 1))
        filter.saturation = Float(FilterOptionValues.Number(Options, "SATURATION", Default: 1))
        if let final = filter.outputImage
        {
            if let final = ImageUtility.CIImageToCGImage(final)
            {
                return final
            }
        }
        throw FilterException(Message: "Error from CIColorControls.")
    }
}
