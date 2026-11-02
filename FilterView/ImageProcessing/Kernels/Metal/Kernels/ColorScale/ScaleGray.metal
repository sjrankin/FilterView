//
//  ScaleGray.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
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
