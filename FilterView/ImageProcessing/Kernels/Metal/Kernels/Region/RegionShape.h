//
//  RegionShape.h
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
//

#ifndef RegionShape_h
#define RegionShape_h

#include <metal_stdlib>
using namespace metal;

// The region shared by the kernels that change the pixels inside a shape (AlphaShape and ColorRegion). Both read these parameters from
// buffer 0, all floats, so the region is the same for both:
//   0-1: center of the shape in pixels, from the top left of the image.
//   2:   shape: 0 circle, 1 oval, 2 square, 3 rectangle.
//   5-6: half the length of the shape's long axis and of its short axis, in pixels. A circle and a square use the first for both.
//   7:   angle of the long axis in radians, clockwise from the horizontal as the image is shown. Circles and squares ignore it.
// (3, 4, and 8 are the mode, the value, and invert, which each kernel reads for itself.)
// Where the shape goes beyond the image the distance is still worked out as if the image went on, so the part that shows is the part of
// the effect that falls on the image.

/// How far out a pixel is: 0 at the center of the shape and 1 on its edge, more than 1 outside it.
inline float RegionDistance(uint2 Position, constant float *Parameters)
{
    float2 Center = float2(Parameters[0], Parameters[1]);
    int Shape = int(Parameters[2] + 0.5);
    float2 Half = max(float2(Parameters[5], Parameters[6]), float2(0.0001));
    float Angle = Parameters[7];

    // The pixel's place relative to the center, and along the shape's own axes.
    float2 Offset = float2(Position) + 0.5 - Center;
    float Cosine = cos(Angle);
    float Sine = sin(Angle);
    float2 Local = float2(Offset.x * Cosine + Offset.y * Sine, -Offset.x * Sine + Offset.y * Cosine);

    switch (Shape)
    {
        case 0:
            return length(Offset) / Half.x;

        case 1:
            return length(Local / Half);

        case 2:
            return max(abs(Offset.x), abs(Offset.y)) / Half.x;

        default:
            return max(abs(Local.x) / Half.x, abs(Local.y) / Half.y);
    }
}

#endif
