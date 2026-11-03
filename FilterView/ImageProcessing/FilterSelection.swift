//
//  FilterSelection.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation

/// A filter chosen in the UI together with the options that go with it. Several tree entries can share one filter
/// (such as the channel swaps) and differ only in their options, so the name alone is not enough.
struct FilterSelection: Hashable, Sendable
{
    /// Registered name of the filter.
    let Filter: String

    /// Options for the filter. `nil` if it takes none.
    let Options: [String: String]?

    /// The label of the tree entry that was chosen, such as "Mirror". Unlike `Filter`, it tells entries that share
    /// a filter apart.
    let DisplayName: String

    /// The options the user can change for this entry. Their current values are in `Options`.
    let Parameters: [FilterParameter]

    /// True if this selection runs a saved pipeline instead of a single filter.
    var IsPipeline: Bool
    {
        Filter == SavedPipelineFilter.FilterName
    }

    /// The same selection with one option changed.
    func Updating(Key: String, Value: String) -> FilterSelection
    {
        var Changed = Options ?? [:]
        Changed[Key] = Value
        return FilterSelection(Filter: Filter, Options: Changed, DisplayName: DisplayName, Parameters: Parameters)
    }
}
