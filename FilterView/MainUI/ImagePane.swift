//
//  ImagePane.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/31/26.
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

/// The image area. Shows the live camera frame while the input is Video; otherwise shows the source image with the
/// selected filter applied, and (on macOS) accepts an image file dropped on it.
struct ImagePane: View
{
    var InputSource: ImageInputSources
    /// The newest live video frame, already filtered. `nil` until the first frame arrives.
    var LiveImage: Image?
    var SourceImage: Image
    var Server: FilterServer?
    var Selection: FilterSelection?
    /// Changes whenever there is a different source image, which makes the image view filter again.
    var SourceID: UUID
    /// Called with how long the filter took to render the image, or `nil` if there was no filter or it failed.
    var OnRendered: (Duration?) -> Void
    /// Called when an image file is dropped on the image (macOS only), with the file and its loaded image.
    var OnDropped: (URL, CGImage) -> Void
    @State private var IsDropTargeted = false

    var body: some View
    {
        Group
        {
            if InputSource == .Video
            {
                // Live video. Frames are filtered as they arrive (see `RunLiveVideo`), so this just shows them.
                (LiveImage ?? Image(systemName: "video"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white)
                    // Filters can make pixels transparent. As with a still image, the background chosen in the settings shows through
                    // them. The placeholder symbol is drawn on plain black.
                    .background
                    {
                        if LiveImage != nil
                        {
                            ImageBackgroundView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
            }
            else
            {
                ImageView(DisplayImage: SourceImage,
                          Server: Server,
                          Selection: Selection,
                          SourceID: SourceID,
                          OnRendered: OnRendered)
                #if os(macOS)
                .dropDestination(for: URL.self)
                {
                    URLs, _ in
                    guard let FirstImage = URLs.first,
                          let Dropped = ImageUtility.LoadImage(from: FirstImage) else
                    {
                        return false
                    }
                    OnDropped(FirstImage, Dropped)
                    return true
                }
                isTargeted:
                {
                    IsDropTargeted = $0
                }
                .overlay
                {
                    if IsDropTargeted
                    {
                        RoundedRectangle(cornerRadius: 8).stroke(.tint, lineWidth: 3)
                    }
                }
                #endif
            }
        }
    }
}

#Preview
{
    ImagePane(InputSource: .Image,
              LiveImage: nil,
              SourceImage: Image("Hana"),
              Server: FilterServer(),
              Selection: nil,
              SourceID: UUID(),
              OnRendered: { _ in },
              OnDropped: { _, _ in })
}
