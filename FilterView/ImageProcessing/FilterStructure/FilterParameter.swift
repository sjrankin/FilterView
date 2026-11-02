//
//  FilterParameter.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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
    /// Choice and Segments: the `Value` of one of the choices.
    let Default: String

    /// Lowest value of a slider.
    let Min: Double?

    /// Highest value of a slider.
    let Max: Double?

    /// Distance between the values a slider can take. If `nil`, a hundredth of the range.
    let Step: Double?

    /// The values a choice can take. Used by `Choice` (a menu) and `Segments` (a segmented picker).
    let Choices: [FilterChoice]?

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
