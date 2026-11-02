//
//  TriangleReflectedTile.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CITriangleFoldReflectedTile: ImageFilter
{
    static let FilterName = "CI Triangle Tile"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.triangleTile()
        filter.inputImage = ci
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 1.0 * 180.0 / .pi))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 120))
        guard let result = filter.outputImage?.cropped(to: ci.extent),
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CITriangleTile")
        }
        return final
    }
}
