//
//  FilterSelection.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
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

    /// True if a parameter applies with the options as they are now. A parameter with no condition always does. One that depends on another
    /// parameter applies while that parameter has one of the listed values, or, if it has no value yet, its default.
    /// - Parameter Parameter: One of this selection's parameters.
    func IsEnabled(_ Parameter: FilterParameter) -> Bool
    {
        guard let Condition = Parameter.EnabledWhen else
        {
            return true
        }
        let Current = Options?[Condition.Key] ?? Parameters.first{$0.Key == Condition.Key}?.Default
        return Condition.Values.contains(Current ?? "")
    }

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
