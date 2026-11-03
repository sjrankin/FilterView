//
//  TestSupport.swift
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

import Foundation
import CoreGraphics
@testable import FilterView

/// Helpers the saved pipeline tests share.
enum TestSupport
{
    /// A small solid image.
    static func MakeImage(Width: Int = 4, Height: Int = 4) -> CGImage
    {
        let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        Context.fill(CGRect(x: 0, y: 0, width: Width, height: Height))
        return Context.makeImage()!
    }

    /// A new empty folder in the temporary directory.
    static func MakeFolder() throws -> URL
    {
        let Folder = FileManager.default.temporaryDirectory.appending(path: "FilterViewTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: Folder, withIntermediateDirectories: true)
        return Folder
    }

    /// A library that uses its own folder and its own defaults, so tests do not touch the user's pipelines.
    static func MakeLibrary(Folder: URL? = nil, SuiteName: String = UUID().uuidString) throws -> (Library: PipelineLibrary, Folder: URL, Defaults: UserDefaults)
    {
        let Directory = try Folder ?? MakeFolder()
        let Defaults = UserDefaults(suiteName: SuiteName) ?? .standard
        return (PipelineLibrary(DefaultDirectory: Directory, Defaults: Defaults), Directory, Defaults)
    }

    /// A filter selection with options and one editable parameter.
    static func MakeSelection(_ Filter: String = "Tag", Amount: String = "1") -> FilterSelection
    {
        let Parameter = FilterParameter(Key: "AMOUNT", Title: "Amount", Kind: .Slider, Default: "1", Min: 0, Max: 10, Step: 1,
                                        Choices: nil)
        return FilterSelection(Filter: Filter, Options: ["AMOUNT": Amount, "MODE": "A"], DisplayName: "Tag \(Amount)",
                               Parameters: [Parameter])
    }

    /// A saved pipeline of one filter stage.
    static func MakePipeline(_ Name: String, Nested: SavedPipeline? = nil) -> SavedPipeline
    {
        var Stage = SavedStage(ID: 1, Kind: .Filter, Input: 0, Under: false, Skipped: false)
        if let Nested = Nested
        {
            Stage.Filter = SavedPipelineFilter.FilterName
            Stage.DisplayName = Nested.Name
            Stage.Nested = Nested
        }
        else
        {
            Stage.Filter = "Tag"
            Stage.DisplayName = "Tag"
            Stage.Options = ["AMOUNT": "3"]
        }
        return SavedPipeline(Name: Name, Stages: [Stage], FinalStage: 1)
    }
}

/// Remembers the options of every call, in order, and passes the image through.
final class RecordingFilter: ImageFilter
{
    static let FilterName = "Tag"
    var FilterType: ImageFilterTypes
    {
        .Infrastructure
    }
    nonisolated(unsafe) var Calls = [[String: String]]()

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        Calls.append((Options ?? [:]).compactMapValues{$0 as? String})
        return Input
    }
}
