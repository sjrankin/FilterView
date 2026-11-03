//
//  OverlayCanvasTests.swift
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

/// Makes an image of a set size, whatever it is given.
final class ShrinkFilter: ImageFilter
{
    static let FilterName = "Shrink"
    var FilterType: ImageFilterTypes
    {
        .Infrastructure
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        TestSupport.MakeImage(Width: 32, Height: 32)
    }
}

/// A generator that remembers the width of the canvas it was given.
final class RecordingGenerator: OverlayGenerator
{
    static let FilterName = "Overlay"
    var FilterType: ImageFilterTypes
    {
        .Infrastructure
    }
    var Widths = [Int]()

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        Widths.append(Input.width)
        return TestSupport.MakeImage(Width: Input.width, Height: Input.height)
    }
}

@MainActor
struct OverlayCanvasTests
{
    /// Original (64 wide), a target stage, and an overlay under the original, merged onto the target.
    private func Stages(Target: String) -> SavedPipeline
    {
        var Shrunk = SavedStage(ID: 1, Kind: .Filter, Input: 0, Under: false, Skipped: false)
        Shrunk.Filter = Target
        var Overlay = SavedStage(ID: 2, Kind: .Filter, Input: 0, Under: true, Skipped: false)
        Overlay.Filter = RecordingGenerator.FilterName
        var Merge = SavedStage(ID: 3, Kind: .Merge, Input: 1, Second: 2, Under: false, Skipped: false)
        Merge.MergeMode = MergeModes.SourceOver.rawValue
        return SavedPipeline(Name: "Overlay", Stages: [Shrunk, Overlay, Merge], FinalStage: 3)
    }

    @Test func AnOverlayIsMadeOnTheTargetsCanvasInASavedPipeline() async throws
    {
        let Generator = RecordingGenerator()
        let Result = try await PipelineExecutor.Run(Stages(Target: ShrinkFilter.FilterName),
                                                    Input: TestSupport.MakeImage(Width: 64, Height: 64),
                                                    Filters: [ShrinkFilter.FilterName: ShrinkFilter(),
                                                              RecordingGenerator.FilterName: Generator])
        // Once for the stage itself, once on the canvas of the stage it is merged onto.
        #expect(Generator.Widths == [64, 32])
        #expect(Result.width == 32)
    }

    @Test func NoSecondRenderWhenTheCanvasAlreadyMatches() async throws
    {
        let Generator = RecordingGenerator()
        _ = try await PipelineExecutor.Run(Stages(Target: PassThroughFilter.FilterName),
                                           Input: TestSupport.MakeImage(Width: 64, Height: 64),
                                           Filters: [PassThroughFilter.FilterName: PassThroughFilter(),
                                                     RecordingGenerator.FilterName: Generator])
        #expect(Generator.Widths == [64])
    }

    @Test func TheWindowMakesTheOverlayOnTheTargetsCanvasToo() async throws
    {
        let Generator = RecordingGenerator()
        let Server = FilterServer()
        Server.BuiltInFilters[ShrinkFilter.FilterName] = ShrinkFilter()
        Server.BuiltInFilters[RecordingGenerator.FilterName] = Generator
        let Model = PipelineModel()
        Model.Server = Server
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage(Width: 64, Height: 64))
        await Model.Load(Stages(Target: ShrinkFilter.FilterName), From: nil)
        #expect(Generator.Widths.contains(32))
        #expect(Model.FinalImage?.width == 32)
    }

    @Test func TheSunbeamsKeepTheirSizeWhileTheCanvasFollowsTheTarget() async throws
    {
        let Server = FilterServer()
        Server.BuiltInFilters[ShrinkFilter.FilterName] = ShrinkFilter()
        #expect(Server.GetFilter(CISunBeamsGenerator.FilterName) is OverlayGenerator)
        var Pipeline = Stages(Target: ShrinkFilter.FilterName)
        Pipeline.Stages[1].Filter = CISunBeamsGenerator.FilterName
        Pipeline.Stages[1].Options = ["CENTERX": "25", "CENTERY": "50", "SUNRADIUS": "6"]
        let Result = try await PipelineExecutor.Run(Pipeline, Input: TestSupport.MakeImage(Width: 64, Height: 64),
                                                    Filters: Server.BuiltInFilters)
        #expect(Result.width == 32 && Result.height == 32)
    }
}
