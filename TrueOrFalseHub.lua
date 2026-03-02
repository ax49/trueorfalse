-- True or False Answer Hub
-- Reads current question from SIGN, matches against CustomQuestions, shows TRUE/FALSE
-- Drawing API overlay for Matcha LuaVM

-- ============================================================
-- PATHS
-- ============================================================
local SIGN_PATH = game.Workspace.CityMap.Model.screen.SurfaceGui.SIGN
local QUESTIONS_FOLDER = game.Workspace.CustomQuestions

-- ============================================================
-- HELPERS
-- ============================================================
local function sq(fill, col)
    local s = Drawing.new("Square")
    s.Filled = fill
    s.Color = col or Color3.new(1,1,1)
    s.Transparency = 1
    s.Thickness = 1
    s.Visible = false
    return s
end

local function tx(str, col, sz)
    local t = Drawing.new("Text")
    t.Text = str or ""
    t.Color = col or Color3.new(1,1,1)
    t.Size = sz or 13
    t.Outline = true
    t.Font = Drawing.Fonts.System
    t.Visible = false
    return t
end

-- ============================================================
-- THEME
-- ============================================================
local GREEN  = Color3.fromRGB(50, 220, 100)
local RED    = Color3.fromRGB(220, 60, 60)
local YELLOW = Color3.fromRGB(255, 220, 50)
local WHITE  = Color3.fromRGB(230, 235, 255)
local BLACK  = Color3.fromRGB(0, 0, 0)
local BG     = Color3.fromRGB(12, 14, 22)
local SURF   = Color3.fromRGB(20, 23, 36)
local BRD    = Color3.fromRGB(40, 46, 72)
local ACC    = Color3.fromRGB(90, 165, 255)

-- ============================================================
-- DRAWINGS
-- ============================================================
local dCrust   = sq(false, BLACK)
local dBrd     = sq(false, BRD)
local dBG      = sq(true,  BG)
local dTitleBG = sq(true,  SURF)
local dAccBar  = sq(true,  ACC)
local dTitle   = tx("TRUE OR FALSE HUB", WHITE, 12)

-- Close button
local dCloseBG = sq(true,  Color3.fromRGB(180,50,50))
local dCloseTx = tx("X", WHITE, 11)

-- Answer display
local dAnsBox  = sq(true,  SURF)
local dAnsBrd  = sq(false, BRD)
local dAnsText = tx("WAITING...", YELLOW, 36)
local dAnsLbl  = tx("ANSWER", Color3.fromRGB(100,115,155), 10)

-- Question display
local dQBox    = sq(true,  SURF)
local dQBrd    = sq(false, BRD)
local dQText   = tx("No question detected", Color3.fromRGB(180,190,220), 11)
local dQLbl    = tx("CURRENT QUESTION", Color3.fromRGB(100,115,155), 10)

-- Status
local dStatusBG = sq(true, SURF)
local dStatusTx = tx("Scanning...", Color3.fromRGB(100,115,155), 10)

-- ============================================================
-- LAYOUT
-- ============================================================
local WX, WY   = 20, 20
local WW, WH   = 420, 260
local TH       = 28
local PAD      = 10
local running  = true
local dragging = false
local dragX, dragY = 0, 0
local m1held   = false

local function hov(mx, my, x, y, w, h)
    return mx >= x and mx <= x+w and my >= y and my <= y+h
end

-- ============================================================
-- ANSWER LOOKUP
-- ============================================================
local function normalize(str)
    if not str then return "" end
    return str:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function findAnswer(questionText)
    if not questionText or questionText == "" then return nil end
    local norm = normalize(questionText)
    for _, child in ipairs(QUESTIONS_FOLDER:GetChildren()) do
        if child:IsA("StringValue") then
            if normalize(child.Value) == norm then
                local answer = child:GetAttribute("CorrectAnswer")
                if answer ~= nil then
                    return answer -- true or false (bool)
                end
            end
        end
    end
    return nil
end

-- ============================================================
-- QUESTION WRAP (fit text into box)
-- ============================================================
local function wrapText(str, maxChars)
    if #str <= maxChars then return str end
    local result = ""
    local lineLen = 0
    for word in str:gmatch("%S+") do
        if lineLen + #word + 1 > maxChars then
            result = result .. "\n" .. word
            lineLen = #word
        else
            if result == "" then
                result = word
            else
                result = result .. " " .. word
            end
            lineLen = lineLen + #word + 1
        end
    end
    return result
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local mouse = game:GetService("Players").LocalPlayer:GetMouse()
local lastQuestion = ""
local currentAnswer = nil

local function step()
    repeat task.wait() until isrbxactive()

    local mx, my = mouse.X, mouse.Y
    local now = os.clock()

    local m1now = iskeypressed(0x01)
    local clicked = m1now and not m1held
    m1held = m1now

    -- Drag
    if dragging then
        if m1now then WX = mx - dragX; WY = my - dragY
        else dragging = false end
        clicked = false
    end

    -- Title bar
    if clicked and hov(mx, my, WX, WY, WW, TH) then
        if hov(mx, my, WX+WW-30, WY+5, 22, 18) then
            running = false; return
        else
            dragging = true; dragX = mx-WX; dragY = my-WY; clicked = false
        end
    end

    -- ---- READ QUESTION ----
    local ok, currentQ = pcall(function() return SIGN_PATH.Text end)
    if not ok or not currentQ then currentQ = "" end

    -- Only re-lookup when question changes
    if currentQ ~= lastQuestion then
        lastQuestion = currentQ
        if currentQ == "" or currentQ == "failed to fetch text" then
            currentAnswer = nil
        else
            currentAnswer = findAnswer(currentQ)
        end
    end

    -- ---- DRAW ----
    local wx, wy = WX, WY

    -- Window
    dCrust.Position  = Vector2.new(wx, wy);        dCrust.Size  = Vector2.new(WW, WH);      dCrust.Visible  = true
    dBrd.Position    = Vector2.new(wx+1, wy+1);    dBrd.Size    = Vector2.new(WW-2, WH-2);  dBrd.Visible    = true
    dBG.Position     = Vector2.new(wx+2, wy+2);    dBG.Size     = Vector2.new(WW-4, WH-4);  dBG.Visible     = true
    dTitleBG.Position= Vector2.new(wx+2, wy+2);    dTitleBG.Size= Vector2.new(WW-4, TH-2);  dTitleBG.Visible= true
    dAccBar.Position = Vector2.new(wx+2, wy+TH-2); dAccBar.Size = Vector2.new(WW-4, 2);      dAccBar.Visible = true
    dTitle.Position  = Vector2.new(wx+10, wy+8);   dTitle.Visible = true

    -- Close
    dCloseBG.Position = Vector2.new(wx+WW-30, wy+5);  dCloseBG.Size = Vector2.new(22,18); dCloseBG.Visible = true
    dCloseTx.Position = Vector2.new(wx+WW-25, wy+8);  dCloseTx.Visible = true

    -- Answer box
    local ansY = wy + TH + PAD
    local ansH = 90
    dAnsBox.Position = Vector2.new(wx+PAD, ansY);       dAnsBox.Size = Vector2.new(WW-PAD*2, ansH); dAnsBox.Visible = true
    dAnsBrd.Position = Vector2.new(wx+PAD, ansY);       dAnsBrd.Size = Vector2.new(WW-PAD*2, ansH); dAnsBrd.Visible = true
    dAnsLbl.Position = Vector2.new(wx+PAD+8, ansY+6);  dAnsLbl.Visible = true

    if currentAnswer == true then
        dAnsText.Text  = "TRUE"
        dAnsText.Color = GREEN
        dAnsBox.Color  = Color3.fromRGB(10, 40, 20)
    elseif currentAnswer == false then
        dAnsText.Text  = "FALSE"
        dAnsText.Color = RED
        dAnsBox.Color  = Color3.fromRGB(40, 10, 10)
    else
        dAnsText.Text  = "?"
        dAnsText.Color = YELLOW
        dAnsBox.Color  = SURF
    end
    dAnsText.Position = Vector2.new(wx + WW/2 - 30, ansY + 25)
    dAnsText.Visible  = true

    -- Question box
    local qY = ansY + ansH + 8
    local qH = WH - TH - PAD - ansH - 8 - PAD - 20
    dQBox.Position  = Vector2.new(wx+PAD, qY);      dQBox.Size  = Vector2.new(WW-PAD*2, qH); dQBox.Visible  = true
    dQBrd.Position  = Vector2.new(wx+PAD, qY);      dQBrd.Size  = Vector2.new(WW-PAD*2, qH); dQBrd.Visible  = true
    dQLbl.Position  = Vector2.new(wx+PAD+8, qY+6); dQLbl.Visible = true

    local displayQ = currentQ == "" and "Waiting for question..." or wrapText(currentQ, 55)
    dQText.Text     = displayQ
    dQText.Position = Vector2.new(wx+PAD+8, qY+20)
    dQText.Visible  = true

    -- Status bar
    local stY = wy + WH - 18
    dStatusBG.Position = Vector2.new(wx+2, stY);    dStatusBG.Size = Vector2.new(WW-4, 16); dStatusBG.Visible = true
    local statusStr
    if currentAnswer ~= nil then
        statusStr = "Match found  |  Drag title to move  |  X to close"
    elseif currentQ ~= "" and currentQ ~= "failed to fetch text" then
        statusStr = "No match in CustomQuestions  |  Question may be server-side only"
    else
        statusStr = "Waiting for round to start..."
    end
    dStatusTx.Text     = statusStr
    dStatusTx.Position = Vector2.new(wx+PAD, stY+2)
    dStatusTx.Visible  = true
end

local function destroy()
    local all = {dCrust,dBrd,dBG,dTitleBG,dAccBar,dTitle,dCloseBG,dCloseTx,dAnsBox,dAnsBrd,dAnsText,dAnsLbl,dQBox,dQBrd,dQText,dQLbl,dStatusBG,dStatusTx}
    for _, d in ipairs(all) do pcall(function() d:Remove() end) end
end

-- ============================================================
-- RUN
-- ============================================================
print("[TrueOrFalseHub] Loaded.")
while running do
    pcall(step)
    task.wait()
end
destroy()
print("[TrueOrFalseHub] Closed.")
