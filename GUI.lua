-- GUI.lua
-- Handles visual interface, manual slider inputs, and the utility interface.

local PAD = 20
local FRAME_W = 300
local LABEL_W = 40
local SLIDER_W = FRAME_W - PAD * 2 - LABEL_W - 4

-- Helper: Scans inventory for any fishing lure and returns total count
-- Cached lure count — only rescanned when inventory changes
local cachedLureCount = 0
local lureCountDirty = true

local function GetLureCount()
    if not lureCountDirty then return cachedLureCount end
    lureCountDirty = false
    local lures = { "Shiny Bauble", "Nightcrawlers", "Aquadynamic Fish Attractor", "Bright Baubles", "Fleshless Bone", "Aquadynamic Fish Lens" }
    local count = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local name = FishingVolume.GetItemName(link)
                if name then
                    for _, lureName in pairs(lures) do
                        if name == lureName then
                            local _, qty = GetContainerItemInfo(bag, slot)
                            count = count + (qty or 1)
                        end
                    end
                end
            end
        end
    end
    cachedLureCount = count
    return count
end

-- Invalidate cache when inventory changes
local invWatcher = CreateFrame("Frame")
invWatcher:RegisterEvent("BAG_UPDATE")
invWatcher:SetScript("OnEvent", function() lureCountDirty = true end)

-- Helper: Calculates percentage safely and consistently
local function GetChestPercent(fish, chests)
    local total = fish + chests
    if total == 0 then return "0.0%" end
    return string.format("%.1f%%", (chests / total) * 100)
end

-- Updates the visual state of the Delay Slider based on the checkbox.
local function UpdateDelaySliderState(frame)
    if not frame.delaySlider or not frame.muteOnStopCheck then return end

    local muteOnStop = FishingVolume.GetSetting("muteOnStop")
    local r, g, b = 1.0, 0.82, 0
    local wr, wg, wb = 1.0, 1.0, 1.0

    if muteOnStop then
        r, g, b, wr, wg, wb = 0.5, 0.5, 0.5, 0.5, 0.5, 0.5
        frame.delaySlider:EnableMouse(false)
        frame.delaySlider:SetAlpha(0.5)
        if frame.delaySlider.editBox then frame.delaySlider.editBox:EnableMouse(false) end
    else
        frame.delaySlider:EnableMouse(true)
        frame.delaySlider:SetAlpha(1.0)
        if frame.delaySlider.editBox then frame.delaySlider.editBox:EnableMouse(true) end
    end

    local text = getglobal("FVDelaySliderText")
    if text then text:SetTextColor(r, g, b) end
    if frame.delaySlider.editBox then
        frame.delaySlider.editBox:SetTextColor(wr, wg, wb)
    end
    local thumb = frame.delaySlider:GetThumbTexture()
    if thumb then thumb:SetVertexColor(r, g, b) end
    frame.delaySlider:SetBackdropBorderColor(muteOnStop and 0.1 or 0.2, muteOnStop and 0.1 or 0.2, muteOnStop and 0.1 or 0.2, 1)
end

-- Shared state update — called for both the main frame and the mini panel.
function UpdateUtilityButtons(frame)
    if not frame.fishBtn or not frame.lureBtn then return end

    local mhLink = GetInventoryItemLink("player", 16)
    local mhName = FishingVolume.GetItemName(mhLink)
    local hasPole    = mhName and string.find(mhName, "Pole")
    local lureCount  = GetLureCount()

    local goldR, goldG, goldB = 1.0, 0.82, 0
    local darkR, darkG, darkB = 0.2, 0.2, 0.2

    -- RAID WARNING ALERTS
    local hasLure, expires = GetWeaponEnchantInfo()
    if frame.hadLure ~= nil then
        if frame.hadLure and not hasLure and not FishingVolume.intentionalSwap then
            PlaySound("RaidWarning")
            UIErrorsFrame:AddMessage("LURE EXPIRED!", 1, 0, 0, 1)
        end
        if frame.lastLureCount and frame.lastLureCount > 0 and lureCount == 0 then
            PlaySound("RaidWarning")
            UIErrorsFrame:AddMessage("OUT OF LURES!", 1, 0, 0, 1)
        end
    end
    frame.hadLure = hasLure
    frame.lastLureCount = lureCount

    local function SetBorder(btn, r, g, b, a)
        if btn.isHovered then return end
        btn._restR, btn._restG, btn._restB, btn._restA = r, g, b, a or 1
        local cr, cg, cb = btn:GetBackdropBorderColor()
        if math.abs((cr or 0) - r) < 0.01 and math.abs((cg or 0) - g) < 0.01
           and math.abs((cb or 0) - b) < 0.01 then return end
        btn:SetBackdropBorderColor(r, g, b, a or 1)
    end

    local function SetEnabled(btn, enabled, textR, textG, textB)
        local wasEnabled = btn._fvEnabled
        if wasEnabled == enabled then return end
        btn._fvEnabled = enabled
        if enabled then
            btn:Enable()
            btn:SetAlpha(1.0)
            btn:GetFontString():SetTextColor(textR, textG, textB)
        else
            btn:Disable()
            btn:SetAlpha(0.4)
            btn:GetFontString():SetTextColor(0.5, 0.5, 0.5)
            if not btn.isHovered then
                btn:SetBackdropBorderColor(0.1, 0.1, 0.1, 0.5)
            end
        end
    end

    if frame.poleBtn then
        SetBorder(frame.poleBtn, hasPole and goldR or darkR, hasPole and goldG or darkG, hasPole and goldB or darkB, 1)
    end

    if frame.weapBtn then
        local savedMH = FishingVolume.GetSetting("savedMainHand")
        local showGold = (not hasPole) and savedMH
        SetBorder(frame.weapBtn, showGold and goldR or darkR, showGold and goldG or darkG, showGold and goldB or darkB, 1)
    end

    if hasPole then
        SetEnabled(frame.fishBtn, true, goldR, goldG, goldB)
        local isFishing = (CastingBarFrame:IsVisible() and CastingBarText:GetText() == "Fishing")
        SetBorder(frame.fishBtn, isFishing and goldR or darkR, isFishing and goldG or darkG, isFishing and goldB or darkB, 1)
    else
        SetEnabled(frame.fishBtn, false)
    end

    if hasPole and lureCount > 0 then
        SetEnabled(frame.lureBtn, true, goldR, goldG, goldB)
        if hasLure then
            SetBorder(frame.lureBtn, goldR, goldG, goldB, 1)
        else
            SetBorder(frame.lureBtn, 1, 0, 0, 1)
        end
    else
        SetEnabled(frame.lureBtn, false)
    end

    if frame.lureTimeText then
        local timeStr = "None"
        if hasLure then
            local seconds = math.floor(expires / 1000)
            timeStr = (seconds > 60) and (math.ceil(seconds / 60) .. "m") or (seconds .. "s")
        end
        if frame._lastTimeStr ~= timeStr then
            frame._lastTimeStr = timeStr
            frame.lureTimeText:SetText("Time remaining on lure: " .. timeStr)
        end
        if frame._lastLureCount ~= lureCount then
            frame._lastLureCount = lureCount
            frame.lureInvText:SetText("Lures in inventory: " .. lureCount)
        end
    end

    if frame.statSessionText then
        local sFish   = FishingVolume.sessionFish or 0
        local sChests = FishingVolume.sessionChests or 0
        local tFish   = FishingVolume.GetSetting("totalFish") or 0
        local tChests = FishingVolume.GetSetting("totalChests") or 0
        if frame._lastSFish ~= sFish or frame._lastSChests ~= sChests then
            frame._lastSFish, frame._lastSChests = sFish, sChests
            frame.statSessionText:SetText(string.format("Session: %d Fish | %d Chests (%s)", sFish, sChests, GetChestPercent(sFish, sChests)))
        end
        if frame._lastTFish ~= tFish or frame._lastTChests ~= tChests then
            frame._lastTFish, frame._lastTChests = tFish, tChests
            frame.statTotalText:SetText(string.format("Lifetime: %d Fish | %d Chests (%s)", tFish, tChests, GetChestPercent(tFish, tChests)))
        end
    end

    if frame.lureStatus then
        local statusText
        if hasLure then
            local s = math.floor(expires / 1000)
            statusText = "Lure: " .. ((s > 60) and (math.ceil(s/60) .. "m") or (s .. "s"))
        elseif lureCount == 0 then
            statusText = "No lure in inventory"
        else
            statusText = "No lure active"
        end
        if frame._lastLureStatus ~= statusText then
            frame._lastLureStatus = statusText
            frame.lureStatus:SetText(statusText)
            if hasLure then
                frame.lureStatus:SetTextColor(goldR, goldG, goldB)
            else
                frame.lureStatus:SetTextColor(1, 0.3, 0.3)
            end
        end
    end
end

local function StripBlizzard(obj, isSlider)
    local name = obj:GetName()
    if not name then return end
    local textures = { "Left", "Middle", "Right", "DisabledLeft", "DisabledMiddle", "DisabledRight" }
    for _, tex in pairs(textures) do
        if getglobal(name..tex) then getglobal(name..tex):SetTexture(nil) end
    end
    if obj.GetNormalTexture    and obj:GetNormalTexture()    then obj:GetNormalTexture():SetTexture(nil)    end
    if obj.GetPushedTexture    and obj:GetPushedTexture()    then obj:GetPushedTexture():SetTexture(nil)    end
    if obj.GetHighlightTexture and obj:GetHighlightTexture() then obj:GetHighlightTexture():SetTexture(nil) end
    if obj.GetDisabledTexture  and obj:GetDisabledTexture()  then obj:GetDisabledTexture():SetTexture(nil)  end
    if isSlider and obj.GetThumbTexture then
        local thumb = obj:GetThumbTexture()
        if thumb then
            thumb:SetTexture(1.0, 0.82, 0)
            thumb:SetWidth(12) thumb:SetHeight(14)
        end
    end
end

local function ApplyPFStyle(obj, isButton)
    obj:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    obj:SetBackdropColor(0, 0, 0, 1)
    obj:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    if isButton then
        obj:SetScript("OnEnter", function()
            this.isHovered = true
            this:SetBackdropBorderColor(1.0, 0.82, 0, 1)
        end)
        obj:SetScript("OnLeave", function()
            this.isHovered = false
            local r = this._restR or 0.2
            local g = this._restG or 0.2
            local b = this._restB or 0.2
            local a = this._restA or 1
            this:SetBackdropBorderColor(r, g, b, a)
        end)
    end
end

function FishingVolume_OnLoad(frame)
    tinsert(UISpecialFrames, "FishingVolumeFrame")
    frame:RegisterForDrag("LeftButton")
    frame:RegisterEvent("UNIT_INVENTORY_CHANGED")

    ApplyPFStyle(frame, false)
    frame:SetBackdropColor(0, 0, 0, 0.85)

    FishingVolumeTitleText:ClearAllPoints()
    FishingVolumeTitleText:SetPoint("TOP", frame, "TOP", 0, -10)
    FishingVolumeTitleText:SetTextColor(1.0, 0.82, 0)

    local close = CreateFrame("Button", "FVUpperCloseBtn", frame)
    close:SetWidth(18) close:SetHeight(18)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    ApplyPFStyle(close, true)
    local xText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xText:SetAllPoints(close)
    xText:SetJustifyH("CENTER")
    xText:SetJustifyV("MIDDLE")
    xText:SetText("X")
    xText:SetTextColor(0.7, 0.2, 0.2)
    close:SetScript("OnClick", function() frame:Hide() end)

    local function MakeSlider(name, label, minVal, maxVal, step, yOff)
        local s = CreateFrame("Slider", name, frame, "OptionsSliderTemplate")
        s:SetMinMaxValues(minVal, maxVal) s:SetValueStep(step)
        s:SetWidth(SLIDER_W) s:SetHeight(14)
        s:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, yOff)

        local labelObj = getglobal(name .. "Text")
        labelObj:SetText(label)
        labelObj:SetTextColor(1.0, 0.82, 0)
        labelObj:ClearAllPoints()
        labelObj:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)

        getglobal(name .. "Low"):Hide() getglobal(name .. "High"):Hide()

        local vt = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        vt:SetWidth(LABEL_W)
        vt:SetJustifyH("RIGHT")
        vt:SetPoint("LEFT", s, "RIGHT", 4, 0)
        s.valText = vt

        local eb = CreateFrame("EditBox", name.."Edit", s)
        eb:SetFontObject(GameFontHighlightSmall)
        eb:SetWidth(45) eb:SetHeight(14)
        eb:SetPoint("CENTER", vt, "CENTER", 0, 0)
        eb:SetJustifyH("LEFT")
        eb:SetAutoFocus(false)
        eb:SetNumeric(true)
        eb:SetMaxLetters(4)
        s.editBox = eb

        s:SetScript("OnValueChanged", function()
            local val = math.floor(this:GetValue())
            local suffix = (name == "FVDelaySlider") and "s" or "%"
            s.valText:SetText(val .. suffix)
            if not s.isTyping then eb:SetText(val .. suffix) end
        end)

        eb:SetScript("OnEditFocusGained", function() s.isTyping = true; s.valText:SetAlpha(0) end)
        eb:SetScript("OnEditFocusLost", function()
            s.isTyping = false; s.valText:SetAlpha(1)
            local suffix = (name == "FVDelaySlider") and "s" or "%"
            this:SetText(math.floor(s:GetValue()) .. suffix)
        end)
        eb:SetScript("OnEnterPressed", function()
            local txt = this:GetText()
            txt = string.gsub(txt, "%%", ""); txt = string.gsub(txt, "s", "")
            local val = tonumber(txt) or 0
            if val > maxVal then val = maxVal elseif val < minVal then val = minVal end
            s:SetValue(val); this:ClearFocus()
        end)
        eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)

        StripBlizzard(s, true); ApplyPFStyle(s, false)
        return s
    end

    frame.fishSlider  = MakeSlider("FVFishSlider",  "Fishing Volume",  0, 100, 1, -55)
    frame.soundSlider = MakeSlider("FVSoundSlider", "Restored Volume", 0, 100, 1, -95)
    frame.delaySlider = MakeSlider("FVDelaySlider", "Restore Delay",   0,  60, 1, -140)

    local chk = CreateFrame("CheckButton", "FVMuteOnStopCheck", frame, "OptionsCheckButtonTemplate")
    chk:SetWidth(18) chk:SetHeight(18)
    chk:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -185)
    StripBlizzard(chk, false)
    ApplyPFStyle(chk, true)
    local chkText = getglobal(chk:GetName().."Text")
    chkText:SetText("Restore Volume Automatically when not Fishing")
    chkText:SetTextColor(1.0, 0.82, 0)
    chkText:SetPoint("LEFT", chk, "RIGHT", 5, 0)

    local checkTex = chk:GetCheckedTexture()
    if checkTex then
        checkTex:SetTexture(1, 0.82, 0, 0.8)
        checkTex:ClearAllPoints()
        checkTex:SetPoint("TOPLEFT", chk, "TOPLEFT", 5, -5)
        checkTex:SetPoint("BOTTOMRIGHT", chk, "BOTTOMRIGHT", -5, 5)
    end

    chk:SetScript("OnClick", function()
        FishingVolume.SetSetting("muteOnStop", this:GetChecked() == 1)
        UpdateDelaySliderState(frame)
    end)

    local chkLabelBtn = CreateFrame("Button", nil, frame)
    chkLabelBtn:SetPoint("TOPLEFT", chk, "TOPLEFT", 0, 0)
    chkLabelBtn:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -PAD, -205)
    chkLabelBtn:SetScript("OnClick", function() chk:Click() end)
    chkLabelBtn:SetScript("OnEnter", function() chk.isHovered = true end)
    chkLabelBtn:SetScript("OnLeave", function() chk.isHovered = false; UpdateDelaySliderState(frame) end)
    frame.muteOnStopCheck = chk

    local chkRecast = CreateFrame("CheckButton", "FVAutoRecastCheck", frame, "OptionsCheckButtonTemplate")
    chkRecast:SetWidth(18) chkRecast:SetHeight(18)
    chkRecast:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -207)
    StripBlizzard(chkRecast, false)
    ApplyPFStyle(chkRecast, true)
    local chkRecastText = getglobal(chkRecast:GetName().."Text")
    chkRecastText:SetText("Left-click for re-cast Fishing")
    chkRecastText:SetTextColor(1.0, 0.82, 0)
    chkRecastText:SetPoint("LEFT", chkRecast, "RIGHT", 5, 0)

    local checkRecastTex = chkRecast:GetCheckedTexture()
    if checkRecastTex then
        checkRecastTex:SetTexture(1, 0.82, 0, 0.8)
        checkRecastTex:ClearAllPoints()
        checkRecastTex:SetPoint("TOPLEFT", chkRecast, "TOPLEFT", 5, -5)
        checkRecastTex:SetPoint("BOTTOMRIGHT", chkRecast, "BOTTOMRIGHT", -5, 5)
    end

    chkRecast:SetScript("OnClick", function()
        FishingVolume.SetSetting("autoRecast", this:GetChecked() == 1)
    end)

    local chkRecastLabelBtn = CreateFrame("Button", nil, frame)
    chkRecastLabelBtn:SetPoint("TOPLEFT", chkRecast, "TOPLEFT", 0, 0)
    chkRecastLabelBtn:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -PAD, -227)
    chkRecastLabelBtn:SetScript("OnClick", function() chkRecast:Click() end)
    chkRecastLabelBtn:SetScript("OnEnter", function() chkRecast.isHovered = true end)
    chkRecastLabelBtn:SetScript("OnLeave", function() chkRecast.isHovered = false; UpdateDelaySliderState(frame) end)
    frame.autoRecastCheck = chkRecast

    local btnW = (FRAME_W - PAD * 2 - 6) / 2

    local function CreateStyledButton(name, text, parent)
        local b = CreateFrame("Button", name, parent or frame, "UIPanelButtonTemplate")
        b:SetWidth(btnW) b:SetHeight(22)
        b:SetText(text); b:GetFontString():SetTextColor(1.0, 0.82, 0)
        StripBlizzard(b, false); ApplyPFStyle(b, true)
        return b
    end

    FVPoleBtn = CreateStyledButton("FVPoleBtn", "Equip Pole")
    FVPoleBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -233)
    FVPoleBtn:SetScript("OnClick", function()
        FishingVolume:EquipPole()
        UpdateUtilityButtons(frame)
        if FVMiniPanel and FVMiniPanel:IsVisible() then UpdateUtilityButtons(FVMiniPanel) end
    end)
    frame.poleBtn = FVPoleBtn

    FVWeaponBtn = CreateStyledButton("FVWeaponBtn", "Equip Weapons")
    FVWeaponBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -233)
    FVWeaponBtn:SetScript("OnClick", function()
        FishingVolume:EquipWeapons()
        UpdateUtilityButtons(frame)
        if FVMiniPanel and FVMiniPanel:IsVisible() then UpdateUtilityButtons(FVMiniPanel) end
    end)
    frame.weapBtn = FVWeaponBtn

    frame.fishBtn = CreateStyledButton("FVFishBtn", "Fish")
    frame.fishBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -258)
    frame.fishBtn:SetScript("OnClick", function()
        FishingVolume:CastFishing() -- Updated to use centralized function
    end)

    frame.lureBtn = CreateStyledButton("FVLureButton", "Apply Lure")
    frame.lureBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -258)
    frame.lureBtn:SetScript("OnClick", function()
        FishingVolume:ApplyBestLure()
        UpdateUtilityButtons(frame)
        if FVMiniPanel and FVMiniPanel:IsVisible() then UpdateUtilityButtons(FVMiniPanel) end
    end)

    frame.lureTimeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.lureTimeText:SetPoint("TOPLEFT", frame.fishBtn, "BOTTOMLEFT", 0, -8)
    frame.lureTimeText:SetTextColor(1, 1, 1)

    frame.lureInvText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.lureInvText:SetPoint("TOPLEFT", frame.lureTimeText, "BOTTOMLEFT", 0, -4)
    frame.lureInvText:SetTextColor(1, 1, 1)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  frame.lureInvText, "BOTTOMLEFT", 0, -7)
    divider:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    divider:SetTexture(0.3, 0.3, 0.3, 1)

    frame.statSessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statSessionText:SetPoint("TOPLEFT", frame.lureInvText, "BOTTOMLEFT", 0, -18)
    frame.statSessionText:SetTextColor(1.0, 0.82, 0)

    frame.statTotalText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statTotalText:SetPoint("TOPLEFT", frame.statSessionText, "BOTTOMLEFT", 0, -4)
    frame.statTotalText:SetTextColor(1.0, 0.82, 0)

    frame:SetScript("OnEvent", function()
        if event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
            UpdateUtilityButtons(frame)
        end
    end)

    -- Poll every 1s for lure timer. Inventory changes trigger immediate updates via OnEvent.
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 1.0 then UpdateUtilityButtons(frame); this.elapsed = 0 end
    end)

    FVSaveBtn = CreateStyledButton("FVSaveBtn", "Save")
    FVSaveBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 15)
    FVSaveBtn:SetScript("OnClick", function()
        FishingVolume.SetSetting("fishingVolume", frame.fishSlider:GetValue() / 100)
        FishingVolume.SetSetting("soundVolume",   frame.soundSlider:GetValue() / 100)
        FishingVolume.SetSetting("muteDelay",     frame.delaySlider:GetValue())
        FishingVolume.SetSetting("muteOnStop",    (frame.muteOnStopCheck:GetChecked() == 1))
        FishingVolume.SetSetting("autoRecast",    (frame.autoRecastCheck:GetChecked() == 1))
        SetCVar("SoundVolume", tostring(frame.soundSlider:GetValue() / 100))
        DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99FishingVolume:|r Settings saved.")
    end)

    FVCloseBtn = CreateStyledButton("FVCloseBtn", "Close")
    FVCloseBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 15)
    FVCloseBtn:SetScript("OnClick", function() FishingVolumeFrame:Hide() end)
end

function FishingVolume_OnShow(frame)
    if not frame.fishSlider then return end
    frame.fishSlider:SetValue(FishingVolume.GetSetting("fishingVolume") * 100)
    frame.soundSlider:SetValue(FishingVolume.GetSetting("soundVolume") * 100)
    frame.delaySlider:SetValue(FishingVolume.GetSetting("muteDelay"))
    frame.muteOnStopCheck:SetChecked(FishingVolume.GetSetting("muteOnStop"))
    frame.autoRecastCheck:SetChecked(FishingVolume.GetSetting("autoRecast"))
    UpdateDelaySliderState(frame)
    UpdateUtilityButtons(frame)
end

-- ================================================================
-- MINI PANEL
-- ================================================================

function FishingVolume_ToggleMiniPanel()
    if not FVMiniPanel then
        FishingVolume_CreateMiniPanel()
    end
    if FVMiniPanel:IsVisible() then
        FVMiniPanel:Hide()
    else
        FVMiniPanel:Show()
    end
end

function FishingVolume_CreateMiniPanel()
    if FVMiniPanel then return end

    local frame = CreateFrame("Frame", "FVMiniPanel", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(180)
    frame:SetHeight(100)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    frame:Hide()

    tinsert(UISpecialFrames, "FVMiniPanel")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText("Fishing Volume Mini")
    title:SetTextColor(1.0, 0.82, 0)

    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetWidth(14) closeBtn:SetHeight(14)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    closeBtn:SetBackdropColor(0, 0, 0, 1)
    closeBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    local xStr = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xStr:SetAllPoints(closeBtn)
    xStr:SetJustifyH("CENTER") xStr:SetJustifyV("MIDDLE")
    xStr:SetText("X") xStr:SetTextColor(0.7, 0.2, 0.2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    closeBtn:SetScript("OnEnter", function() this:SetBackdropBorderColor(1, 0.2, 0.2, 1) end)
    closeBtn:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.2, 0.2, 0.2, 1) end)

    local mPAD   = 8
    local mBtnW   = (180 - mPAD * 2 - 4) / 2
    local mBtnH   = 22

    local function MakeMiniBtn(name, text, point, xOff, yOff)
        local b = CreateFrame("Button", name, frame, "UIPanelButtonTemplate")
        b:SetWidth(mBtnW) b:SetHeight(mBtnH)
        b:SetPoint(point, frame, point, xOff, yOff)
        b:SetText(text)
        b:GetFontString():SetTextColor(1.0, 0.82, 0)
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        b:SetBackdropColor(0, 0, 0, 1)
        b:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        b:SetScript("OnEnter", function()
            this.isHovered = true
            this:SetBackdropBorderColor(1.0, 0.82, 0, 1)
        end)
        b:SetScript("OnLeave", function()
            this.isHovered = false
            local r = this._restR or 0.2
            local g = this._restG or 0.2
            local b = this._restB or 0.2
            local a = this._restA or 1
            this:SetBackdropBorderColor(r, g, b, a)
        end)

        if b.GetNormalTexture    and b:GetNormalTexture()    then b:GetNormalTexture():SetTexture(nil)    end
        if b.GetPushedTexture    and b:GetPushedTexture()    then b:GetPushedTexture():SetTexture(nil)    end
        if b.GetHighlightTexture and b:GetHighlightTexture() then b:GetHighlightTexture():SetTexture(nil) end
        if b.GetDisabledTexture  and b:GetDisabledTexture()  then b:GetDisabledTexture():SetTexture(nil)  end

        b._Enable  = b.Enable
        b._Disable = b.Disable
        b.Enable = function(self)
            self._Enable(self)
            if self.GetNormalTexture    and self:GetNormalTexture()    then self:GetNormalTexture():SetTexture(nil)    end
            if self.GetDisabledTexture  and self:GetDisabledTexture()  then self:GetDisabledTexture():SetTexture(nil)  end
        end
        b.Disable = function(self)
            self._Disable(self)
            if self.GetNormalTexture    and self:GetNormalTexture()    then self:GetNormalTexture():SetTexture(nil)    end
            if self.GetDisabledTexture  and self:GetDisabledTexture()  then self:GetDisabledTexture():SetTexture(nil)  end
        end

        return b
    end

    local poleBtn   = MakeMiniBtn(nil, "Equip Pole",     "TOPLEFT",   mPAD,  -22)
    local weapBtn   = MakeMiniBtn(nil, "Equip Weapons", "TOPRIGHT", -mPAD, -22)
    local fishBtn   = MakeMiniBtn(nil, "Fish",           "TOPLEFT",   mPAD,  -48)
    local lureBtn   = MakeMiniBtn(nil, "Apply Lure",     "TOPRIGHT", -mPAD, -48)

    poleBtn:SetScript("OnClick", function()
        FishingVolume:EquipPole()
        UpdateUtilityButtons(frame)
        if FishingVolumeFrame and FishingVolumeFrame:IsVisible() then UpdateUtilityButtons(FishingVolumeFrame) end
    end)
    weapBtn:SetScript("OnClick", function()
        FishingVolume:EquipWeapons()
        UpdateUtilityButtons(frame)
        if FishingVolumeFrame and FishingVolumeFrame:IsVisible() then UpdateUtilityButtons(FishingVolumeFrame) end
    end)
    fishBtn:SetScript("OnClick", function()
        FishingVolume:CastFishing() -- Updated to use centralized function
    end)
    lureBtn:SetScript("OnClick", function()
        FishingVolume:ApplyBestLure()
        UpdateUtilityButtons(frame)
        if FishingVolumeFrame and FishingVolumeFrame:IsVisible() then UpdateUtilityButtons(FishingVolumeFrame) end
    end)

    frame.poleBtn = poleBtn
    frame.weapBtn = weapBtn
    frame.fishBtn = fishBtn
    frame.lureBtn = lureBtn

    local lureStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lureStatus:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
    lureStatus:SetTextColor(1, 1, 1)
    frame.lureStatus = lureStatus

    frame:SetScript("OnShow", function()
        UpdateUtilityButtons(frame)
    end)

    frame.elapsed = 0
    frame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 0.5 then
            UpdateUtilityButtons(frame)
            this.elapsed = 0
        end
    end)
end
