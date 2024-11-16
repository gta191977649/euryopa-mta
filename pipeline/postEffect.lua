-- Converted From PostEffects.cpp
-- By Nurupo

local screenW, screenH = guiGetScreenSize()

PostEffects = class()

function PostEffects:init()

    self.effects = {}
    self.lastEffect = nil  -- For effect chaining
    
    if not self:radiosityInit() then
        outputDebugString("Failed to initialize Radiosity", 1)
        return false
    end
    
    if not self:blurOverlayInit() then
        outputDebugString("Failed to initialize BlurOverlay", 1)
        return false
    end
    
    -- Add cleanup on resource stop
    addEventHandler("onClientResourceStop", resourceRoot, function()
        self:destroy()
        RTPool.clear()
    end)

    -- Add frame start handler
    addEventHandler("onClientHUDRender", root, function()
        self:frameStart()
    end,false,"low")

    
    return true
end

function PostEffects:frameStart()
    self.lastEffect = nil
    RTPool.frameStart()
    DebugResults.frameStart()

    DebugResults.drawItems (70, 0, 100)
end

function PostEffects:captureScreen()
    -- Update screen source first
    if not dxUpdateScreenSource(self.radiosity.screenSource) then
        return nil
    end
    
    local rt = RTPool.GetUnused(screenW, screenH)
    if rt then
        dxSetRenderTarget(rt)
        dxDrawImage(0, 0, screenW, screenH, self.radiosity.screenSource)
        dxSetRenderTarget()
    end
    return rt
end

function PostEffects:radiosityInit()
    self.radiosity = {
        radiosityShader = nil,
        screenSource = nil,
        xform = {0, 0, 1, 1},
        passes = 1
    }
    
    -- Create shader
    self.radiosity.radiosityShader = dxCreateShader("shader/radiosity2.fx")
    if not self.radiosity.radiosityShader then
        outputDebugString("Failed to create radiosity shader", 1)
        return false
    end
    
    -- Create screen source
    self.radiosity.screenSource = dxCreateScreenSource(screenW, screenH)
    if not self.radiosity.screenSource then
        outputDebugString("Failed to create screen source", 1)
        self:destroy()
        return false
    end
    
    return true
end

function PostEffects:doRadiosity(limit, intensity)
    local r = self.radiosity
    if not r.radiosityShader then return false end
    
    -- Get initial screen content
    local sourceRT = self.lastEffect or self:captureScreen()
    if not sourceRT then return false end
    
    -- Get render targets from pool
    local rt1 = RTPool.GetUnused(256, 128)
    local rt2 = RTPool.GetUnused(256, 128)
    local resultRT = RTPool.GetUnused(screenW, screenH)
    if not rt1 or not rt2 or not resultRT then return false end
    
    -- Set shader parameters
    dxSetShaderValue(r.radiosityShader, "xform", unpack(r.xform))
    dxSetShaderValue(r.radiosityShader, "limit", limit)
    dxSetShaderValue(r.radiosityShader, "intensity", intensity)
    dxSetShaderValue(r.radiosityShader, "passes", r.passes)
    dxSetShaderValue(r.radiosityShader, "screenSize", 256, 128)
    
    -- Downsample with initial radiosity to RT1
    dxSetRenderTarget(rt1)
    dxSetShaderValue(r.radiosityShader, "sourceTexture", sourceRT)
    dxDrawImage(0, 0, 256, 128, r.radiosityShader)
    
    -- Process blur (4 iterations)
    for i = 1, 4 do
        dxSetRenderTarget(rt2)
        dxSetShaderValue(r.radiosityShader, "previousPass", rt1)
        dxDrawImage(0, 0, 256, 128, r.radiosityShader)
        
        rt1, rt2 = rt2, rt1
    end
    
    -- Final composition to resultRT
    dxSetRenderTarget(resultRT)
    dxSetShaderValue(r.radiosityShader, "previousPass", rt1)
    dxSetShaderValue(r.radiosityShader, "sourceTexture", sourceRT)
    dxDrawImage(0, 0, screenW, screenH, r.radiosityShader)
    -- For debugging
    DebugResults.addItem(resultRT, "Radiosity")
    -- Draw to screen
    dxSetRenderTarget()
    dxDrawImage(0, 0, screenW, screenH, resultRT)
    
    -- Store result for next effect
    self.lastEffect = resultRT
    

    return true
end

function PostEffects:blurOverlayInit()
    self.blurOverlay = {
        blurShader = nil,
        justInitialized = true
    }
    
    -- Create shader
    self.blurOverlay.blurShader = dxCreateShader("shader/bluroverlay.fx")
    if not self.blurOverlay.blurShader then
        outputDebugString("Failed to create blur overlay shader", 1)
        return false
    end
    
    return true
end

function PostEffects:doBlurOverlay(intensity, offset, color)
    local b = self.blurOverlay
    if not b.blurShader then return false end
    
    -- Get source from previous effect or screen
    local sourceRT = self.lastEffect or self:captureScreen()
    if not sourceRT then return false end
    
    -- Get render targets from pool (matching original buffer usage)
    local currentFb = RTPool.GetUnused(screenW, screenH)    -- Like ms_pCurrentFb
    local blurBuffer = RTPool.GetUnused(screenW, screenH)   -- Like ms_pBlurBuffer
    local resultRT = RTPool.GetUnused(screenW, screenH)     -- For final result
    if not currentFb or not blurBuffer or not resultRT then return false end
    
    -- Scale offset to match original implementation
    local scaledOffset = offset * (1/1920) -- Scale based on a reference resolution
    
    -- Store current frame in currentFb (like RwRasterRenderFast in original)
    dxSetRenderTarget(currentFb)
    dxDrawImage(0, 0, screenW, screenH, sourceRT)
    
    -- Calculate intensity for blend factor (matching original intensity = intensityf*0.8f)
    local blendIntensity = math.floor(intensity * 0.8 )
    local blendColor = tocolor(blendIntensity, blendIntensity, blendIntensity, 255)
    
    -- Apply blur with intensity blend
    dxSetRenderTarget(resultRT)
    dxSetShaderValue(b.blurShader, "sourceTexture", currentFb)
    dxSetShaderValue(b.blurShader, "blurBuffer", blurBuffer)
    dxSetShaderValue(b.blurShader, "offset", scaledOffset)
    dxSetShaderValue(b.blurShader, "overlayColor", color.r/255, color.g/255, color.b/255, 1)
    dxSetShaderValue(b.blurShader, "isInitialized", not b.justInitialized)
    dxDrawImage(0, 0, screenW, screenH, b.blurShader, 0, 0, 0, blendColor)
    -- For debugging
    DebugResults.addItem(resultRT, "BlurOverlay")
    -- Add to blur buffer if not first frame
    if not b.justInitialized then
        dxSetRenderTarget(blurBuffer)
        dxDrawImage(0, 0, screenW, screenH, resultRT)
        DebugResults.addItem(blurBuffer, "BlurBuffer")
    else
        b.justInitialized = false
    end
    
    -- Draw final result to screen
    dxSetRenderTarget()
    dxDrawImage(0, 0, screenW, screenH, resultRT)
    
    -- Store result for next effect
    self.lastEffect = resultRT
    
   
    return true
end

function PostEffects:destroy()
    -- Destroy radiosity resources
    if self.radiosity then
        if isElement(self.radiosity.radiosityShader) then
            destroyElement(self.radiosity.radiosityShader)
        end
        if isElement(self.radiosity.screenSource) then
            destroyElement(self.radiosity.screenSource)
        end
        self.radiosity = nil
    end
    
    -- Destroy blur overlay resources
    if self.blurOverlay then
        if isElement(self.blurOverlay.blurShader) then
            destroyElement(self.blurOverlay.blurShader)
        end
        self.blurOverlay = nil
    end
    
    self.lastEffect = nil
end
