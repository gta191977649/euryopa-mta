


Building = class()

function Building:init()
    self.buildingPS = dxCreateShader("shader/buildingPS.fx",0,0,false,"world")
    self.neonPS = dxCreateShader("shader/leedsneon.fx",0,0,false,"world") 

    -- init shader
    self:initShader()

    -- params
    self.ambient = {0,0,0}
    self.gDayNightBalance = 1
    self.gWetRoadEffect = 0
    self.dayparam = {0,0,0,1}
    self.nightparam = {1,1,1,1}
    self.noExtraColors = false
end

function Building:initShader()
    if self.buildingPS then
        engineApplyShaderToWorldTexture(self.buildingPS,"*")
        for k, txd in pairs(textureListTable.BuildingPSRemoveList) do 
            engineRemoveShaderFromWorldTexture(self.buildingPS,txd)
        end
        outputChatBox("building shader inited.")
    end
    
    if self.neonPS then 
        engineApplyShaderToWorldTexture(self.neonPS,"*neon*")
        engineApplyShaderToWorldTexture(self.neonPS,"*lightalp*")
        engineApplyShaderToWorldTexture(self.neonPS,"tex_1_07c0")
        engineApplyShaderToWorldTexture(self.neonPS,"bow_abattoir_conc")
        outputChatBox("neon shader inited.")
    end
end

function Building:setAmbient(amb_r,amb_g,amb_b,light_multi)
    light_multi = light_multi or 1
    self.ambient = {amb_r *light_multi /255,amb_g *light_multi /255,amb_b*light_multi /255}

end

function Building:setDaynightBalance(balance)
    if balance < 0.0 then balance = 0.0 end
    if balance > 1.0 then balance = 1.0 end
    self.gDayNightBalance = balance
end

function Building:update() 
    if self.buildingPS then
        dxSetShaderValue(self.buildingPS,"ambient",{self.ambient[1],self.ambient[2],self.ambient[3]})
        -- dat night balance

        -- process daynight balance
        if not self.noExtraColors then
            self.dayparam = {1.0-self.gDayNightBalance,1.0-self.gDayNightBalance,1.0-self.gDayNightBalance,self.gWetRoadEffect}
            self.nightparam = {self.gDayNightBalance,self.gDayNightBalance,self.gDayNightBalance,1.0-self.gWetRoadEffect}
        end

        dxSetShaderValue(self.buildingPS,"dayparam",self.dayparam)
        dxSetShaderValue(self.buildingPS,"nightparam",self.nightparam)
    end
end