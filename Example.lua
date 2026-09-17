--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  UI TEST LAB v2 — จำลองระบบทั้งหมดของ Library                ║
    ║  โหลด Library จาก GitHub: armkkk123/TEST (Library.lua)       ║
    ║  ทดสอบ: Toggle / Slider / Dropdown / Input / NumberAdjust    ║
    ║         Keybind / ColorPicker / Button / Notify / Theme      ║
    ║         Config Save-Load / Responsive UIScale                ║
    ╚══════════════════════════════════════════════════════════════╝

    ทดสอบ Responsive: ย่อ/ขยายหน้าต่าง Roblox หรือหมุนจอมือถือ
    — UI ต้องย่อ/ขยายสมส่วนภายใน ~0.3 วิ (Heartbeat polling)
]]

local LIB_URL = "https://raw.githubusercontent.com/armkkk123/TEST/refs/heads/main/Library.lua"

local ok, Library = pcall(function()
    return loadstring(game:HttpGet(LIB_URL))()
end)
if not ok or type(Library) ~= "table" or not Library.CreateWindow then
    warn("[TEST LAB] โหลด Library จาก GitHub ล้มเหลว: " .. tostring(Library))
    return
end

-- ============================================================
-- สร้างหน้าต่างทดสอบ
-- ============================================================
local Window = Library:CreateWindow({
    Title      = "UI TEST LAB v2.3",
    ToggleIcon = "rbxassetid://101260008442128",
})

-- ============================================================
-- TAB 1: CONTROLS — องค์ประกอบครบทุกชนิด
-- ============================================================
local TabCtl = Window:CreateTab("Controls")

TabCtl:CreateSection("Basic Elements")

TabCtl:CreateParagraph({
    Title   = "Test Lab Info",
    Content = "Library: GitHub (armkkk123/TEST) เวอร์ชันล่าสุด"
        .. "\nทดสอบ Responsive: ย่อ/ขยายหน้าต่าง Roblox หรือหมุนจอมือถือ"
        .. "\nทุก callback จะพิมพ์ผลลัพธ์ใน 'Live Output' ด้านล่าง",
})

TabCtl:CreateLabel("This is a Label (CreateLabel)")

TabCtl:CreateButton({
    Name        = "Test Button",
    Description = "กดแล้วยิง Notification + อัปเดต Live Output",
    Callback    = function()
        Library:Notify({
            Title    = "Button Clicked",
            Content  = "ปุ่มทำงานปกติ ✔",
            Duration = 2,
        })
        PrintLog("Button: clicked")
    end,
})

TabCtl:CreateToggle({
    Name     = "Test Toggle (Auto Farm Simulation)",
    Default  = false,
    Flag     = "Test_Toggle",
    Callback = function(state)
        PrintLog("Toggle: " .. tostring(state))
    end,
})

TabCtl:CreateSection("Slider — ทดสอบความแม่น")

TabCtl:CreateSlider({
    Name      = "Slider Integer (0-100)",
    Min       = 0,
    Max       = 100,
    Default   = 50,
    Precision = 0,
    Flag      = "Test_SliderInt",
    Callback  = function(v)
        PrintLog("SliderInt: " .. tostring(v))
    end,
})

TabCtl:CreateSlider({
    Name      = "Slider Decimal (0-1, step 0.05)",
    Min       = 0,
    Max       = 1,
    Default   = 0.5,
    Precision = 2,
    Flag      = "Test_SliderDec",
    Callback  = function(v)
        PrintLog("SliderDec: " .. string.format("%.2f", v))
    end,
})

TabCtl:CreateSlider({
    Name      = "Walk Speed Simulation (16-200)",
    Min       = 16,
    Max       = 200,
    Default   = 16,
    Precision = 0,
    Suffix    = " WS",
    Flag      = "Test_SliderWS",
    Callback  = function(v)
        PrintLog("WalkSpeed: " .. tostring(v))
    end,
})

TabCtl:CreateSection("Input / Dropdown / Number")

TabCtl:CreateInput({
    Name        = "Test Input",
    Default     = "",
    Placeholder = "พิมพ์อะไรก็ได้...",
    Flag        = "Test_Input",
    Callback    = function(text)
        PrintLog("Input: " .. tostring(text))
    end,
})

local TestDropdown = TabCtl:CreateDropdown({
    Name     = "Test Dropdown",
    Options  = { "Option A", "Option B", "Option C" },
    Default  = "Option A",
    Flag     = "Test_Dropdown",
    Callback = function(selected)
        PrintLog("Dropdown: " .. tostring(selected))
    end,
})

TabCtl:CreateButton({
    Name     = "Dropdown.Refresh (เปลี่ยนตัวเลือกสด)",
    Callback = function()
        TestDropdown.Refresh({ "New X", "New Y", "New Z" })
        PrintLog("Dropdown refreshed -> New X/Y/Z")
    end,
})

TabCtl:CreateNumberAdjust({
    Name     = "Test Number Adjust (1-10)",
    Default  = 1,
    Min      = 1,
    Max      = 10,
    Flag     = "Test_NumberAdjust",
    Callback = function(v)
        PrintLog("NumberAdjust: " .. tostring(v))
    end,
})

TabCtl:CreateSection("Keybind / ColorPicker")

TabCtl:CreateKeybind({
    Name     = "Test Keybind",
    Default  = Enum.KeyCode.E,
    Flag     = "Test_Keybind",
    Callback = function(key)
        PrintLog("Keybind: " .. tostring(key and key.Name or "?"))
    end,
})

TabCtl:CreateColorPicker({
    Name     = "Test Color Picker",
    Default  = Color3.fromRGB(0, 170, 255),
    Flag     = "Test_Color",
    Callback = function(color)
        PrintLog(string.format("Color: RGB(%d, %d, %d)",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5)))
    end,
})

TabCtl:CreateSection("Live Output (จากทุก callback)")

local LiveOut = TabCtl:CreateParagraph({
    Title   = "Live Output",
    Content = "ยังไม่มี event — เริ่มกด/ลาก element ดูได้เลย",
})

local logLines = {}
function PrintLog(msg)
    table.insert(logLines, os.date("%H:%M:%S") .. "  " .. tostring(msg))
    while #logLines > 6 do
        table.remove(logLines, 1)
    end
    LiveOut.Set(table.concat(logLines, "\n"))
end

-- ============================================================
-- TAB 2: API TEST — .Set / Theme / Config / Notify / Responsive
-- ============================================================
local TabApi = Window:CreateTab("API Test")

TabApi:CreateSection("Runtime .Set() Calls (dot API)")

TabApi:CreateButton({
    Name     = "Toggle.Set(true) — บังคับเปิดจากโค้ด",
    Callback = function()
        local el = Library.Elements["Test_Toggle"]
        if el and el.Set then el.Set(true) PrintLog("API: Toggle.Set(true) OK") end
    end,
})

TabApi:CreateButton({
    Name     = "SliderInt.Set(75) — บังคับค่าจากโค้ด",
    Callback = function()
        local el = Library.Elements["Test_SliderInt"]
        if el and el.Set then el.Set(75) PrintLog("API: Slider.Set(75) OK") end
    end,
})

TabApi:CreateButton({
    Name     = "Dropdown.Set(\"New Y\")",
    Callback = function()
        local el = Library.Elements["Test_Dropdown"]
        if el and el.Set then el.Set("New Y") PrintLog("API: Dropdown.Set OK") end
    end,
})

TabApi:CreateSection("Theme Live Test")

TabApi:CreateButton({
    Name     = "SetTheme: Accent แดง",
    Callback = function()
        Library:SetTheme({ Accent = Color3.fromRGB(255, 70, 70) })
        PrintLog("Theme: Accent -> Red")
    end,
})

TabApi:CreateButton({
    Name     = "SetTheme: Accent เขียว",
    Callback = function()
        Library:SetTheme({ Accent = Color3.fromRGB(60, 220, 120) })
        PrintLog("Theme: Accent -> Green")
    end,
})

TabApi:CreateButton({
    Name     = "ResetTheme (คืนค่าโรงงาน)",
    Callback = function()
        Library:ResetTheme()
        PrintLog("Theme: Reset complete")
    end,
})

TabApi:CreateSection("Config Save / Load (Flags)")

TabApi:CreateButton({
    Name     = "SaveConfiguration(\"test_lab\")",
    Callback = function()
        Library:SaveConfiguration("test_lab")
        PrintLog("Config saved: test_lab.json")
    end,
})

TabApi:CreateButton({
    Name     = "LoadConfiguration(\"test_lab\")",
    Callback = function()
        Library:LoadConfiguration("test_lab")
        PrintLog("Config loaded: test_lab.json")
    end,
})

TabApi:CreateSection("Notification Stress Test")

TabApi:CreateButton({
    Name     = "ยิง 5 Notifications พร้อมกัน (ทดสอบ queue)",
    Callback = function()
        for i = 1, 5 do
            Library:Notify({
                Title    = "Notify #" .. i,
                Content  = "ทดสอบระบบแจ้งเตือน (queue สูงสุด 3 อัน)",
                Duration = 3,
            })
        end
        PrintLog("Notify: queued 5 messages")
    end,
})

TabApi:CreateSection("Responsive Scale Status")

TabApi:CreateParagraph({
    Title   = "Viewport / Scale",
    Content = "ตรวจสอบ live ทุก 2 วิ — ย่อ/ขยายหน้าต่างเพื่อดูการเปลี่ยน",
})

local VpStatus = TabApi:CreateParagraph({
    Title   = "Scale Monitor",
    Content = "รอข้อมูล...",
})

task.spawn(function()
    while task.wait(2) do
        pcall(function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local vp = cam.ViewportSize
            VpStatus.Set(string.format("Viewport: %d x %d\nUIScale: %.2f",
                vp.X, vp.Y, Library.UIScale or 1))
        end)
    end
end)

TabApi:CreateSection("Danger Zone")

TabApi:CreateButton({
    Name     = "Library:Destroy() — ปิดและล้างทุกอย่าง",
    Callback = function()
        Library:Destroy()
    end,
})

-- ============================================================
-- เริ่มทดสอบ
-- ============================================================
Library:Notify({
    Title    = "UI TEST LAB Ready",
    Content  = "โหลดจาก GitHub สำเร็จ — ทุกระบบพร้อมทดสอบ",
    Duration = 4,
})
