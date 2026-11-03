//
//  ImageServer.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
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
import Combine
import CoreGraphics

/// Reads an image from a source and lets consumers know it is available.
/// There are three image sources:
/// 1. An image file read from the OS.
/// 2. An image from the camera (if the device has a camera).
/// 3. Streaming video from the camera (if the device has a camera).
/// This class is responsible for applying filters.
class ImageServer
{
    /// The original, unfiltered image. Updated when a new image is loaded.
    @Published var SourceImage: CGImage? = nil
    
    /// The current image with the filter applied. Updated when a new image is loaded or the filter is changed.
    @Published var NewImage: CGImage? = nil
    
    init()
    {
        NewImage = nil
    }
    
    /// Apply the specified filter (and optional parameters) to the image stream.
    /// - Parameter FilterName: The name of the filter. If no name, the passthrough filter will be used.
    /// - Parameter Options: Dictionary of user-settable options for the filter. If `nil`, no options
    /// are available.
    /// - Note: The filter is applied immediately.
    func ApplyFilter(_ FilterName: String, Options: [String: Any]? = nil)
    {
        
    }
    
    func SetImageSource(_ To: ImageSources)
    {
        
    }
}

enum ImageSources
{
    case FromImageFile
    case FromCamera
    case FromVideo
}
