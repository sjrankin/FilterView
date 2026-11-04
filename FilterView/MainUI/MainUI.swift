//
//  MainUI.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
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

/// The main window: the image area and input controls on the left, a draggable divider, and the filter and option panel on the
/// right. The pieces are in `ImagePane`, `InputControlBar`, `PanelDivider`, and `ControlStack`; the actions are in
/// `MainUI+Actions.swift`.
struct MainUI: View
{
    @Binding var Filters: FilterServer?
    var FilterTreeData: FilterNode?
    // These are not private because the functions in `MainUI+Actions.swift` use them.
    @State var Selection: FilterSelection? = nil
    /// The image divided into regions that each have their own filter. `nil` when it is not divided.
    @State var Split: SplitSetup? = nil
    @State var SourceImage = Image("Hana")
    @State var SourceID = UUID()
    /// Where `SourceImage` came from: the built-in image, a file name, or a camera photo. Live video is described
    /// separately (see `DisplayedSourceName`) because `SourceImage` is not used while it runs.
    @State var SourceName = "Built-in"
    /// How long the last render took. `nil` if there is no filter or nothing has rendered yet.
    @State var RenderTime: Duration? = nil
    /// Size in pixels of `SourceImage`. `nil` until known.
    @State var SourceSize: CGSize? = nil
    /// Size in pixels of the live video frames. `nil` until the first frame arrives.
    @State var LiveSize: CGSize? = nil
    @State var InputSource: ImageInputSources = .Image
    @State var ShowExporter = false
    @State var ExportDocument = ImageUtility.PNGImage(Data: Data())
    @State var ShowCamera = false
    /// The filter pipeline. Only used on macOS, where the Pipeline window is.
    @Environment(PipelineModel.self) var Pipeline
    /// The images of batch mode, shared with the Pipeline window.
    @Environment(BatchModel.self) var Batch
    @State var PanelWidth: CGFloat = 300
    /// The panel's height when it is under the image (narrow screens).
    @State var PanelHeight: CGFloat = 300
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var SizeClass
    #endif
    @State var Camera = CameraFrameSource()
    /// The newest live video frame, already filtered. `nil` until the first frame arrives.
    @State var LiveImage: Image? = nil
    /// The newest live video frame before filtering, for the original-image thumbnail. `nil` until the first frame arrives.
    @State var LiveSource: Image? = nil
    /// Frame rate limit for live video, in frames per second.
    @State var MaxFPS = 15.0
    /// Writes the filtered live video to a file while recording.
    @State var Recorder = VideoRecorder()
    @State var IsRecording = false
    /// The last finished recording. Save can save it again until the next recording replaces it.
    @State var LastMovie: RecordedMovie? = nil
    /// Shows the dialog that asks where to save `LastMovie`.
    @State var ShowMovieExporter = false
    /// Shows the general settings dialog.
    @State var ShowSettings = false

    /// True on a narrow screen (iPhone in portrait): the panel goes under the image instead of beside it.
    private var IsCompact: Bool
    {
        #if os(iOS)
        return SizeClass == .compact
        #else
        return false
        #endif
    }

    /// `AnyLayout` keeps the views' identity when the layout changes, so a rotation does not restart live video or lose state.
    private var MainLayout: AnyLayout
    {
        IsCompact ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
    }

    var body: some View
    {
        MainLayout
        {
            VStack
            {
                ImagePane(InputSource: InputSource,
                          LiveImage: LiveImage,
                          SourceImage: SourceImage,
                          Server: Filters,
                          Selection: Selection,
                          Split: Split,
                          OnSelectRegion: SelectRegion,
                          SourceID: SourceID,
                          OnRendered: { RenderTime = $0 },
                          OnDropped: LoadImages)
                    .frame(minHeight: 200)
                    // Selecting Video starts the camera; selecting anything else cancels this task, which stops it.
                    .task(id: InputSource)
                    {
                        await RunLiveVideo()
                    }
                    .onChange(of: MaxFPS)
                    {
                        Camera.MaxFPS = MaxFPS
                    }
                    .onChange(of: IsRecording)
                    {
                        // A recording's size is set by its first frame, so the picture stays as it is until it ends.
                        Camera.RotationLocked = IsRecording
                    }
                    .task
                    {
                        MeasureBuiltInImage()
                    }
                    #if os(iOS)
                    // The system camera.
                    .fullScreenCover(isPresented: $ShowCamera)
                    {
                        CameraPicker
                        {
                            UseCapturedPhoto($0)
                        }
                        .ignoresSafeArea()
                    }
                    #else
                    // macOS has no system camera interface, so this is a capture sheet.
                    .sheet(isPresented: $ShowCamera)
                    {
                        MacCameraSheet
                        {
                            UseCapturedPhoto($0)
                        }
                    }
                    #endif
                SplitControls(Setup: Split, OnChoose: ChooseSplit, OnRemove: RemoveRegions)
                    .padding([.horizontal, .top])
                InputControlBar(InputSource: $InputSource,
                                MaxFPS: $MaxFPS,
                                ShowExporter: $ShowExporter,
                                ExportDocument: ExportDocument,
                                OnLoad: LoadImages,
                                BatchCount: Batch.IsActive ? Batch.Items.count : 0,
                                CanReset: SourceName != "Built-in" || InputSource != .Image || Batch.IsActive,
                                OnReset: ResetToBuiltInImage,
                                OnTakePhoto: { ShowCamera = true },
                                OnSave: PrepareExport,
                                HasFrame: LiveImage != nil,
                                OnSaveFrame: SaveLiveFrame,
                                IsRecording: IsRecording,
                                Movie: LastMovie,
                                ShowMovieExporter: $ShowMovieExporter,
                                OnRecord: { Task { await StartRecording() } },
                                OnStop: StopRecording)
                    .padding()
                #if os(macOS)
                PipelineControls(HasFilter: Selection != nil,
                                 OnSet: AddToPipeline,
                                 OnConditional: AddConditionalToPipeline,
                                 OnSplit: AddSplitterToPipeline)
                    .padding([.horizontal, .bottom])
                #endif
            }
            PanelDivider(Size: IsCompact ? $PanelHeight : $PanelWidth, Direction: IsCompact ? .vertical : .horizontal,
                         MinSize: 200, MaxSize: IsCompact ? 520 : 600)
            // The settings button has its own row above the filter list, so it never covers the list.
            VStack(spacing: 0)
            {
                HStack
                {
                    Spacer()
                    Button("Settings", systemImage: "gearshape")
                    {
                        ShowSettings = true
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .controlSize(.large)
                    .keyboardShortcut(",", modifiers: .command)
                    .help("Settings")
                }
                .padding([.horizontal, .top], 8)
                ControlStack(FilterTreeData: FilterTreeData, Selection: $Selection, SourceName: DisplayedSourceName,
                             FilterName: Selection?.DisplayName ?? "None", RenderTime: RenderTime,
                             ImageSize: DisplayedSize, SourceImage: DisplayedSourceImage)
            }
            .frame(width: IsCompact ? nil : PanelWidth, height: IsCompact ? PanelHeight : nil)
            // Whatever a panel's contents ask for, they stay inside the panel and do not push into the image.
            .clipped()
        }
        .sheet(isPresented: $ShowSettings)
        {
            SettingsView()
        }
        .onAppear
        {
            Pipeline.UseAsSource = UsePipelineResult
            Pipeline.Server = Filters
            Pipeline.SelectedFilter = Selection
        }
        .onChange(of: Selection)
        {
            Pipeline.SelectedFilter = Selection
            // While the image is divided, the filter chosen belongs to the region being edited.
            if var Current = Split,
               Current.ActiveSelection != Selection
            {
                Current.Assign(Selection)
                Split = Current
            }
        }
        // The pipeline starts from the image on show: when its window opens, and whenever that image changes.
        .onChange(of: Pipeline.IsOpen)
        {
            SyncPipeline()
        }
        .onChange(of: SourceID)
        {
            SyncPipeline()
        }
        .onChange(of: InputSource)
        {
            // A batch is only in use while the input is still images.
            Batch.Suspended = InputSource != .Image
            SyncPipeline()
        }
        // Clicking an image of the batch makes it the current image, which is also where the pipeline starts.
        .onChange(of: Batch.FocusedID)
        {
            UseFocusedBatchImage()
        }
    }
}

#Preview
{
    @Previewable @State var Filters: FilterServer? = FilterServer()
    MainUI(Filters: $Filters)
        .environment(PipelineModel())
        .environment(BatchModel())
}
