//
// Example shader - addBlend.fx
//
// Add pixels to render target
//

//---------------------------------------------------------------------
// addBlend settings
//---------------------------------------------------------------------
texture src;


//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique addblend
{
    pass P0
    {
        SrcBlend			= 14; //  D3DBLEND_BLENDFACTOR
        DestBlend			= ONE;
        BLENDOP          = 3; //D3DBLENDOP_REVSUBTRACT

        // Set up texture stage 0
        Texture[0] = src;
    }
}