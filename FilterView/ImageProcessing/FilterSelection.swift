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
}
