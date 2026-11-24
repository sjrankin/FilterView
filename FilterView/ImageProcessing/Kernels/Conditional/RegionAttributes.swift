//
//  RegionAttributes.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/23/26.
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

/// A property of a pixel that `RegionalConditional` cuts the image into regions by, and compares against the user's value. Every
/// attribute is measured from 0.0 to 1.0.
enum RegionAttributes: String, CaseIterable, Sendable
{
    /// Rec. 709 brightness (luma) of the pixel.
    case Brightness = "BRIGHTNESS"
    /// Hue, as a share of the color wheel: 0 is red, 1/3 green, 2/3 blue, and 1 is red again.
    case Hue = "HUE"
    /// HSV saturation: 0 is gray, 1 is the purest color.
    case Saturation = "SATURATION"
    /// The red channel.
    case Red = "RED"
    /// The green channel.
    case Green = "GREEN"
    /// The blue channel.
    case Blue = "BLUE"

    /// The attribute of a pixel.
    /// - Parameter Red: Red, 0.0 to 1.0, not premultiplied.
    /// - Parameter Green: Green, 0.0 to 1.0, not premultiplied.
    /// - Parameter Blue: Blue, 0.0 to 1.0, not premultiplied.
    /// - Returns: The value of this attribute, 0.0 to 1.0.
    func Value(Red R: Float, Green G: Float, Blue B: Float) -> Float
    {
        switch self
        {
            case .Brightness:
                return min(max(0.2126 * R + 0.7152 * G + 0.0722 * B, 0), 1)

            case .Red:
                return R

            case .Green:
                return G

            case .Blue:
                return B

            case .Saturation:
                let Highest = max(R, G, B)
                return Highest <= 0 ? 0 : (Highest - min(R, G, B)) / Highest

            case .Hue:
                let Highest = max(R, G, B)
                let Delta = Highest - min(R, G, B)
                if Delta <= 0
                {
                    return 0
                }
                var Sector: Float
                if Highest == R
                {
                    Sector = (G - B) / Delta
                }
                else if Highest == G
                {
                    Sector = (B - R) / Delta + 2
                }
                else
                {
                    Sector = (R - G) / Delta + 4
                }
                if Sector < 0
                {
                    Sector += 6
                }
                return Sector / 6
        }
    }
}
