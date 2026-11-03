//
//  PipelineModelSavingTests.swift
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
@testable import FilterView

@MainActor
struct PipelineModelSavingTests
{
    /// A model with the window "open" and an original image, holding filters with the given amounts.
    private func MakeModel(Amounts: [String]) async -> PipelineModel
    {
        let Model = PipelineModel()
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage())
        for Amount in Amounts
        {
            await Model.Add(TestSupport.MakeSelection(Amount: Amount))
        }
        return Model
    }

    @Test func SnapshotKeepsEachStagesFilterAndOptions() async throws
    {
        let Model = await MakeModel(Amounts: ["2", "5"])
        let Saved = Model.Snapshot(Name: "  Two Steps ")
        #expect(Saved.Name == "Two Steps")
        #expect(Saved.Stages.map{$0.Options?["AMOUNT"]} == ["2", "5"])
        #expect(Saved.Stages[0].Parameters?.first?.Key == "AMOUNT")
        #expect(Saved.FinalStage == 2)
    }

    @Test func LoadingRestoresTheStagesForEditing() async throws
    {
        let Model = await MakeModel(Amounts: ["2", "5"])
        let Saved = Model.Snapshot(Name: "Round Trip")
        let Other = await MakeModel(Amounts: [])
        await Other.Load(Saved, From: nil)
        #expect(Other.CurrentName == "Round Trip")
        #expect(Other.Stages.count == 3)
        #expect(Other.Stages[2].Selection?.Options?["AMOUNT"] == "5")
        #expect(Other.Snapshot(Name: "Round Trip") == Saved)
        // The next stage added does not reuse a number.
        await Other.Add(TestSupport.MakeSelection())
        #expect(Other.Stages.last?.id == 3)
    }

    @Test func SavingThroughTheLibraryNamesThePipeline() async throws
    {
        let Made = try TestSupport.MakeLibrary()
        let Model = await MakeModel(Amounts: ["4"])
        try Model.Save(Name: "Keeper", Directory: nil, Library: Made.Library)
        #expect(Model.CurrentName == "Keeper")
        #expect(Model.CurrentURL != nil)
        // Saving again under the same name replaces the file; a second pipeline cannot take the name.
        #expect(Model.SaveProblem(Name: "Keeper", Directory: nil, Library: Made.Library) == nil)
        let Stranger = await MakeModel(Amounts: ["1"])
        #expect(Stranger.SaveProblem(Name: "Keeper", Directory: nil, Library: Made.Library) != nil)
    }

    @Test func PipelineSavedElsewhereCannotBeCopiedIntoDefaultUnderTheSameName() async throws
    {
        let Made = try TestSupport.MakeLibrary()
        let Other = try TestSupport.MakeFolder()
        let Model = await MakeModel(Amounts: ["4"])
        try Model.Save(Name: "Away", Directory: Other, Library: Made.Library)
        #expect(Model.SaveProblem(Name: "Away", Directory: Other, Library: Made.Library) == nil)
    }

    @Test func SavingAgainStartsInTheFolderThePipelineIsIn() async throws
    {
        let Made = try TestSupport.MakeLibrary()
        let Other = try TestSupport.MakeFolder()
        let Model = await MakeModel(Amounts: ["4"])
        // Not saved yet, or in the default folder: the default folder.
        #expect(Model.SaveFolder(Library: Made.Library) == nil)
        try Model.Save(Name: "Here", Directory: nil, Library: Made.Library)
        #expect(Model.SaveFolder(Library: Made.Library) == nil)
        // In another folder: that folder, and saving there again over the same file is allowed.
        let Away = await MakeModel(Amounts: ["4"])
        try Away.Save(Name: "There", Directory: Other, Library: Made.Library)
        let Folder = try #require(Away.SaveFolder(Library: Made.Library))
        #expect(Folder.resolvingSymlinksInPath().path == Other.resolvingSymlinksInPath().path)
        #expect(Away.SaveProblem(Name: "There", Directory: Folder, Library: Made.Library) == nil)
    }

    @Test func ASavedPipelineBecomesAStageOfAnother() async throws
    {
        let Inner = TestSupport.MakePipeline("Inner")
        let Selection = FilterSelection(Filter: SavedPipelineFilter.FilterName,
                                        Options: [SavedPipelineFilter.OptionKey: try Inner.JSONString()],
                                        DisplayName: "Inner", Parameters: [])
        let Model = await MakeModel(Amounts: [])
        await Model.Add(Selection)
        #expect(Model.Stages[1].Name == "Pipeline: Inner")
        let Saved = Model.Snapshot(Name: "Outer")
        #expect(Saved.Stages[0].Nested == Inner)
        #expect(Saved.Stages[0].Options == nil)
        let Again = await MakeModel(Amounts: [])
        await Again.Load(Saved, From: nil)
        #expect(Again.Stages[1].Selection?.IsPipeline == true)
        #expect(Again.Snapshot(Name: "Outer") == Saved)
    }

    @Test func APipelineCannotHaveItselfAsAChild() async throws
    {
        let Deep = TestSupport.MakePipeline("Deep")
        let Middle = TestSupport.MakePipeline("Middle", Nested: Deep)
        func Choose(_ Saved: SavedPipeline) throws -> FilterSelection
        {
            FilterSelection(Filter: SavedPipelineFilter.FilterName, Options: [SavedPipelineFilter.OptionKey: try Saved.JSONString()],
                            DisplayName: Saved.Name, Parameters: [])
        }
        let Model = await MakeModel(Amounts: [])
        // An unsaved pipeline has no name, so anything can go in it.
        #expect(Model.NestingProblem(for: try Choose(Middle)) == nil)
        // Editing "Deep": it cannot take itself, nor a pipeline that holds it.
        Model.CurrentName = "Deep"
        #expect(Model.NestingProblem(for: try Choose(Deep)) != nil)
        #expect(Model.NestingProblem(for: try Choose(Middle)) != nil)
        // Editing "Middle": it may take "Deep", which sits below it, to any depth.
        Model.CurrentName = "Middle"
        #expect(Model.NestingProblem(for: try Choose(Deep)) == nil)
        // Plain filters are never a problem.
        #expect(Model.NestingProblem(for: TestSupport.MakeSelection()) == nil)
    }

    @Test func SavingUnderTheNameOfAHeldPipelineIsRefused() async throws
    {
        let Made = try TestSupport.MakeLibrary()
        let Inner = TestSupport.MakePipeline("Inner")
        let Model = await MakeModel(Amounts: [])
        await Model.Add(FilterSelection(Filter: SavedPipelineFilter.FilterName,
                                        Options: [SavedPipelineFilter.OptionKey: try Inner.JSONString()],
                                        DisplayName: "Inner", Parameters: []))
        #expect(Model.SaveProblem(Name: "inner", Directory: nil, Library: Made.Library) != nil)
        #expect(Model.SaveProblem(Name: "Outer", Directory: nil, Library: Made.Library) == nil)
    }

    @Test func UpdatingOptionsReplacesThemOnlyForThatStage() async throws
    {
        let Model = await MakeModel(Amounts: ["1", "1"])
        Model.UpdateOptions(1, To: TestSupport.MakeSelection(Amount: "8"))
        #expect(Model.Stages[1].Selection?.Options?["AMOUNT"] == "8")
        #expect(Model.Stages[2].Selection?.Options?["AMOUNT"] == "1")
        // A different filter is not accepted for the stage.
        Model.UpdateOptions(1, To: TestSupport.MakeSelection("Other", Amount: "3"))
        #expect(Model.Stages[1].Selection?.Options?["AMOUNT"] == "8")
    }
}
