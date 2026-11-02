//
//  CIGlideReflectedTile.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Tiles the image in rows of tiles that alternate between the image and its mirror image. Options: `CENTERX`, `CENTERY` (percent of the
/// width and height; default 50), `ANGLE` (degrees; default 0), and `WIDTH` (tile width; default 70).
class CIGlideReflectedTile: ImageFilter
{
    static let FilterName = "CI Glide Reflected Tile"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.glideReflectedTile()
        // Edge pixels are repeated past the edges, so filters that sample around a point do not fade to transparent there.
        filter.inputImage = ci.clampedToExtent()
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 0))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 70))
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIGlideReflectedTile.")
        }
        return Final
    }
}
