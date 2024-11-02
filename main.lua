
addEventHandler( "onClientResourceStart",resourceRoot,function ( startedRes )
    -- Init timecyc
    timecyc = Timecyc:new("data/timecyc_vcs.dat", "VCS")


    postFX = PostEffects()

    addEventHandler("onClientHUDRender",root,function() 
        local h,m = getTime()
        local wea = getWeather()
        timecyc:update(wea,h,m)

        -- do vcs trails
        local radiosityLimit = timecyc.currentData["radiosityLimit"] /255
        local radiosityIntensity = timecyc.currentData["radiosityIntensity"] /255
        postFX:doRadiosity(radiosityLimit, radiosityIntensity)
        -- do vcs blur
        local blurRGB = timecyc.currentData["BlurRGB"]
        local blurAlpha = timecyc.currentData["blurAlpha"]
        local blurOffset = timecyc.currentData["blurOffset"]
        --postFX:doBlurOverlay(blurAlpha, blurOffset, {r = 0, g = 0, b = 0})
        -- do colorfilteer
        setColorFilter(blurRGB[1],blurRGB[2],blurRGB[3],blurAlpha, blurRGB[1],blurRGB[2],blurRGB[3],blurAlpha )

    
    end,false,"low")



    -- debug ui
    ui = UI:new()
end)