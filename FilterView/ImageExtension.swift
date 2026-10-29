//
//  ImageExtension.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
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
