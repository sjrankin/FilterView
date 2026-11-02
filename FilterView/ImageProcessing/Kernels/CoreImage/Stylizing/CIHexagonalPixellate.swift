//
//  CIHexagonalPixellate.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Makes the image from hexagons. Options: `SCALE` (hexagon size, default 8), and `CENTERX`, `CENTERY` (percent of the width and height;
/// default 50).
class CIHexagonalPixellate: ImageFilter
{
    static let FilterName = "CI Hexagonal Pixellate"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.hexagonalPixellate()
        // Edge pixels are repeated past the edges, so filters that sample around a point do not fade to transparent there.
        filter.inputImage = ci.clampedToExtent()
        filter.scale = Float(FilterOptionValues.Number(Options, "SCALE", Default: 8))
        filter.center = FilterOptionValues.Center(Options, Input)
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIHexagonalPixellate.")
        }
        return Final
    }
}
