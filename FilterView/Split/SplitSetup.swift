//
//  SplitSetup.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/4/26.
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

/// An image divided into regions, each with its own filter, as set up in the main window.
struct SplitSetup: Hashable, Sendable
{
    var Layout: SplitLayouts
    /// The filter of each region, in region order. `nil` leaves a region as it is in the original.
    var Selections: [FilterSelection?]
    /// The region the filter tree and options are editing.
    var Active = 0

    /// A new setup.
    /// - Parameter Layout: How to divide the image.
    /// - Parameter First: The filter for the first region. The others start with none.
    init(Layout: SplitLayouts, First: FilterSelection?)
    {
        self.Layout = Layout
        Selections = [First] + [FilterSelection?](repeating: nil, count: Layout.Count - 1)
    }

    /// True if some region has a filter. Without one the image is shown as it is.
    var HasFilters: Bool
    {
        Selections.contains{$0 != nil}
    }

    /// The filter of the region being edited.
    var ActiveSelection: FilterSelection?
    {
        Selections.indices.contains(Active) ? Selections[Active] : nil
    }

    /// Changes the layout. The regions keep their filters in order; new regions start with none and regions that no longer exist lose theirs.
    mutating func ChangeLayout(to New: SplitLayouts)
    {
        Layout = New
        if Selections.count > New.Count
        {
            Selections.removeLast(Selections.count - New.Count)
        }
        else
        {
            Selections.append(contentsOf: [FilterSelection?](repeating: nil, count: New.Count - Selections.count))
        }
        Active = min(Active, New.Count - 1)
    }

    /// Gives the region being edited this filter.
    mutating func Assign(_ Selection: FilterSelection?)
    {
        if Selections.indices.contains(Active)
        {
            Selections[Active] = Selection
        }
    }

    /// Makes a region the one being edited.
    mutating func Activate(_ Index: Int)
    {
        if Selections.indices.contains(Index)
        {
            Active = Index
        }
    }
}
