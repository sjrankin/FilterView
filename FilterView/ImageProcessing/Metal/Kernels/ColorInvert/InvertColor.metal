//
//  InvertColor.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

#include <metal_stdlib>
using namespace metal;

// Simpler color inversion.
kernel void InvertColor(texture2d<float, access::read> Input [[texture(0)]],
                        texture2d<float, access::write> Output [[texture(1)]],
                        uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    Output.write(float4(1.0 - Color.rgb, Color.a), Position);
}
