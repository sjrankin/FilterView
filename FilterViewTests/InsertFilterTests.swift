//
//  InsertFilterTests.swift
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
struct InsertFilterTests
{
    private func Pass(_ Name: String = "Pass") -> FilterSelection
    {
        FilterSelection(Filter: PassThroughFilter.FilterName, Options: nil, DisplayName: Name, Parameters: [])
    }

    /// Original (0), then stages 1 and 2 in a line.
    private func MakeModel() async -> PipelineModel
    {
        let Model = PipelineModel()
        Model.Server = FilterServer()
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage())
        await Model.Add(Pass("One"))
        await Model.Add(Pass("Two"))
        return Model
    }

    private func Settle(_ Model: PipelineModel) async
    {
        await Model.Drain()
    }

    @Test func InsertingAfterAStageSplicesTheNewStageIntoTheLine() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(After: 1, With: Pass("New"))
        await Settle(Model)
        let New = try #require(Model.Stages.first{$0.id == 3})
        #expect(New.Input == 1 && New.Under == false)
        #expect(New.Selection?.DisplayName == "New")
        #expect(Model.StageFor(2)?.Input == 3)
        #expect(Model.StageFor(1)?.Input == 0)
        // The line is 0, 1, 3, 2, and the last stage is still the end of it.
        #expect(Model.TipID == 2)
        #expect(Model.Stages.allSatisfy{$0.Kind == .Original || $0.Output != nil})
    }

    @Test func InsertingAfterTheOriginalPutsTheNewStageFirst() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(After: 0, With: Pass("New"))
        #expect(Model.StageFor(3)?.Input == 0)
        #expect(Model.StageFor(1)?.Input == 3)
    }

    @Test func InsertingAfterTheLastStageMakesTheNewStageTheEnd() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(After: 2, With: Pass("New"))
        await Settle(Model)
        #expect(Model.StageFor(3)?.Input == 2)
        #expect(Model.TipID == 3)
        #expect(Model.FinalImage != nil)
    }

    @Test func InsertingBeforeAStageTakesItsPlaceInTheLine() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(Before: 2, With: Pass("New"))
        await Settle(Model)
        let New = try #require(Model.StageFor(3))
        #expect(New.Input == 1 && New.Under == false)
        #expect(Model.StageFor(2)?.Input == 3)
        #expect(Model.StageFor(1)?.Input == 0)
        #expect(Model.TipID == 2)
    }

    @Test func InsertingBeforeTheFirstFilterGoesRightAfterTheOriginal() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(Before: 1, With: nil)
        #expect(Model.StageFor(3)?.Input == 0)
        #expect(Model.StageFor(1)?.Input == 3)
    }

    @Test func TheOriginalHasNothingBeforeIt() async throws
    {
        let Model = await MakeModel()
        let Before = Model.Stages.count
        Model.InsertFilter(Before: 0, With: Pass("New"))
        #expect(Model.Stages.count == Before)
    }

    @Test func InsertingBeforeADivergedStageTakesItsPlaceUnderTheSourceAndTheStageContinuesFromIt() async throws
    {
        let Model = await MakeModel()
        Model.Diverge(1)
        let Diverged = try #require(Model.Stages.last)
        #expect(Diverged.Under)
        Model.InsertFilter(Before: Diverged.id, With: Pass("New"))
        let New = try #require(Model.Stages.last)
        #expect(New.Input == 1 && New.Under == true)
        #expect(Model.StageFor(Diverged.id)?.Input == New.id)
        #expect(Model.StageFor(Diverged.id)?.Under == false)
    }

    @Test func InsertingAfterAStageLeavesWhatHangsUnderItAlone() async throws
    {
        let Model = await MakeModel()
        Model.Diverge(1)
        let Diverged = try #require(Model.Stages.last)
        Model.InsertFilter(After: 1, With: nil)
        #expect(Model.StageFor(Diverged.id)?.Input == 1)
        #expect(Model.StageFor(Diverged.id)?.Under == true)
        #expect(Model.StageFor(2)?.Input == Model.Stages.last?.id)
    }

    @Test func WithNoFilterChosenTheNewStagePassesTheImageThrough() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(After: 1, With: nil)
        await Settle(Model)
        let New = try #require(Model.StageFor(3))
        #expect(New.Selection == nil)
        #expect(New.Name == "Passthrough")
        #expect(New.Output != nil)
        // It can be given a filter afterwards like any other empty stage.
        Model.SelectedFilter = Pass("Later")
        Model.UseSelectedFilter(3)
        #expect(Model.StageFor(3)?.Selection?.DisplayName == "Later")
    }

    @Test func ANewStageIsPlacedBetweenItsNeighboursOnScreen() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(After: 1, With: Pass("New"))
        let Where = Model.Positions()
        #expect(Where[1] == PipelineModel.GridPoint(Col: 1, Row: 0))
        #expect(Where[3] == PipelineModel.GridPoint(Col: 2, Row: 0))
        #expect(Where[2] == PipelineModel.GridPoint(Col: 3, Row: 0))
    }

    @Test func ASavedPipelineThatContainsTheOneBeingEditedIsRefused() async throws
    {
        let Deep = TestSupport.MakePipeline("Deep")
        let Middle = TestSupport.MakePipeline("Middle", Nested: Deep)
        let Model = await MakeModel()
        Model.CurrentName = "Deep"
        let Choice = FilterSelection(Filter: SavedPipelineFilter.FilterName,
                                     Options: [SavedPipelineFilter.OptionKey: try Middle.JSONString()],
                                     DisplayName: "Middle", Parameters: [])
        let Before = Model.Stages.count
        Model.InsertFilter(After: 1, With: Choice)
        Model.InsertFilter(Before: 2, With: Choice)
        #expect(Model.Stages.count == Before)
        #expect(Model.Problem != nil)
    }

    @Test func TheFilterChosenInTheMainWindowIsNotUsedOrChecked() async throws
    {
        // A saved pipeline that holds the one being edited is chosen in the main window. Inserting a plain filter is still fine, and the
        // new stage is the one asked for, not the main window's.
        let Deep = TestSupport.MakePipeline("Deep")
        let Model = await MakeModel()
        Model.CurrentName = "Deep"
        Model.SelectedFilter = FilterSelection(Filter: SavedPipelineFilter.FilterName,
                                               Options: [SavedPipelineFilter.OptionKey: try Deep.JSONString()],
                                               DisplayName: "Deep", Parameters: [])
        Model.InsertFilter(After: 1, With: Pass("Asked For"))
        Model.InsertFilter(Before: 2, With: nil)
        #expect(Model.Problem == nil)
        #expect(Model.StageFor(3)?.Selection?.DisplayName == "Asked For")
        #expect(Model.StageFor(4)?.Selection == nil)
    }

    @Test func AnInsertedPipelineAlsoSavesAndLoadsInPlace() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(After: 1, With: Pass("New"))
        let Saved = Model.Snapshot(Name: "Spliced")
        #expect(Saved.FinalStage == 2)
        let Order = PipelineExecutor.Order(Saved)
        #expect(Order == [1, 3, 2])
    }
}
