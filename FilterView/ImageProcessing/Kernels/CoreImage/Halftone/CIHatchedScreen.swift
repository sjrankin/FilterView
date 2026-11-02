//
//  CIHatchedScreen.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIHatchedScreen: ImageFilter
{
    static let FilterName = "CI HatchedScreen"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.hatchedScreen()
        filter.inputImage = ci
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 90))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 4))
        filter.sharpness = Float(FilterOptionValues.Number(Options, "SHARPNESS", Default: 0.7))
        filter.center = FilterOptionValues.Center(Options, Input)
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIDotScreen")
        }
        return final
    }
}
