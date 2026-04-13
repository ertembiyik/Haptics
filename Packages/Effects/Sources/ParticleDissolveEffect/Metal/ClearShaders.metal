#include <metal_stdlib>
using namespace metal;

struct ClearVertexOut {
    float4 position [[position]];
};

vertex ClearVertexOut clearVertex(
    const device float2 *vertices [[buffer(0)]],
    unsigned int vid [[vertex_id]]
) {
    ClearVertexOut out;
    out.position = float4(vertices[vid], 0.0, 1.0);
    return out;
}

fragment float4 clearFragment(
    ClearVertexOut in [[stage_in]],
    const device float4 &color [[buffer(0)]]
) {
    return color;
}