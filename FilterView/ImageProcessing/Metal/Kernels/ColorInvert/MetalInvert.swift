//
//  MetalInvert.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

import Foundation
import CoreGraphics

/// Inverts the colors of an image using the `InvertColor` Metal kernel.
struct MetalInvert: ImageFilter
{
    static let FilterName = "Metal Invert"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    func ProcessImage(_ Input: CGImage) async throws -> CGImage
    {
        return try await MetalProcessor.Shared.Run(Kernel: "InvertColor", On: Input)
    }
}
