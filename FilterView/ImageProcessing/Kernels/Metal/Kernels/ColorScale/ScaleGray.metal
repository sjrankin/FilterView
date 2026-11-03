//
//  ScaleGray.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
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

// Grayscale included only for orthagonality. Take the mean of red, green, and blue and populates
// all channels with that value.
kernel void ScaleGray(texture2d<float, access::read> Input [[texture(0)]],
                   texture2d<float, access::write> Output [[texture(1)]],
                   uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    float Mean = (Color.r + Color.g + Color.b) / 3;
    Output.write(float4(Mean, Mean, Mean, Color.a), Position);
}
