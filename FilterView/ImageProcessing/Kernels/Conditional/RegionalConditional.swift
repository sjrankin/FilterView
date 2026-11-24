//
//  RegionalConditional.swift
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
import CoreGraphics

/// Cuts the image into regions of like attributes (brightness, hue, and so on), then runs a second filter on the regions whose attribute is
/// greater than, or less than, a value the user sets. The rest of the image is left as it was, or, optionally, removed so that only the
/// second filter's result remains.
final class RegionalConditional: ImageFilter
{
    static let FilterName = "Regional Conditional"

    /// The prefix of options that belong to the second filter. The prefix is removed before they are passed on, so `"INNER_AMOUNT"` reaches
    /// the second filter as `"AMOUNT"`.
    static let InnerPrefix = "INNER_"

    /// The server whose filters can be run as the second filter. Set by the server when it registers this filter.
    weak var Server: FilterServer? = nil

    var FilterType: ImageFilterTypes
    {
        .Conditional
    }

    /// Runs the second filter where the regions pass the test.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "FILTER": The name of the second filter, as registered in `FilterServer`. Required. It cannot be this filter.
    ///   - "ATTRIBUTE": What the regions are made from: one of `RegionAttributes` (`BRIGHTNESS`, `HUE`, `SATURATION`, `RED`, `GREEN`,
    ///   `BLUE`). Default is `BRIGHTNESS`.
    ///   - "BANDS": How many steps the attribute is cut into, 2 to 16. Touching pixels in the same step make one region. More steps
    ///   make smaller, more uniform regions. Default is 8.
    ///   - "COMPARE": `GREATER` (default) runs the second filter on regions whose mean attribute is above "VALUE"; `LESS` on regions below it.
    ///   - "VALUE": The value to compare with, 0.0 to 1.0. Default is 0.5.
    ///   - "REMOVE": `true` makes every pixel that does not pass the test transparent, leaving only the second filter's result. Default is
    ///   `false`.
    ///   - Keys that start with `InnerPrefix`: options for the second filter, with the prefix removed.
    /// - Returns: Processed image, the same size.
    /// - Throws: `FilterException` if the second filter is not named, is this filter, or cannot be found, or if the image cannot be read.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        try Task.checkCancellation()
        let Name = FilterOptionValues.Text(Options, "FILTER", Default: "")
        guard !Name.isEmpty,
              Name != RegionalConditional.FilterName else
        {
            throw FilterException(Message: "Regional Conditional needs a second filter to run.")
        }
        guard let Second = Server?.GetFilter(Name) else
        {
            throw FilterException(Message: "Regional Conditional cannot find \(Name).")
        }
        let Attribute = RegionAttributes(rawValue: FilterOptionValues.Text(Options, "ATTRIBUTE", Default: "BRIGHTNESS")) ?? .Brightness
        let Bands = Int(FilterOptionValues.Number(Options, "BANDS", Default: 8).rounded())
        let Greater = FilterOptionValues.Text(Options, "COMPARE", Default: "GREATER") != "LESS"
        let Threshold = Float(min(max(FilterOptionValues.Number(Options, "VALUE", Default: 0.5), 0), 1))
        let Remove = FilterOptionValues.Flag(Options, "REMOVE")

        var Inner = [String: Any]()
        for (Key, Value) in Options ?? [:] where Key.hasPrefix(RegionalConditional.InnerPrefix)
        {
            Inner[String(Key.dropFirst(RegionalConditional.InnerPrefix.count))] = Value
        }

        let Width = Input.width
        let Height = Input.height
        guard let Original = PixelBuffer.Bytes(Input, Width: Width, Height: Height) else
        {
            throw FilterException(Message: "Regional Conditional cannot read the image.")
        }
        let Regions = RegionFinder.Find(Pixels: Original, Width: Width, Height: Height, Attribute: Attribute, Bands: Bands)
        let Passes = Regions.Means.map{Greater ? $0 > Threshold : $0 < Threshold}
        // Nothing passes: there is no need to run the second filter.
        let Filtered: [UInt8]
        if Passes.contains(true)
        {
            let Result = try await Second.ProcessImage(Input, Inner.isEmpty ? nil : Inner)
            guard let Made = PixelBuffer.Bytes(Result, Width: Width, Height: Height) else
            {
                throw FilterException(Message: "Regional Conditional cannot read the result of \(Name).")
            }
            Filtered = Made
        }
        else
        {
            Filtered = Original
        }
        let Combined = RegionalConditional.Combine(Original: Original, Filtered: Filtered, Regions: Regions, Passes: Passes, Remove: Remove)
        guard let Output = PixelBuffer.Image(Combined, Width: Width, Height: Height) else
        {
            throw FilterException(Message: "Regional Conditional cannot make its image.")
        }
        return Output
    }

    /// Chooses, for each pixel, the second filter's pixel (if its region passed) or the original (or nothing, when removing).
    /// - Parameter Original: 8-bit premultiplied RGBA of the input.
    /// - Parameter Filtered: 8-bit premultiplied RGBA of the second filter's result, the same size.
    /// - Parameter Regions: The regions of the input.
    /// - Parameter Passes: For each region number, whether it passed the test.
    /// - Parameter Remove: If true, pixels that did not pass are made transparent.
    static func Combine(Original: [UInt8], Filtered: [UInt8], Regions: RegionMap, Passes: [Bool], Remove: Bool) -> [UInt8]
    {
        var Result = Original
        for Index in 0 ..< Regions.Labels.count
        {
            let Region = Int(Regions.Labels[Index])
            let Passed = Region >= 0 && Passes[Region]
            if Passed
            {
                for Channel in 0 ..< 4
                {
                    Result[Index * 4 + Channel] = Filtered[Index * 4 + Channel]
                }
            }
            else if Remove
            {
                for Channel in 0 ..< 4
                {
                    Result[Index * 4 + Channel] = 0
                }
            }
        }
        return Result
    }
}
