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
        filter.inputImage = ci
        filter.center = ImageUtility.CGImageCenter(Input)
        filter.angle = 1.0
        filter.width = 240
        guard let result = filter.outputImage?.cropped(to: ci.extent),
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIFourFoldReflectedTile")
        }
        return final
    }
}
