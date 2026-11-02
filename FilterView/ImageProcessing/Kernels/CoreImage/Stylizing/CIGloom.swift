//
//  CIGloom.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Dulls the highlights with a soft glow. Options: `RADIUS` (default 10) and `INTENSITY` (default 0.5).
class CIGloom: ImageFilter
{
    static let FilterName = "CI Gloom"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.gloom()
        // Edge pixels are repeated past the edges, so filters that sample around a point do not fade to transparent there.
        filter.inputImage = ci.clampedToExtent()
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 10))
        filter.intensity = Float(FilterOptionValues.Number(Options, "INTENSITY", Default: 0.5))
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIGloom.")
        }
        return Final
    }
}
