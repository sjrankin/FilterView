//
//  ScaleMagentaColor.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
//

#include <metal_stdlib>
using namespace metal;

// Set the green to 0 and the red and blue channels to the mean of the red and blue channels
kernel void ScaleMagentaColor(texture2d<float, access::read> Input [[texture(0)]],
                           texture2d<float, access::write> Output [[texture(1)]],
                           uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    float Magenta = (Color.r + Color.b) / 2;
    Output.write(float4(Magenta, 0, Magenta, Color.a), Position);
}
