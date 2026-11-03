//
//  FilterTreeView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Shows the filter tree. Groups expand and collapse; tapping a filter sets `Selection` to its filter name and options. The last
/// branch, Saved Pipelines, holds the pipelines saved in the default folder and in any folders loaded with the button under the tree.
/// A saved pipeline is chosen like a filter.
struct FilterTreeView: View
{
    /// The tree to show. If `nil`, a placeholder is shown.
    var Root: FilterNode?
    @Binding var Selection: FilterSelection?
    @State private var SelectedNode: FilterNode.ID? = nil
    @State private var ChoosingFolder = false
    @State private var Library = PipelineLibrary.Shared

    var body: some View
    {
        if let Root = Root
        {
            let Branches = (Root.Children ?? []) + [Library.BranchNode]
            VStack(spacing: 0)
            {
                List(Branches, children: \.Children, selection: $SelectedNode)
                {
                    Node in
                    Text(Node.Name)
                        .contextMenu
                        {
                            SavedPipelineMenu(NodeID: Node.id)
                        }
                }
                Divider()
                HStack
                {
                    Button("Load Pipelines…", systemImage: "folder.badge.plus")
                    {
                        ChoosingFolder = true
                    }
                    .help("Add a folder of saved pipelines to the Saved Pipelines branch. The folder is remembered.")
                    Spacer()
                }
                .padding(.vertical)
            }
            .fileImporter(isPresented: $ChoosingFolder, allowedContentTypes: [.folder])
            {
                Chosen in
                if case .success(let Folder) = Chosen
                {
                    Library.AddDirectory(Folder)
                }
            }
            .task
            {
                // Pipelines may have been added or removed outside the app.
                Library.Reload()
            }
            .onChange(of: SelectedNode)
            {
                _, NewNode in
                if let Leaf = Branches.flatMap({$0.Leaves()}).first(where: {$0.id == NewNode}),
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
        .environment(PipelineModel())
}
