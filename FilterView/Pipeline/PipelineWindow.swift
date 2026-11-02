//
//  PipelineWindow.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
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
    @Environment(\.dismissWindow) private var DismissWindow
    @State private var ShowExporter = false
    @State private var ExportDocument = ImageUtility.PNGImage(Data: Data())
    @State private var MergeAsked: MergeRequest? = nil
    @State private var ConfirmClear = false

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
                                      OnMerge: { MergeAsked = MergeRequest(id: Stage.id) })
                                .offset(x: Frame.minX, y: Frame.minY)
                        }
                    }
                }
                .frame(width: Width, height: Height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack
            {
                Button("Save")
                {
                    if let Final = Pipeline.FinalImage,
                       let Encoded = ImageUtility.ImageEncoder.PNGData(Final)
                    {
                        ExportDocument = ImageUtility.PNGImage(Data: Encoded)
                        ShowExporter = true
                    }
                }
                .disabled(Pipeline.FinalImage == nil)
                .fileExporter(isPresented: $ShowExporter,
                              document: ExportDocument,
                              contentType: .png,
                              defaultFilename: "Pipeline")
                {
                    Result in
                    if case .failure(let Failure) = Result
                    {
                        print("Save failed: \(Failure)")
                    }
                }
                Button("Use as Source")
                {
                    Pipeline.SendBack()
                }
                .disabled(Pipeline.FinalImage == nil)
                Button("Clear Pipeline", role: .destructive)
                {
                    ConfirmClear = true
                }
                .disabled(Pipeline.Stages.count < 2)
                Spacer()
                Button("Close")
                {
                    DismissWindow(id: PipelineWindow.ID)
                }
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 360)
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
        .sheet(item: $MergeAsked)
        {
            Request in
            MergeSheet(Source: Request.id)
        }
        .onAppear
        {
            Pipeline.IsOpen = true
        }
        .onDisappear
        {
            // A closed pipeline is thrown away; the next one starts with the original image only.
            Pipeline.IsOpen = false
            Pipeline.Reset()
        }
    }
}
#endif
