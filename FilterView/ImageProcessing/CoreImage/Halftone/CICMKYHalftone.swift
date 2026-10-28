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
    
    func ProcessImage(_ Input: CGImage) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.cmykHalftone()
        filter.inputImage = ci
        filter.angle = 1
        filter.width = 4
        filter.center = ImageUtility.CGImageCenter(Input)
        filter.grayComponentReplacement = 1
        filter.underColorRemoval = 0.1
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CICMYKHalftone")
        }
        return final
    }
}
