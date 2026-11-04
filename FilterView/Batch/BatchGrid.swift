//
//  BatchGrid.swift
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

/// The images of a batch in a grid, in place of the single image. Tapping an image makes it the current one (the one the Pipeline window
/// starts from). The images are filtered here, as the selected filter changes.
struct BatchGrid: View
{
    @Environment(BatchModel.self) private var Batch
    var Server: FilterServer?
    var Selection: FilterSelection?
    /// The regions and their filters, when the image is divided. Used instead of `Selection`.
    var Split: SplitSetup? = nil

    /// A new filter or a new batch makes the grid filter again.
    private struct PreviewKey: Hashable
    {
        let Selection: FilterSelection?
        let Split: SplitSetup?
        let Revision: UUID
    }

    var body: some View
    {
        ScrollView
        {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))])
            {
                ForEach(Batch.Items)
                {
                    Item in
                    BatchCell(Item: Item, IsFocused: Item.id == Batch.FocusedID)
                    {
                        Batch.Focus(Item.id)
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black, ignoresSafeAreaEdges: [])
        .modifier(BatchSaveDialogs(Origin: .Main))
        .task(id: PreviewKey(Selection: Selection, Split: Split, Revision: Batch.Revision))
        {
            // Waits a moment first, so dragging a slider does not start a run of every image for each step.
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled
            {
                return
            }
            await Batch.Preview(Transform: BatchModel.FilterTransform(Server: Server, Selection: Selection, Split: Split))
        }
    }
}

/// One image of the grid, with its name and what is happening to it.
private struct BatchCell: View
{
    let Item: BatchItem
    let IsFocused: Bool
    let OnSelect: () -> Void

    var body: some View
    {
        Button(action: OnSelect)
        {
            VStack
            {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay
                    {
                        ImageUtility.CGImageToImage(Item.Shown)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(.white)
                            .background { ImageBackgroundView() }
                    }
                    .overlay(alignment: .topTrailing)
                    {
                        BatchStatusBadge(Status: Item.Status)
                    }
                    .overlay
                    {
                        if IsFocused
                        {
                            RoundedRectangle(cornerRadius: 4).stroke(.tint, lineWidth: 3)
                        }
                    }
                Text(Item.Name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Item.Name)
        .accessibilityAddTraits(IsFocused ? .isSelected : [])
    }
}

/// A small mark on a grid image: a spinner while it is worked on, then whether it was saved.
private struct BatchStatusBadge: View
{
    let Status: BatchItemStatus

    var body: some View
    {
        switch Status
        {
            case .Idle:
                EmptyView()

            case .Working:
                ProgressView()
                    .controlSize(.small)
                    .padding(4)
                    .background(.regularMaterial, in: .circle)

            case .Saved(let Where):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .background(.white, in: .circle)
                    .accessibilityLabel("Saved as \(Where.lastPathComponent)")

            case .Skipped:
                Image(systemName: "slash.circle.fill")
                    .foregroundStyle(.orange)
                    .background(.white, in: .circle)
                    .accessibilityLabel("Not saved")

            case .Failed(let Reason):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .background(.white, in: .circle)
                    .help(Reason)
                    .accessibilityLabel("Failed: \(Reason)")
        }
    }
}
