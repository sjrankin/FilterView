//
//  SplitRenderer.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/4/26.
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

import CoreGraphics

/// Filters an image region by region.
enum SplitRenderer
{
    /// Runs each region's filter on the whole image and puts each result's part in its region.
    ///
    /// Each filter sees the whole picture and not just its region, so a filter that looks at neighbouring pixels (blur, edges) gives the same
    /// result at the dividing line as it would everywhere else.
    /// - Parameter Source: The image.
    /// - Parameter Setup: The regions and their filters.
    /// - Parameter Server: Runs the filters.
    /// - Throws: Any error from a filter, or `FilterException` if the pieces cannot be put together.
    static func Render(_ Source: CGImage, Setup: SplitSetup, Server: FilterServer) async throws -> CGImage
    {
        guard Setup.HasFilters else
        {
            return Source
        }
        var Results = [CGImage?]()
        // Regions with the same filter and options share one run.
        var Done = [FilterSelection: CGImage]()
        for Selection in Setup.Selections
        {
            guard let Selection = Selection else
            {
                Results.append(nil)
                continue
            }
            if let Same = Done[Selection]
            {
                Results.append(Same)
                continue
            }
            let Made = try await Server.Run(Filter: Selection.Filter, With: Source, Selection.Options)
            Done[Selection] = Made
            Results.append(Made)
        }
        guard let Combined = await SplitCompositor.ComposeAsync(Background: Source, Layout: Setup.Layout, Regions: Results) else
        {
            throw FilterException(Message: "Cannot combine the regions")
        }
        return Combined
    }

    /// The transform for a setup, in the form batch mode and the other callers use. `nil` if no region has a filter.
    static func Transform(Server: FilterServer?, Setup: SplitSetup?) -> BatchModel.Transform?
    {
        guard let Server = Server,
              let Setup = Setup,
              Setup.HasFilters else
        {
            return nil
        }
        return
        {
            Image in
            try await Render(Image, Setup: Setup, Server: Server)
        }
    }
}
