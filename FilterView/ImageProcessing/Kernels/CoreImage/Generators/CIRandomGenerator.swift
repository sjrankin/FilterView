//
//  CIRandomGenerator.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Makes random color noise the size of the image. It has no options, because the Core Image filter has none.
class CIRandomGenerator: ImageFilter
{
    static let FilterName = "CI Random Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        guard let Result = CIFilter.randomGenerator().outputImage else
        {
            throw FilterException(Message: "Error from CIRandomGenerator.")
        }
        return try GeneratorSupport.Finish(Result, Source: ci, OverImage: false, Name: "CIRandomGenerator")
    }
}
