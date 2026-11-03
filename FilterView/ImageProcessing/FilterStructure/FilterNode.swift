//
//  FilterNode.swift
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

/// One node in the filter tree. A node with `Children` is a group; a node with `Filter` is a leaf that runs a filter.
struct FilterNode: Codable, Identifiable, Sendable
{
    /// Identifies the node for SwiftUI. Created at decode time, never stored in JSON. Nodes made for saved pipelines are given the
    /// identity of their file, so a selection survives the tree being built again.
    var NodeID = UUID()

    /// Label shown in the UI.
    let Name: String

    /// Name of the filter to run, as registered in `FilterServer`. `nil` for groups.
    let Filter: String?

    /// Options handed to the filter. `nil` if the filter has none.
    let Options: [String: String]?

    /// Options the user can change, each with a control in the options panel. `nil` if there are none. Their saved values are added
    /// to `Options` when the filter is chosen.
    let Parameters: [FilterParameter]?

    /// Child nodes. `nil` for leaves.
    let Children: [FilterNode]?

    /// The platform this node is for, such as "macOS". `nil` if it is for all of them. A node for another platform is left out when the
    /// tree is loaded (see `FilterTreeLoader`), with everything under it.
    var Platform: String? = nil

    /// `Identifiable` conformance.
    var id: UUID
    {
        NodeID
    }

    /// True if this node runs a filter.
    var IsLeaf: Bool
    {
        Filter != nil
    }

    /// Only the JSON keys are coded; `NodeID` is excluded.
    enum CodingKeys: String, CodingKey
    {
        case Name
        case Filter
        case Options
        case Parameters
        case Children
        case Platform
    }

    /// Returns every leaf under this node (or this node itself if it is a leaf), depth first.
    func Leaves() -> [FilterNode]
    {
        if IsLeaf
        {
            return [self]
        }
        return (Children ?? []).flatMap{$0.Leaves()}
    }

    /// The name of the platform this program is running on, as used by `Platform`.
    static var CurrentPlatform: String
    {
        #if os(macOS)
        return "macOS"
        #else
        return "iOS"
        #endif
    }

    /// This node without the parts meant for other platforms, or `nil` if the whole node is for another platform.
    func ForCurrentPlatform() -> FilterNode?
    {
        if let Wanted = Platform,
           Wanted != FilterNode.CurrentPlatform
        {
            return nil
        }
        guard let Kept = Children else
        {
            return self
        }
        return FilterNode(NodeID: NodeID, Name: Name, Filter: Filter, Options: Options, Parameters: Parameters,
                          Children: Kept.compactMap{$0.ForCurrentPlatform()}, Platform: Platform)
    }
}
