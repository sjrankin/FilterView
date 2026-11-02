//
//  CIEdgeWork.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Makes a woodcut look, black lines on white. Option: `RADIUS` (line thickness, default 3).
class CIEdgeWork: ImageFilter
{
    static let FilterName = "CI Edge Work"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.edgeWork()
        filter.inputImage = ci
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 3))
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIEdgeWork.")
        }
        return Final
    }
}
