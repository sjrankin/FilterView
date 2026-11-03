//
//  DistortSupport.swift
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
import CoreGraphics
import CoreImage

/// Shared steps for the Core Image distortion filters.
enum DistortSupport
{
    /// Makes the final image from what a distortion filter made.
    ///
    /// Core Image gives only the part of the picture a filter changed, or a picture that goes on forever (the edge of the image repeated),
    /// so the result is put on a canvas the size of the image the filter was given. That keeps the size the same all through a pipeline.
    /// - Parameter Result: What the filter made. `nil` if it made nothing.
    /// - Parameter Source: The image the filter was given.
    /// - Parameter Name: Name of the filter, for the error message.
    /// - Parameter OverSource: True for an effect that changes only part of the image, such as a bump or a twirl: the rest of the picture
    /// is the original image. If false, the canvas is transparent, which is right for a filter that makes the whole picture itself.
    /// - Parameter KeepSize: False for a filter that makes an image of another size on purpose, which is only cut if it is infinite.
    /// - Throws: `FilterException` if the image cannot be made.
    static func Finish(_ Result: CIImage?, Source: CIImage, Name: String, OverSource: Bool = false, KeepSize: Bool = true) throws -> CGImage
    {
        guard var Made = Result else
        {
            throw FilterException(Message: "Error from \(Name).")
        }
        if KeepSize
        {
            let Canvas = OverSource ? Source : CIImage(color: .clear).cropped(to: Source.extent)
            Made = Made.composited(over: Canvas).cropped(to: Source.extent)
        }
        else if Made.extent.isInfinite
        {
            Made = Made.cropped(to: Source.extent)
        }
        guard let Final = ImageUtility.CIImageToCGImage(Made) else
        {
            throw FilterException(Message: "Error from \(Name).")
        }
        return Final
    }
}
