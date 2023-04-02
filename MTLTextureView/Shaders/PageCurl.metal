//
//  PageCurl.metal
//  TextureView
//
//  Created by Astemir Eleev on 02.04.2023.
//

#include <metal_stdlib>
using namespace metal;

/*
 Experimental additions for shader page flip transition
 */

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 normal;
    float folded;
};

vertex VertexOut page_flip_vertex(VertexIn in [[stage_in]],
                                  constant float2 &curlPosition [[buffer(0)]],
                                  constant float &curlAngle [[buffer(1)]]) {
    VertexOut out;
    
    float2 pos = in.position;
    float2 uv = in.texCoord;
    
    float2 curlPos = curlPosition * float2(2.0, 1.0) - 1.0;
    float foldDirection = uv.x <= curlPosition.x ? -1.0 : 1.0;
    float angle = curlAngle * foldDirection;
    
    float2x2 rotationMatrix = float2x2(cos(angle), -sin(angle),
                                       sin(angle), cos(angle));
    
    pos = pos - curlPos;
    pos = rotationMatrix * pos;
    pos = pos + curlPos;
    
    out.position = float4(pos, 0.0, 1.0);
    out.texCoord = uv;
    out.normal = float3(0.0, 0.0, 1.0);
    out.folded = uv.x <= curlPosition.x ? 1.0 : 0.0;
    
    return out;
}

fragment float4 page_flip_fragment(VertexOut in [[stage_in]],
                                   texture2d<float> tex [[texture(0)]],
                                   sampler smp [[sampler(0)]]) {
    float2 uv = in.texCoord;
    
    float folded = in.folded;
    
    float2 flippedTexCoord = float2(1.0 - uv.x, uv.y);
    float4 color = tex.sample(smp, uv);
    float4 flippedColor = tex.sample(smp, flippedTexCoord);
    
    float reflection = 0.25 * (1.0 - smoothstep(0.1, 0.9, uv.x)) * folded;
    color = mix(color, flippedColor, reflection);
    
    return color;
}
