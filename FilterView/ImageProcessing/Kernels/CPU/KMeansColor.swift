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
///
/// The clusters are found on the CPU from an even sample of at most `SampleLimit` pixels, which is quick however large the image is.
/// Every pixel of the image is then given to its nearest cluster and painted on the GPU (`KMeansPaint.metal`), which is where the time
/// went when this was all done on the CPU. If Metal is not there the CPU does the painting too.
struct KMeansColor: ImageFilter
{
    static let FilterName = "K-Means"

    /// The most pixels used to find the clusters. A larger image is sampled evenly; every pixel is still assigned to a cluster.
    static let SampleLimit = 40000

    /// The most clusters. The GPU kernel holds this many centers.
    static let MaxClusters = 16

    var FilterType: ImageFilterTypes
    {
        .Metal
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
        let K = min(max(Int(FilterOptionValues.Number(Options, "K", Default: 5).rounded()), 2), KMeansColor.MaxClusters)
        let Iterations = min(max(Int(FilterOptionValues.Number(Options, "ITERATIONS", Default: 10).rounded()), 1), 50)
        let Seed = UInt64(max(FilterOptionValues.Number(Options, "SEED", Default: 0), 0))
        let Output = FilterOptionValues.Text(Options, "OUTPUT", Default: "CENTER")
        let Width = Input.width
        let Height = Input.height
        guard let Pixels = PixelBuffer.Bytes(Input, Width: Width, Height: Height) else
        {
            throw FilterException(Message: "K-Means cannot read the image.")
        }
        guard let Found = KMeansColor.Analyse(Pixels: Pixels, Width: Width, Height: Height, Features: Features, K: K,
                                              Iterations: Iterations, Seed: Seed, Output: Output) else
        {
            // Nothing to cluster, or the image is to be kept as it is.
            return Input
        }
        try Task.checkCancellation()
        do
        {
            return try await MetalProcessor.Shared.Run(Kernel: "KMeansPaint", On: Input, Parameters: Found.KernelParameters(Features))
        }
        catch
        {
            #if DEBUG
            print("K-Means on the GPU failed, so the CPU paints it: \(error)")
            #endif
        }
        let Made = KMeansColor.PaintOnCPU(Pixels: Pixels, Width: Width, Height: Height, Features: Features, Found: Found)
        guard let Result = PixelBuffer.Image(Made, Width: Width, Height: Height) else
        {
            throw FilterException(Message: "K-Means cannot make its image.")
        }
        return Result
    }

    /// What clustering found: where the clusters are and the color each one is painted.
    struct Clusters: Sendable
    {
        /// How many numbers make a point in the feature space.
        let Dimensions: Int
        /// The cluster centers, `Dimensions` numbers each.
        let Centers: [Float]
        /// The color each cluster is painted, red, green and blue, 0.0 to 1.0, three numbers each.
        let Painted: [Float]

        /// How many clusters there are.
        var Count: Int
        {
            Painted.count / 3
        }

        /// The values handed to the GPU kernel: the feature, the number of dimensions and clusters, then the centers and painted colors
        /// with room for `MaxClusters` of each, three numbers apiece.
        /// - Parameter Features: The feature space.
        func KernelParameters(_ Features: KMeansFeatures) -> [Float]
        {
            let Room = KMeansColor.MaxClusters * 3
            var Values = [Float](repeating: 0, count: 4 + Room * 2)
            Values[0] = Float(Features.KernelCode)
            Values[1] = Float(Dimensions)
            Values[2] = Float(Count)
            for Cluster in 0 ..< Count
            {
                for Axis in 0 ..< Dimensions
                {
                    Values[4 + Cluster * 3 + Axis] = Centers[Cluster * Dimensions + Axis]
                }
                for Channel in 0 ..< 3
                {
                    Values[4 + Room + Cluster * 3 + Channel] = Painted[Cluster * 3 + Channel]
                }
            }
            return Values
        }
    }

    /// Finds the clusters from an even sample of the pixels, and the color each is painted.
    /// - Parameter Pixels: 8-bit premultiplied RGBA.
    /// - Returns: The clusters, or `nil` if every pixel is transparent or the output is `KEEP`, when the image stays as it is.
    static func Analyse(Pixels: [UInt8], Width: Int, Height: Int, Features: KMeansFeatures, K: Int, Iterations: Int, Seed: UInt64,
                        Output: String) -> Clusters?
    {
        guard Output != "KEEP" else
        {
            return nil
        }
        let Total = Width * Height
        let Dimensions = Features.Dimensions
        // An even sample of the pixels that are not transparent. Only these are looked at, so a large image costs no more than a small one.
        let Stride = max(Total / SampleLimit, 1)
        var Positions = [Float]()
        var Colors = [Float]()
        for Index in Swift.stride(from: 0, to: Total, by: Stride)
        {
            let Alpha = Float(Pixels[Index * 4 + 3]) / 255
            if Alpha <= 0
            {
                continue
            }
            let R = min(Float(Pixels[Index * 4]) / 255 / Alpha, 1)
            let G = min(Float(Pixels[Index * 4 + 1]) / 255 / Alpha, 1)
            let B = min(Float(Pixels[Index * 4 + 2]) / 255 / Alpha, 1)
            Positions.append(contentsOf: Features.Position(Red: R, Green: G, Blue: B))
            Colors.append(contentsOf: [R, G, B])
        }
        guard !Positions.isEmpty else
        {
            return nil
        }
        let Found = KMeansClustering.Cluster(Points: Positions, Dimensions: Dimensions, K: K, Iterations: Iterations, Seed: Seed)
        let Count = Found.Centers.count / Dimensions
        // The average color of each cluster, from the sample.
        var Sums = [Double](repeating: 0, count: Count * 3)
        var Members = [Int](repeating: 0, count: Count)
        for Slot in 0 ..< Found.Assignments.count
        {
            let Cluster = Found.Assignments[Slot]
            Members[Cluster] += 1
            for Channel in 0 ..< 3
            {
                Sums[Cluster * 3 + Channel] += Double(Colors[Slot * 3 + Channel])
            }
        }
        var Means = [[Float]](repeating: [0, 0, 0], count: Count)
        for Cluster in 0 ..< Count where Members[Cluster] > 0
        {
            Means[Cluster] = (0 ..< 3).map{Float(Sums[Cluster * 3 + $0] / Double(Members[Cluster]))}
        }
        var Painted = [Float]()
        if Output == "GRAY"
        {
            // A gray level for each cluster, spread from black to white in order of the cluster's brightness.
            let Order = (0 ..< Count).sorted
            {
                RegionAttributes.Brightness.Value(Red: Means[$0][0], Green: Means[$0][1], Blue: Means[$0][2]) <
                RegionAttributes.Brightness.Value(Red: Means[$1][0], Green: Means[$1][1], Blue: Means[$1][2])
            }
            var Rank = [Int](repeating: 0, count: Count)
            for (Position, Cluster) in Order.enumerated()
            {
                Rank[Cluster] = Position
            }
            for Cluster in 0 ..< Count
            {
                let Level = Count > 1 ? Float(Rank[Cluster]) / Float(Count - 1) : 0.5
                Painted.append(contentsOf: [Level, Level, Level])
            }
        }
        else
        {
            Painted = Means.flatMap{$0}
        }
        return Clusters(Dimensions: Dimensions, Centers: Found.Centers, Painted: Painted)
    }

    /// Clusters and paints pixels on the CPU.
    /// - Parameter Pixels: 8-bit premultiplied RGBA.
    /// - Returns: 8-bit premultiplied RGBA of the same size. Fully transparent pixels are left alone and do not take part in clustering.
    static func Paint(Pixels: [UInt8], Width: Int, Height: Int, Features: KMeansFeatures, K: Int, Iterations: Int, Seed: UInt64,
                      Output: String) -> [UInt8]
    {
        guard let Found = Analyse(Pixels: Pixels, Width: Width, Height: Height, Features: Features, K: K, Iterations: Iterations,
                                  Seed: Seed, Output: Output) else
        {
            return Pixels
        }
        return PaintOnCPU(Pixels: Pixels, Width: Width, Height: Height, Features: Features, Found: Found)
    }

    /// Gives every pixel to its nearest cluster and paints it, on the CPU. This is what the GPU kernel does.
    static func PaintOnCPU(Pixels: [UInt8], Width: Int, Height: Int, Features: KMeansFeatures, Found: Clusters) -> [UInt8]
    {
        var Result = Pixels
        for Index in 0 ..< Width * Height
        {
            let Alpha = Float(Pixels[Index * 4 + 3]) / 255
            if Alpha <= 0
            {
                continue
            }
            let R = min(Float(Pixels[Index * 4]) / 255 / Alpha, 1)
            let G = min(Float(Pixels[Index * 4 + 1]) / 255 / Alpha, 1)
            let B = min(Float(Pixels[Index * 4 + 2]) / 255 / Alpha, 1)
            let Point = Features.Position(Red: R, Green: G, Blue: B)
            let Cluster = KMeansClustering.NearestCenter(Point, 0, Found.Centers, Found.Count, Found.Dimensions)
            for Channel in 0 ..< 3
            {
                Result[Index * 4 + Channel] = UInt8(min(max(Found.Painted[Cluster * 3 + Channel] * Alpha * 255 + 0.5, 0), 255))
            }
        }
        return Result
    }
}
