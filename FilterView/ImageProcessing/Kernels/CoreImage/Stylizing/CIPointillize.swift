//
//  CIPointillize.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Makes the image from dots. Options: `RADIUS` (dot size, default 20), and `CENTERX`, `CENTERY` (percent of the width and height;
/// default 50).
class CIPointillize: ImageFilter
{
    static let FilterName = "CI Pointillize"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.pointillize()
        // Edge pixels are repeated past the edges, so filters that sample around a point do not fade to transparent there.
        filter.inputImage = ci.clampedToExtent()
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 20))
        filter.center = FilterOptionValues.Center(Options, Input)
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIPointillize.")
        }
        return Final
    }
}
