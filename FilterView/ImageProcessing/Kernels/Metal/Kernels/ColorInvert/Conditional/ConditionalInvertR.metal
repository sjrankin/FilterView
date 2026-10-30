//
//  ConditionalInvertR.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
//

#include <metal_stdlib>
using namespace metal;

// Inverts only the red channel.
kernel void InvertColorR(texture2d<float, access::read> Input [[texture(0)]],
                        texture2d<float, access::write> Output [[texture(1)]],
                        uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    Output.write(float4(1.0 - Color.r, Color.g, Color.b, Color.a), Position);
}
