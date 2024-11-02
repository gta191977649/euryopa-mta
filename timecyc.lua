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


    -- turn of SA effect
    setWorldSpecialPropertyEnabled ("coronaztest", false )
    resetFogDistance()
    resetFarClipDistance()
    resetColorFilter()
    setColorFilter(0,0,0, 0, 0, 0,0, 0 )
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
    local ambient = self:interpolateRGB(self.currentData.Amb, self.nextData.Amb, fa, fb)
    setWorldProperty("AmbientColor", ambient[1], ambient[2], ambient[3])

    -- Interpolate ambient object color
    local ambient_obj = self:interpolateRGB(self.currentData.Amb_Obj, self.nextData.Amb_Obj, fa, fb)
    setWorldProperty("AmbientObjColor", ambient_obj[1], ambient_obj[2], ambient_obj[3])

    -- Interpolate directional color
    local directional = self:interpolateRGB(self.currentData.Dir, self.nextData.Dir, fa, fb)
    setWorldProperty("DirectionalColor", directional[1], directional[2], directional[3])

    -- Interpolate sky gradient
    local skyTop = self:interpolateRGB(self.currentData.Sky_top, self.nextData.Sky_top, fa, fb)
    local skyBot = self:interpolateRGB(self.currentData.Sky_bot, self.nextData.Sky_bot, fa, fb)
    setSkyGradient(skyTop[1], skyTop[2], skyTop[3], skyBot[1], skyBot[2], skyBot[3])

    -- Interpolate cloud colors
    local cloudTop = self:interpolateRGB(self.currentData.TopCloudRGB, self.nextData.TopCloudRGB, fa, fb)
    setWorldProperty("BottomCloudsColor", cloudTop[1], cloudTop[2], cloudTop[3])

    -- local cloudBot = self:interpolateRGB(currentData.BottomCloudRGB, nextData.BottomCloudRGB, fa, fb)
    -- setWorldProperty("BottomCloudsColor", cloudBot[1], cloudBot[2], cloudBot[3])

    local cloudLow = self:interpolateRGB(self.currentData.LowCloudsRGB, self.nextData.LowCloudsRGB, fa, fb)
    setWorldProperty("LowCloudsColor", cloudLow[1], cloudLow[2], cloudLow[3])

    -- Interpolate sun colors
    local sunCore = self:interpolateRGB(self.currentData.SunCore, self.nextData.SunCore, fa, fb)
    local sunCorona = self:interpolateRGB(self.currentData.SunCorona, self.nextData.SunCorona, fa, fb)
    setSunColor(sunCore[1], sunCore[2], sunCore[3], sunCorona[1], sunCorona[2], sunCorona[3])

    -- Interpolate sun size
    local sunSize = self:interpolateValue(self.currentData.SunSz, self.nextData.SunSz, fa, fb)
    setSunSize(sunSize)

    -- Interpolate other properties
    --setWorldProperty("SpriteBrightness", self:interpolateValue(currentData.SprBght, nextData.SprBght, fa, fb))
    setWorldProperty("LightsOnGround", self:interpolateValue(self.currentData.LightOnGround, self.nextData.LightOnGround, fa, fb))
    setWorldProperty("ShadowStrength", self:interpolateValue(self.currentData.LightShd, self.nextData.LightShd, fa, fb))
    setWorldProperty("PoleShadowStrength", self:interpolateValue(self.currentData.PoleShd, self.nextData.PoleShd, fa, fb))
    
    setFarClipDistance(self:interpolateValue(self.currentData.FarClp, self.nextData.FarClp, fa, fb))
    setFogDistance(self:interpolateValue(self.currentData.FogSt, self.nextData.FogSt, fa, fb))

    -- radiocity
    -- local radiosityIntensity = self:interpolateValue(currentData.radiosityIntensity, nextData.radiosityIntensity, fa, fb)
    -- local radiosityLimit = self:interpolateValue(currentData.radiosityLimit, nextData.radiosityLimit, fa, fb)
    -- --doRadiosity(radiosityLimit, 2, 1, radiosityIntensity)
    self.currentWeather = weatherID
end


