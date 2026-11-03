//
//  MirrorVertical.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
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

#include <metal_stdlib>
using namespace metal;

// Copies the top half of the image over the bottom half, flipped upside down, so the two halves meet with no seam.
// Each thread writes only its own pixel; pixels in the bottom half read from the mirrored row in the top half.
// For an odd height the center row is its own mirror and is left alone.
kernel void MirrorVerticalTT(texture2d<float, access::read> Input [[texture(0)]],
                           texture2d<float, access::write> Output [[texture(1)]],
                           uint2 Position [[thread_position_in_grid]])
{
    uint Height = Output.get_height();
    if (Position.x >= Output.get_width() || Position.y >= Height)
    {
        // Ignore invalid positions.
        return;
    }
    uint2 Source = Position;
    if (Position.y > (Height - 1) / 2)
    {
        Source.y = Height - 1 - Position.y;
    }
    Output.write(Input.read(Source), Position);
}
