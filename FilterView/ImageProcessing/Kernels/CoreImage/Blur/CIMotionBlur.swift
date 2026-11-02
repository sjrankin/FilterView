//
//  CIMotionBlur.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIMotionBlur: ImageFilter
{
    static let FilterName = "CI Motion Blur"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.motionBlur()
        filter.inputImage = ci
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 0))
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 20))
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from motion blur")
        }
        return final
    }
}
