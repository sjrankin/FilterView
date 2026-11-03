//
//  EnabledWhenTests.swift
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

/// A parameter can apply only while another parameter has certain values, and is grayed out otherwise.
@MainActor
struct EnabledWhenTests
{
    private func InvertEntry() throws -> FilterNode
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        return try #require(Root.Leaves().first{$0.Filter == MetalInvert.FilterName})
    }

    /// The selection the main window makes when the Invert entry is chosen, with the given mode.
    private func Selection(Mode: String?) throws -> FilterSelection
    {
        let Entry = try InvertEntry()
        var Options = [String: String]()
        for Parameter in Entry.Parameters ?? []
        {
            Options[Parameter.Key] = Parameter.Default
        }
        if let Mode = Mode
        {
            Options["MODE"] = Mode
        }
        return FilterSelection(Filter: MetalInvert.FilterName, Options: Options, DisplayName: Entry.Name, Parameters: Entry.Parameters ?? [])
    }

    @Test func ShowColorIsReadFromTheTreeWithItsCondition() throws
    {
        let Color = try #require(InvertEntry().Parameters?.first{$0.Key == "COLOR"})
        #expect(Color.EnabledWhen == FilterParameterCondition(Key: "MODE", Values: ["BRIGHTNESS"]))
        // The Invert menu itself always applies.
        #expect(try #require(InvertEntry().Parameters?.first{$0.Key == "MODE"}).EnabledWhen == nil)
    }

    @Test func ShowColorIsGrayedOutUnlessInvertIsBrightness() throws
    {
        let Color = try #require(InvertEntry().Parameters?.first{$0.Key == "COLOR"})
        for Mode in ["ALL", "RED", "GREEN", "BLUE", "REDGREEN", "REDBLUE", "GREENBLUE"]
        {
            #expect(try Selection(Mode: Mode).IsEnabled(Color) == false, "\(Mode)")
        }
        #expect(try Selection(Mode: "BRIGHTNESS").IsEnabled(Color))
    }

    @Test func ItFollowsTheModeAsItChanges() throws
    {
        let Color = try #require(InvertEntry().Parameters?.first{$0.Key == "COLOR"})
        let Start = try Selection(Mode: nil)
        // The default mode is All, so Show Color starts grayed out.
        #expect(!Start.IsEnabled(Color))
        let Brightness = Start.Updating(Key: "MODE", Value: "BRIGHTNESS")
        #expect(Brightness.IsEnabled(Color))
        #expect(!Brightness.Updating(Key: "MODE", Value: "RED").IsEnabled(Color))
        // Its own value is kept while it is grayed out, so turning Brightness back on finds it as it was.
        let Remembered = Brightness.Updating(Key: "COLOR", Value: "true").Updating(Key: "MODE", Value: "ALL")
        #expect(Remembered.Options?["COLOR"] == "true")
        #expect(Remembered.Updating(Key: "MODE", Value: "BRIGHTNESS").Options?["COLOR"] == "true")
    }

    @Test func AMissingValueUsesTheDefaultOfTheParameterThatDecides() throws
    {
        let Entry = try InvertEntry()
        let Color = try #require(Entry.Parameters?.first{$0.Key == "COLOR"})
        let NoOptions = FilterSelection(Filter: MetalInvert.FilterName, Options: nil, DisplayName: Entry.Name, Parameters: Entry.Parameters ?? [])
        #expect(!NoOptions.IsEnabled(Color))
    }

    @Test func ParametersWithoutAConditionAlwaysApply() throws
    {
        let Plain = FilterParameter(Key: "AMOUNT", Title: "Amount", Kind: .Slider, Default: "1", Min: 0, Max: 10, Step: 1, Choices: nil)
        let Chosen = FilterSelection(Filter: "Tag", Options: ["AMOUNT": "1"], DisplayName: "Tag", Parameters: [Plain])
        #expect(Chosen.IsEnabled(Plain))
    }

    @Test func TheConditionRoundTripsThroughJSON() throws
    {
        let Text = """
        { "Key": "COLOR", "Title": "Show Color", "Type": "Toggle", "Default": "false", "EnabledWhen": { "Key": "MODE", "Values": ["A", "B"] } }
        """
        let Parameter = try JSONDecoder().decode(FilterParameter.self, from: Data(Text.utf8))
        #expect(Parameter.EnabledWhen == FilterParameterCondition(Key: "MODE", Values: ["A", "B"]))
        let Plain = try JSONDecoder().decode(FilterParameter.self, from: Data(#"{ "Key": "X", "Title": "X", "Type": "Toggle", "Default": "false" }"#.utf8))
        #expect(Plain.EnabledWhen == nil)
    }
}
