//
//  InvertBrightnessKeepColor.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
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

// Inverts the Rec. 709 brightness of each pixel while keeping its color.
// The pixel's color offset from gray is kept, the brightness is set to 1 - Brightness, and the offset is
// reduced only as much as needed to keep every channel in range. Very saturated pixels near the extremes
// therefore lose some saturation, but the new brightness is always exact.
kernel void InvertBrightnessKeepColor(texture2d<float, access::read> Input [[texture(0)]],
                                      texture2d<float, access::write> Output [[texture(1)]],
                                      uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    float Brightness = dot(Color.rgb, float3(0.2126, 0.7152, 0.0722));
    float Target = 1.0 - Brightness;
    float3 Chroma = Color.rgb - Brightness;
    float Scale = 1.0;
    for (int Channel = 0; Channel < 3; Channel++)
    {
        if (Chroma[Channel] > 0.0)
        {
            Scale = min(Scale, (1.0 - Target) / Chroma[Channel]);
        }
        else if (Chroma[Channel] < 0.0)
        {
            Scale = min(Scale, Target / -Chroma[Channel]);
        }
    }
    float3 Result = Target + Chroma * Scale;
    Output.write(float4(Result, Color.a), Position);
}
