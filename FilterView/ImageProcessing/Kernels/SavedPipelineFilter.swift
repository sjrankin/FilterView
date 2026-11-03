//
//  SavedPipelineFilter.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
//

import Foundation
import CoreGraphics

/// Runs a saved pipeline as if it were one filter. The pipeline travels in the options as JSON, under `OptionKey`, so a saved pipeline
/// can be selected in the main window, used on live video, and set as a stage of another pipeline like any other filter.
class SavedPipelineFilter: ImageFilter
{
    static let FilterName = "Saved Pipeline"

    /// The option holding the pipeline, as JSON text.
    static let OptionKey = "PIPELINE"

    /// The server whose filters the pipeline's stages run. Set by the server when it registers this filter.
    weak var Server: FilterServer? = nil

    /// The pipeline decoded last. Live video runs the same pipeline on every frame, so it is decoded once.
    private var Cached: (JSON: String, Pipeline: SavedPipeline)? = nil

    var FilterType: ImageFilterTypes
    {
        .Infrastructure
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        guard let JSON = Options?[SavedPipelineFilter.OptionKey] as? String else
        {
            throw FilterException(Message: "Saved Pipeline was given no pipeline.")
        }
        let Saved: SavedPipeline
        if let Cached = Cached,
           Cached.JSON == JSON
        {
            Saved = Cached.Pipeline
        }
        else
        {
            guard let Decoded = SavedPipeline.Decode(JSON: JSON) else
            {
                throw FilterException(Message: "Saved Pipeline cannot read its pipeline.")
            }
            Cached = (JSON, Decoded)
            Saved = Decoded
        }
        guard let Filters = Server?.BuiltInFilters else
        {
            throw FilterException(Message: "Saved Pipeline has no filter server.")
        }
        return try await PipelineExecutor.Run(Saved, Input: Input, Filters: Filters)
    }
}
