//
//  MainUI.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
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
    @State var SourceImage = Image("Hana")
    @State var SourceID = UUID()
    /// Where `SourceImage` came from: the built-in image, a file name, or a camera photo. Live video is described
    /// separately (see `DisplayedSourceName`) because `SourceImage` is not used while it runs.
    @State var SourceName = "Built-in image"
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
    @State var PanelWidth: CGFloat = 300
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

    var body: some View
    {
        HStack(spacing: 0)
        {
            VStack
            {
                ImagePane(InputSource: InputSource,
                          LiveImage: LiveImage,
                          SourceImage: SourceImage,
                          Server: Filters,
                          Selection: Selection,
                          SourceID: SourceID,
                          OnRendered: { RenderTime = $0 },
                          OnDropped: UseDroppedImage)
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
                InputControlBar(InputSource: $InputSource,
                                MaxFPS: $MaxFPS,
                                ShowExporter: $ShowExporter,
                                ExportDocument: ExportDocument,
                                OnLoad: ImportLoadedImage,
                                OnTakePhoto: { ShowCamera = true },
                                OnSave: PrepareExport,
                                IsRecording: IsRecording,
                                Movie: LastMovie,
                                ShowMovieExporter: $ShowMovieExporter,
                                OnRecord: { Task { await StartRecording() } },
                                OnStop: StopRecording)
                    .padding()
            }
            PanelDivider(Size: $PanelWidth)
            ControlStack(FilterTreeData: FilterTreeData, Selection: $Selection, SourceName: DisplayedSourceName,
                         FilterName: Selection?.DisplayName ?? "None", RenderTime: RenderTime,
                         ImageSize: DisplayedSize, SourceImage: DisplayedSourceImage)
                .frame(width: PanelWidth)
        }
    }
}

#Preview
{
    @Previewable @State var Filters: FilterServer? = FilterServer()
    MainUI(Filters: $Filters)
}
