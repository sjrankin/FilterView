//
//  MainUI.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct MainUI: View
{
    @Binding var Filters: FilterServer?
    var FilterTreeData: FilterNode?
    @State private var Selection: FilterSelection? = nil
    @State var SourceImage = Image("Hana")
    @State var SourceID = UUID()
    @State private var InputSource: ImageInputSources = .Image
    @State var IsDropTargeted = false
    @State var ShowExporter = false
    @State private var ExportDocument = ImageUtility.PNGImage(Data: Data())
    
    var body: some View
    {
        HStack
        {
            VStack
            {
                ImageView(DisplayImage: SourceImage,
                          Server: Filters,
                          Selection: Selection,
                          SourceID: SourceID)
                #if os(macOS)
                .dropDestination(for: URL.self)
                {
                    URLs, _ in
                    guard let FirstImage = URLs.first,
                          let Dropped = ImageUtility.LoadImage(from: FirstImage) else
                    {
                        return false
                    }
                    SourceImage = ImageUtility.CGImageToImage(Dropped)
                    SourceID = UUID()
                    return true
                }
            isTargeted:
                {
                    IsDropTargeted = $0
                }
                .overlay
                {
                    if IsDropTargeted
                    {
                        RoundedRectangle(cornerRadius: 8).stroke(.tint, lineWidth: 3)
                    }
                }
                #endif
                .frame(minHeight: 200)
                HStack
                {
                    Picker("", selection: $InputSource)
                    {
                        ForEach(ImageInputSources.allCases)
                        {
                            SomeSource in
                            Text(SomeSource.rawValue).tag(SomeSource)
                        }
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                    if InputSource == .Image
                    {
                        Button("Load")
                        {
                            print("Load from OS")
                        }
                    }
                    Button("Save")
                    {
                        Task
                        {
                            await PrepareExport()
                        }
                    }
                    .fileExporter(isPresented: $ShowExporter,
                                  document: ExportDocument,
                                  contentType: .png,
                                  defaultFilename: "Filtered")
                    {
                        Result in
                        switch Result
                        {
                            case .success(let Saved):
                                print("Saved to \(Saved)")
                                
                            case .failure(let Failure):
                                print("Save failed: \(Failure)")
                        }
                    }
                }
                .padding()
            }
            Spacer()
            ControlStack(FilterTreeData: FilterTreeData, Selection: $Selection)
        }
    }

    /// Applies the selected filter (if any) to the image, encodes it as PNG, and shows the save dialog.
    private func PrepareExport() async
    {
        guard var Result = ImageUtility.ImageToCGImage(SourceImage) else
        {
            return
        }
        if let Selection = Selection,
           let Server = Filters,
           let Filtered = try? await Server.Run(Filter: Selection.Filter, With: Result, Selection.Options)
        {
            Result = Filtered
        }
        guard let Encoded = ImageUtility.ImageEncoder.PNGData(Result) else
        {
            return
        }
        ExportDocument = ImageUtility.PNGImage(Data: Encoded)
        ShowExporter = true
    }
}

enum ImageInputSources: String, CaseIterable, Identifiable
{
    case Image = "Image"
    case Camera = "Camera"
    case Video = "Video"
    var id: String { rawValue }
}

#Preview
{
    @Previewable @State var Filters: FilterServer? = FilterServer()
    MainUI(Filters: $Filters)
}
