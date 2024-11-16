Timecyc = class()

-- Define field matrices with RGB and single values for different games
local FieldMatrices = {
    VCS = {
        {"Amb", 3}, {"Amb_Obj", 3}, {"Amb_bl", 3}, {"Amb_Obj_bl", 3},
        {"Dir", 3}, {"Sky_top", 3}, {"Sky_bot", 3}, {"SunCore", 3},
        {"SunCorona", 3}, {"SunSz", 1}, {"SprSz", 1}, {"SprBght", 1},
        {"Shdw", 1}, {"LightShd", 1}, {"PoleShd", 1}, {"FarClp", 1},
        {"FogSt", 1}, {"radiosityIntensity", 1}, {"radiosityLimit", 1}, {"LightOnGround", 1},
        {"LowCloudsRGB", 3}, {"TopCloudRGB", 3}, {"BottomCloudRGB", 3},
        {"BlurRGB", 3}, {"WaterRGBA", 4}, {"blurAlpha", 1}, {"blurOffset", 1}
    }
}

-- Fallback for unpack compatibility
local unpack = unpack or table.unpack

function Timecyc:init(timecycPath, game)
    self.timecycPath = timecycPath
    self.game = game
    self.matrix = FieldMatrices[game]
    self.data = {}
    self:loadTimecycFile()
    -- runtime values
    self.currentWeather = 1
    self.currentData = nil
    self.nextData = nil
    self.dayNightBalance = 0

    -- turn of SA effect
    setWorldSpecialPropertyEnabled ("coronaztest", false )
    resetFogDistance()
    resetFarClipDistance()
    resetColorFilter()
    setColorFilter(0,0,0, 0, 0, 0,0, 0 )
    setCloudsEnabled (false)
end

function Timecyc:loadTimecycFile()
    local file = fileOpen(self.timecycPath)
    if not file then
        outputChatBox("Failed to open timecyc file at: " .. self.timecycPath)
        return
    end

    -- Read the entire file into a string and split by lines
    local content = fileRead(file, fileGetSize(file))
    fileClose(file)
    local lines = split(content:gsub("\r", ""), '\n')  -- Remove carriage returns and split by newline

    local currentWeatherID = 0
    local currentTimeIndex = 0
    self.data = {}

    -- Loop through each line to parse the timecyc data
    for i, line in ipairs(lines) do
        -- Check if the line is a weather separator
        if string.find(line, "////////////") then
            currentWeatherID = currentWeatherID + 1  -- Increase weather ID
            currentTimeIndex = 0  -- Reset time index for the new weather section
        elseif line:sub(1, 1) ~= '/' and line:sub(2, 1) ~= '/' then
            -- This line contains actual time attributes
            local parsedLine = self:parseLine(line)
            if parsedLine then
                -- Initialize tables if they don’t exist and store parsed data
                currentTimeIndex = currentTimeIndex + 1  -- Move to the next time index
                self.data[currentWeatherID] = self.data[currentWeatherID] or {}
                self.data[currentWeatherID][currentTimeIndex] = parsedLine

            end
        end
    end

    outputChatBox("Loaded timecyc data for " .. self.game)
    outputChatBox("Total weather IDs found: " .. (currentWeatherID + 1))  -- Output the count of weather IDs
end



function Timecyc:isTimeMarker(line)
    return line[i]:sub(1, 1) ~= '/' and line[i]:sub(2, 1) ~= '/' 
end

function Timecyc:parseLine(line)
    local values = {}
    for num in line:gmatch("[-]?%d+%.?%d*") do
        table.insert(values, tonumber(num))
    end

    local parsedData, valueIndex = {}, 1
    for _, fieldInfo in ipairs(self.matrix) do
        local fieldName, count = fieldInfo[1], fieldInfo[2]
        if count == 1 then
            parsedData[fieldName] = values[valueIndex]
            valueIndex = valueIndex + 1
        else
            parsedData[fieldName] = {unpack(values, valueIndex, valueIndex + count - 1)}
            valueIndex = valueIndex + count
        end
    end
    return parsedData
end

function Timecyc:interpolateValue(a,b,fa,fb) 
    return fa * a + fb * b
end

function Timecyc:interpolateRGB(a1,b1,fa,fb) 
    local r = fa * a1[1] + fb * b1[1]
    local g = fa * a1[2] + fb * b1[2]
    local b = fa * a1[3] + fb * b1[3]
    return {r,g,b}
end

function Timecyc:interpolateRGBA(a1,b1,fa,fb) 
    local r = fa * a1[1] + fb * b1[1]
    local g = fa * a1[2] + fb * b1[2]
    local b = fa * a1[3] + fb * b1[3]
    local a = fa * a1[4] + fb * b1[4]
    return {r,g,b,a}
end

function Timecyc:getValue(type)
    return 
end

function Timecyc:updateDayNightBalance(currentHour, currentMinute)
    local minute = currentHour * 60.0 + currentMinute
    local morningStart = 6 * 60.0
    local morningEnd = 7 * 60.0
    local eveningStart = 20 * 60.0
    local eveningEnd = 21 * 60.0

    -- 1.0 is night, 0.0 is day
    if minute < morningStart then
        self.dayNightBalance = 1.0
    elseif minute < morningEnd then
        self.dayNightBalance = (morningEnd - minute) / (morningEnd - morningStart)
    elseif minute < eveningStart then
        self.dayNightBalance = 0.0
    elseif minute < eveningEnd then
        self.dayNightBalance = 1.0 - (eveningEnd - minute) / (eveningEnd - eveningStart)
    else
        self.dayNightBalance = 1.0
    end
end

function Timecyc:update(weatherID, time, minute)
    -- Adjust weatherID and map timeIndex to account for GTA's indexing and circular hour mapping
    weatherID = weatherID + 1  -- Increment since GTA starts weather ID at 0
    
    -- Map `time` and `minute` to fractional hour and calculate interpolation factor
    local fractionalHour = time + (minute / 60.0)
    local timeIndex = (time == 0) and 24 or time + 1
    local nextTimeIndex = (timeIndex % 24) + 1  -- Wrap around for next hour



    -- Access the data for current and next hour for the given weatherID
    self.currentData = self.data[weatherID] and self.data[weatherID][timeIndex]
    self.nextData = self.data[weatherID] and self.data[weatherID][nextTimeIndex]

    if not self.currentData or not self.nextData then
        outputChatBox("No data available for weather ID: " .. weatherID .. " at time index: " .. timeIndex)
        setWeather(1)
        return
    end

    
    -- Calculate interpolation factors
    local fa = 1 - (minute / 60.0)
    local fb = minute / 60.0
    -- Interpolate ambient color
    self.ambient = self:interpolateRGB(self.currentData.Amb, self.nextData.Amb, fa, fb)
    --iprint(ambient)
    setWorldProperty("AmbientColor", self.ambient[1], self.ambient[2], self.ambient[3])
   
    -- Interpolate ambient object color
    self.ambient_obj = self:interpolateRGB(self.currentData.Amb_Obj, self.nextData.Amb_Obj, fa, fb)
    setWorldProperty("AmbientObjColor", self.ambient_obj[1], self.ambient_obj[2], self.ambient_obj[3])

    -- Interpolate directional color
    self.directional = self:interpolateRGB(self.currentData.Dir, self.nextData.Dir, fa, fb)
    setWorldProperty("DirectionalColor", self.directional[1], self.directional[2], self.directional[3])

    -- Interpolate sky gradient
    self.skyTop = self:interpolateRGB(self.currentData.Sky_top, self.nextData.Sky_top, fa, fb)
    self.skyBot = self:interpolateRGB(self.currentData.Sky_bot, self.nextData.Sky_bot, fa, fb)
    setSkyGradient(self.skyTop[1], self.skyTop[2], self.skyTop[3], self.skyBot[1], self.skyBot[2], self.skyBot[3])

    -- Interpolate cloud colors
    self.cloudTop = self:interpolateRGB(self.currentData.TopCloudRGB, self.nextData.TopCloudRGB, fa, fb)
    setWorldProperty("BottomCloudsColor", self.cloudTop[1], self.cloudTop[2], self.cloudTop[3])

    -- local cloudBot = self:interpolateRGB(currentData.BottomCloudRGB, nextData.BottomCloudRGB, fa, fb)
    -- setWorldProperty("BottomCloudsColor", cloudBot[1], cloudBot[2], cloudBot[3])

    self.cloudLow = self:interpolateRGB(self.currentData.LowCloudsRGB, self.nextData.LowCloudsRGB, fa, fb)
    setWorldProperty("LowCloudsColor", self.cloudLow[1], self.cloudLow[2], self.cloudLow[3])

    -- Interpolate sun colors
    self.sunCore = self:interpolateRGB(self.currentData.SunCore, self.nextData.SunCore, fa, fb)
    self.sunCorona = self:interpolateRGB(self.currentData.SunCorona, self.nextData.SunCorona, fa, fb)
    setSunColor(self.sunCore[1], self.sunCore[2], self.sunCore[3], self.sunCorona[1], self.sunCorona[2], self.sunCorona[3])

    -- Interpolate sun size
    self.sunSize = self:interpolateValue(self.currentData.SunSz, self.nextData.SunSz, fa, fb)
    setSunSize(self.sunSize)

    -- Interpolate other properties
    --setWorldProperty("SpriteBrightness", self:interpolateValue(currentData.SprBght, nextData.SprBght, fa, fb))
    self.lightOnGround = self:interpolateValue(self.currentData.LightOnGround, self.nextData.LightOnGround, fa, fb)
    setWorldProperty("LightsOnGround",self.lightOnGround )
    setWorldProperty("ShadowStrength", self:interpolateValue(self.currentData.LightShd, self.nextData.LightShd, fa, fb))
    setWorldProperty("PoleShadowStrength", self:interpolateValue(self.currentData.PoleShd, self.nextData.PoleShd, fa, fb))
    
    setFarClipDistance(self:interpolateValue(self.currentData.FarClp, self.nextData.FarClp, fa, fb))
    setFogDistance(self:interpolateValue(self.currentData.FogSt, self.nextData.FogSt, fa, fb))
    -- water color
    self.waterRGBA = self:interpolateRGBA(self.currentData.WaterRGBA, self.nextData.WaterRGBA, fa, fb)
    setWaterColor(self.waterRGBA[1],self.waterRGBA[2],self.waterRGBA[3],self.waterRGBA[4])

    -- radiosity
    self.radiosityLimit = self:interpolateValue(self.currentData.radiosityLimit, self.nextData.radiosityLimit, fa, fb)
    self.radiosityIntensity = self:interpolateValue(self.currentData.radiosityIntensity, self.nextData.radiosityIntensity, fa, fb)
    
    -- color filter & blur
    self.colorFilterRGB = self:interpolateRGB(self.currentData.BlurRGB, self.nextData.BlurRGB, fa, fb)
    self.blurAlpha = self:interpolateValue(self.currentData.blurAlpha, self.nextData.blurAlpha, fa, fb)
    self.blurOffset = self:interpolateValue(self.currentData.blurOffset, self.nextData.blurOffset, fa, fb)


    -- update day & night cycle param
    self:updateDayNightBalance(time, minute)
    -- update weather id
    self.currentWeather = weatherID
end


