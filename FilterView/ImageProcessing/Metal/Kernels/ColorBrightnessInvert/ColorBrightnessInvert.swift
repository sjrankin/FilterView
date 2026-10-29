//
//  ColorBrightnessInvert.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

import Foundation
import CoreGraphics

/// Inverts the brightness of an image while keeping its color, using the `InvertBrightnessKeepColor` Metal kernel.
struct ColorBrightnessInvert: ImageFilter
{
    static let FilterName = "Color Bright Invert"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        return try await MetalProcessor.Shared.Run(Kernel: "InvertBrightnessKeepColor", On: Input)
    }
}
