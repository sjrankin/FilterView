//
//  MetalKuwahara.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
//
//  Copyright 2026 Stuart Rankin
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
