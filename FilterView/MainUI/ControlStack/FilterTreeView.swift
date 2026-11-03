//
//  FilterTreeView.swift
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
    /// True (as in the main window) to start a chosen filter from the options the user last set for it. False starts it from the
    /// filter's defaults and neither reads nor changes those saved options, for choosing a filter somewhere else, such as a pipeline.
    var UsesSavedOptions = true
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
                    // The saved value of each parameter goes into the options, so the filter starts with what the user last chose (or, when
                    // the saved values are not used, the defaults).
                    let Parameters = Leaf.Parameters ?? []
                    let Options = UsesSavedOptions
                        ? FilterOptionStore.Shared.Merged(Filter: Name, Fixed: Leaf.Options, Parameters: Parameters)
                        : FilterOptionStore.Defaults(Fixed: Leaf.Options, Parameters: Parameters)
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
