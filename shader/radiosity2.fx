// Shared variables
float2 screenSize = float2(256, 128);
float4 xform;      // xy = offset, zw = scale
float limit;       // radiosity limit
float intensity;   // radiosity intensity
float passes;      // number of passes

texture sourceTexture;
texture previousPass;

sampler SourceSampler = sampler_state {
    Texture = <sourceTexture>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

sampler PreviousPassSampler = sampler_state {
    Texture = <previousPass>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

// Downsample pass
float4 DownsamplePS(float2 texCoord : TEXCOORD0) : COLOR0 
{
    // Transform UV coordinates using xform
    float2 uv = texCoord * xform.zw + xform.xy;
    float4 color = tex2D(SourceSampler, uv);
    
    // Apply initial radiosity calculation
    float4 radiosity = saturate(color * 2.0 - float4(limit, limit, limit, limit));
    color += radiosity * intensity * passes;
    color.a = 1.0;
    
    return color;
}

// Blur pass
static const float2 offsets[8] = {
    float2(-1, -1), float2(0, -1), float2(1, -1),
    float2(-1,  0),                float2(1,  0),
    float2(-1,  1), float2(0,  1), float2(1,  1)
};

float4 BlurPS(float2 texCoord : TEXCOORD0) : COLOR0 
{
    float4 center = tex2D(PreviousPassSampler, texCoord);
    float4 blurred = center;
    
    // Apply blur
    for(int i = 0; i < 8; i++) {
        float2 offset = offsets[i] / screenSize;
        blurred += tex2D(PreviousPassSampler, texCoord + offset);
    }
    blurred /= 9.0;
    
    return blurred;
}

// Final composition pass
float4 FinalBlendPS(float2 texCoord : TEXCOORD0) : COLOR0 
{
    // Get the original color and blur result
    float2 originalUV = texCoord * xform.zw + xform.xy;
    float4 original = tex2D(SourceSampler, originalUV);
    float4 blurred = tex2D(PreviousPassSampler, texCoord);
    
    // Apply the radiosity blend to the blurred result
    float4 radiosity = saturate(blurred * 2.0 - float4(limit, limit, limit, limit));
    float4 result = original + (radiosity * intensity * passes);
    result.a = 1.0;
    
    return result;
}

float4 TestShit(float2 texCoord : TEXCOORD0) : COLOR0 
{
    float4 color = tex2D(SourceSampler, texCoord);
    return color;
}
technique Radiosity
{   
    // pass Test{
    //     PixelShader =  compile ps_2_0 TestShit();
    // }

    pass P0 // Downsample with initial radiosity
    {
        PixelShader = compile ps_2_0 DownsamplePS();
        CullMode = None;
        AlphaBlendEnable = false;  // Disable blending for initial pass
    }
    
    pass P1 // Blur
    {
        PixelShader = compile ps_2_0 BlurPS();
        AlphaBlendEnable = false;  // Let the shader handle the blur
    }
    
    pass P2 // Final composition
    {
        PixelShader = compile ps_2_0 FinalBlendPS();
        AlphaBlendEnable = false;  // Let the shader handle the blur
    }
}