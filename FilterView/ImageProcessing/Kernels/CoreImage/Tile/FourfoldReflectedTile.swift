//
//  FourfoldReflectedTile.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIFourFoldReflectedTile: ImageFilter
{
    static let FilterName = "CI Fourfold Reflected Tile"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.fourfoldReflectedTile()
        // Edge pixels are repeated past the edges, so filters that sample around a point do not fade to transparent there.
        filter.inputImage = ci.clampedToExtent()
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 1.0 * 180.0 / .pi))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 240))
        guard let result = filter.outputImage?.cropped(to: ci.extent),
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIFourFoldReflectedTile")
        }
        return final
    }
}
