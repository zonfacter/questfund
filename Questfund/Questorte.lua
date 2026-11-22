local _, addon = ...
local stageNames={"Questgeber","Questziel","Abgabe"}
local german=GetLocale()=="deDE"
local kindNames={"NPC","Objekt","Gegenstand","Erkundungsziel"}
addon.questStageColors={{0.48,0.74,1},{0.98,0.76,0.46},{0.54,0.89,0.74}}

local function entityName(target)
    local kind,id=target[1],target[2]
    if kind==3 and C_Item and C_Item.GetItemNameByID then
        local name=C_Item.GetItemNameByID(id)
        if type(name)=="string" and not (issecretvalue and issecretvalue(name)) and name~="" then return name end
    end
    local name=german and target[5] or target[3]
    if name~="" then return name end
    return kind==4 and kindNames[4] or kindNames[kind].." #"..id
end

function addon.DestinationLabel(place)
    local target=place.target
    local label=stageNames[place.stage] or kindNames[target[1]]
    local name=entityName(target)
    if place.sourceItem then name=entityName(addon.questEntities[3][place.sourceItem]).." · "..name end
    return label.." · "..name
end

function addon.Destination(place,id,title)
    local point=place.point
    local info=C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(point[1])
    local coords=("%.1f / %.1f"):format(point[2],point[3]):gsub("%.",",")
    return {point=point,target=place.target,stage=place.stage,sourceItem=place.sourceItem,
        questID=id,quest=title,finisher=addon.DestinationLabel(place),coords=coords,zone=info and info.name or "Karte #"..point[1]}
end

function addon.QuestStagePlaces(questID, stage)
    local route=addon.questRoutes[questID]
    local preferred=route and route[2]
    local nearby,other,unmapped={},{},{}
    local function add(target,sourceItem)
        if not target or not addon.QuestTargetAllowed(target,stage,sourceItem) then return end
        if #target[4]==0 then
            unmapped[#unmapped+1]={target=target,stage=stage,sourceItem=sourceItem}
        end
        for _,point in ipairs(target[4]) do
            local group=point[1]==preferred and nearby or other
            group[#group+1]={target=target,point=point,stage=stage,sourceItem=sourceItem}
        end
    end
    for _,ref in ipairs(route and route[stage+2] or {}) do
        local kind,id=ref[1],ref[2]
        local sources=kind==3 and addon.questItemSources[id]
        if sources then
            for _,source in ipairs(sources) do add(addon.questEntities[source[1]][source[2]],id) end
        else
            add(addon.questEntities[kind][id])
        end
    end
    if stage==2 and #nearby==0 and #other==0 then
        local point=addon.LiveQuestWaypoint(questID)
        if point then nearby[1]={target={4,questID,"Quest-Wegpunkt aus dem Questlog",{},nil,3},point=point,stage=stage} end
    end
    for _,place in ipairs(other) do nearby[#nearby+1]=place end
    for _,place in ipairs(unmapped) do nearby[#nearby+1]=place end
    return nearby
end

function addon.QuestMapMarkers(id,title,mapID)
    local markers={}
    for stage=1,3 do
        local seen={}
        for _,place in ipairs(addon.QuestStagePlaces(id,stage)) do
            local target=place.target
            local key=target[1]..":"..target[2]
            if place.point and place.point[1]==mapID and not seen[key] then
                seen[key]=true
                markers[#markers+1]=addon.Destination(place,id,title)
            end
        end
    end
    return markers
end
