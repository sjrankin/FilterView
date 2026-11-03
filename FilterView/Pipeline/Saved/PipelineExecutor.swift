//
//  PipelineExecutor.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
//

import Foundation
import CoreGraphics

/// Runs a saved pipeline on an image without any of the window's state. This is how a saved pipeline works as a filter.
enum PipelineExecutor
{
    /// Runs every stage of a pipeline in order and returns the final image.
    ///
    /// Like the Pipeline window, a stage that cannot run (a filter that is not known or fails, a merge that fails) passes the image it
    /// took on unchanged.
    /// - Parameter Saved: The pipeline.
    /// - Parameter Input: The original image, which is stage 0.
    /// - Parameter Filters: The filters stages can run, by name.
    /// - Returns: The image after the final stage.
    /// - Throws: `CancellationError` if the task is cancelled.
    static func Run(_ Saved: SavedPipeline, Input: CGImage, Filters: [String: ImageFilter]) async throws -> CGImage
    {
        let ByID = Dictionary(Saved.Stages.map{($0.ID, $0)}, uniquingKeysWith: {First, _ in First})
        var Outputs: [Int: CGImage] = [0: Input]
        for ID in Order(Saved)
        {
            try Task.checkCancellation()
            guard let Current = ByID[ID] else
            {
                continue
            }
            let Incoming = Outputs[Current.Input] ?? Input
            var Made = Incoming
            if !Current.Skipped
            {
                switch Current.Kind
                {
                    case .Filter:
                        if let Nested = Current.Nested
                        {
                            Made = try await Run(Nested, Input: Incoming, Filters: Filters)
                        }
                        else if let Name = Current.Filter,
                                let Found = Filters[Name]
                        {
                            do
                            {
                                Made = try await Found.ProcessImage(Incoming, Current.Options)
                            }
                            catch is CancellationError
                            {
                                throw CancellationError()
                            }
                            catch
                            {
                                #if DEBUG
                                print("Pipeline \(Saved.Name): filter \(Name) failed in stage \(ID): \(error)")
                                #endif
                            }
                        }

                    case .Merge:
                        if let Second = Current.Second,
                           let Other = Outputs[Second],
                           let Merged = PipelineMerger.Merge(Background: Incoming, Foreground: Other,
                                                             Mode: MergeModes(rawValue: Current.MergeMode ?? "") ?? .Multiply,
                                                             Amount: Current.MergeAmount ?? 1.0)
                        {
                            Made = Merged
                        }
                }
            }
            Outputs[ID] = Made
        }
        return Outputs[Saved.FinalStage] ?? Input
    }

    /// The stage numbers in an order where every stage comes after the ones it takes images from. A file that has a loop in it
    /// (which the app never writes) still gives a finite order.
    /// - Parameter Saved: The pipeline.
    static func Order(_ Saved: SavedPipeline) -> [Int]
    {
        let ByID = Dictionary(Saved.Stages.map{($0.ID, $0)}, uniquingKeysWith: {First, _ in First})
        var Result = [Int]()
        var Seen = Set<Int>()
        func Visit(_ ID: Int)
        {
            guard !Seen.contains(ID),
                  let Found = ByID[ID] else
            {
                return
            }
            Seen.insert(ID)
            Visit(Found.Input)
            if let Second = Found.Second
            {
                Visit(Second)
            }
            Result.append(ID)
        }
        for Found in Saved.Stages.sorted(by: {$0.ID < $1.ID})
        {
            Visit(Found.ID)
        }
        return Result
    }
}
