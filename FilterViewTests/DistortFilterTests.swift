//
//  DistortFilterTests.swift
//  FilterViewTests
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

import Testing
import Foundation
import CoreGraphics
@testable import FilterView

@MainActor
struct DistortFilterTests
{
    /// The options the filter gets when its entry is chosen in the tree and nothing has been changed.
    private func Defaults(_ Leaf: FilterNode) -> [String: String]
    {
        var Result = Leaf.Options ?? [:]
        for Parameter in Leaf.Parameters ?? []
        {
            Result[Parameter.Key] = Parameter.Default
        }
        return Result
    }

    private func Group(_ Name: String, in Node: FilterNode) -> FilterNode?
    {
        if Node.Name == Name
        {
            return Node
        }
        return (Node.Children ?? []).compactMap{Group(Name, in: $0)}.first
    }

    @Test func EveryEntryInTheTreeNamesARegisteredFilter() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        #expect(FilterTreeLoader.MissingFilters(in: Root, Server: FilterServer()).isEmpty)
    }

    @Test func TheNewEntriesNameRegisteredFilters() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let New = try #require(Group("Distort", in: Root)).Leaves() + (try #require(Group("Text Image", in: Root)).Leaves())
        let Server = FilterServer()
        #expect(New.count == 12)
        #expect(New.compactMap{$0.Filter}.filter{Server.GetFilter($0) == nil}.isEmpty)
    }

    @Test func TheDistortGroupHasTheRequestedFiltersInOrder() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let Distort = try #require(Group("Distort", in: Root))
        #expect(Distort.Children?.map{$0.Name} == ["Bump Distortion", "Circular Wrap", "Droste", "Glass Distortion", "Glass Lozenge",
                                                   "Light Tunnel", "Pinch Distortion", "Stretch Crop", "Torus Lens Distortion",
                                                   "Twirl Distortion", "Vortex Distortion"])
        let Generators = try #require(Group("Generators", in: Root))
        #expect(Generators.Children?.contains{$0.Filter == CITextImageGenerator.FilterName} == true)
    }

    @Test func EveryDistortionRunsWithItsDefaultsAndKeepsTheSize() async throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let Server = FilterServer()
        let Source = TestSupport.MakeImage(Width: 200, Height: 120)
        for Leaf in try #require(Group("Distort", in: Root)).Leaves()
        {
            let Result = try await Server.Run(Filter: try #require(Leaf.Filter), With: Source, Defaults(Leaf))
            #expect(Result.width == 200 && Result.height == 120, "\(Leaf.Name)")
        }
    }

    @Test func GlassDistortionWorksWithNoiseTexture() async throws
    {
        var Options = ["TEXTURE": "NOISE", "SMOOTHING": "2", "SCALE": "50"]
        let Result = try await FilterServer().Run(Filter: CIGlassDistortion.FilterName, With: TestSupport.MakeImage(Width: 100, Height: 80), Options)
        #expect(Result.width == 100 && Result.height == 80)
        Options["SMOOTHING"] = "0"
        _ = try await FilterServer().Run(Filter: CIGlassDistortion.FilterName, With: TestSupport.MakeImage(), Options)
    }

    @Test func StretchCropFollowsTheRequestedSize() async throws
    {
        let Options = ["WIDTH": "50", "HEIGHT": "200"]
        let Result = try await FilterServer().Run(Filter: CIStretchCrop.FilterName, With: TestSupport.MakeImage(Width: 100, Height: 60), Options)
        #expect(Result.width == 50 && Result.height == 120)
    }

    @Test func TextImageDrawsTextOnTheSizeOfTheImage() async throws
    {
        let Server = FilterServer()
        let Source = TestSupport.MakeImage(Width: 300, Height: 200)
        let Alone = try await Server.Run(Filter: CITextImageGenerator.FilterName, With: Source, ["TEXT": "Hi", "FONTSIZE": "80"])
        #expect(Alone.width == 300 && Alone.height == 200)
        #expect(Alone.alphaInfo != .none && Alone.alphaInfo != .noneSkipFirst && Alone.alphaInfo != .noneSkipLast)
        // Over the image the picture is opaque everywhere.
        let Over = try await Server.Run(Filter: CITextImageGenerator.FilterName, With: Source,
                                        ["TEXT": "Hi", "FONTSIZE": "80", "OVERIMAGE": "true"])
        #expect(Over.width == 300 && Over.height == 200)
    }

    @Test func TextImageIsAnOverlayThatFollowsTheTargetCanvas() throws
    {
        #expect(FilterServer().GetFilter(CITextImageGenerator.FilterName) is OverlayGenerator)
    }
}
