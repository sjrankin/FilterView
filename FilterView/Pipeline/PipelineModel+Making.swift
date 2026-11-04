//
//  PipelineModel+Making.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
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
                    // An overlay such as the sunbeams is made on a canvas the size of the stage it is merged onto.
                    var Foreground = Other
                    if let Source = StageFor(Current.Second),
                       Source.Kind == .Filter,
                       !Source.Skipped,
                       let Selection = Source.Selection
                    {
                        Foreground = await PipelineCanvas.Foreground(Generator: Server?.GetFilter(Selection.Filter),
                                                                     Options: Selection.Options, Made: Other, Background: Incoming)
                    }
                    if let Merged = PipelineMerger.Merge(Background: Incoming, Foreground: Foreground, Mode: Current.MergeMode,
                                                         Amount: Current.MergeAmount)
                    {
                        Made = Merged
                    }
                    else
                    {
                        DidFail = true
                    }
                }

            case .Split:
                // The regions' lines start from this image; the split itself changes nothing.
                break

            case .Join:
                if !Current.Skipped,
                   let Layout = Current.Layout
                {
                    if let Combined = await SplitCompositor.ComposeAsync(Background: Incoming, Layout: Layout,
                                                                         Regions: Current.Regions.map{OutputOf($0)})
                    {
                        Made = Combined
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
