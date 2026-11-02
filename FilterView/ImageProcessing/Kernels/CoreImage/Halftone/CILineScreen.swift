//
//  CILineScreen.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CILineScreen: ImageFilter
{
    static let FilterName = "CI LineScreen"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.lineScreen()
        filter.inputImage = ci
        // Use radians.
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 90))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 4))
        filter.sharpness = Float(FilterOptionValues.Number(Options, "SHARPNESS", Default: 0.9))
        filter.center = FilterOptionValues.Center(Options, Input)
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIDotScreen")
        }
        return final
    }
}
