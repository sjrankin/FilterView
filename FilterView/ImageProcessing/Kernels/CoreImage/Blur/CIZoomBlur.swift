//
//  CIZoomBlur.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIZoomBlur: ImageFilter
{
    static let FilterName = "CI Zoom Blur"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.zoomBlur()
        filter.inputImage = ci
        filter.amount = Float(FilterOptionValues.Number(Options, "AMOUNT", Default: 5))
        filter.center = FilterOptionValues.Center(Options, Input)
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from zoom blur")
        }
        return final
    }
}
