//
//  DetectionFilterTests.swift
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
import CoreImage
@testable import FilterView

@MainActor
struct DetectionFilterTests
{
    /// Alternating black and white squares 4 pixels across, so blurring or pixelating them changes the picture.
    private func Checker(Width: Int = 200, Height: Int = 120) -> CGImage
    {
        let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for Y in 0 ..< Height / 4
        {
            for X in 0 ..< Width / 4
            {
                let On: CGFloat = (X + Y) % 2 == 0 ? 1 : 0
                Context.setFillColor(CGColor(red: On, green: On, blue: On, alpha: 1))
                Context.fill(CGRect(x: X * 4, y: Y * 4, width: 4, height: 4))
            }
        }
        return Context.makeImage()!
    }

    /// The pixel at x, y counted from the top left.
    private func Pixel(_ Image: CGImage, _ X: Int, _ Y: Int) -> [Int]
    {
        let Context = CGContext(data: nil, width: Image.width, height: Image.height, bitsPerComponent: 8, bytesPerRow: Image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Image.width, height: Image.height))
        let Bytes = Context.data!.assumingMemoryBound(to: UInt8.self)
        let Start = (Y * Image.width + X) * 4
        return [Int(Bytes[Start]), Int(Bytes[Start + 1]), Int(Bytes[Start + 2]), Int(Bytes[Start + 3])]
    }

    private func Marked(_ Faces: [FaceMark], _ Options: [String: String]) throws -> CGImage
    {
        let Source = CIImage(cgImage: Checker())
        return try #require(ImageUtility.CIImageToCGImage(CIFaceDetector.Mark(Source, Faces: Faces, Options: Options).cropped(to: Source.extent)))
    }

    /// A face 60 across and 60 high whose lower left corner is at 50, 30, so it covers rows 30 to 90 from the bottom.
    private let Face = FaceMark(Bounds: CGRect(x: 50, y: 30, width: 60, height: 60))

    // MARK: Person segmentation

    @Test func SegmentationKeepsTheSizeInEveryOutput() async throws
    {
        let Source = TestSupport.MakeImage(Width: 160, Height: 100)
        for Output in ["PERSON", "BACKGROUND", "MASK"]
        {
            let Result = try await FilterServer().Run(Filter: CIPersonSegmentation.FilterName, With: Source,
                                                      ["OUTPUT": Output, "QUALITY": "FAST"])
            #expect(Result.width == 160 && Result.height == 100, "\(Output)")
        }
    }

    @Test func TheMaskIsPlainGrayAndOpaque() async throws
    {
        let Result = try await FilterServer().Run(Filter: CIPersonSegmentation.FilterName, With: TestSupport.MakeImage(Width: 160, Height: 100),
                                                  ["OUTPUT": "MASK", "QUALITY": "FAST"])
        for Point in [(10, 10), (80, 50), (150, 90)]
        {
            let Value = Pixel(Result, Point.0, Point.1)
            #expect(Value[0] == Value[1] && Value[1] == Value[2])
            #expect(Value[3] == 255)
        }
    }

    @Test func WithNoPersonThePersonOutputIsClearAndTheBackgroundOutputIsKept() async throws
    {
        let Source = TestSupport.MakeImage(Width: 160, Height: 100)
        let Server = FilterServer()
        let Person = try await Server.Run(Filter: CIPersonSegmentation.FilterName, With: Source, ["OUTPUT": "PERSON", "QUALITY": "FAST"])
        let Background = try await Server.Run(Filter: CIPersonSegmentation.FilterName, With: Source, ["OUTPUT": "BACKGROUND", "QUALITY": "FAST"])
        #expect(Pixel(Person, 80, 50)[3] < 30)
        #expect(Pixel(Background, 80, 50)[3] > 225)
    }

    @Test func QualityNamesMapToCoreImagesLevels() throws
    {
        #expect(CIPersonSegmentation.Quality("ACCURATE") == 0)
        #expect(CIPersonSegmentation.Quality("BALANCED") == 1)
        #expect(CIPersonSegmentation.Quality("FAST") == 2)
        #expect(CIPersonSegmentation.Quality("anything else") == 1)
    }

    // MARK: Face detector

    @Test func AnImageWithNoFacesIsReturnedAsItIs() async throws
    {
        let Source = TestSupport.MakeImage(Width: 160, Height: 100)
        let Result = try await FilterServer().Run(Filter: CIFaceDetector.FilterName, With: Source, nil)
        #expect(Result.width == 160 && Result.height == 100)
        #expect(Pixel(Result, 80, 50) == Pixel(Source, 80, 50))
    }

    @Test func OutlineDrawsARectangleAroundTheFaceAndNothingElse() throws
    {
        let Plain = Checker()
        let Result = try Marked([Face], ["MODE": "OUTLINE", "PADDING": "0", "LINEWIDTH": "6", "COLOR": "00FF00FF"])
        // The left edge of the face, halfway down it, is green. In the picture counted from the top, rows 30 to 90 from the bottom are 30 to 90.
        let Edge = Pixel(Result, 50, 60)
        #expect(Edge[1] > 240 && Edge[0] == 0 && Edge[2] == 0)
        // Inside the outline and far outside it the picture is as it was.
        #expect(Pixel(Result, 80, 60) == Pixel(Plain, 80, 60))
        #expect(Pixel(Result, 10, 10) == Pixel(Plain, 10, 10))
    }

    @Test func PaddingMakesTheMarkedAreaBigger() throws
    {
        let Result = try Marked([Face], ["MODE": "OUTLINE", "PADDING": "50", "LINEWIDTH": "6", "COLOR": "00FF00FF"])
        // 50% of 60 is 30, so the left edge moves from 50 to 20.
        #expect(Pixel(Result, 20, 60)[1] > 240 && Pixel(Result, 20, 60)[0] == 0)
        let Plain = Checker()
        #expect(Pixel(Result, 50, 60) == Pixel(Plain, 50, 60))
    }

    @Test func TintKeepsTheFaceVisibleAndLeavesTheRestAlone() throws
    {
        let Plain = Checker()
        let Result = try Marked([Face], ["MODE": "FILL", "PADDING": "0", "COLOR": "00FF00FF"])
        // The pixel at 86, 62 is in a black square. Inside the face it is now green-tinted, but still dark and still opaque.
        #expect(Pixel(Plain, 86, 62) == [0, 0, 0, 255])
        let Dark = Pixel(Result, 86, 62)
        #expect(Dark[1] > 100 && Dark[0] == 0 && Dark[2] == 0 && Dark[3] == 255)
        // A white square is tinted too, but keeps its light.
        #expect(Pixel(Result, 82, 62)[1] > 240 && Pixel(Result, 82, 62)[0] < 255)
        #expect(Pixel(Result, 10, 10) == Pixel(Plain, 10, 10))
    }

    @Test func BlurSoftensTheFaceOnly() throws
    {
        let Plain = Checker()
        let Result = try Marked([Face], ["MODE": "BLUR", "PADDING": "0"])
        // The squares are black and white, so after blurring the middle of the face is gray.
        let Middle = Pixel(Result, 80, 60)
        #expect(Middle[0] > 60 && Middle[0] < 200)
        #expect(Pixel(Result, 10, 10) == Pixel(Plain, 10, 10))
        #expect(Pixel(Result, 150, 100) == Pixel(Plain, 150, 100))
    }

    @Test func PixelateMakesBigBlocksInTheFaceOnly() throws
    {
        let Plain = Checker()
        let Result = try Marked([Face], ["MODE": "PIXELATE", "PADDING": "0"])
        // Blocks are 6 across (a tenth of the face), so two neighboring pixels in the same block match even where the checker changes.
        var Same = 0
        for X in 52 ..< 100
        {
            if Pixel(Result, X, 60) == Pixel(Result, X + 1, 60)
            {
                Same += 1
            }
        }
        #expect(Same > 30)
        #expect(Pixel(Result, 10, 10) == Pixel(Plain, 10, 10))
    }

    @Test func SeveralFacesAreAllMarked() throws
    {
        let Other = FaceMark(Bounds: CGRect(x: 130, y: 30, width: 40, height: 40))
        let Result = try Marked([Face, Other], ["MODE": "OUTLINE", "PADDING": "0", "LINEWIDTH": "6", "COLOR": "FF0000FF"])
        #expect(Pixel(Result, 50, 60)[0] == 255)
        #expect(Pixel(Result, 130, 80)[0] == 255)
    }

    @Test func LandmarksAreOnlyDrawnWhenAsked() throws
    {
        let WithEyes = FaceMark(Bounds: CGRect(x: 50, y: 30, width: 60, height: 60), LeftEye: CGPoint(x: 70, y: 70), RightEye: CGPoint(x: 90, y: 70),
                                Mouth: CGPoint(x: 80, y: 45))
        let Off = try Marked([WithEyes], ["MODE": "OUTLINE", "PADDING": "0", "COLOR": "00FF00FF"])
        let On = try Marked([WithEyes], ["MODE": "OUTLINE", "PADDING": "0", "COLOR": "00FF00FF", "LANDMARKS": "true"])
        // The left eye is at x 70 and 70 up from the bottom, which is row 50 from the top.
        #expect(Pixel(On, 70, 50)[1] > 240 && Pixel(On, 70, 50)[0] == 0)
        #expect(Pixel(Off, 70, 50) != Pixel(On, 70, 50))
    }

    @Test func ThePaddedRectangleGrowsOnEverySide() throws
    {
        let Bigger = CIFaceDetector.Padded(CGRect(x: 100, y: 100, width: 40, height: 20), 0.5)
        #expect(Bigger == CGRect(x: 80, y: 90, width: 80, height: 40))
    }

    // MARK: The tree

    @Test func TheDetectionGroupHoldsBothFilters() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        func Find(_ Node: FilterNode, _ Name: String) -> FilterNode?
        {
            Node.Name == Name ? Node : (Node.Children ?? []).compactMap{Find($0, Name)}.first
        }
        let Group = try #require(Find(Root, "Detection"))
        #expect(Group.Children?.map{$0.Name} == ["Person Segmentation", "Face Detector"])
        #expect(Group.Leaves().compactMap{$0.Filter} == [CIPersonSegmentation.FilterName, CIFaceDetector.FilterName])
        let Server = FilterServer()
        #expect(Group.Leaves().allSatisfy{Server.GetFilter($0.Filter ?? "") != nil})
        let Core = try #require(Find(Root, "Core Image"))
        #expect(Core.Children?.contains{$0.Name == "Detection"} == true)
    }
}
