//
//  RegionFinder.swift
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

/// The regions found in an image: groups of touching pixels that share an attribute band.
struct RegionMap: Sendable
{
    /// Width of the image in pixels.
    let Width: Int

    /// Height of the image in pixels.
    let Height: Int

    /// The region of each pixel, row by row from the top. -1 for a pixel that is in no region (fully transparent).
    let Labels: [Int32]

    /// The mean attribute (0.0 to 1.0) of each region, indexed by region number. For hue it is the mean direction on the color wheel.
    let Means: [Float]

    /// The number of regions.
    var Count: Int
    {
        Means.count
    }
}

/// Cuts an image into regions of like attributes.
enum RegionFinder
{
    /// Finds the regions of an image. A pixel's band is its attribute cut into `Bands` equal steps; a region is a set of pixels in the same
    /// band that touch each other above, below, left, or right.
    /// - Parameter Pixels: 8-bit RGBA, premultiplied, row by row from the top.
    /// - Parameter Width: Width of the image.
    /// - Parameter Height: Height of the image.
    /// - Parameter Attribute: The attribute to cut the image by.
    /// - Parameter Bands: How many bands, clamped to 2 through 16.
    /// - Returns: The region map. Fully transparent pixels belong to no region.
    static func Find(Pixels: [UInt8], Width: Int, Height: Int, Attribute: RegionAttributes, Bands: Int) -> RegionMap
    {
        let Steps = min(max(Bands, 2), 16)
        let Total = Width * Height
        guard Total > 0,
              Pixels.count >= Total * 4 else
        {
            return RegionMap(Width: Width, Height: Height, Labels: [], Means: [])
        }
        var Values = [Float](repeating: 0, count: Total)
        var Band = [Int8](repeating: -1, count: Total)
        for Index in 0 ..< Total
        {
            let Alpha = Float(Pixels[Index * 4 + 3]) / 255
            if Alpha <= 0
            {
                continue
            }
            let Red = min(Float(Pixels[Index * 4]) / 255 / Alpha, 1)
            let Green = min(Float(Pixels[Index * 4 + 1]) / 255 / Alpha, 1)
            let Blue = min(Float(Pixels[Index * 4 + 2]) / 255 / Alpha, 1)
            let Value = Attribute.Value(Red: Red, Green: Green, Blue: Blue)
            Values[Index] = Value
            Band[Index] = Int8(min(Int(Value * Float(Steps)), Steps - 1))
        }

        // Union-find over the pixels: each pixel joins the pixel to its left and the one above when they share a band.
        var Parent = [Int32](repeating: 0, count: Total)
        for Index in 0 ..< Total
        {
            Parent[Index] = Int32(Index)
        }
        func Root(_ Start: Int) -> Int
        {
            var Current = Start
            while Int(Parent[Current]) != Current
            {
                Parent[Current] = Parent[Int(Parent[Current])]
                Current = Int(Parent[Current])
            }
            return Current
        }
        for Y in 0 ..< Height
        {
            for X in 0 ..< Width
            {
                let Index = Y * Width + X
                if Band[Index] < 0
                {
                    continue
                }
                if X > 0,
                   Band[Index - 1] == Band[Index]
                {
                    Parent[Root(Index)] = Int32(Root(Index - 1))
                }
                if Y > 0,
                   Band[Index - Width] == Band[Index]
                {
                    Parent[Root(Index)] = Int32(Root(Index - Width))
                }
            }
        }

        // Number the regions and total their pixels. Hue is a circle, so it is averaged as a direction.
        var Numbers = [Int32](repeating: -1, count: Total)
        var Labels = [Int32](repeating: -1, count: Total)
        var Sums = [Double]()
        var Cosines = [Double]()
        var Counts = [Int]()
        for Index in 0 ..< Total where Band[Index] >= 0
        {
            let Top = Root(Index)
            if Numbers[Top] < 0
            {
                Numbers[Top] = Int32(Sums.count)
                Sums.append(0)
                Cosines.append(0)
                Counts.append(0)
            }
            let Region = Int(Numbers[Top])
            Labels[Index] = Int32(Region)
            Counts[Region] += 1
            if Attribute == .Hue
            {
                Sums[Region] += sin(Double(Values[Index]) * 2 * .pi)
                Cosines[Region] += cos(Double(Values[Index]) * 2 * .pi)
            }
            else
            {
                Sums[Region] += Double(Values[Index])
            }
        }
        var Means = [Float](repeating: 0, count: Sums.count)
        for Region in 0 ..< Sums.count
        {
            if Attribute == .Hue
            {
                var Angle = atan2(Sums[Region], Cosines[Region]) / (2 * .pi)
                if Angle < 0
                {
                    Angle += 1
                }
                Means[Region] = Float(Angle)
            }
            else
            {
                Means[Region] = Float(Sums[Region] / Double(Counts[Region]))
            }
        }
        return RegionMap(Width: Width, Height: Height, Labels: Labels, Means: Means)
    }
}
