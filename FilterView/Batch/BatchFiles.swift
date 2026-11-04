//
//  BatchFiles.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/4/26.
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
import ImageIO
import UniformTypeIdentifiers

/// File work for batch mode: reading images, choosing and encoding the output format, and naming and writing the saved copies. None of
/// it touches the UI, so it is safe to call from any thread.
nonisolated enum BatchFiles
{
    /// Added to the name of a saved copy, before the extension.
    static let Suffix = "_fv"

    /// Longest side, in pixels, of the copies the batch grid keeps and filters.
    static let PreviewPixelSize = 1024

    /// How a saved copy is written.
    struct Format: Equatable
    {
        /// The image type to encode.
        let Kind: UTType
        /// The file extension, without the dot.
        let Extension: String
    }

    /// The extensions that are written in their own format, with the type each uses. Everything else is saved as PNG.
    private static let KnownTypes: [String: UTType] =
    [
        "png": .png, "jpg": .jpeg, "jpeg": .jpeg, "heic": .heic, "heif": .heic, "tif": .tiff, "tiff": .tiff, "bmp": .bmp, "gif": .gif
    ]

    /// The format for the saved copy of a file: the file's own format if the system can write it, otherwise PNG.
    /// - Parameter Source: The file that was read.
    static func OutputFormat(for Source: URL) -> Format
    {
        let Original = Source.pathExtension
        if let Known = KnownTypes[Original.lowercased()],
           CanWrite(Known)
        {
            // The extension keeps the spelling (and case) of the original.
            return Format(Kind: Known, Extension: Original)
        }
        return Format(Kind: .png, Extension: "png")
    }

    /// True if images can be encoded as this type on this system. HEIC, for example, depends on the hardware.
    private static func CanWrite(_ Type: UTType) -> Bool
    {
        let Writable = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return Writable.contains(Type.identifier)
    }

    /// Where the saved copy of a file goes: the same folder, the same name with `_fv` added, and the extension of its format.
    /// - Parameter Source: The file that was read.
    static func OutputURL(for Source: URL) -> URL
    {
        let Name = Source.deletingPathExtension().lastPathComponent + Suffix
        return Source.deletingLastPathComponent().appending(path: Name).appendingPathExtension(OutputFormat(for: Source).Extension)
    }

    /// Encodes an image.
    /// - Parameter Image: The image.
    /// - Parameter Type: The format. JPEG and BMP have no transparency, so an image with some is put on white first.
    /// - Returns: The file's contents. `nil` if the image cannot be encoded.
    static func Encode(_ Image: CGImage, as Type: UTType) -> Data?
    {
        var ToWrite = Image
        if Type == .jpeg || Type == .bmp,
           HasAlpha(Image),
           let Flat = OnWhite(Image)
        {
            ToWrite = Flat
        }
        let Mutable = NSMutableData()
        guard let Destination = CGImageDestinationCreateWithData(Mutable, Type.identifier as CFString, 1, nil) else
        {
            return nil
        }
        let Options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(Destination, ToWrite, Options as CFDictionary)
        return CGImageDestinationFinalize(Destination) ? Mutable as Data : nil
    }

    private static func HasAlpha(_ Image: CGImage) -> Bool
    {
        switch Image.alphaInfo
        {
            case .none, .noneSkipFirst, .noneSkipLast:
                return false

            default:
                return true
        }
    }

    private static func OnWhite(_ Image: CGImage) -> CGImage?
    {
        guard let Context = CGContext(data: nil, width: Image.width, height: Image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else
        {
            return nil
        }
        let Bounds = CGRect(x: 0, y: 0, width: Image.width, height: Image.height)
        Context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        Context.fill(Bounds)
        Context.draw(Image, in: Bounds)
        return Context.makeImage()
    }

    /// A copy of an image scaled down so its longest side is at most `MaxSize`. An image that is small enough is returned as it is.
    static func Downscaled(_ Image: CGImage, MaxSize: Int = PreviewPixelSize) -> CGImage
    {
        let Longest = max(Image.width, Image.height)
        guard Longest > MaxSize,
              Longest > 0 else
        {
            return Image
        }
        let Scale = Double(MaxSize) / Double(Longest)
        let Width = max(1, Int((Double(Image.width) * Scale).rounded()))
        let Height = max(1, Int((Double(Image.height) * Scale).rounded()))
        guard let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: Image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) ?? CGContext(
                                        data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0,
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
        {
            return Image
        }
        Context.interpolationQuality = .high
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Width, height: Height))
        return Context.makeImage() ?? Image
    }

    /// The size, in pixels, an image file will have once loaded: its orientation applied and its longest side limited as `LoadImage`
    /// does. Read from the file's properties, so the image is not decoded.
    /// - Parameter File: The image file.
    static func PixelSize(of File: URL) -> CGSize?
    {
        guard let Source = CGImageSourceCreateWithURL(File as CFURL, nil),
              let Properties = CGImageSourceCopyPropertiesAtIndex(Source, 0, nil) as? [CFString: Any],
              let Width = Properties[kCGImagePropertyPixelWidth] as? Double,
              let Height = Properties[kCGImagePropertyPixelHeight] as? Double else
        {
            return nil
        }
        let Orientation = Properties[kCGImagePropertyOrientation] as? Int ?? 1
        var Size = (5 ... 8).contains(Orientation) ? CGSize(width: Height, height: Width) : CGSize(width: Width, height: Height)
        let Longest = Double(ImageUtility.MaxLoadedPixelSize)
        if max(Size.width, Size.height) > Longest
        {
            let Scale = Longest / max(Size.width, Size.height)
            Size = CGSize(width: (Size.width * Scale).rounded(), height: (Size.height * Scale).rounded())
        }
        return Size
    }

    /// Loads a file at the size the filters work on when it is saved.
    /// - Parameter File: The image file. It is security scoped if the user chose it, so access is requested here.
    @concurrent static func LoadFull(_ File: URL) async -> CGImage?
    {
        let Scope = File.startAccessingSecurityScopedResource()
        defer
        {
            if Scope
            {
                File.stopAccessingSecurityScopedResource()
            }
        }
        return ImageUtility.LoadImage(from: File)
    }

    /// Loads a file at preview size, with the size it will have when it is saved.
    /// - Parameter File: The image file. It is security scoped if the user chose it, so access is requested here.
    /// - Returns: `nil` if the file cannot be read as an image.
    @concurrent static func LoadPreview(_ File: URL) async -> (Image: CGImage, Size: CGSize)?
    {
        let Scope = File.startAccessingSecurityScopedResource()
        defer
        {
            if Scope
            {
                File.stopAccessingSecurityScopedResource()
            }
        }
        guard let Loaded = ImageUtility.LoadImage(from: File, MaxPixelSize: PreviewPixelSize) else
        {
            return nil
        }
        return (Loaded, PixelSize(of: File) ?? CGSize(width: Loaded.width, height: Loaded.height))
    }

    /// Makes the contents of the saved copy.
    /// - Parameter Image: The filtered image.
    /// - Parameter Format: How to write it.
    @concurrent static func EncodeAsync(_ Image: CGImage, as Format: Format) async -> Data?
    {
        Encode(Image, as: Format.Kind)
    }

    /// A small copy of an image for the grid.
    @concurrent static func MakePreview(_ Image: CGImage) async -> CGImage
    {
        Downscaled(Image)
    }

    /// Writes a saved copy in a folder the user chose.
    /// - Parameter Contents: The encoded image.
    /// - Parameter Name: The file's name, with its extension.
    /// - Parameter Folder: The folder. It is security scoped, so access is requested here.
    /// - Returns: The file written.
    /// - Throws: The error from the file system.
    @concurrent static func Write(_ Contents: Data, named Name: String, in Folder: URL) async throws -> URL
    {
        let Scope = Folder.startAccessingSecurityScopedResource()
        defer
        {
            if Scope
            {
                Folder.stopAccessingSecurityScopedResource()
            }
        }
        let Target = Folder.appending(path: Name)
        try Contents.write(to: Target, options: .atomic)
        return Target
    }

    /// Writes a saved copy.
    /// - Parameter Contents: The encoded image.
    /// - Parameter Target: The file to write.
    /// - Parameter Original: The file the image was read from, whose access is held while writing.
    /// - Throws: The error from the file system, such as a permission error when the app may not write in that folder.
    @concurrent static func Write(_ Contents: Data, to Target: URL, Original: URL) async throws
    {
        let Scope = Original.startAccessingSecurityScopedResource()
        defer
        {
            if Scope
            {
                Original.stopAccessingSecurityScopedResource()
            }
        }
        try Contents.write(to: Target, options: .atomic)
    }
}
