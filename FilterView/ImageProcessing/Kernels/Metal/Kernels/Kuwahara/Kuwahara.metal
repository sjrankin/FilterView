//
//  Kuwahara.metal
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
//

#include <metal_stdlib>
using namespace metal;

// Kuwahara filter: edge-preserving smoothing that gives a painted look.
// Four square windows (top-left, top-right, bottom-left, bottom-right) overlap at the pixel. Each is (Radius + 1) pixels
// on a side. The pixel gets the mean color of the window whose luminance varies the least, so flat areas are smoothed but
// a window that would straddle an edge is never chosen.
// buffer(0) is the radius in pixels.
kernel void Kuwahara(texture2d<float, access::read> Input [[texture(0)]],
                     texture2d<float, access::write> Output [[texture(1)]],
                     constant float& Radius [[buffer(0)]],
                     uint2 Position [[thread_position_in_grid]])
{
    int Width = int(Output.get_width());
    int Height = int(Output.get_height());
    if (int(Position.x) >= Width || int(Position.y) >= Height)
    {
        return;
    }
    int R = max(int(Radius), 1);
    int Count = (R + 1) * (R + 1);

    float BestVariance = INFINITY;
    float3 BestMean = Input.read(Position).rgb;
    for (int Quadrant = 0; Quadrant < 4; Quadrant++)
    {
        // Quadrants 0 and 2 extend left, 0 and 1 extend up.
        int StartX = (Quadrant % 2 == 0) ? -R : 0;
        int StartY = (Quadrant < 2) ? -R : 0;
        float3 Sum = float3(0.0);
        float LumaSum = 0.0;
        float LumaSquaredSum = 0.0;
        for (int DY = 0; DY <= R; DY++)
        {
            for (int DX = 0; DX <= R; DX++)
            {
                // Pixels past the edge of the image repeat the edge pixel.
                int X = clamp(int(Position.x) + StartX + DX, 0, Width - 1);
                int Y = clamp(int(Position.y) + StartY + DY, 0, Height - 1);
                float3 Color = Input.read(uint2(X, Y)).rgb;
                float Luma = dot(Color, float3(0.299, 0.587, 0.114));
                Sum += Color;
                LumaSum += Luma;
                LumaSquaredSum += Luma * Luma;
            }
        }
        float MeanLuma = LumaSum / float(Count);
        float Variance = LumaSquaredSum / float(Count) - MeanLuma * MeanLuma;
        if (Variance < BestVariance)
        {
            BestVariance = Variance;
            BestMean = Sum / float(Count);
        }
    }
    Output.write(float4(BestMean, Input.read(Position).a), Position);
}
