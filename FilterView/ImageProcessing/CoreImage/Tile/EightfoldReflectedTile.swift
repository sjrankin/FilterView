//
//  EightfoldReflectedTile.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIEightFoldReflectedTile: ImageFilter
{
    static let FilterName = "CI Eightfold Reflected Tile"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.eightfoldReflectedTile()
        filter.inputImage = ci
        filter.center = ImageUtility.CGImageCenter(Input)
        filter.angle = 1.0
        filter.width = 240
        guard let result = filter.outputImage?.cropped(to: ci.extent),
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIEightFoldReflectedTile")
        }
        return final
    }
}
