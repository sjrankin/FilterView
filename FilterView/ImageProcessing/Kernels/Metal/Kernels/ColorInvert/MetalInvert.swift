//
//  MetalInvert.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
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

/// Inverts the colors of an image. The `MODE` option picks what is inverted; the work is done by the `InvertColor` kernels,
/// `ConditionalMetalInvert` (single channels and pairs), and `MetalBrightnessInvert` (brightness).
struct MetalInvert: ImageFilter
{
    static let FilterName = "Metal Invert"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    /// Inverts the image.
    /// - Parameter Options: `"MODE"` is `"ALL"` (default), `"BRIGHTNESS"`, or one of the `Channels` raw values (`"RED"`,
    /// `"GREEN"`, `"BLUE"`, `"REDGREEN"`, `"REDBLUE"`, `"GREENBLUE"`). `"COLOR"` applies to `"BRIGHTNESS"` only: when `"true"`
    /// the colors are kept, otherwise the result is gray.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        let Mode = FilterOptionValues.Text(Options, "MODE", Default: "ALL")
        switch Mode
        {
            case "ALL":
                return try await MetalProcessor.Shared.Run(Kernel: "InvertColor", On: Input)
                
            case "BRIGHTNESS":
                return try await MetalBrightnessInvert().ProcessImage(Input, Options)
                
            default:
                // `ConditionalMetalInvert` takes the channel as the only key of its options.
                return try await ConditionalMetalInvert().ProcessImage(Input, [Mode: ""])
        }
    }
}
