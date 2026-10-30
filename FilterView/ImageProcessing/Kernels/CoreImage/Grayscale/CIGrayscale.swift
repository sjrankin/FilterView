//
//  CGGrayscale.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIGrayscale: ImageFilter
{
    static let FilterName = "CI Grayscale"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        if let filter = CIFilter(name: "CIPhotoEffectMono")
        {
            filter.setValue(ci, forKey: kCIInputImageKey)
            if let final = filter.outputImage
            {
                if let final = ImageUtility.CIImageToCGImage(final)
                {
                    return final
                }
            }
        }
        throw FilterException(Message: "Error from CIPhotoEffectMono.")
    }
}
