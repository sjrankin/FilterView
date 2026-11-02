//
//  CISpotColor.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Replaces up to three colors. For each spot `N` (1, 2, 3): `CENTERN` is the color to find and `REPLACEN` is its replacement (both
/// hexadecimal; default red, green and blue, each replaced by itself, so nothing changes at first), `CLOSENESSN` is how near a color must
/// be to count (default 0.22), and `CONTRASTN` is the contrast of the replacement (default 0.98).
class CISpotColor: ImageFilter
{
    static let FilterName = "CI Spot Color"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.spotColor()
        filter.inputImage = ci
        filter.centerColor1 = FilterOptionValues.CoreImageColor(Options, "CENTER1", Default: [1.0, 0.0, 0.0, 1.0])
        filter.replacementColor1 = FilterOptionValues.CoreImageColor(Options, "REPLACE1", Default: [1.0, 0.0, 0.0, 1.0])
        filter.closeness1 = Float(FilterOptionValues.Number(Options, "CLOSENESS1", Default: 0.22))
        filter.contrast1 = Float(FilterOptionValues.Number(Options, "CONTRAST1", Default: 0.98))
        filter.centerColor2 = FilterOptionValues.CoreImageColor(Options, "CENTER2", Default: [0.0, 1.0, 0.0, 1.0])
        filter.replacementColor2 = FilterOptionValues.CoreImageColor(Options, "REPLACE2", Default: [0.0, 1.0, 0.0, 1.0])
        filter.closeness2 = Float(FilterOptionValues.Number(Options, "CLOSENESS2", Default: 0.22))
        filter.contrast2 = Float(FilterOptionValues.Number(Options, "CONTRAST2", Default: 0.98))
        filter.centerColor3 = FilterOptionValues.CoreImageColor(Options, "CENTER3", Default: [0.0, 0.0, 1.0, 1.0])
        filter.replacementColor3 = FilterOptionValues.CoreImageColor(Options, "REPLACE3", Default: [0.0, 0.0, 1.0, 1.0])
        filter.closeness3 = Float(FilterOptionValues.Number(Options, "CLOSENESS3", Default: 0.22))
        filter.contrast3 = Float(FilterOptionValues.Number(Options, "CONTRAST3", Default: 0.98))
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CISpotColor.")
        }
        return Final
    }
}
