//
//  MPSCannyTests.swift
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
@testable import FilterView

@MainActor
struct MPSCannyTests
{
    /// Black with a white square from 20 to 44 in a 64 x 64 image.
    private func Square() -> CGImage
    {
        let Context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        Context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        Context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        Context.fill(CGRect(x: 20, y: 20, width: 24, height: 24))
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

    /// The number of pixels brighter than half.
    private func EdgePixels(_ Image: CGImage) -> Int
    {
        var Count = 0
        for Y in 0 ..< Image.height
        {
            for X in 0 ..< Image.width where Pixel(Image, X, Y)[0] > 127
            {
                Count += 1
            }
        }
        return Count
    }

    @Test func FindsThinWhiteEdgesOnBlack() async throws
    {
        let Result = try await FilterServer().Run(Filter: MPSCanny.FilterName, With: Square(), nil)
        #expect(Result.width == 64 && Result.height == 64)
        // Inside the square and far outside it there is no edge, and the edge is gray (all channels the same) and opaque.
        #expect(Pixel(Result, 32, 32)[0] == 0)
        #expect(Pixel(Result, 3, 3)[0] == 0)
        #expect(Pixel(Result, 32, 32)[3] == 255)
        let Edge = EdgePixels(Result)
        // About the outline of the square: 4 sides of 24, a pixel or two wide.
        #expect(Edge > 60 && Edge < 400)
        var Gray = true
        for X in 14 ..< 50
        {
            let Value = Pixel(Result, X, 20)
            Gray = Gray && Value[0] == Value[1] && Value[1] == Value[2]
        }
        #expect(Gray)
    }

    /// A dim square (gray 0.25) on black, whose edges are weak.
    private func DimSquare() -> CGImage
    {
        let Context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        Context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        Context.setFillColor(CGColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1))
        Context.fill(CGRect(x: 20, y: 20, width: 24, height: 24))
        return Context.makeImage()!
    }

    @Test func AHigherThresholdDropsWeakEdges() async throws
    {
        let Server = FilterServer()
        let Normal = try await Server.Run(Filter: MPSCanny.FilterName, With: DimSquare(), nil)
        let Strict = try await Server.Run(Filter: MPSCanny.FilterName, With: DimSquare(), ["HIGH": "0.8", "LOW": "0.4"])
        let Loose = try await Server.Run(Filter: MPSCanny.FilterName, With: DimSquare(), ["HIGH": "0.05", "LOW": "0.02"])
        #expect(EdgePixels(Normal) > 0)
        #expect(EdgePixels(Strict) == 0)
        #expect(EdgePixels(Loose) > 0)
    }

    @Test func ALowThresholdAboveTheHighOneIsMadeEqualToIt() async throws
    {
        let Result = try await FilterServer().Run(Filter: MPSCanny.FilterName, With: Square(), ["HIGH": "0.3", "LOW": "0.9"])
        #expect(Result.width == 64)
    }

    @Test func TheFullAlgorithmAlsoRuns() async throws
    {
        let Result = try await FilterServer().Run(Filter: MPSCanny.FilterName, With: Square(), ["FAST": "false"])
        #expect(EdgePixels(Result) > 0)
    }

    @Test func ItIsInTheMetalEdgesGroup() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        func Find(_ Node: FilterNode, _ Name: String) -> FilterNode?
        {
            Node.Name == Name ? Node : (Node.Children ?? []).compactMap{Find($0, Name)}.first
        }
        let Metal = try #require(Find(Root, "Metal"))
        let Edges = try #require(Find(Metal, "Edges"))
        #expect(Edges.Children?.map{$0.Name} == ["Sobel", "Laplacian", "Canny"])
        let Entry = try #require(Find(Edges, "Canny"))
        #expect(Entry.Filter == MPSCanny.FilterName)
        #expect(Entry.Parameters?.map{$0.Key} == ["SIGMA", "HIGH", "LOW", "FAST"])
        #expect(FilterServer().GetFilter(MPSCanny.FilterName) != nil)
    }
}
