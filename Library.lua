--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║            CUSTOM EXECUTOR GUI LIBRARY v2.3                  ║
    ║         Production-grade UI Library for Roblox               ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- [1] SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- [1.5] RELOAD GUARD — ล้าง instance เก่าก่อนรันทับ (กันหน่วงสะสม)
-- ============================================================
local ENV_KEY = "__CustomGuiLib_v2"

do
    if typeof(getgenv) == "function" then
        local prev = getgenv()[ENV_KEY]
        if type(prev) == "table" then
            pcall(function()
                if prev.Destroy then
                    prev:Destroy()
                elseif prev.ScreenGui then
                    prev.ScreenGui:Destroy()
                end
            end)
        end
        getgenv()[ENV_KEY] = nil
    end
end

-- ============================================================
-- [2] LIBRARY CORE & THEME
-- ============================================================
local Library = {
    Version     = "2.3.1",
    Flags       = {},
    Elements    = {},
    Connections = {},
    Unloaded    = false,
    ConfigFolder = "UILibConfigs",
    SettingsFile = "LibrarySettings.json",

    Theme = {
        MainBg        = Color3.fromRGB(14, 14, 19),
        TopBarBg      = Color3.fromRGB(18, 18, 24),
        SideBarBg     = Color3.fromRGB(11, 11, 15),
        CardBg        = Color3.fromRGB(22, 22, 30),
        CardHoverBg   = Color3.fromRGB(28, 28, 38),
        InputBg       = Color3.fromRGB(26, 26, 36),
        DropdownBg    = Color3.fromRGB(18, 18, 25),
        Accent        = Color3.fromRGB(0, 170, 255),
        AccentDark    = Color3.fromRGB(0, 110, 200),
        AccentHover   = Color3.fromRGB(40, 190, 255),
        Success       = Color3.fromRGB(34, 150, 70),
        SuccessHover  = Color3.fromRGB(44, 170, 85),
        Danger        = Color3.fromRGB(220, 65, 65),
        Warning       = Color3.fromRGB(240, 178, 60),
        Info          = Color3.fromRGB(0, 170, 255),
        Text          = Color3.fromRGB(245, 245, 250),
        TextDim       = Color3.fromRGB(175, 175, 190),
        TextSub       = Color3.fromRGB(130, 130, 142),
        Stroke        = Color3.fromRGB(38, 38, 50),
        StrokeLight   = Color3.fromRGB(60, 60, 78),
        ToggleOff     = Color3.fromRGB(48, 48, 60),
        NotifyBg      = Color3.fromRGB(22, 22, 32),
    },

    -- ค่าเริ่มต้นของธีม (สำเนาตอนโหลด — ใช้ Reset)
    DefaultTheme = nil,
    ToggleKey    = Enum.KeyCode.RightControl,
    SettingsOpen = false,
    MainFrame    = nil,
    OpenBtn      = nil,
    _settingsSaveToken = 0,
}

do
    Library.DefaultTheme = {}
    for k, v in pairs(Library.Theme) do
        Library.DefaultTheme[k] = v
    end
end

-- ============================================================
-- [3] UTILITIES
-- ============================================================
do
    function Library:Create(className, props)
        local ok, inst = pcall(Instance.new, className)
        if not ok then return nil end
        for k, v in pairs(props) do
            pcall(function() inst[k] = v end)
        end
        -- UI Transparency: element ใหม่ที่สร้างหลังเปิด UI ต้องโปร่งตามค่าที่ตั้งไว้ด้วย
        local t = Library.UiTransparency or 0
        if t > 0 and (inst:IsA("GuiObject")) then
            pcall(function()
                if inst.BackgroundTransparency < 0.98 then
                    inst.BackgroundTransparency = math.min(inst.BackgroundTransparency + t, 1)
                end
                if inst:IsA("TextBox") then
                    inst.TextTransparency = math.min(inst.TextTransparency + t * 0.5, 1)
                end
            end)
        end
        return inst
    end

    function Library:Connect(signal, fn)
        local conn = signal:Connect(fn)
        table.insert(Library.Connections, conn)
        return conn
    end

    function Library:Tween(inst, props, t, style, dir)
        t = t or 0.2
        style = style or Enum.EasingStyle.Quart
        dir   = dir   or Enum.EasingDirection.Out
        return TweenService:Create(inst, TweenInfo.new(t, style, dir), props)
    end

    function Library:SnapshotTheme()
        local snap = {}
        for k, v in pairs(Library.Theme) do
            snap[k] = v
        end
        return snap
    end

    -- เปลี่ยนสีทั้ง GUI ตามค่าเก่า→ใหม่ (อัปเดตสด)
    function Library:ApplyThemeLive(oldTheme)
        if not Library.ScreenGui then
            return
        end
        oldTheme = oldTheme or {}
        for _, d in ipairs(Library.ScreenGui:GetDescendants()) do
            pcall(function()
                if d:IsA("GuiObject") then
                    for key, oldC in pairs(oldTheme) do
                        local newC = Library.Theme[key]
                        if newC and d.BackgroundColor3 == oldC then
                            d.BackgroundColor3 = newC
                        end
                    end
                end
                if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                    for key, oldC in pairs(oldTheme) do
                        local newC = Library.Theme[key]
                        if newC and d.TextColor3 == oldC then
                            d.TextColor3 = newC
                        end
                    end
                end
                if d:IsA("UIStroke") then
                    for key, oldC in pairs(oldTheme) do
                        local newC = Library.Theme[key]
                        if newC and d.Color == oldC then
                            d.Color = newC
                        end
                    end
                end
                if d:IsA("ScrollingFrame") then
                    for key, oldC in pairs(oldTheme) do
                        local newC = Library.Theme[key]
                        if newC and d.ScrollBarImageColor3 == oldC then
                            d.ScrollBarImageColor3 = newC
                        end
                    end
                end
            end)
        end
    end

    function Library:SetTheme(themeOverride)
            local old = Library:SnapshotTheme()
            for k, v in pairs(themeOverride or {}) do
                -- จำกัดเฉพาะ key สีเดิม (กัน Type ใหม่/คีย์อื่นหลุดจาก ApplyThemeLive)
                if Library.DefaultTheme[k] ~= nil and typeof(v) == "Color3" then
                    Library.Theme[k] = v
                end
            end
            Library:ApplyThemeLive(old)
    end

    function Library:ResetTheme()
        local old = Library:SnapshotTheme()
        for k, v in pairs(Library.DefaultTheme) do
            Library.Theme[k] = v
        end
        Library:ApplyThemeLive(old)
        Library:SaveLibrarySettings()
    end

    function Library:AddCardHover(container, stroke)
        if not container or not stroke then return end
        container.MouseEnter:Connect(function()
            Library:Tween(stroke, {Color = Library.Theme.StrokeLight}, 0.15):Play()
            Library:Tween(container, {BackgroundColor3 = Library.Theme.CardHoverBg}, 0.15):Play()
        end)
        container.MouseLeave:Connect(function()
            Library:Tween(stroke, {Color = Library.Theme.Stroke}, 0.15):Play()
            Library:Tween(container, {BackgroundColor3 = Library.Theme.CardBg}, 0.15):Play()
        end)
    end

    -- ลากได้ออกนอกขอบจอ (ไม่ clamp) — onDragEnd เรียกเมื่อปล่อยเมาส์
    -- ชดเชย UIScale: UI ที่ย่อด้วย UIScale ลากแล้วต้องขยับ 1:1 กับนิ้ว/เคอร์เซอร์
    -- + gameProcessed filter: กันลากทับตอนเกม/UI อื่นกิน event ไปแล้ว (แบบ Rayfield)
    -- + GetGuiInset compensation: ชดเชย notch/status bar มือถือเมื่อ ScreenGui ใช้ IgnoreGuiInset
    function Library:MakeDraggable(handle, target, onDragEnd)
        local dragging, dragStartX, dragStartY, startPos = false, nil, nil, nil

        -- ชดเชย GuiInset (notch/status bar มือถือ): อินพุตอยู่ใน space เดียวกับ AbsolutePosition
        -- เมื่อ ScreenGui ไม่ IgnoreGuiInset → ต้องบวก inset กลับเข้าตำแหน่ง target
        local guiInsetOffset = Vector2.zero
        pcall(function()
            local sg = target:FindFirstAncestorWhichIsA("ScreenGui")
            if sg and not sg.IgnoreGuiInset then
                guiInsetOffset = game:GetService("GuiService"):GetGuiInset()
            end
        end)

        local function getDragScale()
            local s = 1
            pcall(function()
                local sc = target:FindFirstChildOfClass("UIScale")
                if sc then s = sc.Scale end
            end)
            if not s or s <= 0 then s = 1 end
            return s
        end

        local function onInputBegan(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging   = true
                -- input.Position เป็น Vector3 — ห้ามบวกกับ Vector2 (GetGuiInset) ตรงๆ
                -- บวกแยกแกนเป็นตัวเลขแทน (Lua 5.1 + Luau compatible)
                dragStartX = input.Position.X + guiInsetOffset.X
                dragStartY = input.Position.Y + guiInsetOffset.Y
                startPos   = target.Position
            end
        end

        local function onInputChanged(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end

            local curX = input.Position.X + guiInsetOffset.X
            local curY = input.Position.Y + guiInsetOffset.Y
            local dx   = curX - dragStartX
            local dy   = curY - dragStartY
            local s    = getDragScale()
            local newX = startPos.X.Offset + (dx / s)
            local newY = startPos.Y.Offset + (dy / s)
            target.Position = UDim2.new(0, newX, 0, newY)
        end

        local function onInputEnded(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    if onDragEnd then
                        pcall(onDragEnd, target)
                    end
                end
            end
        end

        handle.InputBegan:Connect(onInputBegan)
        Library:Connect(UserInputService.InputChanged, onInputChanged)
        Library:Connect(UserInputService.InputEnded,   onInputEnded)
    end
end

-- ============================================================
-- [4] SCREEN GUI
-- ============================================================
local UI_NAME = "CustomGuiLib_v2"

local existing = CoreGui:FindFirstChild(UI_NAME)
if existing then existing:Destroy() end
if LocalPlayer and LocalPlayer.PlayerGui:FindFirstChild(UI_NAME) then
    LocalPlayer.PlayerGui:FindFirstChild(UI_NAME):Destroy()
end

local ScreenGui = Library:Create("ScreenGui", {
    Name            = UI_NAME,
    ResetOnSpawn    = false,
    ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset  = true,
})

local parentOk = pcall(function() ScreenGui.Parent = CoreGui end)
if not parentOk then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

Library.ScreenGui = ScreenGui

-- ============================================================
-- [5] NOTIFICATION SYSTEM
-- ============================================================
do
    local notifyQueue   = {}
    local notifyVisible = 0
    local MAX_VISIBLE   = 3

    local notifyContainer = Library:Create("Frame", {
        Name                = "NotifyContainer",
        Size                = UDim2.new(0, 290, 1, -20),
        Position            = UDim2.new(1, -300, 0, 10),
        BackgroundTransparency = 1,
        Parent              = ScreenGui,
    })
    -- สเกลแจ้งเตือนสมส่วนตามจอ + ชิดขอบขวาเสมอ (Position ต้องรีคำนวณตามสเกล)
    -- หมายเหตุ: uiScale คำนวณจริงใน CreateWindow (เรียกทีหลัง) — ตอนนี้ใช้ default 1
    Library.UIScale = Library.UIScale or 1
    local notifyScale = Library:Create("UIScale", {
        Scale  = Library.UIScale,
        Parent = notifyContainer,
    })
    Library.NotifyScale = notifyScale
    Library.UpdateNotifyScale = function()
        local s = Library.UIScale or 1
        notifyScale.Scale = s
        notifyContainer.Position = UDim2.new(1, -(300 * s), 0, 10)
        notifyContainer.Size = UDim2.new(0, 290, 1, -20)
    end
    Library.UpdateNotifyScale()
    Library:Create("UIListLayout", {
        SortOrder           = Enum.SortOrder.LayoutOrder,
        VerticalAlignment   = Enum.VerticalAlignment.Bottom,
        Padding             = UDim.new(0, 6),
        Parent              = notifyContainer,
    })

    local function ShowNotify(data)
        local title    = tostring(data.Title    or "Notification")
        local content  = tostring(data.Content  or "")
        local duration = tonumber(data.Duration) or 3
        local ntype    = tostring(data.Type or "Info")
        local typeKey  = ntype:lower()

        local typeColor = Library.Theme.Info or Library.Theme.Accent
        local typeIcon  = "i"
        if typeKey == "success" then
            typeColor = Library.Theme.Success
            typeIcon  = "✓"
        elseif typeKey == "warning" or typeKey == "warn" then
            typeColor = Library.Theme.Warning or Color3.fromRGB(240, 178, 60)
            typeIcon  = "!"
        elseif typeKey == "error" or typeKey == "danger" then
            typeColor = Library.Theme.Danger
            typeIcon  = "✕"
        end

        local contentLines = 1
        if content ~= "" then
            pcall(function()
                local _, breaks = content:gsub("\n", "\n")
                contentLines = math.min(3, breaks + 1)
            end)
        end
        local cardH = (content == "" and 46) or (30 + contentLines * 16)

        local note = Library:Create("Frame", {
            Size                = UDim2.new(1, 0, 0, cardH),
            BackgroundColor3    = Library.Theme.NotifyBg,
            BackgroundTransparency = 0.02,
            BorderSizePixel     = 0,
            ClipsDescendants    = true,
            Parent              = notifyContainer,
        })
        Library:Create("UICorner",  {CornerRadius = UDim.new(0, 10), Parent = note})
        local noteStroke = Library:Create("UIStroke",  {Color = Library.Theme.Stroke, Thickness = 1, Parent = note})
        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(225, 225, 235)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.94),
                NumberSequenceKeypoint.new(1, 0.88),
            }),
            Rotation = 90,
            Parent = note,
        })

        local topBar = Library:Create("Frame", {
            Size             = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = typeColor,
            BorderSizePixel  = 0,
            Parent           = note,
        })

        local iconBadge = Library:Create("Frame", {
            Size             = UDim2.new(0, 22, 0, 22),
            Position         = UDim2.new(0, 10, 0, 8),
            BackgroundColor3 = typeColor,
            BackgroundTransparency = 0.85,
            BorderSizePixel  = 0,
            Parent           = note,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = iconBadge})
        Library:Create("TextLabel", {
            Size                = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Font                = Enum.Font.GothamBold,
            TextSize           = 12,
            TextColor3          = typeColor,
            Text                = typeIcon,
            Parent              = iconBadge,
        })

        Library:Create("TextLabel", {
            Size                = UDim2.new(1, -44, 0, 20),
            Position            = UDim2.new(0, 38, 0, 7),
            BackgroundTransparency = 1,
            Font                = Enum.Font.GothamBold,
            TextSize           = 14,
            TextColor3          = Library.Theme.Text,
            Text                = title,
            TextXAlignment      = Enum.TextXAlignment.Left,
            TextTruncate        = Enum.TextTruncate.AtEnd,
            Parent              = note,
        })

        if content ~= "" then
            Library:Create("TextLabel", {
                Size                = UDim2.new(1, -44, 0, contentLines * 16),
                Position            = UDim2.new(0, 38, 0, 27),
                BackgroundTransparency = 1,
                Font                = Enum.Font.Gotham,
                TextSize           = 12,
                TextColor3          = Library.Theme.TextDim,
                Text                = content,
                TextWrapped         = true,
                TextXAlignment      = Enum.TextXAlignment.Left,
                TextYAlignment      = Enum.TextYAlignment.Top,
                Parent              = note,
            })
        end

        local progBg = Library:Create("Frame", {
            Size             = UDim2.new(1, -20, 0, 2),
            Position         = UDim2.new(0, 10, 1, -5),
            BackgroundColor3 = Library.Theme.Stroke,
            BackgroundTransparency = 0.4,
            BorderSizePixel  = 0,
            Parent           = note,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = progBg})
        local progFill = Library:Create("Frame", {
            Size             = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = typeColor,
            BorderSizePixel  = 0,
            Parent           = progBg,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = progFill})

        local dismissed = false
        local function dismiss(instant)
            if dismissed then return end
            dismissed = true
            pcall(function()
                Library:Tween(noteStroke, {Transparency = 1}, 0.2):Play()
                Library:Tween(note, {BackgroundTransparency = 1}, 0.2):Play()
                for _, d in ipairs(note:GetDescendants()) do
                    pcall(function()
                        if d:IsA("TextLabel") or d:IsA("TextButton") then
                            Library:Tween(d, {TextTransparency = 1}, 0.2):Play()
                        elseif d:IsA("Frame") and d ~= note then
                            Library:Tween(d, {BackgroundTransparency = 1}, 0.2):Play()
                        elseif d:IsA("UIStroke") then
                            Library:Tween(d, {Transparency = 1}, 0.2):Play()
                        end
                    end)
                end
            end)
            local slideT = instant and 0.01 or 0.3
            Library:Tween(note, {Position = UDim2.new(1.15, 0, 0, 0)}, slideT, Enum.EasingStyle.Quart, Enum.EasingDirection.In):Play()
            task.delay(slideT + 0.05, function()
                pcall(function() note:Destroy() end)
                notifyVisible = notifyVisible - 1
                if #notifyQueue > 0 and notifyVisible < MAX_VISIBLE then
                    local next = table.remove(notifyQueue, 1)
                    ShowNotify(next)
                end
            end)
        end

        note.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dismiss(false)
            end
        end)

        Library:Tween(progFill, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out):Play()
        Library:Tween(noteStroke, {Color = typeColor}, 0.25):Play()
        note.Position = UDim2.new(1.15, 0, 0, 0)
        Library:Tween(note, {Position = UDim2.new(0, 0, 0, 0)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
        notifyVisible = notifyVisible + 1

        task.delay(duration, function()
            dismiss(false)
        end)
    end

    function Library:Notify(data)
        if notifyVisible >= MAX_VISIBLE then
            table.insert(notifyQueue, data)
        else
            ShowNotify(data)
        end
    end

    -- ทางลัดตามระดับ: NotifySuccess / NotifyWarning / NotifyError / NotifyInfo
    function Library:NotifySuccess(title, content, duration)
        Library:Notify({ Title = title, Content = content, Duration = duration, Type = "Success" })
    end
    function Library:NotifyWarning(title, content, duration)
        Library:Notify({ Title = title, Content = content, Duration = duration, Type = "Warning" })
    end
    function Library:NotifyError(title, content, duration)
        Library:Notify({ Title = title, Content = content, Duration = duration, Type = "Error" })
    end
    function Library:NotifyInfo(title, content, duration)
        Library:Notify({ Title = title, Content = content, Duration = duration, Type = "Info" })
    end
end

-- ============================================================
-- [6] CONFIGURATION SAVE / LOAD
-- ============================================================
do
    local function ensureConfigFolder()
        if typeof(isfolder) == "function" and typeof(makefolder) == "function" then
            if not isfolder(Library.ConfigFolder) then
                makefolder(Library.ConfigFolder)
            end
        end
    end

    local function settingsPath()
        return Library.ConfigFolder .. "/" .. Library.SettingsFile
    end

    -- จำ Settings ของ Library (ToggleKey / Theme / ตำแหน่งหน้าต่าง) — เงียบ ไม่แจ้งเตือน
    function Library:SaveLibrarySettings()
        pcall(function()
            if typeof(writefile) ~= "function" then
                return
            end
            ensureConfigFolder()

            local data = {
                ToggleKey = (Library.ToggleKey and Library.ToggleKey.Name) or "RightControl",
                Theme = {},
                UiTransparency = Library.UiTransparency or 0,
            }

            for k, v in pairs(Library.Theme) do
                if typeof(v) == "Color3" then
                    data.Theme[k] = { R = v.R, G = v.G, B = v.B }
                end
            end

            if Library.MainFrame then
                data.WindowPos = {
                    X = Library.MainFrame.Position.X.Offset,
                    Y = Library.MainFrame.Position.Y.Offset,
                }
            end
            if Library.OpenBtn then
                data.OpenBtnPos = {
                    X = Library.OpenBtn.Position.X.Offset,
                    Y = Library.OpenBtn.Position.Y.Offset,
                }
            end

            writefile(settingsPath(), HttpService:JSONEncode(data))
        end)
    end

    -- debounce ตอนลากสี / ลากหน้าต่างถี่ ๆ
    function Library:ScheduleSaveLibrarySettings(delaySec)
        delaySec = delaySec or 0.35
        Library._settingsSaveToken = (Library._settingsSaveToken or 0) + 1
        local token = Library._settingsSaveToken
        task.delay(delaySec, function()
            if token == Library._settingsSaveToken and not Library.Unloaded then
                Library:SaveLibrarySettings()
            end
        end)
    end

    -- คืนค่า table ที่โหลดได้ (มี WindowPos / OpenBtnPos) หรือ nil
    function Library:LoadLibrarySettings()
        local ok, decoded = pcall(function()
            if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
                return nil
            end
            local path = settingsPath()
            if not isfile(path) then
                return nil
            end
            local raw = readfile(path)
            local data = HttpService:JSONDecode(raw)
            assert(type(data) == "table", "Invalid library settings")
            return data
        end)

        if not ok or type(decoded) ~= "table" then
            return nil
        end

        if type(decoded.ToggleKey) == "string" then
            local kc = Enum.KeyCode[decoded.ToggleKey]
            if kc then
                Library.ToggleKey = kc
            end
        end

        if type(decoded.Theme) == "table" then
            for k, c in pairs(decoded.Theme) do
                if Library.Theme[k] ~= nil and type(c) == "table" and typeof(c.R) == "number" then
                    Library.Theme[k] = Color3.new(c.R, c.G, c.B)
                end
            end
        end

        if type(decoded.UiTransparency) == "number" and decoded.UiTransparency > 0 then
            Library.UiTransparency = math.clamp(decoded.UiTransparency, 0, 0.9)
        end

        return decoded
    end

    function Library:SaveConfiguration(name)
        name = (name or "default") .. ".json"
        local ok, err = pcall(function()
            assert(writefile, "writefile not supported by this executor")

            ensureConfigFolder()

            local saveData = {}
            for flag, val in pairs(Library.Flags) do
                local t = typeof(val)
                if t == "Color3" then
                    saveData[flag] = {_type = "Color3", R = val.R, G = val.G, B = val.B}
                elseif t == "EnumItem" then
                    saveData[flag] = {_type = "Enum", Name = val.Name, EnumType = tostring(val.EnumType)}
                else
                    saveData[flag] = val
                end
            end

            writefile(Library.ConfigFolder .. "/" .. name, HttpService:JSONEncode(saveData))
        end)

        if ok then
            Library:Notify({Title = "Config Saved 💾", Content = name, Duration = 2.5})
        else
            Library:Notify({Title = "Save Failed ⚠️", Content = tostring(err), Duration = 3})
        end
    end

    function Library:LoadConfiguration(name)
        name = (name or "default") .. ".json"
        local ok, err = pcall(function()
            assert(isfile, "isfile not supported by this executor")
            assert(isfile(Library.ConfigFolder .. "/" .. name), "Config file not found: " .. name)

            local raw     = readfile(Library.ConfigFolder .. "/" .. name)
            local decoded = HttpService:JSONDecode(raw)
            assert(type(decoded) == "table", "Invalid config format")

            for flag, data in pairs(decoded) do
                local elem = Library.Elements[flag]
                if elem and elem.Set then
                    if type(data) == "table" and data._type == "Color3" then
                        pcall(elem.Set, Color3.new(data.R, data.G, data.B))
                    elseif type(data) == "table" and data._type == "Enum" then
                        local enumVal = pcall(function() return Enum.KeyCode[data.Name] end)
                        if enumVal then pcall(elem.Set, Enum.KeyCode[data.Name]) end
                    else
                        pcall(elem.Set, data)
                    end
                end
            end
        end)

        if ok then
            Library:Notify({Title = "Config Loaded 📂", Content = name, Duration = 2.5})
        else
            Library:Notify({Title = "Load Failed ⚠️", Content = tostring(err), Duration = 3})
        end
    end
end

-- ============================================================
-- [7] WINDOW BUILDER
-- ============================================================
function Library:CreateWindow(config)
    config = config or {}

    local windowTitle  = config.Title      or "Custom Hub"
    local toggleIcon   = config.ToggleIcon or "rbxassetid://101260008442128"

    -- โหลด Settings ที่จำไว้ (ToggleKey / Theme) ก่อนสร้าง UI
    local savedSettings = Library:LoadLibrarySettings()

    -- ขนาดหน้าต่างปรับอัตโนมัติตามขนาดหน้าจอ (มือถือ / แท็บเล็ต / คอม)
    -- + UIScale ย่อสมส่วนทั้ง UI บนจอเล็ก (มือถือ/แท็บเล็ต) — คอมคงลุคเดิม 100%
    -- BASE = ขนาดออกแบบอ้างอิงเดสก์ท็อป
    local BASE_W, BASE_H = 620, 480

    -- คำนวณ tier ขนาด + scale ย่อสมส่วน (เรียกซ้ำได้ตอนหมุนจอ)
    local function computeLayout(vp)
        vp = vp or workspace.CurrentCamera.ViewportSize
        local targetWidth, targetHeight
        if vp.X < 600 then
            -- มือถือ portrait / จอเล็กมาก: เต็มเกือบจอ
            targetWidth  = math.max(280, vp.X - 16)
            targetHeight = math.max(240, vp.Y - 80)
        elseif vp.X < 960 then
            -- มือถือ landscape / แท็บเล็ต: 88% ของจอ
            targetWidth  = math.floor(vp.X * 0.88)
            targetHeight = math.floor(vp.Y * 0.85)
        else
            -- คอม / จอใหญ่: ขนาดออกแบบตายตัว ไม่ย่อ
            targetWidth  = BASE_W
            targetHeight = BASE_H
        end
        targetWidth  = math.min(targetWidth,  vp.X - 16)
        targetHeight = math.min(targetHeight, vp.Y - 16)
        -- สเกลย่อสมส่วน: จอเล็กทั้ง subtree ย่อตาม จอคอม = 1 (ไม่เปลี่ยนลุคเดิม)
        local scale = math.clamp(math.min(targetWidth / BASE_W, targetHeight / BASE_H, 1), 0.55, 1)
        return targetWidth, targetHeight, scale
    end

    local targetWidth, targetHeight, uiScale = computeLayout()
    -- ขนาดตรรกกะที่วางของข้างใน (px เดิม) — UIScale จะ render ย่อจริง
    local logicalW = math.floor(targetWidth / uiScale + 0.5)
    local logicalH = math.floor(targetHeight / uiScale + 0.5)
    local finalSize = UDim2.new(0, logicalW, 0, logicalH)

    local vp = workspace.CurrentCamera.ViewportSize
    local startX = math.max(8, (vp.X - targetWidth)  / 2)
    local startY = math.max(8, (vp.Y - targetHeight) / 2)
    if savedSettings and type(savedSettings.WindowPos) == "table"
        and typeof(savedSettings.WindowPos.X) == "number"
        and typeof(savedSettings.WindowPos.Y) == "number" then
        startX = savedSettings.WindowPos.X
        startY = savedSettings.WindowPos.Y
    end

    -- Library-wide scale state (ใช้ร่วมกับ MakeDraggable / Notify / live-update)
    Library.UIScale = uiScale
    -- sync สเกลแจ้งเตือน (สร้างก่อนหน้านี้ด้วย default 1) + ตำแหน่งชิดขวาตามสเกลจริง
    if Library.UpdateNotifyScale then Library.UpdateNotifyScale() end

    -- ── Touch detection (แยกจากขนาดจอ แบบ Rayfield) ──
    -- อุปกรณ์สัมผัส: ขยาย hit area / ปุ่มลอยให้แตะง่ายขึ้น (แยกจาก useMobileSizing โดยสิ้นเชิง)
    Library.TouchEnabled = false
    pcall(function()
        Library.TouchEnabled = UserInputService.TouchEnabled or false
    end)
    -- live update: อุปกรณ์บางตัวเสียบ/ถอด touch (แท็บเล็ต+คีย์บอร์ด) — เก็บ connection ไว้ปรับ OpenBtn ด้วย
    Library._touchConns = {}
    table.insert(Library._touchConns, UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
        Library.TouchEnabled = UserInputService.TouchEnabled or false
        pcall(function()
            local ob = Library.OpenBtn
            if ob then
                local sz = Library.TouchEnabled and 56 or 44
                ob.Size = UDim2.new(0, sz, 0, sz)
                local ic = ob:FindFirstChildOfClass("ImageLabel")
                if ic then
                    local half = sz / 2
                    ic.Size = UDim2.new(0, sz - 18, 0, sz - 18)
                    ic.Position = UDim2.new(0.5, -(sz - 18) / 2, 0.5, -(sz - 18) / 2)
                end
            end
        end)
    end))

    local openStartX, openStartY = 20, 100
    if savedSettings and type(savedSettings.OpenBtnPos) == "table"
        and typeof(savedSettings.OpenBtnPos.X) == "number"
        and typeof(savedSettings.OpenBtnPos.Y) == "number" then
        openStartX = savedSettings.OpenBtnPos.X
        openStartY = savedSettings.OpenBtnPos.Y
    end

    local function onWindowDragEnd()
        Library:ScheduleSaveLibrarySettings(0.2)
    end

    -- ── Floating Toggle Button (Hidden initially, visible when minimized) ──
    -- อุปกรณ์สัมผัส: ขยาย 56px ให้แตะง่าย (Rayfield-style touch consideration)
    local openBtnSize = Library.TouchEnabled and 56 or 44
    local openBtn = Library:Create("Frame", {
        Name             = "OpenBtn",
        Size             = UDim2.new(0, openBtnSize, 0, openBtnSize),
        Position         = UDim2.new(0, openStartX, 0, openStartY),
        BackgroundColor3 = Library.Theme.TopBarBg,
        BorderSizePixel  = 0,
        Active           = true,
        Visible          = false,
        Parent           = ScreenGui,
    })
    Library:Create("UICorner",  {CornerRadius = UDim.new(1, 0), Parent = openBtn})
    Library:Create("UIStroke",  {Color = Library.Theme.StrokeLight, Thickness = 1.5, Parent = openBtn})
    local openIconSize = openBtnSize - 18
    Library:Create("ImageLabel", {
        Size                   = UDim2.new(0, openIconSize, 0, openIconSize),
        Position               = UDim2.new(0.5, -openIconSize / 2, 0.5, -openIconSize / 2),
        BackgroundTransparency = 1,
        Image                  = toggleIcon,
        Parent                 = openBtn,
    })

    local openClickBtn = Library:Create("TextButton", {
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = "",
        ZIndex                 = 2,
        Parent                 = openBtn,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = openClickBtn})
    Library:MakeDraggable(openClickBtn, openBtn, onWindowDragEnd)

    -- ── Main Frame ────────────────────────────────────────────
    local MainFrame = Library:Create("Frame", {
        Name             = "MainFrame",
        Size             = finalSize,
        Position         = UDim2.new(0, startX, 0, startY),
        BackgroundColor3 = Library.Theme.MainBg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Parent           = ScreenGui,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = MainFrame})
    Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1.5, Parent = MainFrame})

    -- UIScale: ย่อ/ขยายทั้ง subtree สมส่วนตามหน้าจอ (มือถือ/แท็บเล็ตย่อ คอม = 1)
    local mainScale = Library:Create("UIScale", {Scale = uiScale, Parent = MainFrame})
    Library.MainScale = mainScale

    Library.MainFrame = MainFrame
    Library.OpenBtn   = openBtn

    -- ── Live responsive update: หมุนจอ / ย่อ-ขยายหน้าต่างเกม ──
    -- คำนวณ tier + scale ใหม่ ปรับขนาด/สเกลสด และ clamp ตำแหน่งไม่ให้หลุดจอ
    function Library:ApplyResponsiveLayout()
        pcall(function()
            if Library.Unloaded then return end
            local camNow = workspace.CurrentCamera
            if not camNow then return end
            local vpNow = camNow.ViewportSize

            local w, h, s = computeLayout(vpNow)
            local logicalW2 = math.floor(w / s + 0.5)
            local logicalH2 = math.floor(h / s + 0.5)

            Library.UIScale = s
            if Library.MainScale then Library.MainScale.Scale = s end
            MainFrame.Size = UDim2.new(0, logicalW2, 0, logicalH2)

            if Library.UpdateNotifyScale then Library.UpdateNotifyScale() end

            -- clamp ตำแหน่งหน้าต่าง + ปุ่มลอยให้อยู่ในจอ (render size = logical × s)
            local function clampPos(inst, rw, rh)
                local p = inst.Position
                local nx = math.clamp(p.X.Offset, -rw * 0.5, math.max(8, vpNow.X - rw * 0.5))
                local ny = math.clamp(p.Y.Offset, 0, math.max(8, vpNow.Y - rh * 0.5))
                inst.Position = UDim2.new(p.X.Scale, nx, p.Y.Scale, ny)
            end
            clampPos(MainFrame, logicalW2 * s, logicalH2 * s)
            if Library.OpenBtn then
                clampPos(Library.OpenBtn, 44, 44)
            end
        end)
    end

    -- Heartbeat polling: เช็ค viewport ทุก 0.3 วิ — ทนทานทุก executor
    -- (GetPropertyChangedSignal("ViewportSize") บาง executor ไม่ยิงเมื่อย่อหน้าต่าง)
    local lastVpX, lastVpY = -1, -1
    local pollAcc = 0
    Library:Connect(RunService.Heartbeat, function(dt)
        pollAcc = pollAcc + dt
        if pollAcc < 0.3 then return end
        pollAcc = 0
        local camNow = workspace.CurrentCamera
        if not camNow then return end
        local vpNow = camNow.ViewportSize
        if vpNow.X ~= lastVpX or vpNow.Y ~= lastVpY then
            lastVpX, lastVpY = vpNow.X, vpNow.Y
            Library:ApplyResponsiveLayout()
        end
    end)
    -- เช็คครั้งแรกทันที (จับกรณี viewport เปลี่ยนระหว่างโหลด)
    Library:ApplyResponsiveLayout()

    -- ── TopBar ────────────────────────────────────────────────
    local TopBar = Library:Create("Frame", {
        Name             = "TopBar",
        Size             = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Library.Theme.TopBarBg,
        BorderSizePixel  = 0,
        ZIndex           = 2,
        Parent           = MainFrame,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = TopBar})
    Library:Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 10),
        Position         = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Library.Theme.TopBarBg,
        BorderSizePixel  = 0,
        ZIndex           = 2,
        Parent           = TopBar,
    })

    Library:MakeDraggable(TopBar, MainFrame, onWindowDragEnd)

    Library:Create("ImageLabel", {
        Size                   = UDim2.new(0, 24, 0, 24),
        Position               = UDim2.new(0, 14, 0.5, -12),
        BackgroundTransparency = 1,
        Image                  = "rbxassetid://101260008442128",
        ZIndex                 = 3,
        Parent                 = TopBar,
    })

    -- ความกว้างชื่อ: เว้นพื้นที่ปุ่มด้านขวา (touch ปุ่มใหญ่กว่า)
    local titleRight = Library.TouchEnabled and -168 or -128
    Library:Create("TextLabel", {
        Size               = UDim2.new(1, titleRight, 1, 0),
        Position           = UDim2.new(0, 42, 0, 0),
        BackgroundTransparency = 1,
        Font               = Enum.Font.GothamBold,
        TextSize           = 15,
        TextColor3         = Library.Theme.Text,
        Text               = windowTitle,
        TextXAlignment     = Enum.TextXAlignment.Left,
        ZIndex             = 3,
        Parent             = TopBar,
    })

    -- ── Window control icons (settings / minimize / close) ────
    -- อุปกรณ์สัมผัส: ปุ่ม 36×36 + glyph ใหญ่ขึ้น (แตะง่าย) / เดสก์ท็อป: 28×28 เหมือนเดิม
    local chromeBtnSize = Library.TouchEnabled and 36 or 28
    local chromeHalf = chromeBtnSize / 2
    -- ตำแหน่งปุ่มจากขอบขวา: เว้นช่องไฟ 4px ระหว่างปุ่มเสมอ
    local posXClose = -(4 + chromeBtnSize)
    local posXMin = posXClose - 4 - chromeBtnSize
    local posXSettings = posXMin - 4 - chromeBtnSize
    -- ขนาด glyph (ขีด / แท่ง X)
    local dashW = Library.TouchEnabled and 16 or 12
    local dashH = Library.TouchEnabled and 3 or 2
    local xLen = Library.TouchEnabled and 17 or 13
    local xH = Library.TouchEnabled and 3 or 2
    local gearSize = Library.TouchEnabled and 20 or 16

    local function makeChromeIconBtn(btnPosX, makeGlyph)
        local btn = Library:Create("TextButton", {
            Size               = UDim2.new(0, chromeBtnSize, 0, chromeBtnSize),
            Position           = UDim2.new(1, btnPosX, 0.5, -chromeHalf),
            BackgroundColor3   = Library.Theme.CardBg,
            BackgroundTransparency = 1,
            Text               = "",
            AutoButtonColor    = false,
            ZIndex             = 4,
            Parent             = TopBar,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = btn})

        local glyphs = makeGlyph(btn, Library.Theme.TextSub)

        local function setGlyphColor(color)
            for _, g in ipairs(glyphs) do
                if g:IsA("GuiObject") and not g:IsA("ImageLabel") and not g:IsA("ImageButton") then
                    g.BackgroundColor3 = color
                elseif g:IsA("ImageLabel") or g:IsA("ImageButton") then
                    g.ImageColor3 = color
                elseif g:IsA("UIStroke") then
                    g.Color = color
                end
            end
        end

        btn.MouseEnter:Connect(function()
            Library:Tween(btn, {BackgroundTransparency = 0.35}, 0.12):Play()
            setGlyphColor(Library.Theme.Text)
        end)
        btn.MouseLeave:Connect(function()
            Library:Tween(btn, {BackgroundTransparency = 1}, 0.12):Play()
            setGlyphColor(Library.Theme.TextSub)
        end)

        return btn, setGlyphColor
    end

    -- Settings: official Roblox gear (white silhouette) — tinted to match theme
    -- Source: Roblox Creator Docs interactive UI tutorial
    local SETTINGS_ICON = "rbxassetid://104919049969988"
    local SettingsBtn = Library:Create("TextButton", {
        Name                   = "SettingsBtn",
        Size                   = UDim2.new(0, chromeBtnSize, 0, chromeBtnSize),
        Position               = UDim2.new(1, posXSettings, 0.5, -chromeHalf),
        BackgroundTransparency = 1,
        Text                   = "",
        AutoButtonColor        = false,
        ZIndex                 = 4,
        Parent                 = TopBar,
    })
    local settingsIcon = Library:Create("ImageLabel", {
        Name                   = "Icon",
        Size                   = UDim2.new(0, gearSize, 0, gearSize),
        Position               = UDim2.new(0.5, -gearSize / 2, 0.5, -gearSize / 2),
        BackgroundTransparency = 1,
        Image                  = SETTINGS_ICON,
        ImageColor3            = Library.Theme.TextSub,
        ScaleType              = Enum.ScaleType.Fit,
        ZIndex                 = 5,
        Parent                 = SettingsBtn,
    })
    SettingsBtn.MouseEnter:Connect(function()
        settingsIcon.ImageColor3 = Library.Theme.Accent
    end)
    SettingsBtn.MouseLeave:Connect(function()
        settingsIcon.ImageColor3 = Library.SettingsOpen and Library.Theme.Accent or Library.Theme.TextSub
    end)

    -- Minimize: clean horizontal dash
    local MinBtn = makeChromeIconBtn(posXMin, function(btn, color)
        local bar = Library:Create("Frame", {
            Size             = UDim2.new(0, dashW, 0, dashH),
            Position         = UDim2.new(0.5, -dashW / 2, 0.5, -dashH / 2),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
            ZIndex           = 5,
            Parent           = btn,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = bar})
        return { bar }
    end)

    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        openBtn.Visible   = true
        Library.SettingsOpen = false
    end)

    -- Close: modern X from two rotated bars
    local CloseBtn, setCloseGlyphColor = makeChromeIconBtn(posXClose, function(btn, color)
        local a = Library:Create("Frame", {
            Size             = UDim2.new(0, xLen, 0, xH),
            Position         = UDim2.new(0.5, -xLen / 2, 0.5, -xH / 2),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
            Rotation         = 45,
            ZIndex           = 5,
            Parent           = btn,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = a})
        local b = Library:Create("Frame", {
            Size             = UDim2.new(0, xLen, 0, xH),
            Position         = UDim2.new(0.5, -xLen / 2, 0.5, -xH / 2),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
            Rotation         = -45,
            ZIndex           = 5,
            Parent           = btn,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = b})
        return { a, b }
    end)

    -- Override close hover to danger red
    CloseBtn.MouseEnter:Connect(function()
        Library:Tween(CloseBtn, {
            BackgroundTransparency = 0.25,
            BackgroundColor3 = Color3.fromRGB(60, 18, 22),
        }, 0.12):Play()
        setCloseGlyphColor(Library.Theme.Danger)
    end)
    CloseBtn.MouseLeave:Connect(function()
        Library:Tween(CloseBtn, {
            BackgroundTransparency = 1,
            BackgroundColor3 = Library.Theme.CardBg,
        }, 0.12):Play()
        setCloseGlyphColor(Library.Theme.TextSub)
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        Library:Destroy()
    end)

    -- Restore Window on Floating Button Click
    local clickStart
    openClickBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            clickStart = i.Position
        end
    end)
    openClickBtn.InputEnded:Connect(function(i)
        if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            if clickStart and (i.Position - clickStart).Magnitude < 8 then
                MainFrame.Visible = true
                openBtn.Visible   = false
            end
        end
    end)

    -- ── Settings Panel ────────────────────────────────────────
    local settingsBinding = false
    local SettingsPanel = Library:Create("Frame", {
        Name             = "SettingsPanel",
        Size             = UDim2.new(1, -12, 1, -54),
        Position         = UDim2.new(0, 6, 0, 49),
        BackgroundColor3 = Library.Theme.MainBg,
        BorderSizePixel  = 0,
        Visible          = false,
        ZIndex           = 50,
        ClipsDescendants = true,
        Parent           = MainFrame,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = SettingsPanel})
    Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = SettingsPanel})

    local settingsHeader = Library:Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Library.Theme.TopBarBg,
        BorderSizePixel  = 0,
        ZIndex           = 51,
        Parent           = SettingsPanel,
    })
    Library:Create("TextLabel", {
        Size               = UDim2.new(1, -50, 1, 0),
        Position           = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Font               = Enum.Font.GothamBold,
        TextSize           = 15,
        TextColor3         = Library.Theme.Text,
        Text               = "Settings",
        TextXAlignment     = Enum.TextXAlignment.Left,
        ZIndex             = 52,
        Parent             = settingsHeader,
    })
    local settingsClose = Library:Create("TextButton", {
        Size               = UDim2.new(0, 30, 0, 30),
        Position           = UDim2.new(1, -34, 0.5, -15),
        BackgroundTransparency = 1,
        Font               = Enum.Font.GothamBold,
        TextSize           = 16,
        TextColor3         = Library.Theme.TextSub,
        Text               = "X",
        ZIndex             = 52,
        Parent             = settingsHeader,
    })

    local settingsScroll = Library:Create("ScrollingFrame", {
        Size                   = UDim2.new(1, -16, 1, -52),
        Position               = UDim2.new(0, 8, 0, 44),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 4,
        ScrollBarImageColor3   = Library.Theme.StrokeLight,
        CanvasSize             = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        ZIndex                 = 51,
        Parent                 = SettingsPanel,
    })
    Library:Create("UIListLayout", {
        Padding   = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent    = settingsScroll,
    })
    Library:Create("UIPadding", {
        PaddingTop    = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft   = UDim.new(0, 4),
        PaddingRight  = UDim.new(0, 8),
        Parent        = settingsScroll,
    })

    local function settingsSection(title)
        local f = Library:Create("Frame", {
            Size             = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            ZIndex           = 52,
            Parent           = settingsScroll,
        })
        Library:Create("TextLabel", {
            Size               = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Font               = Enum.Font.GothamBold,
            TextSize           = 12,
            TextColor3         = Library.Theme.Accent,
            Text               = string.upper(title),
            TextXAlignment     = Enum.TextXAlignment.Left,
            ZIndex             = 53,
            Parent             = f,
        })
        return f
    end

    settingsSection("Hotkeys")

    local keyRow = Library:Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Library.Theme.CardBg,
        BorderSizePixel  = 0,
        ZIndex           = 52,
        Parent           = settingsScroll,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = keyRow})
    Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = keyRow})
    Library:Create("TextLabel", {
        Size               = UDim2.new(1, -120, 1, 0),
        Position           = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Font               = Enum.Font.GothamSemibold,
        TextSize           = 13,
        TextColor3         = Library.Theme.TextDim,
        Text               = "Toggle GUI Key",
        TextXAlignment     = Enum.TextXAlignment.Left,
        ZIndex             = 53,
        Parent             = keyRow,
    })
    local keyBindBtn = Library:Create("TextButton", {
        Size             = UDim2.new(0, 100, 0, 26),
        Position         = UDim2.new(1, -110, 0.5, -13),
        BackgroundColor3 = Library.Theme.InputBg,
        Font             = Enum.Font.GothamBold,
        TextSize         = 12,
        TextColor3       = Library.Theme.Accent,
        Text             = "[" .. Library.ToggleKey.Name .. "]",
        BorderSizePixel  = 0,
        ZIndex           = 53,
        Parent           = keyRow,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = keyBindBtn})
    local keyBindStroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = keyBindBtn})

    keyBindBtn.MouseButton1Click:Connect(function()
        settingsBinding = true
        keyBindBtn.Text = "[ ... ]"
        keyBindBtn.TextColor3 = Color3.fromRGB(255, 210, 50)
        Library:Tween(keyBindStroke, {Color = Color3.fromRGB(255, 210, 50)}, 0.15):Play()
    end)

    Library:Connect(UserInputService.InputBegan, function(input, gp)
        if settingsBinding then
            if input.KeyCode == Enum.KeyCode.Escape then
                settingsBinding = false
                keyBindBtn.Text = "[" .. Library.ToggleKey.Name .. "]"
                keyBindBtn.TextColor3 = Library.Theme.Accent
                Library:Tween(keyBindStroke, {Color = Library.Theme.Stroke}, 0.15):Play()
            elseif input.UserInputType == Enum.UserInputType.Keyboard then
                settingsBinding = false
                Library.ToggleKey = input.KeyCode
                keyBindBtn.Text = "[" .. Library.ToggleKey.Name .. "]"
                keyBindBtn.TextColor3 = Library.Theme.Accent
                Library:Tween(keyBindStroke, {Color = Library.Theme.Stroke}, 0.15):Play()
                Library:SaveLibrarySettings()
                Library:Notify({
                    Title = "Hotkey Set",
                    Content = "Toggle GUI: " .. Library.ToggleKey.Name,
                    Duration = 2,
                })
            end
            return
        end

        if gp or Library.Unloaded then
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode == Library.ToggleKey
            and Library.ToggleKey ~= Enum.KeyCode.Unknown then
            if MainFrame.Visible then
                MainFrame.Visible = false
                openBtn.Visible = true
                SettingsPanel.Visible = false
                Library.SettingsOpen = false
            else
                MainFrame.Visible = true
                openBtn.Visible = false
            end
        end
    end)

    settingsSection("Theme Colors")

    local THEME_ROWS = {
        { Key = "MainBg",       Label = "Main Background" },
        { Key = "TopBarBg",     Label = "Top Bar" },
        { Key = "SideBarBg",    Label = "Side Bar" },
        { Key = "CardBg",       Label = "Card Background" },
        { Key = "CardHoverBg",  Label = "Card Hover" },
        { Key = "InputBg",      Label = "Button / Input" },
        { Key = "DropdownBg",   Label = "Dropdown" },
        { Key = "Accent",       Label = "Accent" },
        { Key = "AccentDark",   Label = "Accent Dark" },
        { Key = "AccentHover",  Label = "Accent Hover" },
        { Key = "Success",      Label = "Success / Button" },
        { Key = "SuccessHover", Label = "Success Hover" },
        { Key = "Danger",       Label = "Danger" },
        { Key = "Warning",      Label = "Warning" },
        { Key = "Info",         Label = "Info" },
        { Key = "Text",         Label = "Primary Text" },
        { Key = "TextDim",      Label = "Secondary Text" },
        { Key = "TextSub",      Label = "Muted Text" },
        { Key = "Stroke",       Label = "Stroke" },
        { Key = "StrokeLight",  Label = "Stroke Light" },
        { Key = "ToggleOff",    Label = "Toggle Off" },
        { Key = "NotifyBg",     Label = "Notify Background" },
    }

    local colorSwatches = {}
    local ROW_COLLAPSED = 40
    local ROW_EXPANDED  = 210

    local function makeColorRow(info)
        local h, s, v = Library.Theme[info.Key]:ToHSV()

        local row = Library:Create("Frame", {
            Size             = UDim2.new(1, 0, 0, ROW_COLLAPSED),
            BackgroundColor3 = Library.Theme.CardBg,
            BorderSizePixel  = 0,
            ClipsDescendants = true,
            ZIndex           = 52,
            Parent           = settingsScroll,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = row})
        Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = row})

        Library:Create("TextLabel", {
            Size               = UDim2.new(1, -58, 0, 38),
            Position           = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Font               = Enum.Font.GothamSemibold,
            TextSize           = 12,
            TextColor3         = Library.Theme.TextDim,
            Text               = info.Label,
            TextXAlignment     = Enum.TextXAlignment.Left,
            TextTruncate       = Enum.TextTruncate.AtEnd,
            ZIndex             = 53,
            Parent             = row,
        })

        local swatch = Library:Create("TextButton", {
            Size             = UDim2.new(0, 36, 0, 22),
            Position         = UDim2.new(1, -46, 0, 9),
            BackgroundColor3 = Library.Theme[info.Key],
            Text             = "",
            BorderSizePixel  = 0,
            ZIndex           = 53,
            Parent           = row,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = swatch})
        Library:Create("UIStroke", {Color = Library.Theme.StrokeLight, Thickness = 1, Parent = swatch})
        colorSwatches[info.Key] = swatch

        -- Expanded Color Picker (preview left + SV canvas right + hue bar)
        local editor = Library:Create("Frame", {
            Size             = UDim2.new(1, -12, 0, 162),
            Position         = UDim2.new(0, 6, 0, 40),
            BackgroundColor3 = Library.Theme.InputBg,
            BorderSizePixel  = 0,
            Visible          = false,
            ZIndex           = 53,
            Parent           = row,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = editor})
        Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = editor})

        Library:Create("TextLabel", {
            Size               = UDim2.new(1, -12, 0, 22),
            Position           = UDim2.new(0, 10, 0, 4),
            BackgroundTransparency = 1,
            Font               = Enum.Font.GothamBold,
            TextSize           = 12,
            TextColor3         = Library.Theme.Text,
            Text               = "Color Picker",
            TextXAlignment     = Enum.TextXAlignment.Left,
            ZIndex             = 54,
            Parent             = editor,
        })

        local preview = Library:Create("Frame", {
            Size             = UDim2.new(0, 52, 0, 96),
            Position         = UDim2.new(0, 10, 0, 28),
            BackgroundColor3 = Library.Theme[info.Key],
            BorderSizePixel  = 0,
            ZIndex           = 54,
            Parent           = editor,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = preview})

        local svFrame = Library:Create("Frame", {
            Size             = UDim2.new(1, -80, 0, 96),
            Position         = UDim2.new(0, 70, 0, 28),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel  = 0,
            ClipsDescendants = true,
            ZIndex           = 54,
            Parent           = editor,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = svFrame})

        -- White → transparent (left to right = saturation)
        local satGrad = Library:Create("Frame", {
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundColor3       = Color3.fromRGB(255, 255, 255),
            BorderSizePixel        = 0,
            ZIndex                 = 55,
            Parent                 = svFrame,
        })
        Library:Create("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = satGrad,
        })

        -- Transparent → black (top to bottom = value)
        local valGrad = Library:Create("Frame", {
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundColor3       = Color3.fromRGB(0, 0, 0),
            BorderSizePixel        = 0,
            ZIndex                 = 56,
            Parent                 = svFrame,
        })
        Library:Create("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            }),
            Parent = valGrad,
        })

        local cursor = Library:Create("Frame", {
            Size             = UDim2.new(0, 14, 0, 14),
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.new(s, 0, 1 - v, 0),
            BackgroundTransparency = 1,
            ZIndex           = 57,
            Parent           = svFrame,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = cursor})
        Library:Create("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255),
            Thickness = 2,
            Parent = cursor,
        })
        Library:Create("Frame", {
            Size             = UDim2.new(1, -4, 1, -4),
            Position         = UDim2.new(0, 2, 0, 2),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ZIndex           = 58,
            Parent           = cursor,
        })

        -- Hue rainbow bar
        local hueFrame = Library:Create("Frame", {
            Size             = UDim2.new(1, -20, 0, 12),
            Position         = UDim2.new(0, 10, 0, 132),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel  = 0,
            ZIndex           = 54,
            Parent           = editor,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = hueFrame})
        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0, 0)),
            }),
            Parent = hueFrame,
        })
        local hueKnob = Library:Create("Frame", {
            Size             = UDim2.new(0, 6, 1, 4),
            Position         = UDim2.new(h, -3, 0, -2),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel  = 0,
            ZIndex           = 55,
            Parent           = hueFrame,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = hueKnob})
        Library:Create("UIStroke", {Color = Color3.fromRGB(30, 30, 30), Thickness = 1, Parent = hueKnob})

        local hexLbl = Library:Create("TextLabel", {
            Size               = UDim2.new(1, -20, 0, 14),
            Position           = UDim2.new(0, 10, 0, 146),
            BackgroundTransparency = 1,
            Font               = Enum.Font.Gotham,
            TextSize           = 11,
            TextColor3         = Library.Theme.TextSub,
            Text               = "",
            TextXAlignment     = Enum.TextXAlignment.Left,
            ZIndex             = 54,
            Parent             = editor,
        })

        local function colorToHex(c)
            return string.format("#%02X%02X%02X",
                math.floor(c.R * 255 + 0.5),
                math.floor(c.G * 255 + 0.5),
                math.floor(c.B * 255 + 0.5))
        end

        local function commitColor(fireLive)
            local newColor = Color3.fromHSV(h, s, v)
            local old = fireLive and Library:SnapshotTheme() or nil
            Library.Theme[info.Key] = newColor
            swatch.BackgroundColor3 = newColor
            preview.BackgroundColor3 = newColor
            svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            cursor.Position = UDim2.new(s, 0, 1 - v, 0)
            hueKnob.Position = UDim2.new(h, -3, 0, -2)
            hexLbl.Text = colorToHex(newColor)
                .. string.format("  RGB(%d, %d, %d)",
                    math.floor(newColor.R * 255 + 0.5),
                    math.floor(newColor.G * 255 + 0.5),
                    math.floor(newColor.B * 255 + 0.5))
            if fireLive and old then
                Library:ApplyThemeLive(old)
            end
        end

        local function syncFromTheme()
            h, s, v = Library.Theme[info.Key]:ToHSV()
            commitColor(false)
        end

        local draggingSV, draggingHue = false, false

        local function updateSV(inputPos)
            local abs = svFrame.AbsolutePosition
            local size = svFrame.AbsoluteSize
            if size.X <= 0 or size.Y <= 0 then return end
            s = math.clamp((inputPos.X - abs.X) / size.X, 0, 1)
            v = 1 - math.clamp((inputPos.Y - abs.Y) / size.Y, 0, 1)
            commitColor(true)
        end

        local function updateHue(inputPos)
            local abs = hueFrame.AbsolutePosition
            local size = hueFrame.AbsoluteSize
            if size.X <= 0 then return end
            h = math.clamp((inputPos.X - abs.X) / size.X, 0, 1)
            commitColor(true)
        end

        svFrame.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                draggingSV = true
                updateSV(i.Position)
            end
        end)
        hueFrame.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                draggingHue = true
                updateHue(i.Position)
            end
        end)
        Library:Connect(UserInputService.InputChanged, function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            if draggingSV then updateSV(i.Position) end
            if draggingHue then updateHue(i.Position) end
        end)
        Library:Connect(UserInputService.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                if draggingSV or draggingHue then
                    draggingSV, draggingHue = false, false
                    Library:ScheduleSaveLibrarySettings(0.25)
                else
                    draggingSV, draggingHue = false, false
                end
            end
        end)

        local expanded = false
        swatch.MouseButton1Click:Connect(function()
            expanded = not expanded
            editor.Visible = expanded
            row.Size = UDim2.new(1, 0, 0, expanded and ROW_EXPANDED or ROW_COLLAPSED)
            if expanded then
                syncFromTheme()
            end
        end)

        syncFromTheme()
        return row
    end

    for _, info in ipairs(THEME_ROWS) do
        makeColorRow(info)
    end

    -- ── UI Transparency (ความโปร่งใสทั้ง GUI) ──
    -- ค่า 0 = ทึบปกติ, 0.9 = ใสมาก (ปรับเยอะ = ใสเยอะ) — บันทึกอัตโนมัติลง settings
    Library.UiTransparency = Library.UiTransparency or 0
    function Library:ApplyUiTransparency()
        pcall(function()
            if Library.Unloaded or not Library.ScreenGui then return end
            local t = math.clamp(Library.UiTransparency or 0, 0, 0.9)
            for _, d in ipairs(Library.ScreenGui:GetDescendants()) do
                if d:IsA("GuiObject") and not d:IsA("TextBox") then
                    if d.BackgroundTransparency < 0.98 then
                        d.BackgroundTransparency = math.min(d.BackgroundTransparency + t, 1)
                    end
                elseif d:IsA("TextBox") then
                    if d.BackgroundTransparency < 0.98 then
                        d.BackgroundTransparency = math.min(d.BackgroundTransparency + t, 1)
                    end
                    d.TextTransparency = math.min(d.TextTransparency + t * 0.5, 1)
                end
            end
            -- ปุ่มลอย OpenBtn (อยู่นอก MainFrame แต่ใน ScreenGui เดียวกัน) ครอบด้วย loop เดียวจบ
        end)
    end

    settingsSection("Interface")

    -- แถวปรับความโปร่งใส
    local transpRow = Library:Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Library.Theme.CardBg,
        BorderSizePixel  = 0,
        ZIndex           = 52,
        Parent           = settingsScroll,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = transpRow})
    Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = transpRow})
    Library:Create("TextLabel", {
        Size               = UDim2.new(1, -110, 0, 20),
        Position           = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Font               = Enum.Font.GothamSemibold,
        TextSize           = 12,
        TextColor3         = Library.Theme.TextDim,
        Text               = "UI Transparency",
        TextXAlignment     = Enum.TextXAlignment.Left,
        ZIndex             = 53,
        Parent             = transpRow,
    })
    local transpValLbl = Library:Create("TextLabel", {
        Size               = UDim2.new(0, 90, 0, 20),
        Position           = UDim2.new(1, -100, 0, 6),
        BackgroundTransparency = 1,
        Font               = Enum.Font.GothamBold,
        TextSize           = 12,
        TextColor3         = Library.Theme.Text,
        Text               = tostring(math.floor((Library.UiTransparency or 0) * 100)) .. "%",
        TextXAlignment     = Enum.TextXAlignment.Right,
        ZIndex             = 53,
        Parent             = transpRow,
    })

    local transpBarBg = Library:Create("Frame", {
        Size             = UDim2.new(1, -24, 0, 8),
        Position         = UDim2.new(0, 12, 0, 34),
        BackgroundColor3 = Library.Theme.InputBg,
        BorderSizePixel  = 0,
        ZIndex           = 53,
        Parent           = transpRow,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = transpBarBg})
    Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = transpBarBg})

    local transpRel0 = (Library.UiTransparency or 0) / 0.9
    local transpFill = Library:Create("Frame", {
        Size             = UDim2.new(transpRel0, 0, 1, 0),
        BackgroundColor3 = Library.Theme.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 54,
        Parent           = transpBarBg,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = transpFill})

    local transpKnob = Library:Create("Frame", {
        Size             = UDim2.new(0, 18, 0, 18),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(transpRel0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        ZIndex           = 5,
        Parent           = transpBarBg,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = transpKnob})

    local transpHitH = Library.TouchEnabled and 34 or 26
    local transpHit = Library:Create("Frame", {
        Size                       = UDim2.new(1, -24, 0, transpHitH),
        Position                   = UDim2.new(0, 12, 0, 38 - transpHitH / 2),
        BackgroundTransparency     = 1,
        BorderSizePixel            = 0,
        Active                     = true,
        ZIndex                     = 6,
        Parent                     = transpRow,
    })

    local transpDrag = false
    local function ApplyTransp(t)
        t = math.clamp(t, 0, 0.9)
        Library.UiTransparency = t
        transpFill.Size  = UDim2.new(t / 0.9, 0, 1, 0)
        transpKnob.Position = UDim2.new(t / 0.9, 0, 0.5, 0)
        transpValLbl.Text = tostring(math.floor(t * 100 + 0.5)) .. "%"
        Library:ApplyUiTransparency()
    end

    local function TranspPosToRel(pos)
        local sizeX = transpBarBg.AbsoluteSize.X
        if sizeX <= 0 then return nil end
        return math.clamp((pos.X - transpBarBg.AbsolutePosition.X) / sizeX, 0, 1)
    end

    transpHit.InputBegan:Connect(function(i, processed)
        if processed then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            transpDrag = true
            local rel = TranspPosToRel(i.Position)
            if rel then ApplyTransp(rel * 0.9) end
        end
    end)
    Library:Connect(UserInputService.InputChanged, function(i)
        if transpDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local rel = TranspPosToRel(i.Position)
            if rel then ApplyTransp(rel * 0.9) end
        end
    end)
    Library:Connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if transpDrag then
                transpDrag = false
                Library:ScheduleSaveLibrarySettings(0.35) -- บันทึกค่าไว้ใช้ครั้งหน้า
            end
        end
    end)

    -- Apply ความโปร่งใสที่โหลดจาก settings (ทำครั้งเดียวตอนเปิด UI)
    if (Library.UiTransparency or 0) > 0 then
        Library:ApplyUiTransparency()
    end

    settingsSection("Actions")

    local resetBtn = Library:Create("TextButton", {
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Library.Theme.InputBg,
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        TextColor3       = Library.Theme.Text,
        Text             = "Reset Theme to Default",
        BorderSizePixel  = 0,
        ZIndex           = 52,
        Parent           = settingsScroll,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = resetBtn})
    Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = resetBtn})
    resetBtn.MouseButton1Click:Connect(function()
        Library:ResetTheme()
        keyBindBtn.TextColor3 = Library.Theme.Accent
        for key, sw in pairs(colorSwatches) do
            if Library.Theme[key] then
                sw.BackgroundColor3 = Library.Theme[key]
            end
        end
        Library:Notify({ Title = "Theme Reset", Content = "Restored default theme colors", Duration = 2 })
    end)

    local function setSettingsOpen(open)
        Library.SettingsOpen = open
        SettingsPanel.Visible = open
        if settingsIcon then
            settingsIcon.ImageColor3 = open and Library.Theme.Accent or Library.Theme.TextSub
        end
    end

    SettingsBtn.MouseButton1Click:Connect(function()
        setSettingsOpen(not Library.SettingsOpen)
    end)
    settingsClose.MouseButton1Click:Connect(function()
        setSettingsOpen(false)
    end)
    MinBtn.MouseButton1Click:Connect(function()
        setSettingsOpen(false)
    end)

    -- ── Sidebar ───────────────────────────────────────────────
    local SideBar = Library:Create("Frame", {
        Name             = "SideBar",
        Size             = UDim2.new(0, 168, 1, -54),
        Position         = UDim2.new(0, 6, 0, 49),
        BackgroundColor3 = Library.Theme.SideBarBg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Parent           = MainFrame,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = SideBar})
    Library:Create("UIStroke", {Color = Color3.fromRGB(24, 24, 32), Thickness = 1, Parent = SideBar})

    local PROFILE_H = 58
    local SideScroll = Library:Create("ScrollingFrame", {
        Size                  = UDim2.new(1, 0, 1, -(PROFILE_H + 16)),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 3,
        ScrollBarImageColor3   = Library.Theme.StrokeLight,
        CanvasSize             = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        Parent                 = SideBar,
    })
    Library:Create("UIListLayout", {
        Padding        = UDim.new(0, 5),
        SortOrder      = Enum.SortOrder.LayoutOrder,
        Parent         = SideScroll,
    })
    Library:Create("UIPadding", {
        PaddingTop    = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft   = UDim.new(0, 8),
        PaddingRight  = UDim.new(0, 8),
        Parent        = SideScroll,
    })

    -- ── Profile Card (ล่างซ้าย): รูป + DisplayName + @username ──
    -- SideScroll สั้นลงแล้ว (จบบนการ์ด) + การ์ดทึบ ZIndex สูงกว่า → แท็บล้นจมอยู่หลัง ไม่มีวันทับ
    local ProfileCard = Library:Create("Frame", {
        Name             = "ProfileCard",
        Size             = UDim2.new(1, -16, 0, PROFILE_H),
        Position         = UDim2.new(0, 8, 1, -(PROFILE_H + 8)),
        BackgroundColor3 = Library.Theme.CardBg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = 10,
        Parent           = SideBar,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = ProfileCard})
    Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = ProfileCard})

    local AvatarImg = Library:Create("ImageLabel", {
        Name                   = "Avatar",
        Size                   = UDim2.new(0, 36, 0, 36),
        Position               = UDim2.new(0, 8, 0.5, -18),
        BackgroundColor3       = Library.Theme.InputBg,
        BackgroundTransparency = 0,
        BorderSizePixel        = 0,
        ZIndex                 = 11,
        Parent                 = ProfileCard,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = AvatarImg})
    Library:Create("UIStroke", {Color = Library.Theme.StrokeLight, Thickness = 1, Parent = AvatarImg})

    local OnlineDot = Library:Create("Frame", {
        Size             = UDim2.new(0, 10, 0, 10),
        Position         = UDim2.new(1, -8, 1, -8),
        BackgroundColor3 = Library.Theme.Success,
        BorderSizePixel  = 0,
        ZIndex           = 12,
        Parent           = AvatarImg,
    })
    Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = OnlineDot})
    Library:Create("UIStroke", {Color = Library.Theme.CardBg, Thickness = 2, Parent = OnlineDot})

    local dispName, userName = "Player", "Player"
    pcall(function()
        if LocalPlayer then
            dispName = tostring(LocalPlayer.DisplayName or LocalPlayer.Name or "Player")
            userName = tostring(LocalPlayer.Name or "Player")
        end
    end)
    Library:Create("TextLabel", {
        Size                = UDim2.new(1, -58, 0, 18),
        Position            = UDim2.new(0, 52, 0, 10),
        BackgroundTransparency = 1,
        Font                = Enum.Font.GothamBold,
        TextSize            = 13,
        TextColor3          = Library.Theme.Text,
        Text                = dispName,
        TextXAlignment      = Enum.TextXAlignment.Left,
        TextTruncate        = Enum.TextTruncate.AtEnd,
        ZIndex              = 11,
        Parent              = ProfileCard,
    })
    Library:Create("TextLabel", {
        Size                = UDim2.new(1, -58, 0, 16),
        Position            = UDim2.new(0, 52, 0, 28),
        BackgroundTransparency = 1,
        Font                = Enum.Font.Gotham,
        TextSize            = 11,
        TextColor3          = Library.Theme.TextDim,
        Text                = "@" .. userName,
        TextXAlignment      = Enum.TextXAlignment.Left,
        TextTruncate        = Enum.TextTruncate.AtEnd,
        ZIndex              = 11,
        Parent              = ProfileCard,
    })

    task.spawn(function()
        pcall(function()
            if not LocalPlayer then return end
            local thumb, ready = Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
            if ready and typeof(thumb) == "string" and thumb ~= "" then
                AvatarImg.Image = thumb
            end
        end)
    end)

    -- ── Content Area ──────────────────────────────────────────
    local ContentArea = Library:Create("Frame", {
        Name             = "ContentArea",
        Size             = UDim2.new(1, -186, 1, -54),
        Position         = UDim2.new(0, 180, 0, 49),
        BackgroundTransparency = 1,
        Parent           = MainFrame,
    })

    local Window = {Tabs = {}, ActiveTab = nil}

    -- ============================================================
    -- [8] TAB BUILDER
    -- ============================================================
    function Window:CreateTab(tabName, tabIcon)
        tabName = tabName or "Tab"

        local TabPage = Library:Create("ScrollingFrame", {
            Name                   = tabName .. "_Page",
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            ScrollBarThickness     = 4,
            ScrollBarImageColor3   = Library.Theme.StrokeLight,
            CanvasSize             = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize    = Enum.AutomaticSize.Y,
            Visible                = false,
            Parent                 = ContentArea,
        })
        Library:Create("UIListLayout", {
            Padding       = UDim.new(0, 8),
            SortOrder     = Enum.SortOrder.LayoutOrder,
            Parent        = TabPage,
        })
        Library:Create("UIPadding", {
            PaddingTop    = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 16),
            PaddingLeft   = UDim.new(0, 8),
            PaddingRight  = UDim.new(0, 12),
            Parent        = TabPage,
        })

        local TabBtn = Library:Create("TextButton", {
            Name             = tabName .. "_Btn",
            Size             = UDim2.new(1, 0, 0, 42),
            BackgroundColor3 = Color3.fromRGB(15, 15, 20),
            Font             = Enum.Font.GothamMedium,
            TextSize           = 13,
            TextColor3       = Library.Theme.TextSub,
            Text             = (tabIcon and tabIcon .. "  " or "") .. tabName,
            BorderSizePixel  = 0,
            Parent           = SideScroll,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = TabBtn})
        local tabStroke = Library:Create("UIStroke", {
            Color     = Color3.fromRGB(24, 24, 32),
            Thickness = 1,
            Parent    = TabBtn,
        })

        local tabAccent = Library:Create("Frame", {
            Size             = UDim2.new(0, 3, 0.6, 0),
            Position         = UDim2.new(0, 0, 0.2, 0),
            BackgroundColor3 = Library.Theme.Accent,
            BorderSizePixel  = 0,
            Visible          = false,
            Parent           = TabBtn,
        })
        Library:Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = tabAccent})

        local Tab = {Page = TabPage, Button = TabBtn}

        local function SelectTab()
            for _, t in ipairs(Window.Tabs) do
                t.Page.Visible = false
                Library:Tween(t.Button, {BackgroundColor3 = Color3.fromRGB(15, 15, 20)}, 0.15):Play()
                t.Button.Font = Enum.Font.GothamMedium
                t.Button.TextColor3 = Library.Theme.TextSub
                t.Button.UIStroke.Color = Color3.fromRGB(24, 24, 32)
                local acc = t.Button:FindFirstChild("Frame")
                if acc then acc.Visible = false end
            end

            TabPage.Visible = true
            Library:Tween(TabBtn, {BackgroundColor3 = Color3.fromRGB(26, 26, 36)}, 0.15):Play()
            TabBtn.Font = Enum.Font.GothamBold
            TabBtn.TextColor3 = Library.Theme.Text
            tabStroke.Color = Library.Theme.StrokeLight
            tabAccent.Visible = true
            Window.ActiveTab = Tab
        end

        TabBtn.MouseButton1Click:Connect(SelectTab)
        TabBtn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                Library:Tween(TabBtn, {BackgroundColor3 = Color3.fromRGB(20, 20, 28)}, 0.1):Play()
            end
        end)
        TabBtn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                Library:Tween(TabBtn, {BackgroundColor3 = Color3.fromRGB(15, 15, 20)}, 0.1):Play()
            end
        end)

        if #Window.Tabs == 0 then SelectTab() end
        table.insert(Window.Tabs, Tab)

        -- ============================================================
        -- [9] COMPONENT BUILDERS
        -- ============================================================
        do
            -- ── Section Header ───────────────────────────────────────
            function Tab:CreateSection(text)
                local frame = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 24),
                    BackgroundTransparency = 1,
                    Parent           = TabPage,
                })

                -- Left accent bar
                Library:Create("Frame", {
                    Size             = UDim2.new(0, 3, 0, 12),
                    Position         = UDim2.new(0, 0, 0.5, -6),
                    BackgroundColor3 = Library.Theme.Accent,
                    BorderSizePixel  = 0,
                    Parent           = frame,
                })

                Library:Create("TextLabel", {
                    Size               = UDim2.new(1, -10, 1, 0),
                    Position           = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamBold,
                    TextSize           = 13,
                    TextColor3         = Color3.fromRGB(150, 150, 165),
                    Text               = string.upper(text),
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    Parent             = frame,
                })
                return frame
            end

            -- ── Label ─────────────────────────────────────────────────
            function Tab:CreateLabel(textOrOpts)
                local text = type(textOrOpts) == "table" and (textOrOpts.Name or textOrOpts.Text or "") or tostring(textOrOpts)

                local frame = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 30),
                    BackgroundColor3 = Library.Theme.CardBg,
                    BorderSizePixel  = 0,
                    Parent           = TabPage,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = frame})
                local stroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = frame})
                Library:AddCardHover(frame, stroke)

                local lbl = Library:Create("TextLabel", {
                    Size               = UDim2.new(1, -14, 1, 0),
                    Position           = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.Gotham,
                    TextSize           = 13,
                    TextColor3         = Library.Theme.TextDim,
                    Text               = text,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    TextTruncate       = Enum.TextTruncate.AtEnd,
                    Parent             = frame,
                })

                return {
                    Set = function(v) lbl.Text = tostring(v) end,
                    GetValue = function() return lbl.Text end,
                }
            end

            -- ── Button ────────────────────────────────────────────────
            function Tab:CreateButton(options)
                options = options or {}
                local text     = options.Name or "Button"
                local callback = options.Callback or function() end
                local desc     = options.Description

                local container = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, desc and 54 or 42),
                    BackgroundTransparency = 1,
                    Parent           = TabPage,
                })

                if desc then
                    Library:Create("TextLabel", {
                        Size               = UDim2.new(1, -4, 0, 16),
                        Position           = UDim2.new(0, 2, 0, 0),
                        BackgroundTransparency = 1,
                        Font               = Enum.Font.Gotham,
                        TextSize           = 12,
                        TextColor3         = Library.Theme.TextSub,
                        Text               = desc,
                        TextXAlignment     = Enum.TextXAlignment.Left,
                        TextTruncate       = Enum.TextTruncate.AtEnd,
                        Parent             = container,
                    })
                end

                local btn = Library:Create("TextButton", {
                    Size             = desc and UDim2.new(1, 0, 0, 36) or UDim2.new(1, 0, 1, 0),
                    Position         = desc and UDim2.new(0, 0, 0, 18) or UDim2.new(0, 0, 0, 0),
                    BackgroundColor3 = Library.Theme.InputBg,
                    BorderSizePixel  = 0,
                    Font             = Enum.Font.GothamBold,
                    TextSize           = 16,
                    TextColor3       = Library.Theme.Text,
                    Text             = text,
                    Parent           = container,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = btn})
                local btnStroke = Library:Create("UIStroke", {
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Color = Library.Theme.Stroke,
                    Thickness = 1,
                    Parent = btn
                })

                local btnNormalSize = desc and UDim2.new(1, 0, 0, 36) or UDim2.new(1, 0, 1, 0)
                local btnNormalPos  = desc and UDim2.new(0, 0, 0, 18) or UDim2.new(0, 0, 0, 0)
                local btnPressSize  = desc and UDim2.new(1, -4, 0, 34) or UDim2.new(1, -4, 1, -4)
                local btnPressPos   = desc and UDim2.new(0, 2, 0, 19) or UDim2.new(0, 2, 0, 1)

                btn.MouseEnter:Connect(function()
                    Library:Tween(btn, {BackgroundColor3 = Library.Theme.Success}, 0.15):Play()
                    Library:Tween(btnStroke, {Color = Library.Theme.Accent}, 0.15):Play()
                end)
                btn.MouseLeave:Connect(function()
                    Library:Tween(btn, {BackgroundColor3 = Library.Theme.InputBg}, 0.15):Play()
                    Library:Tween(btnStroke, {Color = Library.Theme.Stroke}, 0.15):Play()
                end)
                btn.MouseButton1Down:Connect(function()
                    Library:Tween(btn, {Size = btnPressSize, Position = btnPressPos}, 0.06):Play()
                end)
                btn.MouseButton1Up:Connect(function()
                    Library:Tween(btn, {Size = btnNormalSize, Position = btnNormalPos}, 0.1):Play()
                end)
                btn.MouseButton1Click:Connect(function() pcall(callback) end)

                return {
                    Set = function(v) btn.Text = tostring(v) end,
                }
            end

            -- ── Toggle ────────────────────────────────────────────────
            function Tab:CreateToggle(options)
                options = options or {}
                local labelText = options.Name or "Toggle"
                local default   = options.Default  or false
                local flag      = options.Flag
                local callback  = options.Callback or function() end
                local desc      = options.Description

                local container = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, desc and 54 or 42),
                    BackgroundColor3 = Library.Theme.CardBg,
                    BorderSizePixel  = 0,
                    Parent           = TabPage,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = container})
                local containerStroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = container})
                Library:AddCardHover(container, containerStroke)

                if desc then
                    Library:Create("TextLabel", {
                        Size               = UDim2.new(1, -64, 0, 14),
                        Position           = UDim2.new(0, 10, 0, 4),
                        BackgroundTransparency = 1,
                        Font               = Enum.Font.Gotham,
                        TextSize           = 12,
                        TextColor3         = Library.Theme.TextSub,
                        Text               = desc,
                        TextXAlignment     = Enum.TextXAlignment.Left,
                        TextTruncate       = Enum.TextTruncate.AtEnd,
                        Parent             = container,
                    })
                end

                Library:Create("TextLabel", {
                    Size               = UDim2.new(1, -64, 0, 22),
                    Position           = UDim2.new(0, 10, 0, desc and 22 or 10),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamSemibold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.TextDim,
                    Text               = labelText,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    Parent             = container,
                })

                local switch = Library:Create("TextButton", {
                    Size             = UDim2.new(0, 44, 0, 22),
                    Position         = UDim2.new(1, -52, 0, desc and 22 or 10),
                    BackgroundColor3 = default and Library.Theme.Accent or Library.Theme.ToggleOff,
                    Text             = "",
                    BorderSizePixel  = 0,
                    Parent           = container,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 11), Parent = switch})

                local knob = Library:Create("Frame", {
                    Size             = UDim2.new(0, 18, 0, 18),
                    Position         = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel  = 0,
                    Parent           = switch,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})

                local active = default
                if flag then Library.Flags[flag] = active end

                local function SetState(state, fire)
                    active = state
                    if flag then Library.Flags[flag] = active end
                    local targetPos   = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
                    local targetColor = state and Library.Theme.Accent or Library.Theme.ToggleOff

                    Library:Tween(knob, {Size = UDim2.new(0, 14, 0, 18)}, 0.07):Play()
                    task.delay(0.07, function()
                        Library:Tween(knob, {Size = UDim2.new(0, 18, 0, 18), Position = targetPos}, 0.2, Enum.EasingStyle.Back):Play()
                    end)
                    Library:Tween(switch, {BackgroundColor3 = targetColor}, 0.2):Play()

                    if fire ~= false then pcall(callback, active) end
                end

                switch.MouseEnter:Connect(function()
                    if not active then Library:Tween(switch, {BackgroundColor3 = Color3.fromRGB(60, 60, 72)}, 0.12):Play() end
                end)
                switch.MouseLeave:Connect(function()
                    if not active then Library:Tween(switch, {BackgroundColor3 = Library.Theme.ToggleOff}, 0.12):Play() end
                end)
                switch.MouseButton1Click:Connect(function() SetState(not active, true) end)

                local elem = {
                    Set      = SetState,
                    GetValue = function() return active end,
                }
                if flag then Library.Elements[flag] = elem end
                return elem
            end

            -- ── Slider ────────────────────────────────────────────────
            function Tab:CreateSlider(options)
                options = options or {}
                local labelText = options.Name      or "Slider"
                local minVal    = options.Min       or 0
                local maxVal    = options.Max       or 100
                local default   = options.Default   or minVal
                local precision = options.Precision or 0
                local suffix    = options.Suffix    or ""
                local flag      = options.Flag
                local callback  = options.Callback  or function() end

                default = math.clamp(default, minVal, maxVal)

                local container = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 58),
                    BackgroundColor3 = Library.Theme.CardBg,
                    BorderSizePixel  = 0,
                    Parent           = TabPage,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = container})
                local containerStroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = container})
                Library:AddCardHover(container, containerStroke)

                Library:Create("TextLabel", {
                    Size               = UDim2.new(1, -80, 0, 22),
                    Position           = UDim2.new(0, 10, 0, 4),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamSemibold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.TextDim,
                    Text               = labelText,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    Parent             = container,
                })

                local valLabel = Library:Create("TextLabel", {
                    Size               = UDim2.new(0, 70, 0, 22),
                    Position           = UDim2.new(1, -78, 0, 4),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamBold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.Text,
                    Text               = tostring(default) .. suffix,
                    TextXAlignment     = Enum.TextXAlignment.Right,
                    Parent             = container,
                })

                local barBg = Library:Create("Frame", {
                    Size             = UDim2.new(1, -20, 0, 8),
                    Position         = UDim2.new(0, 10, 0, 36),
                    BackgroundColor3 = Library.Theme.InputBg,
                    BorderSizePixel  = 0,
                    Parent           = container,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = barBg})
                Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = barBg})

                local rel0 = (default - minVal) / (maxVal - minVal)
                local barFill = Library:Create("Frame", {
                    Size             = UDim2.new(rel0, 0, 1, 0),
                    BackgroundColor3 = Library.Theme.Accent,
                    BorderSizePixel  = 0,
                    Parent           = barBg,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = barFill})

                local knob = Library:Create("Frame", {
                    Size             = UDim2.new(0, 18, 0, 18),
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    Position         = UDim2.new(rel0, 0, 0.5, 0),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel  = 0,
                    ZIndex           = 3,
                    Parent           = barBg,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})

                local currentValue = default
                if flag then Library.Flags[flag] = currentValue end

                -- พื้นที่กดขยาย: โปร่งใส คลุมแนว bar (คลิก/แตะติดง่าย)
                -- อุปกรณ์สัมผัส: สูง 34px (แตะง่ายตามมาตรฐาน finger-friendly) / เมาส์ 26px
                -- Active = true: แตะลาก slider แล้วหน้าไม่ scroll ซ้อน (มือถือ) + ไม่ทะลุคลิกของเกม
                local hitH = Library.TouchEnabled and 34 or 26
                -- ชดเชย GuiInset: input.Position อยู่ space เดียวกับ AbsolutePosition เมื่อ ScreenGui ไม่ IgnoreGuiInset
                local hitZoneInset = Vector2.zero
                pcall(function()
                    local sg = container:FindFirstAncestorWhichIsA("ScreenGui")
                    if sg and not sg.IgnoreGuiInset then
                        hitZoneInset = game:GetService("GuiService"):GetGuiInset()
                    end
                end)
                local hitZone = Library:Create("Frame", {
                    Name                       = "SliderHitZone",
                    Size                       = UDim2.new(1, -20, 0, hitH),
                    Position                   = UDim2.new(0, 10, 0, 40 - hitH / 2),
                    BackgroundTransparency     = 1,
                    BorderSizePixel            = 0,
                    Active                     = true,
                    ZIndex                     = 4,
                    Parent                     = container,
                })

                -- Apply relX -> UI + flag + callback (ตัวเดียวจบ ใช้ทั้ง drag และ Set)
                local function ApplySlider(relX)
                    relX = math.clamp(relX, 0, 1)
                    local raw  = minVal + (maxVal - minVal) * relX
                    local mult = 10 ^ precision
                    currentValue = math.floor(raw * mult + 0.5) / mult

                    barFill.Size     = UDim2.new(relX, 0, 1, 0)
                    knob.Position    = UDim2.new(relX, 0, 0.5, 0)
                    valLabel.Text    = tostring(currentValue) .. suffix
                    if flag then Library.Flags[flag] = currentValue end
                    pcall(callback, currentValue)
                end

                -- แปลงตำแหน่ง input (screen space) -> relX ของแถบ
                -- pos เป็น Vector3 (input.Position) — หัก GuiInset (Vector2) แยกแกน X ข้างในนี้
                local function PosToRel(pos)
                    local sizeX = barBg.AbsoluteSize.X
                    if sizeX <= 0 then return nil end
                    return math.clamp((pos.X - hitZoneInset.X - barBg.AbsolutePosition.X) / sizeX, 0, 1)
                end

                local dragging = false
                local targetRel = nil -- ค่าเป้าหมาย (นิ้ว/เมาส์อยู่ตรงไหน)
                hitZone.InputBegan:Connect(function(i, processed)
                    if processed then return end
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        Library:Tween(knob, {Size = UDim2.new(0, 22, 0, 22)}, 0.08):Play()
                        local rel = PosToRel(i.Position)
                        if rel then
                            targetRel = rel
                            ApplySlider(rel) -- ตอนเพิ่งกด: กระโดดทันที (ตอบสนองเร็ว)
                        end
                    end
                end)

                -- Chase easing loop (แบบ Rayfield): ค่าไหลตามนิ้ว/เมาส์แบบ smooth
                -- ลดอาการกระตุกเวลาลากเร็วบนมือถือ และค่า callback ไม่สั่น
                Library:Connect(RunService.RenderStepped, function()
                    if not dragging or targetRel == nil then return end
                    local curRel = (currentValue - minVal) / (maxVal - minVal)
                    local eased  = curRel + (targetRel - curRel) * 0.35 -- lerp 35%/เฟรม
                    if math.abs(targetRel - eased) < 0.002 then
                        eased = targetRel -- ถึงเป้าแล้ว: ล็อกตรง (กันสั่นน้อยๆ ไม่จบ)
                    end
                    ApplySlider(eased)
                end)

                Library:Connect(UserInputService.InputChanged, function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        local rel = PosToRel(i.Position)
                        if rel then targetRel = rel end
                    end
                end)
                Library:Connect(UserInputService.InputEnded, function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        if dragging and targetRel ~= nil then
                            ApplySlider(targetRel) -- ปล่อย: ล็อกค่าเป้าหมายเป๊ะ
                        end
                        dragging = false
                        targetRel = nil
                        Library:Tween(knob, {Size = UDim2.new(0, 18, 0, 18)}, 0.08):Play()
                    end
                end)

                local elem = {
                    Set = function(v)
                        v = math.clamp(v, minVal, maxVal)
                        ApplySlider((v - minVal) / (maxVal - minVal))
                    end,
                    GetValue = function() return currentValue end,
                }
                if flag then Library.Elements[flag] = elem end
                return elem
            end

            -- ── Dropdown ──────────────────────────────────────────────
            function Tab:CreateDropdown(options)
                options = options or {}
                local labelText = options.Name     or "Dropdown"
                local optList   = options.Options  or {}
                local default   = options.Default  or optList[1] or ""
                local flag      = options.Flag
                local callback  = options.Callback or function() end
                local maxHeight = options.MaxHeight or 160

                local container = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 44),
                    BackgroundTransparency = 1,
                    ClipsDescendants = false,
                    ZIndex           = 10,
                    Parent           = TabPage,
                })

                local mainBg = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 42),
                    BackgroundColor3 = Library.Theme.InputBg,
                    BorderSizePixel  = 0,
                    ZIndex           = 10,
                    Parent           = container,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = mainBg})
                local ddStroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = mainBg})

                Library:Create("TextLabel", {
                    Size               = UDim2.new(0.45, 0, 1, 0),
                    Position           = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamSemibold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.TextDim,
                    Text               = labelText,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    ZIndex             = 11,
                    Parent             = mainBg,
                })

                local selectedLbl = Library:Create("TextLabel", {
                    Size               = UDim2.new(0.5, -24, 1, 0),
                    Position           = UDim2.new(0.45, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamBold,
                    TextSize           = 13,
                    TextColor3         = Library.Theme.Accent,
                    Text               = tostring(default),
                    TextXAlignment     = Enum.TextXAlignment.Right,
                    TextTruncate       = Enum.TextTruncate.AtEnd,
                    ZIndex             = 11,
                    Parent             = mainBg,
                })

                local arrow = Library:Create("TextLabel", {
                    Size               = UDim2.new(0, 22, 1, 0),
                    Position           = UDim2.new(1, -24, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamBold,
                    TextSize           = 13,
                    TextColor3         = Library.Theme.TextSub,
                    Text               = "▼",
                    ZIndex             = 11,
                    Parent             = mainBg,
                })

                local listPanel = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 0),
                    Position         = UDim2.new(0, 0, 0, 46),
                    BackgroundColor3 = Library.Theme.DropdownBg,
                    BorderSizePixel  = 0,
                    ClipsDescendants = true,
                    ZIndex           = 20,
                    Visible          = false,
                    Parent           = container,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = listPanel})
                Library:Create("UIStroke", {Color = Library.Theme.StrokeLight, Thickness = 1, Parent = listPanel})

                local listScroll = Library:Create("ScrollingFrame", {
                    Size                   = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    ScrollBarThickness     = 3,
                    ScrollBarImageColor3   = Library.Theme.StrokeLight,
                    CanvasSize             = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize    = Enum.AutomaticSize.Y,
                    ZIndex                 = 20,
                    Parent                 = listPanel,
                })
                Library:Create("UIListLayout", {
                    Padding   = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent    = listScroll,
                })
                Library:Create("UIPadding", {
                    PaddingTop    = UDim.new(0, 8),
                    PaddingBottom = UDim.new(0, 4),
                    PaddingLeft   = UDim.new(0, 8),
                    PaddingRight  = UDim.new(0, 4),
                    Parent        = listScroll,
                })

                local open     = false
                local selected = default
                if flag then Library.Flags[flag] = selected end

                local function CloseDropdown()
                    open = false
                    arrow.Text = "▼"
                    Library:Tween(ddStroke, {Color = Library.Theme.Stroke}, 0.15):Play()
                    Library:Tween(listPanel, {Size = UDim2.new(1, 0, 0, 0)}, 0.2, Enum.EasingStyle.Quart):Play()
                    Library:Tween(container, {Size = UDim2.new(1, 0, 0, 44)}, 0.2, Enum.EasingStyle.Quart):Play()
                    task.delay(0.22, function() listPanel.Visible = false end)
                end

                local function PopulateOptions(list)
                    for _, c in ipairs(listScroll:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end

                    for _, opt in ipairs(list) do
                        local isSel = (opt == selected)
                        local item = Library:Create("TextButton", {
                            Size             = UDim2.new(1, 0, 0, 36),
                            BackgroundColor3 = isSel and Library.Theme.AccentDark or Color3.fromRGB(22, 22, 30),
                            Text             = "",
                            BorderSizePixel  = 0,
                            ZIndex           = 21,
                            Parent           = listScroll,
                        })
                        Library:Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = item})

                        Library:Create("TextLabel", {
                            Size               = UDim2.new(1, -34, 1, 0),
                            Position           = UDim2.new(0, 10, 0, 0),
                            BackgroundTransparency = 1,
                            Font               = isSel and Enum.Font.GothamBold or Enum.Font.Gotham,
                            TextSize           = 13,
                            TextColor3         = isSel and Library.Theme.Text or Library.Theme.TextDim,
                            Text               = tostring(opt),
                            TextXAlignment     = Enum.TextXAlignment.Left,
                            ZIndex             = 22,
                            Parent             = item,
                        })

                        if isSel then
                            Library:Create("TextLabel", {
                                Size               = UDim2.new(0, 22, 1, 0),
                                Position           = UDim2.new(1, -24, 0, 0),
                                BackgroundTransparency = 1,
                                Font               = Enum.Font.GothamBold,
                                TextSize           = 16,
                                TextColor3         = Library.Theme.Text,
                                Text               = "✓",
                                ZIndex             = 22,
                                Parent             = item,
                            })
                        end

                        item.MouseEnter:Connect(function()
                            if opt ~= selected then
                                Library:Tween(item, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}, 0.1):Play()
                            end
                        end)
                        item.MouseLeave:Connect(function()
                            if opt ~= selected then
                                Library:Tween(item, {BackgroundColor3 = Color3.fromRGB(22, 22, 30)}, 0.1):Play()
                            end
                        end)

                        item.MouseButton1Click:Connect(function()
                            selected = opt
                            selectedLbl.Text = tostring(selected)
                            if flag then Library.Flags[flag] = selected end
                            PopulateOptions(list)
                            CloseDropdown()
                            pcall(callback, selected)
                        end)
                    end

                    local itemH = math.min(#list * 38 + 8, maxHeight)
                    listPanel.Size = UDim2.new(1, 0, 0, open and itemH or 0)
                end

                PopulateOptions(optList)

                mainBg.InputBegan:Connect(function(i)
                    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    open = not open
                    arrow.Text = open and "▲" or "▼"
                    Library:Tween(ddStroke, {Color = open and Library.Theme.Accent or Library.Theme.Stroke}, 0.15):Play()

                    if open then
                        listPanel.Visible = true
                        local targetH = math.min(#optList * 38 + 8, maxHeight)
                        listPanel.Size = UDim2.new(1, 0, 0, 0)
                        Library:Tween(listPanel, {Size = UDim2.new(1, 0, 0, targetH)}, 0.25, Enum.EasingStyle.Quart):Play()
                        Library:Tween(container, {Size = UDim2.new(1, 0, 0, 44 + targetH + 4)}, 0.25, Enum.EasingStyle.Quart):Play()
                    else
                        CloseDropdown()
                    end
                end)

                local elem = {
                    Set = function(v)
                        selected = v
                        selectedLbl.Text = tostring(selected)
                        if flag then Library.Flags[flag] = selected end
                        PopulateOptions(optList)
                        pcall(callback, selected)
                    end,
                    Refresh = function(newList)
                        optList = newList or {}
                        selected = optList[1] or ""
                        selectedLbl.Text = tostring(selected)
                        if flag then Library.Flags[flag] = selected end
                        CloseDropdown()
                        PopulateOptions(optList)
                        if selected ~= "" and selected ~= "No macros found" then
                            pcall(callback, selected)
                        end
                    end,
                    GetValue = function() return selected end,
                }
                if flag then Library.Elements[flag] = elem end
                return elem
            end

            -- ── Input ─────────────────────────────────────────────────
            function Tab:CreateInput(options)
                options = options or {}
                local labelText  = options.Name        or "Input"
                local default    = options.Default     or ""
                local placeholder = options.Placeholder or "Type here..."
                local numeric    = options.Numeric     or false
                local flag       = options.Flag
                local callback   = options.Callback    or function() end

                local container = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 42),
                    BackgroundColor3 = Library.Theme.CardBg,
                    BorderSizePixel  = 0,
                    ClipsDescendants = true,
                    Parent           = TabPage,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = container})
                local containerStroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = container})
                Library:AddCardHover(container, containerStroke)

                Library:Create("TextLabel", {
                    Size               = UDim2.new(0, 110, 1, 0),
                    Position           = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamSemibold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.TextDim,
                    Text               = labelText,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    TextTruncate       = Enum.TextTruncate.AtEnd,
                    Parent             = container,
                })

                -- กล่องคลิปข้อความยาว (กันล้นทับ label)
                local boxWrap = Library:Create("Frame", {
                    Size             = UDim2.new(1, -130, 0, 26),
                    Position         = UDim2.new(0, 122, 0.5, -13),
                    BackgroundColor3 = Library.Theme.InputBg,
                    BorderSizePixel  = 0,
                    ClipsDescendants = true,
                    Parent           = container,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = boxWrap})
                local inputStroke = Library:Create("UIStroke", {
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Color           = Library.Theme.Stroke,
                    Thickness       = 1,
                    Parent          = boxWrap,
                })

                local box = Library:Create("TextBox", {
                    Size                   = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Font                   = Enum.Font.Gotham,
                    TextSize               = 13,
                    TextColor3             = Library.Theme.Text,
                    PlaceholderColor3      = Color3.fromRGB(90, 90, 100),
                    PlaceholderText        = placeholder,
                    Text                   = tostring(default),
                    ClearTextOnFocus       = false,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    TextTruncate           = Enum.TextTruncate.AtEnd,
                    ClipsDescendants       = true,
                    Parent                 = boxWrap,
                })
                Library:Create("UIPadding", {
                    PaddingLeft  = UDim.new(0, 8),
                    PaddingRight = UDim.new(0, 8),
                    Parent       = box,
                })

                if numeric then
                    box:GetPropertyChangedSignal("Text"):Connect(function()
                        local filtered = box.Text:gsub("[^%d%.%-]", "")
                        if filtered ~= box.Text then box.Text = filtered end
                    end)
                end

                box.Focused:Connect(function()
                    Library:Tween(inputStroke, {Color = Library.Theme.Accent, Thickness = 1.5}, 0.15):Play()
                end)
                box.FocusLost:Connect(function()
                    Library:Tween(inputStroke, {Color = Library.Theme.Stroke, Thickness = 1}, 0.15):Play()
                    local v = numeric and tonumber(box.Text) or box.Text
                    if flag then Library.Flags[flag] = v end
                    pcall(callback, v)
                end)

                if flag then Library.Flags[flag] = default end

                local elem = {
                    Set = function(v)
                        box.Text = tostring(v)
                        local val = numeric and (tonumber(v) or v) or v
                        if flag then Library.Flags[flag] = val end
                        pcall(callback, val)
                    end,
                    GetValue = function() return numeric and (tonumber(box.Text) or box.Text) or box.Text end,
                }
                if flag then Library.Elements[flag] = elem end
                return elem
            end

            -- ── Number Adjuster (Minus Left, Value Center, Plus Right) ──
            function Tab:CreateNumberAdjust(options)
                options = options or {}
                local labelText = options.Name     or "Adjuster"
                local default   = options.Default  or 1
                local minVal    = options.Min      or 1
                local maxVal    = options.Max      or 100
                local step      = options.Step     or 1
                local flag      = options.Flag
                local callback  = options.Callback or function() end

                local container = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 42),
                    BackgroundColor3 = Library.Theme.CardBg,
                    BorderSizePixel  = 0,
                    Parent           = TabPage,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = container})
                local containerStroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = container})
                Library:AddCardHover(container, containerStroke)

                Library:Create("TextLabel", {
                    Size               = UDim2.new(1, -125, 1, 0),
                    Position           = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamSemibold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.TextDim,
                    Text               = labelText,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    Parent             = container,
                })

                local val = math.clamp(default, minVal, maxVal)
                if flag then Library.Flags[flag] = val end

                -- Control box containing [ - ] [ Value ] [ + ]
                local ctrlFrame = Library:Create("Frame", {
                    Size             = UDim2.new(0, 106, 0, 26),
                    Position         = UDim2.new(1, -112, 0.5, -13),
                    BackgroundTransparency = 1,
                    Parent           = container,
                })

                local valLbl = Library:Create("TextLabel", {
                    Size               = UDim2.new(0, 54, 1, 0),
                    Position           = UDim2.new(0, 26, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamBold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.Text,
                    Text               = tostring(val),
                    TextXAlignment     = Enum.TextXAlignment.Center,
                    Parent             = ctrlFrame,
                })

                local function Update(newVal)
                    val = math.clamp(newVal, minVal, maxVal)
                    valLbl.Text = tostring(val)
                    if flag then Library.Flags[flag] = val end
                    pcall(callback, val)
                end

                local function MakeBtn(txt, pos, delta)
                    local btn = Library:Create("TextButton", {
                        Size             = UDim2.new(0, 26, 1, 0),
                        Position         = pos,
                        BackgroundColor3 = Library.Theme.InputBg,
                        Font             = Enum.Font.GothamBold,
                        TextSize           = 16,
                        TextColor3       = Library.Theme.Text,
                        Text             = txt,
                        BorderSizePixel  = 0,
                        Parent           = ctrlFrame,
                    })
                    Library:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = btn})
                    Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = btn})

                    btn.MouseButton1Down:Connect(function()
                        Library:Tween(btn, {BackgroundColor3 = Library.Theme.AccentDark}, 0.06):Play()
                    end)
                    local function resetColor()
                        Library:Tween(btn, {BackgroundColor3 = Library.Theme.InputBg}, 0.12):Play()
                    end
                    btn.MouseButton1Up:Connect(resetColor)
                    btn.MouseLeave:Connect(resetColor)

                    btn.MouseButton1Click:Connect(function() Update(val + delta) end)

                    local holding = false
                    btn.MouseButton1Down:Connect(function()
                        holding = true
                        task.delay(0.5, function()
                            while holding do
                                Update(val + delta)
                                task.wait(0.09)
                            end
                        end)
                    end)
                    btn.MouseButton1Up:Connect(function() holding = false end)
                    btn.MouseLeave:Connect(function() holding = false end)
                end

                MakeBtn("−", UDim2.new(0, 0, 0, 0), -step)
                MakeBtn("+", UDim2.new(0, 80, 0, 0), step)

                local elem = {
                    Set      = function(v) Update(v) end,
                    GetValue = function() return val end,
                }
                if flag then Library.Elements[flag] = elem end
                return elem
            end

            -- ── Keybind ───────────────────────────────────────────────
            function Tab:CreateKeybind(options)
                options = options or {}
                local labelText = options.Name     or "Keybind"
                local default   = options.Default  or Enum.KeyCode.Unknown
                local flag      = options.Flag
                local callback  = options.Callback or function() end

                local container = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 42),
                    BackgroundColor3 = Library.Theme.CardBg,
                    BorderSizePixel  = 0,
                    Parent           = TabPage,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = container})
                local containerStroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = container})
                Library:AddCardHover(container, containerStroke)

                Library:Create("TextLabel", {
                    Size               = UDim2.new(1, -120, 1, 0),
                    Position           = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamSemibold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.TextDim,
                    Text               = labelText,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    Parent             = container,
                })

                local currentKey = default
                if flag then Library.Flags[flag] = currentKey end

                local kbStroke = Library:Create("UIStroke", {
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Color = Library.Theme.Stroke, 
                    Thickness = 1
                })
                local keyBtn = Library:Create("TextButton", {
                    Size             = UDim2.new(0, 100, 0, 24),
                    Position         = UDim2.new(1, -108, 0.5, -12),
                    BackgroundColor3 = Library.Theme.InputBg,
                    Font             = Enum.Font.GothamBold,
                    TextSize           = 13,
                    TextColor3       = Library.Theme.Accent,
                    Text             = "[" .. currentKey.Name .. "]",
                    BorderSizePixel  = 0,
                    Parent           = container,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = keyBtn})
                kbStroke.Parent = keyBtn

                local binding = false

                keyBtn.MouseButton1Click:Connect(function()
                    binding = true
                    keyBtn.Text = "[ ... ]"
                    keyBtn.TextColor3 = Color3.fromRGB(255, 210, 50)
                    Library:Tween(kbStroke, {Color = Color3.fromRGB(255, 210, 50)}, 0.15):Play()
                end)

                Library:Connect(UserInputService.InputBegan, function(input, gp)
                    if binding then
                        if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                            binding = false
                            currentKey = Enum.KeyCode.Unknown
                            keyBtn.Text = "[None]"
                            keyBtn.TextColor3 = Library.Theme.Accent
                            Library:Tween(kbStroke, {Color = Library.Theme.Stroke}, 0.15):Play()
                            if flag then Library.Flags[flag] = currentKey end
                        elseif input.UserInputType == Enum.UserInputType.Keyboard then
                            binding = false
                            currentKey = input.KeyCode
                            keyBtn.Text = "[" .. currentKey.Name .. "]"
                            keyBtn.TextColor3 = Library.Theme.Accent
                            Library:Tween(kbStroke, {Color = Library.Theme.Stroke}, 0.15):Play()
                            if flag then Library.Flags[flag] = currentKey end
                        end
                    elseif not gp and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey and currentKey ~= Enum.KeyCode.Unknown then
                        pcall(callback, currentKey)
                    end
                end)

                local elem = {
                    Set = function(k)
                        currentKey = k
                        keyBtn.Text = "[" .. currentKey.Name .. "]"
                        if flag then Library.Flags[flag] = currentKey end
                    end,
                    GetValue = function() return currentKey end,
                }
                if flag then Library.Elements[flag] = elem end
                return elem
            end

            -- ── Color Picker (2D Saturation/Value Canvas + Rainbow Hue Slider) ──
            function Tab:CreateColorPicker(options)
                options = options or {}
                local labelText   = options.Name     or "Color Picker"
                local default     = options.Default  or Color3.fromRGB(255, 60, 60)
                local flag        = options.Flag
                local callback    = options.Callback or function() end

                local h, s, v     = default:ToHSV()

                local container = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 42),
                    BackgroundColor3 = Library.Theme.CardBg,
                    BorderSizePixel  = 0,
                    ClipsDescendants = true,
                    Parent           = TabPage,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = container})
                local containerStroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = container})
                Library:AddCardHover(container, containerStroke)

                Library:Create("TextLabel", {
                    Size               = UDim2.new(1, -60, 0, 34),
                    Position           = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamSemibold,
                    TextSize           = 16,
                    TextColor3         = Library.Theme.TextDim,
                    Text               = labelText,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    Parent             = container,
                })

                -- Preview swatch + expand button
                local swatch = Library:Create("TextButton", {
                    Size             = UDim2.new(0, 38, 0, 22),
                    Position         = UDim2.new(1, -46, 0, 6),
                    BackgroundColor3 = default,
                    Text             = "",
                    BorderSizePixel  = 0,
                    Parent           = container,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = swatch})
                Library:Create("UIStroke", {Color = Library.Theme.StrokeLight, Thickness = 1, Parent = swatch})

                -- 2D Color Picker Panel (Expandable) — อยู่ใต้ header + ซ่อนตอนหุบ กันโผล่ขอบ
                local COLLAPSED_H = 42
                local EXPANDED_H  = 180
                local panel = Library:Create("Frame", {
                    Size             = UDim2.new(1, -20, 0, 130),
                    Position         = UDim2.new(0, 10, 0, COLLAPSED_H),
                    BackgroundTransparency = 1,
                    Visible          = false,
                    Parent           = container,
                })

                -- 2D Saturation / Value Box
                local svFrame = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 100),
                    Position         = UDim2.new(0, 0, 0, 0),
                    BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                    BorderSizePixel  = 0,
                    Parent           = panel,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = svFrame})

                -- White gradient (Saturation: Left White -> Right Transparent)
                local satGrad = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel  = 0,
                    Parent           = svFrame,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = satGrad})
                Library:Create("UIGradient", {
                    Transparency = NumberSequence.new{
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1)
                    },
                    Parent = satGrad,
                })

                -- Black gradient (Value: Top Transparent -> Bottom Black)
                local valGrad = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel  = 0,
                    Parent           = svFrame,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = valGrad})
                Library:Create("UIGradient", {
                    Rotation     = 90,
                    Transparency = NumberSequence.new{
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0)
                    },
                    Parent = valGrad,
                })

                -- 2D Picker RingCursor
                local pickerRing = Library:Create("Frame", {
                    Size             = UDim2.new(0, 12, 0, 12),
                    Position         = UDim2.new(s, -6, 1 - v, -6),
                    BackgroundTransparency = 1,
                    ZIndex           = 3,
                    Parent           = svFrame,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = pickerRing})
                Library:Create("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Parent = pickerRing})

                -- Rainbow Hue Slider Bar
                local hueFrame = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 14),
                    Position         = UDim2.new(0, 0, 0, 108),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel  = 0,
                    Parent           = panel,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = hueFrame})
                Library:Create("UIGradient", {
                    Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0,     Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.5,   Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1,     Color3.fromRGB(255, 0, 0))
                    },
                    Parent = hueFrame,
                })

                -- Hue Slider Knob
                local hueKnob = Library:Create("Frame", {
                    Size             = UDim2.new(0, 10, 0, 18),
                    Position         = UDim2.new(h, -5, 0.5, -9),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel  = 0,
                    ZIndex           = 3,
                    Parent           = hueFrame,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = hueKnob})
                Library:Create("UIStroke", {Color = Color3.fromRGB(30, 30, 40), Thickness = 1, Parent = hueKnob})

                local currentColor = default
                if flag then Library.Flags[flag] = currentColor end

                local function UpdateColor()
                    currentColor = Color3.fromHSV(h, s, v)
                    swatch.BackgroundColor3 = currentColor
                    svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    if flag then Library.Flags[flag] = currentColor end
                    pcall(callback, currentColor)
                end

                -- Drag 2D SV Box
                local svDragging = false
                local function UpdateSV(pos)
                    local relX = math.clamp((pos.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
                    local relY = math.clamp((pos.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
                    s = relX
                    v = 1 - relY
                    pickerRing.Position = UDim2.new(s, -6, 1 - v, -6)
                    UpdateColor()
                end

                svFrame.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        svDragging = true
                        UpdateSV(i.Position)
                    end
                end)
                Library:Connect(UserInputService.InputChanged, function(i)
                    if svDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        UpdateSV(i.Position)
                    end
                end)
                Library:Connect(UserInputService.InputEnded, function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        svDragging = false
                    end
                end)

                -- Drag Hue Slider
                local hueDragging = false
                local function UpdateHue(pos)
                    local relX = math.clamp((pos.X - hueFrame.AbsolutePosition.X) / hueFrame.AbsoluteSize.X, 0, 1)
                    h = relX
                    hueKnob.Position = UDim2.new(h, -5, 0.5, -9)
                    UpdateColor()
                end

                hueFrame.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        hueDragging = true
                        UpdateHue(i.Position)
                    end
                end)
                Library:Connect(UserInputService.InputChanged, function(i)
                    if hueDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        UpdateHue(i.Position)
                    end
                end)
                Library:Connect(UserInputService.InputEnded, function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        hueDragging = false
                    end
                end)

                local expanded = false
                swatch.MouseButton1Click:Connect(function()
                    expanded = not expanded
                    panel.Visible = expanded
                    local targetH = expanded and EXPANDED_H or COLLAPSED_H
                    Library:Tween(container, {Size = UDim2.new(1, 0, 0, targetH)}, 0.25, Enum.EasingStyle.Quart):Play()
                end)

                local elem = {
                    Set = function(col)
                        h, s, v = col:ToHSV()
                        pickerRing.Position = UDim2.new(s, -6, 1 - v, -6)
                        hueKnob.Position    = UDim2.new(h, -5, 0.5, -9)
                        UpdateColor()
                    end,
                    GetValue = function() return currentColor end,
                }
                if flag then Library.Elements[flag] = elem end
                return elem
            end

            -- ── Paragraph ─────────────────────────────────────────────
            function Tab:CreateParagraph(options)
                options = options or {}
                local title   = options.Title   or "Info"
                local content = options.Content or ""

                local frame = Library:Create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 0),
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Library.Theme.CardBg,
                    BorderSizePixel  = 0,
                    ClipsDescendants = false,
                    Parent           = TabPage,
                })
                Library:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = frame})
                local stroke = Library:Create("UIStroke", {Color = Library.Theme.Stroke, Thickness = 1, Parent = frame})
                Library:AddCardHover(frame, stroke)
                Library:Create("UIPadding", {
                    PaddingTop    = UDim.new(0, 8),
                    PaddingBottom = UDim.new(0, 8),
                    PaddingLeft   = UDim.new(0, 10),
                    PaddingRight  = UDim.new(0, 12),
                    Parent        = frame,
                })
                Library:Create("UIListLayout", {
                    Padding   = UDim.new(0, 8),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent    = frame,
                })

                Library:Create("TextLabel", {
                    Size               = UDim2.new(1, 0, 0, 16),
                    AutomaticSize      = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.GothamBold,
                    TextSize           = 15,
                    TextColor3         = Library.Theme.Text,
                    Text               = title,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    TextWrapped        = true,
                    TextStrokeTransparency = 1,
                    Parent             = frame,
                })

                local descLbl = Library:Create("TextLabel", {
                    Size               = UDim2.new(1, 0, 0, 0),
                    AutomaticSize      = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Font               = Enum.Font.Gotham,
                    TextSize           = 13,
                    LineHeight         = 1.45,
                    TextColor3         = Library.Theme.TextSub,
                    Text               = content,
                    TextWrapped        = true,
                    TextXAlignment     = Enum.TextXAlignment.Left,
                    TextYAlignment     = Enum.TextYAlignment.Top,
                    TextStrokeTransparency = 1,
                    Parent             = frame,
                })

                return {
                    Set = function(newContent) descLbl.Text = tostring(newContent) end,
                    SetTitle = function(newTitle)
                        local titleLbl = frame:FindFirstChildWhichIsA("TextLabel")
                        if titleLbl then titleLbl.Text = newTitle end
                    end,
                }
            end
        end -- do

        return Tab
    end -- CreateTab

    return Window
end -- CreateWindow

-- ============================================================
-- [10] DESTROY / CLEANUP
-- ============================================================
function Library:Destroy()
    if Library.Unloaded then
        return
    end
    Library.Unloaded = true

    for _, conn in ipairs(Library.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Library.Connections = {}
    Library.Flags = {}
    Library.Elements = {}

    -- เก็บกวาด touch connections เพิ่มเติม (แยกจาก Library.Connections)
    if Library._touchConns then
        for _, c in ipairs(Library._touchConns) do
            pcall(function() c:Disconnect() end)
        end
        Library._touchConns = nil
    end

    if Library.ScreenGui then
        pcall(function() Library.ScreenGui:Destroy() end)
        Library.ScreenGui = nil
    end
    Library.MainFrame = nil
    Library.OpenBtn = nil

    -- ลบซ้ำเผื่อ parent เปลี่ยน / ชื่อชน
    pcall(function()
        local cg = CoreGui:FindFirstChild(UI_NAME)
        if cg then cg:Destroy() end
    end)
    pcall(function()
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            local pg = LocalPlayer.PlayerGui:FindFirstChild(UI_NAME)
            if pg then pg:Destroy() end
        end
    end)

    if typeof(getgenv) == "function" and getgenv()[ENV_KEY] == Library then
        getgenv()[ENV_KEY] = nil
    end
end

if typeof(getgenv) == "function" then
    getgenv()[ENV_KEY] = Library
end

return Library
