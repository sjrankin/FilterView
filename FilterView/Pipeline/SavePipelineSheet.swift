//
//  SavePipelineSheet.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// The dialog that saves the pipeline under a unique name, by default in `Documents/FilterView/Pipelines` or, if the user prefers,
/// in a folder of their choice.
struct SavePipelineSheet: View
{
    @Environment(PipelineModel.self) private var Pipeline
    @Environment(\.dismiss) private var Dismiss
    @State private var Name = ""
    /// The folder the user chose instead of the default. `nil` means the default folder.
    @State private var Folder: URL? = nil
    @State private var ChoosingFolder = false
    @State private var Failure: String? = nil
    private let Library = PipelineLibrary.Shared

    var body: some View
    {
        let Problem = Pipeline.SaveProblem(Name: Name, Directory: Folder, Library: Library)
        VStack(alignment: .leading)
        {
            Text("Save Pipeline")
                .font(.headline)
            TextField("Name", text: $Name)
                .onSubmit
                {
                    Save()
                }
            HStack
            {
                Text("Folder")
                Text(Folder?.path ?? "Documents/FilterView/Pipelines")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Choose…")
                {
                    ChoosingFolder = true
                }
                if Folder != nil
                {
                    Button("Default")
                    {
                        Folder = nil
                    }
                }
            }
            Text("Only pipelines in the default folder, and in folders loaded in the filter tree, are listed there.")
                .font(.caption)
                .foregroundStyle(.secondary)
            // Nothing is said about an empty name until the user has typed something.
            if let Problem = Failure ?? (Name.isEmpty ? nil : Problem)
            {
                Text(Problem)
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
                Button("Save")
                {
                    Save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(Problem != nil)
            }
        }
        .padding()
        .frame(width: 440)
        .fileImporter(isPresented: $ChoosingFolder, allowedContentTypes: [.folder])
        {
            Chosen in
            if case .success(let Picked) = Chosen
            {
                Folder = Picked
            }
        }
        .onChange(of: Name)
        {
            Failure = nil
        }
        .onAppear
        {
            Name = Pipeline.CurrentName ?? ""
        }
    }

    private func Save()
    {
        guard Pipeline.SaveProblem(Name: Name, Directory: Folder, Library: Library) == nil else
        {
            return
        }
        do
        {
            try Pipeline.Save(Name: Name, Directory: Folder, Library: Library)
            Dismiss()
        }
        catch let Caught as FilterException
        {
            Failure = Caught.Message
        }
        catch
        {
            Failure = error.localizedDescription
        }
    }
}
#endif
