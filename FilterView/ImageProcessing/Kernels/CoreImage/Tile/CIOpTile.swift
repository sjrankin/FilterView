//
//  CIOpTile.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Makes an op-art tiling by repeating the image at a smaller scale. Options: `CENTERX`, `CENTERY` (percent of the width and height;
/// default 50), `SCALE` (default 2.8), `ANGLE` (degrees; default 0), and `WIDTH` (tile width; default 65).
class CIOpTile: ImageFilter
{
    static let FilterName = "CI Op Tile"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.opTile()
        // Edge pixels are repeated past the edges, so filters that sample around a point do not fade to transparent there.
        filter.inputImage = ci.clampedToExtent()
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.scale = Float(FilterOptionValues.Number(Options, "SCALE", Default: 2.8))
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 0))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 65))
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIOpTile.")
        }
        return Final
    }
}
