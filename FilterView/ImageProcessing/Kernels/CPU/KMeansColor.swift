//
//  KMeansColor.swift
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

/// Groups the pixels of an image into `K` clusters of like color, using k-means on the color attribute (or color space) the user picks,
/// then paints each pixel to show its cluster. Clustering on hue, for example, finds the main colors regardless of lightness, while
/// clustering on brightness gives a posterized gray-level look that keeps the original colors.
struct KMeansColor: ImageFilter
{
    static let FilterName = "K-Means"

    /// The most pixels used to find the clusters. A larger image is sampled evenly; every pixel is still assigned to a cluster.
    static let SampleLimit = 40000

    var FilterType: ImageFilterTypes
    {
        .CPU
    }

    /// Clusters the pixels and paints the result.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "FEATURES": What pixels are clustered by: one of `KMeansFeatures` (`RGB`, `LAB`, `HSB`, `BRIGHTNESS`, `HUE`, `SATURATION`,
    ///   `RED`, `GREEN`, `BLUE`). Default is `RGB`.
    ///   - "K": How many clusters, 2 to 16. Default is 5.
    ///   - "ITERATIONS": The most rounds of refinement, 1 to 50. Default is 10.
    ///   - "SEED": Seed for the starting centers, 0 or more. The same seed gives the same clusters. Default is 0.
    ///   - "OUTPUT": How each pixel is painted. `CENTER` (default) gives it the average color of its cluster. `GRAY` gives it a gray
    ///   level that identifies its cluster, evenly spread from black to white in order of cluster brightness. `KEEP` leaves the image
    ///   as it was.
    /// - Returns: Processed image, the same size, with the same alpha.
    /// - Throws: `FilterException` if the image cannot be read.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        try Task.checkCancellation()
        let Features = KMeansFeatures(rawValue: FilterOptionValues.Text(Options, "FEATURES", Default: "RGB")) ?? .RGB
        let K = min(max(Int(FilterOptionValues.Number(Options, "K", Default: 5).rounded()), 2), 16)
        let Iterations = min(max(Int(FilterOptionValues.Number(Options, "ITERATIONS", Default: 10).rounded()), 1), 50)
        let Seed = UInt64(max(FilterOptionValues.Number(Options, "SEED", Default: 0), 0))
        let Output = FilterOptionValues.Text(Options, "OUTPUT", Default: "CENTER")
        let Width = Input.width
        let Height = Input.height
        guard let Pixels = PixelBuffer.Bytes(Input, Width: Width, Height: Height) else
        {
            throw FilterException(Message: "K-Means cannot read the image.")
        }
        let Made = KMeansColor.Paint(Pixels: Pixels, Width: Width, Height: Height, Features: Features, K: K, Iterations: Iterations,
                                     Seed: Seed, Output: Output)
        guard let Result = PixelBuffer.Image(Made, Width: Width, Height: Height) else
        {
            throw FilterException(Message: "K-Means cannot make its image.")
        }
        return Result
    }

    /// Clusters and paints pixels.
    /// - Parameter Pixels: 8-bit premultiplied RGBA.
    /// - Returns: 8-bit premultiplied RGBA of the same size. Fully transparent pixels are left alone and do not take part in clustering.
    static func Paint(Pixels: [UInt8], Width: Int, Height: Int, Features: KMeansFeatures, K: Int, Iterations: Int, Seed: UInt64,
                      Output: String) -> [UInt8]
    {
        let Total = Width * Height
        let Dimensions = Features.Dimensions
        // The opaque-enough pixels, with their positions in the chosen space.
        var Used = [Int]()
        Used.reserveCapacity(Total)
        var Positions = [Float]()
        Positions.reserveCapacity(Total * Dimensions)
        var Colors = [Float]()
        Colors.reserveCapacity(Total * 3)
        for Index in 0 ..< Total
        {
            let Alpha = Float(Pixels[Index * 4 + 3]) / 255
            if Alpha <= 0
            {
                continue
            }
            let R = min(Float(Pixels[Index * 4]) / 255 / Alpha, 1)
            let G = min(Float(Pixels[Index * 4 + 1]) / 255 / Alpha, 1)
            let B = min(Float(Pixels[Index * 4 + 2]) / 255 / Alpha, 1)
            Used.append(Index)
            Positions.append(contentsOf: Features.Position(Red: R, Green: G, Blue: B))
            Colors.append(contentsOf: [R, G, B])
        }
        guard !Used.isEmpty,
              Output != "KEEP" else
        {
            return Pixels
        }

        // Find the clusters from an even sample, then assign every pixel.
        let Stride = max(Used.count / SampleLimit, 1)
        var Sample = [Float]()
        for Slot in Swift.stride(from: 0, to: Used.count, by: Stride)
        {
            Sample.append(contentsOf: Positions[Slot * Dimensions ..< (Slot + 1) * Dimensions])
        }
        let Found = KMeansClustering.Cluster(Points: Sample, Dimensions: Dimensions, K: K, Iterations: Iterations, Seed: Seed)
        let Clusters = Found.Centers.count / Dimensions
        var Labels = [Int](repeating: 0, count: Used.count)
        var Sums = [Double](repeating: 0, count: Clusters * 3)
        var Members = [Int](repeating: 0, count: Clusters)
        for Slot in 0 ..< Used.count
        {
            let Cluster = KMeansClustering.NearestCenter(Positions, Slot * Dimensions, Found.Centers, Clusters, Dimensions)
            Labels[Slot] = Cluster
            Members[Cluster] += 1
            for Channel in 0 ..< 3
            {
                Sums[Cluster * 3 + Channel] += Double(Colors[Slot * 3 + Channel])
            }
        }
        // Average color of each cluster, and the order of the clusters from darkest to brightest.
        var Means = [[Float]](repeating: [0, 0, 0], count: Clusters)
        for Cluster in 0 ..< Clusters where Members[Cluster] > 0
        {
            Means[Cluster] = (0 ..< 3).map{Float(Sums[Cluster * 3 + $0] / Double(Members[Cluster]))}
        }
        let Order = (0 ..< Clusters).sorted
        {
            RegionAttributes.Brightness.Value(Red: Means[$0][0], Green: Means[$0][1], Blue: Means[$0][2]) <
            RegionAttributes.Brightness.Value(Red: Means[$1][0], Green: Means[$1][1], Blue: Means[$1][2])
        }
        var Rank = [Int](repeating: 0, count: Clusters)
        for (Position, Cluster) in Order.enumerated()
        {
            Rank[Cluster] = Position
        }

        var Result = Pixels
        for Slot in 0 ..< Used.count
        {
            let Index = Used[Slot]
            let Cluster = Labels[Slot]
            let Alpha = Float(Pixels[Index * 4 + 3]) / 255
            var Painted: [Float]
            if Output == "GRAY"
            {
                let Level = Clusters > 1 ? Float(Rank[Cluster]) / Float(Clusters - 1) : 0.5
                Painted = [Level, Level, Level]
            }
            else
            {
                Painted = Means[Cluster]
            }
            for Channel in 0 ..< 3
            {
                Result[Index * 4 + Channel] = UInt8(min(max(Painted[Channel] * Alpha * 255 + 0.5, 0), 255))
            }
        }
        return Result
    }
}
