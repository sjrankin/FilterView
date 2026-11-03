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
                .foregroundStyle(.white)
                .background { ImageBackgroundView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black, ignoresSafeAreaEdges: [])
        .task(id: TaskKey(Selection: Selection, SourceID: SourceID))
        {
            let Current = SourceID
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

/// Identifies one filtering job: re-run when either the filter or the source image changes.
private struct TaskKey: Hashable
{
    let Selection: FilterSelection?
    let SourceID: UUID
}

#Preview
{
    ImageView(DisplayImage: Image("Hana"), Server: FilterServer())
}
