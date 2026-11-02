//
//  CIHighlightShadowAdjust.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Brings out detail in highlights and shadows. Options: `HIGHLIGHT` (default 1, which changes nothing), `SHADOW` (default 0, which changes
/// nothing), and `RADIUS` (default 0).
class CIHighlightShadowAdjust: ImageFilter
{
    static let FilterName = "CI Highlight Shadow Adjust"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = ci
        filter.highlightAmount = Float(FilterOptionValues.Number(Options, "HIGHLIGHT", Default: 1))
        filter.shadowAmount = Float(FilterOptionValues.Number(Options, "SHADOW", Default: 0))
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 0))
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIHighlightShadowAdjust.")
        }
        return Final
    }
}
