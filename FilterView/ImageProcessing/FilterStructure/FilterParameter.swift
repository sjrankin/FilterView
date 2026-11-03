//
//  FilterParameter.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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

import Foundation

/// One option of a filter that the user can change, as described in `FilterTree.json`. All values travel as strings, the same as
/// the fixed `Options` of a tree entry, and are converted by the filter that uses them.
struct FilterParameter: Codable, Hashable, Identifiable, Sendable
{
    /// The key the filter looks for in its options dictionary.
    let Key: String

    /// Label shown next to the control.
    let Title: String

    /// Which control edits the value.
    let Kind: Kinds

    /// The value used until the user changes it. Slider: a number. Toggle: `true` or `false`. Color: `RRGGBB` or `RRGGBBAA`.
    /// Choice and Segments: the `Value` of one of the choices. Text: the text.
    let Default: String

    /// Lowest value of a slider.
    let Min: Double?

    /// Highest value of a slider.
    let Max: Double?

    /// Distance between the values a slider can take. If `nil`, a hundredth of the range.
    let Step: Double?

    /// The values a choice can take. Used by `Choice` (a menu) and `Segments` (a segmented picker).
    let Choices: [FilterChoice]?

    /// If set, the parameter only applies while another parameter of the same filter has one of the given values, and its control is grayed out
    /// the rest of the time. `nil` means it always applies.
    var EnabledWhen: FilterParameterCondition? = nil

    var id: String
    {
        Key
    }

    /// Kinds of control. The raw values are what the JSON uses for `Type`.
    enum Kinds: String, Codable, Sendable
    {
        case Slider
        case Toggle
        case Color
        case Choice
        case Segments
        case Text
    }

    enum CodingKeys: String, CodingKey
    {
        case Key
        case Title
        case Kind = "Type"
        case Default
        case Min
        case Max
        case Step
        case Choices
        case EnabledWhen
    }
}

/// One value a `Choice` parameter can take.
struct FilterChoice: Codable, Hashable, Sendable
{
    /// Label shown in the menu.
    let Title: String

    /// Value handed to the filter.
    let Value: String
}

/// When a parameter applies: while the parameter `Key` has one of `Values`. In `FilterTree.json` it is the parameter's `EnabledWhen`, as
/// `{ "Key": "MODE", "Values": ["BRIGHTNESS"] }`.
struct FilterParameterCondition: Codable, Hashable, Sendable
{
    /// The key of the parameter that decides.
    let Key: String

    /// The values of that parameter for which this one applies.
    let Values: [String]
}
