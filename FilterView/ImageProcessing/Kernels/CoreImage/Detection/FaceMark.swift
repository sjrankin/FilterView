//
//  FaceMark.swift
//  FilterView
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

import Foundation
import CoreGraphics

/// One face found in an image, in Core Image's coordinates (the origin is the bottom left corner of the image).
struct FaceMark: Equatable
{
    /// The rectangle around the face.
    var Bounds: CGRect
    var LeftEye: CGPoint? = nil
    var RightEye: CGPoint? = nil
    var Mouth: CGPoint? = nil
}
