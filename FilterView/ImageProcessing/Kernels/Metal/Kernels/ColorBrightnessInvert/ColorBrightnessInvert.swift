//
//  ColorBrightnessInvert.swift
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
