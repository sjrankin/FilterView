//
//  BatchSaveDialogs.swift
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

import SwiftUI
import UniformTypeIdentifiers

/// The dialogs a batch save can need: what to do with an image that cannot be written beside its original (choose a folder for the rest,
/// save this one somewhere, or skip it), and the message at the end. They open over the window that started the save (`BatchOrigin`).
struct BatchSaveDialogs: ViewModifier
{
    @Environment(BatchModel.self) private var Batch
    /// The window this is attached to.
    let Origin: BatchOrigin

    /// True while the question is at this step and is for this window.
    private func Showing(_ Mode: BatchAskMode) -> Binding<Bool>
    {
        Binding(get: { Batch.CurrentAsk != nil && Batch.Origin == Origin && Batch.AskMode == Mode }, set: { _ in })
    }

    private var SummaryShowing: Binding<Bool>
    {
        Binding(get: { Batch.Summary != nil && Batch.Origin == Origin }, set: { if !$0 { Batch.Summary = nil } })
    }

    func body(content: Content) -> some View
    {
        content
            .modifier(ChoiceDialog(Batch: Batch, IsShowing: Showing(.Choosing)))
            .modifier(FolderDialog(Batch: Batch, IsShowing: Showing(.Folder)))
            .modifier(ExporterDialog(Batch: Batch, IsShowing: Showing(.Exporter)))
            .alert(Batch.Summary?.Title ?? "", isPresented: SummaryShowing)
            {
                Button("OK") {}
            }
            message:
            {
                Text(Batch.Summary?.Message ?? "")
            }
    }
}

/// The three choices for an image that cannot be saved beside its original.
private struct ChoiceDialog: ViewModifier
{
    let Batch: BatchModel
    let IsShowing: Binding<Bool>

    func body(content: Content) -> some View
    {
        content
            .confirmationDialog("Cannot save “\(Batch.CurrentAsk?.Name ?? "")” beside its original",
                                isPresented: IsShowing, titleVisibility: .visible)
            {
                Button("Choose a Folder for the Rest…")
                {
                    Batch.Ask(Mode: .Folder)
                }
                Button("Save This One As…")
                {
                    Batch.Ask(Mode: .Exporter)
                }
                Button("Skip This Image", role: .cancel)
                {
                    Batch.Answer(.Cancelled)
                }
            }
            message:
            {
                Text("The app is not allowed to write in that folder. Images that cannot be saved there can all go in one folder you choose, or you can choose a place for each one.")
            }
    }
}

/// Choosing the folder for the rest of the images.
private struct FolderDialog: ViewModifier
{
    let Batch: BatchModel
    let IsShowing: Binding<Bool>

    func body(content: Content) -> some View
    {
        content
            .fileImporter(isPresented: IsShowing, allowedContentTypes: [.folder], allowsMultipleSelection: false)
            {
                Result in
                if case .success(let Chosen) = Result,
                   let Folder = Chosen.first
                {
                    Batch.Answer(.UseFolder(Folder))
                }
                else
                {
                    Batch.Ask(Mode: .Choosing)
                }
            }
            onCancellation:
            {
                // Back to the choices.
                Batch.Ask(Mode: .Choosing)
            }
    }
}

/// The save dialog for one image.
private struct ExporterDialog: ViewModifier
{
    let Batch: BatchModel
    let IsShowing: Binding<Bool>

    func body(content: Content) -> some View
    {
        content
            .fileExporter(isPresented: IsShowing,
                          document: Batch.CurrentAsk?.Document,
                          contentTypes: [Batch.CurrentAsk?.Format.Kind ?? .png],
                          defaultFilename: Batch.CurrentAsk?.Name)
            {
                Result in
                switch Result
                {
                    case .success(let Saved):
                        Batch.Answer(.Saved(Saved))

                    case .failure(let Failure):
                        Batch.Answer(.Failed(Failure.localizedDescription))
                }
            }
            onCancellation:
            {
                // Back to the choices, so cancelling the dialog does not lose the chance to pick a folder.
                Batch.Ask(Mode: .Choosing)
            }
    }
}
