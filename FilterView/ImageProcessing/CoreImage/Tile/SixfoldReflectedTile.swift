//
//  SixfoldReflectedTile.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CISixFoldReflectedTile: ImageFilter
{
    static let FilterName = "CI Sixfold Reflected Tile"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.sixfoldReflectedTile()
        filter.inputImage = ci
        filter.center = ImageUtility.CGImageCenter(Input)
        filter.angle = 1.0
        filter.width = 120
        guard let result = filter.outputImage?.cropped(to: ci.extent),
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CISixFoldReflectedTile")
        }
        return final
    }
}
