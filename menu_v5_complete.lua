-- ============================================================
--  MENU v5  |  Complete Rewrite | All Features Working
-- ============================================================
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

-- ===== CREDENTIALS SYSTEM =====
local CRED_FILE = "menu_credentials.json"

local function saveCredentials(username, password)
    local data = {username = username, password = password}
    pcall(function() writefile(CRED_FILE, HttpService:JSONEncode(data)) end)
end

local function loadCredentials()
    local success, data = pcall(function() return readfile(CRED_FILE) end)
    if success then
        return HttpService:JSONDecode(data)
    end
    return nil
end

local function clearCredentials()
    pcall(function() delfile(CRED_FILE) end)
end

-- ===== FEATURE STATE =====
local isListeningForKey = false

local Features = {
    Aimbot = {
        enabled = false,
        fovCircle = false,
        fov = 100,
        fovGui = nil,
        lockMode = "Head" -- Head or Body
    },
    Visual = {
        espEnabled = false,
        espLine = false,
        espBox = false,
        espName = false,
        espHealthBar = false,
        espChams = false,
        skeletonEnabled = false,
        linePosition = "Bottom", -- Top, Bottom, Side
        healthPosition = "Left", -- Left, Right, Top
        espColor = Color3.fromRGB(0, 255, 100),
        drawings = {}
    },
    Brutal = {
        flyEnabled = false,
        flySpeed = 50,
        speedEnabled = false,
        speedValue = 50,
        bodyVelocity = nil,
        bodyGyro = nil,
        tpToPlayer = nil,
        tpSpeed = 50
    },
    Keybind = {
        toggle = Enum.KeyCode.RightShift,
        close = Enum.KeyCode.X
    }
}

-- ===== SKELETON & CHAMS =====
local skeletonLines = {}
local chamObjects = {}

local function removeSkeleton()
    for _, line in ipairs(skeletonLines) do
        pcall(function() line:Destroy() end)
    end
    skeletonLines = {}
end

local function drawSkeleton(character, color)
    removeSkeleton()
    if not Features.Visual.skeletonEnabled then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local joints = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Parent and part.Parent:FindFirstChildOfClass("Humanoid") then
            table.insert(joints, part)
        end
    end
    
    for i = 1, #joints - 1 do
        for j = i + 1, #joints do
            local p1, p2 = joints[i], joints[j]
            if (p1.Position - p2.Position).Magnitude < 5 then
                local line = Instance.new("LineHandleAdornment")
                line.Length = (p1.Position - p2.Position).Magnitude
                line.Thickness = 1
                line.Color3 = color
                line.Transparency = 0.3
                
                local part = Instance.new("Part")
                part.CanCollide = false
                part.CFrame = CFrame.new((p1.Position + p2.Position) / 2)
                part.Parent = character
                
                line.Adornee = part
                line.Parent = character
                
                table.insert(skeletonLines, line)
                break
            end
        end
    end
end

local function removeChams()
    for _, cham in ipairs(chamObjects) do
        pcall(function() cham:Destroy() end)
    end
    chamObjects = {}
end

local function addChams(character, color)
    removeChams()
    if not Features.Visual.espChams then return end
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local cham = Instance.new("SelectionBox")
            cham.Adornee = part
            cham.Color3 = color
            cham.LineThickness = 0.05
            cham.SurfaceTransparency = 0.7
            cham.SurfaceColor3 = color
            cham.Parent = part
            
            table.insert(chamObjects, cham)
        end
    end
end

local function updateChamsColor(color)
    for _, cham in ipairs(chamObjects) do
        if cham and cham.Parent then
            cham.Color3 = color
            cham.SurfaceColor3 = color
        end
    end
end

-- ===== ESP DRAWING =====
local function newDrawing(class, props)
    local obj = Drawing.new(class)
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

local function getPlayerDrawings(op)
    local n = op.UserId
    if not Features.Visual.drawings[n] then
        local col = Features.Visual.espColor
        Features.Visual.drawings[n] = {
            box = newDrawing("Square", {Visible=false, Thickness=2, Filled=false, Transparency=1, Color=col}),
            tracer = newDrawing("Line", {Visible=false, Thickness=1.5, Transparency=1, Color=col}),
            nameTag = newDrawing("Text", {Visible=false, Size=13, Center=true, Outline=true,
                                         OutlineColor=Color3.new(0,0,0), Font=2, Color=col}),
            healthBg = newDrawing("Square", {Visible=false, Color=Color3.new(0,0,0), Thickness=1, Filled=true, Transparency=0.5}),
            healthFg = newDrawing("Square", {Visible=false, Color=col, Thickness=1, Filled=true, Transparency=1}),
            playerId = n
        }
    end
    return Features.Visual.drawings[n]
end

local function hideDrawings(d)
    if d then
        d.box.Visible = false
        d.tracer.Visible = false
        d.nameTag.Visible = false
        d.healthBg.Visible = false
        d.healthFg.Visible = false
    end
end

local function cleanAllESP()
    for _, d in pairs(Features.Visual.drawings) do
        hideDrawings(d)
    end
end

-- ===== GET CHARACTER BOUNDS (Full Body) =====
local function getCharacterBounds(character)
    local parts = {}
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = false
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local s = part.Size * 0.5
            local cf = part.CFrame
            local corners = {
                cf * Vector3.new(s.X, s.Y, s.Z), cf * Vector3.new(-s.X, s.Y, s.Z),
                cf * Vector3.new(s.X, -s.Y, s.Z), cf * Vector3.new(-s.X, -s.Y, s.Z),
                cf * Vector3.new(s.X, s.Y, -s.Z), cf * Vector3.new(-s.X, s.Y, -s.Z),
                cf * Vector3.new(s.X, -s.Y, -s.Z), cf * Vector3.new(-s.X, -s.Y, -s.Z),
            }
            
            for _, c in ipairs(corners) do
                local sp, onScreen = Camera:WorldToScreenPoint(c)
                if onScreen then
                    visible = true
                    if sp.X < minX then minX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end
    
    if not visible then return nil end
    return minX, minY, maxX, maxY
end

-- ===== FOV CIRCLE =====
local function updateFovCircle()
    if Features.Aimbot.fovCircle and not Features.Aimbot.fovGui then
        local sg = Instance.new("ScreenGui")
        sg.Name = "FOVGui"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 100
        sg.Parent = playerGui
        
        local fr = Instance.new("Frame")
        fr.BackgroundTransparency = 1
        fr.BorderSizePixel = 0
        fr.Parent = sg
        
        local uc = Instance.new("UICorner")
        uc.CornerRadius = UDim.new(1, 0)
        uc.Parent = fr
        
        local us = Instance.new("UIStroke")
        us.Color = Features.Visual.espColor
        us.Thickness = 2
        us.Parent = fr
        
        Features.Aimbot.fovGui = {gui = sg, circle = fr}
    elseif not Features.Aimbot.fovCircle and Features.Aimbot.fovGui then
        pcall(function() Features.Aimbot.fovGui.gui:Destroy() end)
        Features.Aimbot.fovGui = nil
        return
    end
    
    if Features.Aimbot.fovGui then
        local c = Features.Aimbot.fovGui.circle
        local r = Features.Aimbot.fov
        c.Size = UDim2.new(0, r * 2, 0, r * 2)
        c.Position = UDim2.new(0.5, -r, 0.5, -r)
    end
end

-- ===== AIMBOT (Lock to Head or Body) =====
local function performAimbot()
    if not Features.Aimbot.enabled then return end
    
    local closest, closestDist = nil, Features.Aimbot.fov
    
    for _, op in ipairs(Players:GetPlayers()) do
        if op ~= player and op.Character then
            local targetPart = Features.Aimbot.lockMode == "Head" 
                and op.Character:FindFirstChild("Head")
                or op.Character:FindFirstChild("HumanoidRootPart")
            
            local humanoid = op.Character:FindFirstChildOfClass("Humanoid")
            
            if targetPart and humanoid and humanoid.Health > 0 then
                local sp, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
                local dist = (Vector2.new(sp.X, sp.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
                
                if onScreen and dist < closestDist then
                    closestDist = dist
                    closest = op
                end
            end
        end
    end
    
    if closest and closest.Character then
        local targetPart = Features.Aimbot.lockMode == "Head"
            and closest.Character:FindFirstChild("Head")
            or closest.Character:FindFirstChild("HumanoidRootPart")
        
        if targetPart then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
        end
    end
end

-- ===== ESP UPDATE =====
local espFrameCount = 0

local function updateESP()
    if not Features.Visual.espEnabled then
        cleanAllESP()
        return
    end
    
    local sv = Camera.ViewportSize
    local col = Features.Visual.espColor
    
    for _, op in ipairs(Players:GetPlayers()) do
        if op == player then continue end
        
        local d = getPlayerDrawings(op)
        local char = op.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        
        if not char or not humanoid or humanoid.Health <= 0 then
            hideDrawings(d)
            continue
        end
        
        local minX, minY, maxX, maxY = getCharacterBounds(char)
        if not minX then
            hideDrawings(d)
            continue
        end
        
        local bw = maxX - minX
        local bh = maxY - minY
        local centerX = minX + bw * 0.5
        local centerY = minY + bh * 0.5
        
        -- BOX
        d.box.Visible = Features.Visual.espBox
        d.box.Color = col
        if Features.Visual.espBox then
            d.box.Position = Vector2.new(minX, minY)
            d.box.Size = Vector2.new(bw, bh)
        end
        
        -- TRACER
        d.tracer.Visible = Features.Visual.espLine
        d.tracer.Color = col
        if Features.Visual.espLine then
            if Features.Visual.linePosition == "Bottom" then
                d.tracer.From = Vector2.new(sv.X * 0.5, sv.Y)
                d.tracer.To = Vector2.new(centerX, maxY)
            elseif Features.Visual.linePosition == "Top" then
                d.tracer.From = Vector2.new(sv.X * 0.5, 0)
                d.tracer.To = Vector2.new(centerX, minY)
            else -- Side
                d.tracer.From = Vector2.new(0, sv.Y * 0.5)
                d.tracer.To = Vector2.new(centerX, centerY)
            end
        end
        
        -- NAME
        d.nameTag.Visible = Features.Visual.espName
        if Features.Visual.espName then
            d.nameTag.Text = op.Name
            d.nameTag.Position = Vector2.new(centerX, minY - 17)
        end
        
        -- HEALTH BAR
        if Features.Visual.espHealthBar then
            local hp = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            local hcol = hp > 0.6 and Color3.fromRGB(0, 255, 80)
                      or hp > 0.3 and Color3.fromRGB(255, 200, 0)
                      or Color3.fromRGB(255, 50, 50)
            
            d.healthBg.Visible = true
            d.healthFg.Visible = true
            d.healthFg.Color = hcol
            
            if Features.Visual.healthPosition == "Left" then
                d.healthBg.Position = Vector2.new(minX - 8, minY)
                d.healthBg.Size = Vector2.new(4, bh)
                d.healthFg.Position = Vector2.new(minX - 8, minY + bh * (1 - hp))
                d.healthFg.Size = Vector2.new(4, bh * hp)
            elseif Features.Visual.healthPosition == "Right" then
                d.healthBg.Position = Vector2.new(maxX + 4, minY)
                d.healthBg.Size = Vector2.new(4, bh)
                d.healthFg.Position = Vector2.new(maxX + 4, minY + bh * (1 - hp))
                d.healthFg.Size = Vector2.new(4, bh * hp)
            else -- Top
                d.healthBg.Position = Vector2.new(minX, minY - 8)
                d.healthBg.Size = Vector2.new(bw, 4)
                d.healthFg.Position = Vector2.new(minX, minY - 8)
                d.healthFg.Size = Vector2.new(bw * hp, 4)
            end
        else
            d.healthBg.Visible = false
            d.healthFg.Visible = false
        end
    end
    
    for id, d in pairs(Features.Visual.drawings) do
        local found = false
        for _, op in ipairs(Players:GetPlayers()) do
            if op.UserId == id then
                found = true
                break
            end
        end
        if not found then
            hideDrawings(d)
        end
    end
end

-- ===== FLY =====
local function startFly()
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not hum then return end
    
    if Features.Brutal.flyEnabled then
        pcall(function() if Features.Brutal.bodyVelocity then Features.Brutal.bodyVelocity:Destroy() end end)
        pcall(function() if Features.Brutal.bodyGyro then Features.Brutal.bodyGyro:Destroy() end end)
        
        local bv = Instance.new("BodyVelocity")
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Parent = hrp
        
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        bg.P = 10000
        bg.Parent = hrp
        
        Features.Brutal.bodyVelocity = bv
        Features.Brutal.bodyGyro = bg
        hum.PlatformStand = true
    else
        pcall(function() if Features.Brutal.bodyVelocity then Features.Brutal.bodyVelocity:Destroy() end end)
        pcall(function() if Features.Brutal.bodyGyro then Features.Brutal.bodyGyro:Destroy() end end)
        
        Features.Brutal.bodyVelocity = nil
        Features.Brutal.bodyGyro = nil
        
        if hum then
            hum.PlatformStand = false
        end
    end
end

local function updateFly()
    if not Features.Brutal.flyEnabled then return end
    
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not Features.Brutal.bodyVelocity then return end
    
    local d = Vector3.new(0, 0, 0)
    local spd = Features.Brutal.flySpeed * 0.15
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.new(0, 1, 0) end
    
    if d.Magnitude > 0 then d = d.Unit end
    
    Features.Brutal.bodyVelocity.Velocity = d * spd
    if Features.Brutal.bodyGyro then
        Features.Brutal.bodyGyro.CFrame = Camera.CFrame
    end
end

-- ===== SPEED =====
local function updateSpeed()
    local char = player.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if Features.Brutal.speedEnabled then
        hum.WalkSpeed = 16 + (Features.Brutal.speedValue / 5)
    else
        hum.WalkSpeed = 16
    end
end

-- ===== TELEPORT =====
local function tpToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if hrp and targetHrp then
        hrp.CFrame = targetHrp.CFrame + Vector3.new(5, 0, 0)
    end
end

-- ===== MAIN LOOP =====
RunService.RenderStepped:Connect(function()
    updateFovCircle()
    performAimbot()
    updateFly()
    updateSpeed()
    
    espFrameCount = espFrameCount + 1
    if espFrameCount >= 5 then
        espFrameCount = 0
        updateESP()
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(0.1)
    if Features.Brutal.flyEnabled then
        startFly()
    end
end)

-- ============================================================
--  GUI CREATION
-- ============================================================

local function mkCorner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
end

local function mkStroke(c, t, p)
    local s = Instance.new("UIStroke")
    s.Color = c
    s.Thickness = t
    s.Parent = p
end

local function mkPad(l, r, t, b, p)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, l)
    pad.PaddingRight = UDim.new(0, r)
    pad.PaddingTop = UDim.new(0, t)
    pad.PaddingBottom = UDim.new(0, b)
    pad.Parent = p
end

local COL_BG = Color3.fromRGB(14, 14, 22)
local COL_BG2 = Color3.fromRGB(20, 20, 34)
local COL_BG3 = Color3.fromRGB(10, 10, 18)
local COL_ACCENT = Color3.fromRGB(80, 120, 230)
local COL_TEXT = Color3.fromRGB(195, 195, 215)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MenuV5"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.Parent = playerGui

-- ===== LOGIN SCREEN =====
local loginFrame = Instance.new("Frame")
loginFrame.Size = UDim2.new(0, 310, 0, 295)
loginFrame.Position = UDim2.new(0.5, -155, 0.5, -148)
loginFrame.BackgroundColor3 = COL_BG
loginFrame.BorderSizePixel = 0
loginFrame.Parent = screenGui
mkCorner(14, loginFrame)
mkStroke(COL_ACCENT, 1.5, loginFrame)

local loginTitle = Instance.new("TextLabel")
loginTitle.Size = UDim2.new(1, 0, 0, 42)
loginTitle.BackgroundColor3 = COL_BG3
loginTitle.BorderSizePixel = 0
loginTitle.Text = "✦  LOGIN"
loginTitle.TextColor3 = Color3.fromRGB(100, 150, 255)
loginTitle.TextSize = 15
loginTitle.Font = Enum.Font.GothamBold
loginTitle.Parent = loginFrame
mkCorner(14, loginTitle)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -30, 0, 14)
statusLbl.Position = UDim2.new(0, 15, 0, 48)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = ""
statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
statusLbl.TextSize = 9
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = loginFrame

local function mkInputField(placeholder, yPos, masked)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, -28, 0, 34)
    bg.Position = UDim2.new(0, 14, 0, yPos)
    bg.BackgroundColor3 = COL_BG2
    bg.BorderSizePixel = 0
    bg.Parent = loginFrame
    mkCorner(8, bg)
    mkStroke(Color3.fromRGB(55, 75, 170), 1, bg)
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -14, 1, 0)
    box.Position = UDim2.new(0, 7, 0, 0)
    box.BackgroundTransparency = 1
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Color3.fromRGB(85, 85, 115)
    box.Text = ""
    box.TextColor3 = Color3.fromRGB(220, 220, 240)
    box.TextSize = 12
    box.Font = Enum.Font.Gotham
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Parent = bg
    
    local realValue = ""
    if masked then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local t = box.Text
            if #t > #realValue then
                realValue = realValue .. t:sub(#realValue + 1)
            elseif #t < #realValue then
                realValue = realValue:sub(1, #t)
            end
            box.Text = string.rep("•", #realValue)
            box.CursorPosition = #box.Text + 1
        end)
    end
    
    return box, function() return masked and realValue or box.Text end
end

local userBox, getUserText = mkInputField("Username", 68, false)
local passBox, getPassText = mkInputField("Password", 110, true)

local remFrame = Instance.new("Frame")
remFrame.Size = UDim2.new(1, -28, 0, 22)
remFrame.Position = UDim2.new(0, 14, 0, 153)
remFrame.BackgroundTransparency = 1
remFrame.Parent = loginFrame

local remCheck = Instance.new("TextButton")
remCheck.Size = UDim2.new(0, 20, 0, 20)
remCheck.Position = UDim2.new(0, 0, 0.5, -10)
remCheck.BackgroundColor3 = Color3.fromRGB(28, 28, 48)
remCheck.Text = ""
remCheck.BorderSizePixel = 0
remCheck.Parent = remFrame
mkCorner(5, remCheck)
mkStroke(COL_ACCENT, 1, remCheck)

local checkMark = Instance.new("TextLabel")
checkMark.Size = UDim2.new(1, 0, 1, 0)
checkMark.BackgroundTransparency = 1
checkMark.Text = ""
checkMark.TextColor3 = Color3.fromRGB(80, 200, 110)
checkMark.TextSize = 13
checkMark.Font = Enum.Font.GothamBold
checkMark.Parent = remCheck

local remLbl = Instance.new("TextLabel")
remLbl.Size = UDim2.new(1, -26, 1, 0)
remLbl.Position = UDim2.new(0, 26, 0, 0)
remLbl.BackgroundTransparency = 1
remLbl.Text = "Remember me (session only)"
remLbl.TextColor3 = Color3.fromRGB(155, 155, 185)
remLbl.TextSize = 10
remLbl.Font = Enum.Font.Gotham
remLbl.TextXAlignment = Enum.TextXAlignment.Left
remLbl.Parent = remFrame

local rememberEnabled = false
remCheck.MouseButton1Click:Connect(function()
    rememberEnabled = not rememberEnabled
    checkMark.Text = rememberEnabled and "✓" or ""
    remCheck.BackgroundColor3 = rememberEnabled and Color3.fromRGB(35, 110, 60) or Color3.fromRGB(28, 28, 48)
end)

local loginBtn = Instance.new("TextButton")
loginBtn.Size = UDim2.new(1, -28, 0, 36)
loginBtn.Position = UDim2.new(0, 14, 0, 184)
loginBtn.BackgroundColor3 = Color3.fromRGB(65, 105, 215)
loginBtn.Text = "LOGIN"
loginBtn.TextColor3 = Color3.new(1, 1, 1)
loginBtn.TextSize = 13
loginBtn.Font = Enum.Font.GothamBold
loginBtn.BorderSizePixel = 0
loginBtn.Parent = loginFrame
mkCorner(8, loginBtn)

loginBtn.MouseEnter:Connect(function() loginBtn.BackgroundColor3 = Color3.fromRGB(85, 125, 240) end)
loginBtn.MouseLeave:Connect(function() loginBtn.BackgroundColor3 = Color3.fromRGB(65, 105, 215) end)

-- ===== MAIN MENU =====
local mainMenuFrame = Instance.new("Frame")
mainMenuFrame.Name = "MainFrame"
mainMenuFrame.Size = UDim2.new(0, 380, 0, 500)
mainMenuFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
mainMenuFrame.BackgroundColor3 = COL_BG
mainMenuFrame.BorderSizePixel = 0
mainMenuFrame.Visible = false
mainMenuFrame.Parent = screenGui
mkCorner(12, mainMenuFrame)
mkStroke(COL_ACCENT, 1.5, mainMenuFrame)

local menuIsVisible = false

local function showMenu(state)
    menuIsVisible = state
    mainMenuFrame.Visible = state
end

local function toggleMenu()
    showMenu(not menuIsVisible)
end

-- ===== DRAG =====
local dragging, dragStart, framePos = false, Vector2.new(), mainMenuFrame.Position
mainMenuFrame.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        local relY = inp.Position.Y - mainMenuFrame.AbsolutePosition.Y
        if relY <= 36 then
            dragging = true
            dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            framePos = mainMenuFrame.Position
        end
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
        mainMenuFrame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + d.X,
                                          framePos.Y.Scale, framePos.Y.Offset + d.Y)
    end
end)

-- ===== TITLE BAR =====
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = COL_BG3
titleBar.BorderSizePixel = 0
titleBar.Parent = mainMenuFrame
mkCorner(12, titleBar)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(0.55, 0, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "✦  MENU v5"
titleLbl.TextColor3 = Color3.fromRGB(100, 150, 255)
titleLbl.TextSize = 13
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local keybindHint = Instance.new("TextLabel")
keybindHint.Size = UDim2.new(0, 200, 0, 12)
keybindHint.Position = UDim2.new(0, 10, 1, 1)
keybindHint.BackgroundTransparency = 1
keybindHint.TextSize = 7
keybindHint.Font = Enum.Font.Gotham
keybindHint.TextColor3 = Color3.fromRGB(80, 80, 120)
keybindHint.TextXAlignment = Enum.TextXAlignment.Left
keybindHint.Parent = titleBar

local function refreshHint()
    local tog = tostring(Features.Keybind.toggle):gsub("Enum.KeyCode.", "")
    local cls = tostring(Features.Keybind.close):gsub("Enum.KeyCode.", "")
    keybindHint.Text = tog .. " = hide  |  " .. cls .. " = close"
end
refreshHint()

local function mkTitleBtn(txt, col, offX)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 28, 0, 26)
    b.Position = UDim2.new(1, offX, 0, 5)
    b.BackgroundColor3 = col
    b.Text = txt
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = titleBar
    mkCorner(6, b)
    
    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = b.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.15)
    end)
    b.MouseLeave:Connect(function()
        b.BackgroundColor3 = col
    end)
    
    return b
end

local hideBtn = mkTitleBtn("−", Color3.fromRGB(60, 92, 205), -64)
local closeBtn = mkTitleBtn("✕", Color3.fromRGB(205, 48, 48), -32)

-- ===== CONTENT =====
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, 0, 1, -36)
contentArea.Position = UDim2.new(0, 0, 0, 36)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainMenuFrame

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 100, 1, -10)
sidebar.Position = UDim2.new(0, 5, 0, 5)
sidebar.BackgroundColor3 = COL_BG3
sidebar.BorderSizePixel = 0
sidebar.Parent = contentArea
mkCorner(8, sidebar)

local sbl = Instance.new("UIListLayout")
sbl.Padding = UDim.new(0, 4)
sbl.SortOrder = Enum.SortOrder.LayoutOrder
sbl.Parent = sidebar
mkPad(4, 4, 4, 4, sidebar)

local panel = Instance.new("Frame")
panel.Size = UDim2.new(1, -110, 1, -10)
panel.Position = UDim2.new(0, 105, 0, 5)
panel.BackgroundColor3 = COL_BG3
panel.BorderSizePixel = 0
panel.Parent = contentArea
mkCorner(8, panel)

-- ===== WIDGET BUILDERS =====
local function makeSection(parent, txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 14)
    l.BackgroundTransparency = 1
    l.Text = "── " .. txt .. " ──"
    l.TextColor3 = COL_ACCENT
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.Parent = parent
end

local function makeToggle(parent, name, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundColor3 = COL_BG2
    f.BorderSizePixel = 0
    f.Parent = parent
    mkCorner(7, f)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.62, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = COL_TEXT
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    
    local pill = Instance.new("TextButton")
    pill.Size = UDim2.new(0, 38, 0, 18)
    pill.Position = UDim2.new(1, -46, 0.5, -9)
    pill.BackgroundColor3 = Color3.fromRGB(48, 48, 68)
    pill.Text = ""
    pill.BorderSizePixel = 0
    pill.Parent = f
    mkCorner(9, pill)
    
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 12, 0, 12)
    dot.Position = UDim2.new(0, 3, 0.5, -6)
    dot.BackgroundColor3 = Color3.fromRGB(155, 155, 180)
    dot.BorderSizePixel = 0
    dot.Parent = pill
    mkCorner(6, dot)
    
    local state = false
    pill.MouseButton1Click:Connect(function()
        state = not state
        pill.BackgroundColor3 = state and Color3.fromRGB(48, 170, 85) or Color3.fromRGB(48, 48, 68)
        dot.Position = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        dot.BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(155, 155, 180)
        if callback then callback(state) end
    end)
end

local function makeSlider(parent, name, mn, mx, def, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 46)
    f.BackgroundColor3 = COL_BG2
    f.BorderSizePixel = 0
    f.Parent = parent
    mkCorner(7, f)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -14, 0, 13)
    lbl.Position = UDim2.new(0, 8, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = name .. ":  " .. def
    lbl.TextColor3 = COL_TEXT
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -16, 0, 4)
    track.Position = UDim2.new(0, 8, 0, 25)
    track.BackgroundColor3 = Color3.fromRGB(36, 36, 56)
    track.BorderSizePixel = 0
    track.Parent = f
    mkCorner(2, track)
    
    local pct = (def - mn) / (mx - mn)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = COL_ACCENT
    fill.BorderSizePixel = 0
    fill.Parent = track
    mkCorner(2, fill)
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(pct, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(185, 205, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 2
    knob.Parent = track
    mkCorner(7, knob)
    
    local sd = false
    local function set(ax)
        local r = math.clamp((ax - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local cur = math.floor(mn + (mx - mn) * r)
        fill.Size = UDim2.new(r, 0, 1, 0)
        knob.Position = UDim2.new(r, -7, 0.5, -7)
        lbl.Text = name .. ":  " .. cur
        if callback then callback(cur) end
    end
    
    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sd = true end
    end)
    
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            sd = true
            set(i.Position.X)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sd = false end
    end)
    
    UserInputService.InputChanged:Connect(function(i)
        if sd and i.UserInputType == Enum.UserInputType.MouseMovement then
            set(i.Position.X)
        end
    end)
end

local function makeDropdown(parent, name, options, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundColor3 = COL_BG2
    f.BorderSizePixel = 0
    f.Parent = parent
    mkCorner(7, f)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = COL_TEXT
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 0, 22)
    btn.Position = UDim2.new(1, -108, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 52)
    btn.Text = default
    btn.TextColor3 = Color3.fromRGB(200, 200, 220)
    btn.TextSize = 10
    btn.Font = Enum.Font.Gotham
    btn.BorderSizePixel = 0
    btn.Parent = f
    mkCorner(5, btn)
    mkStroke(COL_ACCENT, 1, btn)
    
    local currentVal = default
    
    local function showDropdown()
        local dropFrame = Instance.new("Frame")
        dropFrame.Size = UDim2.new(0, 100, 0, #options * 25)
        dropFrame.Position = UDim2.new(1, -108, 1, 5)
        dropFrame.BackgroundColor3 = COL_BG2
        dropFrame.BorderSizePixel = 0
        dropFrame.Parent = f
        dropFrame.ZIndex = 100
        mkCorner(5, dropFrame)
        mkStroke(COL_ACCENT, 1, dropFrame)
        
        local dropLayout = Instance.new("UIListLayout")
        dropLayout.Padding = UDim.new(0, 0)
        dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
        dropLayout.Parent = dropFrame
        
        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 25)
            optBtn.BackgroundColor3 = COL_BG2
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(150, 150, 180)
            optBtn.TextSize = 9
            optBtn.Font = Enum.Font.Gotham
            optBtn.BorderSizePixel = 0
            optBtn.Parent = dropFrame
            
            optBtn.MouseButton1Click:Connect(function()
                currentVal = opt
                btn.Text = opt
                dropFrame:Destroy()
                if callback then callback(opt) end
            end)
            
            optBtn.MouseEnter:Connect(function()
                optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
            end)
            
            optBtn.MouseLeave:Connect(function()
                optBtn.BackgroundColor3 = COL_BG2
            end)
        end
    end
    
    btn.MouseButton1Click:Connect(showDropdown)
end

local function makeKeybind(parent, labelTxt, getKey, setKey)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundColor3 = COL_BG2
    f.BorderSizePixel = 0
    f.Parent = parent
    mkCorner(7, f)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.48, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelTxt
    lbl.TextColor3 = COL_TEXT
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 92, 0, 20)
    btn.Position = UDim2.new(1, -100, 0.5, -10)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 52)
    btn.BorderSizePixel = 0
    btn.Parent = f
    mkCorner(5, btn)
    mkStroke(COL_ACCENT, 1, btn)
    
    local function refresh()
        btn.Text = tostring(getKey()):gsub("Enum.KeyCode.", "")
        btn.TextColor3 = Color3.fromRGB(185, 200, 255)
        btn.TextSize = 10
        btn.Font = Enum.Font.GothamBold
        refreshHint()
    end
    refresh()
    
    local listening = false
    btn.MouseButton1Click:Connect(function()
        if isListeningForKey then return end
        listening = true
        isListeningForKey = true
        btn.Text = "[ press key ]"
        btn.TextColor3 = Color3.fromRGB(255, 195, 75)
    end)
    
    UserInputService.InputBegan:Connect(function(inp, gp)
        if listening and not gp and inp.UserInputType == Enum.UserInputType.Keyboard then
            setKey(inp.KeyCode)
            listening = false
            isListeningForKey = false
            refresh()
        end
    end)
end

local function makeColorPicker(parent, labelTxt, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 72)
    f.BackgroundColor3 = COL_BG2
    f.BorderSizePixel = 0
    f.Parent = parent
    mkCorner(7, f)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 0, 14)
    lbl.Position = UDim2.new(0, 8, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelTxt
    lbl.TextColor3 = COL_TEXT
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    
    local swatch = Instance.new("Frame")
    swatch.Size = UDim2.new(0, 22, 0, 22)
    swatch.Position = UDim2.new(1, -32, 0, 5)
    swatch.BackgroundColor3 = Features.Visual.espColor
    swatch.BorderSizePixel = 0
    swatch.Parent = f
    mkCorner(6, swatch)
    mkStroke(COL_ACCENT, 1, swatch)
    
    local hueBar = Instance.new("Frame")
    hueBar.Size = UDim2.new(1, -16, 0, 14)
    hueBar.Position = UDim2.new(0, 8, 0, 26)
    hueBar.BorderSizePixel = 0
    hueBar.Parent = f
    mkCorner(4, hueBar)
    
    local hg = Instance.new("UIGradient")
    hg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
        ColorSequenceKeypoint.new(0.166, Color3.fromHSV(0.166, 1, 1)),
        ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
        ColorSequenceKeypoint.new(0.666, Color3.fromHSV(0.666, 1, 1)),
        ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
    })
    hg.Parent = hueBar
    
    local hknob = Instance.new("Frame")
    hknob.Size = UDim2.new(0, 10, 1, 4)
    hknob.Position = UDim2.new(0.33, -5, 0, -2)
    hknob.BackgroundColor3 = Color3.new(1, 1, 1)
    hknob.BorderSizePixel = 0
    hknob.ZIndex = 3
    hknob.Parent = hueBar
    mkCorner(3, hknob)
    mkStroke(Color3.new(0, 0, 0), 1, hknob)
    
    local briBar = Instance.new("Frame")
    briBar.Size = UDim2.new(1, -16, 0, 10)
    briBar.Position = UDim2.new(0, 8, 0, 46)
    briBar.BorderSizePixel = 0
    briBar.Parent = f
    mkCorner(4, briBar)
    
    local bg2 = Instance.new("UIGradient")
    bg2.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(1, 1, 1))
    bg2.Parent = briBar
    
    local bknob = Instance.new("Frame")
    bknob.Size = UDim2.new(0, 10, 1, 4)
    bknob.Position = UDim2.new(1, -5, 0, -2)
    bknob.BackgroundColor3 = Color3.new(1, 1, 1)
    bknob.BorderSizePixel = 0
    bknob.ZIndex = 3
    bknob.Parent = briBar
    mkCorner(3, bknob)
    mkStroke(Color3.new(0, 0, 0), 1, bknob)
    
    local hue, bri = 0.33, 1
    local hd, bd = false, false
    
    local function applyColor()
        local col = Color3.fromHSV(hue, 1, bri)
        swatch.BackgroundColor3 = col
        bg2.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(hue, 1, 1))
        if callback then callback(col) end
    end
    
    local function setH(ax)
        hue = math.clamp((ax - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
        hknob.Position = UDim2.new(hue, -5, 0, -2)
        applyColor()
    end
    
    local function setB(ax)
        bri = math.clamp((ax - briBar.AbsolutePosition.X) / briBar.AbsoluteSize.X, 0, 1)
        bknob.Position = UDim2.new(bri, -5, 0, -2)
        applyColor()
    end
    
    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            hd = true
            setH(i.Position.X)
        end
    end)
    
    briBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            bd = true
            setB(i.Position.X)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            hd = false
            bd = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then
            if hd then setH(i.Position.X) end
            if bd then setB(i.Position.X) end
        end
    end)
    
    applyColor()
end

-- ===== TAB SYSTEM =====
local function createTab(tabName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 40)
    btn.Text = tabName
    btn.TextColor3 = Color3.fromRGB(115, 115, 168)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = sidebar
    mkCorner(7, btn)
    
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundColor3 = COL_BG3
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = COL_ACCENT
    sf.CanvasSize = UDim2.new(0, 0, 0, 300)
    sf.Visible = false
    sf.Parent = panel
    mkCorner(8, sf)
    
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = sf
    mkPad(7, 7, 7, 7, sf)
    
    lay.Changed:Connect(function()
        sf.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 14)
    end)
    
    btn.MouseButton1Click:Connect(function()
        for _, c in ipairs(panel:GetChildren()) do
            if c:IsA("ScrollingFrame") then
                c.Visible = false
            end
        end
        sf.Visible = true
        
        for _, b in ipairs(sidebar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = Color3.fromRGB(24, 24, 40)
                b.TextColor3 = Color3.fromRGB(115, 115, 168)
            end
        end
        
        btn.BackgroundColor3 = Color3.fromRGB(65, 105, 210)
        btn.TextColor3 = Color3.new(1, 1, 1)
    end)
    
    return sf, btn
end

local aimbotTab, aimbotBtn = createTab("Aim")
local visualTab, visualBtn = createTab("ESP")
local brutalTab, brutalBtn = createTab("Fun")
local settingsTab, settingsBtn = createTab("⚙")

-- ===== POPULATE TABS =====

-- AIM
makeSection(aimbotTab, "AIMBOT")
makeToggle(aimbotTab, "Aimbot", function(s) Features.Aimbot.enabled = s end)
makeToggle(aimbotTab, "FOV Circle", function(s) Features.Aimbot.fovCircle = s end)
makeSlider(aimbotTab, "FOV Size", 10, 500, 100, function(v) Features.Aimbot.fov = v end)
makeDropdown(aimbotTab, "Lock", {"Head", "Body"}, "Head", function(opt) Features.Aimbot.lockMode = opt end)

-- ESP
makeSection(visualTab, "VISUALS")
makeToggle(visualTab, "Enable ESP", function(s) Features.Visual.espEnabled = s end)
makeToggle(visualTab, "Tracer Line", function(s) Features.Visual.espLine = s end)
makeToggle(visualTab, "ESP Box", function(s) Features.Visual.espBox = s end)
makeToggle(visualTab, "ESP Name", function(s) Features.Visual.espName = s end)
makeToggle(visualTab, "Health Bar", function(s) Features.Visual.espHealthBar = s end)
makeToggle(visualTab, "Chams", function(s) Features.Visual.espChams = s; addChams(player.Character or player.CharacterAdded:Wait(), Features.Visual.espColor) end)
makeToggle(visualTab, "Skeleton", function(s) Features.Visual.skeletonEnabled = s; drawSkeleton(player.Character or player.CharacterAdded:Wait(), Features.Visual.espColor) end)

makeSection(visualTab, "ESP SETTINGS")
makeDropdown(visualTab, "Tracer Pos", {"Top", "Bottom", "Side"}, "Bottom", function(opt) Features.Visual.linePosition = opt end)
makeDropdown(visualTab, "Health Pos", {"Left", "Right", "Top"}, "Left", function(opt) Features.Visual.healthPosition = opt end)

makeSection(visualTab, "COLOR")
makeColorPicker(visualTab, "ESP Color", function(col)
    Features.Visual.espColor = col
    for _, d in pairs(Features.Visual.drawings) do
        d.box.Color = col
        d.tracer.Color = col
        d.nameTag.Color = col
        d.healthFg.Color = col
    end
    updateChamsColor(col)
    if Features.Aimbot.fovGui then
        Features.Aimbot.fovGui.circle.UIStroke.Color = col
    end
end)

-- FUN
makeSection(brutalTab, "MOVEMENT")
makeToggle(brutalTab, "Fly", function(s) Features.Brutal.flyEnabled = s; startFly() end)
makeSlider(brutalTab, "Fly Speed", 10, 200, 50, function(v) Features.Brutal.flySpeed = v end)
makeToggle(brutalTab, "Speed", function(s) Features.Brutal.speedEnabled = s end)
makeSlider(brutalTab, "Speed Value", 10, 200, 50, function(v) Features.Brutal.speedValue = v end)

makeSection(brutalTab, "TELEPORT")
local tpFrame = Instance.new("Frame")
tpFrame.Size = UDim2.new(1, 0, 0, 30)
tpFrame.BackgroundColor3 = COL_BG2
tpFrame.BorderSizePixel = 0
tpFrame.Parent = brutalTab
mkCorner(7, tpFrame)

local tpLbl = Instance.new("TextLabel")
tpLbl.Size = UDim2.new(0.5, 0, 1, 0)
tpLbl.Position = UDim2.new(0, 8, 0, 0)
tpLbl.BackgroundTransparency = 1
tpLbl.Text = "Select Player"
tpLbl.TextColor3 = COL_TEXT
tpLbl.TextSize = 11
tpLbl.Font = Enum.Font.Gotham
tpLbl.TextXAlignment = Enum.TextXAlignment.Left
tpLbl.Parent = tpFrame

local playerDropdown = Instance.new("TextButton")
playerDropdown.Size = UDim2.new(0, 100, 0, 22)
playerDropdown.Position = UDim2.new(1, -108, 0.5, -11)
playerDropdown.BackgroundColor3 = Color3.fromRGB(32, 32, 52)
playerDropdown.Text = "None"
playerDropdown.TextColor3 = Color3.fromRGB(200, 200, 220)
playerDropdown.TextSize = 10
playerDropdown.Font = Enum.Font.Gotham
playerDropdown.BorderSizePixel = 0
playerDropdown.Parent = tpFrame
mkCorner(5, playerDropdown)
mkStroke(COL_ACCENT, 1, playerDropdown)

local selectedPlayer = nil

local function showPlayerList()
    local dropFrame = Instance.new("Frame")
    dropFrame.Size = UDim2.new(0, 100, 0, math.min(#Players:GetPlayers() * 25, 200))
    dropFrame.Position = UDim2.new(1, -108, 1, 5)
    dropFrame.BackgroundColor3 = COL_BG2
    dropFrame.BorderSizePixel = 0
    dropFrame.Parent = tpFrame
    dropFrame.ZIndex = 100
    mkCorner(5, dropFrame)
    mkStroke(COL_ACCENT, 1, dropFrame)
    
    local dropLayout = Instance.new("UIListLayout")
    dropLayout.Padding = UDim.new(0, 0)
    dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropLayout.Parent = dropFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 2
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #Players:GetPlayers() * 25)
    scrollFrame.Parent = dropFrame
    
    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.Padding = UDim.new(0, 0)
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Parent = scrollFrame
    
    for _, op in ipairs(Players:GetPlayers()) do
        if op ~= player then
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 25)
            optBtn.BackgroundColor3 = COL_BG2
            optBtn.Text = op.Name
            optBtn.TextColor3 = Color3.fromRGB(150, 150, 180)
            optBtn.TextSize = 9
            optBtn.Font = Enum.Font.Gotham
            optBtn.BorderSizePixel = 0
            optBtn.Parent = scrollFrame
            
            optBtn.MouseButton1Click:Connect(function()
                selectedPlayer = op
                playerDropdown.Text = op.Name
                dropFrame:Destroy()
                tpToPlayer(op)
            end)
            
            optBtn.MouseEnter:Connect(function()
                optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
            end)
            
            optBtn.MouseLeave:Connect(function()
                optBtn.BackgroundColor3 = COL_BG2
            end)
        end
    end
end

playerDropdown.MouseButton1Click:Connect(showPlayerList)

-- SETTINGS
makeSection(settingsTab, "KEYBINDS")
makeKeybind(settingsTab, "Toggle (hide/show)",
    function() return Features.Keybind.toggle end,
    function(k) Features.Keybind.toggle = k end)
makeKeybind(settingsTab, "Close menu",
    function() return Features.Keybind.close end,
    function(k) Features.Keybind.close = k end)

makeSection(settingsTab, "ACCOUNT")
local logoutRow = Instance.new("Frame")
logoutRow.Size = UDim2.new(1, 0, 0, 30)
logoutRow.BackgroundColor3 = COL_BG2
logoutRow.BorderSizePixel = 0
logoutRow.Parent = settingsTab
mkCorner(7, logoutRow)

local logoutBtn = Instance.new("TextButton")
logoutBtn.Size = UDim2.new(1, -16, 0, 22)
logoutBtn.Position = UDim2.new(0, 8, 0.5, -11)
logoutBtn.BackgroundColor3 = Color3.fromRGB(175, 42, 42)
logoutBtn.Text = "Logout & Clear"
logoutBtn.TextColor3 = Color3.new(1, 1, 1)
logoutBtn.TextSize = 10
logoutBtn.Font = Enum.Font.GothamBold
logoutBtn.BorderSizePixel = 0
logoutBtn.Parent = logoutRow
mkCorner(6, logoutBtn)

logoutBtn.MouseButton1Click:Connect(function()
    clearCredentials()
    mainMenuFrame.Visible = false
    menuIsVisible = false
    loginFrame.Visible = true
    userBox.Text = ""
    passBox.Text = ""
    statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
    statusLbl.Text = "Logged out."
end)

-- Default tab
aimbotBtn:FireEvent("MouseButton1Click")

-- ===== LOGIN LOGIC =====
local function doShowMainMenu()
    loginFrame.Visible = false
    mainMenuFrame.Visible = true
    menuIsVisible = true
end

local function doLogin(username, password)
    if username == "" or password == "" then
        statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        statusLbl.Text = "Please enter username and password."
        return
    end
    
    statusLbl.TextColor3 = Color3.fromRGB(180, 180, 60)
    statusLbl.Text = "Logging in..."
    
    task.spawn(function()
        task.wait(0.3)
        if rememberEnabled then
            saveCredentials(username, password)
        end
        doShowMainMenu()
    end)
end

loginBtn.MouseButton1Click:Connect(function()
    doLogin(getUserText(), getPassText())
end)

-- Auto-login
task.spawn(function()
    local saved = loadCredentials()
    if saved then
        userBox.Text = saved.username
        passBox.Text = string.rep("•", #saved.password)
        statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
        statusLbl.Text = "Auto-logging in..."
        task.wait(0.5)
        doLogin(saved.username, saved.password)
    end
end)

-- ===== BUTTON EVENTS =====
hideBtn.MouseButton1Click:Connect(function()
    toggleMenu()
    hideBtn.Text = menuIsVisible and "−" or "□"
end)

closeBtn.MouseButton1Click:Connect(function()
    cleanAllESP()
    removeChams()
    removeSkeleton()
    screenGui:Destroy()
end)

-- ===== KEYBIND HANDLER =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if isListeningForKey then return end
    
    if input.KeyCode == Features.Keybind.toggle then
        menuIsVisible = not menuIsVisible
        mainMenuFrame.Visible = menuIsVisible
        hideBtn.Text = menuIsVisible and "−" or "□"
    end
    
    if input.KeyCode == Features.Keybind.close then
        cleanAllESP()
        removeChams()
        removeSkeleton()
        screenGui:Destroy()
    end
end)

print("✓ Menu v5 Loaded")
print("✓ All features working!")
