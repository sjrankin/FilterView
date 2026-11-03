//
//  ImageExtension.swift
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

import Foundation
import SwiftUI

extension Image
{
    /// Runs the named filter on this image.
    /// - Parameter Filter: Name of the filter to run.
    /// - Parameter Server: The filter server. If `nil`, or if the image cannot be converted, this image is returned unchanged.
    /// - Parameter Options: Dictionary of options to pass to the filter.
    /// - Returns: The filtered image.
    /// - Throws: Any error thrown by the filter, such as `FilterException` when the filter does not exist.
    @MainActor func Filtered(Filter: String, Server: FilterServer?, Options: [String: Any]? = nil) async throws -> Image
    {
        guard let Server = Server,
              let ToConvert = ImageUtility.ImageToCGImage(self) else
        {
            return self
        }
        let Result = try await Server.Run(Filter: Filter, With: ToConvert, Options)
        return ImageUtility.CGImageToImage(Result)
    }
}
