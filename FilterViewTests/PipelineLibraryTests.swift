//
//  PipelineLibraryTests.swift
//  FilterViewTests
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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

import Testing
import Foundation
@testable import FilterView

struct PipelineLibraryTests
{
    @Test func SavesInTheDefaultFolderAndListsIt() throws
    {
        let Made = try TestSupport.MakeLibrary()
        let File = try Made.Library.Save(TestSupport.MakePipeline("Sepia Look"))
        #expect(File.deletingLastPathComponent().lastPathComponent == Made.Folder.lastPathComponent)
        #expect(File.pathExtension == SavedPipeline.FileExtension)
        #expect(Made.Library.Folders[0].IsDefault)
        #expect(Made.Library.Folders[0].Entries.map{$0.Pipeline.Name} == ["Sepia Look"])
        let Branch = Made.Library.BranchNode
        #expect(Branch.Name == "Saved Pipelines")
        #expect(Branch.Children?.first?.Filter == SavedPipelineFilter.FilterName)
        #expect(Branch.Children?.first?.Options?[SavedPipelineFilter.OptionKey] != nil)
    }

    @Test func CreatesTheDefaultFolderWhenMissing() throws
    {
        let Missing = try TestSupport.MakeFolder().appending(path: "FilterView/Pipelines", directoryHint: .isDirectory)
        let Made = try TestSupport.MakeLibrary(Folder: Missing)
        try Made.Library.Save(TestSupport.MakePipeline("First"))
        #expect(FileManager.default.fileExists(atPath: Missing.path))
    }

    @Test func NamesAreUniqueIgnoringCase() throws
    {
        let Made = try TestSupport.MakeLibrary()
        try Made.Library.Save(TestSupport.MakePipeline("Blur Then Edge"))
        #expect(Made.Library.Problem(forName: "blur then edge") != nil)
        #expect(throws: FilterException.self)
        {
            try Made.Library.Save(TestSupport.MakePipeline("BLUR THEN EDGE"))
        }
        #expect(Made.Library.Problem(forName: "Another") == nil)
    }

    @Test func ASavedPipelineCanBeSavedOverItself() throws
    {
        let Made = try TestSupport.MakeLibrary()
        let File = try Made.Library.Save(TestSupport.MakePipeline("Mine"))
        var Changed = TestSupport.MakePipeline("Mine")
        Changed.Stages[0].Options = ["AMOUNT": "9"]
        try Made.Library.Save(Changed, Replacing: File)
        #expect(Made.Library.AllEntries.count == 1)
        #expect(Made.Library.AllEntries[0].Pipeline.Stages[0].Options?["AMOUNT"] == "9")
    }

    @Test func RejectsNamesThatCannotBeFileNames() throws
    {
        for Bad in ["", "   ", "a/b", "a:b", ".hidden", String(repeating: "x", count: 81)]
        {
            #expect(PipelineLibrary.ProblemWithName(Bad) != nil, "\(Bad)")
        }
        #expect(PipelineLibrary.ProblemWithName("Night Vision 2") == nil)
    }

    @Test func SavesElsewhereWithoutListingItInTheTree() throws
    {
        let Made = try TestSupport.MakeLibrary()
        let Elsewhere = try TestSupport.MakeFolder()
        try Made.Library.Save(TestSupport.MakePipeline("Far Away"), Directory: Elsewhere)
        #expect(FileManager.default.fileExists(atPath: Elsewhere.appending(path: "Far Away.fvpipeline").path))
        #expect(Made.Library.AllEntries.isEmpty)
        // The name is also taken in that folder.
        #expect(Made.Library.Problem(forName: "Far Away", Directory: Elsewhere) != nil)
    }

    @Test func ALoadedFolderIsRememberedAcrossInstances() throws
    {
        let Suite = UUID().uuidString
        let Made = try TestSupport.MakeLibrary(SuiteName: Suite)
        let Other = try TestSupport.MakeFolder()
        try Made.Library.Save(TestSupport.MakePipeline("Elsewhere One"), Directory: Other)
        Made.Library.AddDirectory(Other)
        #expect(Made.Library.AllEntries.map{$0.Pipeline.Name} == ["Elsewhere One"])
        // A name used in a loaded folder cannot be used in the default folder.
        #expect(Made.Library.Problem(forName: "elsewhere one") != nil)

        let Again = PipelineLibrary(DefaultDirectory: Made.Folder, Defaults: Made.Defaults)
        #expect(Again.Folders.count == 2)
        #expect(Again.AllEntries.map{$0.Pipeline.Name} == ["Elsewhere One"])

        let Group = try #require(Again.Folders.last)
        Again.RemoveDirectory(Group.id)
        #expect(Again.Folders.count == 1)
        #expect(PipelineLibrary(DefaultDirectory: Made.Folder, Defaults: Made.Defaults).Folders.count == 1)
    }

    @Test func SelectionOfATreeNodeSurvivesReloading() throws
    {
        let Made = try TestSupport.MakeLibrary()
        try Made.Library.Save(TestSupport.MakePipeline("Stable"))
        let Before = try #require(Made.Library.BranchNode.Children?.first?.id)
        Made.Library.Reload()
        #expect(Made.Library.BranchNode.Children?.first?.id == Before)
        #expect(Made.Library.EntryFor(Node: Before)?.Pipeline.Name == "Stable")
    }
}
