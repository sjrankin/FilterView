//
//  BrightnessInvert.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

import Foundation
import CoreGraphics

/// Inverts the brightness of an image using the `InvertBrightness` Metal kernel.
struct MetalBrightnessInvert: ImageFilter
{
    static let FilterName = "Metal Bright Invert"
    
    var FilterType: ImageFilterTypes
    {
        .Metal
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        return try await MetalProcessor.Shared.Run(Kernel: "InvertBrightness", On: Input)
    }
}
