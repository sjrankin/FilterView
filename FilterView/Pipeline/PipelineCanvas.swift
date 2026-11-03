//
//  PipelineCanvas.swift
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

/// Decides which image a merge lays on its background.
enum PipelineCanvas
{
    /// The image to merge onto a background. Normally that is the image the stage made. An overlay generator (see `OverlayGenerator`)
    /// whose image is not the size of the background is made again on a canvas the size of the background, so it is not scaled
    /// by the merge. The main window does not do this; there a generator just uses the size of the image it is given.
    /// - Parameter Generator: The filter of the stage being merged. `nil` if the stage does not run a filter.
    /// - Parameter Options: The options of that filter.
    /// - Parameter Made: The image the stage made.
    /// - Parameter Background: The image it is merged onto, which sets the size of the canvas.
    /// - Returns: The image to merge. If the filter fails, the image the stage made.
    static func Foreground(Generator: ImageFilter?, Options: [String: Any]?, Made: CGImage, Background: CGImage) async -> CGImage
    {
        guard let Generator = Generator as? OverlayGenerator,
              Made.width != Background.width || Made.height != Background.height else
        {
            return Made
        }
        return (try? await Generator.ProcessImage(Background, Options)) ?? Made
    }
}
