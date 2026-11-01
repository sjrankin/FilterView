//
//  ImageInputSources.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation

/// Where the main UI gets its image.
enum ImageInputSources: String, CaseIterable, Identifiable
{
    /// An image file.
    case Image = "Image"
    /// A single photo taken with the device's camera.
    case Camera = "Camera"
    /// Live video from the device's camera.
    case Video = "Video"
    var id: String { rawValue }
}
