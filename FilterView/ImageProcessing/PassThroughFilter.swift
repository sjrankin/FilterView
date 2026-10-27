//
//  PassThroughFilter.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics

class PassThroughFilter: ImageFilter
{
    static let FilterName = "Passthrough"
    
    var FilterType: ImageFilterTypes
    {
        .Infrastructure
    }
    
    func ProcessImage(_ Input: CGImage) async throws -> CGImage
    {
        try Task.checkCancellation()
        return Input
    }
}
