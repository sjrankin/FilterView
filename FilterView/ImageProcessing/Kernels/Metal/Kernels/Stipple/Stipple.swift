//
//  Stipple.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/17/26.
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

import Foundation
import CoreGraphics

/// Paints an image with two colors and scatters dots over it: the brighter a part of the original image was, the more dots it gets.
/// The work is done by the `Stipple` Metal kernel in one pass.
struct Stipple: ImageFilter
{
    static let FilterName = "Stipple"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    /// Stipples the image.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "BANDS": How many brightness regions to cut the image into, 2 to 16. Less than 2 uses no regions: the dots follow each pixel's
    ///   brightness smoothly. Default is 0 (smooth).
    ///   - "DENSITY": The share of the brightest pixels or region that become dots, 0.0 to 1.0. Darker ones get fewer, the darkest none.
    ///   Default is 1.
    ///   - "CURVE": Tone curve exponent, 0.2 to 5. The share of dots is the brightness to this power; above 1 thins out the dots in all but
    ///   the brightest parts. Default is 2.
    ///   - "TEXTURE": 0.0 to 1.0. More makes dots in the same row or column tend to appear together, giving streaks and a faint lattice.
    ///   Default is 0.5.
    ///   - "DOTSIZE": Dot size in pixels, 1 to 16. Default is 1.
    ///   - "SEED": Seed for the random placement, 0 or more. The same seed gives the same dots. Default is 0.
    ///   - "BASE": The color of everything that is not a dot, `RRGGBB`. Default is black.
    ///   - "DOT": The color of the dots, `RRGGBB`. Default is white.
    /// - Returns: Processed image, the same size, with the same alpha.
    /// - Throws: Throws exceptions on error.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        let Bands = min(max(FilterOptionValues.Number(Options, "BANDS", Default: 0), 0), 16)
        let Density = min(max(FilterOptionValues.Number(Options, "DENSITY", Default: 1), 0), 1)
        let Curve = min(max(FilterOptionValues.Number(Options, "CURVE", Default: 2), 0.2), 5)
        let Texture = min(max(FilterOptionValues.Number(Options, "TEXTURE", Default: 0.5), 0), 1)
        let DotSize = min(max(FilterOptionValues.Number(Options, "DOTSIZE", Default: 1), 1), 16)
        let Seed = max(FilterOptionValues.Number(Options, "SEED", Default: 0), 0)
        let Base = FilterOptionValues.Color(Options, "BASE", Default: [0, 0, 0, 1])
        let Dot = FilterOptionValues.Color(Options, "DOT", Default: [1, 1, 1, 1])
        let Parameters: [Float] = [Float(Bands), Float(Density), Float(DotSize), Float(Seed),
                                   Base[0], Base[1], Base[2], Dot[0], Dot[1], Dot[2], Float(Curve), Float(Texture)]
        return try await MetalProcessor.Shared.Run(Kernel: "Stipple", On: Input, Parameters: Parameters)
    }
}
