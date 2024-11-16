
addEventHandler( "onClientResourceStart",resourceRoot,function ( startedRes )
    setOcclusionsEnabled(false)
    -- Init timecyc
    timecyc = Timecyc:new("data/timecyc_vcs.dat", "VCS")
    buildingPipeline = Building:new()
    buildingPipeline.noExtraColors = true
    postFX = PostEffects()
    enableBloom()

    addEventHandler("onClientHUDRender",root,function() 
        local h,m = getTime()
        local wea = getWeather()
        timecyc:update(wea,h,m)
      
        -- process pipeline
        local amb = timecyc.ambient
        --local dir = timecyc.lightOnGround
        buildingPipeline:setAmbient(amb[1],amb[2],amb[3],1)
        if not buildingPipeline.noExtraColors then --update online if extra color is on
            buildingPipeline:setDaynightBalance(timecyc.dayNightBalance)
        end

        buildingPipeline:update()

        -- do vcs trails
        local radiosityLimit = timecyc.radiosityLimit/2 / 255
        local radiosityIntensity = timecyc.radiosityIntensity / 255

        postFX:doRadiosity(radiosityLimit, radiosityIntensity)
        -- do vcs extra bloom
        setBloomParameter(timecyc.radiosityIntensity,timecyc.radiosityLimit) 

        -- do vcs blur
        local blurRGB = timecyc.colorFilterRGB
        local blurAlpha = timecyc.blurAlpha
        local blurOffset = timecyc.blurOffset
        postFX:doBlurOverlay(blurAlpha,blurOffset, {r = 0, g = 0, b = 0})
        -- finally  do colorfilteer
        setColorFilter(blurRGB[1],blurRGB[2],blurRGB[3],blurAlpha, blurRGB[1],blurRGB[2],blurRGB[3],blurAlpha )

    end,false,"low")

    -- debug ui
    ui = UI:new()
end)

