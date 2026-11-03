//
//  PipelineSettingsAreSeparateTests.swift
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

/// The options of a pipeline stage start as a copy of the main window's, and from then on the two are separate.
@MainActor
struct PipelineSettingsAreSeparateTests
{
    private func Tag(_ Amount: String) -> FilterSelection
    {
        TestSupport.MakeSelection("Tag", Amount: Amount)
    }

    private func MakeModel() async -> PipelineModel
    {
        let Model = PipelineModel()
        Model.Server = FilterServer()
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage())
        return Model
    }

    private var Key: String
    {
        FilterOptionStore.DefaultsKey(Filter: "Tag", Key: "AMOUNT")
    }

    @Test func SetUsesTheMainWindowsSettings() async throws
    {
        let Model = await MakeModel()
        await Model.Add(Tag("6"))
        #expect(Model.Stages[1].Selection?.Options?["AMOUNT"] == "6")
    }

    @Test func ChangingAStageDoesNotChangeTheMainWindow() async throws
    {
        let Model = await MakeModel()
        let Main = Tag("6")
        Model.SelectedFilter = Main
        await Model.Add(Main)
        Model.UpdateOptions(1, To: Tag("1"))
        #expect(Model.Stages[1].Selection?.Options?["AMOUNT"] == "1")
        // What the main window has chosen, and what it remembers, are as they were.
        #expect(Model.SelectedFilter == Main)
        #expect(UserDefaults.standard.string(forKey: Key) == nil)
    }

    @Test func ChangingTheMainWindowLaterDoesNotChangeAStage() async throws
    {
        let Model = await MakeModel()
        Model.SelectedFilter = Tag("6")
        await Model.Add(try #require(Model.SelectedFilter))
        Model.SelectedFilter = Model.SelectedFilter?.Updating(Key: "AMOUNT", Value: "9")
        #expect(Model.SelectedFilter?.Options?["AMOUNT"] == "9")
        #expect(Model.Stages[1].Selection?.Options?["AMOUNT"] == "6")
    }

    @Test func UseSelectedFilterCopiesTheSettingsOnce() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(After: 0, With: nil)
        Model.SelectedFilter = Tag("4")
        Model.UseSelectedFilter(1)
        Model.SelectedFilter = Tag("8")
        #expect(Model.Stages[1].Selection?.Options?["AMOUNT"] == "4")
    }

    @Test func ALoadedPipelineDoesNotTouchTheMainWindowsSettings() async throws
    {
        let Model = await MakeModel()
        let Main = Tag("3")
        Model.SelectedFilter = Main
        var Saved = TestSupport.MakePipeline("Loaded")
        Saved.Stages[0].Options = ["AMOUNT": "7"]
        await Model.Load(Saved, From: nil)
        #expect(Model.SelectedFilter == Main)
        #expect(UserDefaults.standard.string(forKey: Key) == nil)
    }

    @Test func AFilterChosenForAPipelineStartsFromDefaultsAndLeavesTheSavedSettingsAlone() throws
    {
        let Parameter = FilterParameter(Key: "AMOUNT", Title: "Amount", Kind: .Slider, Default: "1", Min: 0, Max: 10, Step: 1, Choices: nil)
        let Defaults = try #require(FilterOptionStore.Defaults(Fixed: ["MODE": "A"], Parameters: [Parameter]))
        #expect(Defaults == ["MODE": "A", "AMOUNT": "1"])
        #expect(FilterOptionStore.Defaults(Fixed: nil, Parameters: []) == nil)
        // The main window's saved settings were neither read nor written to make them.
        #expect(UserDefaults.standard.string(forKey: Key) == nil)
    }

    @Test func TheMainWindowsRememberedValueDoesNotLeakIntoANewStage() throws
    {
        let Store = FilterOptionStore(Defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
        let Parameter = FilterParameter(Key: "AMOUNT", Title: "Amount", Kind: .Slider, Default: "1", Min: 0, Max: 10, Step: 1, Choices: nil)
        Store.Save(Filter: "Tag", Key: "AMOUNT", Value: "9")
        #expect(Store.Merged(Filter: "Tag", Fixed: nil, Parameters: [Parameter])?["AMOUNT"] == "9")
        #expect(FilterOptionStore.Defaults(Fixed: nil, Parameters: [Parameter])?["AMOUNT"] == "1")
    }
}
