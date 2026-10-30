//
//  CIComicEffect.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CIComicEffect: ImageFilter
{
    static let FilterName = "CI ComicEffect"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.comicEffect()
        filter.inputImage = ci
        guard let result = filter.outputImage,
              let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CIComicEffect")
        }
        return final
    }
}
