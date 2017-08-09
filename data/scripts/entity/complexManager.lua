package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/entity/ui/complexManager/?.lua"
package.path = package.path .. ";data/scripts/entity/?.lua"
require ("utility")
require ("faction")
require ("defaultscripts")
require ("randomext")
require ("stationextensions")
require ("productions")
require ("goods")
require("stringutility")
require("constructionTab")
require("overviewTab")
require("tradingTab")
--require("complexFactory")
Dialog = require("dialogutility")


VERSION = "[0.87] "
MOD = "[CPX3]"

DEBUGLEVEL = 2

COMPLEXINTEGRITYCHECK = 60   --every 60 seconds
CFSCRIPT = "data/scripts/entity/merchants/complexFactory.lua"
FSCRIPT = "data/scripts/entity/merchants/factory.lua"
-- Menu items
local window

--UI Renderer
local selectedTab = 1               --1:BCU, 2:ICU, 3:TCU

--Complex Data
local indexedComplexData = {}   --[priority] = {["factoryBlockId"] = num, ["relativeCoords"] = vec3(x,y,z), ["nodeOffset"] = vec3(x,y,z), ["factoryTyp"] = {}, ["size"] = num, ["name"] = ""}
local currentNodeID
local currentNodeOffset = vec3(0,0,0)
local targetCoreBlockIndex
local targetCoreBlockCoord
local productionData = {}
local constructionData = {}     --{[buildorder] = {[BlockID]= ["position"] = {x,y,z}, ["size"] = {x,y,z}, ["rootID"] = rootID}}}
local bonusValues = {}

local timepassedAfterLastCheck = 65

function debugPrint(debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end

function initialize()
    local station = Entity()
    if Player().index ~= station.factionIndex then
        debugPrint(0," wrong player called")
    end
    if onClient() then
        if Entity():hasScript(CFSCRIPT) then         
            EntityIcon().icon = "data/textures/icons/pixel/crate.png"
        end
        InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
    end

end

function getIcon()
    return "data/textures/icons/blockstats.png"
end


-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)
    if Player().index ~= Entity().factionIndex then
        debugPrint(0, " wrong player called")
        return false
    end
    return true
end

-- create all required UI elements for the client side
function initUI()
    
    local res = getResolution()*0.9
    local size = vec2(1100, 800)
    
    synchComplexdata(nil, nil, true)
    
    local menu = ScriptUI()
    window = menu:createWindow(Rect(getResolution()*0.5 - res * 0.5, getResolution()*0.5 + res*0.5))

    window.caption = "Complex Manager"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Build Complex"%_t);
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), window.size))
    tabbedWindow.onSelectedFunction = "onSelectedFunction"
--===============================================================================Build Complex UI======================================================================================================
    local constructionTab = tabbedWindow:createTab("BCU"%_t, "data/textures/icons/brick-pile.png", "Complex Construction"%_t)
    createConstructionUI(constructionTab)
    
--===============================================================================Info Complex UI=======================================================================================================
    local infoTab = tabbedWindow:createTab("ICU"%_t, "data/textures/icons/blockstats.png", "Complex Overview"%_t)
    createOverviewUI(infoTab)
    
--===============================================================================Trading Complex UI====================================================================================================
    local tradingTab = tabbedWindow:createTab("TCU"%_t, "data/textures/icons/trade.png", "Complex Trading Overview"%_t)
    createTradingUI(tradingTab)
end

-- this function gets called every time the window is shown on the client, ie. when a player presses F
function onShowWindow()
    invokeServerFunction("removeMissingFactories")
    updateStationCombo()
end

function renderUI()
    if selectedTab == 1 then
        cTRenderUI()
    end
    if selectedTab == 2 then
        
    end
    if selectedTab == 3 then
        
    end
end

function getUpdateInterval()
    return 0.05
end

function update(timeStep)                                               --checking if selection in the List has changed
    if onClient() then
        updateOT(timeStep)
        updateTT(timeStep)
    else
        timepassedAfterLastCheck = timepassedAfterLastCheck + timeStep
        if timepassedAfterLastCheck >= COMPLEXINTEGRITYCHECK then
            debugPrint(1,"Complex integrity Check", nil, Entity().index)
            timepassedAfterLastCheck = 0
            if onServer() == true then
                Entity():removeBonus(4321234)--No Entity should have this BlockId
                Entity():addKeyedMultiplyableBias(StatsBonuses.ArmedTurrets,4321234, math.floor(Entity():getPlan():getMoneyValue()/600000))       --adding 1 Turret per 600,000 net worth of the complex
            end
            removeMissingFactories()
        end
    end
end

function onSelectedFunction(tabIndex)
    local tabname = TabbedWindow(tabIndex):getActiveTab().name
     if tabname == "BCU" then
        selectedTab = 1
     end
     if tabname == "ICU" then
        selectedTab = 2
        updateOTListdataPanel()
     end
     if tabname == "TCU" then
        selectedTab = 3
        Entity():invokeFunction(CFSCRIPT, "synchTradingLists", nil,nil,nil,nil, true)
     end
end

function cmOnConstructionButtonPress(constructionData, addedPlan, addedComplexData, basefab)
    if basefab ~= nil then
        indexedComplexData[1] = basefab
    end
    
    indexedComplexData[#indexedComplexData + 1] = addedComplexData
    invokeServerFunction("startConstruction", constructionData, addedPlan, indexedComplexData, Player().index)
    debugPrint(3, "pre Fab added", indexedComplexData)
end

-- ######################################################################################################### --
-- ######################################     Both Sided     ############################################# --
-- ######################################################################################################### --

-- First synchronise the data, then update the corresponding Classes
function synchSingleComplexdata(priority, data, calledOnServer)
    if priority == nil then debugPrint(3, "synchSingleComplexdata nil found") return end
    if data == nil then debugPrint(3, "Synch single data nil") end
    --vec3 is userdata and gets converted to a Table, when transmitted. This turns tables back to vec3.
    if type(data.nodeOffset) == "table" then
        data.nodeOffset = tableToVec3(data.nodeOffset)
        debugPrint(4, "nodeOffset Table")
    end
    if type(data.relativeCoords) == "table" then
        data.relativeCoords = tableToVec3(data.relativeCoords)
         debugPrint(4, "relativeCoords Table")
    end
    
    if onServer() == true then
        if calledOnServer == nil then
            invokeClientFunction(Player(), "synchSingleComplexdata", priority, data, true)
        end
        updateSingleComplexdata(priority, data)
    else
        if calledOnServer == nil then
            invokeServerFunction("synchSingleComplexdata", priority, data, false)
        end
        updateSingleComplexdata(priority, data)
    end
end
--requests allow for simple sending without changing data
function synchComplexdata(pIndexedComplexData, calledOnServer, isrequest)
    if onServer() then
        debugPrint(3, "synchronising", indexedComplexData, Entity().index)
    end
    if isrequest == true then
        if onServer() then
            if callingPlayer ~= nil then 
                invokeClientFunction(Player(callingPlayer), "synchComplexdata", indexedComplexData, true) 
                return
            else
                --broadcastInvokeClientFunction("synchComplexdata", indexedComplexData, true) 
                debugPrint(1, "wrong player:", nil, callingPlayer, calledOnServer)
                return
            end
        else
            if indexedComplexData == nil or next(indexedComplexData) == nil then
                invokeServerFunction("synchComplexdata", nil, nil, true)
            else
                updateComplexdata(indexedComplexData)
            end
        end
    end
    if pIndexedComplexData == nil then debugPrint(3, "synchComplexdata is nil") return end
    -- When transmitted, userdata vec3 gets converted to a Table. This turns tables back to vec3.
    for priority, data in pairs(pIndexedComplexData) do
        if type(data.nodeOffset) == "table" then
            data.nodeOffset = tableToVec3(data.nodeOffset)
        end
        if type(data.relativeCoords) == "table" then
            data.relativeCoords = tableToVec3(data.relativeCoords)
        end
        pIndexedComplexData[priority] = data
    end
    
    if onServer() == true then
        if calledOnServer == nil then
            invokeClientFunction(Player(), "synchComplexdata", pIndexedComplexData, true)
        end
        updateComplexdata(pIndexedComplexData)
    else
        if calledOnServer == nil then
            invokeServerFunction("synchComplexdata", pIndexedComplexData, false)
        end
        updateComplexdata(pIndexedComplexData)
    end
end

function updateSingleComplexdata(priority, data)
    if onServer() == true then
        indexedComplexData[priority] = data
        Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData)
    else
        indexedComplexData[priority] = data
        updateOTComplexData(indexedComplexData)
        updateComplexdataCT(indexedComplexData)
    end
end

function updateComplexdata(pIndexedComplexData)
    if onServer() == true then
        indexedComplexData = pIndexedComplexData
        local status = Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData)
        debugPrint(3, "updateComplexdata "..CFSCRIPT.." status:", nil, status)
    else
        indexedComplexData = pIndexedComplexData
        updateOTComplexData(indexedComplexData)
        updateComplexdataCT(indexedComplexData)
    end
end

function passChangedTradingDataToTT(pTradingData)
    if onServer() == true then 
        debugPrint(0, "passing TradingData to Server is not allowed!")
    else
        updateTradingdata(pTradingData)
    end
end

function synchProductionData(pProductionData, calledOnServer)
    debugPrint(3,"sync of ProductionData", pProductionData)
    if onServer() == true then 
        if calledOnServer == nil then
            invokeClientFunction(Player(),"synchProductionData", pProductionData, true)
        else
            debugPrint(0,"synchProductionData called from Client - This is not allowed!")
            return
        end
        updateProductionData(pProductionData)
    else
        if calledOnServer == true then
            updateProductionData(pProductionData)
        else
            debugPrint(0,"synchProductionData called on Client- This is not allowed!")
            return
        end
    end
end

function updateProductionData(pProductionData)
    if onServer() == true then 
        productionData = pProductionData -- To be able to save it on Sector-unload
    else
        --no need to store it on the clientside. We just pass it directly to the overview-tab
        updateOTFactoryList(pProductionData)
    end
end
-- only bonusType == "GeneratedEnergy"
function addStatBonus(id, bonusType, value)
    if onClient() then
        invokeServerFunction("addStatBonus", id, bonusType, value)
    else
        Entity():removeBonus(id)
        local v = Entity():addKeyedMultiplyableBias(StatsBonuses.GeneratedEnergy, id, value)  --add <factor> to the stat
        bonusValues[id] = value
    end
end

function removeBonus(id)
    if onClient() then
        invokeServerFunction("addStatBonus", id, bonusType, value)
    else
        bonusValues[id] =  nil
        Entity():removeBonus(id)
    end
end

function updateTradingTab()
    if onServer() then
        debugPrint(0, "updateTradingTab is not allowed on Server")
    else
        updateTradingdata()
    end
end

function tRN(number)
    number = tonumber(number)
    if number == nil then return 0 end
    number = math.floor(number*100)/100     --keep last 2 digit
    local formatted = number
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

function vec3ToTable(vec)
    local retTable = {x = vec.x, y = vec.y, z = vec.z}
    return retTable
end

function tableToVec3(tab)
    local vec = vec3(tab.x, tab.y, tab.z)
    return vec
end

function removeMissingFactories()
    local complex = Entity():getPlan()   
    local removedSomething = false
    for index,data in pairs(indexedComplexData) do 
        local nodeID = data.factoryBlockId
        if not complex:getBlock(nodeID) then
            debugPrint(1, data.name.." has been removed from your Complex: ", nil, Entity().index)
            Player(Entity().factionIndex):sendChatMessage( Entity().name, 2, data.name.." has been removed from your Complex: "..Entity().name)
            indexedComplexData[index] = nil
            bonusValues[nodeID] = nil
            removedSomething = true
        end
    end
    
    if removedSomething == true then
        local t = 1
        local cleanList = {}
        for index,data in pairs(indexedComplexData) do 
            cleanList[t] = data
            t = t + 1
        end
        indexedComplexData = cleanList
        if onServer() == true then
            debugPrint(2, "synch Missing fabs")
            synchComplexdata(indexedComplexData)
        else
            debugPrint(0, "removeMissingFactories should not be called onClient")
        end

    end
end
-- ######################################################################################################### --
-- ######################################     Server Sided     ############################################# --
-- ######################################################################################################### --
function startConstruction(pConstructionData, connectorPipePlan, pIndexedComplexData, playerIndex)
    indexedComplexData = pIndexedComplexData
    if indexedComplexData == nil or next(indexedComplexData) == nil then
        debugPrint(0, "IndexedComplexData incomplete")
    end
    constructionData = pConstructionData
    local self = Entity()
    
    local player = Player(playerIndex)
    -- get the money required for the plan
    local requiredMoney = connectorPipePlan:getMoneyValue()
    local requiredResources = {connectorPipePlan:getResourceValue()}
    local canPay, msg, args = player:canPay(requiredMoney, unpack(requiredResources))
    if not canPay then -- if there was an error, print it
        player:sendChatMessage(self.title, 1, msg, unpack(args))
        return;
    end
    
    -- let the player pay
    player:pay(requiredMoney, unpack(requiredResources))
    player:sendChatMessage(self.title, 0, "Complex Construction begins.")
    
    local addedFactory = Entity(constructionData[0].targetID)
    local newComplex =self:getPlan()
    local addedFactoryPlan = addedFactory:getPlan()

    --extending Complex from data send
    newComplex:addBlock(tableToVec3(constructionData[1].position), tableToVec3(constructionData[1].size), constructionData[1].rootID, constructionData[1].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[2].position), tableToVec3(constructionData[2].size), constructionData[2].rootID, constructionData[2].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[3].position), tableToVec3(constructionData[3].size), constructionData[3].rootID, constructionData[3].BlockID, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    newComplex:addBlock(tableToVec3(constructionData[4].position), tableToVec3(constructionData[4].size), constructionData[4].rootID, constructionData[4].BlockID, ColorRGB(0.5, 0.0, 0.0), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)
    --adding new Station
    newComplex:addPlanDisplaced(constructionData[4].blockID, addedFactoryPlan, addedFactoryPlan.rootIndex, tableToVec3(constructionData[4].position))
    --set new Complex
    self:setPlan(newComplex)
    
    --carry over Crew and Storage
    
    local crew = addedFactory.crew
    for crewman, num in pairs(crew:getMembers()) do
        self:addCrew(num, crewman)
    end
    
    local facGoods = addedFactory:getCargos()
    for tg,num in pairs(facGoods)do
        self:addCargo(tg, num)
    end
    addedFactory:destroyCargo(addedFactory.maxCargoSpace)
    
    Sector():deleteEntityJumped(addedFactory)

    
    
    
    debugPrint(3, "sending indexedComplexData to Client:")
    synchComplexdata(indexedComplexData)
    if Entity():hasScript(CFSCRIPT) then
        if Entity():hasScript(FSCRIPT) then
            Entity():removeScript(FSCRIPT)
        end
        Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData) 
    else
        if Entity():hasScript(FSCRIPT) then
            Entity():removeScript(FSCRIPT)
        end
        Entity():addScript(CFSCRIPT)
        Entity():invokeFunction(CFSCRIPT, "setComplexData", indexedComplexData)
    end
    
end

function applyBoni()
    for id,value in pairs(bonusValues) do
        debugPrint(3,"applyBoni", nil, id, value)
        addStatBonus(id, "GeneratedEnergy", value)
    end
end

function restore(restoreData)
    debugPrint(3,"Manager ", restoreData, Entity().index)
    for index, data in pairs(restoreData.indexedComplexData) do
        data.nodeOffset = tableToVec3(data.nodeOffset)
        data.relativeCoords = tableToVec3(data.relativeCoords)
        indexedComplexData[index] = data
    end
    for index, data in pairs(restoreData.productionData) do
        data.nodeOffset = vec3ToTable(data.nodeOffset)
        data.relativeCoords = vec3ToTable(data.relativeCoords)
        productionData[index] = data
    end
    bonusValues = restoreData.bonusValues or {}
    synchComplexdata(indexedComplexData)
    synchProductionData(productionData)
    applyBoni()
end

function secure()
    local savedata = {}
    local pProductionData, pIndexedComplexData = {}, {}
    --Current production Data
    for index, data in pairs(productionData) do
        data.nodeOffset = vec3ToTable(data.nodeOffset)
        data.relativeCoords = vec3ToTable(data.relativeCoords)
        pProductionData[index] = data
    end
    --prioritised Complex Data
    for index, data in pairs(indexedComplexData) do
        data.nodeOffset = vec3ToTable(data.nodeOffset)
        data.relativeCoords = vec3ToTable(data.relativeCoords)
        pIndexedComplexData[index] = data
    end
    
    savedata["productionData"] = pProductionData
    savedata["indexedComplexData"] = pIndexedComplexData
    savedata.bonusValues = bonusValues
    return savedata
end
