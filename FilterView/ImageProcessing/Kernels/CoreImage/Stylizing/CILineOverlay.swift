//
//  CILineOverlay.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

class CILineOverlay: ImageFilter
{
    static let FilterName = "CI LineOverlay"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.lineOverlay()
        filter.inputImage = ci
        filter.nrNoiseLevel = Float(FilterOptionValues.Number(Options, "NOISE", Default: 0.07))
        filter.nrSharpness = Float(FilterOptionValues.Number(Options, "SHARPNESS", Default: 0.85))
        filter.edgeIntensity = Float(FilterOptionValues.Number(Options, "EDGE", Default: 1))
        filter.threshold = Float(FilterOptionValues.Number(Options, "THRESHOLD", Default: 0.1))
        filter.contrast = Float(FilterOptionValues.Number(Options, "CONTRAST", Default: 50))
        //The filter outputs black lines on a transparent background. Put them on white so the result
        //is visible on any background.
        guard let lines = filter.outputImage else
        {
            throw FilterException(Message: "Error from CILineOverlay")
        }
        let white = CIImage(color: .white).cropped(to: ci.extent)
        let result = lines.composited(over: white)
        guard let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CILineOverlay")
        }
        return final
    }
}
