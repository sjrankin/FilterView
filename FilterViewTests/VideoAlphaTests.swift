//
//  VideoAlphaTests.swift
//  FilterViewTests
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

import Testing
import Foundation
import CoreGraphics
import AVFoundation
@testable import FilterView

/// A video cannot hold transparency, so frames with alpha below 1 are recorded on a checkerboard instead of turning black.
@MainActor
struct VideoAlphaTests
{
    /// An orange image drawn at the given alpha, so its pixels are partly or fully transparent.
    private func Frame(Alpha: CGFloat) -> CGImage
    {
        let Context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.setAlpha(Alpha)
        Context.setFillColor(CGColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1))
        Context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return Context.makeImage()!
    }

    private func Pixel(_ Image: CGImage, _ X: Int, _ Y: Int) -> [Int]
    {
        let Context = CGContext(data: nil, width: Image.width, height: Image.height, bitsPerComponent: 8, bytesPerRow: Image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Image.width, height: Image.height))
        let Bytes = Context.data!.assumingMemoryBound(to: UInt8.self)
        let Start = (Y * Image.width + X) * 4
        return [Int(Bytes[Start]), Int(Bytes[Start + 1]), Int(Bytes[Start + 2]), Int(Bytes[Start + 3])]
    }

    /// Records a few copies of a frame and returns a frame of the finished video.
    private func Recorded(_ Source: CGImage, On Background: ImageBackgrounds = .Checkerboard) async throws -> CGImage
    {
        let Recorder = VideoRecorder()
        await Recorder.Begin(Background: Background)
        for _ in 0 ..< 8
        {
            await Recorder.Append(Source)
            try await Task.sleep(for: .milliseconds(80))
        }
        let File = try await Recorder.Finish()
        let Generator = AVAssetImageGenerator(asset: AVURLAsset(url: File))
        Generator.requestedTimeToleranceBefore = .positiveInfinity
        Generator.requestedTimeToleranceAfter = .positiveInfinity
        let (Image, _) = try await Generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600))
        return Image
    }

    @Test func TheCheckerboardHasTwoGraysAndIsOpaque() throws
    {
        let Board = try #require(VideoRecorder.Checkerboard(Width: 192, Height: 108))
        #expect(Board.width == 192 && Board.height == 108)
        // The squares are 8 across (the smaller side is under 384), and neighbors alternate.
        let Light = Pixel(Board, 0, 0)
        let Dark = Pixel(Board, 9, 0)
        #expect(Light[3] == 255 && Dark[3] == 255)
        #expect(Light[0] != Dark[0])
        #expect(Set([Light[0], Dark[0]]) == Set([217, 153]))
    }

    @Test func SquaresGrowWithTheVideo() throws
    {
        let Big = try #require(VideoRecorder.Checkerboard(Width: 1920, Height: 1080))
        // 1080 / 48 is 22, so the first square ends at 22 and the next begins.
        #expect(Pixel(Big, 21, 0)[0] != Pixel(Big, 23, 0)[0])
        #expect(Pixel(Big, 1, 0)[0] == Pixel(Big, 21, 0)[0])
    }

    @Test func AnOpaqueFrameIsRecordedAsItWas() async throws
    {
        let Source = Frame(Alpha: 1)
        let Result = try await Recorded(Source)
        let Value = Pixel(Result, 32, 32)
        let Wanted = Pixel(Source, 32, 32)
        // The video is lossy, so the color is close and not exact.
        #expect(abs(Value[0] - Wanted[0]) < 25 && abs(Value[1] - Wanted[1]) < 25 && abs(Value[2] - Wanted[2]) < 35)
    }

    @Test func AFullyTransparentFrameIsTheCheckerboardNotBlack() async throws
    {
        let Result = try await Recorded(Frame(Alpha: 0))
        for Point in [(5, 5), (32, 32), (58, 58)]
        {
            let Value = Pixel(Result, Point.0, Point.1)
            #expect(Value[0] > 130 && Value[0] < 235, "\(Point)")
        }
    }

    @Test func ATransparentFrameIsRecordedOnTheChosenBackground() async throws
    {
        let OnWhite = try await Recorded(Frame(Alpha: 0), On: .White)
        let OnBlack = try await Recorded(Frame(Alpha: 0), On: .Black)
        #expect(Pixel(OnWhite, 32, 32)[0] > 235 && Pixel(OnWhite, 5, 5)[0] > 235)
        #expect(Pixel(OnBlack, 32, 32)[0] < 25 && Pixel(OnBlack, 5, 5)[0] < 25)
    }

    @Test func AFaintFrameIsBrightOnWhiteAndDarkOnBlack() async throws
    {
        let OnWhite = Pixel(try await Recorded(Frame(Alpha: 0.3), On: .White), 32, 32)
        let OnBlack = Pixel(try await Recorded(Frame(Alpha: 0.3), On: .Black), 32, 32)
        #expect(OnWhite[0] > OnBlack[0] + 100)
    }

    @Test func EachBackgroundMakesAnOpaqueImageTheSizeOfTheVideo() throws
    {
        for Kind in ImageBackgrounds.allCases
        {
            let Image = try #require(VideoRecorder.Backdrop(for: Kind, Width: 100, Height: 60))
            #expect(Image.width == 100 && Image.height == 60, "\(Kind)")
            #expect(Pixel(Image, 50, 30)[3] == 255, "\(Kind)")
        }
        let Black = try #require(VideoRecorder.Backdrop(for: .Black, Width: 20, Height: 20))
        let White = try #require(VideoRecorder.Backdrop(for: .White, Width: 20, Height: 20))
        #expect(Pixel(Black, 3, 3)[0] == 0)
        #expect(Pixel(White, 3, 3)[0] == 255)
    }

    @Test func AFaintFrameStillShowsItsColorOverTheCheckerboard() async throws
    {
        // At alpha 0.2 the frame used to come out almost black. Now it is mostly the checkerboard with a hint of orange: red above blue.
        let Result = try await Recorded(Frame(Alpha: 0.2))
        let Value = Pixel(Result, 32, 32)
        #expect(Value[0] > 130)
        #expect(Value[0] > Value[2] + 10)
    }

    @Test func ABrighterFrameIsBrighterThanAFainterOne() async throws
    {
        let Faint = Pixel(try await Recorded(Frame(Alpha: 0.3)), 32, 32)
        let Strong = Pixel(try await Recorded(Frame(Alpha: 0.9)), 32, 32)
        // Orange has more red than blue, and more of it shows through at a higher alpha.
        #expect(Strong[0] - Strong[2] > Faint[0] - Faint[2])
    }
}
