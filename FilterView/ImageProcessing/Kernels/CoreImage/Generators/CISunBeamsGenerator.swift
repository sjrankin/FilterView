//
//  CISunBeamsGenerator.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Makes a sun with beams radiating from it. This is a generator, so it does not use the image's pixels, only its size, which the
/// result is cut to. Options:
///   - `CENTERX`, `CENTERY`: where the sun is, as percentages of the width and height (default 50, the middle). Y is measured from the
///   top of the image.
///   - `COLOR`: the color of the sun and beams, as hexadecimal text (default orange, `FF8000FF`).
///   - `SUNRADIUS`: radius of the sun in pixels (default 40).
///   - `MAXSTRIATION`: how far the beams reach, from the sun (default 2.58).
///   - `STRENGTH`: strength of the beams (default 0.5).
///   - `CONTRAST`: contrast of the beams (default 1.375).
///   - `TIME`: moves the beams, 0.0 to 1.0, so they can be animated (default 0).
///   - `OVERIMAGE`: `true` puts the beams over the image; the default `false` shows only the beams.
class CISunBeamsGenerator: ImageFilter
{
    static let FilterName = "CI Sunbeams Generator"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let Orange: [Float] = [1.0, 0.5, 0.0, 1.0]
        let Beams = FilterOptionValues.Color(Options, "COLOR", Default: Orange)
        let filter = CIFilter.sunbeamsGenerator()
        filter.center = FilterOptionValues.Center(Options, Input)
        filter.color = CIColor(red: CGFloat(Beams[0]), green: CGFloat(Beams[1]), blue: CGFloat(Beams[2]), alpha: CGFloat(Beams[3]))
        filter.sunRadius = Float(FilterOptionValues.Number(Options, "SUNRADIUS", Default: 40))
        filter.maxStriationRadius = Float(FilterOptionValues.Number(Options, "MAXSTRIATION", Default: 2.58))
        filter.striationStrength = Float(FilterOptionValues.Number(Options, "STRENGTH", Default: 0.5))
        filter.striationContrast = Float(FilterOptionValues.Number(Options, "CONTRAST", Default: 1.375))
        filter.time = Float(FilterOptionValues.Number(Options, "TIME", Default: 0))
        // The generator's image goes on forever, so it is cut to the size of the input.
        guard var result = filter.outputImage?.cropped(to: ci.extent) else
        {
            throw FilterException(Message: "Error from CISunBeamsGenerator.")
        }
        if FilterOptionValues.Flag(Options, "OVERIMAGE")
        {
            result = result.composited(over: ci)
        }
        guard let final = ImageUtility.CIImageToCGImage(result) else
        {
            throw FilterException(Message: "Error from CISunBeamsGenerator.")
        }
        return final
    }
}
