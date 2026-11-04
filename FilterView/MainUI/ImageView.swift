//
//  ImageView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
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

struct ImageView: View
{
    /// The image to filter. A plain property (not `@State`) so a new image from the parent replaces it.
    var DisplayImage: Image
    var Server: FilterServer? = nil
    var Selection: FilterSelection? = nil
    /// The regions and their filters, when the image is divided. Used instead of `Selection`.
    var Split: SplitSetup? = nil
    /// Called with the region the user taps while the image is divided.
    var OnSelectRegion: ((Int) -> Void)? = nil
    /// Changes whenever the parent supplies a different image, which restarts the filter task.
    var SourceID = UUID()
    /// Called with how long the filter took to produce the image (from the call to the finished image), or `nil` if there is no
    /// filter or it failed.
    var OnRendered: ((Duration?) -> Void)? = nil
    @State private var FilteredImage: Image?
    /// The `SourceID` that `FilteredImage` was made from. A result for an older image is never shown.
    @State private var FilteredFor: UUID?

    var body: some View
    {
        VStack
        {
            ((FilteredFor == SourceID ? FilteredImage : nil) ?? DisplayImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay
                {
                    // The overlay is the size of the picture, so its lines are exactly where the regions are.
                    if let Split = Split
                    {
                        SplitRegionOverlay(Setup: Split)
                        {
                            OnSelectRegion?($0)
                        }
                    }
                }
                .foregroundStyle(.white)
                .background { ImageBackgroundView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black, ignoresSafeAreaEdges: [])
        .task(id: TaskKey(Selection: Selection, Split: Split, SourceID: SourceID))
        {
            let Current = SourceID
            if let Split = Split
            {
                await RenderSplit(Split, For: Current)
                return
            }
            guard let Selection = Selection else
            {
                FilteredImage = nil
                OnRendered?(nil)
                return
            }
            let StartTime = ContinuousClock.now
            do
            {
                let Result = try await DisplayImage.Filtered(Filter: Selection.Filter,
                                                             Server: Server,
                                                             Options: Selection.Options)
                if !Task.isCancelled
                {
                    FilteredImage = Result
                    FilteredFor = Current
                    let Elapsed = ContinuousClock.now - StartTime
                    OnRendered?(Elapsed)
                    #if DEBUG
                    print("Filter \(Selection.Filter): \(Elapsed) from call to display")
                    #endif
                }
            }
            catch
            {
                FilteredImage = nil
                OnRendered?(nil)
                #if DEBUG
                print("Filter \(Selection.Filter): failed after \(ContinuousClock.now - StartTime) (\(error))")
                #endif
            }
        }
    }
}

extension ImageView
{
    /// Filters the image region by region and shows the result.
    /// - Parameter Setup: The regions and their filters.
    /// - Parameter Current: The `SourceID` the image belongs to.
    @MainActor fileprivate func RenderSplit(_ Setup: SplitSetup, For Current: UUID) async
    {
        guard Setup.HasFilters,
              let Server = Server,
              let Source = ImageUtility.ImageToCGImage(DisplayImage) else
        {
            FilteredImage = nil
            OnRendered?(nil)
            return
        }
        let StartTime = ContinuousClock.now
        do
        {
            let Result = try await SplitRenderer.Render(Source, Setup: Setup, Server: Server)
            if !Task.isCancelled
            {
                FilteredImage = ImageUtility.CGImageToImage(Result)
                FilteredFor = Current
                OnRendered?(ContinuousClock.now - StartTime)
            }
        }
        catch
        {
            FilteredImage = nil
            OnRendered?(nil)
            #if DEBUG
            print("Split filters failed: \(error)")
            #endif
        }
    }
}

/// Identifies one filtering job: re-run when either the filter or the source image changes.
private struct TaskKey: Hashable
{
    let Selection: FilterSelection?
    let Split: SplitSetup?
    let SourceID: UUID
}

#Preview
{
    ImageView(DisplayImage: Image("Hana"), Server: FilterServer())
}
