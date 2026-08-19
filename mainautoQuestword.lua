-- [[ 🐲 RUAJAD HUB: WORLD AUTOQUEST (BUG FIX EDITION) ]]
local CHAIN_SAVE_FILE = "RuajadHub/AutoQuestChain.txt"
local RESUME_FILE = "RuajadHub/AutoQuestResume.txt"

local function ruajadDelFile(path)
    pcall(function()
        if typeof(isfile) == "function" and typeof(delfile) == "function" and isfile(path) then
            delfile(path)
        end
    end)
end

local function clearAllPersistFiles()
    ruajadDelFile(RESUME_FILE)
    ruajadDelFile(CHAIN_SAVE_FILE)
end

-- มีไฟล์ resume หรือ flag จากคิววาป = รันต่อแล้วฟาร์ม
local resumeFileOn = false
pcall(function()
    if typeof(isfile) == "function" and isfile(RESUME_FILE) then
        resumeFileOn = true
    end
end)
local isTeleportReload = getgenv().RuajadTeleportResume and true or resumeFileOn
getgenv().RuajadTeleportResume = nil

if not isTeleportReload then
    clearAllPersistFiles()
end
if getgenv().RuajadAutoQuestLoaded and not isTeleportReload then
    return
end
getgenv().RuajadAutoQuestLoaded = true

if not isTeleportReload then
    warn("⏳ [RUAJAD] waiting 9s before script starts...")
    task.wait(9)
end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- ใส่ URL raw ของไฟล์นี้บน Gist — ไม่ใส่ commit hash กลางลิงก์ อัป Gist แล้วได้ล่าสุดอัตโนมัติ
local AUTOQUEST_RAW_URL = "https://gist.githubusercontent.com/armkkk123/7f421620a8f9819207d1eeace542ef2d/raw/main_autoquest.lua"

local function ensureRuajadFolder()
    pcall(function()
        if typeof(isfolder) == "function" and typeof(makefolder) == "function" then
            if not isfolder("RuajadHub") then
                makefolder("RuajadHub")
            end
        end
    end)
end

local function setChainPersist(on)
    ensureRuajadFolder()
    pcall(function()
        if on then
            if typeof(writefile) == "function" then
                writefile(CHAIN_SAVE_FILE, "1")
            end
        else
            ruajadDelFile(CHAIN_SAVE_FILE)
        end
    end)
end

local function isChainPersistOn()
    local on = false
    pcall(function()
        if typeof(isfile) == "function" and isfile(CHAIN_SAVE_FILE) then
            on = true
        end
    end)
    return on
end

local function markAutoResume()
    ensureRuajadFolder()
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(RESUME_FILE, "1")
        end
    end)
end

local function consumeAutoResume()
    local had = false
    pcall(function()
        if typeof(isfile) == "function" and isfile(RESUME_FILE) then
            had = true
        end
    end)
    ruajadDelFile(RESUME_FILE)
    return had
end

local function clearStaleResumeFile()
    clearAllPersistFiles()
end

local Library
local AdvanceChainToggleObj = nil

local QUEST_FLAG_KEYS = {
    "AutoQuestOrigins", "AutoQuestGrassland", "AutoQuestJungle", "AutoQuestVolcano",
    "AutoQuestTundra", "AutoQuestOcean", "AutoQuestDesert", "AutoQuestFantasy",
    "AutoQuestShinrin", "AutoQuestPrehistoric", "AutoQuestWasteland",
}

local function hubNotify(title, content, duration)
    pcall(function()
        if Library and Library.Notify then
            Library:Notify({ Title = title, Content = content, Duration = duration or 3 })
        end
    end)
end

local function setToggleValue(toggle, on)
    if not toggle then return end
    pcall(function() toggle.Set(on) end)
end

local function minimizeHubToFloatBtn()
    pcall(function()
        if Library and Library.MainFrame then
            Library.MainFrame.Visible = false
        end
        if Library and Library.OpenBtn then
            Library.OpenBtn.Visible = true
        end
        if Library and Library.ScreenGui then
            Library.ScreenGui.Enabled = true
        end
    end)
end

_G.RuajadCancelChain = function()
    _G.AutoQuestChain = false
    _G.AutoQuestChainWorld = false
    setChainPersist(false)
    clearStaleResumeFile()
    for _, flag in ipairs(QUEST_FLAG_KEYS) do
        _G[flag] = false
    end
    setPhysics(false)
end

local function queueAutoQuestOnTeleport()
    local qot = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
    if type(qot) ~= "function" then
        return
    end
    markAutoResume()
    local url = AUTOQUEST_RAW_URL
    local loader = [[
        repeat task.wait() until game:IsLoaded()
        task.wait(9)
        getgenv().RuajadTeleportResume = true
        pcall(function()
            loadstring(game:HttpGet("]] .. url .. [["))()
        end)
    ]]
    pcall(qot, loader)
end

local function hopToNewServer(reason)
    warn("🌐 [ServerHop] " .. (reason or "ย้ายเซิร์ฟ") .. "...")
    queueAutoQuestOnTeleport()
    setChainPersist(_G.AutoQuestChain == true)

    local HttpReq = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if HttpReq then
        local ok, response = pcall(function()
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                game.PlaceId
            )
            return HttpReq({ Url = url, Method = "GET" })
        end)
        if ok and response and response.Body then
            local decoded = HttpService:JSONDecode(response.Body)
            if decoded and decoded.data then
                local servers = {}
                for _, v in pairs(decoded.data) do
                    if type(v) == "table"
                        and v.playing and v.maxPlayers
                        and v.playing < v.maxPlayers
                        and v.id ~= game.JobId then
                        table.insert(servers, v.id)
                    end
                end
                if #servers > 0 then
                    TeleportService:TeleportToPlaceInstance(
                        game.PlaceId,
                        servers[math.random(1, #servers)],
                        LP
                    )
                    return true
                end
            end
        end
    end

    pcall(function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)
    return false
end

-- ============================================================
-- [[ 🌐 AUTO-RESUME OVERLAY (after world/server teleport) ]]
-- แถบบนตรงกลาง โปร่งใส เล็ก — ไม่ทึบ ไม่บังจอ
-- ============================================================

local function isFiniteVec(v)
    return v and v.X == v.X and v.Y == v.Y and v.Z == v.Z
        and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

local function getLoadedCharacter()
    local char = LP.Character
    if not (char and char.Parent) then
        local folder = workspace:FindFirstChild("Characters")
        char = folder and folder:FindFirstChild(LP.Name)
    end
    if not (char and char.Parent and char:IsDescendantOf(workspace)) then
        return nil
    end
    return char
end

-- ตัวละคร + มังกรอยู่ในแมปแล้วหรือยัง (ไม่มี timeout)
local function getDragonInWorld(char)
    if not char then
        return nil
    end
    local folder = char:FindFirstChild("Dragons")
    if not folder then
        return nil
    end
    for _, d in ipairs(folder:GetChildren()) do
        local hrp = d:FindFirstChild("HumanoidRootPart")
        if hrp and d.Parent and d:IsDescendantOf(workspace) and isFiniteVec(hrp.Position) then
            return d
        end
    end
    return nil
end

local function playerAndDragonReady()
    if not game:IsLoaded() then
        return false, "game"
    end
    local char = getLoadedCharacter()
    if not char then
        return false, "character"
    end
    local charHrp = char:FindFirstChild("HumanoidRootPart")
    if not (charHrp and isFiniteVec(charHrp.Position)) then
        return false, "character"
    end
    if not getDragonInWorld(char) then
        return false, "dragon"
    end
    return true, "ready"
end

-- ห้ามทำอย่างอื่นจนกว่าเห็นตัวละครและมังกรในแมป — ไม่มีเวลาตายตัว
local function waitUntilPlayerAndDragonInWorld(onStatus, shouldStop)
    warn("⏳ [System] waiting until character + dragon are in the world")
    while true do
        if shouldStop and shouldStop() then
            return false
        end
        local ready, why = playerAndDragonReady()
        if onStatus then
            pcall(onStatus, ready, why)
        end
        if ready then
            task.wait()
            if playerAndDragonReady() then
                warn("✅ [System] character + dragon in world")
                return true
            end
        end
        task.wait(0.2)
    end
end

local function waitUntilWorldAndCharacterReady()
    return waitUntilPlayerAndDragonInWorld()
end


-- [[ 📺 CENTER WARNING UI ]]
local ScreenGui = Instance.new("ScreenGui")
local WarningLabel = Instance.new("TextLabel")
ScreenGui.Name = "RUAJAD_Warning"
ScreenGui.Parent = LP:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

WarningLabel.Name = "Msg"
WarningLabel.Parent = ScreenGui
WarningLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
WarningLabel.BackgroundTransparency = 1
WarningLabel.Position = UDim2.new(0.5, -280, 0.38, -30)
WarningLabel.Size = UDim2.new(0, 560, 0, 70)
WarningLabel.Font = Enum.Font.GothamBold
WarningLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
WarningLabel.TextSize = 22
WarningLabel.TextWrapped = true
WarningLabel.Text = "⚠️ [System waiting for chest spawn] ⚠️"
WarningLabel.Visible = false

-- Lightweight blinking system - no spec consumption
task.spawn(function()
    while true do
        if WarningLabel.Visible then
            WarningLabel.TextTransparency = 0
            task.wait(0.5)
            WarningLabel.TextTransparency = 1
            task.wait(0.5)
        else
            task.wait(1)
        end
    end
end)

local function showCenterWarning(active, text)
    if WarningLabel.Text ~= text then WarningLabel.Text = text or "" end
    WarningLabel.Visible = active
    if not active then WarningLabel.TextTransparency = 0 end
end

-- [[ 🛡️ SHIELD + 👻 GHOST MODE DAMAGE BLOCKER ]]
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
        -- ⚡ Super Fast Check: ไม่ใช้ pcall เพราะมันสร้างขยะ RAM (Lag) มหาศาลเมื่อเรียกทุกเสี้ยวseconds
        if typeof(self) == "Instance" then
            local n = self.Name
            if n == "Ban" or n == "Kick" or n == "Report" then return nil end
            if n == "Ban" or n == "Kick" or n == "Report" then return nil end
            -- [[ 👻 GHOST MODE: Network-level damage blocking ]]
            -- Client won't send data "dragon got hit" to Server
            if _G.GhostMode and n == "MobDamageRemote" then return nil end
        end
    end
    return oldNamecall(self, ...)
end))

-- [[ 🧲 AUTO COLLECT DROPS (MAGNET) ]]
task.spawn(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    
    -- Path: Auto collect drops from Node/Mob via: Server→Client(BillboardPart, waveId, itemsTable)
    local function setupAutoCollect(remoteName)
        local remote = Remotes:FindFirstChild(remoteName)
        if not (remote and remote:IsA("RemoteEvent")) then return end
        warn("✅ [Magnet] Installed: " .. remoteName)
        remote.OnClientEvent:Connect(function(nodePart, waveId, itemsTable)
            if type(itemsTable) ~= "table" then return end
            for itemIndex, _ in pairs(itemsTable) do
                pcall(function()
                    remote:FireServer(nodePart, waveId, itemIndex)
                end)
                task.wait(0.03)
            end
        end)
    end
    
    -- Real remotes in game (filter out fake ones)
    setupAutoCollect("LargeNodeDropsRemote")  -- For drops from Node (trees, rocks, food)
    setupAutoCollect("MobDropsRemote")         -- For drops from mobs
end)

-- [[ 🛑 AUTO SHUTDOWN & RESUME ON BOSS DEATH ]]
local QuestToggles = {}
_G.RuajadInOwnBossFight = false
_G.RuajadBossRestartBusy = false

local function isOwnBossStillAlive()
    local myNameStr = LP.Name
    local activeBosses = workspace:FindFirstChild("ActiveBossModels")
    if activeBosses then
        for _, boss in pairs(activeBosses:GetChildren()) do
            if boss:IsA("Model") and boss.Name:find(myNameStr) then
                return true
            end
        end
    end
    local lootFrame = LP:FindFirstChild("PlayerGui")
        and LP.PlayerGui:FindFirstChild("BossGui")
        and LP.PlayerGui.BossGui:FindFirstChild("LootFrame")
    if lootFrame and lootFrame.Visible then
        return false -- หน้า loot ของเรา = บอสเราตายแล้ว
    end
    return false
end

task.spawn(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local BossDropRemote = Remotes:WaitForChild("StartBossDropRemote")
    
    BossDropRemote.OnClientEvent:Connect(function()
        -- remote นี้ยิงทุกบอสในเซิร์ฟ — อย่าปิดระบบถ้าเรายังตีบอสตัวเองอยู่
        local lootFrame = LP:FindFirstChild("PlayerGui")
            and LP.PlayerGui:FindFirstChild("BossGui")
            and LP.PlayerGui.BossGui:FindFirstChild("LootFrame")
        local lootOpen = lootFrame and lootFrame.Visible

        if _G.RuajadInOwnBossFight and isOwnBossStillAlive() and not lootOpen then
            warn("🎊 [System] บอสคนอื่นตาย — ข้าม (เรายังอยู่ในไฟต์)")
            return
        end
        -- หน้า PICK A REWARD ของเราขึ้น = รับของได้เลย แม้ flag ไฟต์หลุดไปแล้ว
        if not lootOpen and not _G.RuajadInOwnBossFight then
            warn("🎊 [System] บอสตายแต่ไม่ใช่ไฟต์เรา — ข้าม")
            return
        end
        if _G.RuajadBossRestartBusy then
            return
        end
        _G.RuajadBossRestartBusy = true
        warn("🎊 [System] บอสเราตายแล้ว! Claim loot then restart farm...")

        local chainWasOn = (_G.AutoQuestChain == true)
        if chainWasOn then
            _G.AutoQuestChainPaused = true
        end

        local activeBefore = {}
        for name, toggle in pairs(QuestToggles) do
            local flagName = "AutoQuest" .. name
            if _G[flagName] == true then
                table.insert(activeBefore, {t = toggle, f = flagName, n = name})
            end
        end

        pcall(function()
            hubNotify("BOSS DEFEATED", "Claim reward then auto-restart after Exit...", 6)
        end)

        task.spawn(function()
            pcall(function()
                if _G.RuajadAutoClaimBossLoot then
                    _G.RuajadAutoClaimBossLoot()
                end
            end)
            if _G.RuajadRestartQuestsAfterBoss then
                _G.RuajadRestartQuestsAfterBoss(activeBefore, chainWasOn)
            end
            _G.RuajadInOwnBossFight = false
            _G.RuajadBossRestartBusy = false
        end)
    end)
end)

-- [[ 🚀 DRAGON CORE ]]
local function getActiveDragonModel()
    local char = workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LP.Name)
    if char and char:FindFirstChild("Dragons") then return char.Dragons:GetChildren()[1] end
    local c = LP.Character
    if c and c:FindFirstChild("Dragons") then return c.Dragons:GetChildren()[1] end
    return nil
end

local function getRoot()
    local char = LP.Character
    if not char then return nil end
    local dragon = getActiveDragonModel()
    -- ล็อคที่ Root มังกรเป็นหลัก เพราะถ้ามังกรอยู่ต่ำเราจะโดนดาเมจ
    return (dragon and dragon:FindFirstChild("HumanoidRootPart")) or char:FindFirstChild("HumanoidRootPart")
end

-- เติมเกจพ่นไฟจากค่า capacity จริงของมังกร (อ้างอิงจาก maindragon.Lua)
local function refillDragonBreathFuel(dragon)
    if not dragon then return end
    local data = dragon:FindFirstChild("Data")
    if not data then return end

    local combatStats = data:FindFirstChild("CombatStats")
    local fireFolder = data:FindFirstChild("Fire")
    local breathCapacity = combatStats and combatStats:FindFirstChild("BreathCapacity")
    local breathFuel = fireFolder and fireFolder:FindFirstChild("BreathFuel")
    if breathCapacity and breathFuel then
        breathFuel.Value = breathCapacity.Value
    end

    local breathCooldown = fireFolder and fireFolder:FindFirstChild("BreathCooldown")
    if breathCooldown and breathCooldown:IsA("NumberValue") then
        breathCooldown.Value = 0
    end
end

local bv = nil
local function setPhysics(active)
    local root = getRoot()
    if not root then return end
    if active then
        -- ถ้าย้ายร่างไปขี่มังกร แต่ตัวต้านแรงโน้มถ่วงยังติดอยู่กับตัวเก่า ให้ทิ้งซะแล้วสร้างใหม่
        if bv and bv.Parent ~= root then
            pcall(function() bv:Destroy() end)
            bv = nil
        end

        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = root
        end
        
        -- ล็อคความเร็วปัจจุบันไม่ให้ร่วง
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        
        -- บังคับกล้องให้systemมาโฟกัสที่ตัวเรา/มังกร กันกล้องค้างที่เดิมตอนบินไวๆ
        pcall(function()
            local cam = workspace.CurrentCamera
            local hum = nil
            local dragon = getActiveDragonModel()
            if dragon then hum = dragon:FindFirstChildWhichIsA("Humanoid") end
            if not hum and LP.Character then hum = LP.Character:FindFirstChildWhichIsA("Humanoid") end
            if hum and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
        end)
    else
        if bv then 
            pcall(function() bv:Destroy() end) 
            bv = nil 
        end
    end
end

local SPEED = 250
local FLY_HEIGHT_OFFSET = 80  -- บินสูงขึ้นจากจุดปัจจุบันเท่านี้ (แทนค่าตายตัว เพื่อรองรับทุกโลก)

-- ============================================================
-- [[ 🔄 AUTO RESET CHARACTER SYSTEM ]]
-- ============================================================
local function resetCharacter()
    pcall(function()
        warn("🔄 [System] กำลังรีเซ็ทตัวละคร...")
        local RefreshRemote = LP:WaitForChild("Remotes"):WaitForChild("RefreshAppearanceRemote")
        if RefreshRemote then
            RefreshRemote:FireServer()
            task.wait(0.8)
            -- รีเซ็ท HP และฟูลสเตททุกอย่าง
            local dragon = getActiveDragonModel()
            if dragon then
                refillDragonBreathFuel(dragon)
                local hum = dragon:FindFirstChildOfClass("Humanoid")
                if hum then hum.Health = hum.MaxHealth end
            end
            local char = LP.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Health = hum.MaxHealth end
            end
            task.wait(0.3)
            warn("✅ [System] รีเซ็ทตัวละครเสร็จสิ้น!")
        end
    end)
end

-- [[ ✈️ SMART FLY: วาร์ปขึ้นสูง → Tween ในอากาศ → วาร์ปลงหาเป้าหมาย (เลี่ยง Portal 100%) ]]
local function flyTo(targetCF)
    local root = getRoot()
    if not root then return end
    local dist = (root.Position - targetCF.Position).Magnitude
    if dist < 10 then
        root.CFrame = targetCF
        root.AssemblyLinearVelocity = Vector3.new(0,0,0)
        return
    end

    -- Step 1: วาร์ปขึ้นสูง ทันที (ไม่ Tween ขึ้น)
    setPhysics(true)
    local flyY = math.max(root.Position.Y, targetCF.Position.Y) + FLY_HEIGHT_OFFSET
    local highPos = CFrame.new(root.Position.X, flyY, root.Position.Z)
    root.CFrame = highPos
    root.AssemblyLinearVelocity = Vector3.new(0,0,0)
    task.wait(0.1)

    -- Step 2: Tween ในอากาศไปเหนือเป้าหมาย
    local aboveTarget = CFrame.new(targetCF.Position.X, flyY, targetCF.Position.Z)
    local horizDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(targetCF.Position.X, 0, targetCF.Position.Z)).Magnitude
    local tw2 = TweenService:Create(root, TweenInfo.new(horizDist / SPEED, Enum.EasingStyle.Linear), {CFrame = aboveTarget})
    tw2:Play()
    tw2.Completed:Wait()

    -- Step 3: วาร์ปลงหา Target ทันที (ไม่ Tween ลง)
    setPhysics(false)
    root.CFrame = targetCF
    root.AssemblyLinearVelocity = Vector3.new(0,0,0)
    root.AssemblyAngularVelocity = Vector3.new(0,0,0)
    task.wait(0.2)
end

local function isTargetAlive(targetObj)
    if not targetObj or not targetObj.Parent then return false end
    -- เช็คแบบลึก: บางมอนเก็บ Health/Dead ไว้ใน descendants
    local hp = targetObj:FindFirstChild("Health", true)
    local dead = targetObj:FindFirstChild("Dead", true)

    if hp and hp:IsA("ValueBase") then
        local n = tonumber(hp.Value)
        if n and n <= 0 then return false end
    end
    if dead and dead:IsA("BoolValue") and dead.Value == true then
        return false
    end

    return true
end

local function findNearestPortalMinion(radius)
    local root = getRoot()
    if not root then return nil end
    
    local nearest = nil
    local minD = radius

    -- สแกนทั้งหมดใน Workspace.MobFolder (ไม่กรองชื่อมอน)
    local mobFolder = workspace:FindFirstChild("MobFolder")
    if not mobFolder then return nil end
    for _, mob in pairs(mobFolder:GetChildren()) do
        if mob:IsA("Model") and isTargetAlive(mob) then
            local hrp = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart")
            if hrp then
                local d = (root.Position - hrp.Position).Magnitude
                if d < minD then
                    minD = d
                    nearest = mob
                end
            end
        end
    end
    return nearest
end

local function isDead(node)
    if not node or not node.Parent then return true end
    local deadVal = node:FindFirstChild("Dead", true)
    if deadVal and deadVal:IsA("BoolValue") and deadVal.Value == true then return true end
    local hpVal = node:FindFirstChild("Health", true)
    if hpVal and hpVal:IsA("ValueBase") and tonumber(hpVal.Value) and tonumber(hpVal.Value) <= 0 then return true end
    if not node:FindFirstChild("BillboardPart", true) then return true end
    return false
end

-- ============================================================
-- [[ 🧠 SMART QUEST SCANNER v2: MODULE-BASED (LANGUAGE-AGNOSTIC) ]]
-- ดึงข้อมูลจาก ModuleScript ของเกมโดยตรง ไม่สนภาษา!
-- ใช้ LayoutOrder + RequiredAmount เพื่อระบุประเภทเควสแบบ 100% แม่นยำ
-- ============================================================
local WorldMissionData = nil
pcall(function()
    WorldMissionData = require(ReplicatedStorage.Storage.Missions.WorldMissions)
end)
if WorldMissionData then
    warn("✅ [SmartScanner] โหลด WorldMissions Module สำเร็จ!")
else
    warn("⚠️ [SmartScanner] ไม่สามารถโหลด Module ได้ จะใช้ค่า Fallback")
end


-- Fallback RequiredAmounts (ใช้เมื่อ require ไม่ได้)
local FALLBACK_AMOUNTS = {
    EggQuest      = {Default = 5,  Lobby = 1},
    RidingRing    = {Default = 30, Lobby = 10},
    TreasureChest = {Default = 3},
    KillMobs      = {Default = 15, Lobby = 10},
    KillBoss      = {Default = 1},
    SpendTime      = {Default = 450},
    Harvest       = {Default = 50},
}

local function getMaxAmount(questType, worldName)
    -- ลองดึงจาก Module จริงก่อน
    if WorldMissionData and WorldMissionData[questType] then
        local def = WorldMissionData[questType]
        if def.CustomRequiredAmounts and def.CustomRequiredAmounts[worldName] then
            return def.CustomRequiredAmounts[worldName]
        end
        return def.RequiredAmount
    end
    -- Fallback
    local fb = FALLBACK_AMOUNTS[questType]
    if fb then return fb[worldName] or fb.Default or 0 end
    return 0
end

local function getQuestRemaining(questType, worldName)
    local maxAmount = getMaxAmount(questType, worldName)
    if maxAmount == 0 then return 0 end

    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return 0 end

    local hudGui = pg:FindFirstChild("HUDGui")
    local missionsFrame = hudGui and hudGui:FindFirstChild("MissionsFrame")
    
    if not missionsFrame then
        warn("⚠️ [Scanner] ไม่พบ HUDGui.MissionsFrame รอโหลดก่อน...")
        return 0
    end

    -- เจาะจงหา Frame ใน HUD ที่มีชื่อตรงกับเควส + โลก (เช่น KillMobsOcean จะตรงกับ KillMobs + Ocean)
    for _, desc in ipairs(missionsFrame:GetDescendants()) do
        local nameMatch = (desc.Name:find(questType) or (questType:find("Boss") and desc.Name:find("Boss")))
        local worldMatch = desc.Name:find(worldName)
        
    -- ☢️ Wasteland/Toxic/Prehistoric/Shinrin Fallback: เฉพาะโลก Wasteland/Wastelands/Toxic/Prehistoric/Shinrin เท่านั้น
    -- ถ้าหาชื่อโลกในชื่อ Frame ไม่เจอ ให้รับ Frame ที่ไม่มีชื่อโลกอื่นปนอยู่
    if not worldMatch and (worldName == "Wasteland" or worldName == "Wastelands" or worldName == "Toxic" or worldName == "Prehistoric" or worldName == "Shinrin") then
        local otherWorlds = {"Lobby", "Origins", "Grassland", "Jungle", "Volcano", "Tundra", "Ocean", "Desert", "Fantasy"}
        local isOther = false
        for _, w in ipairs(otherWorlds) do if desc.Name:find(w) then isOther = true break end end
        if not isOther then worldMatch = true end
    end

        if nameMatch and worldMatch and (desc:IsA("Frame") or desc:IsA("ImageButton")) then
            -- หา ProgressLabel ข้างใน
            local rightSide = desc:FindFirstChild("RightSideFrame")
            local progLabel = rightSide and rightSide:FindFirstChild("ProgressLabel")
            
            if progLabel and progLabel:IsA("TextLabel") then
                local rawText = progLabel.Text:gsub("<[^>]+>", "")
                local cur, mx = rawText:match("(%d+)%s*/%s*(%d+)")
                
                if cur and mx then
                    local curNum = tonumber(cur)
                    local mxNum = tonumber(mx)
                    local needed = mxNum - curNum
                    warn("📊 [Scanner] " .. questType .. " เจอเป้าหมายจริง!: " .. cur .. "/" .. mx .. " → เหลืออีก " .. math.max(0, needed))
                    return math.max(0, needed)
                end
                if questType == "SpendTime" then
                    local curMin, curSec, mxMin, mxSec = rawText:match("(%d+):(%d+)%s*/%s*(%d+):(%d+)")
                    if curMin and mxMin then
                        local curNum = tonumber(curMin) * 60 + tonumber(curSec)
                        local mxNum = tonumber(mxMin) * 60 + tonumber(mxSec)
                        local needed = mxNum - curNum
                        warn("📊 [Scanner] SpendTime: " .. curMin .. ":" .. curSec .. "/" .. mxMin .. ":" .. mxSec .. " → เหลืออีก " .. math.max(0, needed) .. "s")
                        return math.max(0, needed)
                    end
                elseif questType:find("Boss") then
                    -- สำหรับเควสบอส บางทีมันไม่มีตัวเลขขึ้น (เช่นโชว์แค่ Defeat Boss) ให้ถือว่าเหลือ 1
                    warn("📊 [Scanner] พบเควสบอสแล้วแต่ไม่มีตัวเลขคืบหน้า ให้ค่าเริ่มต้นเป็น 1")
                    return 1
                end
            end
        end
    end

    -- ถ้าหาบน HUD ไม่เจอ แปลว่าไม่ได้ปักหมุด หรือทำเสร็จแล้ว
    return 0
end

-- [[ 📍 AUTO TRACKER ]]
local function trackQuest(questType, worldName)
    local focusR = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("FocusMissionRemote")
    if focusR then
        warn("📌 [AutoTrack] กำลังปักหมุดเควส: " .. questType)
        focusR:FireServer("WorldMission", worldName, questType, true)
        task.wait(0.3)
    end
end

-- โลกนี้มี SpendTime ใน Data จริงหรือไม่ (Grassland ไม่มี — ไม่ต้องรอเวลา)
local function hasSpendTimeMission(worldName)
    local data = LP:FindFirstChild("Data")
    local worldMissions = data and data:FindFirstChild("WorldMissions")
    local worldFolder = worldMissions and worldMissions:FindFirstChild(worldName)
    local missions = worldFolder and worldFolder:FindFirstChild("Missions")
    return missions and missions:FindFirstChild("SpendTime") ~= nil
end

local function parseSpendTimeLabel(rawText)
    if type(rawText) ~= "string" then return nil end
    local text = rawText:gsub("<[^>]+>", "")
    local curMin, curSec, mxMin, mxSec = text:match("(%d+):(%d+)%s*/%s*(%d+):(%d+)")
    if curMin then
        local current = tonumber(curMin) * 60 + tonumber(curSec)
        local maxAmount = tonumber(mxMin) * 60 + tonumber(mxSec)
        return current, maxAmount, math.max(0, maxAmount - current), text
    end
    local cur, mx = text:match("(%d+)%s*/%s*(%d+)")
    if cur and mx then
        local current = tonumber(cur)
        local maxAmount = tonumber(mx)
        return current, maxAmount, math.max(0, maxAmount - current), text
    end
    return nil
end

-- อ่านเวลาจาก HUD จริง 100% — หา Frame ที่ชื่อมี SpendTime ไม่บังคับชื่อโลก
local function scanHudSpendTime()
    local pg = LP:FindFirstChild("PlayerGui")
    local hudGui = pg and pg:FindFirstChild("HUDGui")
    local missionsFrame = hudGui and hudGui:FindFirstChild("MissionsFrame")
    if not missionsFrame then
        return { found = false }
    end

    for _, desc in ipairs(missionsFrame:GetDescendants()) do
        if (desc:IsA("Frame") or desc:IsA("ImageButton")) and desc.Name:find("SpendTime", 1, true) then
            local rightSide = desc:FindFirstChild("RightSideFrame")
            local progLabel = (rightSide and rightSide:FindFirstChild("ProgressLabel"))
                or desc:FindFirstChild("ProgressLabel", true)
            if progLabel and progLabel:IsA("TextLabel") then
                local current, maxAmount, remaining, raw = parseSpendTimeLabel(progLabel.Text)
                if current then
                    return {
                        found = true,
                        current = current,
                        max = maxAmount,
                        remaining = remaining,
                        raw = raw,
                    }
                end
                return { found = true, current = 0, max = 0, remaining = 0, raw = progLabel.Text }
            end
        end
    end
    return { found = false }
end

local function getSpendTimeData(worldName)
    local data = LP:FindFirstChild("Data")
    local worldMissions = data and data:FindFirstChild("WorldMissions")
    local worldFolder = worldMissions and worldMissions:FindFirstChild(worldName)
    local missions = worldFolder and worldFolder:FindFirstChild("Missions")
    local spendNode = missions and missions:FindFirstChild("SpendTime")
    if not spendNode then return nil end

    local current = 0
    local progress = spendNode:FindFirstChild("Progress")
    if progress and progress:IsA("IntValue") then
        current = progress.Value
    end
    local completed = spendNode:IsA("BoolValue") and spendNode.Value == true
    return { current = current, completed = completed }
end

-- เควส SpendTime = อ่าน HUD เป็นหลัก แล้วค่อยดู Data
local function getSpendTimeProgress(worldName)
    if not hasSpendTimeMission(worldName) then
        return nil
    end

    local maxAmount = getMaxAmount("SpendTime", worldName)
    if maxAmount <= 0 then maxAmount = 450 end

    local dataSt = getSpendTimeData(worldName)
    local current = dataSt and dataSt.current or 0
    local done = dataSt and dataSt.completed or false

    local hud = scanHudSpendTime()
    if hud.found and hud.max and hud.max > 0 then
        current = math.max(current, hud.current)
        maxAmount = hud.max
        if hud.remaining > 0 then
            done = false
        elseif hud.remaining == 0 and hud.current >= hud.max then
            done = true
        end
    end

    if current >= maxAmount then
        done = true
    end

    return {
        done = done,
        current = current,
        max = maxAmount,
        remaining = math.max(0, maxAmount - current),
        hudRemaining = hud.found and hud.remaining or 0,
        hudFound = hud.found == true,
    }
end

local function formatSpendWaitText(displayName, rem, cur, mx)
    rem = math.max(0, math.floor(tonumber(rem) or 0))
    local mins = math.floor(rem / 60)
    local secs = rem % 60
    return "⏱️ [" .. displayName .. "] Waiting for time quest  ~" .. mins .. "m " .. secs .. "s left  (" .. tostring(cur or 0) .. "/" .. tostring(mx or 0) .. ")"
end
local function waitForSpendTimeMission(displayName, internalName, flagKey, maxWait)
    local st = getSpendTimeProgress(internalName)
    if not st or st.done then return true end

    showCenterWarning(true, "⏱️ [" .. displayName .. "] Waiting for time quest...")

    local hud = scanHudSpendTime()
    -- อย่าปัก SpendTime ถ้ายังเป็นแค่รอรอบสั้น — จะไปแย่งหมุดเควสอื่น
    if not hud.found and not maxWait then
        warn("⏱️ [" .. displayName .. "] ปักหมุด SpendTime เพื่ออ่านเวลาบน HUD")
        showCenterWarning(true, "⏱️ [" .. displayName .. "] Pinning time quest...")
        trackQuest("SpendTime", internalName)
        local pinDeadline = os.clock() + 8
        while os.clock() < pinDeadline and _G[flagKey] do
            hud = scanHudSpendTime()
            if hud.found then break end
            task.wait(0.35)
        end
    end

    st = getSpendTimeProgress(internalName)
    if not st or st.done then
        showCenterWarning(false)
        return true
    end

    if hud.found or (st.current or 0) > 0 then
        local shown = hud.found and (hud.raw or (hud.current .. "/" .. hud.max)) or (st.current .. "/" .. st.max)
        warn("⏱️ [" .. displayName .. "] อ่านเวลาได้แล้ว: " .. shown .. " — รอจนครบ (ไม่ย้ายเซิร์ฟ)")
        local lastLog = 0
        local sliceEnd = maxWait and (os.clock() + maxWait) or nil
        while _G[flagKey] do
            st = getSpendTimeProgress(internalName)
            hud = scanHudSpendTime()
            local remaining = (hud.found and hud.remaining) or (st and st.remaining) or 0
            local cur = (hud.found and hud.current) or (st and st.current) or 0
            local mx = (hud.found and hud.max) or (st and st.max) or 0
            showCenterWarning(true, formatSpendWaitText(displayName, remaining, cur, mx))
            if (st and st.done) or (hud.found and hud.remaining <= 0 and hud.max > 0) then
                warn("✅ [SpendTime] เควสเวลาเสร็จ — " .. displayName)
                showCenterWarning(true, "✅ [" .. displayName .. "] Time quest complete")
                task.wait(1.2)
                showCenterWarning(false)
                return true
            end
            if sliceEnd and os.clock() >= sliceEnd then
                showCenterWarning(false)
                return false
            end
            if os.clock() - lastLog >= 15 then
                local mins = math.floor(remaining / 60)
                local secs = remaining % 60
                warn("⏱️ [" .. displayName .. "] รอในเซิร์ฟ... เหลือ ~" .. mins .. "m " .. secs .. "s (" .. cur .. "/" .. mx .. ")")
                lastLog = os.clock()
            end
            task.wait(5)
        end
        showCenterWarning(false)
        return false
    end

    if maxWait then
        showCenterWarning(false)
        return false
    end

    warn("⏱️ [" .. displayName .. "] HUD ไม่มีเควสเวลา และ Data ยัง 0 — ย้ายเซิร์ฟหาเซิร์ฟที่มีเควส")
    showCenterWarning(true, "🌐 [" .. displayName .. "] No time quest — hopping server...")
    hopToNewServer("SpendTime not on HUD")
    showCenterWarning(false)
    return false
end

-- ============================================================
-- [[ SHARED QUEST FUNCTIONS ]]
-- ============================================================

-- 🥚 EGG COLLECTOR
local function collectEggs(amount, flagKey, worldName)
    local Rem = ReplicatedStorage:WaitForChild("Remotes")
    local FocusR = Rem:FindFirstChild("FocusMissionRemote")
    local SetR = Rem:FindFirstChild("SetCollectEggRemote")
    local CollR = Rem:FindFirstChild("CollectEggRemote")
    if not (FocusR and SetR and CollR) then return end

    local collected = 0
    while collected < amount and _G[flagKey] do
        local interactions = workspace:FindFirstChild("Interactions")
        local eggNodes = interactions and interactions:FindFirstChild("Nodes")
            and interactions.Nodes:FindFirstChild("Eggs")
            and interactions.Nodes.Eggs:FindFirstChild("ActiveNodes")
        if not eggNodes then task.wait(2) continue end

        local activeNodes = eggNodes:GetChildren()
        if #activeNodes == 0 then task.wait(2) continue end

        local root = getRoot()
        if not root then task.wait(1) continue end

        local nearestNode, minDist = nil, math.huge
        for _, node in pairs(activeNodes) do
            local ok, p = pcall(function() return node:GetPivot().Position end)
            if ok then
                local d = (root.Position - p).Magnitude
                if d < minDist then minDist = d nearestNode = node end
            end
        end

        if nearestNode then
            -- 🚀 ลงไปใกล้ไข่มากขึ้น (จาก 15 เหลือ 5) เพื่อให้เกมตัดสินใจว่าเราอยู่ใกล้จริงๆ
            flyTo(nearestNode:GetPivot() * CFrame.new(0, 5, 0))
            
            local eggId = nearestNode.Name
            FocusR:FireServer("WorldMission", worldName, "EggQuest")
            
            local success = false
            pcall(function()
                SetR:InvokeServer(eggId)
                success = CollR:InvokeServer(eggId)
            end)
            
            if success == true then
                collected = collected + 1
            else
                -- ⚡ Fallback แบบติดจรวด (หยุดทันทีที่เจอ ไม่รันครบ 20 รอบ)
                for i = 1, 25 do
                    if not _G[flagKey] then return end
                    local idStr = tostring(i)
                    task.spawn(function()
                        pcall(function() SetR:InvokeServer(idStr) end)
                    end)
                    -- รัน CollR สลับทีละตัว
                    local s2 = false
                    pcall(function() s2 = CollR:InvokeServer(idStr) end)
                    if s2 == true then
                        collected = collected + 1
                        break
                    end
                end
            end
        end
        task.wait(0.05) -- ลดดีเลย์รอรอบต่อไปให้ไวที่สุด
    end
end

-- 💍 RING FLYER (Nearest First)
local monsterLockConnection = nil
local monsterLockTarget = nil
local monsterLockHeight = 15

-- Ghost Mode & Safe Noclip Logic
local noclipCharParts = {}
local noclipDragonParts = {}
local noclipCacheChar = nil
local noclipCacheDragon = nil
local noclipCacheRefreshAt = 0

local function applyGhostPhysicsStep()
    local char = LP.Character
    local dragon = getActiveDragonModel()
    local root = getRoot()
    if not char or not root then return end

    local now = os.clock()
    if char ~= noclipCacheChar or dragon ~= noclipCacheDragon or now >= noclipCacheRefreshAt then
        noclipCacheChar = char
        noclipCacheDragon = dragon
        noclipCacheRefreshAt = now + 2
        noclipCharParts = {}
        noclipDragonParts = {}

        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then table.insert(noclipCharParts, v) end
        end
        if dragon then
            for _, v in pairs(dragon:GetDescendants()) do
                if v:IsA("BasePart") then table.insert(noclipDragonParts, v) end
            end
        end
    end

    local isGhost = _G.GhostMode
    local isNearGround = false
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char, dragon}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local ray = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), rayParams)
    if ray then isNearGround = true end

    -- อัปเดตชิ้นส่วนตัวละคร
    for _, part in ipairs(noclipCharParts) do
        if part and part.Parent then
            if isGhost then
                -- [[ 👻 GHOST MODE ]]
                part.CanTouch = true -- เปิดเพื่อเก็บของได้ (อมตะผ่าน MobDamageRemote block + Heal 60fps)
                part.CanQuery = false -- กันมอนสแกนเจอ
                if part.Name == "HumanoidRootPart" then
                    part.CanCollide = true -- กันตกพื้น
                else
                    part.CanCollide = false -- บังคับมอนทะลุ
                end
            else
                -- [[ 🛡️ NORMAL/SAFE NOCLIP ]]
                part.CanTouch = true
                part.CanQuery = true
                if part.Name == "HumanoidRootPart" and isNearGround then
                    part.CanCollide = true
                else
                    part.CanCollide = false
                end
            end
        end
    end

    -- อัปเดตชิ้นส่วนมังกร
    for _, part in ipairs(noclipDragonParts) do
        if part and part.Parent then
            if isGhost then
                part.CanTouch = true -- เปิดเพื่อเก็บของได้ (อมตะผ่าน MobDamageRemote block + Heal 60fps)
                part.CanQuery = false
                if part.Name == "HumanoidRootPart" then
                    part.CanCollide = true
                else
                    part.CanCollide = false
                end
            else
                part.CanTouch = true
                part.CanQuery = true
                if part.Name == "HumanoidRootPart" then
                    part.CanCollide = true
                else
                    part.CanCollide = false
                end
            end
        end
    end
end

local function lockPlayerToMonster(target, height)
    if monsterLockConnection then monsterLockConnection:Disconnect() end
    monsterLockTarget = target
    monsterLockHeight = height or 15
    monsterLockConnection = RunService.Heartbeat:Connect(function(dt)
        if not monsterLockTarget or (typeof(monsterLockTarget) == "Instance" and not monsterLockTarget.Parent) then 
            if monsterLockConnection then monsterLockConnection:Disconnect() monsterLockConnection = nil end
            return 
        end

        local root = getRoot()
        if root then
            local ok, cf = pcall(function() 
                return (typeof(monsterLockTarget) == "Instance") and monsterLockTarget:GetPivot() or monsterLockTarget 
            end)
            if ok then
                -- บังคับล็อคพิกัดและเคลียร์แรงทุกเฟรม (Heartbeat) รับรองนิ่งสนิท ไม่สะบัด ไม่กระตุก
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                root.CFrame = cf * CFrame.new(0, monsterLockHeight, 0)
            end
        end
    end)
end

local function unlockPlayerFromMonster()
    if monsterLockConnection then monsterLockConnection:Disconnect() monsterLockConnection = nil end
end

local function releaseTravelLock()
    unlockPlayerFromMonster()
    setPhysics(false)
    local root = getRoot()
    if root then
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

local function unlockPlayer()
    unlockPlayerFromMonster()
end

local function flyRings(amount, flagKey)
    local ringsFolder = workspace:FindFirstChild("Interactions")
        and workspace.Interactions:FindFirstChild("RidingRings")
        and workspace.Interactions.RidingRings:FindFirstChild("Flying")
    if not ringsFolder then return end

    local available = {}
    for _, ring in ipairs(ringsFolder:GetChildren()) do
        if ring:IsA("BasePart") then table.insert(available, ring) end
    end

    local count = 0
    while #available > 0 and count < amount and _G[flagKey] do
        local root = getRoot()
        if not root then task.wait(1) break end
        local nearest, idx, minD = nil, -1, math.huge
        for i, ring in ipairs(available) do
            local d = (root.Position - ring.Position).Magnitude
            if d < minD then minD = d nearest = ring idx = i end
        end
        if nearest then
            -- ห่วงอยู่สูงอยู่แล้ว ไม่ต้องหนี Portal ใช้ Tween ตรงได้เลย
            setPhysics(true)
            local tw = TweenService:Create(root, TweenInfo.new(minD / SPEED, Enum.EasingStyle.Linear), {CFrame = nearest.CFrame})
            tw:Play()
            tw.Completed:Wait()
            setPhysics(false)
            table.remove(available, idx)
            count = count + 1
            task.wait(0.1)
        else break end
    end
end

-- ============================================================
-- [[ 🔒 HEARTBEAT LOCKER (AUTO-AIMMING) ]]
-- ============================================================

-- ⚔️ MOB KILLER (Real-time HUD update)
local function killMobs(targetAmount, flagKey, worldName)
    while _G[flagKey] do
        -- เช็คความคืบหน้าจริงจากหน้าจอทุกครั้ง
        local remaining = getQuestRemaining("KillMobs", worldName)
        if remaining <= 0 then 
            warn("✅ [KillMobs] ภารกิจมอนสเตอร์เสร็จสิ้น!")
            break 
        end

        local root = getRoot()
        local mobFolder = workspace:FindFirstChild("MobFolder")
        if not (root and mobFolder) then task.wait(1) continue end

        local nearest, minD = nil, math.huge
        for _, obj in pairs(mobFolder:GetDescendants()) do
            if (obj:IsA("MeshPart") or obj:IsA("Part")) and isTargetAlive(obj) then
                local d = (root.Position - obj.Position).Magnitude
                if d < minD then minD = d nearest = obj end
            end
        end

        if nearest then
            -- เช็คอีกทีก่อนบิน (กันกรณี mob ตายระหว่างสแกน)
            if not isTargetAlive(nearest) then task.wait(0.3) continue end

            local mobTrack = nearest
            if nearest.Parent and nearest.Parent:IsA("Model") then
                mobTrack = nearest.Parent
            end
            
            flyTo(mobTrack:GetPivot() * CFrame.new(0, 15, 0))
            
            -- เช็คอีกทีหลังบินถึง (กันกรณี mob ตายระหว่างบิน)
            if not isTargetAlive(nearest) then 
                task.wait(0.3) 
                continue 
            end
            
            local dragon = getActiveDragonModel()
            if dragon and dragon:FindFirstChild("Remotes") then
                local soundR = dragon.Remotes:FindFirstChild("PlaySoundRemote")
                local breathR = dragon.Remotes:FindFirstChild("BreathFireRemote")
                if breathR then breathR:FireServer(true) end
                
                local t = os.clock()
                -- ล็อคตามมอน (Instance) ไม่ใช้พิกัดคงที่ — มอนเดินหนีก็ตามไป
                lockPlayerToMonster(mobTrack, 15)
                
                while _G[flagKey] and isTargetAlive(nearest) and (os.clock() - t < 15) do
                    -- [[ 🔥 AURA DAMAGE: โจมตี 1 ครั้งต่อ 1 ตัวในรัศมี 50 Studs ]]
                    local rootForAura = getRoot()
                    if rootForAura then
                        local attackedMobs = {}
                        for _, obj in pairs(mobFolder:GetDescendants()) do
                            if (obj:IsA("MeshPart") or obj:IsA("Part")) and isTargetAlive(obj) then
                                local mobModel = obj.Parent
                                if mobModel and not attackedMobs[mobModel] then
                                    local d = (rootForAura.Position - obj.Position).Magnitude
                                    if d <= 50 then
                                        if soundR then soundR:FireServer("Breath", "Mobs", obj) end
                                        attackedMobs[mobModel] = true -- จำไว้ว่าตีตัวนี้ไปแล้วในรอบนี้
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.25)
                end
                
                unlockPlayerFromMonster()
                if breathR then breathR:FireServer(false) end
            end

        else
            task.wait(2)
        end
        task.wait(0.5)
    end
end

-- 🍎 HARVESTER (FIX: บินสูงเลี่ยง Portal)
-- 🍎 HARVESTER (Real-time HUD update - สนใจจำนวนของที่ดรอป ไม่ใช่จำนวนต้นไม้)
local function harvestResources(targetAmount, flagKey, worldName)
    local Rem = ReplicatedStorage:WaitForChild("Remotes")
    local HitRemote = Rem:FindFirstChild("ClientDestructibleHitRemote")
    if not HitRemote then return end

    while _G[flagKey] do
        -- อัปเดต Progress จาก HUD ตลอดเวลา (เพราะ 1 ต้นอาจได้ของหลายชิ้น)
        local remaining = getQuestRemaining("Harvest", worldName)
        if remaining <= 0 then 
            warn("✅ [Harvest] เก็บเกี่ยวครบตามจำนวนบน HUD แล้ว!")
            break 
        end

        local root = getRoot()
        local nodes = workspace:FindFirstChild("Interactions") and workspace.Interactions:FindFirstChild("Nodes")
        if not (root and nodes) then task.wait(1) continue end

        local nearest, minD = nil, math.huge
        for _, folderName in ipairs({"Food", "Resources"}) do
            local folder = nodes:FindFirstChild(folderName)
            if folder then
                for _, node in pairs(folder:GetChildren()) do
                    if node:IsA("Model") and not isDead(node) then
                        local ok, p = pcall(function() return node:GetPivot().Position end)
                        if ok then
                            local d = (root.Position - p).Magnitude
                            if d < minD then minD = d nearest = node end
                        end
                    end
                end
            end
        end

        if nearest then
            -- ดิ่งลงพื้น (-10 จากแกนกลาง) เพื่อให้ชนไอเท็มดรอปที่พื้น
            flyTo(nearest:GetPivot() * CFrame.new(0, -10, 0))
            local billboard = nearest:FindFirstChild("BillboardPart", true)
            local dragon = getActiveDragonModel()
            local t = os.clock()
            
            -- ล็อคพิกัดแนบแน่นกับต้นไม้ ป้องกันภาพตัดหรือกระตุกไปมา
            lockPlayerToMonster(nearest, -10)
            
            while _G[flagKey] and not isDead(nearest) and (os.clock() - t < 12) do
                pcall(function()
                    if dragon and dragon:FindFirstChild("Remotes") then
                        dragon.Remotes.PlaySoundRemote:FireServer("Breath", "Destructibles", billboard)
                    end
                    HitRemote:FireServer(nearest, billboard)
                end)
                task.wait(0.15)
            end
            unlockPlayerFromMonster()
        else
            task.wait(2)
        end
        task.wait(0.3)
    end
end

-- ============================================================
-- [[ 🗺️ CHEST SPAWN PATROL — บินวนทุกจุดใน Treasure รอหีบเกิด ]]
-- ============================================================
local PATROL_MAX_SECONDS = 90
local CHEST_SMART_SKIP_PATROL = 6 -- สแกนสั้นๆ ก่อนข้ามไปเควสอื่น (Smart Loop)
local CHEST_NODE_BLACKLIST = {} -- [nodeId] = true (บัคถาวร) | number (expire os.clock)
local CHEST_NODE_BLACKLIST_BUG = 600 -- วินาทีก่อนลอง node เดิมอีก (respawn)

local function getTreasureFolder()
    local nodes = workspace:FindFirstChild("Interactions") and workspace.Interactions:FindFirstChild("Nodes")
    if not nodes then return nil end
    return nodes:FindFirstChild("Treasure")
        or nodes:FindFirstChild("TreasureChests")
        or nodes:FindFirstChild("TreasureChest")
        or nodes:FindFirstChild("Treasure Chests")
end

local function zeroRootMotion(root)
    if not root then return end
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local function getInstanceFlyCFrame(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then
        return CFrame.new(inst.Position + Vector3.new(0, 8, 0))
    end
    if inst:IsA("Model") then
        local hrp = inst:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.CFrame * CFrame.new(0, 8, 0) end
        if inst.PrimaryPart then
            return inst.PrimaryPart.CFrame * CFrame.new(0, 8, 0)
        end
        local part = inst:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.CFrame * CFrame.new(0, 8, 0) end
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok and cf then return cf * CFrame.new(0, 8, 0) end
    end
    return nil
end

local function getChestNodeId(chestModel)
    if not chestModel then return nil end
    local treasure = getTreasureFolder()
    if not treasure then return nil end
    if chestModel.Parent == treasure then
        return tonumber(chestModel.Name)
    end
    if chestModel.Parent and chestModel.Parent.Parent == treasure then
        return tonumber(chestModel.Parent.Name)
    end
    return nil
end

local function isChestNodeBlacklisted(nodeId)
    if not nodeId then return false end
    local key = tostring(nodeId)
    local entry = CHEST_NODE_BLACKLIST[key]
    if not entry then return false end
    if entry == true then return true end
    if type(entry) == "number" and os.clock() > entry then
        CHEST_NODE_BLACKLIST[key] = nil
        return false
    end
    return true
end

local function markChestNodeDone(chestModel, reason, permanent)
    local nodeId = getChestNodeId(chestModel)
    if not nodeId then return end
    local key = tostring(nodeId)
    if permanent then
        CHEST_NODE_BLACKLIST[key] = true
    else
        CHEST_NODE_BLACKLIST[key] = os.clock() + CHEST_NODE_BLACKLIST_BUG
    end
    warn("📦 [Chest] จำ node " .. key .. " แล้ว (" .. reason .. ")")
end

local function isChestModelAlive(model)
    if not (model and model:IsA("Model")) then return false end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local hp = hrp:FindFirstChild("Health")
    local dead = hrp:FindFirstChild("Dead")
    return (hp and hp.Value > 0) and (not dead or dead.Value == false)
end

local function shouldSkipChestModel(model)
    if not model then return true end
    return isChestNodeBlacklisted(getChestNodeId(model))
end

local function findNearestLiveChest()
    local root = getRoot()
    local treasure = getTreasureFolder()
    if not root or not treasure then return nil end
    local nearest, minD = nil, math.huge
    for _, nodeSlot in pairs(treasure:GetChildren()) do
        if not shouldSkipChestModel(nodeSlot) and isChestModelAlive(nodeSlot) then
            local hrp = nodeSlot.HumanoidRootPart
            local d = (root.Position - hrp.Position).Magnitude
            if d < minD then
                minD = d
                nearest = nodeSlot
            end
        end
        for _, chest in pairs(nodeSlot:GetChildren()) do
            if not shouldSkipChestModel(chest) and isChestModelAlive(chest) then
                local hrp = chest.HumanoidRootPart
                local d = (root.Position - hrp.Position).Magnitude
                if d < minD then
                    minD = d
                    nearest = chest
                end
            end
        end
    end
    return nearest
end

-- ดึงพิกัดทุกจุดจาก workspace.Interactions.Nodes.Treasure
local function getTreasureSpawnPoints()
    local treasure = getTreasureFolder()
    if not treasure then return {} end
    local points = {}
    for _, nodeSlot in ipairs(treasure:GetChildren()) do
        local cf = getInstanceFlyCFrame(nodeSlot)
        if not cf then
            for _, child in ipairs(nodeSlot:GetChildren()) do
                cf = getInstanceFlyCFrame(child)
                if cf then break end
            end
        end
        if cf then
            table.insert(points, {
                id = nodeSlot.Name,
                cframe = cf,
                position = cf.Position,
            })
        end
    end
    local root = getRoot()
    if root then
        local rp = root.Position
        table.sort(points, function(a, b)
            return (a.position - rp).Magnitude < (b.position - rp).Magnitude
        end)
    end
    return points
end

-- บินวนทุกจุด spawn — เจอหีบใหม่ return ทันทีให้เปิด
local function runChestSpawnPatrol(flagKey, maxSeconds)
    if not _G[flagKey] then return nil end

    local live = findNearestLiveChest()
    if live then return live end

    setPhysics(true)
    warn("🗺️ [Chest Patrol] Cycling Treasure spawn points...")
    pcall(function()
        hubNotify("Map Patrol", "Visiting all treasure spawn points (loop)...", 3)
    end)

    local deadline = os.clock() + (maxSeconds or PATROL_MAX_SECONDS)
    local lap = 0

    while _G[flagKey] and os.clock() < deadline do
        lap = lap + 1
        local points = getTreasureSpawnPoints()
        if #points == 0 then
            warn("🗺️ [Chest Patrol] Treasure folder empty — wait respawn")
            task.wait(2)
        else
            warn("🗺️ [Chest Patrol] Lap " .. tostring(lap) .. " | " .. tostring(#points) .. " points")
            for _, pt in ipairs(points) do
                if not _G[flagKey] or os.clock() >= deadline then break end

                live = findNearestLiveChest()
                if live then
                    setPhysics(false)
                    pcall(function()
            hubNotify("Map Patrol", "New chest detected!", 2)
                    end)
                    return live
                end

                flyTo(pt.cframe)

                for _ = 1, 8 do
                    if not _G[flagKey] or os.clock() >= deadline then break end
                    live = findNearestLiveChest()
                    if live then
                        setPhysics(false)
                        pcall(function()
                            hubNotify("Map Patrol", "Chest spawned — opening!", 2)
                        end)
                        return live
                    end
                    task.wait(0.3)
                end
            end
        end
        task.wait(0.4)
    end

    setPhysics(false)
    return findNearestLiveChest()
end

-- 📦 CHEST FINDER (Smart Skip: ไม่มีหีบ → return 0 ให้ทำเควสอื่นก่อน)
local function findChests(amount, flagKey, worldName, opts)
    opts = opts or {}
    local smartSkip = opts.smartSkip
    local patrolMax = smartSkip and (opts.patrolSeconds or CHEST_SMART_SKIP_PATROL) or PATROL_MAX_SECONDS

    local found = 0
    while found < amount and _G[flagKey] do
        local root = getRoot()
        local treasure = getTreasureFolder()
        if not (root and treasure) then
            if smartSkip then return found end
            task.wait(2)
            continue
        end

        local nearest = findNearestLiveChest()
        if not nearest then
            if smartSkip then
                warn("📦 [Chest] ไม่เจอหีบ — สแกนจุด spawn " .. patrolMax .. "s ก่อนข้าม...")
                nearest = runChestSpawnPatrol(flagKey, patrolMax)
                if not nearest then
                    warn("📦 [Chest] หีบยังไม่เกิด — ข้ามไปเควสอื่นก่อน")
                    return found
                end
            else
                while not nearest and _G[flagKey] do
                    warn("📦 [Chest] No live chest — cycling spawn points...")
                    showCenterWarning(true, "⚠️ [Map Patrol — waiting for chest spawn] ⚠️")
                    nearest = runChestSpawnPatrol(flagKey, patrolMax)
                    showCenterWarning(false)
                    if not nearest then
                        task.wait(1)
                    end
                end
            end
        end
        if not nearest then break end
            local hrp = nearest.HumanoidRootPart
            local chestPos = hrp.Position
            
            -- 🚀 บินไปอยู่เหนือหีบเตรียมทำพายุพ่นไฟ
            flyTo(CFrame.new(chestPos + Vector3.new(0, 8, 0)))
            
            -- เปิดไฟพ่น
            local dragon = getActiveDragonModel()
            local breathR = dragon and dragon:FindFirstChild("Remotes") and dragon.Remotes:FindFirstChild("BreathFireRemote")
            if breathR then breathR:FireServer(true) end
            
            -- 🌪️ ระบบหมุนควงสว่าน 360 องศา (X และ Y)
            unlockPlayerFromMonster() -- ปลดล็อคระบบเดิมก่อน
            local chestLocker = true
            local startSpinTime = os.clock()
            local spinConn = RunService.Heartbeat:Connect(function()
                if not chestLocker then return end
                local root = getRoot()
                if root then
                    -- คำนวณองศาการหมุนแบบพายุ (360 องศา)
                    local elapsed = os.clock() - startSpinTime
                    local spinX = elapsed * math.rad(360) * 3.0 -- ตีลังกา 3 รอบต่อseconds
                    local spinY = elapsed * math.rad(360) * 4.0 -- ควงสว่าน 4 รอบต่อseconds
                    
                    -- ลอยตัวเหนือหีบ 8 เมตร แล้วหมุนทุกทิศทาง
                    local rotCF = CFrame.new(chestPos + Vector3.new(0, 8, 0)) * CFrame.Angles(spinX, spinY, 0)
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    root.CFrame = rotCF
                end
            end)
            
            local t = os.clock()
            while _G[flagKey] and nearest.Parent do
                local hp = hrp:FindFirstChild("Health")
                local dead = hrp:FindFirstChild("Dead")
                if (dead and dead.Value == true) or (hp and hp.Value <= 0) then break end
                
                -- ระบบป้องกันหีบบัค: ถ้าติดเกิน 5 วิ ข้ามและจำ node
                if os.clock() - t > 5 then 
                    markChestNodeDone(nearest, "bug_stuck", true)
                    pcall(function() nearest:Destroy() end)
                    warn("⚠️ [Chest Finder] ข้ามหีบบัค node — จำไม่หาใหม่")
                    break 
                end
                
                -- 💥 จำลองคลิค (Mobile = Touch Tap, PC = Mouse Click)
                -- mobile executor (Delta/Fluxus) จะแปลงเป็น Touch ให้อัตโนมัติ
                pcall(function()
                    mouse1press()
                    task.wait(0.1)
                    mouse1release()
                end)
                task.wait(0.15)
            end
            
            -- หยุดหมุน 360 องศาเมื่อหีบพังเสร็จแล้ว
            chestLocker = false
            if spinConn then spinConn:Disconnect() spinConn = nil end
            if breathR then breathR:FireServer(false) end

            -- เปิดหีบเก็บของ (จำ node เฉพาะเมื่อเก็บสำเร็จจริง)
            local nodeID = tonumber(nearest.Parent and nearest.Parent.Name) or getChestNodeId(nearest)
            local chestCollected = false
            if nodeID then
                pcall(function()
                    local OpenR = LP:WaitForChild("Remotes"):FindFirstChild("OpenChestRemote")
                    local TDropR = ReplicatedStorage.Remotes:FindFirstChild("TreasureChestDropsRemote")
                    if OpenR and TDropR then
                        local items = nil
                        local conn = TDropR.OnClientEvent:Connect(function(_, i) if typeof(i) == "table" then items = i end end)
                        OpenR:InvokeServer(nodeID, false)
                        local s = tick()
                        while not items and tick() - s < 2 do task.wait(0.05) end
                        conn:Disconnect()
                        local dataRef = nil
                        for _, folderName in ipairs({"TreasureChests", "EventTreasureChests"}) do
                            if dataRef then break end
                            local mainFolder = LP.Data:FindFirstChild(folderName)
                            if mainFolder then
                                for _, mapFolder in pairs(mainFolder:GetChildren()) do
                                    local ref = mapFolder:FindFirstChild(tostring(nodeID))
                                    if ref then dataRef = ref break end
                                end
                            end
                        end
                        if dataRef then
                            if items then
                                for idx, _ in pairs(items) do TDropR:FireServer(dataRef, idx) task.wait(0.05) end
                            else
                                for idx = 1, 4 do TDropR:FireServer(dataRef, idx) task.wait(0.05) end
                            end
                            chestCollected = true
                        end
                    end
                end)
                if chestCollected then
                    markChestNodeDone(nearest, "claimed", true)
                end
            end
            found = found + 1
            showCenterWarning(false)
            if smartSkip then
                return found -- เปิดทีละใบ แล้วกลับให้ Smart Loop ทำเควสอื่น
            end
        task.wait(0.3)
    end
    return found
end

-- ============================================================
-- [[ 🎮 UI ]]
-- รันมือ → เปิดหน้าต่าง | วาร์ปอัตโนมัติ → ซ่อนหน้าต่าง เหลือแค่ปุ่มลอย
-- ============================================================
local pendingAutoResume = isTeleportReload
if pendingAutoResume then
    consumeAutoResume()
else
    clearAllPersistFiles()
end
waitUntilPlayerAndDragonInWorld()

Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/armkkk123/ui-/refs/heads/main/Library.obfuscated.lua"))()
local Window = Library:CreateWindow({
    Title = "RUAJAD HUB",
})
if pendingAutoResume then
    minimizeHubToFloatBtn()
end

local MainTab = Window:CreateTab("Quest")
_G.AutoQuestOrigins = false
_G.AutoQuestGrassland = false
_G.AutoQuestJungle = false
_G.AutoQuestVolcano = false
_G.AutoQuestTundra = false
_G.AutoQuestOcean = false
_G.AutoQuestDesert = false
_G.AutoQuestFantasy = false
_G.AutoQuestShinrin = false
_G.AutoQuestPrehistoric = false
_G.AutoQuestWasteland = false

-- [[ 🎮 BOSS QUEUE AUTOMATION ]]
local vim = game:GetService("VirtualInputManager")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HitRemote = Remotes:FindFirstChild("ClientDestructibleHitRemote")

local function fastClick(obj)
    if not obj then return end
    pcall(function()
        if getconnections then
            for _, c in pairs(getconnections(obj.Activated)) do c:Fire() end
            for _, c in pairs(getconnections(obj.MouseButton1Click)) do c:Fire() end
        end
        local pos = obj.AbsolutePosition
        local size = obj.AbsoluteSize
        local center = pos + (size / 2)
        vim:SendMouseButtonEvent(center.X, center.Y + 36, 0, true, game, 0)
        task.wait(0.05)
        vim:SendMouseButtonEvent(center.X, center.Y + 36, 0, false, game, 0)
    end)
end

-- ปุ่มเกมนี้ handler อยู่ที่ UpperLabel (Start/Claim/Exit เหมือนกัน)
local function clickGuiFace(btn)
    if not btn then return end
    local face = btn:FindFirstChild("UpperLabel")
    if not (face and face:IsA("GuiButton")) then
        face = btn
    end
    fastClick(face)
end

-- [[ 🎁 AUTO CLAIM BOSS LOOT — PICK A REWARD ]]
local BOSS_LOOT_PREFERRED_SLOT = 2 -- 1=Emerald, 2=Sapphire, 3=Ruby

local function getBossLootFrame()
    local pg = LP:FindFirstChild("PlayerGui")
    local bossGui = pg and pg:FindFirstChild("BossGui")
    return bossGui and bossGui:FindFirstChild("LootFrame")
end

local function waitForBossLootFrame(maxWait)
    local deadline = os.clock() + (maxWait or 12)
    while os.clock() < deadline do
        local lootFrame = getBossLootFrame()
        if lootFrame and lootFrame.Visible then
            return lootFrame
        end
        task.wait(0.25)
    end
    return getBossLootFrame()
end

local function isBossLootFrameOpen()
    local lootFrame = getBossLootFrame()
    return lootFrame and lootFrame.Visible
end

local function clickBossLootExit()
    local lootFrame = getBossLootFrame()
    if not lootFrame then return false end
    local exitBtn = lootFrame:FindFirstChild("LeaveButton")
    if exitBtn and exitBtn:IsA("GuiObject") and exitBtn.Visible and exitBtn.AbsoluteSize.X > 2 then
        warn("🚪 [BossLoot] คลิก Exit @ " .. exitBtn:GetFullName())
        for _ = 1, 3 do
            clickGuiFace(exitBtn)
            task.wait(0.45)
            if not isBossLootFrameOpen() then break end
        end
        return not isBossLootFrameOpen()
    end
    return false
end

_G.RuajadAutoClaimBossLoot = function()
    local preferredSlot = BOSS_LOOT_PREFERRED_SLOT
    warn("🎁 [BossLoot] รอหน้า PICK A REWARD...")
    local lootFrame = waitForBossLootFrame(12)

    if lootFrame and lootFrame.Visible then
        warn("🎁 [BossLoot] LootFrame เปิดแล้ว — slot " .. tostring(preferredSlot)
            .. " (1=Emerald, 2=Sapphire, 3=Ruby)")

        -- Claim เทาจนกว่าจะเลือกหีบก่อน
        local chestsFrame = lootFrame:FindFirstChild("ChestsFrame")
        local chestBtn = chestsFrame and chestsFrame:FindFirstChild(tostring(preferredSlot))
        if not (chestBtn and chestBtn:IsA("ImageButton") and chestBtn.Visible) then
            for _, child in ipairs(chestsFrame and chestsFrame:GetChildren() or {}) do
                if child:IsA("ImageButton") and child.Visible and child.AbsoluteSize.X > 2 then
                    chestBtn = child
                    preferredSlot = tonumber(child.Name) or preferredSlot
                    break
                end
            end
        end
        if chestBtn then
            warn("🎁 [BossLoot] เลือก chest @ " .. chestBtn:GetFullName())
            clickGuiFace(chestBtn)
            local chestLabel = chestBtn:FindFirstChild("ChestLabel")
            if chestLabel then fastClick(chestLabel) end
            task.wait(0.6)
        end

        local mainClaim = lootFrame:FindFirstChild("ClaimButton")
        if mainClaim and mainClaim.Visible then
            warn("🎁 [BossLoot] คลิก Claim @ " .. mainClaim:GetFullName())
            clickGuiFace(mainClaim)
            task.wait(0.8)
        end
    end

    if isBossLootFrameOpen() then
        local getLootR = Remotes:FindFirstChild("GetBossLootRemote")
        if getLootR then
            pcall(function()
                getLootR:InvokeServer(preferredSlot)
                warn("🎁 [BossLoot] GetBossLootRemote(" .. tostring(preferredSlot) .. ")")
            end)
            task.wait(0.5)
        end
        if isBossLootFrameOpen() then
            local lootFrame2 = getBossLootFrame()
            local claim2 = lootFrame2 and lootFrame2:FindFirstChild("ClaimButton")
            if claim2 and claim2.Visible then
                warn("🎁 [BossLoot] retry Claim")
                clickGuiFace(claim2)
                task.wait(0.5)
            end
        end
    end

    if not isBossLootFrameOpen() then
        warn("✅ [BossLoot] รับรางวัลเสร็จ")
    end

    -- หลัง Claim ต้องกด Exit ทุกครั้งเพื่อออก
    task.wait(0.4)
    clickBossLootExit()

    if not isBossLootFrameOpen() then
        warn("✅ [BossLoot] ออกจากหน้า Loot แล้ว")
    else
        warn("⚠️ [BossLoot] หน้า Loot ยังเปิด — ลอง remote Leave")
        local leaveR = Remotes:FindFirstChild("LeaveBossInstanceRemote")
        if leaveR then
            pcall(function()
                leaveR:InvokeServer()
                warn("🎁 [BossLoot] LeaveBossInstanceRemote()")
            end)
        end
        task.wait(0.5)
        if isBossLootFrameOpen() then
            clickBossLootExit()
        end
    end

    unlockPlayerFromMonster()
    unlockPlayer()
    setPhysics(false)
    warn("🎁 [BossLoot] cleanup — unlock player / physics off")
end

-- ถ้าหน้า PICK A REWARD เปิดอยู่ ให้รับของเลย ไม่รอ remote (remote อาจยิงหลัง flag ไฟต์ถูกเคลียร์)
task.spawn(function()
    while true do
        task.wait(0.5)
        if _G.RuajadBossRestartBusy then
            continue
        end
        if isBossLootFrameOpen() then
            _G.RuajadBossRestartBusy = true
            warn("🎁 [BossLoot] เจอหน้า PICK A REWARD — รับของอัตโนมัติ")
            pcall(function()
                if _G.RuajadAutoClaimBossLoot then
                    _G.RuajadAutoClaimBossLoot()
                end
            end)
            _G.RuajadBossRestartBusy = false
        end
    end
end)

-- [[ 🌋 พิกัดบอสแต่ละโลก ]]
local BOSS_QUEUE_COORDS = {
    Default  = CFrame.new(-634.14, 165.47, 743.25, -0.866, 0.108, 0.488, 0.014, 0.981, -0.192, -0.500, -0.159, -0.851),
    Jungle   = CFrame.new(-634.14, 165.47, 743.25, -0.866, 0.108, 0.488, 0.014, 0.981, -0.192, -0.500, -0.159, -0.851),
    Volcano  = CFrame.new(-1318.37, 178.56, -605.27, 1.000, 0.006, 0.010, -0.004, 0.984, -0.180, -0.011, 0.180, 0.984),
    Tundra   = CFrame.new(1461.48, 1629.44, 209.71, -0.493, -0.154, -0.856, -0.014, 0.985, -0.169, 0.870, -0.072, -0.488),
    Ocean    = CFrame.new(-240.35, -56.83, 1765.83, 0.665, 0.055, -0.745, -0.042, 0.998, 0.036, 0.746, 0.008, 0.666),
    Desert   = CFrame.new(2822.57, 1003.45, 1402.59, -0.305, -0.143, -0.942, -0.030, 0.990, -0.141, 0.952, -0.014, -0.306),
    Fantasy  = CFrame.new(-1242.81, 271.30, -551.95, 0.605, 0.134, 0.785, 0.012, 0.984, -0.178, -0.796, 0.117, 0.594),
    Wasteland = CFrame.new(-684.70, 226.54, -1229.74),
    Prehistoric = CFrame.new(-514.82, 750.51, -704.42, -0.488, 0.097, 0.867, -0.094, 0.982, -0.163, -0.868, -0.161, -0.471),
}

local currentBossWorld = "Default" -- จะถูกเซ็ตตอนเรียก killBoss จาก SmartLoop

local function isBossArenaActive()
    local bossInstances = workspace:FindFirstChild("Interactions")
        and workspace.Interactions:FindFirstChild("Boss")
        and workspace.Interactions.Boss:FindFirstChild("BossInstances")
    if not bossInstances then return false end
    local myNameStr = LP.Name
    for _, folder in pairs(bossInstances:GetChildren()) do
        if folder.Name:find(myNameStr) then return true end
    end
    return false
end

local function joinBossQueue(flagKey)
    local targetCF = BOSS_QUEUE_COORDS[currentBossWorld] or BOSS_QUEUE_COORDS.Default
    warn("🚀 [BossQueue] กำลังบินไปจุดรวมพล (" .. currentBossWorld .. ") พิกัด: " .. tostring(targetCF.Position))
    flyTo(targetCF)
    lockPlayerToMonster(targetCF, 0) -- ล็อคความสูงที่ 0 เมตร (แนบพื้น) เพื่อให้ GUI เด้ง
    task.wait(0.8)

    warn("⏳ [BossQueue] รอหน้า Boss Queue...")
    local queueFrame = nil
    local waitDeadline = os.clock() + 5
    local lastQueueLog = os.clock()
    while os.clock() < waitDeadline do
        local pg = LP:FindFirstChild("PlayerGui")
        local bossGui = pg and pg:FindFirstChild("BossGui")
        local qf = bossGui and bossGui:FindFirstChild("QueueFrame")
        if qf and qf.Visible then
            queueFrame = qf
            warn("✅ [BossQueue] หน้า Boss Queue พร้อม")
            break
        end
        if os.clock() - lastQueueLog >= 1.2 then
            warn("⏳ [BossQueue] รอหน้า Boss Queue...")
            lastQueueLog = os.clock()
        end
        task.wait(0.15)
    end
    if not queueFrame then
        warn("⚠️ [BossQueue] ไม่พบป้ายคิวบอส!")
        releaseTravelLock()
        return false
    end

    local function waitArenaEnter(maxWait)
        local deadline = os.clock() + (maxWait or 4)
        local lastLog = os.clock()
        warn("⏳ [BossQueue] รอเกมพาเข้าห้องบอส...")
        while os.clock() < deadline and (not flagKey or _G[flagKey]) do
            if isBossArenaActive() then return true end
            if os.clock() - lastLog >= 1.2 then
                warn("⏳ [BossQueue] กำลังเข้าห้องบอส...")
                lastLog = os.clock()
            end
            task.wait(0.2)
        end
        return isBossArenaActive()
    end

    local function clickQueueButton(btn, label)
        if not btn or not btn.Visible or btn.AbsoluteSize.X < 2 then return end
        warn("🖱️ [BossQueue] " .. label .. " @ " .. btn:GetFullName())
        clickGuiFace(btn)
    end

    local function getReadyStartButton()
        local currentFrame = queueFrame:FindFirstChild("CurrentFrame")
        if not (currentFrame and currentFrame.Visible) then return nil end
        local prompt = currentFrame:FindFirstChild("PromptLabel")
        if prompt and prompt.Visible then
            local text = string.lower(prompt.Text or "")
            if not text:find("ready", 1, true) then
                return nil
            end
        end
        local buttons = currentFrame:FindFirstChild("ButtonsFrame")
        local startBtn = buttons and buttons:FindFirstChild("Start")
        if startBtn and startBtn.Visible and startBtn.AbsoluteSize.X > 2 then
            return startBtn
        end
        return nil
    end

    local function tryClickReadyStart()
        local startBtn = getReadyStartButton()
        if not startBtn then return false end
        clickQueueButton(startBtn, "คลิก Start (3/3)")
        releaseTravelLock()
        if waitArenaEnter(4) then
            warn("✅ [BossQueue] เข้าอารีน่าสำเร็จ")
            return true
        end
        -- retry ครั้งเดียวถ้ายัง Ready อยู่
        startBtn = getReadyStartButton()
        if startBtn then
            warn("🖱️ [BossQueue] retry Start")
            clickQueueButton(startBtn, "คลิก Start retry")
            releaseTravelLock()
            if waitArenaEnter(3) then
                warn("✅ [BossQueue] เข้าอารีน่าสำเร็จ (retry)")
                return true
            end
        end
        return false
    end

    local function performClicks()
        if isBossArenaActive() then
            warn("✅ [BossQueue] อยู่ในอารีน่าแล้ว")
            return true
        end

        if tryClickReadyStart() then
            return true
        end

        local activeFrame = queueFrame:FindFirstChild("ActiveFrame")
        local createBtn1 = activeFrame and activeFrame.Visible
            and activeFrame:FindFirstChild("CreateFrame")
            and activeFrame.CreateFrame:FindFirstChild("CreateButton")
        if createBtn1 and createBtn1.Visible then
            clickQueueButton(createBtn1, "คลิก Create (1/3)")
            task.wait(1)
        end

        local createFrame = queueFrame:FindFirstChild("CreateFrame")
        if createFrame and createFrame.Visible then
            local createBtn2 = createFrame:FindFirstChild("CreateButton")
            if createBtn2 and createBtn2.Visible then
                clickQueueButton(createBtn2, "คลิก Create (2/3)")
                task.wait(1)
            end
        end

        warn("⏳ [BossQueue] รอปุ่ม Start...")
        local deadline = os.clock() + 7
        local lastStartLog = os.clock()
        while os.clock() < deadline and (not flagKey or _G[flagKey]) do
            if isBossArenaActive() then
                warn("✅ [BossQueue] เข้าอารีน่าสำเร็จ")
                return true
            end
            if tryClickReadyStart() then
                return true
            end
            if os.clock() - lastStartLog >= 1.2 then
                warn("⏳ [BossQueue] รอปุ่ม Start...")
                lastStartLog = os.clock()
            end
            task.wait(0.25)
        end
        return isBossArenaActive()
    end

    for attempt = 1, 2 do
        if performClicks() then
            releaseTravelLock()
            return true
        end
        if attempt < 2 and (not flagKey or _G[flagKey]) then
            warn("⚠️ [BossQueue] ไม่เข้าอารีน่า — ลองอีกรอบ (" .. attempt .. "/2)")
            releaseTravelLock()
            task.wait(1)
            flyTo(targetCF)
            lockPlayerToMonster(targetCF, 0)
            task.wait(1)
        end
    end
    warn("⚠️ [BossQueue] Timeout — ไม่เข้าอารีน่า")
    releaseTravelLock()
    return false
end

local function waitWhileFlag(flagKey, seconds, label)
    local deadline = os.clock() + (seconds or 1)
    local lastLog = os.clock()
    while os.clock() < deadline and _G[flagKey] do
        if label and (seconds or 1) >= 2 and os.clock() - lastLog >= 1.2 then
            warn("⏳ " .. label)
            lastLog = os.clock()
        end
        task.wait(0.1)
    end
end

local function killBoss(amount, flagKey)
    -- ปรับจูนแบบ conservative: ลดความถี่สแกน/ยิงเพื่อลดกระตุก แต่ยังคง flow เดิม
    local SEARCH_WAIT = 0.25
    local COMBAT_TICK = 0.45
    local MINION_SCAN_INTERVAL = 0.35
    local ENABLE_MINION_INTERRUPT = true
    local MINION_ENABLE_AFTER_BOSS_SECONDS = 15
    local MINION_DETECT_RADIUS = 250

    local killed = 0
    while killed < amount and _G[flagKey] do
        local myNameStr = LP.Name
        local bossInstances = workspace:FindFirstChild("Interactions") 
            and workspace.Interactions:FindFirstChild("Boss")
            and workspace.Interactions.Boss:FindFirstChild("BossInstances")
        local myArenaFolder = nil
        if bossInstances then
            for _, folder in pairs(bossInstances:GetChildren()) do
                if folder.Name:find(myNameStr) then myArenaFolder = folder break end
            end
        end
        if not myArenaFolder then
            warn("📢 [BossKiller] เริ่มขั้นตอนกดเข้าคิว...")
            local success = joinBossQueue(flagKey)
            releaseTravelLock()
            if success then
                waitWhileFlag(flagKey, 2, "[BossKiller] รอบอสโผล่...")
            else
                waitWhileFlag(flagKey, 1)
            end
            continue
        end
        releaseTravelLock()
        warn("🏟️ [BossKiller] บอสกำลังแสกนหาบอส: " .. myNameStr)
        local targetBoss = nil
        local scanStartTime = os.clock()
        while _G[flagKey] and myArenaFolder and myArenaFolder.Parent ~= nil and not targetBoss and (os.clock() - scanStartTime < 60) do
            local activeBosses = workspace:FindFirstChild("ActiveBossModels")
            if activeBosses then
                for _, boss in pairs(activeBosses:GetChildren()) do
                    if boss:IsA("Model") and boss.Name:find(myNameStr) then targetBoss = boss break end
                end
            end
            if not targetBoss then
                task.wait(SEARCH_WAIT)
            end
        end
        if targetBoss then
            warn("🎯 [BossKiller] ล็อคเป้าสำเร็จ!")
            _G.RuajadInOwnBossFight = true
            local dragon = getActiveDragonModel()
            if dragon and dragon:FindFirstChild("Remotes") then
                local breathR = dragon.Remotes:FindFirstChild("BreathFireRemote")
                local soundR = dragon.Remotes:FindFirstChild("PlaySoundRemote")
                if breathR then breathR:FireServer(true) end
                local targetPart = targetBoss:FindFirstChild("HumanoidRootPart") or targetBoss:FindFirstChild("HitboxPart") or targetBoss:FindFirstChildWhichIsA("BasePart")
                local lastMinionScan = 0
                local bossFightStart = os.clock()
                local hitPulse = 0
                local breathPulse = 0
                local currentLockTarget = nil
                local currentLockHeight = nil
                local function setCombatLock(nextTarget, nextHeight)
                    if not nextTarget then return end
                    if currentLockTarget ~= nextTarget or currentLockHeight ~= nextHeight then
                        lockPlayerToMonster(nextTarget, nextHeight)
                        currentLockTarget = nextTarget
                        currentLockHeight = nextHeight
                    end
                end
                while _G[flagKey] and myArenaFolder and myArenaFolder.Parent ~= nil and isTargetAlive(targetBoss) and targetPart do
                    -- ล็อคค้าง ไม่ reconnect ซ้ำทุกรอบลูป (ลดอาการกระตุกเป็นจังหวะ)
                    setCombatLock(targetPart, 30)

                    -- [[ 🛡️ ระบบสแกนหาลูกน้องแบบ throttle เพื่อลดภาระ CPU ]]
                    local minion = nil
                    local now = os.clock()
                    local minionInterruptActive = ENABLE_MINION_INTERRUPT and ((now - bossFightStart) >= MINION_ENABLE_AFTER_BOSS_SECONDS)
                    if minionInterruptActive then
                        if (now - lastMinionScan) >= MINION_SCAN_INTERVAL then
                            minion = findNearestPortalMinion(MINION_DETECT_RADIUS)
                            lastMinionScan = now
                        end
                    end
                    if minion then
                        -- [[ 🔗 CHAIN MODE: วาร์ปจากมอนไปมอนจนหมด แล้วค่อยsystemบอส ]]
                        warn("🛡️ [BossKiller] พบลูกน้อง! เข้าโหมดกวาดล้าง...")
                        while minion and _G[flagKey] and myArenaFolder and myArenaFolder.Parent ~= nil do
                            local mRoot = minion:FindFirstChild("HumanoidRootPart") or minion:FindFirstChildWhichIsA("BasePart")
                            if not mRoot then break end
                            
                            -- วาร์ปไปมอนตัวนี้ทันที
                            flyTo(mRoot.CFrame * CFrame.new(0, 12, 0))
                            setCombatLock(mRoot, 20)
                            
                            -- ตี 1.2 seconds
                            local minionStart = os.clock()
                            while _G[flagKey] and (os.clock() - minionStart < 1.2) do
                                local currentMRoot = minion:FindFirstChild("HumanoidRootPart") or minion:FindFirstChildWhichIsA("BasePart")
                                if not currentMRoot then break end
                                
                                refillDragonBreathFuel(dragon)
                                hitPulse = (hitPulse + 1) % 2
                                breathPulse = (breathPulse + 1) % 3
                                if breathR and breathPulse == 0 then breathR:FireServer(true) end
                                if soundR then
                                    soundR:FireServer("Breath", "Mobs", currentMRoot)
                                    if HitRemote and hitPulse == 0 then HitRemote:FireServer(currentMRoot) end
                                end
                                task.wait(0.2)
                            end
                            
                            -- สแกนหามอนตัวถัดไปทันที (ไม่systemบอส)
                            minion = findNearestPortalMinion(MINION_DETECT_RADIUS)
                        end
                        
                        -- หมดมอนแล้ว systemมาล็อคบอส
                        warn("✅ [BossKiller] กวาดลูกน้องหมด! systemตีบอส...")
                        if targetPart and targetPart.Parent then
                            setCombatLock(targetPart, 30)
                        end
                    else
                        refillDragonBreathFuel(dragon)
                        hitPulse = (hitPulse + 1) % 2
                        breathPulse = (breathPulse + 1) % 3
                        if breathR and breathPulse == 0 then breathR:FireServer(true) end
                        if soundR then 
                            soundR:FireServer("Breath", "Bosses", targetPart)
                            -- [[ 👊 ดาเมจเสริมไม่สนมานา ]]
                            if HitRemote and hitPulse == 0 then HitRemote:FireServer(targetPart) end
                        end
                        task.wait(COMBAT_TICK)
                    end
                end
                unlockPlayer()
                if breathR then breathR:FireServer(false) end
            end
            killed = killed + 1
            unlockPlayerFromMonster()
            setPhysics(false)
            
        else
            killed = killed + 1
        end
        waitWhileFlag(flagKey, 1)
    end
    unlockPlayerFromMonster()
    setPhysics(false)
    if not isBossLootFrameOpen() then
        _G.RuajadInOwnBossFight = false
    end
end

-- ============================================================
-- [[ 🧠 UNIVERSAL SMART QUEST ENGINE v3 ]]
-- สมองกลางคุมทุกโลก: ปักหมุดอัตโนมัติ, จัดลำดับความสำคัญ, และล่าบอส
-- ============================================================

local function getPinnedQuests(worldName)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return {} end
    local hudGui = pg:FindFirstChild("HUDGui")
    local missionsFrame = hudGui and hudGui:FindFirstChild("MissionsFrame")
    if not missionsFrame then return {} end
    
    local pinned = {}
    for _, desc in ipairs(missionsFrame:GetDescendants()) do
        if desc:IsA("Frame") or desc:IsA("ImageButton") then
             for _, qName in ipairs({"EggQuest", "TreasureChest", "KillMobs", "Harvest", "KillBoss", "RidingRing", "SpendTime", "Boss"}) do
                 if desc.Name:find(qName) then
                    -- กรองโลก: เช็คว่าชื่อ Frame มีชื่อโลกกำกับ (เช่น EggQuestLobby, KillMobsOcean)
                    local belongsToWorld = (not worldName) or desc.Name:find(worldName)
                    
    -- ☢️ Wasteland/Toxic/Prehistoric/Shinrin Fallback: เฉพาะโลก Wasteland/Wastelands/Toxic/Prehistoric/Shinrin เท่านั้น
    -- ถ้าหาชื่อโลกในชื่อ Frame ไม่เจอ ให้รับ Frame ที่ไม่มีชื่อโลกอื่นปนอยู่
    if not belongsToWorld and (worldName == "Wasteland" or worldName == "Wastelands" or worldName == "Toxic" or worldName == "Prehistoric" or worldName == "Shinrin") then
        local otherWorlds = {"Lobby", "Origins", "Grassland", "Jungle", "Volcano", "Tundra", "Ocean", "Desert", "Fantasy"}
        local isOther = false
        for _, w in ipairs(otherWorlds) do if desc.Name:find(w) then isOther = true break end end
        if not isOther then belongsToWorld = true end
    end
                    
                    if belongsToWorld then
                        local key = (qName == "Boss") and "KillBoss" or qName
                        pinned[key] = true
                    end
                 end
             end
        end
    end
    return pinned
end

-- เควสที่ต้องทำให้หมดก่อน เวลาเป็นอันดับสุดท้ายเสมอ
local ACTION_QUESTS = {"KillBoss", "EggQuest", "TreasureChest", "KillMobs", "Harvest", "RidingRing"}

local function hasActionQuestPinned(pinned)
    if not pinned then return false end
    for _, q in ipairs(ACTION_QUESTS) do
        if pinned[q] then return true end
    end
    return false
end

local function tryPinNextActionQuest(worldName, skipPinned)
    for _, q in ipairs(ACTION_QUESTS) do
        if not (skipPinned and skipPinned[q]) then
            trackQuest(q, worldName)
            task.wait(1.5)
            local checkPinned = getPinnedQuests(worldName)
            if checkPinned[q] then
                return checkPinned, q
            end
        end
    end
    return nil, nil
end

local function runUniversalSmartLoop(displayName, internalName, flagKey)
    warn("======== 🚀 เริ่มระบบ Smart Loop: " .. displayName .. " ========")
    
    local heartbeatCount = 0
    local forceRetrack = false -- สัญญาณสั่งปักหมุดใหม่ถ้าทางตัน
    
    while _G[flagKey] do
        heartbeatCount = heartbeatCount + 1
        if heartbeatCount % 5 == 0 then warn("💓 [SmartLoop:" .. displayName .. "] กำลังตรวจสอบ HUD...") end
        
        local pinned = getPinnedQuests(internalName)
        -- SpendTime บน HUD ไม่นับว่ามีงานทำ — ต้องไล่ปักเควสอื่นให้หมดก่อน
        local hasActionPinned = hasActionQuestPinned(pinned)
        if pinned["SpendTime"] and not hasActionPinned then
            warn("🧪 [TEST] HUD มีแค่เควสเวลา — จะปักเควสอื่นก่อน (KillBoss → Egg → Chest → Mobs → Harvest → Ring)")
        end
        
        -- [[ 📌 1. ระบบปักหมุดอัตโนมัติ (Auto-Pinning) ]]
        -- เควสอื่นก่อนเสมอ: บอส > ไข่ > หีบ > มอน > เก็บเกี่ยว > ห่วง — เวลาเป็นอันดับสุดท้าย
        if not hasActionPinned or forceRetrack then
             local skipPinned = {}
             if forceRetrack then
                 for _, q in ipairs(ACTION_QUESTS) do
                     if pinned[q] then skipPinned[q] = true end
                 end
             end
             forceRetrack = false
             warn("📌 [AutoTrack] กำลังหยิบเควสอื่นใน " .. displayName .. " (เวลาเป็นอันดับสุดท้าย)")
             local newPinned, pinnedName = tryPinNextActionQuest(internalName, skipPinned)
             if newPinned then
                 hasActionPinned = true
                 pinned = newPinned
                 warn("📌 [AutoTrack] ปักหมุดสำเร็จ: " .. tostring(pinnedName))
             elseif not hasActionPinned then
                 local spendSt = getSpendTimeProgress(internalName)
                 if spendSt and not spendSt.done then
                     warn("⏱️ [SmartLoop] เควสอื่นปักไม่ได้แล้ว — รอเวลา 20s แล้วค่อยลองหยิบเควสอื่นอีก")
                     local spendDone = waitForSpendTimeMission(displayName, internalName, flagKey, 20)
                     if spendDone then
                         warn("✅ [SmartLoop] เคลียร์ทุกเควสใน " .. displayName .. " จบแล้ว!")
                         break
                     end
                     continue -- กลับไปปักเควสอื่น ห้ามค้างรอเวลาอย่างเดียว
                 else
                     warn("✅ [SmartLoop] เคลียร์ทุกเควสใน " .. displayName .. " จบแล้ว!")
                     break
                 end
             end
        end
        
        -- [[ ⚔️ 2. ระบบรันเควสตามหมุด (Execution) ]]
        local didWork = false
        
        -- 👹 บอส (Priority 1)
        if pinned["KillBoss"] and _G[flagKey] then
             local need = getQuestRemaining("KillBoss", internalName)
             if need > 0 then 
                 warn("👹 [" .. displayName .. "] พบบอส! เข้าจัดการ...")
                -- เซ็ตพิกัดบอส ตามโลกที่กำลังเล่น
                if internalName == "Volcano" then currentBossWorld = "Volcano"
                elseif internalName == "Tundra" then currentBossWorld = "Tundra"
                elseif internalName == "Ocean" then currentBossWorld = "Ocean"
                elseif internalName == "Desert" then currentBossWorld = "Desert"
                elseif internalName == "Fantasy" then currentBossWorld = "Fantasy"
                elseif internalName == "Wasteland" or internalName == "Toxic" then currentBossWorld = "Wasteland"
                elseif internalName == "Prehistoric" then currentBossWorld = "Prehistoric"
                elseif internalName == "Jungle" then currentBossWorld = "Jungle"
                else currentBossWorld = "Default" end
                
                warn("🚀 [BossQueue] ใช้พิกัดโลก: " .. currentBossWorld)
                killBoss(need, flagKey)
                 didWork = true 
             end
        end
        
        -- 🥚 เก็บไข่
        if pinned["EggQuest"] and _G[flagKey] and not didWork then
             local need = getQuestRemaining("EggQuest", internalName)
             if need > 0 then 
                 warn("🥚 [" .. displayName .. "] เก็บไข่อีก " .. need .. " ฟอง")
                 collectEggs(need, flagKey, internalName) 
                 didWork = true 
             end
        end
        
        -- 💍 ลอดห่วง (เฉพาะ Origins/Event)
        if pinned["RidingRing"] and _G[flagKey] and not didWork then
             local need = getQuestRemaining("RidingRing", internalName)
             if need > 0 then 
                 warn("💍 [" .. displayName .. "] ลอดห่วงอีก " .. need .. " ห่วง")
                 flyRings(need, flagKey) 
                 didWork = true 
             end
        end

        -- 📦 หีบสมบัติ (Smart Skip: ถ้าไม่เจอหีบจะข้ามไปเควสถัดไป)
        local chestSkipFallback = false
        if pinned["TreasureChest"] and _G[flagKey] and not didWork then
             local need = getQuestRemaining("TreasureChest", internalName)
             if need > 0 then 
                 warn("📦 [" .. displayName .. "] เปิดหีบอีก " .. need .. " ใบ")
                 local chestFound = findChests(need, flagKey, internalName, { smartSkip = true }) or 0
                 if chestFound > 0 then
                     didWork = true -- เจอหีบแล้วตี → ถือว่าทำงานแล้ว
                 else
                     warn("📦 [" .. displayName .. "] ไม่มีหีบ! ข้ามไปเควสถัดไป...")
                     chestSkipFallback = true -- 🧠 สัญญาณ: ลองทำเควสอื่นแม้ไม่ได้ปักหมุด
                 end
             end
        end
        
        -- ⚔️ ฆ่ามอน
        if (pinned["KillMobs"] or chestSkipFallback) and _G[flagKey] and not didWork then
             -- 🧠 ถ้ายังไม่ได้ปักหมุด ลองปักแล้วรอนานขึ้น
             if not pinned["KillMobs"] and chestSkipFallback then
                 trackQuest("KillMobs", internalName)
                 task.wait(1.5)
             end
             local need = getQuestRemaining("KillMobs", internalName)
             if need > 0 then 
                 warn("⚔️ [" .. displayName .. "] ฆ่ามอนอีก " .. need .. " ตัว")
                 killMobs(need, flagKey, internalName) 
                 didWork = true 
             end
        end
        
        -- 🍎 เก็บเกี่ยว
        if (pinned["Harvest"] or chestSkipFallback) and _G[flagKey] and not didWork then
             -- 🧠 ถ้ายังไม่ได้ปักหมุด ลองปักแล้วรอนานขึ้น
             if not pinned["Harvest"] and chestSkipFallback then
                 trackQuest("Harvest", internalName)
                 task.wait(1.5)
             end
             local need = getQuestRemaining("Harvest", internalName)
             if need > 0 then 
                 warn("🍎 [" .. displayName .. "] เก็บเกี่ยวอีก " .. need .. " อัน")
                 harvestResources(need, flagKey, internalName) 
                 didWork = true 
             end
        end
        
        -- ⏱️ เควสเวลา = อันดับสุดท้ายเท่านั้น ห้ามเข้าถ้ายังมีเควสอื่นปักอยู่
        if _G[flagKey] and not didWork and not hasActionPinned then
            local spendSt = getSpendTimeProgress(internalName)
            if spendSt and not spendSt.done then
                waitForSpendTimeMission(displayName, internalName, flagKey, 20)
                didWork = true
            end
        end
        
        if not didWork then 
            -- ถ้าพยายามรันทุกหมุดแล้วแต่ทำไม่ได้เลย (เช่น มอนไม่เกิด/ไข่ไม่มี) ให้สั่ง Re-track เควสอื่น
            if hasActionPinned then forceRetrack = true end
            task.wait(0.5) 
        end
        task.wait(0.2)
    end
    
    -- ก่อนออกจากโลก — รอ SpendTime อีกรอบเผื่อ HUD ว่างแต่เวลายังไม่ครบ
    if _G[flagKey] then
        waitForSpendTimeMission(displayName, internalName, flagKey)
    end
    
    warn("======== 🏁 จบ Smart Loop: " .. displayName .. " ========")
    if not _G.AutoQuestChainPaused then
        _G[flagKey] = false
    end
    setPhysics(false)
end

local QUEST_RUNNERS = {}

_G.RuajadRestartQuestsAfterBoss = function(activeBefore, chainWasOn)
    warn("♻️ [System] รอโลกนิ่งหลัง Exit แล้วเปิดระบบใหม่...")
    task.wait(3)

    unlockPlayerFromMonster()
    unlockPlayer()
    setPhysics(false)
    _G.AutoQuestChainPaused = false
    _G.AutoQuestChainWorld = false
    _G.RuajadInOwnBossFight = false

    -- ปิดก่อน แล้วเปิดใหม่ (อย่าปิดกลางไฟต์ — ฟังก์ชันนี้เรียกหลัง Exit เท่านั้น)
    for _, data in ipairs(activeBefore) do
        pcall(function() setToggleValue(data.t, false) end)
        _G[data.f] = false
    end
    if chainWasOn then
        pcall(function()
            if AdvanceChainToggleObj then setToggleValue(AdvanceChainToggleObj, false) end
        end)
        _G.AutoQuestChain = false
        _G.AutoQuestChainWorld = false
    end

    task.wait(1.5)

    for _, data in ipairs(activeBefore) do
        warn("♻️ [System] Restart " .. data.n)
        pcall(function() setToggleValue(data.t, true) end)
    end
    if chainWasOn then
        warn("♻️ [System] Restart Advance Chain")
        pcall(function()
            if AdvanceChainToggleObj then
                setToggleValue(AdvanceChainToggleObj, true)
            elseif type(_G.runAdvanceQuestChain) == "function" then
                _G.AutoQuestChain = true
                task.spawn(_G.runAdvanceQuestChain)
            end
        end)
    end
end

local function runOriginsQuest()
    runUniversalSmartLoop("Origins", "Lobby", "AutoQuestOrigins")
end
QUEST_RUNNERS.Origins = runOriginsQuest

local function runGrasslandQuest()
    runUniversalSmartLoop("Grassland", "Grassland", "AutoQuestGrassland")
end
QUEST_RUNNERS.Grassland = runGrasslandQuest

local function runJungleQuest()
    runUniversalSmartLoop("Jungle", "Jungle", "AutoQuestJungle")
end
QUEST_RUNNERS.Jungle = runJungleQuest

local function runVolcanoQuest()
    runUniversalSmartLoop("Volcano", "Volcano", "AutoQuestVolcano")
end
QUEST_RUNNERS.Volcano = runVolcanoQuest

local function runTundraQuest()
    runUniversalSmartLoop("Tundra", "Tundra", "AutoQuestTundra")
end
QUEST_RUNNERS.Tundra = runTundraQuest

local function runOceanQuest()
    runUniversalSmartLoop("Ocean", "Ocean", "AutoQuestOcean")
end
QUEST_RUNNERS.Ocean = runOceanQuest

local function runDesertQuest()
    runUniversalSmartLoop("Desert", "Desert", "AutoQuestDesert")
end
QUEST_RUNNERS.Desert = runDesertQuest

local function runFantasyQuest()
    runUniversalSmartLoop("Fantasy", "Fantasy", "AutoQuestFantasy")
end
QUEST_RUNNERS.Fantasy = runFantasyQuest

local function runShinrinQuest()
    runUniversalSmartLoop("Shinrin", "Shinrin", "AutoQuestShinrin")
end
QUEST_RUNNERS.Shinrin = runShinrinQuest

local function runPrehistoricQuest()
    -- 🛡️ Prehistoric Special: รอโหลด HUD ให้ครบ 6 ตัวก่อนเริ่มทำงาน เพื่อป้องกันปัญหาปักหมุดไม่ได้
    warn("⏳ [Prehistoric] กำลังรอโหลด HUD Missions...")
    task.wait(3)
    runUniversalSmartLoop("Prehistoric", "Prehistoric", "AutoQuestPrehistoric")
end
QUEST_RUNNERS.Prehistoric = runPrehistoricQuest

local function runWastelandQuest()
    -- ใช้ "Toxic" ตามที่สแกนได้จาก Remote Log ของผู้ใช้ (อัปเดตล่าสุด)
    runUniversalSmartLoop("Wasteland", "Toxic", "AutoQuestWasteland")
end
QUEST_RUNNERS.Wasteland = runWastelandQuest

-- ============================================================
-- [[ 🚀 ADVANCE QUEST CHAIN: Origin → Shinrin (1 toggle) ]]
-- สแกนล็อคโลก → ทำเควสโลกปัจจุบันจนจบ → ตรวจปลดโลกถัดไป → วาร์ปต่อ
-- ============================================================
do
    local CHAIN = {
        { display = "Origins",     internal = "Lobby",       placeId = 3475397644 },
        { display = "Grassland",   internal = "Grassland",   placeId = 3475419198 },
        { display = "Jungle",      internal = "Jungle",      placeId = 3475422608 },
        { display = "Volcano",     internal = "Volcano",     placeId = 3487210751 },
        { display = "Tundra",      internal = "Tundra",      placeId = 3623549100 },
        { display = "Ocean",       internal = "Ocean",       placeId = 3737848045 },
        { display = "Desert",      internal = "Desert",      placeId = 3752680052 },
        { display = "Fantasy",     internal = "Fantasy",     placeId = 4174118306 },
        { display = "Wasteland",   internal = "Toxic",       placeId = 4728805070 },
        { display = "Prehistoric", internal = "Prehistoric", placeId = 4869039553 },
        { display = "Shinrin",     internal = "Shinrin",     placeId = 125804922932357 },
    }

    _G.AutoQuestChain = false
    _G.AutoQuestChainWorld = false
    _G.AutoQuestChainPaused = false

    local function chainLog(msg)
        warn("🔗 [AdvanceChain] " .. tostring(msg))
    end

    local function notifyChain(title, content)
        pcall(function()
            hubNotify(title, content, 4)
        end)
    end

    local function isWorldUnlocked(worldKey)
        if worldKey == "Lobby" then
            return true
        end
        local data = LP:FindFirstChild("Data")
        local worlds = data and data:FindFirstChild("Worlds")
        if not worlds then
            return false
        end
        local node = worlds:FindFirstChild(worldKey)
        if not node then
            return false
        end
        if node:IsA("BoolValue") then
            return node.Value == true
        end
        if node:IsA("Folder") then
            local u = node:FindFirstChild("UnlockedOutOfLobby")
            if u and u:IsA("BoolValue") then
                return u.Value == true
            end
            local entered = node:FindFirstChild("Entered")
            if entered and entered:IsA("BoolValue") then
                return entered.Value == true
            end
        end
        return false
    end

    local function scanAllWorlds()
        local lines = {}
        for _, w in ipairs(CHAIN) do
            local unlocked = isWorldUnlocked(w.internal)
            table.insert(lines, (unlocked and "✅ " or "🔒 ") .. w.display)
            chainLog(w.display .. " = " .. (unlocked and "UNLOCKED" or "LOCKED"))
        end
        notifyChain("World Scan", table.concat(lines, "  |  "))
        return lines
    end

    local function waitForHud(timeoutSec)
        local deadline = os.clock() + (timeoutSec or 20)
        while os.clock() < deadline and _G.AutoQuestChain do
            local pg = LP:FindFirstChild("PlayerGui")
            local hud = pg and pg:FindFirstChild("HUDGui")
            if hud and hud:FindFirstChild("MissionsFrame") then
                return true
            end
            task.wait(0.3)
        end
        return false
    end

    local function warpToWorld(world)
        if game.PlaceId == world.placeId then
            return true
        end
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local tp = remotes and remotes:FindFirstChild("WorldTeleportRemote")
        if not tp then
            chainLog("ไม่พบ WorldTeleportRemote")
            return false
        end
        chainLog("วาร์ปไป " .. world.display .. " (" .. tostring(world.placeId) .. ")")
        notifyChain("Advance Chain", "Warping to " .. world.display .. "...")

        local completed, response
        task.spawn(function()
            pcall(function()
                response = tp:InvokeServer(world.placeId, {})
            end)
            completed = true
        end)

        local start = os.clock()
        while os.clock() - start < 1.2 and not completed do
            task.wait(0.05)
        end

        if completed and response == false then
            chainLog(world.display .. " ล็อค (remote=false)")
            notifyChain("Locked", world.display .. " is still locked.")
            return false
        end

        local untilT = nil
        while _G.AutoQuestChain do
            if game.PlaceId == world.placeId then
                chainLog("วาร์ปถึง " .. world.display .. " แล้ว — รอตัวละคร+มังกร")
                waitUntilPlayerAndDragonInWorld()
                return true
            end
            task.wait(0.25)
        end
        return game.PlaceId == world.placeId
    end

    local function waitUntilUnlocked(world, maxWait)
        local deadline = os.clock() + (maxWait or 45)
        while _G.AutoQuestChain and os.clock() < deadline do
            if isWorldUnlocked(world.internal) then
                return true
            end
            chainLog("รอปลดล็อค " .. world.display .. "...")
            task.wait(2)
        end
        return isWorldUnlocked(world.internal)
    end

    -- โลกที่ปลดไกลสุดในสาย (Grassland ปลดแล้ว = ข้าม Origins ไม่ย้อนทำใหม่)
    local function findStartIndex()
        local startIdx = 1
        for i, w in ipairs(CHAIN) do
            if isWorldUnlocked(w.internal) then
                startIdx = i
            else
                break
            end
        end
        return startIdx
    end

    local function runAdvanceQuestChain()
        chainLog("Chain ON — เริ่มทำงาน")
        setChainPersist(true)
        queueAutoQuestOnTeleport()
        waitUntilPlayerAndDragonInWorld()
        chainLog("เริ่มสแกนโลกทั้งหมด")
        scanAllWorlds()

        local idx = findStartIndex()
        local startWorld = CHAIN[idx]
        chainLog("เริ่มจากโลกที่ปลดได้ไกลสุด: " .. startWorld.display .. " (ข้ามโลกก่อนหน้า)")
        notifyChain("Advance Chain", "Resume at " .. startWorld.display .. " (skip completed worlds)")

        while _G.AutoQuestChain and idx <= #CHAIN do
            local world = CHAIN[idx]

            if not isWorldUnlocked(world.internal) then
                chainLog(world.display .. " ยังล็อค — รอปลดจากเควสโลกก่อนหน้า")
                notifyChain("Advance Chain", "Waiting to unlock " .. world.display)
                if not waitUntilUnlocked(world, 60) then
                    chainLog("ยังปลด " .. world.display .. " ไม่ได้ — หยุด chain")
                    notifyChain("Advance Chain", "Stopped: " .. world.display .. " still locked.")
                    break
                end
            end

            if game.PlaceId ~= world.placeId then
                queueAutoQuestOnTeleport()
                local okWarp = warpToWorld(world)
                if not okWarp then
                    if not waitUntilUnlocked(world, 20) then
                        break
                    end
                    if not warpToWorld(world) then
                        break
                    end
                end
            else
                waitUntilPlayerAndDragonInWorld()
            end

            if world.internal == "Prehistoric" then
                chainLog("รอ HUD Prehistoric")
                task.wait(3)
            end

            if not _G.AutoQuestChain then
                break
            end

            chainLog("ทำเควสโลก " .. world.display)
            notifyChain("Advance Chain", "Questing: " .. world.display)

            _G.AutoQuestChainWorld = true
            runUniversalSmartLoop(world.display, world.internal, "AutoQuestChainWorld")

            if not _G.AutoQuestChain then
                break
            end

            if _G.AutoQuestChainPaused then
                chainLog("พักหลังบอส — รอ restart")
                break
            end

            chainLog("จบ " .. world.display .. " — สแกนโลกถัดไป")
            task.wait(1.5)
            scanAllWorlds()
            idx = idx + 1
        end

        _G.AutoQuestChainWorld = false
        if _G.AutoQuestChain then
            chainLog("Chain ครบ Origin → Shinrin (หรือหยุดที่โลกที่ยังล็อค)")
            notifyChain("Advance Chain", "Finished Origin → Shinrin (or stopped at a locked world).")
            _G.AutoQuestChain = false
            setChainPersist(false)
        else
            chainLog("Chain ถูกปิด")
            setChainPersist(false)
        end
        setPhysics(false)
        _G.RuajadChainSpawned = false
    end

    _G.runAdvanceQuestChain = runAdvanceQuestChain
end

-- ============================================================
-- [[ 🔥 GLOBAL INFINITE BREATH (AUTO FARM CORE) ]]
-- เติมพ่นไฟอัตโนมัติทุกโหมดฟาร์ม (Origins/Grassland/Jungle)
-- ============================================================
local function isAnyAutoFarmEnabled()
    return _G.AutoQuestChain or _G.AutoQuestChainWorld
        or _G.AutoQuestOrigins or _G.AutoQuestGrassland or _G.AutoQuestJungle or _G.AutoQuestVolcano or _G.AutoQuestTundra or _G.AutoQuestOcean or _G.AutoQuestDesert or _G.AutoQuestFantasy or _G.AutoQuestShinrin or _G.AutoQuestPrehistoric or _G.AutoQuestWasteland
end

_G.AutoAntiHitWhileFarm = true

local function isAntiHitActive()
    return _G.GodMode or _G.GhostMode or (_G.AutoAntiHitWhileFarm and isAnyAutoFarmEnabled())
end

-- ============================================================
-- [[ 📷 HARD CAMERA LOCK FIX - แก้กล้องตก/สั่นตอนบิน Tween ]]
-- ============================================================
local cameraLockConnection = nil
local cameraHardLockEnabled = false

local function applyHardCameraLock()
    if cameraLockConnection then return end
    cameraHardLockEnabled = true
    
    -- ปิด AutoRotate ทั้งคนและมังกร
    pcall(function()
        local char = LP.Character
        local dragon = getActiveDragonModel()
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = false end
        end
        if dragon then
            local hum = dragon:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = false end
        end
    end)

    -- ล็อกกล้องทุกเฟรม Heartbeat (60 ครั้ง/seconds) ไม่มีช่องว่างเลย
    cameraLockConnection = RunService.Heartbeat:Connect(function()
        if not cameraHardLockEnabled then return end
        pcall(function()
            local cam = workspace.CurrentCamera
            local dragon = getActiveDragonModel()
            local char = LP.Character
            
            local targetHum = nil
            if dragon then targetHum = dragon:FindFirstChildOfClass("Humanoid") end
            if not targetHum and char then targetHum = char:FindFirstChildOfClass("Humanoid") end
            
            if targetHum then
                -- Force Lock ไม่สนเกมจะเปลี่ยนอะไร
                cam.CameraSubject = targetHum
                cam.CameraType = Enum.CameraType.Follow
                
                -- ป้องกันการสั่นระหว่าง Tween
                if cam.CFrame.p.Y < 10 then
                    cam.FieldOfView = 70
                end
            end
        end)
    end)
end

local function disableHardCameraLock()
    cameraHardLockEnabled = false
    if cameraLockConnection then
        cameraLockConnection:Disconnect()
        cameraLockConnection = nil
    end
    
    -- คืนค่า AutoRotate systemเป็นปกติ
    pcall(function()
        local char = LP.Character
        local dragon = getActiveDragonModel()
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = true end
        end
        if dragon then
            local hum = dragon:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = true end
        end
    end)
end

-- ============================================================
-- [[ ✈️ FIX TWEEN SHAKE - แก้อาการสั่นตอนเคลื่อนที่ ]]
-- ============================================================
-- Hook __newindex เพื่อบล็อกเกมจากการเปลี่ยนกล้อง
local oldNewIndex
oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, idx, val)
    -- สลับลำดับเช็คเพื่อหยุดการเข้าถึง C++ Object ลึกซึ้ง (ลดกาดร้อป FPS เวลาเกมรันกราฟิกรัวๆ)
    if cameraHardLockEnabled and idx == "CameraSubject" and not checkcaller() then
        if self == workspace.CurrentCamera then
            return nil 
        end
    end
    return oldNewIndex(self, idx, val)
end))

-- ============================================================
-- [[ 🛡️ GHOST MODE 3.0: HEARTBEAT-DRIVEN INVINCIBILITY ]]
-- ทำงานทุกเฟรม (~60fps) ไม่มีช่องว่างให้ดาเมจเข้าได้เลย
-- ============================================================
local antiHitApplied = false
local ghostHeartbeatConnection = nil
 local lastBreathRefill = 0
 
 local function startGhostHeartbeat()
     if ghostHeartbeatConnection then return end
     ghostHeartbeatConnection = RunService.Heartbeat:Connect(function()
         pcall(function()
             -- [[ 👻 GHOST PHYSICS: ปิด CanTouch/CanQuery ทุกเฟรม (~60fps) ]]
             applyGhostPhysicsStep()
 
             -- [[ 🩸 INSTANT HEAL (Humanoid): เติมเลือดโมเดลทุกเฟรม ]]
             local char = LP.Character
             local p_hum = char and char:FindFirstChildOfClass("Humanoid")
             if p_hum then p_hum.Health = p_hum.MaxHealth end
 
             local dragonModel = getActiveDragonModel()
             local d_hum = dragonModel and dragonModel:FindFirstChildOfClass("Humanoid")
             if d_hum then d_hum.Health = d_hum.MaxHealth end
 
             -- [[ 🛡️ ULTIMATE DATA HEAL (Anti-Boss): กันบอสตีเข้าเลือดจริง ]]
             local data = LP:FindFirstChild("Data")
             if data then
                 local dragonsData = data:FindFirstChild("Dragons")
                 if dragonsData then
                     for _, dFolder in pairs(dragonsData:GetChildren()) do
                         local h = dFolder:FindFirstChild("Health")
                         local mh = dFolder:FindFirstChild("MaxHealth")
                         if h and mh and h:IsA("ValueBase") and mh:IsA("ValueBase") then h.Value = mh.Value end
                     end
                 end
                 local stats = data:FindFirstChild("Stats")
                 if stats then
                     local h = stats:FindFirstChild("Health")
                     local mh = stats:FindFirstChild("MaxHealth")
                     if h and mh and h:IsA("ValueBase") and mh:IsA("ValueBase") then h.Value = mh.Value end
                 end
             end
 
             -- [[ 🔥 BREATH REFILL (Throttled) ]]
             local now = os.clock()
             
             if now - lastBreathRefill >= 0.5 then
                 lastBreathRefill = now
                 refillDragonBreathFuel(dragonModel)
             end
         end)
     end)
 end

local function stopGhostHeartbeat()
    if ghostHeartbeatConnection then
        ghostHeartbeatConnection:Disconnect()
        ghostHeartbeatConnection = nil
    end
end

-- ตัวเช็คสถานะ on/off (ไม่ต้องไว เช็คทุก 0.5 secondsพอ)
task.spawn(function()
    while true do
        local active = isAntiHitActive()
        if active ~= antiHitApplied then
            if active then
                applyHardCameraLock()
                startGhostHeartbeat()
                warn("🛡️ [Ghost 3.0] Heartbeat Protection ACTIVE (60fps)")
            else
                stopGhostHeartbeat()
                disableHardCameraLock()
                -- ฟื้นฟูค่า CanCollide, CanTouch ให้systemเป็นปกติ
                pcall(function()
                    local char = LP.Character
                    local dragon = getActiveDragonModel()
                    if char then
                        for _, v in pairs(char:GetDescendants()) do
                            if v:IsA("BasePart") then 
                                v.CanCollide = true 
                                v.CanTouch = true
                                v.CanQuery = true
                            end
                        end
                    end
                    if dragon then
                        for _, v in pairs(dragon:GetDescendants()) do
                            if v:IsA("BasePart") then 
                                v.CanCollide = true 
                                v.CanTouch = true
                                v.CanQuery = true
                            end
                        end
                    end
                    -- รีเซ็ตแคชเพื่อเวลาเปิดใหม่จะได้สแกนใหม่
                    noclipCacheChar = nil
                    noclipCacheDragon = nil
                end)
                warn("🛡️ [Ghost 3.0] Heartbeat Protection DISABLED")
            end
            antiHitApplied = active
        end
        task.wait(0.5)
    end
end)

_G.GhostMode = true

MainTab:CreateToggle({
    Name = "👻 Ghost Mode (Entity Bypass)",
    Default = true,
    Flag = "GhostModeToggle",
    Callback = function(Value)
        _G.GhostMode = Value
    end,
})

QuestToggles.Origins = MainTab:CreateToggle({
    Name = "🏠 Autoquest Original word",
    Default = false,
    Flag = "OriginsToggle",
    Callback = function(Value)
        _G.AutoQuestOrigins = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runOriginsQuest) end
    end,
})

QuestToggles.Grassland = MainTab:CreateToggle({
    Name = "🌱 Autoquest Grass land word",
    Default = false,
    Flag = "GrasslandToggle",
    Callback = function(Value)
        _G.AutoQuestGrassland = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runGrasslandQuest) end
    end,
})

QuestToggles.Jungle = MainTab:CreateToggle({
    Name = "🌴 Autoquest Jungle word",
    Default = false,
    Flag = "JungleToggle",
    Callback = function(Value)
        _G.AutoQuestJungle = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runJungleQuest) end
    end,
})

QuestToggles.Volcano = MainTab:CreateToggle({
    Name = "🌋 Autoquest Volcano word",
    Default = false,
    Flag = "VolcanoToggle",
    Callback = function(Value)
        _G.AutoQuestVolcano = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runVolcanoQuest) end
    end,
})

QuestToggles.Tundra = MainTab:CreateToggle({
    Name = "❄️ Autoquest Tundra word",
    Default = false,
    Flag = "TundraToggle",
    Callback = function(Value)
        _G.AutoQuestTundra = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runTundraQuest) end
    end,
})

QuestToggles.Ocean = MainTab:CreateToggle({
    Name = "🌊 Autoquest Ocean word",
    Default = false,
    Flag = "OceanToggle",
    Callback = function(Value)
        _G.AutoQuestOcean = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runOceanQuest) end
    end,
})

QuestToggles.Desert = MainTab:CreateToggle({
    Name = "🏜️ Autoquest Desert word",
    Default = false,
    Flag = "DesertToggle",
    Callback = function(Value)
        _G.AutoQuestDesert = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runDesertQuest) end
    end,
})

QuestToggles.Fantasy = MainTab:CreateToggle({
    Name = "✨ Autoquest Fantasy word",
    Default = false,
    Flag = "FantasyToggle",
    Callback = function(Value)
        _G.AutoQuestFantasy = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runFantasyQuest) end
    end,
})

QuestToggles.Wasteland = MainTab:CreateToggle({
    Name = "☢️ Autoquest Wasteland word",
    Default = false,
    Flag = "WastelandToggle",
    Callback = function(Value)
        _G.AutoQuestWasteland = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runWastelandQuest) end
    end,
})

QuestToggles.Prehistoric = MainTab:CreateToggle({
    Name = "🦖 Autoquest Prehistoric word",
    Default = false,
    Flag = "PrehistoricToggle",
    Callback = function(Value)
        _G.AutoQuestPrehistoric = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runPrehistoricQuest) end
    end,
})

QuestToggles.Shinrin = MainTab:CreateToggle({
    Name = "🌿 Autoquest Shinrin word",
    Default = false,
    Flag = "ShinrinToggle",
    Callback = function(Value)
        _G.AutoQuestShinrin = Value
        if Value and not _G.RuajadBossResuming then task.spawn(runShinrinQuest) end
    end,
})

-- ============================================================
-- [[ 🚀 ADVANCE TAB — 1 toggle: Origin → Shinrin ]]
-- ============================================================
local AdvanceTab = Window:CreateTab("Advance")
AdvanceTab:CreateSection("Quest Chain")
AdvanceTab:CreateParagraph({
    Title = "How it works",
    Content = "One toggle. Scans unlocks, resumes at the furthest unlocked world (e.g. Grassland — skips Origins), then quests and warps forward to Shinrin.",
})
AdvanceChainToggleObj = AdvanceTab:CreateToggle({
    Name = "Auto Quest Chain (Origin → Shinrin)",
    Default = false,
    Flag = "AdvanceQuestChainToggle",
    Callback = function(Value)
        _G.AutoQuestChain = Value
        if Value then
            setChainPersist(true)
            queueAutoQuestOnTeleport()
            _G.AutoQuestChainPaused = false
            if _G.RuajadChainSpawned then
                return
            end
            _G.RuajadChainSpawned = true
            task.spawn(function()
                if type(_G.runAdvanceQuestChain) == "function" then
                    _G.runAdvanceQuestChain()
                end
            end)
        else
            _G.RuajadChainSpawned = false
            _G.AutoQuestChainPaused = false
            _G.AutoQuestChainWorld = false
            setChainPersist(false)
            clearStaleResumeFile()
            for _, flag in ipairs(QUEST_FLAG_KEYS) do
                _G[flag] = false
            end
            setPhysics(false)
        end
    end,
})

_G.RuajadCancelChain = function()
    if AdvanceChainToggleObj then
        setToggleValue(AdvanceChainToggleObj, false)
    else
        _G.AutoQuestChain = false
        _G.AutoQuestChainWorld = false
        setChainPersist(false)
        clearStaleResumeFile()
        for _, flag in ipairs(QUEST_FLAG_KEYS) do
            _G[flag] = false
        end
        setPhysics(false)
    end
end

-- วาร์ปอัตโนมัติ → ฟาร์มเลย + ซ่อน GUI เหลือปุ่มลอย
if pendingAutoResume then
    minimizeHubToFloatBtn()
    _G.AutoQuestChain = true
    setChainPersist(true)
    queueAutoQuestOnTeleport()
    _G.AutoQuestChainPaused = false
    _G.RuajadChainSpawned = true
    pcall(function()
        if AdvanceChainToggleObj and AdvanceChainToggleObj.Set then
            AdvanceChainToggleObj.Set(true, false)
        end
    end)
    task.spawn(function()
        if type(_G.runAdvanceQuestChain) == "function" then
            _G.runAdvanceQuestChain()
        end
    end)
end

-- ============================================================
-- [[ 🌍 WORLD TELEPORT SYSTEM (DYNAMIC AUTO-FETCH) ]]
-- ============================================================
local TeleportTab = Window:CreateTab("Teleport")
TeleportTab:CreateSection("Instant World Teleport")

task.spawn(function()
    -- ใช้ข้อมูลที่รวบรวมมาโดยตรง เพื่อความแม่นยำและรวดเร็วที่สุด
    local manualWorlds = {
        {Name = "🏠 Original / Lobby", ID = 3475397644},
        {Name = "🌱 Grasslands", ID = 3475419198},
        {Name = "🌴 Jungle", ID = 3475422608},
        {Name = "🌋 Volcano", ID = 3487210751},
        {Name = "❄️ Tundra", ID = 3623549100},
        {Name = "🌊 Ocean", ID = 3737848045},
        {Name = "🏜️ Desert", ID = 3752680052},
        {Name = "✨ Fantasy", ID = 4174118306},
        {Name = "☢️ Wasteland", ID = 4728805070},
        {Name = "🦖 Prehistoric", ID = 4869039553},
        {Name = "🌿 Shinrin", ID = 125804922932357},
    }

    TeleportTab:CreateSection("Instant World Teleport")

    for _, world in ipairs(manualWorlds) do
        TeleportTab:CreateButton({
            Name = "Teleport to: " .. world.Name,
            Callback = function()
                local tpRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("WorldTeleportRemote")
                if tpRemote then
                    hubNotify("Warp Active", "Warping to " .. world.Name .. "...", 3)
                    tpRemote:InvokeServer(world.ID, {})
                else
                    hubNotify("Error", "WorldTeleportRemote not found!", 3)
                end
            end,
        })
    end
end)

if pendingAutoResume then
    minimizeHubToFloatBtn()
else
    hubNotify("RUAJAD HUB", "Loot-Friendly Ghost Mode & Auto-Loot Active!", 5)
end

-- ============================================================
-- [[ 💰 AUTO-LOOT SYSTEM: ดูดของออโต้ทันทีที่ดรอป ]]
-- ============================================================
task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    
    local dropsRemote = remotes:FindFirstChild("MobDropsRemote")
    if dropsRemote then
        dropsRemote.OnClientEvent:Connect(function(mobFolder, dropsTable)
            if _G.GhostMode and dropsTable then
                for index, _ in pairs(dropsTable) do
                    dropsRemote:FireServer(mobFolder, index)
                end
            end
        end)
    end
end) 
