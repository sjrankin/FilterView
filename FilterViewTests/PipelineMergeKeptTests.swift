//
//  PipelineMergeKeptTests.swift
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

/// A merge of the original onto the end of a line keeps its place, mode, and amount through every kind of edit.
@MainActor
struct PipelineMergeKeptTests
{
    private func MakeModel() async -> PipelineModel
    {
        let Model = PipelineModel()
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage())
        await Model.Add(TestSupport.MakeSelection(Amount: "1"))
        await Model.Add(TestSupport.MakeSelection(Amount: "2"))
        Model.Merge(From: 0, With: 2, Mode: .Screen, Amount: 0.6)
        return Model
    }

    /// The merge stage's links, mode, and amount.
    private func Merge(_ Model: PipelineModel) -> (Input: Int?, Second: Int?, Mode: MergeModes, Amount: Double)?
    {
        guard let Found = Model.Stages.first(where: {$0.Kind == .Merge}) else
        {
            return nil
        }
        return (Found.Input, Found.Second, Found.MergeMode, Found.MergeAmount)
    }

    @Test func EditingAStagesOptionsKeepsTheMerge() async throws
    {
        let Model = await MakeModel()
        Model.UpdateOptions(1, To: TestSupport.MakeSelection(Amount: "9"))
        await Model.Drain()
        let Kept = try #require(Merge(Model))
        #expect(Kept.Input == 2 && Kept.Second == 0 && Kept.Mode == .Screen && Kept.Amount == 0.6)
    }

    @Test func InsertingFiltersKeepsTheMerge() async throws
    {
        let Model = await MakeModel()
        Model.InsertFilter(After: 2, With: TestSupport.MakeSelection())
        Model.InsertFilter(Before: 1, With: TestSupport.MakeSelection())
        Model.InsertFilter(After: 0, With: TestSupport.MakeSelection())
        await Model.Drain()
        let Kept = try #require(Merge(Model))
        #expect(Kept.Second == 0 && Kept.Mode == .Screen && Kept.Amount == 0.6)
        // The merge still takes the end of the line as its background.
        #expect(Model.StageFor(Kept.Input)?.Kind == .Filter)
    }

    @Test func SavingAndLoadingKeepsTheMerge() async throws
    {
        let Model = await MakeModel()
        let Saved = Model.Snapshot(Name: "Merged")
        let Other = PipelineModel()
        Other.IsOpen = true
        await Other.Refresh(Original: TestSupport.MakeImage())
        await Other.Load(Saved, From: nil)
        Other.UpdateOptions(2, To: TestSupport.MakeSelection(Amount: "7"))
        await Other.Drain()
        let Kept = try #require(Merge(Other))
        #expect(Kept.Input == 2 && Kept.Second == 0 && Kept.Mode == .Screen && Kept.Amount == 0.6)
        #expect(Other.Snapshot(Name: "Merged").Stages.last?.Second == 0)
    }

    @Test func NewOriginalKeepsTheMerge() async throws
    {
        let Model = await MakeModel()
        await Model.Refresh(Original: TestSupport.MakeImage(Width: 6, Height: 6))
        let Kept = try #require(Merge(Model))
        #expect(Kept.Input == 2 && Kept.Second == 0)
        #expect(Model.Stages.last?.Output?.width == 6)
    }
}
