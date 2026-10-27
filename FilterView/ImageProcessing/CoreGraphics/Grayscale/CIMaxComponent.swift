//
//  CIMaxComponent.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIMaxComponent: ImageFilter
{
    static let FilterName = "CI MaxComponent"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.maximumComponent()
        filter.inputImage = ci
        guard let final = filter.outputImage else
        {
            throw FilterException(Message: "No max component output.")
        }
        if let real_final = ImageUtility.CIImageToCGImage(final)
        {
            return real_final
        }
        
        throw FilterException(Message: "Error from CIMaxComponent.")
    }
}
