//
//  PipelineWindow.swift
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
import UniformTypeIdentifiers

/// The Pipeline window: the original image on the left, then the image after each filter. Lines run from each stage to the stages
/// that take its image, and each stage has a menu.
struct PipelineWindow: View
{
    /// Identifies the window, to open and close it.
    static let ID = "pipeline"

    @Environment(PipelineModel.self) private var Pipeline
    @Environment(BatchModel.self) private var Batch
    @Environment(\.dismissWindow) private var DismissWindow
    @State private var ShowExporter = false
    @State private var ExportDocument = ImageUtility.PNGImage(Data: Data())
    /// The file name the save dialog starts with.
    @State private var ExportName = "Pipeline"
    @State private var MergeAsked: MergeRequest? = nil
    @State private var EditAsked: EditRequest? = nil
    @State private var InsertAsked: InsertRequest? = nil
    @State private var ShowSavePipeline = false
    @State private var ConfirmClear = false
    @State private var ShowText = false
    @State private var ConfirmCancel = false
    /// True while a save started by Cancel is being asked for, so the window closes when it is done.
    @State private var CloseAfterSave = false
    /// The width the user has dragged the final image view to.
    @State private var FinalWidth: CGFloat = 280
    /// The width of the whole window, which limits the final image view.
    @State private var WindowWidth: CGFloat = 1000

    var body: some View
    {
        let Where = Pipeline.Positions()
        let Edges = Pipeline.DrawnEdges()
        let Tip = Pipeline.TipID
        let Columns = (Where.values.map{$0.Col}.max() ?? 0) + 1
        let Rows = (Where.values.map{$0.Row}.max() ?? 0) + 1
        let Width = CGFloat(Columns) * PipelineMetrics.CellWidth - PipelineMetrics.GapWidth + 2 * PipelineMetrics.Margin
        let Height = CGFloat(Rows) * PipelineMetrics.CellHeight + 2 * PipelineMetrics.Margin
        VStack(spacing: 0)
        {
            HStack(spacing: 0)
            {
            ScrollView([.horizontal, .vertical])
            {
                ZStack(alignment: .topLeading)
                {
                    // The lines are drawn first, so they pass under the stages.
                    Canvas
                    {
                        Context, _ in
                        for Line in Edges
                        {
                            if let From = Where[Line.From],
                               let To = Where[Line.To]
                            {
                                PipelineConnector.Draw(Context, From, To)
                            }
                        }
                    }
                    .frame(width: Width, height: Height)
                    ForEach(Pipeline.Stages)
                    {
                        Stage in
                        if let Point = Where[Stage.id]
                        {
                            let Frame = PipelineMetrics.ImageRect(Point)
                            StageView(Stage: Stage,
                                      IsFinal: Stage.id == Tip && Stage.Kind != .Original,
                                      OnMerge: { MergeAsked = MergeRequest(id: Stage.id) },
                                      OnEdit: { EditAsked = EditRequest(id: Stage.id) },
                                      OnInsert: { InsertAsked = InsertRequest(id: Stage.id, After: $0) },
                                      OnSave: { SaveStageImage(Stage) })
                                .offset(x: Frame.minX, y: Frame.minY)
                        }
                    }
                }
                .frame(width: Width, height: Height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            PipelineFinalView(WindowWidth: WindowWidth, Width: $FinalWidth)
            }
            Divider()
            HStack
            {
                Button("Save Pipeline…")
                {
                    ShowSavePipeline = true
                }
                .disabled(Pipeline.Stages.count < 2)
                .help("Save the filters and all of their options, to use again or to use inside another pipeline.")
                Button(Batch.IsActive ? "Save All Images" : "Export Image")
                {
                    if Batch.IsActive
                    {
                        SaveBatch()
                    }
                    else if let Final = Pipeline.FinalImage,
                       let Encoded = ImageUtility.ImageEncoder.PNGData(Final)
                    {
                        ExportDocument = ImageUtility.PNGImage(Data: Encoded)
                        ExportName = "Pipeline"
                        ShowExporter = true
                    }
                }
                .disabled(Batch.IsActive ? Batch.IsSaving : Pipeline.FinalImage == nil)
                .help(Batch.IsActive ? "Run every image of the batch through this pipeline and save each one beside its original" : "")
                .fileExporter(isPresented: $ShowExporter,
                              document: ExportDocument,
                              contentType: .png,
                              defaultFilename: ExportName)
                {
                    Result in
                    if case .failure(let Failure) = Result
                    {
                        print("Save failed: \(Failure)")
                    }
                }
                Button("Edit as Text…")
                {
                    ShowText = true
                }
                .help("Show the pipeline as text, to edit it in words, or to save it as a text file or open one.")
                Button("Use as Source")
                {
                    Pipeline.SendBack()
                }
                // The batch images are saved from their files, so the pipeline's result cannot replace one.
                .disabled(Pipeline.FinalImage == nil || Batch.IsActive)
                Button("Clear Pipeline", role: .destructive)
                {
                    ConfirmClear = true
                }
                .disabled(Pipeline.Stages.count < 2)
                Spacer()
                if let Name = Pipeline.CurrentName
                {
                    Text(Name)
                        .bold()
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                Button("Cancel")
                {
                    if Pipeline.HasUnsavedChanges
                    {
                        ConfirmCancel = true
                    }
                    else
                    {
                        DismissWindow(id: PipelineWindow.ID)
                    }
                }
                .help("Throw away the changes made since the window opened, and close it.")
                Button("Close")
                {
                    DismissWindow(id: PipelineWindow.ID)
                }
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 360)
        .modifier(BatchSaveDialogs(Origin: .Pipeline))
        .confirmationDialog("Clear the pipeline?", isPresented: $ConfirmClear)
        {
            Button("Clear Pipeline", role: .destructive)
            {
                Pipeline.Clear()
            }
            Button("Cancel", role: .cancel) {}
        }
        message:
        {
            Text("Every filter, branch and merge is removed. Only the original image stays.")
        }
        .confirmationDialog("Save changes to the pipeline?", isPresented: $ConfirmCancel)
        {
            Button("Save")
            {
                SaveThenClose()
            }
            Button("Don’t Save", role: .destructive)
            {
                Task
                {
                    await Pipeline.DiscardChanges()
                    DismissWindow(id: PipelineWindow.ID)
                }
            }
            Button("Keep Editing", role: .cancel) {}
        }
        message:
        {
            Text("The pipeline has changes that are not saved. Don’t Save throws them away.")
        }
        .onGeometryChange(for: CGFloat.self)
        {
            $0.size.width
        }
        action:
        {
            WindowWidth = $0
        }
        .sheet(item: $MergeAsked)
        {
            Request in
            MergeSheet(Source: Request.id)
        }
        .sheet(item: $EditAsked)
        {
            Request in
            if let Found = Pipeline.StageFor(Request.id), Found.Kind == .Merge
            {
                MergeEditSheet(StageID: Request.id, Mode: Found.MergeMode, Amount: Found.MergeAmount)
            }
            else if let Selection = Pipeline.StageFor(Request.id)?.Selection
            {
                StageOptionsSheet(StageID: Request.id, Selection: Selection)
            }
        }
        .sheet(item: $InsertAsked)
        {
            Request in
            InsertFilterSheet(StageID: Request.id, After: Request.After)
        }
        .sheet(isPresented: $ShowSavePipeline, onDismiss:
        {
            // Closes the window if the save that Cancel asked for was done, and stays open if the user backed out of it.
            if CloseAfterSave && !Pipeline.HasUnsavedChanges
            {
                DismissWindow(id: PipelineWindow.ID)
            }
            CloseAfterSave = false
        })
        {
            SavePipelineSheet()
        }
        .sheet(isPresented: $ShowText)
        {
            PipelineTextSheet()
        }
        .onAppear
        {
            Pipeline.IsOpen = true
            Pipeline.MarkBaseline()
        }
        .onDisappear
        {
            // A closed pipeline is thrown away; the next one starts with the original image only.
            Pipeline.IsOpen = false
            Pipeline.Reset()
        }
    }

    /// Saves the pipeline under its own name, or asks for a name if it has none, and then closes the window.
    private func SaveThenClose()
    {
        if let Name = Pipeline.CurrentName
        {
            do
            {
                try Pipeline.Save(Name: Name, Directory: Pipeline.SaveFolder(Library: .Shared), Library: .Shared)
                DismissWindow(id: PipelineWindow.ID)
                return
            }
            catch
            {
                // The name cannot be used as it is, so the save dialog explains and lets the user choose another.
            }
        }
        CloseAfterSave = true
        ShowSavePipeline = true
    }

    /// Asks where to save the image a stage has made, as a PNG. Transparency is kept.
    /// - Parameter Stage: The stage whose image is saved.
    private func SaveStageImage(_ Stage: PipelineModel.Stage)
    {
        guard let Output = Stage.Output,
              let Encoded = ImageUtility.ImageEncoder.PNGData(Output) else
        {
            return
        }
        ExportDocument = ImageUtility.PNGImage(Data: Encoded)
        ExportName = "Pipeline Stage \(Stage.id)"
        ShowExporter = true
    }

    /// Runs every image of the batch through the pipeline as it is now, and saves each one beside its original.
    private func SaveBatch()
    {
        let Saved = Pipeline.Snapshot(Name: "Batch")
        let Filters = Pipeline.Server?.BuiltInFilters ?? [:]
        Task
        {
            await Batch.SaveAll(From: .Pipeline)
            {
                Image in
                try await PipelineExecutor.Run(Saved, Input: Image, Filters: Filters)
            }
        }
    }
}
#endif
