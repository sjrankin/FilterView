//
//  ScaleGreenColor.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
//

#include <metal_stdlib>
using namespace metal;

// Set the red and blue channels to 0, leaving only green.
kernel void ScaleGreenColor(texture2d<float, access::read> Input [[texture(0)]],
                            texture2d<float, access::write> Output [[texture(1)]],
                            uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    Output.write(float4(0, Color.g, 0, Color.a), Position);
}
