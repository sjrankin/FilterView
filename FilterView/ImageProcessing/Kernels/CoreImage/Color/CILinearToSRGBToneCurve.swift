//
//  CILinearToSRGBToneCurve.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CILinearToSRGBToneCurve: ImageFilter
{
    static let FilterName = "CI Linear To sRGB Tone Curve"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.linearToSRGBToneCurve()
        filter.inputImage = ci
        if let final = filter.outputImage
        {
            if let final = ImageUtility.CIImageToCGImage(final)
            {
                return final
            }
        }
        throw FilterException(Message: "Error from CILinearToSRGBToneCurve.")
    }
}
