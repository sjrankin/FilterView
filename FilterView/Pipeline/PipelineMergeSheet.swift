//
//  PipelineMergeSheet.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

#if os(macOS)
import SwiftUI

/// Identifies the stage a merge dialog is for.
struct MergeRequest: Identifiable
{
    let id: Int
}

/// The dialog that asks which stage to merge with and how.
struct MergeSheet: View
{
    /// The stage being merged.
    let Source: Int
    @Environment(PipelineModel.self) private var Pipeline
    @Environment(\.dismiss) private var Dismiss
    @State private var Target = -1
    @State private var Mode = MergeModes.Multiply
    @State private var Amount = 1.0

    var body: some View
    {
        let Targets = Pipeline.MergeTargets(for: Source)
        VStack(alignment: .leading, spacing: 14)
        {
            Text("Merge stage \(Source)")
                .font(.headline)
            if Targets.isEmpty
            {
                Text("There is no stage this one can be merged with.")
            }
            else
            {
                Picker("Merge with", selection: $Target)
                {
                    ForEach(Targets, id: \.self)
                    {
                        ID in
                        Text("\(ID): \(Pipeline.StageFor(ID)?.Name ?? "")").tag(ID)
                    }
                }
                Picker("Mode", selection: $Mode)
                {
                    ForEach(MergeModes.allCases)
                    {
                        Text($0.Title).tag($0)
                    }
                }
                HStack
                {
                    Text("Amount: \(Amount, format: .percent.precision(.fractionLength(0)))")
                        .monospacedDigit()
                        .frame(width: 110, alignment: .leading)
                    Slider(value: $Amount, in: 0 ... 1)
                }
                Text("The merge goes after the chosen stage. Stage \(Source) is merged onto it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack
            {
                Spacer()
                Button("Cancel")
                {
                    Dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Merge")
                {
                    Pipeline.Merge(From: Source, With: Target, Mode: Mode, Amount: Amount)
                    Dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!Targets.contains(Target))
            }
        }
        .padding()
        .frame(width: 380)
        .onAppear
        {
            if let First = Targets.first
            {
                Target = First
            }
        }
    }
}
#endif
