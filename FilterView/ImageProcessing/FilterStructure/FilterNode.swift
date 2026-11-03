//
//  FilterNode.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
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
}
