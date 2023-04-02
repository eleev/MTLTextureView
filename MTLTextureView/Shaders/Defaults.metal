//
//  Shaders.metal
//  TextureView
//
//  Created by Astemir Eleev on 02.04.2023.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Shaders

// Define the input vertex attributes
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

// Define the output vertex attributes
struct VertexOut {
    float2 texCoord [[user(locn0)]];
    float4 position [[position]];
};

// The vertex_passthrough function
vertex VertexOut vertex_passthrough(VertexIn in [[stage_in]]) {
    VertexOut out;

    // Pass through the position and texture coordinates
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;

    return out;
}

// Experimental page curl vertex transformation. Note that `curlAmount` needs to be set and update in the Renderer
vertex VertexOut page_curl_vertex(VertexIn in [[stage_in]], constant float2 &curlAmount [[buffer(1)]]) {
    VertexOut out;
    
    float2 pos = in.position;
    float2 uv = in.texCoord;
    
    float2 curlPos = pos * curlAmount;
    float curlLength = length(curlPos);
    float angle = (1.0 - curlLength) * 1.5 * atan2(curlAmount.y, curlAmount.x);
    
    float2x2 rotationMatrix = float2x2(cos(angle), -sin(angle),
                                       sin(angle), cos(angle));
    
    pos = pos - curlPos;
    pos = rotationMatrix * pos;
    pos = pos + curlPos;
    
    float folded = pos.x < curlPos.x ? 1.0 : 0.0;
    
    out.position = float4(pos, folded, 1.0);
    out.texCoord = uv;
    
    return out;
}

// MARK: - Fragment Shaders

// Define the input fragment attributes
struct FragmentIn {
    float2 texCoord [[user(locn0)]];
};

// The sampling_linear function
fragment float4 sampling_linear(FragmentIn in [[stage_in]],
                                texture2d<float> inputTexture [[texture(0)]],
                                sampler inputSampler [[sampler(0)]]) {
    // Sample the input texture using the input sampler and texture coordinates
    float4 color = inputTexture.sample(inputSampler, in.texCoord);

    return color;
}


fragment float4 page_curl_fragment(VertexOut in [[stage_in]],
                                   texture2d<float> tex [[texture(0)]],
                                   sampler smp [[sampler(0)]]) {
    float2 uv = in.texCoord;
    
    float folded = in.position.z;
    
    float2 flippedTexCoord = float2(1.0 - uv.x, uv.y);
    float4 color = tex.sample(smp, uv);
    float4 flippedColor = tex.sample(smp, flippedTexCoord);
    
    float reflection = 0.25 * (1.0 - smoothstep(0.1, 0.9, uv.x)) * folded;
    color = mix(color, flippedColor, reflection);
    
    return color;
}
