//
//  RegionOptions.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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

/// The options that describe a region of an image, read the same way for every filter that changes the pixels inside a shape
/// (`AlphaShape` and `ColorRegion`), and turned into the parameters their kernels share (see `RegionShape.h`). Missing or unreadable
/// values use the defaults.
///   - `CENTERX`, `CENTERY`: where the middle of the shape is, as percentages of the width and height, with Y from the top. Default is 50, 50,
///   the middle of the image.
///   - `SHAPE`: `CIRCLE` (default), `OVAL`, `SQUARE`, or `RECTANGLE`.
///   - `SIZE`: the length of the shape's long axis (the diameter of a circle, the side of a square), as a percentage of the shorter side of
///   the image. It may be more than 100. Default is 50.
///   - `ASPECT`: for an oval or rectangle, the length of the short axis as a percentage of the long axis, 1 to 100. Default is 50.
///   - `ANGLE`: for an oval or rectangle, the direction of the long axis in degrees, clockwise from the horizontal. Default is 0.
///   - `MODE`: `SET` (default) gives every pixel in the shape the value. `FADEOUT` goes from 1.0 at the edge of the shape to 0.0 at its center.
///   - `INVERT`: `true` keeps the middle and changes the surroundings. Default is `false`.
struct RegionOptions
{
    /// The center of the shape in pixels, from the top left.
    var CenterX: Float
    var CenterY: Float
    /// 0 circle, 1 oval, 2 square, 3 rectangle.
    var Shape: Int
    /// 0 sets the value, 1 fades.
    var Mode: Int
    /// The value `SET` uses, 0.0 to 1.0.
    var Value: Float
    /// Half the length of the long axis and of the short axis, in pixels.
    var HalfLong: Float
    var HalfShort: Float
    /// The angle of the long axis in radians. 0 for a circle or square, which have no direction.
    var Angle: Float
    var Invert: Bool

    /// - Parameter Options: The filter's options.
    /// - Parameter Image: The image, whose size the percentages are of.
    /// - Parameter ValueKey: The key of the value `SET` uses (`ALPHA` for the alpha filter, `LEVEL` for the color one).
    /// - Parameter ValueDefault: The value when there is none.
    init(Options: [String: Any]?, Image: CGImage, ValueKey: String, ValueDefault: Double = 0)
    {
        let Width = Double(Image.width)
        let Height = Double(Image.height)
        CenterX = Float(Width * min(max(FilterOptionValues.Number(Options, "CENTERX", Default: 50), 0), 100) / 100.0)
        CenterY = Float(Height * min(max(FilterOptionValues.Number(Options, "CENTERY", Default: 50), 0), 100) / 100.0)
        Shape = RegionOptions.Shapes(FilterOptionValues.Text(Options, "SHAPE", Default: "CIRCLE"))
        Mode = RegionOptions.Modes(FilterOptionValues.Text(Options, "MODE", Default: "SET"))
        Value = Float(min(max(FilterOptionValues.Number(Options, ValueKey, Default: ValueDefault), 0), 1))
        let LongAxis = max(FilterOptionValues.Number(Options, "SIZE", Default: 50), 0) / 100.0 * min(Width, Height)
        let Aspect = min(max(FilterOptionValues.Number(Options, "ASPECT", Default: 50), 1), 100) / 100.0
        let HasShortAxis = Shape == 1 || Shape == 3
        HalfLong = Float(LongAxis / 2)
        HalfShort = Float(HasShortAxis ? LongAxis * Aspect / 2 : LongAxis / 2)
        Angle = HasShortAxis ? Float(FilterOptionValues.Radians(Options, "ANGLE", DefaultDegrees: 0)) : 0
        Invert = FilterOptionValues.Flag(Options, "INVERT")
    }

    /// The parameters the kernels read from buffer 0, in the order `RegionShape.h` describes.
    var Parameters: [Float]
    {
        [CenterX, CenterY, Float(Shape), Float(Mode), Value, HalfLong, HalfShort, Angle, Invert ? 1 : 0]
    }

    /// The number the kernels use for a shape.
    static func Shapes(_ Name: String) -> Int
    {
        switch Name
        {
            case "OVAL": return 1
            case "SQUARE": return 2
            case "RECTANGLE": return 3
            default: return 0
        }
    }

    /// The number the kernels use for a mode.
    static func Modes(_ Name: String) -> Int
    {
        switch Name
        {
            case "FADEOUT": return 1
            default: return 0
        }
    }
}
