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
    /// - Parameter Options: Dictionary with at most one key (the value is ignored). Larger radii give a stronger, more
    /// painted look and are slower.
    ///   - "RADIUS2": Radius of 2 pixels.
    ///   - "RADIUS4": Radius of 4 pixels.
    ///   - "RADIUS6": Radius of 6 pixels.
    ///   - "RADIUS8": Radius of 8 pixels.
    /// If no recognized key is present, the radius is `DefaultRadius`.
    /// - Returns: The filtered image.
    /// - Throws: Throws exceptions on error.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        var Radius = MetalKuwahara.DefaultRadius
        for Candidate in [2, 4, 6, 8]
        {
            if Options?["RADIUS\(Candidate)"] != nil
            {
                Radius = Candidate
            }
        }
        return try await MetalProcessor.Shared.Run(Kernel: "Kuwahara", On: Input, Parameters: [Float(Radius)])
    }

    /// Radius in pixels when no radius is given.
    static let DefaultRadius = 4
}
