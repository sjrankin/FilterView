//
//  PipelineTextSheet.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/23/26.
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

/// The pipeline written as text, to edit here. Apply replaces the filters of the pipeline in the window with the ones the text
/// describes, and Save also writes them to the pipeline's own file. Text with a mistake in it is shown with the problem and is never
/// applied or saved. See `PipelineText` for how to write it.
struct PipelineTextSheet: View
{
    @Environment(PipelineModel.self) private var Pipeline
    @Environment(\.dismiss) private var Dismiss
    @State private var Source = ""
    /// Why the pipeline could not be saved.
    @State private var SaveFailure: String? = nil
    private let Library = PipelineLibrary.Shared

    /// What is wrong with the text, or `nil` if it can be used.
    private var Problem: String?
    {
        do
        {
            _ = try PipelineText.Parse(Source)
            return nil
        }
        catch
        {
            return (error as? FilterException)?.Message ?? "The text cannot be read."
        }
    }

    var body: some View
    {
        let Found = Problem
        VStack(alignment: .leading)
        {
            Text("Pipeline as Text")
                .font(.headline)
            TextEditor(text: $Source)
                .font(.body.monospaced())
                .autocorrectionDisabled()
                .frame(minWidth: 520, minHeight: 320)
            if let Message = SaveFailure ?? Found
            {
                Text(Message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack
            {
                Spacer()
                Button("Cancel")
                {
                    Dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Apply")
                {
                    Apply(Save: false)
                }
                .disabled(Found != nil)
                .help("Replace the filters of the pipeline with the ones in the text, without saving the pipeline's file.")
                Button("Save")
                {
                    Apply(Save: true)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(Found != nil)
                .help("Replace the filters of the pipeline with the ones in the text, and save the pipeline's file.")
            }
        }
        .padding()
        .onChange(of: Source)
        {
            SaveFailure = nil
        }
        .onAppear
        {
            Source = PipelineText.Format(Pipeline.Snapshot(Name: Pipeline.CurrentName ?? "Pipeline"))
        }
    }

    /// Replaces the pipeline's stages with the ones in the text, and saves the pipeline's file if asked. If the text has a mistake, or
    /// the pipeline cannot be saved, nothing is changed and the problem is shown.
    /// - Parameter Save: True to also write the pipeline's file.
    private func Apply(Save: Bool)
    {
        guard let Parsed = try? PipelineText.Parse(Source) else
        {
            return
        }
        Task
        {
            do
            {
                if Save
                {
                    try await Pipeline.ApplyAndSave(Parsed, Library: Library)
                }
                else
                {
                    await Pipeline.Load(Parsed, From: Pipeline.CurrentURL)
                }
                Dismiss()
            }
            catch
            {
                SaveFailure = (error as? FilterException)?.Message ?? error.localizedDescription
            }
        }
    }
}
#endif
