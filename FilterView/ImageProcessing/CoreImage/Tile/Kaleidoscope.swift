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
        filter.center = ImageUtility.CGImageCenter(Input)
        filter.angle = 0.0
        filter.count = 6
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIKaleidoscope")
        }
        return final
    }
}
