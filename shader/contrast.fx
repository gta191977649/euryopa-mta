texture tex;
float3 contrastMult;
float3 contrastAdd;

sampler TexSampler = sampler_state
{
    Texture = <tex>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct PS_INPUT
{
    float2 texcoord0 : TEXCOORD0;
};

float4 main(PS_INPUT IN) : COLOR
{
    float4 c = tex2D(TexSampler, IN.texcoord0);
    c.a = 1.0f;
    c.rgb = c.rgb * contrastMult + contrastAdd;
    return c;
}

technique ContrastTechnique
{
    pass P0
    {
        PixelShader = compile ps_2_0 main();
    }
}
