//
//  PipelineModel.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

import SwiftUI
import CoreGraphics

/// A graph of filters run on an image (or on every frame of live video), keeping the image after each one.
///
/// Stage 0 is the original image. Every other stage takes one image (or, for a merge, two) from earlier stages. Most of the time
/// the stages are one line, each taking the one before; `Diverge` hangs a new line under a stage and `Merge` joins one line into
/// another. A stage can never depend on a stage that depends on it, so the graph has no loops.
/// The model only holds the stages; the Pipeline window (macOS) shows them.
@Observable @MainActor
final class PipelineModel
{
    /// True while the Pipeline window is open. Set by the window. `Add` does nothing when it is false.
    var IsOpen = false
    /// The filter chosen in the main window. "Use Selected Filter" puts it on a stage. Kept up to date by the main UI.
    var SelectedFilter: FilterSelection? = nil
    /// Runs the filters. Set by the main UI.
    @ObservationIgnored var Server: FilterServer? = nil
    /// Called with the final image when the user sends it back to be the main image. Set by the main UI.
    @ObservationIgnored var UseAsSource: ((CGImage) -> Void)? = nil
    /// The main image that came from this pipeline's own final image. The pipeline keeps its original image and filters instead of
    /// starting over from it. Cleared when the pipeline is reset.
    @ObservationIgnored var IgnoredSourceID: UUID? = nil
    /// The stages. Changed by this model's own extensions only.
    var Stages = [Stage(id: 0, Kind: .Original)]
    var NextID = 1
    /// Stages whose images must be made again (with everything after them).
    var Dirty = Set<Int>()
    var IsComputing = false
    /// The name of the saved pipeline being edited. `nil` for a pipeline that has not been saved or loaded.
    var CurrentName: String? = nil
    /// The file the pipeline was loaded from or last saved to. Saving over it is allowed; saving over any other file is not.
    var CurrentURL: URL? = nil
    /// Something the user needs to be told, such as why a pipeline could not be added. Shown in the main window.
    var Problem: String? = nil
}
