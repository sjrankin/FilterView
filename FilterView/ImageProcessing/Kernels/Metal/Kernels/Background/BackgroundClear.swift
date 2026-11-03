//
//  BackgroundClear.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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

/// Replaces a target color (and colors near it) with a replacement color, which may be transparent.
struct BackgroundClear: ImageFilter
{
    static let FilterName = "BackgroundClear"
    
    var FilterType: ImageFilterTypes
    {
        .Metal
    }
    
    /// Replaces every pixel whose color is within the tolerance of the target color with the replacement color.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Dictionary of `[String: Any]` with the recognized keys in the Notes. Missing or unreadable values
    /// use the defaults.
    /// - Returns: Processed image.
    /// - Throws: Throws exceptions on error.
    /// - Note: Colors are strings of hexadecimal digits, `RRGGBB` or `RRGGBBAA` (with or without a leading `#`). Colors
    /// without an alpha are opaque. Alpha is part of the comparison, so an opaque target does not match transparent pixels.
    ///   - "TARGET": The color to look for. Default is opaque white.
    ///   - "SOURCE": The color that replaces it. Default is fully transparent (`00000000`), which clears the background.
    ///   - "TOLERANCE": A normal value, 0.0 to 1.0. 0.0 matches only the exact target color and 1.0 matches every color.
    ///   Default is 0.1.
    ///   - "IGNOREALPHA": `true` compares only the red, green, and blue of each pixel and of the target, so a pixel that is partly
    ///   transparent is matched by its color alone. A fully transparent pixel has no color and is never matched. Default is `false`, when
    ///   alpha counts as a fourth part of the color.
    ///   - "KEEPALPHA": `true` replaces only the color of a matched pixel and leaves its alpha as it was, so the alpha of "SOURCE" is not
    ///   used. Default is `false`, when the replacement is written as it is, alpha included.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        let Target = FilterOptionValues.ParseColor(Options?["TARGET"] as? String) ?? [1, 1, 1, 1]
        let Replacement = FilterOptionValues.ParseColor(Options?["SOURCE"] as? String) ?? [0, 0, 0, 0]
        var Tolerance = BackgroundClear.DefaultTolerance
        if let Text = Options?["TOLERANCE"] as? String,
           let Value = Float(Text)
        {
            Tolerance = min(max(Value, 0.0), 1.0)
        }
        return try await MetalProcessor.Shared.Run(Kernel: "BackgroundClear",
                                                   On: Input,
                                                   Parameters: Target + Replacement + [Tolerance,
                                                                                         FilterOptionValues.Flag(Options, "IGNOREALPHA") ? 1 : 0,
                                                                                         FilterOptionValues.Flag(Options, "KEEPALPHA") ? 1 : 0])
    }
    
    /// Tolerance when none is given.
    static let DefaultTolerance: Float = 0.1
}
