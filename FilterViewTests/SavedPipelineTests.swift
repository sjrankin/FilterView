//
//  SavedPipelineTests.swift
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

struct SavedPipelineTests
{
    @Test func RoundTripKeepsEveryOption() throws
    {
        let Inner = TestSupport.MakePipeline("Inner")
        var Outer = TestSupport.MakePipeline("Outer", Nested: Inner)
        Outer.Stages[0].Parameters = TestSupport.MakeSelection().Parameters
        let Decoded = try #require(SavedPipeline.Decode(Data: Outer.FileData()))
        #expect(Decoded == Outer)
        #expect(Decoded.Stages[0].Nested?.Stages[0].Options?["AMOUNT"] == "3")
    }

    @Test func JSONTextIsStable() throws
    {
        let Saved = TestSupport.MakePipeline("A")
        #expect(try Saved.JSONString() == Saved.JSONString())
        #expect(SavedPipeline.Decode(JSON: try Saved.JSONString()) == Saved)
    }

    @Test func RejectsGarbageAndNewerVersions() throws
    {
        #expect(SavedPipeline.Decode(JSON: "not json") == nil)
        var Future = TestSupport.MakePipeline("Future")
        Future.Version = SavedPipeline.CurrentVersion + 1
        #expect(SavedPipeline.Decode(Data: try Future.FileData()) == nil)
    }

    @Test func ContainsLooksAtEveryDepthIgnoringCase() throws
    {
        let Deep = TestSupport.MakePipeline("Deep")
        let Middle = TestSupport.MakePipeline("Middle", Nested: Deep)
        let Top = TestSupport.MakePipeline("Top", Nested: Middle)
        #expect(Top.Contains(Named: "deep"))
        #expect(Top.Contains(Named: "MIDDLE"))
        #expect(Top.Contains(Named: "Top"))
        #expect(!Top.Contains(Named: "Other"))
        #expect(Top.AllNames == ["Top", "Middle", "Deep"])
    }
}
