//
//  PipelineExecutorTests.swift
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

struct PipelineExecutorTests
{
    @Test func RunsStagesInOrderWithTheirOptions() async throws
    {
        let Recorder = RecordingFilter()
        var Saved = TestSupport.MakePipeline("Order")
        var Second = SavedStage(ID: 2, Kind: .Filter, Input: 1, Under: false, Skipped: false)
        Second.Filter = "Tag"
        Second.Options = ["AMOUNT": "7"]
        Saved.Stages.append(Second)
        Saved.FinalStage = 2
        _ = try await PipelineExecutor.Run(Saved, Input: TestSupport.MakeImage(), Filters: ["Tag": Recorder])
        #expect(Recorder.Calls.map{$0["AMOUNT"]} == ["3", "7"])
    }

    @Test func SkippedStagesPassTheImageThrough() async throws
    {
        let Recorder = RecordingFilter()
        var Saved = TestSupport.MakePipeline("Skip")
        Saved.Stages[0].Skipped = true
        _ = try await PipelineExecutor.Run(Saved, Input: TestSupport.MakeImage(), Filters: ["Tag": Recorder])
        #expect(Recorder.Calls.isEmpty)
    }

    @Test func UnknownFiltersPassTheImageThrough() async throws
    {
        let Image = TestSupport.MakeImage()
        let Result = try await PipelineExecutor.Run(TestSupport.MakePipeline("Missing"), Input: Image, Filters: [:])
        #expect(Result.width == Image.width)
    }

    @Test func NestedPipelinesRunInsideTheStage() async throws
    {
        let Recorder = RecordingFilter()
        let Inner = TestSupport.MakePipeline("Inner")
        let Outer = TestSupport.MakePipeline("Outer", Nested: TestSupport.MakePipeline("Middle", Nested: Inner))
        _ = try await PipelineExecutor.Run(Outer, Input: TestSupport.MakeImage(), Filters: ["Tag": Recorder])
        #expect(Recorder.Calls.count == 1)
    }

    @Test func AFileWithALoopStillFinishes() async throws
    {
        var Saved = TestSupport.MakePipeline("Loop")
        Saved.Stages[0].Input = 1
        let Result = try await PipelineExecutor.Run(Saved, Input: TestSupport.MakeImage(), Filters: ["Tag": RecordingFilter()])
        #expect(Result.width == 4)
    }

    @Test func SavedPipelineRunsAsAFilterThroughTheServer() async throws
    {
        let Server = FilterServer()
        let Saved = TestSupport.MakePipeline("Empty", Nested: nil)
        var Plain = Saved
        Plain.Stages[0].Filter = PassThroughFilter.FilterName
        Plain.Stages[0].Options = nil
        let Options = [SavedPipelineFilter.OptionKey: try Plain.JSONString()]
        let Result = try await Server.Run(Filter: SavedPipelineFilter.FilterName, With: TestSupport.MakeImage(), Options)
        #expect(Result.width == 4)
    }
}
