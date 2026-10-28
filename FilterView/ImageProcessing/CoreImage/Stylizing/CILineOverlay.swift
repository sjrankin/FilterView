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
    
    func ProcessImage(_ Input: CGImage) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.lineOverlay()
        filter.inputImage = ci
        filter.nrNoiseLevel = 0.07
        filter.nrSharpness = 0.85
        filter.edgeIntensity = 1
        filter.threshold = 0.1
        filter.contrast = 50.0
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
