//
//  KMeansClustering.swift
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

/// A color space or single color attribute that pixels are clustered in.
enum KMeansFeatures: String, CaseIterable, Sendable
{
    /// Red, green, and blue together.
    case RGB = "RGB"
    /// CIE L*a*b*, where distance is close to how different two colors look.
    case Lab = "LAB"
    /// Hue, saturation, and brightness together, as a cone so that hue wraps around.
    case HSB = "HSB"
    /// Rec. 709 brightness only.
    case Brightness = "BRIGHTNESS"
    /// Hue only, around the color wheel.
    case Hue = "HUE"
    /// HSV saturation only.
    case Saturation = "SATURATION"
    /// The red channel only.
    case Red = "RED"
    /// The green channel only.
    case Green = "GREEN"
    /// The blue channel only.
    case Blue = "BLUE"

    /// How many numbers describe a pixel in this space.
    var Dimensions: Int
    {
        switch self
        {
            case .RGB, .Lab, .HSB:
                return 3

            case .Hue:
                return 2

            default:
                return 1
        }
    }

    /// Writes the position of a color in this space.
    /// - Parameter Red: Red, 0.0 to 1.0, not premultiplied.
    /// - Parameter Green: Green, 0.0 to 1.0, not premultiplied.
    /// - Parameter Blue: Blue, 0.0 to 1.0, not premultiplied.
    /// - Returns: `Dimensions` numbers, each about 0.0 to 1.0 in range (Lab is scaled to fit).
    func Position(Red R: Float, Green G: Float, Blue B: Float) -> [Float]
    {
        switch self
        {
            case .RGB:
                return [R, G, B]

            case .Red:
                return [R]

            case .Green:
                return [G]

            case .Blue:
                return [B]

            case .Brightness:
                return [RegionAttributes.Brightness.Value(Red: R, Green: G, Blue: B)]

            case .Saturation:
                return [RegionAttributes.Saturation.Value(Red: R, Green: G, Blue: B)]

            case .Hue:
                let Angle = RegionAttributes.Hue.Value(Red: R, Green: G, Blue: B) * 2 * .pi
                return [cos(Angle) * 0.5 + 0.5, sin(Angle) * 0.5 + 0.5]

            case .HSB:
                let Angle = RegionAttributes.Hue.Value(Red: R, Green: G, Blue: B) * 2 * .pi
                let Saturation = RegionAttributes.Saturation.Value(Red: R, Green: G, Blue: B)
                let Value = max(R, G, B)
                return [Saturation * Value * cos(Angle) * 0.5 + 0.5, Saturation * Value * sin(Angle) * 0.5 + 0.5, Value]

            case .Lab:
                return KMeansFeatures.Lab(Red: R, Green: G, Blue: B)
        }
    }

    /// sRGB to CIE L*a*b* (D65), scaled so L is 0 to 1 and a and b are about 0 to 1 (a and b of -128 to 127).
    private static func Lab(Red: Float, Green: Float, Blue: Float) -> [Float]
    {
        func Linear(_ Value: Float) -> Float
        {
            Value <= 0.04045 ? Value / 12.92 : pow((Value + 0.055) / 1.055, 2.4)
        }
        func Curve(_ Value: Float) -> Float
        {
            Value > 0.008856 ? cbrt(Value) : 7.787 * Value + 16.0 / 116.0
        }
        let R = Linear(Red)
        let G = Linear(Green)
        let B = Linear(Blue)
        let X = Curve((0.4124564 * R + 0.3575761 * G + 0.1804375 * B) / 0.95047)
        let Y = Curve(0.2126729 * R + 0.7151522 * G + 0.0721750 * B)
        let Z = Curve((0.0193339 * R + 0.1191920 * G + 0.9503041 * B) / 1.08883)
        let L = 116 * Y - 16
        let A = 500 * (X - Y)
        let BB = 200 * (Y - Z)
        return [L / 100, (A + 128) / 255, (BB + 128) / 255]
    }
}

/// The result of clustering: which cluster each point is in and where the clusters are.
struct KMeansResult: Sendable
{
    /// The cluster of every point, in the order the points were given.
    let Assignments: [Int]

    /// The center of every cluster, `Dimensions` numbers each, one after another.
    let Centers: [Float]
}

/// k-means clustering of points in a few dimensions.
enum KMeansClustering
{
    /// A small seeded random number generator (SplitMix64), so the same seed always gives the same clusters.
    struct SeededGenerator: RandomNumberGenerator
    {
        private var State: UInt64

        init(Seed: UInt64)
        {
            State = Seed
        }

        mutating func next() -> UInt64
        {
            State &+= 0x9E3779B97F4A7C15
            var Z = State
            Z = (Z ^ (Z >> 30)) &* 0xBF58476D1CE4E5B9
            Z = (Z ^ (Z >> 27)) &* 0x94D049BB133111EB
            return Z ^ (Z >> 31)
        }
    }

    /// Clusters points.
    /// - Parameter Points: The points, `Dimensions` numbers each, one after another.
    /// - Parameter Dimensions: How many numbers make a point.
    /// - Parameter K: How many clusters. Fewer are made if there are fewer points.
    /// - Parameter Iterations: The most rounds of moving points to the nearest center and the centers to the middle of their points.
    /// Stops early when no point changes cluster.
    /// - Parameter Seed: Seed for choosing the first centers (k-means++), so results repeat.
    /// - Returns: The cluster of each point and the cluster centers.
    static func Cluster(Points: [Float], Dimensions: Int, K: Int, Iterations: Int, Seed: UInt64) -> KMeansResult
    {
        let Count = Dimensions > 0 ? Points.count / Dimensions : 0
        guard Count > 0 else
        {
            return KMeansResult(Assignments: [], Centers: [])
        }
        let Clusters = min(max(K, 1), Count)
        var Generator = SeededGenerator(Seed: Seed)

        // k-means++: the first center is a random point; each next one is picked with odds in proportion to its squared distance from the
        // nearest center chosen so far, which spreads the starting centers out.
        var Centers = [Float]()
        let First = Int.random(in: 0 ..< Count, using: &Generator)
        Centers.append(contentsOf: Points[First * Dimensions ..< (First + 1) * Dimensions])
        var Nearest = [Float](repeating: .greatestFiniteMagnitude, count: Count)
        while Centers.count < Clusters * Dimensions
        {
            let Last = Centers.count - Dimensions
            var Total: Double = 0
            for Index in 0 ..< Count
            {
                let Distance = SquaredDistance(Points, Index * Dimensions, Centers, Last, Dimensions)
                Nearest[Index] = min(Nearest[Index], Distance)
                Total += Double(Nearest[Index])
            }
            var Chosen = Count - 1
            if Total > 0
            {
                var Target = Double.random(in: 0 ..< Total, using: &Generator)
                for Index in 0 ..< Count
                {
                    Target -= Double(Nearest[Index])
                    if Target < 0
                    {
                        Chosen = Index
                        break
                    }
                }
            }
            else
            {
                // Every point is already on a center, so the new center repeats one.
                Chosen = Int.random(in: 0 ..< Count, using: &Generator)
            }
            Centers.append(contentsOf: Points[Chosen * Dimensions ..< (Chosen + 1) * Dimensions])
        }

        var Assignments = [Int](repeating: -1, count: Count)
        for _ in 0 ..< max(Iterations, 1)
        {
            var Changed = false
            var Sums = [Double](repeating: 0, count: Clusters * Dimensions)
            var Members = [Int](repeating: 0, count: Clusters)
            for Index in 0 ..< Count
            {
                let Best = NearestCenter(Points, Index * Dimensions, Centers, Clusters, Dimensions)
                if Assignments[Index] != Best
                {
                    Assignments[Index] = Best
                    Changed = true
                }
                Members[Best] += 1
                for Axis in 0 ..< Dimensions
                {
                    Sums[Best * Dimensions + Axis] += Double(Points[Index * Dimensions + Axis])
                }
            }
            for Cluster in 0 ..< Clusters where Members[Cluster] > 0
            {
                for Axis in 0 ..< Dimensions
                {
                    Centers[Cluster * Dimensions + Axis] = Float(Sums[Cluster * Dimensions + Axis] / Double(Members[Cluster]))
                }
            }
            if !Changed
            {
                break
            }
        }
        return KMeansResult(Assignments: Assignments, Centers: Centers)
    }

    /// The cluster whose center is nearest to a point.
    /// - Parameter Points: Array holding the point.
    /// - Parameter Offset: Where the point starts in `Points`.
    /// - Parameter Centers: The cluster centers.
    /// - Parameter Clusters: How many centers there are.
    /// - Parameter Dimensions: How many numbers make a point.
    static func NearestCenter(_ Points: [Float], _ Offset: Int, _ Centers: [Float], _ Clusters: Int, _ Dimensions: Int) -> Int
    {
        var Best = 0
        var BestDistance = Float.greatestFiniteMagnitude
        for Cluster in 0 ..< Clusters
        {
            let Distance = SquaredDistance(Points, Offset, Centers, Cluster * Dimensions, Dimensions)
            if Distance < BestDistance
            {
                BestDistance = Distance
                Best = Cluster
            }
        }
        return Best
    }

    /// The squared distance between a point in one array and a point in another.
    private static func SquaredDistance(_ A: [Float], _ OffsetA: Int, _ B: [Float], _ OffsetB: Int, _ Dimensions: Int) -> Float
    {
        var Total: Float = 0
        for Axis in 0 ..< Dimensions
        {
            let Difference = A[OffsetA + Axis] - B[OffsetB + Axis]
            Total += Difference * Difference
        }
        return Total
    }
}
