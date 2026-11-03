//
//  PipelineStageView.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
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

#if os(macOS)
import SwiftUI

/// One image with its number, its name under it, and its menu.
struct StageView: View
{
    let Stage: PipelineModel.Stage
    let IsFinal: Bool
    /// Called when the user chooses Merge With.
    let OnMerge: () -> Void
    /// Called when the user taps Edit Filter.
    let OnEdit: () -> Void
    /// Called when the user chooses Insert Filter Before (false) or After (true). The window asks which filter.
    let OnInsert: (Bool) -> Void
    @Environment(PipelineModel.self) private var Pipeline

    /// True if the stage's filter has options to edit.
    private var CanEdit: Bool
    {
        Stage.Kind == .Filter && !(Stage.Selection?.Parameters.isEmpty ?? true)
    }

    var body: some View
    {
        VStack(spacing: 4)
        {
            Group
            {
                if let Output = Stage.Output
                {
                    Image(decorative: Output, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(Checkerboard(SquareSize: 8))
                }
                else
                {
                    ProgressView()
                }
            }
            .frame(width: PipelineMetrics.Side, height: PipelineMetrics.Side)
            .background(.black)
            .opacity(Stage.Skipped ? 0.4 : 1.0)
            .overlay
            {
                // The final image is outlined.
                if IsFinal
                {
                    Rectangle().stroke(.tint, lineWidth: 3)
                }
            }
            .overlay(alignment: .topLeading)
            {
                // The stage number, large and in the accent color so it is easy to see.
                Text("\(Stage.id)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(.tint, in: .capsule)
                    .shadow(radius: 2)
                    .padding(8)
            }
            .overlay(alignment: .bottom)
            {
                if CanEdit
                {
                    Button("Edit Filter", systemImage: "slider.horizontal.3")
                    {
                        OnEdit()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(6)
                }
            }
            .overlay(alignment: .topTrailing)
            {
                Menu
                {
                    MenuItems
                }
                label:
                {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(6)
            }
            // The name has a background so a line passing under it is not seen through the text.
            VStack(spacing: 2)
            {
                Text(Stage.Name)
                    .bold(IsFinal)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if Stage.Skipped
                {
                    Text("Skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if IsFinal
                {
                    Text("Final")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
                if Stage.Failed
                {
                    Text("Failed")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(width: PipelineMetrics.Side)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: PipelineMetrics.Side, alignment: .top)
        .contextMenu
        {
            MenuItems
        }
    }

    /// What the stage's menu offers. The original image cannot be skipped or deleted.
    @ViewBuilder private var MenuItems: some View
    {
        if Stage.Kind != .Original
        {
            if Stage.Skipped
            {
                Button("Resume")
                {
                    Pipeline.Resume(Stage.id)
                }
            }
            else
            {
                Button("Skip")
                {
                    Pipeline.Skip(Stage.id)
                }
            }
            Button("Delete", role: .destructive)
            {
                Pipeline.Delete(Stage.id)
            }
            Divider()
        }
        if Stage.Kind != .Original
        {
            Button("Insert Filter Before…")
            {
                OnInsert(false)
            }
        }
        Button("Insert Filter After…")
        {
            OnInsert(true)
        }
        Divider()
        Button("Diverge")
        {
            Pipeline.Diverge(Stage.id)
        }
        Button("Merge With…")
        {
            OnMerge()
        }
        .disabled(Pipeline.MergeTargets(for: Stage.id).isEmpty)
        if CanEdit
        {
            Button("Edit Filter…")
            {
                OnEdit()
            }
        }
        if Stage.Kind == .Filter
        {
            Button("Use Selected Filter")
            {
                Pipeline.UseSelectedFilter(Stage.id)
            }
            .disabled(Pipeline.SelectedFilter == nil)
        }
    }
}
#endif
