//
//  CICircularScreen.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CICircularScreen: ImageFilter
{
    static let FilterName = "CI CircularScreen"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.circularScreen()
        filter.inputImage = ci
        filter.width = 4
        filter.sharpness = 0.9
        filter.center = ImageUtility.CGImageCenter(Input)
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIDotScreen")
        }
        return final
    }
}
