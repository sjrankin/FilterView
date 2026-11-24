//
//  KMeansTests.swift
//  FilterViewTests
//
//  Created by Claude/Stuart Rankin on 11/23/26.
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

import Testing
import Foundation
import CoreGraphics
@testable import FilterView

@MainActor
struct KMeansTests
{
    /// An opaque 30 x 10 image of three solid vertical bands: red, green, and blue, with slight noise in the red channel of each.
    private func Source() -> CGImage
    {
        var Pixels = [UInt8]()
        for Y in 0 ..< 10
        {
            for X in 0 ..< 30
            {
                let Noise = UInt8((X + Y) % 4)
                switch X / 10
                {
                    case 0:
                        Pixels.append(contentsOf: [200 + Noise, 10, 10, 255])

                    case 1:
                        Pixels.append(contentsOf: [10 + Noise, 200, 10, 255])

                    default:
                        Pixels.append(contentsOf: [10 + Noise, 10, 200, 255])
                }
            }
        }
        return PixelBuffer.Image(Pixels, Width: 30, Height: 10)!
    }

    private func Options(_ Extra: [String: Any] = [:]) -> [String: Any]
    {
        var Result: [String: Any] = ["FEATURES": "RGB", "K": "3", "SEED": "1"]
        Result.merge(Extra){_, New in New}
        return Result
    }

    @Test func ClusteringSeparatesObviousGroups()
    {
        // Two tight groups far apart.
        var Points = [Float]()
        for Index in 0 ..< 20
        {
            Points.append(Index < 10 ? 0.1 + Float(Index) * 0.001 : 0.9 + Float(Index) * 0.001)
        }
        let Result = KMeansClustering.Cluster(Points: Points, Dimensions: 1, K: 2, Iterations: 10, Seed: 3)
        #expect(Result.Centers.count == 2)
        #expect(Set(Result.Assignments[0 ..< 10]).count == 1)
        #expect(Set(Result.Assignments[10 ..< 20]).count == 1)
        #expect(Result.Assignments[0] != Result.Assignments[19])
    }

    @Test func SameSeedGivesSameClusters()
    {
        let Points = (0 ..< 300).map{Float(($0 * 37) % 101) / 100}
        let First = KMeansClustering.Cluster(Points: Points, Dimensions: 3, K: 4, Iterations: 10, Seed: 7)
        let Second = KMeansClustering.Cluster(Points: Points, Dimensions: 3, K: 4, Iterations: 10, Seed: 7)
        #expect(First.Assignments == Second.Assignments)
        #expect(First.Centers == Second.Centers)
    }

    @Test func FewerPointsThanClustersStillWorks()
    {
        let Result = KMeansClustering.Cluster(Points: [0.2, 0.8], Dimensions: 1, K: 5, Iterations: 5, Seed: 0)
        #expect(Result.Assignments.count == 2)
        #expect(Result.Centers.count == 2)
    }

    @Test func CenterOutputFlattensNoiseIntoThreeColors() async throws
    {
        let Result = PixelBuffer.Bytes(try await KMeansColor().ProcessImage(Source(), Options()), Width: 30, Height: 10)!
        var Seen = Set<[UInt8]>()
        for Index in 0 ..< 300
        {
            Seen.insert(Array(Result[Index * 4 ..< Index * 4 + 3]))
        }
        #expect(Seen.count == 3)
        // The left band stays reddish, the right band bluish.
        #expect(Result[0] > 150)
        #expect(Result[29 * 4 + 2] > 150)
    }

    @Test func GrayOutputSpansBlackToWhite() async throws
    {
        let Result = PixelBuffer.Bytes(try await KMeansColor().ProcessImage(Source(), Options(["OUTPUT": "GRAY"])), Width: 30, Height: 10)!
        var Levels = Set<UInt8>()
        for Index in 0 ..< 300
        {
            #expect(Result[Index * 4] == Result[Index * 4 + 1])
            Levels.insert(Result[Index * 4])
        }
        #expect(Levels == [0, 128, 255])
    }

    @Test func EveryFeatureSetRuns() async throws
    {
        for Feature in KMeansFeatures.allCases
        {
            let Result = try await KMeansColor().ProcessImage(Source(), Options(["FEATURES": Feature.rawValue]))
            #expect(Result.width == 30)
            #expect(Result.height == 10)
        }
    }

    @Test func HueClusteringIgnoresLightness() async throws
    {
        // Two reds, one dark and one light, and a green: clustering by hue with two clusters pairs the reds.
        var Pixels = [UInt8]()
        for Level in [(240, 20, 20), (110, 10, 10), (20, 220, 20)]
        {
            for _ in 0 ..< 10
            {
                Pixels.append(contentsOf: [UInt8(Level.0), UInt8(Level.1), UInt8(Level.2), 255])
            }
        }
        let Image = PixelBuffer.Image(Pixels, Width: 30, Height: 1)!
        let Result = PixelBuffer.Bytes(try await KMeansColor().ProcessImage(Image, Options(["FEATURES": "HUE", "K": "2"])), Width: 30, Height: 1)!
        #expect(Array(Result[0 ..< 3]) == Array(Result[10 * 4 ..< 10 * 4 + 3]))
        #expect(Array(Result[0 ..< 3]) != Array(Result[20 * 4 ..< 20 * 4 + 3]))
    }

    @Test func TransparentPixelsAreLeftAlone() async throws
    {
        var Pixels = [UInt8](repeating: 0, count: 4 * 4)
        Pixels.replaceSubrange(0 ..< 4, with: [255, 0, 0, 255])
        let Image = PixelBuffer.Image(Pixels, Width: 4, Height: 1)!
        let Result = PixelBuffer.Bytes(try await KMeansColor().ProcessImage(Image, Options()), Width: 4, Height: 1)!
        #expect(Array(Result[4 ..< 16]) == [UInt8](repeating: 0, count: 12))
    }

    @Test func KeepReturnsThePixelsUnchanged() async throws
    {
        let Image = Source()
        let Result = try await KMeansColor().ProcessImage(Image, Options(["OUTPUT": "KEEP"]))
        #expect(PixelBuffer.Bytes(Result, Width: 30, Height: 10) == PixelBuffer.Bytes(Image, Width: 30, Height: 10))
    }

    @Test func TreeEntryIsRegistered() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let Server = FilterServer()
        #expect(FilterTreeLoader.MissingFilters(in: Root, Server: Server).isEmpty)
        #expect(Root.Leaves().contains{$0.Filter == KMeansColor.FilterName})
        #expect(Server.GetFilter(KMeansColor.FilterName)?.FilterType == .CPU)
    }
}
