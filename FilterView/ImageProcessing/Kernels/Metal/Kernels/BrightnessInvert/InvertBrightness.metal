//
//  InvertBrightness.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

#include <metal_stdlib>
using namespace metal;

// Invert the brightness of each pixel. Uses Rec. 709 for brightness.
kernel void InvertBrightness(texture2d<float, access::read> Input [[texture(0)]],
                        texture2d<float, access::write> Output [[texture(1)]],
                        uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    float Brightness = dot(Color.rgb, float3(0.2126, 0.7152, 0.0722));
    float Inverted = 1.0 - Brightness;
    Output.write(float4(float3(Inverted), Color.a), Position);
}
