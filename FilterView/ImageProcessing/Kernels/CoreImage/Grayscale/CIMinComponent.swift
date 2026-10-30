//
//  CIMinComponent.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIMinComponent: ImageFilter
{
    static let FilterName = "CI MinComponent"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.minimumComponent()
        filter.inputImage = ci
        guard let final = filter.outputImage else
        {
            throw FilterException(Message: "No min component output.")
        }
        if let real_final = ImageUtility.CIImageToCGImage(final)
        {
            return real_final
        }
        
        throw FilterException(Message: "Error from CIMinComponent.")
    }
}
