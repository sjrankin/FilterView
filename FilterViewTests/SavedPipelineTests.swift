//
//  SavedPipelineTests.swift
//  FilterViewTests
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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
