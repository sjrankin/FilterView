//
//  SameFilterTwiceTests.swift
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

/// A pipeline may use the same filter in any number of stages, each with its own options.
@MainActor
struct SameFilterTwiceTests
{
    private func Tag(_ Amount: String) -> FilterSelection
    {
        TestSupport.MakeSelection("Tag", Amount: Amount)
    }

    private func MakeModel(_ Recorder: RecordingFilter) async -> PipelineModel
    {
        let Server = FilterServer()
        Server.BuiltInFilters[RecordingFilter.FilterName] = Recorder
        let Model = PipelineModel()
        Model.Server = Server
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage())
        return Model
    }

    @Test func EachStageRunsTheFilterWithItsOwnOptions() async throws
    {
        let Recorder = RecordingFilter()
        let Model = await MakeModel(Recorder)
        await Model.Add(Tag("2"))
        await Model.Add(Tag("9"))
        await Model.Add(Tag("5"))
        #expect(Recorder.Calls.map{$0["AMOUNT"]} == ["2", "9", "5"])
        #expect(Model.Stages.compactMap{$0.Selection?.Options?["AMOUNT"]} == ["2", "9", "5"])
    }

    @Test func ChangingOneStageLeavesTheOthersAlone() async throws
    {
        let Recorder = RecordingFilter()
        let Model = await MakeModel(Recorder)
        await Model.Add(Tag("2"))
        await Model.Add(Tag("2"))
        Model.UpdateOptions(1, To: Tag("7"))
        await Model.Drain()
        #expect(Model.Stages[1].Selection?.Options?["AMOUNT"] == "7")
        #expect(Model.Stages[2].Selection?.Options?["AMOUNT"] == "2")
        // The stage after the changed one is made again, still with its own options.
        #expect(Recorder.Calls.suffix(2).map{$0["AMOUNT"]} == ["7", "2"])
    }

    @Test func EditingAStageDoesNotChangeWhatTheMainWindowRemembers() async throws
    {
        let Recorder = RecordingFilter()
        let Model = await MakeModel(Recorder)
        await Model.Add(Tag("2"))
        Model.UpdateOptions(1, To: Tag("8"))
        let Key = FilterOptionStore.DefaultsKey(Filter: "Tag", Key: "AMOUNT")
        #expect(UserDefaults.standard.string(forKey: Key) == nil)
    }

    @Test func TheSameFilterKeepsEachStagesOptionsWhenSavedAndLoaded() async throws
    {
        let Made = try TestSupport.MakeLibrary()
        let Recorder = RecordingFilter()
        let Model = await MakeModel(Recorder)
        await Model.Add(Tag("2"))
        await Model.Add(Tag("9"))
        try Model.Save(Name: "Twice", Directory: nil, Library: Made.Library)
        let Loaded = try #require(Made.Library.AllEntries.first)
        let Other = await MakeModel(RecordingFilter())
        await Other.Load(Loaded.Pipeline, From: Loaded.URL)
        #expect(Other.Stages.compactMap{$0.Selection?.Options?["AMOUNT"]} == ["2", "9"])
    }

    @Test func ASavedPipelineRunsTheSameFilterTwiceWithDifferentOptions() async throws
    {
        let Recorder = RecordingFilter()
        var Saved = TestSupport.MakePipeline("Twice")
        Saved.Stages[0].Options = ["AMOUNT": "2"]
        var Second = SavedStage(ID: 2, Kind: .Filter, Input: 1, Under: false, Skipped: false)
        Second.Filter = "Tag"
        Second.Options = ["AMOUNT": "9"]
        Saved.Stages.append(Second)
        Saved.FinalStage = 2
        _ = try await PipelineExecutor.Run(Saved, Input: TestSupport.MakeImage(), Filters: ["Tag": Recorder])
        #expect(Recorder.Calls.map{$0["AMOUNT"]} == ["2", "9"])
    }

    @Test func TheSameSavedPipelineCanBeUsedTwiceAndNestedInItself() async throws
    {
        let Recorder = RecordingFilter()
        let Inner = TestSupport.MakePipeline("Inner")
        var Outer = TestSupport.MakePipeline("Outer", Nested: Inner)
        var Again = SavedStage(ID: 2, Kind: .Filter, Input: 1, Under: false, Skipped: false)
        Again.Filter = SavedPipelineFilter.FilterName
        Again.DisplayName = "Inner"
        Again.Nested = Inner
        Outer.Stages.append(Again)
        Outer.FinalStage = 2
        _ = try await PipelineExecutor.Run(Outer, Input: TestSupport.MakeImage(), Filters: ["Tag": Recorder])
        #expect(Recorder.Calls.count == 2)
    }

    @Test func InsertingTheSameFilterNextToItselfIsAllowed() async throws
    {
        let Model = await MakeModel(RecordingFilter())
        await Model.Add(Tag("2"))
        Model.InsertFilter(After: 1, With: Tag("6"))
        Model.InsertFilter(Before: 1, With: Tag("4"))
        await Model.Drain()
        #expect(Model.Problem == nil)
        #expect(Model.Stages.filter{$0.Selection?.Filter == "Tag"}.count == 3)
    }
}
