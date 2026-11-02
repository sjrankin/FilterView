//
//  CICMKYHalftone.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CICMYKHalftone: ImageFilter
{
    static let FilterName = "CI CMYKHalftone"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.cmykHalftone()
        filter.inputImage = ci
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 1.0 * 180.0 / .pi))
        filter.width = Float(FilterOptionValues.Number(Options, "WIDTH", Default: 4))
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.grayComponentReplacement = Float(FilterOptionValues.Number(Options, "GCR", Default: 1))
        filter.underColorRemoval = Float(FilterOptionValues.Number(Options, "UCR", Default: 0.1))
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CICMYKHalftone")
        }
        return final
    }
}
