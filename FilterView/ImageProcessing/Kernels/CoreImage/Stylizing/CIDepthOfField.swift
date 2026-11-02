//
//  CIDepthOfField.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Keeps a band between two points sharp and blurs the rest. Options: `P0X`, `P0Y`, `P1X`, `P1Y` (the two points, as percent of the width
/// and height; defaults 25, 50 and 75, 50), `RADIUS` (blur, default 6), `SATURATION` (default 1.5), `MASKRADIUS` (default 2.5), and
/// `MASKINTENSITY` (default 0.5).
class CIDepthOfField: ImageFilter
{
    static let FilterName = "CI Depth Of Field"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.depthOfField()
        // Edge pixels are repeated past the edges, so filters that sample around a point do not fade to transparent there.
        filter.inputImage = ci.clampedToExtent()
        filter.point0 = FilterOptionValues.Point(Options, "P0X", "P0Y", Input, DefaultX: 25, DefaultY: 50)
        filter.point1 = FilterOptionValues.Point(Options, "P1X", "P1Y", Input, DefaultX: 75, DefaultY: 50)
        filter.radius = Float(FilterOptionValues.Number(Options, "RADIUS", Default: 6))
        filter.saturation = Float(FilterOptionValues.Number(Options, "SATURATION", Default: 1.5))
        filter.unsharpMaskRadius = Float(FilterOptionValues.Number(Options, "MASKRADIUS", Default: 2.5))
        filter.unsharpMaskIntensity = Float(FilterOptionValues.Number(Options, "MASKINTENSITY", Default: 0.5))
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIDepthOfField.")
        }
        return Final
    }
}
