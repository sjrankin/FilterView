//
//  CIEdges.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Draws the edges of the image, bright on a dark background. Option: `INTENSITY` (default 1).
class CIEdges: ImageFilter
{
    static let FilterName = "CI Edges"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.edges()
        filter.inputImage = ci
        filter.intensity = Float(FilterOptionValues.Number(Options, "INTENSITY", Default: 1))
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIEdges.")
        }
        return Final
    }
}
