-- Load Silithyst node locations from SandLocations.lua

local trackingEnabled = true -- Ensure tracking is enabled by default
local silithystNodes = SandPacker_SilithystNodes or {}
SandPacker_SavedNodes = SandPacker_SavedNodes or {}

-- Persistent pin data for robust re-registration
local SandPacker_PinData = {}

local SandPackerRef = {}

-- HereBeDragons library assignments
local HBD = LibStub and LibStub("HereBeDragonsQuestie-2.0", true)
local HBDPins = LibStub and LibStub("HereBeDragonsQuestie-Pins-2.0", true)

-- LibDataBroker and LibDBIcon minimap button setup
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

local SandPackerLDB = nil
if LDB then
    SandPackerLDB = LDB:NewDataObject("SandPacker", {
        type = "launcher",
        text = "SandPacker",
        icon = "Interface\\Icons\\INV_Misc_Dust_02",
        OnClick = function(self, button)
            ToggleTracking()
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("SandPacker")
            tooltip:AddLine("Click to toggle Silithyst node tracking.")
        end,
    })
end

if LDBIcon and SandPackerLDB then
    LDBIcon:Register("SandPacker", SandPackerLDB, {})
end

activePins = {}

-- Main addon frame for event handling
local SandPacker = CreateFrame("Frame", "SandPackerFrame")

-- Standalone robust frame pool for SandPacker

local SandPackerFramePool = {}
local unusedFrames = {}
local usedFrames = {}
local frameCount = 0

local function CreatePinFrame()
    frameCount = frameCount + 1
    local frame = CreateFrame("Frame", "SandPackerPin"..frameCount, WorldMapFrame)
    frame:SetSize(8, 8)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(100)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon = icon
    icon:SetTexture("Interface\\Icons\\INV_Misc_Dust_02")
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetAllPoints(frame)
    frame:Hide()
    return frame
end

function SandPackerFramePool:GetFrame()
    local frame = next(unusedFrames)
    if frame then
        unusedFrames[frame] = nil
    else
        frame = CreatePinFrame()
    end
    usedFrames[frame] = true
    frame:Show()
    return frame
end

function SandPackerFramePool:RecycleFrame(frame)
    if frame then
        frame:Hide()
        usedFrames[frame] = nil
        unusedFrames[frame] = frame
    end
end

function SandPackerFramePool:RecycleAll()
    for frame in pairs(usedFrames) do
        self:RecycleFrame(frame)
    end
end

local SandPackerMapDrawQueue = {}
local SandPackerMinimapDrawQueue = {}
local drawQueueTickRate = 0.2
local drawTimer = nil

local function ProcessQueue()
    while #SandPackerMapDrawQueue > 0 do
        local mapDrawCall = table.remove(SandPackerMapDrawQueue, 1)
        local frame = mapDrawCall[2]
        HBDPins:AddWorldMapIconMap(unpack(mapDrawCall))
        frame:SetSize(16, 16)
        -- Do NOT set parent/frame level/strata for world map pins; HBD handles this (Questie style)
    end
    while #SandPackerMinimapDrawQueue > 0 do
        local minimapDrawCall = table.remove(SandPackerMinimapDrawQueue, 1)
        local frame = minimapDrawCall[2]
        HBDPins:AddMinimapIconMap(unpack(minimapDrawCall))
        frame:SetSize(16, 16)
        local frameLevel = Minimap:GetFrameLevel() + 2015
        frame:SetParent(Minimap)
        frame:SetFrameStrata(Minimap:GetFrameStrata())
        frame:SetFrameLevel(frameLevel)
    end
end

local function StartDrawQueueTimer()
    if not drawTimer then
        drawTimer = C_Timer.NewTicker(drawQueueTickRate, ProcessQueue)
    end
end

local function AddMapPins()
    if not HBD or not HBDPins then
        print("[SandPacker] HereBeDragons library not found!")
        return
    end
    SandPackerFramePool:RecycleAll()
    activePins = {}
    SandPackerMapDrawQueue = {}
    SandPackerMinimapDrawQueue = {}
    -- Merge static and discovered nodes
    local allNodes = {}
    for _, node in ipairs(silithystNodes) do table.insert(allNodes, node) end
    for _, node in ipairs(SandPacker_SavedNodes) do table.insert(allNodes, node) end
    print("[SandPacker DEBUG] AddMapPins called. trackingEnabled:", trackingEnabled)
    SandPacker_PinData = {}
    local silithusUiMapID = 1451 -- Classic Silithus
    for i, node in ipairs(allNodes) do
        table.insert(SandPacker_PinData, {x = node.x, y = node.y})
        print(string.format("[SandPacker DEBUG] Adding world map pin #%d at %.2f, %.2f", i, node.x, node.y))
    local worldMapPin = CreateFrame("Frame", nil)
    worldMapPin:SetSize(8, 8)
    local icon = worldMapPin:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Dust_02")
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetAllPoints(worldMapPin)
    worldMapPin.icon = icon
    HBDPins:AddWorldMapIconMap(SandPackerRef, worldMapPin, silithusUiMapID, node.x / 100, node.y / 100, -1)
        -- For minimap pins, still use frame pool
        local pin = SandPackerFramePool:GetFrame()
        pin.x = node.x
        pin.y = node.y
        pin.UiMapID = silithusUiMapID
        pin.data = { id = i, Name = "Silithyst Node", GetIconScale = function() return 1 end, Type = "manual" }
        table.insert(SandPackerMinimapDrawQueue, {SandPackerRef, pin, silithusUiMapID, node.x / 100, node.y / 100, false, false, "OVERLAY", 8})
        pin.hidden = false
        table.insert(activePins, pin)
    end
    StartDrawQueueTimer()
    print("[SandPacker DEBUG] activePins count after AddMapPins:", #activePins)
    print("[SandPacker DEBUG] Map pins placed using HereBeDragons.")
    if HBDPins and HBDPins.worldmapProvider and HBDPins.worldmapProvider.RefreshAllData then
        print("[SandPacker DEBUG] Forcing HBD worldmapProvider:RefreshAllData()")
        HBDPins.worldmapProvider:RefreshAllData()
    end
end





local function RemoveMapPins()
    print("[SandPacker DEBUG] RemoveMapPins called.")
    HBDPins:RemoveAllWorldMapIcons(SandPackerRef)
    HBDPins:RemoveAllMinimapIcons(SandPackerRef)
    SandPackerFramePool:RecycleAll()
    activePins = {}
    SandPacker:SetScript("OnUpdate", nil)
end


function ToggleTracking()
    print("[SandPacker DEBUG] ToggleTracking called. trackingEnabled:", trackingEnabled)
    trackingEnabled = not trackingEnabled
    if trackingEnabled then
        trackingEnabled = true
        if GetRealZoneText() == "Silithus" then
            AddMapPins()
        else
            print("[SandPacker] Tracking enabled, but you are not in Silithus.")
        end
    else
        RemoveMapPins()
    end
end





SandPacker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
SandPacker:RegisterEvent("PLAYER_ENTERING_WORLD")
SandPacker:RegisterEvent("CHAT_MSG_LOOT")
SandPacker:RegisterEvent("MAP_EXPLORATION_UPDATED")

SandPacker:SetScript("OnEvent", function(self, event, ...)
    print("[SandPacker DEBUG] Event:", event)
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" or event == "MAP_EXPLORATION_UPDATED" then
        local zone = GetRealZoneText()
        if zone == "Silithus" and trackingEnabled then
            AddMapPins()
        else
            RemoveMapPins()
        end
    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        if msg:find("Silithyst") then
            print("[SandPacker] Silithyst picked up!")
            -- Save current position as a new node if not already present
            local mapID = 1451 -- Silithus mapID for Classic
            local px, py, _ = UnitPosition("player")
            if px and py then
                local minX, minY, maxX, maxY = 0, 0, 100, 100
                local normX = math.floor(px + 0.5)
                local normY = math.floor(py + 0.5)
                local exists = false
                for _, node in ipairs(SandPacker_SavedNodes) do
                    if math.abs(node.x - normX) < 1 and math.abs(node.y - normY) < 1 then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(SandPacker_SavedNodes, {x = normX, y = normY})
                    print(string.format("[SandPacker] New Silithyst node saved at (%.1f, %.1f)", normX, normY))
                    AddMapPins()
                end
            end
        end
    end
end)




print("[SandPacker DEBUG] Addon loaded.")
C_Timer.After(2, function()
    if GetRealZoneText() == "Silithus" then
        AddMapPins()
    end
end)

SLASH_SANDPACKER1 = "/sandpacker"
SlashCmdList["SANDPACKER"] = function(msg)
    print("SandPacker loaded. Silithyst locations are shown on the map in Silithus.")
end
