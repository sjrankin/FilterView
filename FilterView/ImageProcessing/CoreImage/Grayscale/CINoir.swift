//
//  CINoir.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CINoir: ImageFilter
{
    static let FilterName = "CI Noir"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        if let filter = CIFilter(name: "CIPhotoEffectNoir")
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
        throw FilterException(Message: "Error from CINoir.")
    }
}
