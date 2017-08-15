package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")

FSCRIPT = "data/scripts/entity/merchants/factory.lua"
CMSCRIPT = "data/scripts/entity/complexManager.lua"

VERSION = "[0.87] "
MOD = "[CPX3]"

DEBUGLEVEL = 2
-- Complex building menu items
local dirButtonXP, dirButtonYP, dirButtonZP
local dirButtonXM, dirButtonYM, dirButtonZM

local advancedCheckbox
local sliderX
local sliderY
local sliderZ
local numberBoxX, numberBoxXValue = 0
local numberBoxY, numberBoxYValue = 0
local numberBoxZ, numberBoxZValue = 0

local stationCombo
local stationComboIndexList = {}
local directionToAdd = 2             -- 0:X+, 1:X-, 2:Y+, 3:Y-, 4:Z+, 5:Z-

local buttonNodeXP, buttonNodeYP, buttonNodeZP
local buttonNodeXM, buttonNodeYM, buttonNodeZM

local constructionButton

local planDisplayer

local stationNameTextbox, stationNameButton

--Complex Blockplans 
local addedPlan
local preview

--Complex Data
local complexData = {}
local currentNodeIndex
local currentNodeOffset = vec3(0,0,0)
local targetCoreBlockIndex
local targetCoreBlockCoord
local constructionData = {}     --{[buildorder] = {[BlockID]= {["position"] = {x,y,z}, ["size"] = {x,y,z}, ["rootID"] = rootID}}}

local UIinititalised = false

function debugPrint(debuglvl, msg, tableToPrint, ...)
    if debuglvl <= DEBUGLEVEL then
        print(MOD..VERSION..msg, ...)
        if type(tableToPrint) == "table" then
            printTable(tableToPrint)
        end
    end
end

function createConstructionUI(tabWindow)
    local container = tabWindow:createContainer(Rect(vec2(0, 0), tabWindow.size));

    local vsplit = UIVerticalSplitter(Rect(vec2(0, 0), container.size), 10, 10, 0.25)

    local left = vsplit.left
    local right = vsplit.right

    container:createFrame(left);
    container:createFrame(right);

    local lister = UIVerticalLister(left, 10, 10)
    local l = container:createLabel(vec2(), "Select Station"%_t, 14);
    l.size = vec2(0, 0)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 10
    
    stationCombo = container:createComboBox(Rect(),"onStationComboSelect")
    --updateStationCombo()
    lister:placeElementCenter(stationCombo)
    lister.padding = 5 

    --creating Station offset Buttons
    local l = container:createLabel(vec2(), "Move Station Offset"%_t, 14);
    l.size = vec2(0, 0)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 5
    
    local rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit = UIVerticalMultiSplitter(rect, 5, 3, 2)
    dirButtonXP = container:createButton(vmsplit:partition(0), "X+", "onSetOffsetXP");
    dirButtonYP = container:createButton(vmsplit:partition(1), "Y+", "onSetOffsetYP");
    dirButtonZP = container:createButton(vmsplit:partition(2), "Z+", "onSetOffsetZP");
    lister.padding = 5
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit2 = UIVerticalMultiSplitter(rect, 5, 3, 2)
    dirButtonXM = container:createButton(vmsplit2:partition(0), "X-", "onSetOffsetXM");
    dirButtonYM = container:createButton(vmsplit2:partition(1), "Y-", "onSetOffsetYM");
    dirButtonZM = container:createButton(vmsplit2:partition(2), "Z-", "onSetOffsetZM");
    lister.padding = 10
    setDirButtonsActive()

    -- create advanced check boxes
    advancedCheckbox = container:createCheckBox(Rect(), "Advanced Building Opotions"%_t, "onAdvancedChecked")
    lister:placeElementCenter(advancedCheckbox)
    lister.padding = 20
    
    --advanced Slider and Numberbox for X-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderX = container:createSlider(sliderSplit.left, -100, 100, 200, "X"%_t, "updatePlan")
    sliderX.value = 0;
    sliderX.visible = false
    sliderX.segments = 40
    
    numberBoxX = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredX")
    numberBoxX.text = "0"
    numberBoxX.allowedCharacters = "-0123456789"
    numberBoxX.clearOnClick = 1
    numberBoxX.visible = false
    
    --advanced Slider and Numberbox for Y-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderY = container:createSlider(sliderSplit.left, -100, 100, 200, "Y"%_t, "updatePlan")
    sliderY.value = 0;
    sliderY.visible = false
    sliderY.segments = 40
    
    numberBoxY = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredY")
    numberBoxY.text = "0"
    numberBoxY.allowedCharacters = "-0123456789"
    numberBoxY.clearOnClick = 1
    numberBoxY.visible = false
    
    --advanced Slider and Numberbox for Z-Axis
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local sliderSplit = UIVerticalSplitter(rect, 5, 0, 0.7)
    sliderZ = container:createSlider(sliderSplit.left, -100, 100, 200, "Z"%_t, "updatePlan")
    sliderZ.value = 0;
    sliderZ.visible = false
    sliderZ.segments = 40
    
    numberBoxZ = container:createTextBox(sliderSplit.right, "onNumberfieldEnteredZ")
    numberBoxZ.text = "0"
    numberBoxZ.allowedCharacters = "-0123456789"
    numberBoxZ.clearOnClick = 1
    numberBoxZ.visible = false

    lister.padding = 10
    --creating Node offset Buttons
    local l = container:createLabel(vec2(), "Move to Node Offset"%_t, 14);
    l.size = vec2(0, 0)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 5
    local rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit = UIVerticalMultiSplitter(rect, 5, 3, 2)
    buttonNodeXP = container:createButton(vmsplit:partition(0), "X+", "onSetNodeOffsetXP");  
    buttonNodeXP.active = false
    buttonNodeYP = container:createButton(vmsplit:partition(1), "Y+", "onSetNodeOffsetYP");
    buttonNodeYP.active = false
    buttonNodeZP = container:createButton(vmsplit:partition(2), "Z+", "onSetNodeOffsetZP");
    buttonNodeZP.active = false
    lister.padding = 5
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local vmsplit2 = UIVerticalMultiSplitter(rect, 5, 3, 2)
    buttonNodeXM = container:createButton(vmsplit2:partition(0), "X-", "onSetNodeOffsetXM");
    buttonNodeXM.active = false
    buttonNodeYM = container:createButton(vmsplit2:partition(1), "Y-", "onSetNodeOffsetYM");
    buttonNodeYM.active = false
    buttonNodeZM = container:createButton(vmsplit2:partition(2), "Z-", "onSetNodeOffsetZM");
    buttonNodeZM.active = false
    setNodeButtonsActive()
    lister.padding = 10
    
    
    --Station naming
    rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local split2 = UIVerticalSplitter(rect, 5, 0, 0.7)
    stationNameTextbox = container:createTextBox(split2.left, "onNameFieldEntered")
    stationNameTextbox.text = Entity().name
    stationNameButton = container:createButton(split2.right, "Change Name", "onChangeName");
    
    -- button at the bottom
    constructionButton = container:createButton(Rect(), "Build"%_t, "onConstructionButtonPress");
    local organizer = UIOrganizer(left)
    organizer.padding = 10
    organizer.margin = 10
    organizer:placeElementBottom(constructionButton)

    -- create the viewer
    planDisplayer = container:createPlanDisplayer(vsplit.right);
    planDisplayer.showStats = 0
    planDisplayer.autoCenter = 0
    planDisplayer.center = vec3(0,0,0)
    
    
    advancedCheckbox.checked = true
    --onAdvancedChecked()
    UIinititalised = true
end

function updateComplexdataCT(pIndexedComplexdata)
    if onServer() then debugPrint(0,"updateComplexdataCT onServer not allowed !") end 
    complexData = applyIndexedToComplexdata(pIndexedComplexdata)
    if UIinititalised == false then return end
    updateStationCombo()
    setNodeButtonsActive()
    updatePlan()
    debugPrint(3, "ComplexData =========", complexData)
end

function applyIndexedToComplexdata(pIndexedComplexData)
    local list = {}
    for _,data in pairs(pIndexedComplexData) do
        local t = {
        ["relativeCoords"] = data.relativeCoords,
        ["factoryTyp"] = data.factoryTyp,
        ["nodeOffset"] = data.nodeOffset,
        ["size"] = data.size,
        ["name"] = data.name}
        list[data.factoryBlockId] = t
    end
    return list
end

function cTRenderUI()
    if addedPlan == nil then return end
        local planMoney = addedPlan:getMoneyValue()
        local planResources = {addedPlan:getResourceValue()}

        local offset = 10
        offset = offset + renderPrices(planDisplayer.lower + vec2(10, offset), "Construction Costs"%_t, planMoney, planResources)
end

function updatePlan()
    -- just to make sure that the interface is completely created, this function is called during initialization of the GUI, and not everything may be constructed yet
    if planDisplayer == nil then return end
    if stationCombo == nil then return  end
    if stationComboIndexList == nil then return end
    if sliderX == nil then return end
    if sliderY == nil then return end
    if sliderZ == nil then return end
    if directionToAdd == nil then return end
    if stationCombo.selectedIndex == nil then return end
    if stationComboIndexList[stationCombo.selectedIndex] == nil then
        constructionButton.active = false
        entityPlan = Entity():getPlan()
        planDisplayer.plan = entityPlan
        if currentNodeOffset == nil then currentNodeOffset = vec3(0,0,0) end
        currentNodeIndex = getNodeIDFromNodeOffset(currentNodeOffset) or entityPlan.rootIndex
        if complexData[currentNodeIndex] ~= nil then 
            planDisplayer.center = complexData[currentNodeIndex].relativeCoords
        else
            planDisplayer.center = vec3(0,0,0)
        end
        return 
    end
    if numberBoxX == nil then return end
    if numberBoxY == nil then return end
    if numberBoxZ == nil then return end
    
    if currentNodeOffset == nil then currentNodeOffset = vec3(0,0,0) end
    
    local sec = systemTimeMs()
    
    if complexData[currentNodeIndex] == nil then 
        debugPrint(1, "complexData nil on Complex", nil, Entity().index)
        currentNodeIndex = 0
        currentNodeOffset = vec3(0,0,0)
        targetCoreBlockIndex = nil
        targetCoreBlockCoord = vec3(0,0,0)
    end
    
    local newPlan = Entity():getPlan()
    addedPlan = BlockPlan()
    local addedStationPlan = Entity(stationComboIndexList[stationCombo.selectedIndex]):getPlan()

    if complexData == nil or next(complexData) == nil then                          --inititalizing Complexdata
        local status , factoryData = Entity():invokeFunction(FSCRIPT, "secure", nil)
        if status ~= 0 then debugPrint("Could not find Factory.lua on Station.")return end
        local name, args = formatFactoryName(factoryData.production, factoryData.maxNumProductions - 1)
        name = string.gsub(name, "${good}", tostring(args.good))
        name = string.gsub(name, "${size}", "S")
        local data = {["name"] = name, ["relativeCoords"] = vec3(0,0,0), ["nodeOffset"] = vec3(0,0,0), ["factoryTyp"] = factoryData.production, ["size"] = factoryData.maxNumProductions}
        complexData[newPlan.rootIndex] = data 
    end
    currentNodeIndex = getNodeIDFromNodeOffset(currentNodeOffset) or newPlan.rootIndex
    
    constructionData[0] = {["targetID"] = stationComboIndexList[stationCombo.selectedIndex]}
    
    local mainBB, addedBB = newPlan:getBoundingBox(), addedStationPlan:getBoundingBox()
    local xAdd, yAdd, zAdd = sliderX.value + (numberBoxXValue or 0), sliderY.value + (numberBoxYValue or 0), sliderZ.value + (numberBoxZValue or 0)
    local x, y, z = xAdd, yAdd, zAdd

    local nodeCoords = complexData[currentNodeIndex].relativeCoords
    if nodeCoords == nil then
        debugPrint(2,"nodeCoords nil ")
        invokeServerFunction("removeMissingFactories")
        return
    end
    
    if directionToAdd == 0 then
        x = mainBB.size.x/2 + addedBB.size.x/2 + xAdd
    end
    if directionToAdd == 1 then
        x = mainBB.size.x/2 + addedBB.size.x/2
        x = x * -1 + xAdd
    end
    if directionToAdd == 2 then
        y = mainBB.size.y/2 + addedBB.size.y/2 + yAdd
    end
    if directionToAdd == 3 then
        y = mainBB.size.y/2 + addedBB.size.y/2
        y = y * -1 + yAdd
    end
    if directionToAdd == 4 then
        z = mainBB.size.z/2 + addedBB.size.z/2 + zAdd
    end
    if directionToAdd == 5 then
        z = mainBB.size.z/2 + addedBB.size.z/2
        z = z * -1 + zAdd
    end
    local total = systemTimeMs()- sec
    debugPrint(2,"Needed "..tostring(systemTimeMs()-sec).."ms for preparation")
    local sec = systemTimeMs()
    
    local sizeVec3
    local posVec3
    --prevent z fighting, overlapping and visually loose connections
    if y < 0 then
        sizeVec3 = vec3(2,-y,2)
        posVec3 = vec3(0,(y/2)-0.5,0)
    else
        sizeVec3 = vec3(2,y+2,2)
        posVec3 = vec3(0,(y/2)+0,0)
    end
    posVec3 = posVec3 + nodeCoords
    local connectorY = newPlan:addBlock(posVec3, sizeVec3, currentNodeIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    addedPlan:addBlock(posVec3, sizeVec3, addedPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    constructionData[1] = {["BlockID"] = connectorY,["position"] = vec3ToTable(posVec3), ["size"] = vec3ToTable(sizeVec3), ["rootID"] = currentNodeIndex}
    if x < 0 then 
        sizeVec3 = vec3(-x-2,2,2)
    else
        sizeVec3 = vec3(x-2,2,2)
    end
    posVec3 = vec3(x/2,y,0) + nodeCoords
    local connectorX = newPlan:addBlock(posVec3, sizeVec3, connectorY, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    addedPlan:addBlock(posVec3, sizeVec3, addedPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    constructionData[2] = {["BlockID"] = connectorX,["position"] = vec3ToTable(posVec3), ["size"] = vec3ToTable(sizeVec3), ["rootID"] = connectorY}
    if z < 0 then
        if x == 0 then 
            sizeVec3 = vec3(2,2,-z-2)
        else
            sizeVec3 = vec3(2,2,-z+2)
        end
    else
        if x == 0 then 
            sizeVec3 = vec3(2,2,z-2)
        else
            sizeVec3 = vec3(2,2,z+2)
        end
    end
    posVec3 = vec3(x,y,z/2) + nodeCoords
    local connectorZ = newPlan:addBlock(posVec3, sizeVec3, connectorX, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)
    addedPlan:addBlock(posVec3, sizeVec3, addedPlan.rootIndex, -1, ColorRGB(0.5, 0.5, 0.5), Material(MaterialType.Xanion) , Matrix(), BlockType.Hull)                      --For price calculation
    constructionData[3] = {["BlockID"] = connectorZ,["position"] = vec3ToTable(posVec3), ["size"] = vec3ToTable(sizeVec3), ["rootID"] = connectorX}
    
    targetCoreBlockCoord = vec3(x,y,z) + nodeCoords
    targetCoreBlockIndex = newPlan:addBlock(targetCoreBlockCoord, vec3(5,5,5), connectorZ, -1, ColorRGB(0.5, 0.0, 0.0), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)
    addedPlan:addBlock(targetCoreBlockCoord, vec3(5,5,5), addedPlan.rootIndex, -1, ColorRGB(0.5, 0.0, 0.0), Material(MaterialType.Trinium) , Matrix(), BlockType.Armor)                   --For price calculation
    constructionData[4] = {["BlockID"] = targetCoreBlockIndex,["position"] = vec3ToTable(targetCoreBlockCoord), ["size"] = vec3ToTable(vec3(5,5,5)), ["rootID"] = connectorZ}
    
   
    local total = total + systemTimeMs()- sec
    debugPrint(2, "Needed "..tostring(systemTimeMs()-sec).."ms until merge")
    local sec = systemTimeMs()
    
    newPlan:addPlanDisplaced(targetCoreBlockIndex, addedStationPlan, addedStationPlan.rootIndex,targetCoreBlockCoord)
    
    local total = total + systemTimeMs()- sec
    debugPrint(2,"Needed "..tostring(systemTimeMs()-sec).."ms for addPlanDisplaced")
    local sec = systemTimeMs()
    
    -- set to display
    --preview = newPlan
    planDisplayer.plan = newPlan
    local total = total + systemTimeMs()- sec
    debugPrint(2, "Needed "..tostring(systemTimeMs()-sec).."ms for Plandisplayer set plan")
    local sec = systemTimeMs()
    setDirButtonsActive()
    
    planDisplayer.center = complexData[currentNodeIndex].relativeCoords
    
    local total = total + systemTimeMs()- sec
    debugPrint(2, "Needed "..tostring(systemTimeMs()-sec).."ms for Plandisplayer center")
    local sec = systemTimeMs()
    setDirButtonsActive()
    if  (directionToAdd == 0 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(1,0,0)))) or             --Trying to add the Complex on the existing Node in X+
        (directionToAdd == 1 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(-1,0,0)))) or            --Trying to add the Complex on the existing Node in X-
        (directionToAdd == 2 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(0,1,0)))) or             --...
        (directionToAdd == 3 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(0,-1,0)))) or 
        (directionToAdd == 4 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(0,0,1)))) or 
        (directionToAdd == 5 and getNodeIDFromNodeOffset((currentNodeOffset + vec3(0,0,-1))))               --Trying to add the Complex on the existing Node in Z-
    then
        constructionButton.active = false
    else
        constructionButton.active = true
    end
    local total = total + systemTimeMs()- sec
    debugPrint(1, "Needed "..tostring(systemTimeMs()- sec).."ms for construction of total "..tostring(total).."ms")
end

function updateStationCombo()
    local entitiesInSector = {Sector():getEntitiesByType(EntityType.Station)}
    local wantedStations = {}
    local enindex = Entity().index
    local index = 0
    stationCombo:clear()
    stationComboIndexList = {}
    for _, station in pairs(entitiesInSector) do
        if station.factionIndex == Player().index and station.index ~= enindex and station:hasScript("data/scripts/entity/merchants/factory.lua") then   
            
            local status , factoryData = station:invokeFunction(FSCRIPT, "secure", nil)
            if next(factoryData.production) then
                local name, args = formatFactoryName(factoryData.production, factoryData.maxNumProductions - 1)
                name = string.gsub(name, "${good}", tostring(args.good))
                name = string.gsub(name, "${size}", getFactoryClassBySize(factoryData.maxNumProductions))
                debugPrint(2,"combolist entries ", nil, index, name)
                stationComboIndexList[index] = station.index
                stationCombo:addEntry(name)
                index = index + 1
            end
        end
        
    end
end

function getNodeSuccessor(dir, searchVector) 
    if not currentNodeOffset then return nil end
    local smallestDistance = math.huge
    local biggestDistance = 0
    local smallestIndex = nil
    for nodeID,data in pairs(complexData) do    
        --debugPrint(4, "|"..tostring(data.nodeOffset), nil, tostring((currentNodeOffset + searchVector)))
        if vec3Equal(data.nodeOffset,(currentNodeOffset + searchVector)) then
            --debugPrint(4, "Selected1: "..tostring(data.nodeOffset))
            --debugPrint(4, "=================================")
            return nodeID
        end
        if searchVector[dir] == 1 then
            if data.nodeOffset[dir] >= (currentNodeOffset[dir] + searchVector[dir]) then
                local dist = getDistBetweenVectors(data.nodeOffset,(currentNodeOffset + searchVector))
                if dist < smallestDistance then
                    smallestDistance = dist
                    smallestIndex = nodeID
                    --debugPrint(4, "pre"..tostring(data.nodeOffset) .. " dist: " .. dist)
                end
            else  end
        end
        if searchVector[dir] == -1 then
            if data.nodeOffset[dir] <= (currentNodeOffset[dir] + searchVector[dir]) then
                local dist = getDistBetweenVectors(data.nodeOffset,(currentNodeOffset + searchVector))
                if dist < biggestDistance then
                    biggestDistance = dist
                    smallestIndex = nodeID
                    --debugPrint(4, "pre"..tostring(data.nodeOffset) .. " dist: " .. dist)
                end
            else  end
        end
    end
    if smallestIndex ~= nil then
        --debugPrint(4, "Selected: "..tostring(complexData[smallestIndex].nodeOffset))
    end
    --debugPrint(4, "=================================")
    return smallestIndex
end

function vec3Equal(vecIn1,vecIn2)
    if vecIn1 == nil or vecIn2 == nil then return false end
    return (vecIn1.x == vecIn2.x and vecIn1.y == vecIn2.y and vecIn1.z == vecIn2.z)
end

function getDistBetweenVectors(vector1, vector2)
    local vec = vector1 - vector2
    return math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
end

function getIndexById(orderedList, id)
    for ind,factoryId in pairs(orderedList) do
        if factoryId == id then
            return ind
        end
    end
    return nil
    
end

function getNodeIDFromNodeOffset(offset)
    for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset, offset)then
            return nodeID
        end
    end
    return nil
end

function isNodeInComplexData(nodeOffset)
    for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset,nodeOffset) then
            return true
        end
    end
    return false
end

function findDirectional(searchVector)
     if not currentNodeOffset then return end
     local nextIndex = nil
     for nodeID,data in pairs(complexData) do
        if vec3Equal(data.nodeOffset, (currentNodeOffset + searchVector)) then
            nextIndex = nodeID
            break
        end
     end
     return nextIndex
end

function setDirButtonsActive()
    if findDirectional(vec3(1,0,0))  then dirButtonXP.active = false else dirButtonXP.active = true end
    if findDirectional(vec3(-1,0,0)) then dirButtonXM.active = false else dirButtonXM.active = true end
    if findDirectional(vec3(0,1,0))  then dirButtonYP.active = false else dirButtonYP.active = true end
    if findDirectional(vec3(0,-1,0)) then dirButtonYM.active = false else dirButtonYM.active = true end
    if findDirectional(vec3(0,0,1))  then dirButtonZP.active = false else dirButtonZP.active = true end
    if findDirectional(vec3(0,0,-1)) then dirButtonZM.active = false else dirButtonZM.active = true end
end

function setNodeButtonsActive()
    local hasCurrentNode = isNodeInComplexData(currentNodeOffset)
    if hasCurrentNode == false then
        currentNodeIndex, data = next(complexData)
        if currentNodeIndex == nil or data == nil then return end
        currentNodeOffset = data.nodeOffset
        if currentNodeOffset == nil then 
            currentNodeOffset = vec3(0,0,0) 
            synchComplexdata(nil, nil, true)
            debugPrint(0, "The current Node got messed up. resetting: "..tostring(currentNodeOffset))
        end
    end
    if not getNodeSuccessor("x", vec3(1,0,0)) then buttonNodeXP.active = false else buttonNodeXP.active = true end
    if not getNodeSuccessor("y", vec3(0,1,0)) then buttonNodeYP.active = false else buttonNodeYP.active = true end
    if not getNodeSuccessor("z", vec3(0,0,1)) then buttonNodeZP.active = false else buttonNodeZP.active = true end
    if not getNodeSuccessor("x", vec3(-1,0,0)) then buttonNodeXM.active = false else buttonNodeXM.active = true end
    if not getNodeSuccessor("y", vec3(0,-1,0)) then buttonNodeYM.active = false else buttonNodeYM.active = true end
    if not getNodeSuccessor("z", vec3(0,0,-1)) then buttonNodeZM.active = false else buttonNodeZM.active = true end
    
end

function onSetOffsetXP()
    directionToAdd = 0
    updatePlan();
end

function onSetOffsetXM()
    directionToAdd = 1
    updatePlan();
end

function onSetOffsetYP()
    directionToAdd = 2
    updatePlan();
end

function onSetOffsetYM()
    directionToAdd = 3
    updatePlan();
end

function onSetOffsetZP()
    directionToAdd = 4
    updatePlan();
end

function onSetOffsetZM()
    directionToAdd = 5
    updatePlan();
end


function onSetNodeOffsetXP()
    currentNodeIndex = getNodeSuccessor("x", vec3(1,0,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetXM()
    currentNodeIndex = getNodeSuccessor("x", vec3(-1,0,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetYP()
    currentNodeIndex = getNodeSuccessor("y", vec3(0,1,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetYM()
    currentNodeIndex = getNodeSuccessor("y", vec3(0,-1,0))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetZP()
    currentNodeIndex = getNodeSuccessor("z",vec3(0,0,1))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onSetNodeOffsetZM()
    currentNodeIndex = getNodeSuccessor("z", vec3(0,0,-1))
    currentNodeOffset = complexData[currentNodeIndex].nodeOffset
    setNodeButtonsActive()
    updatePlan();
end

function onAdvancedChecked()
    if advancedCheckbox.checked then
        sliderX.visible = true
        sliderY.visible = true
        sliderZ.visible = true
        
        numberBoxX.visible = true
        numberBoxY.visible = true
        numberBoxZ.visible = true
    else
        -- reset Sliders
        sliderX.visible = false
        sliderX.value = 0
        sliderY.visible = false
        sliderY.value = 0
        sliderZ.visible = false
        sliderZ.value = 0
        --reset numberboxes
        numberBoxX.visible = false
        numberBoxX.text = "0"
        numberBoxXValue = 0
        numberBoxY.visible = false
        numberBoxY.text = "0"
        numberBoxYValue = 0
        numberBoxZ.visible = false
        numberBoxZ.text = "0"
        numberBoxZValue = 0
    end
    updatePlan();
end

function onNumberfieldEnteredX()
    local value = tonumber(numberBoxX.text)
    if value then
        sliderX.value = 0
        numberBoxXValue = value
    else
        --numberBoxX.text = "0"
    end
    updatePlan();
end

function onNumberfieldEnteredY()
    local value = tonumber(numberBoxY.text)
    if value then
        sliderY.value = 0
        numberBoxYValue = value
    else
        --numberBoxY.text = "0"
    end
    updatePlan();
end

function onNumberfieldEnteredZ()
    local value = tonumber(numberBoxZ.text)
    if value then
        sliderZ.value = 0
        numberBoxZValue = value
    else
        --numberBoxZ.text = "0"
    end
    updatePlan();
end

function onStationComboSelect()   
    updatePlan();
end

function onNameFieldEntered()

end

function onChangeName()
    if stationNameTextbox.text ~= nil then
        if string.len(stationNameTextbox.text) < 4 then
            print("Stationname needs to be at least 4 Characters long!")
            stationNameTextbox.text = "-"
        else
            invokeServerFunction("changeName", stationNameTextbox.text, Player().index)
        end
    end
end

function changeName(newName, playerIndex)
    if onClient() then debugPrint(0,"Wrong Side in CT-change Name") return end
    if callingPlayer ~= playerIndex then debugPrint(0, "Wrong Player tried to rename Complex:", nil, Entity().name, Player(callingPlayer).name) return end
    Player():sendChatMessage(Entity().name, 3, "Your Complex: "..Entity().name.." has been renamed to: "..newName, Entity().name)
    Entity().name = newName
end

function onConstructionButtonPress()
    local status , factoryData = Entity(stationComboIndexList[stationCombo.selectedIndex]):invokeFunction(FSCRIPT, "secure", nil)
    local name, args = formatFactoryName(factoryData.production, factoryData.maxNumProductions - 1)
    name = string.gsub(name, "${good}", tostring(args.good))
    name = string.gsub(name, "${size}", getFactoryClassBySize(factoryData.maxNumProductions))
    local nodeOffset
    if directionToAdd == 0 then nodeOffset = vec3(1,0,0) + currentNodeOffset end
    if directionToAdd == 1 then nodeOffset = vec3(-1,0,0) + currentNodeOffset end
    if directionToAdd == 2 then nodeOffset = vec3(0,1,0) + currentNodeOffset end
    if directionToAdd == 3 then nodeOffset = vec3(0,-1,0) + currentNodeOffset end
    if directionToAdd == 4 then nodeOffset = vec3(0,0,1) + currentNodeOffset end
    if directionToAdd == 5 then nodeOffset = vec3(0,0,-1) + currentNodeOffset end
    currentNodeOffset = nodeOffset
    currentNodeIndex = targetCoreBlockIndex
    local data = {["name"] = name, ["relativeCoords"] = targetCoreBlockCoord, ["nodeOffset"] = nodeOffset, ["factoryTyp"] = factoryData.production, ["size"] = factoryData.maxNumProductions}
    local basefab = {   ["name"] = complexData[0].name, 
                        ["relativeCoords"] = complexData[0].relativeCoords, 
                        ["nodeOffset"] = complexData[0].nodeOffset, 
                        ["factoryTyp"] = complexData[0].factoryTyp, 
                        ["size"] = complexData[0].size, 
                        ["factoryBlockId"] = 0}
    
    complexData[targetCoreBlockIndex] = data 
    data.factoryBlockId = targetCoreBlockIndex
    
    local count = 0
    for _,_ in pairs(complexData) do
        count = count + 1
    end
    if count > 2 then
        local status, data = Entity():invokeFunction(CMSCRIPT,"cmOnConstructionButtonPress",constructionData, addedPlan, data)
    else --initializing
        local status, data = Entity():invokeFunction(CMSCRIPT,"cmOnConstructionButtonPress",constructionData, addedPlan, data, basefab)
    end
    constructionButton.active = false                                                                       --Locking The construction Button to prevent inconsistent data. Gets activated after new Complexdata is send to the client
end




