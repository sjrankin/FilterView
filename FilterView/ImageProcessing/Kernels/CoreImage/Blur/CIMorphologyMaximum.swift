//
//  CIMorphologyMaximum.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIMorphologyMaximum: ImageFilter
{
    static let FilterName = "CI MorphologyMaximum"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.morphologyMaximum()
        filter.inputImage = ci
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 5))
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from morphology maximum")
        }
        return final
    }
}
