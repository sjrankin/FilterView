//
//  PipelineModel+Making.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

import SwiftUI
import CoreGraphics

extension PipelineModel
{
    // MARK: Making the images

    /// Starts making the images of the dirty stages, unless that is already going on.
    func Kick()
    {
        Task
        {
            await Drain()
        }
    }

    /// Makes the images of the dirty stages and everything after them, each from the image or images before it. Changes that
    /// come in meanwhile are picked up in another round; only one run is ever going.
    func Drain() async
    {
        guard !IsComputing else
        {
            return
        }
        IsComputing = true
        defer
        {
            IsComputing = false
        }
        while !Dirty.isEmpty
        {
            let Batch = WithDescendants(Dirty)
            Dirty.removeAll()
            for ID in Topological() where Batch.contains(ID)
            {
                await Compute(ID)
            }
        }
    }

    /// Makes one stage's image.
    func Compute(_ ID: Int) async
    {
        guard let Current = StageFor(ID),
              Current.Kind != .Original,
              let Incoming = OutputOf(Current.Input) else
        {
            return
        }
        var Made = Incoming
        var DidFail = false
        switch Current.Kind
        {
            case .Filter:
                if !Current.Skipped,
                   let Selection = Current.Selection,
                   let Server = Server
                {
                    do
                    {
                        Made = try await Server.Run(Filter: Selection.Filter, With: Incoming, Selection.Options)
                    }
                    catch
                    {
                        DidFail = true
                        #if DEBUG
                        print("Pipeline filter \(Selection.Filter) failed: \(error)")
                        #endif
                    }
                }

            case .Merge:
                if !Current.Skipped,
                   let Other = OutputOf(Current.Second)
                {
                    if let Merged = PipelineMerger.Merge(Background: Incoming, Foreground: Other, Mode: Current.MergeMode,
                                                         Amount: Current.MergeAmount)
                    {
                        Made = Merged
                    }
                    else
                    {
                        DidFail = true
                    }
                }

            case .Original:
                break
        }
        // The stage may have been deleted while the filter ran.
        if let Where = Stages.firstIndex(where: {$0.id == ID})
        {
            Stages[Where].Output = Made
            Stages[Where].Failed = DidFail
        }
    }
}
