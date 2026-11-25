//
//  PipelineTextTests.swift
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
//

import Testing
import Foundation
@testable import FilterView

@MainActor
struct PipelineTextTests
{
    /// A pipeline with a filter, a merge back onto the original, a split and a join.
    private func Sample() -> SavedPipeline
    {
        var Filter = SavedStage(ID: 1, Kind: .Filter, Input: 0, Second: nil, Under: false, Skipped: false)
        Filter.Filter = "Regional Conditional"
        Filter.DisplayName = "Regional Conditional"
        Filter.Options = ["FILTER": "CI LineScreen", "REMOVE": "true", "TITLE": "He said \"hi\"\nthen left", "EMPTY": ""]
        var Named = SavedStage(ID: 2, Kind: .Filter, Input: 1, Second: nil, Under: true, Skipped: true)
        Named.Filter = "Metal Invert"
        Named.DisplayName = "Invert Colors"
        var Merge = SavedStage(ID: 3, Kind: .Merge, Input: 2, Second: 0, Under: false, Skipped: false)
        Merge.MergeMode = "Soft Light"
        Merge.MergeAmount = 0.6
        var Split = SavedStage(ID: 4, Kind: .Split, Input: 3, Second: nil, Under: false, Skipped: false)
        Split.Layout = "2x1"
        var Left = SavedStage(ID: 5, Kind: .Filter, Input: 4, Second: nil, Under: true, Skipped: false)
        Left.Filter = "Metal Invert"
        Left.DisplayName = "Metal Invert"
        var Join = SavedStage(ID: 6, Kind: .Join, Input: 4, Second: nil, Under: false, Skipped: false)
        Join.Layout = "2x1"
        Join.Regions = [5, 4]
        return SavedPipeline(Name: "Line \"Art\"", Stages: [Filter, Named, Merge, Split, Left, Join], FinalStage: 6)
    }

    @Test func TextRoundTripsEveryKindOfStage() throws
    {
        let Original = Sample()
        let Back = try PipelineText.Parse(PipelineText.Format(Original))
        #expect(Back == Original)
    }

    @Test func NestedPipelinesRoundTripAtAnyDepth() throws
    {
        var Inner = SavedPipeline(Name: "Inner", Stages: [], FinalStage: 1)
        var Step = SavedStage(ID: 1, Kind: .Filter, Input: 0, Second: nil, Under: false, Skipped: false)
        Step.Filter = "Metal Invert"
        Step.DisplayName = "Metal Invert"
        Step.Options = ["AMOUNT": "3"]
        Inner.Stages = [Step]
        var Middle = SavedPipeline(Name: "Middle", Stages: [], FinalStage: 1)
        var Holder = SavedStage(ID: 1, Kind: .Filter, Input: 0, Second: nil, Under: false, Skipped: false)
        Holder.Filter = SavedPipelineFilter.FilterName
        Holder.DisplayName = "Inner"
        Holder.Nested = Inner
        Middle.Stages = [Holder]
        var Outer = SavedPipeline(Name: "Outer", Stages: [], FinalStage: 2)
        var First = Holder
        First.Filter = SavedPipelineFilter.FilterName
        First.DisplayName = "Middle"
        First.Nested = Middle
        var After = SavedStage(ID: 2, Kind: .Filter, Input: 1, Second: nil, Under: false, Skipped: false)
        After.Filter = "Metal Invert"
        After.DisplayName = "Metal Invert"
        Outer.Stages = [First, After]
        let Back = try PipelineText.Parse(PipelineText.Format(Outer))
        #expect(Back == Outer)
    }

    @Test func HandWrittenTextIsUnderstood() throws
    {
        let Written = """
        # My line art
        pipeline "Line Art"

        stage 1 filter "Regional Conditional" from 0
            FILTER = "CI LineScreen"
            REMOVE = true
        stage 2 merge from 1 with 0 mode Multiply amount 0.5
        final 2
        """
        let Found = try PipelineText.Parse(Written)
        #expect(Found.Name == "Line Art")
        #expect(Found.FinalStage == 2)
        #expect(Found.Stages.count == 2)
        #expect(Found.Stages[0].Options == ["FILTER": "CI LineScreen", "REMOVE": "true"])
        #expect(Found.Stages[0].DisplayName == "Regional Conditional")
        #expect(Found.Stages[1].Second == 0)
        #expect(Found.Stages[1].MergeMode == "Multiply")
        #expect(Found.Stages[1].MergeAmount == 0.5)
    }

    @Test func FinalDefaultsToTheLastStage() throws
    {
        let Found = try PipelineText.Parse("pipeline X\nstage 1 pass from 0\nstage 2 pass from 1\n")
        #expect(Found.FinalStage == 2)
    }

    @Test(arguments: [
        ("", "no pipeline"),
        ("stage 1 pass from 0", "starts with"),
        ("pipeline X\nstage 1 pass from 5", "does not exist"),
        ("pipeline X\nstage 1 pass from 0\nstage 1 pass from 0", "two stages"),
        ("pipeline X\nstage 1 pass from 2\nstage 2 pass from 1", "its own result"),
        ("pipeline X\nstage 1 merge from 0", "second image"),
        ("pipeline X\nstage 1 merge from 0 with 0 mode Bogus", "merge mode"),
        ("pipeline X\nstage 1 split from 0 layout 9x9", "layout"),
        ("pipeline X\nstage 1 pass from 0\n    A = b", "filter stage"),
        ("pipeline X\nstage 1 nested from 0\npipeline Y\n", "no 'end'"),
        ("pipeline X\nstage 1 filter F from 0 wiggle", "wiggle"),
        ("pipeline X\nstage 1 filter F from 0\n  A = \"open", "quote"),
        ("pipeline X\nfinal 9", "does not exist")
    ])
    func MistakesAreReportedClearly(Text: String, Expected: String) {
        do
        {
            _ = try PipelineText.Parse(Text)
            Issue.record("Accepted: \(Text)")
        }
        catch
        {
            #expect((error as? FilterException)?.Message.contains(Expected) == true)
        }
    }

    @Test func ErrorsNameTheLine() {
        do
        {
            _ = try PipelineText.Parse("pipeline X\n\nstage 1 filter F from 0 wiggle\n")
            Issue.record("Accepted")
        }
        catch
        {
            #expect((error as? FilterException)?.Message.hasPrefix("Line 3:") == true)
        }
    }

    @Test func LoadingTextGivesAPipelineThatKeepsItsMerge() async throws
    {
        let Server = FilterServer()
        defer { withExtendedLifetime(Server) {} }
        let Model = PipelineModel()
        let Written = "pipeline T\nstage 1 pass from 0\nstage 2 pass from 1\nstage 3 merge from 2 with 0 mode Screen amount 0.6\nfinal 3\n"
        await Model.Load(try PipelineText.Parse(Written), From: nil)
        let Merge = try #require(Model.StageFor(3))
        #expect(Merge.Input == 2)
        #expect(Merge.Second == 0)
        #expect(Merge.MergeMode == .Screen)
        #expect(Model.CurrentName == "T")
    }

    @Test func SavedStagesOfKnownFiltersLeaveOutTheControlList() async throws
    {
        let Server = FilterServer()
        defer { withExtendedLifetime(Server) {} }
        let Model = PipelineModel()
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage())
        let Known = try #require(FilterTreeLoader.CurrentParameters(Filter: "Regional Conditional", DisplayName: "Regional Conditional"))
        await Model.Add(FilterSelection(Filter: "Regional Conditional", Options: ["VALUE": "0.3"], DisplayName: "Regional Conditional",
                                        Parameters: Known))
        let Saved = Model.Snapshot(Name: "Short")
        #expect(Saved.Stages[0].Parameters == nil)
        #expect(Saved.Stages[0].Options?["VALUE"] == "0.3")
        // Loading brings the controls back from the filter tree, with the defaults of options the file lacks.
        let Other = PipelineModel()
        await Other.Load(Saved, From: nil)
        let Selection = try #require(Other.StageFor(1)?.Selection)
        #expect(Selection.Parameters == Known)
        #expect(Selection.Options?["VALUE"] == "0.3")
        #expect(Selection.Options?["CLEARWHITE"] != nil)
    }
}
