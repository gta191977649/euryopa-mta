local vcs_radiosity_blur1 = nil
local vcs_radiosity_blur2 = nil
local rt_radiosity = nil
local screenSource = nil
function radiosity_vcs_init()
    shaderBlurPS = dxCreateShader("shader/blurPS.fx", 0, 0, false)
    shaderRadiosityPS = dxCreateShader("shader/radiosityPS.fx", 0, 0, false)
    shaderAddblend = dxCreateShader("shader/addBlend.fx", 0, 0, false)
    local w, h = guiGetScreenSize()
    screenSource = dxCreateScreenSource(w, h)

    -- Use RTPool to get the radiosity render targets with dimensions w x h
    vcs_radiosity_blur1 = RTPool.GetUnused(w, h)
    vcs_radiosity_blur2 = RTPool.GetUnused(w, h)
    rt_radiosity = RTPool.GetUnused(w, h)
end

function doRadiosity(intensityLimit, filterPasses, renderPasses, intensity)
    if not vcs_radiosity_blur1 or not vcs_radiosity_blur2 or not rt_radiosity then
        radiosity_vcs_init()
    end

    local w, h = guiGetScreenSize()
    params = {}
    params[1] = 0
    params[2] = 1 / h
    params[3] = bitLShift(1, filterPasses)
    params[3] = params[3] * w / 640.0

    -- Blur Vertically
    dxUpdateScreenSource(screenSource, true)
    dxSetRenderTarget(vcs_radiosity_blur1)
    dxSetShaderValue(shaderBlurPS, "tex", screenSource)
    dxSetShaderValue(shaderBlurPS, "pxSz", {params[1], params[2], params[3]})
    dxDrawImage(0, 0, w, h, shaderBlurPS)

    -- Blur Horizontally
    dxSetRenderTarget(vcs_radiosity_blur2)
    params[1] = 1 / w
    params[2] = 0
    dxSetShaderValue(shaderBlurPS, "tex", vcs_radiosity_blur1)
    dxSetShaderValue(shaderBlurPS, "pxSz", {params[1], params[2], params[3]})
    dxDrawImage(0, 0, w, h, shaderBlurPS)

    -- Final Composite Pass
    dxSetRenderTarget()
    dxDrawImage(0, 0, w, h, vcs_radiosity_blur2, 0, 0, 0, tocolor(255, 255, 255, intensity))

    -- Radiosity Pass
    dxSetShaderValue(shaderRadiosityPS, "limit", intensityLimit  / 255.0)
    dxSetShaderValue(shaderRadiosityPS, "intensity", intensity  / 255.0)
    dxSetShaderValue(shaderRadiosityPS, "passes", renderPasses)

    local off = ((bitLShift(1, filterPasses)) - 1)
    local m_RadiosityFilterUCorrection, m_RadiosityFilterVCorrection = 2, 2
    local offu = off * m_RadiosityFilterUCorrection
    local offv = off * m_RadiosityFilterVCorrection
    local minu = offu
    local minv = offv
    local maxu = w - offu
    local maxv = h - offv
    local cu = (offu * (w + 0.5) + offu * 0.5) / w
    local cv = (offv * (h + 0.5) + offv * 0.5) / h

    params[1] = cu / w
    params[2] = cv / h
    params[3] = (maxu - minu) / w
    params[4] = (maxv - minv) / h
    dxSetShaderValue(shaderRadiosityPS, "xform", {params[1], params[2], params[3], params[4]})
    dxSetShaderValue(shaderRadiosityPS, "tex", vcs_radiosity_blur2)

    dxSetRenderTarget(rt_radiosity)

    dxDrawImage(0, 0, w, h, shaderRadiosityPS)
    dxSetRenderTarget()
    
    dxSetShaderValue(shaderAddblend, "src", rt_radiosity)
    --RwD3D9SetRenderState(D3DRS_BLENDFACTOR, D3DCOLOR_ARGB(0xFF, intensity*4, intensity*4, intensity*4));
    --[[
        RwD3D9SetRenderState(D3DRS_BLENDOP, D3DBLENDOP_REVSUBTRACT);
        RwD3D9SetRenderState(D3DRS_SRCBLEND, D3DBLEND_BLENDFACTOR);
        RwD3D9SetRenderState(D3DRS_DESTBLEND, D3DBLEND_ONE);
        RwD3D9SetRenderState(D3DRS_BLENDFACTOR, D3DCOLOR_ARGB(0xFF, limit/2, limit/2, limit/2));
    -]]
    dxDrawImage(0, 0, w, h, shaderAddblend, 0, 0, 0, tocolor(intensityLimit/2, intensityLimit/2, intensityLimit/2,0xFF))
end
