//
//  ImageUtility.swift
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
import CoreGraphics
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Contains miscellaneous utility functions for images.
class ImageUtility
{
    static var Context = CIContext()
    
#if canImport(UIKit)
    /// Convert the passed `CGImage` an a UIImage.
    /// - Parameter cg: The `CGImage` to convert.
    /// - Returns: `UIImage` equivalent of the passed `CGImage`.
    static func CGImageToUIImage(_ cg: CGImage) -> UIImage
    {
        return UIImage(cgImage: cg)
    }
    
    /// Convert the passed `UIImage` to a `CGImage`.
    /// - Parameter ui: The `UIImage` to convert.
    /// - Returns: `CGImage` equivalent of the passed `UIImage`. Result is `nil` if error converting.
    static func UIImageToCGImage(_ ui: UIImage) -> CGImage?
    {
        if let easy = ui.cgImage
        {
            return easy
        }
        if let cg = ui.ciImage
        {
            return Context.createCGImage(cg, from: cg.extent)
        }
        return nil
    }
#elseif canImport(AppKit)
    
    /// Convert the passed `CGImage` to an NSImage.
    /// - Parameter cg: The `CGImage` to convert.
    /// - Returns: `NSImage` equivalent of the passed `CGImage`.
    static func CGImageToNSImage(_ cg: CGImage) -> NSImage
    {
        return NSImage(cgImage: cg, size: NSSize(width: cg.width / 2, height: cg.height / 2))
    }
    
    /// Convert the passed `NSImage` to a `CGImage`.
    /// - Parameter ns: The `NSImage` to convert.
    /// - Returns: `CGImage` equivalent of the passed `NSImage`. Result is `nil` if error converting.
    static func NSImageToCGImage(_ ns: NSImage) -> CGImage?
    {
        var r = CGRect(origin: .zero, size: ns.size)
        return ns.cgImage(forProposedRect: &r, context: nil, hints: nil)
    }
#endif
    
    /// Convert the passed `CGImage` to a SwiftUI `Image`.
    /// - Parameter cg: The `CGImage` to convert.
    /// - Returns: `Image` equivalent of the passed `CGImage`.
    static func CGImageToImage(_ cg: CGImage) -> Image
    {
        return Image(decorative: cg, scale: 1.0)
    }
    
    /// Converts a `CGImage` to a `CIImage`.
    /// - Parameter cg: The image to convert.
    /// - Returns: `CIImage` based on the passed `CGImage`.
    static func CGImageToCIImage(_ cg: CGImage) -> CIImage
    {
        return CIImage(cgImage: cg)
    }
    
    /// Converts a `CIImage` to a `CGImage`.
    /// - Parameter ci: The image to convert.
    /// - Returns: `CGImage` based on the passed `CIImage`.
    static func CIImageToCGImage(_ ci: CIImage) -> CGImage?
    {
        if let Direct = ci.cgImage
        {
            return Direct
        }
        guard !ci.extent.isInfinite,
              !ci.extent.isEmpty else
        {
            return nil
        }
        return Context.createCGImage(ci, from: ci.extent)
    }
    
    /// Converts a SwiftUI image to a `CGImage`.
    /// - Parameter su: The SwiftUI image to convert.
    /// - Returns: The converted SwiftUI image as a `CGImage`. `Nil` on error.
    static func ImageToCGImage(_ su: Image) -> CGImage?
    {
        let Renderer = ImageRenderer(content: su)
        return Renderer.cgImage
    }
    
    /// Returns the center point of the passed `CGImage`.
    /// - Parameter cg: The image whose center will be returned.
    /// - Returns: The point at the center of the passed image.
    static func CGImageCenter(_ cg: CGImage) -> CGPoint
    {
        let CenterX = Double(cg.width) / 2.0
        let CenterY = Double(cg.height) / 2.0
        return CGPoint(x: CenterX, y: CenterY)
    }
    
    // MARK: - File saving in SwiftUI

    enum ImageEncoder
    {
        static func PNGData(_ Source: CGImage) -> Data?
        {
            let Mutable = NSMutableData()
            guard let Destination = CGImageDestinationCreateWithData(Mutable,
                                                                     UTType.png.identifier as CFString,
                                                                     1, nil) else
            {
                return nil
            }
            CGImageDestinationAddImage(Destination, Source, nil)
            return CGImageDestinationFinalize(Destination) ? Mutable as Data : nil
        }
    }
    
    struct PNGImage: FileDocument
    {
        static var readableContentTypes: [UTType] { [.png] }
        var Data: Data
        
        init(Data: Data)
        {
            self.Data = Data
        }
        
        init(configuration: ReadConfiguration) throws{
            Data = configuration.file.regularFileContents ?? Foundation.Data()
        }
        
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper
        {
            FileWrapper(regularFileWithContents: Data)
        }
    }
}

extension ImageUtility
{
    /// Longest side, in pixels, of an image loaded by `LoadImage`. Larger images are scaled down so they do not slow the filters.
    nonisolated static let MaxLoadedPixelSize = 4096

    /// Loads an image file. Works on iOS and macOS.
    /// - Parameter URL: The image file.
    /// - Parameter MaxPixelSize: Longest side, in pixels, the image may have. Defaults to `MaxLoadedPixelSize`.
    /// - Returns: The image with its EXIF orientation applied (so iPhone photos are not rotated), scaled down if its longest
    /// side is over `MaxPixelSize`. `nil` if the file cannot be read as an image.
    nonisolated static func LoadImage(from URL: URL, MaxPixelSize: Int = MaxLoadedPixelSize) -> CGImage?
    {
        guard let Source = CGImageSourceCreateWithURL(URL as CFURL, nil) else
        {
            return nil
        }
        let Options: [CFString: Any] =
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: MaxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(Source, 0, Options as CFDictionary)
    }
}
