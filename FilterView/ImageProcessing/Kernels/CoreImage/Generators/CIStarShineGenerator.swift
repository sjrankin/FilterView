//
//  CIStarShineGenerator.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Makes a star-shaped glint. Options: `CENTERX`, `CENTERY` (percent of the width and height; default 50), `COLOR` (hexadecimal;
/// default `FFCC99FF`), `RADIUS` (pixels; default 50), `CROSSSCALE` (default 15), `CROSSANGLE` (degrees; default 34.4), `CROSSOPACITY`
/// (default -2), `CROSSWIDTH` (default 2.5), `EPSILON` (default -2), and `OVERIMAGE` (`true` puts the star over the image).
class CIStarShineGenerator: ImageFilter
{
    static let FilterName = "CI Star Shine Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let Shine = FilterOptionValues.Color(Options, "COLOR", Default: [1.0, 0.8, 0.6, 1.0])
        let filter = CIFilter.starShineGenerator()
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.color = CIColor(red: CGFloat(Shine[0]), green: CGFloat(Shine[1]), blue: CGFloat(Shine[2]), alpha: CGFloat(Shine[3]))
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 50))
        filter.crossScale = Float(FilterOptionValues.Number(Options, "CROSSSCALE", Default: 15))
        filter.crossAngle = Float(FilterOptionValues.Radians(Options, "CROSSANGLE", DefaultDegrees: 0.6 * 180.0 / .pi))
        filter.crossOpacity = Float(FilterOptionValues.Number(Options, "CROSSOPACITY", Default: -2))
        filter.crossWidth = Float(FilterOptionValues.Number(Options, "CROSSWIDTH", Default: 2.5))
        filter.epsilon = Float(FilterOptionValues.Number(Options, "EPSILON", Default: -2))
        guard let Result = filter.outputImage else
        {
            throw FilterException(Message: "Error from CIStarShineGenerator.")
        }
        return try GeneratorSupport.Finish(Result, Source: ci, OverImage: FilterOptionValues.Flag(Options, "OVERIMAGE"), Name: "CIStarShineGenerator")
    }
}
