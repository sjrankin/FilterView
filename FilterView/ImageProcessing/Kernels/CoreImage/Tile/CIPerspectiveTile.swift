//
//  CIPerspectiveTile.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Tiles the image as if it were seen in perspective. The four corners of the tile are points given as percent of the width and height (Y
/// from the top): `TLX`, `TLY` (top left; default 20, 20), `TRX`, `TRY` (top right; 80, 20), `BRX`, `BRY` (bottom right; 80, 80), and `BLX`,
/// `BLY` (bottom left; 20, 80).
class CIPerspectiveTile: ImageFilter
{
    static let FilterName = "CI Perspective Tile"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.perspectiveTile()
        // Edge pixels are repeated past the edges, so filters that sample around a point do not fade to transparent there.
        filter.inputImage = ci.clampedToExtent()
        filter.topLeft = FilterOptionValues.Point(Options, "TLX", "TLY", Input, DefaultX: 20, DefaultY: 20)
        filter.topRight = FilterOptionValues.Point(Options, "TRX", "TRY", Input, DefaultX: 80, DefaultY: 20)
        filter.bottomRight = FilterOptionValues.Point(Options, "BRX", "BRY", Input, DefaultX: 80, DefaultY: 80)
        filter.bottomLeft = FilterOptionValues.Point(Options, "BLX", "BLY", Input, DefaultX: 20, DefaultY: 80)
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CIPerspectiveTile.")
        }
        return Final
    }
}
