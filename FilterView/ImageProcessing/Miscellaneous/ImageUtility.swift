//
//  ImageUtility.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import SwiftUI

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
}
