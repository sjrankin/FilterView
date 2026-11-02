//
//  PipelineWindow.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// Where the stages go in the window and how big they are.
private enum PipelineMetrics
{
    /// Width and height of each stage's image.
    static let Side: CGFloat = 198
    /// Space between one column of images and the next, where the lines run.
    static let GapWidth: CGFloat = 70
    /// Room under an image for its name and a note.
    static let LabelHeight: CGFloat = 64
    /// Space between one row of stages and the next.
    static let GapHeight: CGFloat = 36
    /// Space around everything.
    static let Margin: CGFloat = 24
    static let CellWidth = Side + GapWidth
    static let CellHeight = Side + LabelHeight + GapHeight

    /// The image of the stage at this place.
    static func ImageRect(_ Point: PipelineModel.GridPoint) -> CGRect
    {
        CGRect(x: Margin + CGFloat(Point.Col) * CellWidth, y: Margin + CGFloat(Point.Row) * CellHeight, width: Side, height: Side)
    }
}

/// Identifies the stage a merge dialog is for.
private struct MergeRequest: Identifiable
{
    let id: Int
}

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
                                Connect(Context, From, To)
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
                Spacer()
                Button("Close")
                {
                    DismissWindow(id: PipelineWindow.ID)
                }
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 360)
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

    /// Draws an arrow from one stage's image to another's. A stage under the one it follows gets a straight line down from the
    /// bottom edge of the image to the top edge of the next. Otherwise the line leaves the right edge, runs through the space
    /// between the columns, and enters the left edge of the next stage.
    private func Connect(_ Context: GraphicsContext, _ From: PipelineModel.GridPoint, _ To: PipelineModel.GridPoint)
    {
        let A = PipelineMetrics.ImageRect(From)
        let B = PipelineMetrics.ImageRect(To)
        var Line = Path()
        var Head = Path()
        if To.Col == From.Col && To.Row > From.Row
        {
            let End = CGPoint(x: B.midX, y: B.minY)
            Line.move(to: CGPoint(x: A.midX, y: A.maxY))
            Line.addLine(to: End)
            Head.move(to: End)
            Head.addLine(to: CGPoint(x: End.x - 6, y: End.y - 11))
            Head.addLine(to: CGPoint(x: End.x + 6, y: End.y - 11))
        }
        else
        {
            let Start = CGPoint(x: A.maxX, y: A.midY)
            let End = CGPoint(x: B.minX, y: B.midY)
            Line.move(to: Start)
            if abs(Start.y - End.y) > 0.5
            {
                let Channel = A.maxX + PipelineMetrics.GapWidth / 2
                Line.addLine(to: CGPoint(x: Channel, y: Start.y))
                Line.addLine(to: CGPoint(x: Channel, y: End.y))
            }
            Line.addLine(to: End)
            Head.move(to: End)
            Head.addLine(to: CGPoint(x: End.x - 11, y: End.y - 6))
            Head.addLine(to: CGPoint(x: End.x - 11, y: End.y + 6))
        }
        Head.closeSubpath()
        Context.stroke(Line, with: .color(.gray), lineWidth: 2)
        Context.fill(Head, with: .color(.gray))
    }

    /// One image with its number, its name under it, and its menu.
    private struct StageView: View
    {
        let Stage: PipelineModel.Stage
        let IsFinal: Bool
        /// Called when the user chooses Merge With.
        let OnMerge: () -> Void
        @Environment(PipelineModel.self) private var Pipeline

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
                    // The stage number.
                    Text("\(Stage.id)")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: Capsule())
                        .padding(6)
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
            Button("Diverge")
            {
                Pipeline.Diverge(Stage.id)
            }
            Button("Merge With…")
            {
                OnMerge()
            }
            .disabled(Pipeline.MergeTargets(for: Stage.id).isEmpty)
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

    /// The dialog that asks which stage to merge with and how.
    private struct MergeSheet: View
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
}
#endif
