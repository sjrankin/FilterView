//
//  FilterTreeView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import SwiftUI

/// Shows the filter tree. Groups expand and collapse; tapping a filter sets `Selection` to its filter name and options.
struct FilterTreeView: View
{
    /// The tree to show. If `nil`, a placeholder is shown.
    var Root: FilterNode?
    @Binding var Selection: FilterSelection?
    @State private var SelectedNode: FilterNode.ID? = nil

    var body: some View
    {
        if let Root = Root
        {
            List(Root.Children ?? [], children: \.Children, selection: $SelectedNode)
            {
                Node in
                Text(Node.Name)
            }
            .onChange(of: SelectedNode)
            {
                _, NewNode in
                if let Leaf = Root.Leaves().first(where: {$0.id == NewNode}),
                   let Name = Leaf.Filter
                {
                    // The saved value of each parameter goes into the options, so the filter starts with what the user last chose.
                    let Parameters = Leaf.Parameters ?? []
                    let Options = FilterOptionStore.Shared.Merged(Filter: Name, Fixed: Leaf.Options, Parameters: Parameters)
                    Selection = FilterSelection(Filter: Name, Options: Options, DisplayName: Leaf.Name, Parameters: Parameters)
                }
            }
        }
        else
        {
            ContentUnavailableView("No Filters", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

#Preview
{
    @Previewable @State var Selected: FilterSelection? = nil
    FilterTreeView(Root: try? FilterTreeLoader.Load(Resource: "FilterTree"),
                   Selection: $Selected)
}
