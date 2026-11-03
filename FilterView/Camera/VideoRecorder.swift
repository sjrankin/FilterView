//
//  VideoRecorder.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
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
import AVFoundation
import CoreVideo
import CoreGraphics

/// Records a sequence of images (the filtered live video frames) to an MP4 file in the temporary folder.
///
/// Call `Begin()`, then `Append(_:)` for each frame, then `Finish()`, which returns the file. The video's size is the size of
/// the first frame; later frames of another size are scaled to fit. Each frame is stamped with the time it arrives, so the video
/// plays at the speed it was recorded even though the frame rate varies.
///
/// A video cannot hold transparency, so every frame is put on the background chosen in the settings (black, white, or the checkerboard the
/// main window shows), which is how a frame with transparent parts looks on screen. Without that, the parts of a frame that are transparent
/// or partly so would be black.
actor VideoRecorder
{
    private var Writer: AVAssetWriter? = nil
    private var Receiver: AVAssetWriterInput.PixelBufferReceiver? = nil
    private var Pool: CVMutablePixelBuffer.Pool? = nil
    private var FileURL: URL? = nil
    private var StartedAt: ContinuousClock.Instant? = nil
    private var LastTime = CMTime.invalid
    private var VideoWidth = 0
    private var VideoHeight = 0
    /// What every frame is drawn over, the size of the video.
    private var Backdrop: CGImage? = nil
    /// The background chosen when the recording began.
    private var Background = ImageBackgrounds.Checkerboard
    private var IsActive = false

    /// Starts a new recording. The file is created when the first frame arrives, because its size is not known until then.
    /// A recording that was never finished is thrown away.
    /// - Parameter Background: What every frame is put on, which is what shows through its transparent parts.
    func Begin(Background: ImageBackgrounds = .Checkerboard)
    {
        Discard()
        self.Background = Background
        IsActive = true
    }

    /// Adds a frame to the recording. Does nothing if no recording is active, and drops the frame if the file writer is not
    /// ready for it (so a slow disk makes frames drop instead of piling up).
    /// - Parameter Frame: The frame.
    func Append(_ Frame: CGImage)
    {
        guard IsActive else
        {
            return
        }
        if Writer == nil && !Start(FirstFrame: Frame)
        {
            // The file could not be started. Stop trying.
            IsActive = false
            return
        }
        guard let Writer = Writer,
              let Receiver = Receiver,
              let Pool = Pool,
              let StartedAt = StartedAt,
              Writer.status == .writing else
        {
            return
        }
        let Elapsed = ContinuousClock.now - StartedAt
        let Seconds = Double(Elapsed.components.seconds) + Double(Elapsed.components.attoseconds) / 1e18
        let Time = CMTime(seconds: Seconds, preferredTimescale: 600)
        if LastTime.isValid && Time <= LastTime
        {
            // Times must increase.
            return
        }
        guard var Pixels = try? Pool.makeMutablePixelBuffer() else
        {
            return
        }
        let Width = VideoWidth
        let Height = VideoHeight
        // Draw the frame into the buffer's memory. This also scales it if it is not the size of the video.
        let Drawn = Pixels.accessUnsafeMutableRawPlaneBytes
        {
            Planes -> Bool in
            guard let Plane = Planes.first,
                  let Memory = Plane.bytes.baseAddress,
                  let Context = CGContext(data: Memory,
                                          width: Width,
                                          height: Height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: Plane.properties.bytesPerRow,
                                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else
            {
                return false
            }
            let Area = CGRect(x: 0, y: 0, width: Width, height: Height)
            if let Backdrop = Backdrop
            {
                Context.draw(Backdrop, in: Area)
            }
            Context.draw(Frame, in: Area)
            return true
        }
        guard Drawn else
        {
            return
        }
        // Returns false, without waiting, if the writer is not ready for another frame.
        if (try? Receiver.appendImmediately(CVReadOnlyPixelBuffer(Pixels), with: Time)) == true
        {
            LastTime = Time
        }
    }

    /// Ends the recording and finishes the file.
    /// - Returns: The MP4 file, in the temporary folder.
    /// - Throws: `FilterException` if no frames were recorded or the file could not be finished.
    func Finish() async throws -> URL
    {
        IsActive = false
        guard let Writer = Writer,
              let Receiver = Receiver,
              let File = FileURL,
              Writer.status == .writing else
        {
            Discard()
            throw FilterException(Message: "No video was recorded")
        }
        Receiver.finish()
        await Writer.finishWriting()
        let Failure = Writer.error
        let Completed = Writer.status == .completed
        Reset()
        guard Completed else
        {
            try? FileManager.default.removeItem(at: File)
            throw FilterException(Message: "Could not finish the video: \(Failure?.localizedDescription ?? "unknown error")")
        }
        return File
    }

    /// Creates the file and starts writing, with the size of the first frame.
    /// - Parameter FirstFrame: The first frame.
    /// - Returns: True if writing started.
    private func Start(FirstFrame: CGImage) -> Bool
    {
        // Video codecs need even dimensions.
        let Width = max(FirstFrame.width & ~1, 2)
        let Height = max(FirstFrame.height & ~1, 2)
        let File = URL.temporaryDirectory.appending(path: "FilterView \(UUID().uuidString).mp4")
        guard let NewWriter = try? AVAssetWriter(outputURL: File, fileType: .mp4) else
        {
            return false
        }
        let Settings: [String: Any] =
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Width,
            AVVideoHeightKey: Height,
            // Dithered and filtered frames are full of fine detail, so give the encoder plenty of bits.
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: Width * Height * 8]
        ]
        let Attributes = CVPixelBufferCreationAttributes(pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
                                                         size: CVImageSize(width: Width, height: Height))
        guard let NewPool = try? CVMutablePixelBuffer.Pool(pixelBufferAttributes: Attributes) else
        {
            return false
        }
        // Getting the receiver also adds the input to the writer.
        let NewInput = AVAssetWriterInput(mediaType: .video, outputSettings: Settings)
        let NewReceiver = NewWriter.inputPixelBufferReceiver(for: NewInput, pixelBufferAttributes: Attributes)
        guard (try? NewWriter.start()) != nil else
        {
            return false
        }
        NewWriter.startSession(atSourceTime: .zero)
        Writer = NewWriter
        Receiver = NewReceiver
        Pool = NewPool
        FileURL = File
        VideoWidth = Width
        VideoHeight = Height
        Backdrop = VideoRecorder.Backdrop(for: Background, Width: Width, Height: Height)
        StartedAt = ContinuousClock.now
        LastTime = .invalid
        return true
    }

    /// What frames are drawn over for a background.
    /// - Parameter Kind: The background.
    /// - Parameter Width: Width of the video in pixels.
    /// - Parameter Height: Height of the video in pixels.
    /// - Returns: An opaque image the size of the video, or `nil` if it cannot be made.
    nonisolated static func Backdrop(for Kind: ImageBackgrounds, Width: Int, Height: Int) -> CGImage?
    {
        switch Kind
        {
            case .Checkerboard:
                return Checkerboard(Width: Width, Height: Height)

            case .Black, .White:
                guard let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
                {
                    return nil
                }
                Context.setFillColor(CGColor(srgbRed: Kind == .White ? 1 : 0, green: Kind == .White ? 1 : 0, blue: Kind == .White ? 1 : 0,
                                             alpha: 1))
                Context.fill(CGRect(x: 0, y: 0, width: Width, height: Height))
                return Context.makeImage()
        }
    }

    /// The checkerboard frames are drawn over: squares of light and darker gray, the same grays as the one in the main window. The squares
    /// grow with the video so they look the same at any size.
    /// - Parameter Width: Width of the video in pixels.
    /// - Parameter Height: Height of the video in pixels.
    /// - Returns: An opaque image the size of the video, or `nil` if it cannot be made.
    nonisolated static func Checkerboard(Width: Int, Height: Int) -> CGImage?
    {
        guard let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
        {
            return nil
        }
        let Square = max(min(Width, Height) / 48, 8)
        Context.setFillColor(CGColor(srgbRed: 0.85, green: 0.85, blue: 0.85, alpha: 1))
        Context.fill(CGRect(x: 0, y: 0, width: Width, height: Height))
        Context.setFillColor(CGColor(srgbRed: 0.6, green: 0.6, blue: 0.6, alpha: 1))
        for Row in 0 ..< (Height + Square - 1) / Square
        {
            for Column in 0 ..< (Width + Square - 1) / Square where (Row + Column).isMultiple(of: 2)
            {
                Context.fill(CGRect(x: Column * Square, y: Row * Square, width: Square, height: Square))
            }
        }
        return Context.makeImage()
    }

    /// Forgets the writer, leaving the file alone.
    private func Reset()
    {
        Writer = nil
        Receiver = nil
        Pool = nil
        FileURL = nil
        StartedAt = nil
        LastTime = .invalid
        Backdrop = nil
    }

    /// Cancels any unfinished recording and deletes its file.
    private func Discard()
    {
        Writer?.cancelWriting()
        if let File = FileURL
        {
            try? FileManager.default.removeItem(at: File)
        }
        Reset()
        IsActive = false
    }
}
