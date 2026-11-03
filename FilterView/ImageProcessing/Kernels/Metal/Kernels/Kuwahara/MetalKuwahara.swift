//
//  MetalKuwahara.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
//

import Foundation
import CoreGraphics

/// Edge-preserving painterly smoothing using the `Kuwahara` Metal kernel.
struct MetalKuwahara: ImageFilter
{
    static let FilterName = "Metal Kuwahara"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    /// Applies the Kuwahara filter.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Dictionary with the radius. Larger radii give a stronger, more painted look and are slower.
    ///   - "RADIUS": Radius in pixels: 2, 4, 6, or 8. Anything else is `DefaultRadius`.
    /// - Returns: The filtered image.
    /// - Throws: Throws exceptions on error.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        var Radius = Int(FilterOptionValues.Number(Options, "RADIUS", Default: Double(MetalKuwahara.DefaultRadius)))
        if ![2, 4, 6, 8].contains(Radius)
        {
            Radius = MetalKuwahara.DefaultRadius
        }
        return try await MetalProcessor.Shared.Run(Kernel: "Kuwahara", On: Input, Parameters: [Float(Radius)])
    }

    /// Radius in pixels when no radius is given.
    static let DefaultRadius = 4
}
