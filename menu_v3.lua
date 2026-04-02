-- ============================================================
--  MENU v3  |  Login + Auto-Login + Perf Fixes + Full ESP
-- ============================================================
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Camera           = workspace.CurrentCamera
local HttpService      = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse     = player:GetMouse()

-- ===== SAVED CREDENTIALS (writefile / readfile exploit API) =====
local SAVE_FILE = "menu_credentials.json"

local function saveCredentials(username, password, rememberMe)
    if not writefile then return end
    local data = HttpService:JSONEncode({
        username   = username,
        password   = password,
        rememberMe = rememberMe
    })
    writefile(SAVE_FILE, data)
end

local function loadCredentials()
    if not readfile or not isfile then return nil end
    if not isfile(SAVE_FILE) then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(SAVE_FILE))
    end)
    if ok and data then return data end
    return nil
end

local function clearCredentials()
    if deletefile then pcall(function() deletefile(SAVE_FILE) end) end
end

-- ===== FEATURE STATE =====
local menuVisible      = true
local isListeningForKey = false

local Features = {
    Aimbot = {
        enabled   = false,
        fovCircle = false,
        fov       = 100,
        fovGui    = nil
    },
    Visual = {
        espEnabled  = false,
        espLine     = false,
        espBox      = false,
        espName     = false,
        espHealthBar= false,
        espChams    = false,
        espColor    = Color3.fromRGB(0, 255, 100),
        drawings    = {}
    },
    Brutal = {
        flyEnabled   = false,
        flySpeed     = 50,
        speedEnabled = false,
        speedValue   = 50,
        bodyVelocity = nil,
        bodyGyro     = nil
    },
    Keybind = {
        toggle = Enum.KeyCode.Insert,
        close  = Enum.KeyCode.Delete
    }
}

-- ===== PART CACHE (perf fix) =====
local partCache = {}
local function getPartsForCharacter(character)
    if partCache[character] then return partCache[character] end
    local parts = {}
    for _, p in ipairs(character:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(parts, p) end
    end
    partCache[character] = parts
    character.AncestryChanged:Connect(function()
        partCache[character] = nil
    end)
    return parts
end

local function getCharacterBounds(character)
    local parts = getPartsForCharacter(character)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = false
    for _, part in ipairs(parts) do
        local s  = part.Size / 2
        local cf = part.CFrame
        local corners = {
            cf*Vector3.new( s.X, s.Y, s.Z), cf*Vector3.new(-s.X, s.Y, s.Z),
            cf*Vector3.new( s.X,-s.Y, s.Z), cf*Vector3.new(-s.X,-s.Y, s.Z),
            cf*Vector3.new( s.X, s.Y,-s.Z), cf*Vector3.new(-s.X, s.Y,-s.Z),
            cf*Vector3.new( s.X,-s.Y,-s.Z), cf*Vector3.new(-s.X,-s.Y,-s.Z),
        }
        for _, corner in ipairs(corners) do
            local sp, onScreen = Camera:WorldToScreenPoint(corner)
            if onScreen then
                visible = true
                minX=math.min(minX,sp.X); minY=math.min(minY,sp.Y)
                maxX=math.max(maxX,sp.X); maxY=math.max(maxY,sp.Y)
            end
        end
    end
    if not visible then return nil end
    return minX, minY, maxX, maxY
end

-- ===== DRAWING HELPERS =====
local function newDrawing(class, props)
    local obj = Drawing.new(class)
    for k,v in pairs(props) do obj[k]=v end
    return obj
end

local function getPlayerDrawings(op)
    local n = op.Name
    if not Features.Visual.drawings[n] then
        Features.Visual.drawings[n] = {
            box      = newDrawing("Square",{Visible=false,Thickness=1.5,Filled=false,Transparency=1,Color=Features.Visual.espColor}),
            tracer   = newDrawing("Line",  {Visible=false,Thickness=1,  Transparency=1,            Color=Features.Visual.espColor}),
            nameTag  = newDrawing("Text",  {Visible=false,Size=13,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Font=2,Color=Color3.new(1,1,1)}),
            healthBg = newDrawing("Square",{Visible=false,Color=Color3.new(0,0,0),Thickness=1,Filled=true,Transparency=0.5}),
            healthFg = newDrawing("Square",{Visible=false,Color=Color3.fromRGB(0,255,80),Thickness=1,Filled=true,Transparency=1}),
        }
    end
    return Features.Visual.drawings[n]
end

local function hidePlayerDrawings(d)
    d.box.Visible=false; d.tracer.Visible=false
    d.nameTag.Visible=false; d.healthBg.Visible=false; d.healthFg.Visible=false
end

local function cleanAllESP()
    for _,d in pairs(Features.Visual.drawings) do hidePlayerDrawings(d) end
end

-- ===== CHAMS (only rebuild on character events, not per-frame) =====
local chamsObjects = {}

local function removeAllChams()
    for _,h in ipairs(chamsObjects) do pcall(function() h:Destroy() end) end
    chamsObjects = {}
end

local function applyChamsToCharacter(character, color)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local h = Instance.new("SelectionBox")
            h.Name              = "ESPCham"
            h.Adornee           = part
            h.Color3            = color
            h.LineThickness     = 0.03
            h.SurfaceTransparency = 0.6
            h.SurfaceColor3     = color
            h.Parent            = part
            table.insert(chamsObjects, h)
        end
    end
end

local function rebuildChams()
    removeAllChams()
    if not Features.Visual.espEnabled or not Features.Visual.espChams then return end
    for _, op in ipairs(Players:GetPlayers()) do
        if op ~= player and op.Character then
            applyChamsToCharacter(op.Character, Features.Visual.espColor)
        end
    end
end

-- Hook character added for chams
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if Features.Visual.espChams and Features.Visual.espEnabled then
            applyChamsToCharacter(char, Features.Visual.espColor)
        end
    end)
end)

-- ===== FOV CIRCLE =====
local function updateFovCircle()
    if Features.Aimbot.fovCircle and not Features.Aimbot.fovGui then
        local sg=Instance.new("ScreenGui"); sg.Name="FOVGui"; sg.ResetOnSpawn=false; sg.DisplayOrder=100; sg.Parent=playerGui
        local fr=Instance.new("Frame"); fr.BackgroundTransparency=1; fr.BorderSizePixel=0; fr.Parent=sg
        local _=Instance.new("UICorner"); _.CornerRadius=UDim.new(1,0); _.Parent=fr
        local us=Instance.new("UIStroke"); us.Color=Features.Visual.espColor; us.Thickness=1.5; us.Parent=fr
        Features.Aimbot.fovGui={gui=sg,circle=fr,stroke=us}
    elseif not Features.Aimbot.fovCircle and Features.Aimbot.fovGui then
        pcall(function() Features.Aimbot.fovGui.gui:Destroy() end)
        Features.Aimbot.fovGui=nil; return
    end
    if Features.Aimbot.fovGui then
        local c=Features.Aimbot.fovGui.circle
        c.Size    =UDim2.new(0,Features.Aimbot.fov*2,0,Features.Aimbot.fov*2)
        c.Position=UDim2.new(0.5,-Features.Aimbot.fov,0.5,-Features.Aimbot.fov)
    end
end

-- ===== AIMBOT =====
local function performAimbot()
    if not Features.Aimbot.enabled then return end
    local closest, closestDist = nil, Features.Aimbot.fov
    for _,op in ipairs(Players:GetPlayers()) do
        if op~=player and op.Character then
            local h=op.Character:FindFirstChild("Head")
            local hum=op.Character:FindFirstChildOfClass("Humanoid")
            if h and hum and hum.Health>0 then
                local sp,onScreen=Camera:WorldToScreenPoint(h.Position)
                local dist=(Vector2.new(sp.X,sp.Y)-Vector2.new(mouse.X,mouse.Y)).Magnitude
                if onScreen and dist<closestDist then closestDist=dist; closest=op end
            end
        end
    end
    if closest and closest.Character then
        local h=closest.Character:FindFirstChild("Head")
        if h then Camera.CFrame=CFrame.new(Camera.CFrame.Position, h.Position) end
    end
end

-- ===== ESP UPDATE (throttled every 3 frames) =====
local espFrame = 0
local function updateESP()
    if not Features.Visual.espEnabled then cleanAllESP(); return end
    local sv  = Camera.ViewportSize
    local col = Features.Visual.espColor

    for _,op in ipairs(Players:GetPlayers()) do
        if op==player then continue end
        local d    = getPlayerDrawings(op)
        local char = op.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then hidePlayerDrawings(d); continue end

        local minX,minY,maxX,maxY = getCharacterBounds(char)
        if not minX then hidePlayerDrawings(d); continue end
        local bw=maxX-minX; local bh=maxY-minY

        d.box.Visible=Features.Visual.espBox; d.box.Color=col
        if Features.Visual.espBox then
            d.box.Position=Vector2.new(minX,minY); d.box.Size=Vector2.new(bw,bh)
        end

        d.tracer.Visible=Features.Visual.espLine; d.tracer.Color=col
        if Features.Visual.espLine then
            d.tracer.From=Vector2.new(sv.X/2,sv.Y)
            d.tracer.To  =Vector2.new(minX+bw/2, maxY)
        end

        d.nameTag.Visible=Features.Visual.espName
        if Features.Visual.espName then
            d.nameTag.Text    =op.Name
            d.nameTag.Position=Vector2.new(minX+bw/2, minY-17)
        end

        if Features.Visual.espHealthBar then
            local hp   = math.clamp(hum.Health/hum.MaxHealth,0,1)
            local barX = minX-7
            local hcol = hp>0.6 and Color3.fromRGB(0,255,80) or (hp>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,50,50))
            d.healthBg.Visible=true; d.healthBg.Position=Vector2.new(barX,minY); d.healthBg.Size=Vector2.new(4,bh)
            d.healthFg.Visible=true; d.healthFg.Color=hcol
            d.healthFg.Position=Vector2.new(barX,minY+bh*(1-hp)); d.healthFg.Size=Vector2.new(4,bh*hp)
        else
            d.healthBg.Visible=false; d.healthFg.Visible=false
        end
    end

    for name,d in pairs(Features.Visual.drawings) do
        if not Players:FindFirstChild(name) then hidePlayerDrawings(d) end
    end
end

-- ===== FLY =====
local function startFly()
    local char=player.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    if Features.Brutal.flyEnabled then
        pcall(function() if Features.Brutal.bodyVelocity then Features.Brutal.bodyVelocity:Destroy() end end)
        pcall(function() if Features.Brutal.bodyGyro     then Features.Brutal.bodyGyro:Destroy()     end end)
        local bv=Instance.new("BodyVelocity"); bv.Velocity=Vector3.new(0,0,0); bv.MaxForce=Vector3.new(1e9,1e9,1e9); bv.Parent=hrp; Features.Brutal.bodyVelocity=bv
        local bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(1e9,1e9,1e9); bg.P=10000; bg.Parent=hrp; Features.Brutal.bodyGyro=bg
        hum.PlatformStand=true
    else
        pcall(function() if Features.Brutal.bodyVelocity then Features.Brutal.bodyVelocity:Destroy() end end)
        pcall(function() if Features.Brutal.bodyGyro     then Features.Brutal.bodyGyro:Destroy()     end end)
        Features.Brutal.bodyVelocity=nil; Features.Brutal.bodyGyro=nil
        hum.PlatformStand=false
    end
end

local function updateFly()
    if not Features.Brutal.flyEnabled then return end
    local char=player.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp or not Features.Brutal.bodyVelocity then return end
    local d=Vector3.new(0,0,0); local spd=Features.Brutal.flySpeed*0.15
    if UserInputService:IsKeyDown(Enum.KeyCode.W)           then d=d+Camera.CFrame.LookVector  end
    if UserInputService:IsKeyDown(Enum.KeyCode.A)           then d=d-Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S)           then d=d-Camera.CFrame.LookVector  end
    if UserInputService:IsKeyDown(Enum.KeyCode.D)           then d=d+Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then d=d+Vector3.new(0,1,0)        end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d=d-Vector3.new(0,1,0)        end
    if d.Magnitude>0 then d=d.Unit end
    Features.Brutal.bodyVelocity.Velocity=d*spd
    if Features.Brutal.bodyGyro then Features.Brutal.bodyGyro.CFrame=Camera.CFrame end
end

local function updateSpeed()
    local char=player.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    hum.WalkSpeed=Features.Brutal.speedEnabled and (16+Features.Brutal.speedValue/10) or 16
end

-- ===== MAIN LOOP (throttled ESP) =====
RunService.RenderStepped:Connect(function()
    updateFovCircle(); performAimbot(); updateFly(); updateSpeed()
    espFrame=espFrame+1
    if espFrame>=3 then espFrame=0; updateESP() end
end)

player.CharacterAdded:Connect(function()
    task.wait(0.1)
    if Features.Brutal.flyEnabled then startFly() end
end)

-- ============================================================
--  GUI UTILITIES
-- ============================================================

local function mkCorner(r, p) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=p end
local function mkStroke(col, th, p) local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=th; s.Parent=p end
local function mkPadding(l,r,t,b,p)
    local pad=Instance.new("UIPadding")
    pad.PaddingLeft=UDim.new(0,l); pad.PaddingRight=UDim.new(0,r)
    pad.PaddingTop=UDim.new(0,t);  pad.PaddingBottom=UDim.new(0,b)
    pad.Parent=p
end

-- Root ScreenGui
local screenGui=Instance.new("ScreenGui")
screenGui.Name="MenuV3"; screenGui.ResetOnSpawn=false; screenGui.DisplayOrder=999; screenGui.Parent=playerGui

-- ============================================================
--  LOGIN SCREEN
-- ============================================================

local loginFrame=Instance.new("Frame")
loginFrame.Size=UDim2.new(0,320,0,310); loginFrame.Position=UDim2.new(0.5,-160,0.5,-155)
loginFrame.BackgroundColor3=Color3.fromRGB(14,14,22); loginFrame.BorderSizePixel=0; loginFrame.Parent=screenGui
mkCorner(14,loginFrame); mkStroke(Color3.fromRGB(80,120,230),1.5,loginFrame)

-- Title
local loginTitle=Instance.new("TextLabel")
loginTitle.Size=UDim2.new(1,0,0,44); loginTitle.BackgroundColor3=Color3.fromRGB(8,8,16); loginTitle.BorderSizePixel=0
loginTitle.Text="✦  LOGIN"; loginTitle.TextColor3=Color3.fromRGB(100,150,255)
loginTitle.TextSize=16; loginTitle.Font=Enum.Font.GothamBold; loginTitle.Parent=loginFrame
mkCorner(14,loginTitle)

-- Status label
local statusLabel=Instance.new("TextLabel")
statusLabel.Size=UDim2.new(1,-30,0,16); statusLabel.Position=UDim2.new(0,15,0,50)
statusLabel.BackgroundTransparency=1; statusLabel.Text=""
statusLabel.TextColor3=Color3.fromRGB(255,80,80); statusLabel.TextSize=10
statusLabel.Font=Enum.Font.Gotham; statusLabel.TextXAlignment=Enum.TextXAlignment.Left
statusLabel.Parent=loginFrame

local function mkInput(placeholderTxt, yPos, masked)
    local bg=Instance.new("Frame")
    bg.Size=UDim2.new(1,-30,0,36); bg.Position=UDim2.new(0,15,0,yPos)
    bg.BackgroundColor3=Color3.fromRGB(22,22,36); bg.BorderSizePixel=0; bg.Parent=loginFrame
    mkCorner(8,bg); mkStroke(Color3.fromRGB(60,80,180),1,bg)
    local box=Instance.new("TextBox")
    box.Size=UDim2.new(1,-16,1,0); box.Position=UDim2.new(0,8,0,0)
    box.BackgroundTransparency=1; box.PlaceholderText=placeholderTxt
    box.PlaceholderColor3=Color3.fromRGB(90,90,120); box.Text=""
    box.TextColor3=Color3.fromRGB(220,220,240); box.TextSize=12
    box.Font=Enum.Font.Gotham; box.TextXAlignment=Enum.TextXAlignment.Left
    if masked then box.TextTransparency=0; end  -- real masking below
    box.Parent=bg
    if masked then
        -- mask with dots by tracking actual value
        local realText=""
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local t=box.Text
            if #t>#realText then
                realText=realText..t:sub(#realText+1)
            elseif #t<#realText then
                realText=realText:sub(1,#t)
            end
            box.Text=string.rep("•",#realText)
            -- put cursor at end
            box.CursorPosition=#box.Text+1
        end)
        -- expose realText via a hidden value
        local rv=Instance.new("StringValue"); rv.Name="RealValue"; rv.Parent=box
        box:GetPropertyChangedSignal("Text"):Connect(function()
            rv.Value=realText
        end)
    end
    return box, bg
end

local userBox,  userBg  = mkInput("Username", 72,  false)
local passBox,  passBg  = mkInput("Password", 116, true)

-- Remember me toggle
local rememberFrame=Instance.new("Frame")
rememberFrame.Size=UDim2.new(1,-30,0,24); rememberFrame.Position=UDim2.new(0,15,0,162)
rememberFrame.BackgroundTransparency=1; rememberFrame.Parent=loginFrame

local rememberCheck=Instance.new("TextButton")
rememberCheck.Size=UDim2.new(0,20,0,20); rememberCheck.Position=UDim2.new(0,0,0.5,-10)
rememberCheck.BackgroundColor3=Color3.fromRGB(30,30,50); rememberCheck.Text=""
rememberCheck.BorderSizePixel=0; rememberCheck.Parent=rememberFrame
mkCorner(4,rememberCheck); mkStroke(Color3.fromRGB(80,120,230),1,rememberCheck)

local checkMark=Instance.new("TextLabel")
checkMark.Size=UDim2.new(1,0,1,0); checkMark.BackgroundTransparency=1
checkMark.Text=""; checkMark.TextColor3=Color3.fromRGB(100,200,120)
checkMark.TextSize=13; checkMark.Font=Enum.Font.GothamBold; checkMark.Parent=rememberCheck

local rememberLabel=Instance.new("TextLabel")
rememberLabel.Size=UDim2.new(1,-28,1,0); rememberLabel.Position=UDim2.new(0,28,0,0)
rememberLabel.BackgroundTransparency=1; rememberLabel.Text="Remember me"
rememberLabel.TextColor3=Color3.fromRGB(170,170,200); rememberLabel.TextSize=11
rememberLabel.Font=Enum.Font.Gotham; rememberLabel.TextXAlignment=Enum.TextXAlignment.Left
rememberLabel.Parent=rememberFrame

local rememberEnabled=false
rememberCheck.MouseButton1Click:Connect(function()
    rememberEnabled=not rememberEnabled
    checkMark.Text=rememberEnabled and "✓" or ""
    rememberCheck.BackgroundColor3=rememberEnabled and Color3.fromRGB(40,120,70) or Color3.fromRGB(30,30,50)
end)

-- Login button
local loginBtn=Instance.new("TextButton")
loginBtn.Size=UDim2.new(1,-30,0,38); loginBtn.Position=UDim2.new(0,15,0,196)
loginBtn.BackgroundColor3=Color3.fromRGB(70,110,220); loginBtn.Text="LOGIN"
loginBtn.TextColor3=Color3.new(1,1,1); loginBtn.TextSize=13; loginBtn.Font=Enum.Font.GothamBold
loginBtn.BorderSizePixel=0; loginBtn.Parent=loginFrame
mkCorner(8,loginBtn)

-- Forgot / clear saved
local clearBtn=Instance.new("TextButton")
clearBtn.Size=UDim2.new(1,-30,0,20); clearBtn.Position=UDim2.new(0,15,0,244)
clearBtn.BackgroundTransparency=1; clearBtn.Text="Clear saved login"
clearBtn.TextColor3=Color3.fromRGB(100,100,140); clearBtn.TextSize=9
clearBtn.Font=Enum.Font.Gotham; clearBtn.BorderSizePixel=0; clearBtn.Parent=loginFrame

clearBtn.MouseButton1Click:Connect(function()
    clearCredentials()
    userBox.Text=""; passBox.Text=""
    local rv=passBox:FindFirstChild("RealValue"); if rv then rv.Value="" end
    statusLabel.TextColor3=Color3.fromRGB(100,200,130)
    statusLabel.Text="Saved login cleared."
end)

-- ===== LOGIN HANDLER =====
-- Replace the body of doLogin with your KeyAuth call.
-- The username and password are passed in as arguments.

local mainMenuFrame  -- forward declare so login handler can show it

local function showMainMenu()
    loginFrame.Visible=false
    mainMenuFrame.Visible=true
end

local function doLogin(username, password)
    if username=="" or password=="" then
        statusLabel.TextColor3=Color3.fromRGB(255,80,80)
        statusLabel.Text="Enter username and password."
        return
    end

    statusLabel.TextColor3=Color3.fromRGB(180,180,80)
    statusLabel.Text="Logging in..."

    -- =====================================================
    -- PASTE YOUR KEYAUTH CALL HERE
    -- Example structure (fill in your own KeyAuth loader):
    --
    --   local KeyAuth = loadstring(game:HttpGet("https://raw.githubusercontent.com/..."))()
    --   KeyAuth:init(name, ownerid, version)
    --   local success, msg = KeyAuth:login(username, password)
    --   if success then
    --       if rememberEnabled then saveCredentials(username, password, true) end
    --       showMainMenu()
    --   else
    --       statusLabel.TextColor3 = Color3.fromRGB(255,80,80)
    --       statusLabel.Text = "Login failed: " .. tostring(msg)
    --   end
    --
    -- For now, a simple placeholder check is used so the menu works:
    -- =====================================================

    -- PLACEHOLDER (remove when you add KeyAuth):
    task.wait(0.4)  -- simulate network delay
    local success = (username ~= "" and password ~= "")
    if success then
        if rememberEnabled then saveCredentials(username, password, true) end
        showMainMenu()
    else
        statusLabel.TextColor3=Color3.fromRGB(255,80,80)
        statusLabel.Text="Invalid credentials."
    end
end

loginBtn.MouseButton1Click:Connect(function()
    local rv=passBox:FindFirstChild("RealValue")
    local realPass = rv and rv.Value or passBox.Text
    doLogin(userBox.Text, realPass)
end)

-- Auto-login if saved
task.spawn(function()
    local saved=loadCredentials()
    if saved and saved.rememberMe and saved.username~="" and saved.password~="" then
        userBox.Text=saved.username
        -- fill masked password display
        local rv=passBox:FindFirstChild("RealValue")
        if rv then rv.Value=saved.password end
        passBox.Text=string.rep("•",#saved.password)
        rememberEnabled=true; checkMark.Text="✓"
        rememberCheck.BackgroundColor3=Color3.fromRGB(40,120,70)
        statusLabel.TextColor3=Color3.fromRGB(100,200,130)
        statusLabel.Text="Auto-logging in..."
        task.wait(0.6)
        doLogin(saved.username, saved.password)
    end
end)

-- ============================================================
--  MAIN MENU (hidden until login succeeds)
-- ============================================================

mainMenuFrame=Instance.new("Frame")
mainMenuFrame.Name="MainFrame"; mainMenuFrame.Size=UDim2.new(0,358,0,475)
mainMenuFrame.Position=UDim2.new(0.05,0,0.1,0); mainMenuFrame.BackgroundColor3=Color3.fromRGB(14,14,22)
mainMenuFrame.BorderSizePixel=0; mainMenuFrame.Visible=false; mainMenuFrame.Parent=screenGui
mkCorner(12,mainMenuFrame); mkStroke(Color3.fromRGB(80,120,230),1.5,mainMenuFrame)

-- Drag (title bar area only)
local dragging,dragStart,framePos=false,Vector2.new(),mainMenuFrame.Position
mainMenuFrame.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 then
        local rel=inp.Position.Y-mainMenuFrame.AbsolutePosition.Y
        if rel<=36 then dragging=true; dragStart=Vector2.new(inp.Position.X,inp.Position.Y); framePos=mainMenuFrame.Position end
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
        local d=Vector2.new(inp.Position.X,inp.Position.Y)-dragStart
        mainMenuFrame.Position=UDim2.new(framePos.X.Scale,framePos.X.Offset+d.X,framePos.Y.Scale,framePos.Y.Offset+d.Y)
    end
end)

-- Title bar
local titleBar=Instance.new("Frame")
titleBar.Size=UDim2.new(1,0,0,36); titleBar.BackgroundColor3=Color3.fromRGB(8,8,16)
titleBar.BorderSizePixel=0; titleBar.Parent=mainMenuFrame
mkCorner(12,titleBar)

local titleLbl=Instance.new("TextLabel")
titleLbl.Size=UDim2.new(0.55,0,1,0); titleLbl.Position=UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency=1; titleLbl.Text="✦  MENU v3"
titleLbl.TextColor3=Color3.fromRGB(100,150,255); titleLbl.TextSize=13
titleLbl.Font=Enum.Font.GothamBold; titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=titleBar

local function mkBtn(txt,col,offX)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(0,28,0,26); b.Position=UDim2.new(1,offX,0,5)
    b.BackgroundColor3=col; b.Text=txt; b.TextColor3=Color3.new(1,1,1)
    b.TextSize=14; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0; b.Parent=titleBar
    mkCorner(6,b); return b
end
local hideBtn  = mkBtn("−",Color3.fromRGB(65,95,210),-64)
local closeBtn = mkBtn("✕",Color3.fromRGB(210,50,50),-32)

-- Content area
local contentArea=Instance.new("Frame")
contentArea.Size=UDim2.new(1,0,1,-36); contentArea.Position=UDim2.new(0,0,0,36)
contentArea.BackgroundTransparency=1; contentArea.Parent=mainMenuFrame

-- Sidebar
local sidebar=Instance.new("Frame")
sidebar.Size=UDim2.new(0,92,1,-10); sidebar.Position=UDim2.new(0,5,0,5)
sidebar.BackgroundColor3=Color3.fromRGB(10,10,18); sidebar.BorderSizePixel=0; sidebar.Parent=contentArea
mkCorner(8,sidebar)
local sbl=Instance.new("UIListLayout"); sbl.Padding=UDim.new(0,4); sbl.SortOrder=Enum.SortOrder.LayoutOrder; sbl.Parent=sidebar
mkPadding(4,4,4,4,sidebar)

-- Panel
local panel=Instance.new("Frame")
panel.Size=UDim2.new(1,-102,1,-10); panel.Position=UDim2.new(0,97,0,5)
panel.BackgroundColor3=Color3.fromRGB(10,10,18); panel.BorderSizePixel=0; panel.Parent=contentArea
mkCorner(8,panel)

-- ===== WIDGET BUILDERS =====

local function makeSection(parent,txt)
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,14); l.BackgroundTransparency=1
    l.Text="── "..txt.." ──"; l.TextColor3=Color3.fromRGB(80,120,230); l.TextSize=9
    l.Font=Enum.Font.GothamBold; l.Parent=parent
end

local function makeToggle(parent,name,callback)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,30); f.BackgroundColor3=Color3.fromRGB(20,20,34); f.BorderSizePixel=0; f.Parent=parent
    mkCorner(7,f)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.62,0,1,0); lbl.Position=UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=name; lbl.TextColor3=Color3.fromRGB(195,195,215)
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local pill=Instance.new("TextButton"); pill.Size=UDim2.new(0,38,0,18); pill.Position=UDim2.new(1,-46,0.5,-9)
    pill.BackgroundColor3=Color3.fromRGB(50,50,70); pill.Text=""; pill.BorderSizePixel=0; pill.Parent=f
    mkCorner(9,pill)
    local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,12,0,12); dot.Position=UDim2.new(0,3,0.5,-6)
    dot.BackgroundColor3=Color3.fromRGB(160,160,185); dot.BorderSizePixel=0; dot.Parent=pill; mkCorner(6,dot)
    local state=false
    pill.MouseButton1Click:Connect(function()
        state=not state
        pill.BackgroundColor3=state and Color3.fromRGB(50,175,90) or Color3.fromRGB(50,50,70)
        dot.Position=state and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
        dot.BackgroundColor3=state and Color3.new(1,1,1) or Color3.fromRGB(160,160,185)
        if callback then callback(state) end
    end)
end

local function makeSlider(parent,name,mn,mx,def,callback)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,46); f.BackgroundColor3=Color3.fromRGB(20,20,34); f.BorderSizePixel=0; f.Parent=parent
    mkCorner(7,f)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-14,0,13); lbl.Position=UDim2.new(0,8,0,4)
    lbl.BackgroundTransparency=1; lbl.Text=name..":  "..def; lbl.TextColor3=Color3.fromRGB(195,195,215)
    lbl.TextSize=10; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local track=Instance.new("Frame"); track.Size=UDim2.new(1,-16,0,4); track.Position=UDim2.new(0,8,0,25)
    track.BackgroundColor3=Color3.fromRGB(38,38,58); track.BorderSizePixel=0; track.Parent=f; mkCorner(2,track)
    local pct=(def-mn)/(mx-mn)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new(pct,0,1,0); fill.BackgroundColor3=Color3.fromRGB(80,120,230); fill.BorderSizePixel=0; fill.Parent=track; mkCorner(2,fill)
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,14,0,14); knob.Position=UDim2.new(pct,-7,0.5,-7)
    knob.BackgroundColor3=Color3.fromRGB(190,210,255); knob.BorderSizePixel=0; knob.ZIndex=2; knob.Parent=track; mkCorner(7,knob)
    local sd=false
    local function set(ax)
        local r=math.clamp((ax-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local cur=math.floor(mn+(mx-mn)*r)
        fill.Size=UDim2.new(r,0,1,0); knob.Position=UDim2.new(r,-7,0.5,-7)
        lbl.Text=name..":  "..cur; if callback then callback(cur) end
    end
    knob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sd=true end end)
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sd=true; set(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sd=false end end)
    UserInputService.InputChanged:Connect(function(i) if sd and i.UserInputType==Enum.UserInputType.MouseMovement then set(i.Position.X) end end)
end

local function makeKeybind(parent,labelTxt,getKey,setKey)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,30); f.BackgroundColor3=Color3.fromRGB(20,20,34); f.BorderSizePixel=0; f.Parent=parent
    mkCorner(7,f)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.5,0,1,0); lbl.Position=UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=labelTxt; lbl.TextColor3=Color3.fromRGB(195,195,215)
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,90,0,20); btn.Position=UDim2.new(1,-98,0.5,-10)
    btn.BackgroundColor3=Color3.fromRGB(35,35,58); btn.BorderSizePixel=0; btn.Parent=f
    mkCorner(5,btn); mkStroke(Color3.fromRGB(80,120,230),1,btn)
    local function refresh()
        btn.Text=tostring(getKey()):gsub("Enum.KeyCode.","")
        btn.TextColor3=Color3.fromRGB(190,200,255); btn.TextSize=10; btn.Font=Enum.Font.GothamBold
    end; refresh()
    local listening=false
    btn.MouseButton1Click:Connect(function()
        if isListeningForKey then return end
        listening=true; isListeningForKey=true
        btn.Text="[press key]"; btn.TextColor3=Color3.fromRGB(255,200,80)
    end)
    UserInputService.InputBegan:Connect(function(inp,gp)
        if listening and not gp and inp.UserInputType==Enum.UserInputType.Keyboard then
            setKey(inp.KeyCode); listening=false; isListeningForKey=false; refresh()
        end
    end)
end

local function makeColorPicker(parent, labelTxt, callback)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,72); f.BackgroundColor3=Color3.fromRGB(20,20,34); f.BorderSizePixel=0; f.Parent=parent
    mkCorner(7,f)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.6,0,0,14); lbl.Position=UDim2.new(0,8,0,5)
    lbl.BackgroundTransparency=1; lbl.Text=labelTxt; lbl.TextColor3=Color3.fromRGB(195,195,215)
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f

    local swatch=Instance.new("Frame"); swatch.Size=UDim2.new(0,22,0,22); swatch.Position=UDim2.new(1,-32,0,5)
    swatch.BackgroundColor3=Features.Visual.espColor; swatch.BorderSizePixel=0; swatch.Parent=f
    mkCorner(6,swatch); mkStroke(Color3.fromRGB(80,120,230),1,swatch)

    -- Hue bar
    local hueBar=Instance.new("Frame"); hueBar.Size=UDim2.new(1,-16,0,14); hueBar.Position=UDim2.new(0,8,0,26)
    hueBar.BorderSizePixel=0; hueBar.Parent=f; mkCorner(4,hueBar)
    local hGrad=Instance.new("UIGradient")
    hGrad.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromHSV(0,   1,1)),
        ColorSequenceKeypoint.new(0.166,Color3.fromHSV(0.166,1,1)),
        ColorSequenceKeypoint.new(0.333,Color3.fromHSV(0.333,1,1)),
        ColorSequenceKeypoint.new(0.5,  Color3.fromHSV(0.5, 1,1)),
        ColorSequenceKeypoint.new(0.666,Color3.fromHSV(0.666,1,1)),
        ColorSequenceKeypoint.new(0.833,Color3.fromHSV(0.833,1,1)),
        ColorSequenceKeypoint.new(1,    Color3.fromHSV(1,   1,1)),
    }); hGrad.Parent=hueBar
    local hknob=Instance.new("Frame"); hknob.Size=UDim2.new(0,10,1,4); hknob.Position=UDim2.new(0,-5,0,-2)
    hknob.BackgroundColor3=Color3.new(1,1,1); hknob.BorderSizePixel=0; hknob.ZIndex=3; hknob.Parent=hueBar
    mkCorner(3,hknob); mkStroke(Color3.new(0,0,0),1,hknob)

    -- Brightness bar
    local briBar=Instance.new("Frame"); briBar.Size=UDim2.new(1,-16,0,10); briBar.Position=UDim2.new(0,8,0,46)
    briBar.BorderSizePixel=0; briBar.Parent=f; mkCorner(4,briBar)
    local bGrad=Instance.new("UIGradient"); bGrad.Color=ColorSequence.new(Color3.new(0,0,0),Color3.new(1,1,1)); bGrad.Parent=briBar
    local bknob=Instance.new("Frame"); bknob.Size=UDim2.new(0,10,1,4); bknob.Position=UDim2.new(1,-5,0,-2)
    bknob.BackgroundColor3=Color3.new(1,1,1); bknob.BorderSizePixel=0; bknob.ZIndex=3; bknob.Parent=briBar
    mkCorner(3,bknob); mkStroke(Color3.new(0,0,0),1,bknob)

    local hue,bri=0.33,1
    local hueDrag,briDrag=false,false

    local function applyColor()
        local col=Color3.fromHSV(hue,1,bri)
        swatch.BackgroundColor3=col
        bGrad.Color=ColorSequence.new(Color3.new(0,0,0),Color3.fromHSV(hue,1,1))
        if callback then callback(col) end
    end

    local function setHue(ax)
        hue=math.clamp((ax-hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X,0,1)
        hknob.Position=UDim2.new(hue,-5,0,-2); applyColor()
    end
    local function setBri(ax)
        bri=math.clamp((ax-briBar.AbsolutePosition.X)/briBar.AbsoluteSize.X,0,1)
        bknob.Position=UDim2.new(bri,-5,0,-2); applyColor()
    end

    hueBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then hueDrag=true; setHue(i.Position.X) end end)
    briBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then briDrag=true; setBri(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then hueDrag=false; briDrag=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement then
            if hueDrag then setHue(i.Position.X) end
            if briDrag then setBri(i.Position.X) end
        end
    end)
    applyColor()
end

-- ===== TAB CREATOR =====
local function createTab(tabName)
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,0,34)
    btn.BackgroundColor3=Color3.fromRGB(26,26,42); btn.Text=tabName
    btn.TextColor3=Color3.fromRGB(120,120,175); btn.TextSize=11; btn.Font=Enum.Font.GothamBold
    btn.BorderSizePixel=0; btn.Parent=sidebar; mkCorner(7,btn)

    local sf=Instance.new("ScrollingFrame"); sf.Size=UDim2.new(1,0,1,0)
    sf.BackgroundColor3=Color3.fromRGB(10,10,18); sf.BorderSizePixel=0
    sf.ScrollBarThickness=3; sf.ScrollBarImageColor3=Color3.fromRGB(80,120,230)
    sf.CanvasSize=UDim2.new(0,0,0,300); sf.Visible=false; sf.Parent=panel; mkCorner(8,sf)
    local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,6); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=sf
    mkPadding(7,7,7,7,sf)
    lay.Changed:Connect(function() sf.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+14) end)

    btn.MouseButton1Click:Connect(function()
        for _,c in ipairs(panel:GetChildren()) do if c:IsA("ScrollingFrame") then c.Visible=false end end
        sf.Visible=true
        for _,b in ipairs(sidebar:GetChildren()) do
            if b:IsA("TextButton") then b.BackgroundColor3=Color3.fromRGB(26,26,42); b.TextColor3=Color3.fromRGB(120,120,175) end
        end
        btn.BackgroundColor3=Color3.fromRGB(70,110,215); btn.TextColor3=Color3.new(1,1,1)
    end)
    return sf, btn
end

local aimbotTab, aimbotBtn   = createTab("Aim")
local visualTab,  visualBtn  = createTab("ESP")
local brutalTab,  brutalBtn  = createTab("Fun")
local settingsTab,settingsBtn= createTab("⚙")

-- ===== POPULATE TABS =====

-- AIM
makeSection(aimbotTab,"AIMBOT")
makeToggle(aimbotTab,"Aimbot",          function(s) Features.Aimbot.enabled=s end)
makeToggle(aimbotTab,"FOV Circle",      function(s) Features.Aimbot.fovCircle=s end)
makeSlider(aimbotTab,"FOV Size",10,500,100,function(v) Features.Aimbot.fov=v end)

-- ESP
makeSection(visualTab,"VISUALS")
makeToggle(visualTab,"Enable ESP",      function(s) Features.Visual.espEnabled=s end)
makeToggle(visualTab,"Tracer Line",     function(s) Features.Visual.espLine=s end)
makeToggle(visualTab,"ESP Box",         function(s) Features.Visual.espBox=s end)
makeToggle(visualTab,"ESP Name",        function(s) Features.Visual.espName=s end)
makeToggle(visualTab,"Health Bar",      function(s) Features.Visual.espHealthBar=s end)
makeToggle(visualTab,"Chams",           function(s) Features.Visual.espChams=s; rebuildChams() end)
makeSection(visualTab,"ESP COLOR")
makeColorPicker(visualTab,"ESP Color",function(col)
    Features.Visual.espColor=col
    for _,d in pairs(Features.Visual.drawings) do d.box.Color=col; d.tracer.Color=col end
    rebuildChams()
end)

-- FUN
makeSection(brutalTab,"MOVEMENT")
makeToggle(brutalTab,"Fly",             function(s) Features.Brutal.flyEnabled=s; startFly() end)
makeSlider(brutalTab,"Fly Speed",10,200,50,function(v) Features.Brutal.flySpeed=v end)
makeToggle(brutalTab,"Speed",           function(s) Features.Brutal.speedEnabled=s end)
makeSlider(brutalTab,"Speed Value",10,200,50,function(v) Features.Brutal.speedValue=v end)

-- SETTINGS
makeSection(settingsTab,"KEYBINDS")
makeKeybind(settingsTab,"Toggle Menu",
    function() return Features.Keybind.toggle end,
    function(k) Features.Keybind.toggle=k end)
makeKeybind(settingsTab,"Close Menu",
    function() return Features.Keybind.close end,
    function(k) Features.Keybind.close=k end)
makeSection(settingsTab,"ACCOUNT")
-- Logout button
local logoutF=Instance.new("Frame"); logoutF.Size=UDim2.new(1,0,0,30); logoutF.BackgroundColor3=Color3.fromRGB(20,20,34); logoutF.BorderSizePixel=0; logoutF.Parent=settingsTab; mkCorner(7,logoutF)
local logoutBtn=Instance.new("TextButton"); logoutBtn.Size=UDim2.new(1,-16,0,22); logoutBtn.Position=UDim2.new(0,8,0.5,-11)
logoutBtn.BackgroundColor3=Color3.fromRGB(180,45,45); logoutBtn.Text="Logout & Clear Saved Login"
logoutBtn.TextColor3=Color3.new(1,1,1); logoutBtn.TextSize=10; logoutBtn.Font=Enum.Font.GothamBold
logoutBtn.BorderSizePixel=0; logoutBtn.Parent=logoutF; mkCorner(6,logoutBtn)
logoutBtn.MouseButton1Click:Connect(function()
    clearCredentials()
    mainMenuFrame.Visible=false
    loginFrame.Visible=true
    userBox.Text=""; passBox.Text=""
    local rv=passBox:FindFirstChild("RealValue"); if rv then rv.Value="" end
    statusLabel.TextColor3=Color3.fromRGB(100,200,130); statusLabel.Text="Logged out."
end)

-- Default tab
aimbotBtn:FireEvent("MouseButton1Click")

-- ===== CLOSE / HIDE =====
local function doClose()
    cleanAllESP(); removeAllChams()
    for _,d in pairs(Features.Visual.drawings) do
        for _,obj in pairs(d) do pcall(function() obj:Remove() end) end
    end
    if Features.Aimbot.fovGui then pcall(function() Features.Aimbot.fovGui.gui:Destroy() end) end
    screenGui:Destroy()
end

local function toggleMenu()
    menuVisible=not menuVisible
    mainMenuFrame.Visible=menuVisible and not loginFrame.Visible
    hideBtn.Text=menuVisible and "−" or "□"
end

closeBtn.MouseButton1Click:Connect(doClose)
hideBtn.MouseButton1Click:Connect(toggleMenu)

UserInputService.InputBegan:Connect(function(inp,gp)
    if gp or isListeningForKey then return end
    if inp.UserInputType==Enum.UserInputType.Keyboard then
        if inp.KeyCode==Features.Keybind.toggle then toggleMenu() end
        if inp.KeyCode==Features.Keybind.close  then doClose()    end
    end
end)

print("✓ Menu v3 loaded  |  Login screen shown")
print("✓ INSERT=toggle  DELETE=close  (changeable in ⚙ tab)")
print("✓ Paste your KeyAuth call inside doLogin() where marked")
