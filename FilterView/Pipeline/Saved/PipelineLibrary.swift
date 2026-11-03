//
//  PipelineLibrary.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
//

import Foundation

/// The saved pipelines the app knows about: those in the default folder (`Documents/FilterView/Pipelines`) and those in any other
/// folders the user has loaded. The other folders are remembered between launches with security-scoped bookmarks, which the sandbox
/// needs to open a folder again without asking.
@Observable @MainActor
final class PipelineLibrary
{
    static let Shared = PipelineLibrary()

    /// The `UserDefaults` key of the bookmarks of the other folders.
    static let BookmarksKey = "PipelineLibrary.Folders"

    /// Where pipelines are saved unless the user chooses another folder.
    nonisolated static var StandardDirectory: URL
    {
        URL.documentsDirectory.appending(path: "FilterView/Pipelines", directoryHint: .isDirectory)
    }

    /// One saved pipeline file.
    struct Entry: Identifiable
    {
        /// Stays the same for a file as the library is read again, so a selection in the filter tree survives it.
        let id: UUID
        let Pipeline: SavedPipeline
        let URL: URL
        /// The pipeline as JSON text, ready to be the option of `SavedPipelineFilter`.
        let JSON: String
    }

    /// One folder and the pipelines in it.
    struct Folder: Identifiable
    {
        let id: UUID
        let URL: URL
        var Entries: [Entry]
        let IsDefault: Bool
    }

    /// The default folder, then the folders the user loaded.
    private(set) var Folders = [Folder]()

    /// Identifies the "Saved Pipelines" branch of the filter tree.
    let BranchID = UUID()

    let DefaultDirectory: URL
    @ObservationIgnored private let Defaults: UserDefaults
    /// The folders the user loaded, which are open for access.
    @ObservationIgnored private var OtherDirectories = [URL]()
    @ObservationIgnored private var StableIDs = [String: UUID]()

    /// - Parameter DefaultDirectory: Where pipelines are saved by default.
    /// - Parameter Defaults: Where the remembered folders are kept.
    init(DefaultDirectory: URL = PipelineLibrary.StandardDirectory, Defaults: UserDefaults = .standard)
    {
        self.DefaultDirectory = DefaultDirectory
        self.Defaults = Defaults
        OtherDirectories = ResolveBookmarks()
        Reload()
    }

    // MARK: Reading

    /// Reads the folders again.
    func Reload()
    {
        var Result = [Folder(id: StableID(DefaultDirectory), URL: DefaultDirectory, Entries: Entries(in: DefaultDirectory),
                             IsDefault: true)]
        for Directory in OtherDirectories
        {
            Result.append(Folder(id: StableID(Directory), URL: Directory, Entries: Entries(in: Directory), IsDefault: false))
        }
        Folders = Result
    }

    /// The pipelines in a folder, sorted by name. Files that are not pipelines are left out.
    private func Entries(in Directory: URL) -> [Entry]
    {
        let Files = (try? FileManager.default.contentsOfDirectory(at: Directory, includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles])) ?? []
        var Found = [Entry]()
        for File in Files where File.pathExtension == SavedPipeline.FileExtension
        {
            guard let Raw = try? Data(contentsOf: File),
                  let Saved = SavedPipeline.Decode(Data: Raw),
                  let JSON = try? Saved.JSONString() else
            {
                continue
            }
            Found.append(Entry(id: StableID(File), Pipeline: Saved, URL: File, JSON: JSON))
        }
        return Found.sorted{$0.Pipeline.Name.localizedStandardCompare($1.Pipeline.Name) == .orderedAscending}
    }

    private func StableID(_ Location: URL) -> UUID
    {
        let Key = Location.resolvingSymlinksInPath().path
        if let Known = StableIDs[Key]
        {
            return Known
        }
        let New = UUID()
        StableIDs[Key] = New
        return New
    }

    /// Every pipeline in every folder.
    var AllEntries: [Entry]
    {
        Folders.flatMap{$0.Entries}
    }

    // MARK: Other folders

    /// Adds a folder to the ones the library reads, and remembers it for the next launch.
    /// - Parameter Directory: The folder, as chosen by the user.
    func AddDirectory(_ Directory: URL)
    {
        let Path = Directory.resolvingSymlinksInPath().path
        guard Path != DefaultDirectory.resolvingSymlinksInPath().path,
              !OtherDirectories.contains(where: {$0.resolvingSymlinksInPath().path == Path}) else
        {
            return
        }
        _ = Directory.startAccessingSecurityScopedResource()
        OtherDirectories.append(Directory)
        SaveBookmarks()
        Reload()
    }

    /// Stops reading a folder. The files in it are left alone.
    /// - Parameter ID: The `id` of the folder.
    func RemoveDirectory(_ ID: UUID)
    {
        guard let Gone = Folders.first(where: {$0.id == ID && !$0.IsDefault}) else
        {
            return
        }
        Gone.URL.stopAccessingSecurityScopedResource()
        OtherDirectories.removeAll{$0.resolvingSymlinksInPath().path == Gone.URL.resolvingSymlinksInPath().path}
        SaveBookmarks()
        Reload()
    }

    #if os(macOS)
    private static let BookmarkCreation = URL.BookmarkCreationOptions.withSecurityScope
    private static let BookmarkResolution = URL.BookmarkResolutionOptions.withSecurityScope
    #else
    private static let BookmarkCreation = URL.BookmarkCreationOptions()
    private static let BookmarkResolution = URL.BookmarkResolutionOptions()
    #endif

    private func SaveBookmarks()
    {
        var Marks = [Data]()
        for Directory in OtherDirectories
        {
            do
            {
                Marks.append(try Directory.bookmarkData(options: PipelineLibrary.BookmarkCreation, includingResourceValuesForKeys: nil,
                                                        relativeTo: nil))
            }
            catch
            {
                print("Cannot remember the folder \(Directory.path): \(error)")
            }
        }
        Defaults.set(Marks, forKey: PipelineLibrary.BookmarksKey)
    }

    /// Opens the folders remembered from the last launch. A folder that is gone or no longer allowed is forgotten.
    private func ResolveBookmarks() -> [URL]
    {
        var Found = [URL]()
        var Changed = false
        for Mark in Defaults.array(forKey: PipelineLibrary.BookmarksKey) as? [Data] ?? []
        {
            var IsStale = false
            guard let Directory = try? URL(resolvingBookmarkData: Mark, options: PipelineLibrary.BookmarkResolution, relativeTo: nil,
                                           bookmarkDataIsStale: &IsStale) else
            {
                Changed = true
                continue
            }
            _ = Directory.startAccessingSecurityScopedResource()
            Found.append(Directory)
            Changed = Changed || IsStale
        }
        if Changed
        {
            OtherDirectories = Found
            SaveBookmarks()
        }
        return Found
    }

    // MARK: Saving

    /// Why a name cannot be used, or `nil` if it is fine. Names are file names, so they have to be usable as one.
    /// - Parameter Name: The name.
    static func ProblemWithName(_ Name: String) -> String?
    {
        let Trimmed = Name.trimmingCharacters(in: .whitespacesAndNewlines)
        if Trimmed.isEmpty
        {
            return "Enter a name for the pipeline."
        }
        if Trimmed.count > 80
        {
            return "The name is too long."
        }
        if Trimmed.contains(where: {"/:\\".contains($0)}) || Trimmed.hasPrefix(".")
        {
            return "A name cannot contain / : or \\ and cannot start with a period."
        }
        return nil
    }

    /// Why a pipeline cannot be saved with this name in this folder, or `nil` if it can. Names are unique: no other pipeline the
    /// library knows about, and no file in the folder, may have the name.
    /// - Parameter Name: The name.
    /// - Parameter Directory: The folder it will be saved in. `nil` for the default folder.
    /// - Parameter Replacing: The file the pipeline was loaded from or saved to before. Saving over that file is allowed.
    func Problem(forName Name: String, Directory: URL? = nil, Replacing: URL? = nil) -> String?
    {
        if let Bad = PipelineLibrary.ProblemWithName(Name)
        {
            return Bad
        }
        let Wanted = Name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let Target = Directory ?? DefaultDirectory
        let Own = Replacing.flatMap
        {
            $0.deletingLastPathComponent().resolvingSymlinksInPath().path == Target.resolvingSymlinksInPath().path ? $0 : nil
        }
        let OwnPath = Own?.resolvingSymlinksInPath().path
        if AllEntries.contains(where: {$0.Pipeline.Name.lowercased() == Wanted && $0.URL.resolvingSymlinksInPath().path != OwnPath})
        {
            return "A pipeline named “\(Name)” already exists."
        }
        let File = Target.appending(path: FileName(for: Name))
        if FileManager.default.fileExists(atPath: File.path),
           File.resolvingSymlinksInPath().path != OwnPath
        {
            return "The folder already has a file for a pipeline named “\(Name)”."
        }
        return nil
    }

    /// The file name for a pipeline.
    func FileName(for Name: String) -> String
    {
        "\(Name.trimmingCharacters(in: .whitespacesAndNewlines)).\(SavedPipeline.FileExtension)"
    }

    /// Writes a pipeline to a file and reads the library again.
    /// - Parameter Saved: The pipeline. Its name is the name it is saved under.
    /// - Parameter Directory: The folder to save in. `nil` for the default folder, which is made if it is not there.
    /// - Parameter Replacing: The file the pipeline was loaded from or saved to before, which may be written over.
    /// - Returns: The file that was written.
    /// - Throws: `FilterException` if the name cannot be used or the file cannot be written.
    @discardableResult
    func Save(_ Saved: SavedPipeline, Directory: URL? = nil, Replacing: URL? = nil) throws -> URL
    {
        if let Bad = Problem(forName: Saved.Name, Directory: Directory, Replacing: Replacing)
        {
            throw FilterException(Message: Bad)
        }
        let Target = Directory ?? DefaultDirectory
        let Opened = Target.startAccessingSecurityScopedResource()
        defer
        {
            if Opened
            {
                Target.stopAccessingSecurityScopedResource()
            }
        }
        let File = Target.appending(path: FileName(for: Saved.Name))
        do
        {
            try FileManager.default.createDirectory(at: Target, withIntermediateDirectories: true)
            try Saved.FileData().write(to: File, options: .atomic)
        }
        catch let Failure as FilterException
        {
            throw Failure
        }
        catch
        {
            throw FilterException(Message: "Cannot save the pipeline: \(error.localizedDescription)")
        }
        Reload()
        return File
    }

    // MARK: The filter tree

    /// The "Saved Pipelines" branch of the filter tree: the pipelines in the default folder, then a group for each other folder.
    var BranchNode: FilterNode
    {
        var Children = [FilterNode]()
        for Folder in Folders where Folder.IsDefault
        {
            Children.append(contentsOf: Folder.Entries.map(Node))
        }
        for Folder in Folders where !Folder.IsDefault
        {
            Children.append(FilterNode(NodeID: Folder.id, Name: Folder.URL.lastPathComponent, Filter: nil, Options: nil,
                                       Parameters: nil, Children: Folder.Entries.map(Node)))
        }
        return FilterNode(NodeID: BranchID, Name: "Saved Pipelines", Filter: nil, Options: nil, Parameters: nil, Children: Children)
    }

    /// The leaf that runs a saved pipeline.
    private func Node(_ Found: Entry) -> FilterNode
    {
        FilterNode(NodeID: Found.id, Name: Found.Pipeline.Name, Filter: SavedPipelineFilter.FilterName,
                   Options: [SavedPipelineFilter.OptionKey: Found.JSON], Parameters: nil, Children: nil)
    }

    /// The pipeline a tree node stands for. `nil` if the node is not a saved pipeline.
    func EntryFor(Node ID: UUID) -> Entry?
    {
        AllEntries.first{$0.id == ID}
    }

    /// The folder a tree node stands for. `nil` if the node is not a folder.
    func FolderFor(Node ID: UUID) -> Folder?
    {
        Folders.first{$0.id == ID}
    }
}
