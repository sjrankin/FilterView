//
//  Kaleidoscope.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIKaleidoscope: ImageFilter
{
    static let FilterName = "CI Kaleidoscope"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.kaleidoscope()
        filter.inputImage = ci
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.angle = Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 0))
        filter.count = Int(FilterOptionValues.Number(Options, "COUNT", Default: 6).rounded())
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIKaleidoscope")
        }
        return final
    }
}
