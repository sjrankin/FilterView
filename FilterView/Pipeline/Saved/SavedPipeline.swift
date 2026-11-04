//
//  SavedPipeline.swift
//  FilterView
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

/// A pipeline as it is saved to disk and as it runs when used as a filter.
///
/// It holds the filter of every stage with all the options the user set for that stage, and how the stages are joined. Another saved
/// pipeline used as a stage is held inside it in full (`SavedStage.Nested`), so a saved pipeline is complete in itself and can never
/// lead back to itself through a loop. Nesting can go as deep as the user likes.
struct SavedPipeline: Codable, Hashable, Sendable
{
    /// The file extension of a saved pipeline.
    static let FileExtension = "fvpipeline"

    /// Bumped when the layout of the file changes in a way old versions cannot read.
    static let CurrentVersion = 1

    var Version = SavedPipeline.CurrentVersion

    /// The name the user gave the pipeline. It is unique among the pipelines the app knows about.
    var Name: String

    /// Every stage but the original image (stage 0), which is whatever image the pipeline is run on.
    var Stages: [SavedStage]

    /// The stage whose image is the result of the pipeline. 0 if there are no stages, which makes the result the original image.
    var FinalStage: Int

    /// The name of this pipeline and of every pipeline nested in it, at any depth.
    var AllNames: [String]
    {
        [Name] + Stages.flatMap{$0.Nested?.AllNames ?? []}
    }

    /// True if this pipeline is, or holds at any depth, a pipeline with this name. Case does not matter, as names are also file names.
    /// - Parameter Target: The name to look for.
    func Contains(Named Target: String) -> Bool
    {
        let Wanted = Target.lowercased()
        return AllNames.contains{$0.lowercased() == Wanted}
    }

    /// The pipeline as JSON text. Keys are sorted so the same pipeline always gives the same text.
    /// - Throws: `FilterException` if it cannot be encoded.
    func JSONString() throws -> String
    {
        let Encoder = JSONEncoder()
        Encoder.outputFormatting = [.sortedKeys]
        do
        {
            return String(decoding: try Encoder.encode(self), as: UTF8.self)
        }
        catch
        {
            throw FilterException(Message: "Cannot encode pipeline \(Name): \(error)")
        }
    }

    /// The pipeline as the data written to a file: readable JSON.
    /// - Throws: `FilterException` if it cannot be encoded.
    func FileData() throws -> Data
    {
        let Encoder = JSONEncoder()
        Encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do
        {
            return try Encoder.encode(self)
        }
        catch
        {
            throw FilterException(Message: "Cannot encode pipeline \(Name): \(error)")
        }
    }

    /// Reads a pipeline from JSON data.
    /// - Parameter Raw: The data.
    /// - Returns: The pipeline, or `nil` if the data is not a pipeline this version understands.
    static func Decode(Data Raw: Data) -> SavedPipeline?
    {
        guard let Found = try? JSONDecoder().decode(SavedPipeline.self, from: Raw),
              Found.Version <= CurrentVersion else
        {
            return nil
        }
        return Found
    }

    /// Reads a pipeline from JSON text.
    /// - Parameter JSON: The text.
    /// - Returns: The pipeline, or `nil` if the text is not a pipeline this version understands.
    static func Decode(JSON: String) -> SavedPipeline?
    {
        Decode(Data: Data(JSON.utf8))
    }
}

/// One saved stage of a pipeline.
struct SavedStage: Codable, Hashable, Sendable
{
    enum Kinds: String, Codable, Sendable
    {
        /// Runs a filter, or another pipeline. With neither it passes its image through.
        case Filter
        /// Combines two images.
        case Merge
        /// Divides the image into regions (`Layout`). It passes its image on; the regions' lines of stages start under it.
        case Split
        /// Puts the last stage of each region's line (`Regions`) in the region's place in the picture.
        case Join
    }

    /// The number of the stage, as the other stages refer to it.
    var ID: Int
    var Kind: Kinds
    /// The stage whose image this one takes. For a merge, the background.
    var Input: Int
    /// A merge's second image.
    var Second: Int?
    /// True for a stage made by Diverge, which is drawn under the stage it takes its image from.
    var Under: Bool
    /// True if the stage does nothing.
    var Skipped: Bool

    /// The name of the filter to run, as registered in `FilterServer`.
    var Filter: String?
    /// The label of the tree entry the filter came from. The name of the pipeline for a nested pipeline.
    var DisplayName: String?
    /// Every option of the filter, as the user set them.
    var Options: [String: String]?
    /// Describes the options the user can change, so they can be edited again.
    var Parameters: [FilterParameter]?
    /// Another pipeline run as this stage's filter.
    var Nested: SavedPipeline?

    /// How a split or join divides the image, as `SplitLayouts.rawValue`.
    var Layout: String?
    /// A join's inputs: the last stage of each region's line, in region order.
    var Regions: [Int]?

    /// A merge's mode, as `MergeModes.rawValue`.
    var MergeMode: String?
    var MergeAmount: Double?
}
