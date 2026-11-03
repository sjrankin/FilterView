//
//  SavedPipelineMenu.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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

/// The context menu of a row in the filter tree. A saved pipeline can be opened in the Pipeline window to be edited (macOS), and a
/// folder that was loaded can be forgotten. Other rows have no menu.
struct SavedPipelineMenu: View
{
    /// The row's node.
    let NodeID: UUID
    @Environment(PipelineModel.self) private var Pipeline
    #if os(macOS)
    @Environment(\.openWindow) private var OpenWindow
    #endif

    var body: some View
    {
        let Library = PipelineLibrary.Shared
        #if os(macOS)
        if let Entry = Library.EntryFor(Node: NodeID)
        {
            Button("Edit in Pipeline Window")
            {
                OpenWindow(id: PipelineWindow.ID)
                Task
                {
                    await Pipeline.Load(Entry.Pipeline, From: Entry.URL)
                }
            }
            .help("Replaces the pipeline in the Pipeline window with this one.")
        }
        #endif
        if let Folder = Library.FolderFor(Node: NodeID),
           !Folder.IsDefault
        {
            Button("Forget This Folder")
            {
                Library.RemoveDirectory(Folder.id)
            }
            .help("The folder's pipelines are no longer listed. The files are not deleted.")
        }
    }
}
