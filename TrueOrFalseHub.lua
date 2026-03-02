-- True or False Answer Hub v3
-- Auto-finds SIGN on any map, calls Cloudflare Worker for AI answer

local WORKER_URL = "https://billowing-sun-30dd.azizxqa.workers.dev"
local QUESTIONS_FOLDER = game.Workspace:FindFirstChild("CustomQuestions")

-- ============================================================
-- FIND SIGN DYNAMICALLY (works on any map)
-- ============================================================
local SIGN_PATH = nil
local function findSign()
    for _, v in ipairs(game.Workspace:GetDescendants()) do
        if v:IsA("TextLabel") and v.Name == "SIGN" then
            return v
        end
    end
    return nil
end
SIGN_PATH = findSign()

-- ============================================================
-- HELPERS
-- ============================================================
local function sq(fill, col)
    local s = Drawing.new("Square")
    s.Filled = fill; s.Color = col or Color3.new(1,1,1)
    s.Transparency = 1; s.Thickness = 1; s.Visible = false
    return s
end

local function tx(str, col, sz)
    local t = Drawing.new("Text")
    t.Text = str or ""; t.Color = col or Color3.new(1,1,1)
    t.Size = sz or 13; t.Outline = true
    t.Font = Drawing.Fonts.System; t.Visible = false
    return t
end

local function hov(mx, my, x, y, w, h)
    return mx >= x and mx <= x+w and my >= y and my <= y+h
end

local function normalize(str)
    if not str then return "" end
    return str:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function wrapText(str, maxChars)
    if #str <= maxChars then return str end
    local result = ""; local lineLen = 0
    for word in str:gmatch("%S+") do
        if lineLen + #word + 1 > maxChars then
            result = result .. "\n" .. word; lineLen = #word
        else
            result = result == "" and word or result .. " " .. word
            lineLen = lineLen + #word + 1
        end
    end
    return result
end

-- ============================================================
-- THEME
-- ============================================================
local GREEN  = Color3.fromRGB(50, 220, 100)
local RED    = Color3.fromRGB(220, 60, 60)
local YELLOW = Color3.fromRGB(255, 220, 50)
local PURPLE = Color3.fromRGB(180, 100, 255)
local WHITE  = Color3.fromRGB(230, 235, 255)
local BLACK  = Color3.fromRGB(0, 0, 0)
local BG     = Color3.fromRGB(12, 14, 22)
local SURF   = Color3.fromRGB(20, 23, 36)
local BRD    = Color3.fromRGB(40, 46, 72)
local ACC    = Color3.fromRGB(90, 165, 255)
local SUB    = Color3.fromRGB(100, 115, 155)

-- ============================================================
-- DRAWINGS
-- ============================================================
local dCrust   = sq(false, BLACK);   local dBrd     = sq(false, BRD)
local dBG      = sq(true,  BG);      local dTitleBG = sq(true,  SURF)
local dAccBar  = sq(true,  ACC);     local dTitle   = tx("TRUE OR FALSE HUB", WHITE, 12)
local dCloseBG = sq(true,  Color3.fromRGB(180,50,50))
local dCloseTx = tx("X", WHITE, 11)
local dAnsBox  = sq(true,  SURF);    local dAnsBrd  = sq(false, BRD)
local dAnsText = tx("?", YELLOW, 42); local dAnsLbl = tx("ANSWER", SUB, 10)
local dQBox    = sq(true,  SURF);    local dQBrd    = sq(false, BRD)
local dQText   = tx("Waiting...", Color3.fromRGB(180,190,220), 11)
local dQLbl    = tx("CURRENT QUESTION", SUB, 10)
local dStatusBG = sq(true, Color3.fromRGB(15,17,28))
local dStatusTx = tx("Waiting for question...", SUB, 10)

-- ============================================================
-- LAYOUT
-- ============================================================
local WX, WY   = 20, 20
local WW, WH   = 430, 270
local TH       = 28; local PAD = 10
local running  = true
local dragging = false
local dragX, dragY = 0, 0
local m1held   = false

-- ============================================================
-- STATE
-- ============================================================
local lastQuestion  = ""
local currentAnswer = nil
local asking        = false
local mouse = game:GetService("Players").LocalPlayer:GetMouse()

-- ============================================================
-- LOCAL LOOKUP
-- ============================================================
local function findAnswerLocal(questionText)
    if not QUESTIONS_FOLDER then return nil end
    local norm = normalize(questionText)
    for _, child in ipairs(QUESTIONS_FOLDER:GetChildren()) do
        if child:IsA("StringValue") and normalize(child.Value) == norm then
            local answer = child:GetAttribute("CorrectAnswer")
            if answer ~= nil then return answer end
        end
    end
    return nil
end

-- ============================================================
-- AI LOOKUP
-- ============================================================
local function askAI(question)
    if WORKER_URL == "" then return nil end
    asking = true
    local encoded = question:gsub(" ", "+"):gsub("([^%w%+%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    local url = WORKER_URL .. "?q=" .. encoded
    local ok, result = pcall(function() return game:HttpGet(url) end)
    asking = false
    if not ok or not result then return nil end
    result = result:upper():gsub("%s+", "")
    if result == "MAJORITY" then return "MAJORITY" end
    if result:find("TRUE") then return true end
    if result:find("FALSE") then return false end
    return nil
end

-- ============================================================
-- MAIN STEP
-- ============================================================
local function step()
    repeat task.wait() until isrbxactive()

    local mx, my = mouse.X, mouse.Y
    local m1now = iskeypressed(0x01)
    local clicked = m1now and not m1held
    m1held = m1now

    if dragging then
        if m1now then WX = mx - dragX; WY = my - dragY
        else dragging = false end
        clicked = false
    end

    if clicked and hov(mx, my, WX, WY, WW, TH) then
        if hov(mx, my, WX+WW-30, WY+5, 22, 18) then
            running = false; return
        else
            dragging = true; dragX = mx-WX; dragY = my-WY; clicked = false
        end
    end

    -- Re-find SIGN if lost (map rotation)
    if not SIGN_PATH or not pcall(function() return SIGN_PATH.Parent end) then
        SIGN_PATH = nil
        task.wait(3) -- wait for new map to load
        SIGN_PATH = findSign()
        lastQuestion = "" -- reset so new map question triggers fresh lookup
        currentAnswer = nil
    end

    -- Read question
    local currentQ = ""
    if SIGN_PATH then
        local ok, t = pcall(function() return SIGN_PATH.Text end)
        if ok and t then currentQ = t end
    end

    -- Filter invalid
    if currentQ == "failed to fetch text" or #currentQ < 20 or currentQ:sub(1,1) == "#" then
        currentQ = ""
    end

    -- New question
    if currentQ ~= lastQuestion and not asking then
        lastQuestion = currentQ
        currentAnswer = nil
        if currentQ ~= "" then
            local localAnswer = findAnswerLocal(currentQ)
            if localAnswer ~= nil then
                currentAnswer = localAnswer
            else
                spawn(function() currentAnswer = askAI(currentQ) end)
            end
        end
    end

    -- ---- DRAW ----
    local wx, wy = WX, WY

    dCrust.Position=Vector2.new(wx,wy);         dCrust.Size=Vector2.new(WW,WH);       dCrust.Visible=true
    dBrd.Position=Vector2.new(wx+1,wy+1);       dBrd.Size=Vector2.new(WW-2,WH-2);     dBrd.Visible=true
    dBG.Position=Vector2.new(wx+2,wy+2);        dBG.Size=Vector2.new(WW-4,WH-4);      dBG.Visible=true
    dTitleBG.Position=Vector2.new(wx+2,wy+2);   dTitleBG.Size=Vector2.new(WW-4,TH-2); dTitleBG.Visible=true
    dAccBar.Position=Vector2.new(wx+2,wy+TH-2); dAccBar.Size=Vector2.new(WW-4,2);     dAccBar.Visible=true
    dTitle.Position=Vector2.new(wx+10,wy+8);    dTitle.Visible=true
    dCloseBG.Position=Vector2.new(wx+WW-30,wy+5); dCloseBG.Size=Vector2.new(22,18);   dCloseBG.Visible=true
    dCloseTx.Position=Vector2.new(wx+WW-25,wy+8); dCloseTx.Visible=true

    -- Answer box
    local ansY = wy+TH+PAD; local ansH = 95
    dAnsBox.Position=Vector2.new(wx+PAD,ansY);      dAnsBox.Size=Vector2.new(WW-PAD*2,ansH); dAnsBox.Visible=true
    dAnsBrd.Position=Vector2.new(wx+PAD,ansY);      dAnsBrd.Size=Vector2.new(WW-PAD*2,ansH); dAnsBrd.Visible=true
    dAnsLbl.Position=Vector2.new(wx+PAD+8,ansY+6);  dAnsLbl.Visible=true

    if asking then
        dAnsText.Text="..."; dAnsText.Color=ACC; dAnsBox.Color=SURF
    elseif currentAnswer=="MAJORITY" then
        dAnsText.Text="MAJORITY"; dAnsText.Color=PURPLE; dAnsBox.Color=Color3.fromRGB(30,15,50)
    elseif currentAnswer==true then
        dAnsText.Text="TRUE"; dAnsText.Color=GREEN; dAnsBox.Color=Color3.fromRGB(8,35,16)
    elseif currentAnswer==false then
        dAnsText.Text="FALSE"; dAnsText.Color=RED; dAnsBox.Color=Color3.fromRGB(35,8,8)
    else
        dAnsText.Text="?"; dAnsText.Color=YELLOW; dAnsBox.Color=SURF
    end
    dAnsText.Position=Vector2.new(wx+WW/2-50,ansY+26); dAnsText.Visible=true

    -- Question box
    local qY=ansY+ansH+8; local qH=WH-TH-PAD-ansH-8-PAD-20
    dQBox.Position=Vector2.new(wx+PAD,qY);    dQBox.Size=Vector2.new(WW-PAD*2,qH); dQBox.Visible=true
    dQBrd.Position=Vector2.new(wx+PAD,qY);    dQBrd.Size=Vector2.new(WW-PAD*2,qH); dQBrd.Visible=true
    dQLbl.Position=Vector2.new(wx+PAD+8,qY+6); dQLbl.Visible=true
    dQText.Text=lastQuestion=="" and "Waiting for question..." or wrapText(lastQuestion,58)
    dQText.Position=Vector2.new(wx+PAD+8,qY+20); dQText.Visible=true

    -- Status
    local stY=wy+WH-18
    dStatusBG.Position=Vector2.new(wx+2,stY); dStatusBG.Size=Vector2.new(WW-4,16); dStatusBG.Visible=true
    local status
    if not SIGN_PATH then status="SIGN not found - waiting for map..."
    elseif asking then status="Asking AI..."
    elseif currentAnswer~=nil then status="Answer ready  |  drag to move  |  X to close"
    elseif lastQuestion~="" then status="Waiting for AI response..."
    else status="Waiting for question..." end
    dStatusTx.Text=status; dStatusTx.Position=Vector2.new(wx+PAD,stY+2); dStatusTx.Visible=true
end

local function destroy()
    local all={dCrust,dBrd,dBG,dTitleBG,dAccBar,dTitle,dCloseBG,dCloseTx,dAnsBox,dAnsBrd,dAnsText,dAnsLbl,dQBox,dQBrd,dQText,dQLbl,dStatusBG,dStatusTx}
    for _,d in ipairs(all) do pcall(function() d:Remove() end) end
end

print("[TrueOrFalseHub] Loaded. SIGN found: " .. tostring(SIGN_PATH ~= nil))
while running do pcall(step); task.wait() end
destroy()
print("[TrueOrFalseHub] Closed.")
