-- Onetap ReCoded | Fixed & Cleaned
-- Authors: x2zu

-- ============================================================
-- SERVICES & CORE
-- ============================================================
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer    = Players.LocalPlayer

-- ============================================================
-- ESP LIBRARY
-- ============================================================
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/CewhoBey/actyxtest/refs/heads/main/library.lua"))()

ESP.Enabled          = false
ESP.ShowBox          = false
ESP.ShowName         = false
ESP.ShowHealth       = false
ESP.ShowTracer       = false
ESP.ShowDistance     = false
ESP.ShowSkeletons    = false
ESP.TeamCheck        = false
ESP.BoxType          = "2D"
ESP.TracerPosition   = "Bottom"

-- ============================================================
-- AIMBOT STATE
-- ============================================================
local aimbotEnabled     = false
local aimAtPart         = "HumanoidRootPart"
local wallCheckEnabled  = false
local targetNPCs        = false
local teamCheckEnabled  = false
local infiniteJump      = false
local aimbotConnection  = nil
local aimbotFOV         = 180 -- max screen radius in pixels (0 = unlimited)
local smoothAim         = false
local smoothness        = 0.2  -- lerp factor (lower = smoother)
local aimKeyOnly        = false -- only aim when RMB held
local aimPrediction     = false

-- Misc state
local noclipEnabled     = false
local flyEnabled        = false
local flySpeed          = 50
local antiaafkEnabled   = false
local fullbrightEnabled = false
local noclipConnection  = nil
local flyConnection     = nil
local antiaafkConnection = nil
local autoHealEnabled   = false
local autoHealConnection = nil
local lagSwitchEnabled  = false
local chamsEnabled      = false
local chamsColor        = Color3.fromRGB(255, 0, 0)
local chamsCache        = {} -- player -> {parts -> original color}
local clickTeleportConn = nil
local clickTeleportEnabled = false

-- FOV circle drawing
local fovCircle = Drawing.new("Circle")
fovCircle.Visible    = false
fovCircle.Color      = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness  = 1
fovCircle.Transparency = 0.6
fovCircle.NumSides   = 64
fovCircle.Filled     = false

-- Custom crosshair drawings
local crosshairEnabled = false
local chLines = {
    Drawing.new("Line"), Drawing.new("Line"),
    Drawing.new("Line"), Drawing.new("Line"),
}
for _, l in ipairs(chLines) do
    l.Color       = Color3.fromRGB(255, 255, 255)
    l.Thickness   = 1
    l.Transparency = 1
    l.Visible     = false
end

-- ============================================================
-- MISC LOGIC
-- ============================================================
local function startNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection = RunService.Stepped:Connect(function()
        if not noclipEnabled then
            noclipConnection:Disconnect()
            noclipConnection = nil
            return
        end
        local char = localPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function startFly()
    if flyConnection then flyConnection:Disconnect() end
    local char = localPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(0, 0, 0)
    bg.Parent = hrp
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = hrp

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyEnabled then
            flyConnection:Disconnect()
            flyConnection = nil
            hum.PlatformStand = false
            bg:Destroy()
            bv:Destroy()
            return
        end
        local Cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
        bv.Velocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
    end)
end

local function setFullbright(enabled)
    local lighting = game:GetService("Lighting")
    if enabled then
        lighting.Brightness = 2
        lighting.ClockTime = 14
        lighting.FogEnd = 100000
        lighting.GlobalShadows = false
        lighting.Ambient = Color3.fromRGB(255, 255, 255)
    else
        lighting.Brightness = 1
        lighting.ClockTime = 14
        lighting.FogEnd = 100000
        lighting.GlobalShadows = true
        lighting.Ambient = Color3.fromRGB(127, 127, 127)
    end
end

-- ============================================================
-- AIMBOT: GET CLOSEST TARGET (FOV-based)
-- ============================================================
local function getClosestTarget()
    local Cam         = workspace.CurrentCamera
    local character   = localPlayer.Character
    if not character then return nil end
    local localRoot   = character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end

    local nearestTarget   = nil
    local shortestDistance = math.huge
    local center = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)

    local function checkTarget(target)
        if not (target and target ~= character) then return end
        if not (target:IsA("Model") and target:FindFirstChildOfClass("Humanoid") and target:FindFirstChild(aimAtPart)) then return end

        local humanoid = target:FindFirstChildOfClass("Humanoid")
        if humanoid.Health <= 0 then return end

        local targetRoot = target[aimAtPart]
        local dist = (targetRoot.Position - localRoot.Position).Magnitude

        if dist >= shortestDistance then return end

        -- FOV check: only target within screen radius
        if aimbotFOV > 0 then
            local screenPos, onScreen = Cam:WorldToViewportPoint(targetRoot.Position)
            if not onScreen then return end
            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if screenDist > aimbotFOV then return end
        end

        if wallCheckEnabled then
            local rayDir    = (targetRoot.Position - Cam.CFrame.Position).Unit * 1000
            local params    = RaycastParams.new()
            params.FilterDescendantsInstances = {character}
            params.FilterType = Enum.RaycastFilterType.Blacklist
            local result = workspace:Raycast(Cam.CFrame.Position, rayDir, params)
            if not (result and result.Instance:IsDescendantOf(target)) then return end
        end

        shortestDistance = dist
        nearestTarget    = target
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local check = (not teamCheckEnabled) or (player.Team ~= localPlayer.Team)
            if check and player.Character then
                checkTarget(player.Character)
            end
        end
    end

    if targetNPCs then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                checkTarget(obj)
            end
        end
    end

    return nearestTarget
end

-- ============================================================
-- AIMBOT: LOOK AT
-- ============================================================
local function lookAt(targetPosition)
    local Cam = workspace.CurrentCamera
    if targetPosition then
        Cam.CFrame = CFrame.new(Cam.CFrame.Position, targetPosition)
    end
end

-- ============================================================
-- AIMBOT: START / STOP
-- ============================================================
local function startAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end

    aimbotConnection = RunService.RenderStepped:Connect(function()
        if not aimbotEnabled then
            aimbotConnection:Disconnect()
            aimbotConnection = nil
            return
        end

        -- Aim key check
        if aimKeyOnly and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            return
        end

        local target = getClosestTarget()
        if target and target:FindFirstChild(aimAtPart) then
            local humanoid = target:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local Cam = workspace.CurrentCamera
                local targetRoot = target[aimAtPart]
                local aimPos = targetRoot.Position

                -- Aim prediction: lead target by velocity * offset
                if aimPrediction then
                    local vel = targetRoot.AssemblyLinearVelocity
                    local dist = (targetRoot.Position - Cam.CFrame.Position).Magnitude
                    local travelTime = dist / 300 -- rough bullet travel estimate
                    aimPos = aimPos + vel * travelTime
                end

                if smoothAim then
                    local targetCF = CFrame.new(Cam.CFrame.Position, aimPos)
                    Cam.CFrame = Cam.CFrame:Lerp(targetCF, smoothness)
                else
                    lookAt(aimPos)
                end
            end
        end
    end)
end

-- ============================================================
-- FOV CIRCLE + CROSSHAIR UPDATE LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    local Cam = workspace.CurrentCamera
    local cx = Cam.ViewportSize.X / 2
    local cy = Cam.ViewportSize.Y / 2

    -- FOV circle
    fovCircle.Position = Vector2.new(cx, cy)
    fovCircle.Radius   = aimbotFOV

    -- Crosshair (4-line plus sign)
    local size = 10
    local gap  = 4
    if crosshairEnabled then
        -- left
        chLines[1].From = Vector2.new(cx - size - gap, cy)
        chLines[1].To   = Vector2.new(cx - gap, cy)
        -- right
        chLines[2].From = Vector2.new(cx + gap, cy)
        chLines[2].To   = Vector2.new(cx + size + gap, cy)
        -- up
        chLines[3].From = Vector2.new(cx, cy - size - gap)
        chLines[3].To   = Vector2.new(cx, cy - gap)
        -- down
        chLines[4].From = Vector2.new(cx, cy + gap)
        chLines[4].To   = Vector2.new(cx, cy + size + gap)
        for _, l in ipairs(chLines) do l.Visible = true end
    else
        for _, l in ipairs(chLines) do l.Visible = false end
    end
end)

-- ============================================================
-- ANTI-AFK
-- ============================================================
local VirtualUser = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    if antiaafkEnabled then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

-- ============================================================
-- CHAMS
-- ============================================================
local function applyChams(enabled)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    if enabled then
                        part.Material = Enum.Material.Neon
                        part.Color = chamsColor
                    else
                        part.Material = Enum.Material.SmoothPlastic
                    end
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not chamsEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Material = Enum.Material.Neon
                    part.Color = chamsColor
                end
            end
        end
    end
end)

-- ============================================================
-- AUTO-HEAL [RISKY — server may detect rapid health changes]
-- ============================================================
local function startAutoHeal()
    if autoHealConnection then autoHealConnection:Disconnect() end
    autoHealConnection = RunService.Heartbeat:Connect(function()
        if not autoHealEnabled then
            autoHealConnection:Disconnect()
            autoHealConnection = nil
            return
        end
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
end

-- ============================================================
-- CLICK TELEPORT [RISKY — position changes are server-visible]
-- ============================================================
local function startClickTeleport()
    if clickTeleportConn then clickTeleportConn:Disconnect() end
    clickTeleportConn = UserInputService.InputBegan:Connect(function(input, processed)
        if not clickTeleportEnabled or processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local unitRay = workspace.CurrentCamera:ScreenPointToRay(
            UserInputService:GetMouseLocation().X,
            UserInputService:GetMouseLocation().Y
        )
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {localPlayer.Character}
        params.FilterType = Enum.RaycastFilterType.Blacklist
        local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
        if result then
            local char = localPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
            end
        end
    end)
end

-- ============================================================
-- PLAYER JOIN/LEAVE NOTIFICATIONS
-- ============================================================
local notifyJoinLeave = false
Players.PlayerAdded:Connect(function(player)
    if notifyJoinLeave then
        -- Rayfield may not be available yet at this point so we guard
        task.delay(0.5, function()
            if Rayfield then
                Rayfield:Notify({ Title = "Player Joined", Content = player.Name .. " joined the game.", Duration = 4 })
            end
        end)
    end
end)
Players.PlayerRemoving:Connect(function(player)
    if notifyJoinLeave then
        if Rayfield then
            Rayfield:Notify({ Title = "Player Left", Content = player.Name .. " left the game.", Duration = 4 })
        end
    end
end)

-- ============================================================
-- HEAD RESIZE
-- ============================================================
local function resizeHeads()
    local function resizeHead(model)
        local head = model:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            head.Size = Vector3.new(5, 5, 5)
            head.CanCollide = false
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            resizeHead(player.Character)
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Head") and not Players:GetPlayerFromCharacter(obj) then
            resizeHead(obj)
        end
    end
end

-- ============================================================
-- INFINITE JUMP
-- ============================================================
UserInputService.JumpRequest:Connect(function()
    if infiniteJump then
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- ============================================================
-- RAYFIELD UI
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/CewhoBey/actyxtest/refs/heads/main/RAYFIELD-ui.lua'))()

local Window = Rayfield:CreateWindow({
    Name             = "Onetap ReCoded",
    Icon             = 0,
    LoadingTitle     = "Onetap ReCoded",
    LoadingSubtitle  = "by actyx",
    Theme            = "Ocean",

    DisableRayfieldPrompts  = false,
    DisableBuildWarnings    = false,

    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "OnetapReCoded",
        FileName   = "Config"
    },

    Discord = {
        Enabled = false,
        Invite  = "",
        RememberJoins = true
    },

    KeySystem = false,
})

-- ============================================================
-- TAB: AIMBOT
-- ============================================================
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
AimbotTab:CreateSection("Settings")

AimbotTab:CreateButton({
    Name     = "Silent Aim (by actyx)",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/CewhoBey/actyxtest/refs/heads/main/silent.lua'))()
    end,
})

AimbotTab:CreateToggle({
    Name         = "Aimbot",
    CurrentValue = false,
    Flag         = "AimbotEnabled",
    Callback     = function(Value)
        aimbotEnabled = Value
        if aimbotEnabled then
            startAimbot()
        end
    end,
})

AimbotTab:CreateButton({
    Name     = "Switch Aim Part (HRP <-> Head)",
    Callback = function()
        aimAtPart = (aimAtPart == "HumanoidRootPart") and "Head" or "HumanoidRootPart"
        Rayfield:Notify({
            Title    = "Aim Part Changed",
            Content  = "Now aiming at: " .. aimAtPart,
            Duration = 4,
        })
    end,
})

AimbotTab:CreateToggle({
    Name         = "Wall Check",
    CurrentValue = false,
    Flag         = "AimbotWallCheck",
    Callback     = function(Value)
        wallCheckEnabled = Value
    end,
})

AimbotTab:CreateToggle({
    Name         = "Team Check",
    CurrentValue = false,
    Flag         = "AimbotTeamCheck",
    Callback     = function(Value)
        teamCheckEnabled = Value
    end,
})

AimbotTab:CreateToggle({
    Name         = "Target NPCs",
    CurrentValue = false,
    Flag         = "AimbotTargetNPCs",
    Callback     = function(Value)
        targetNPCs = Value
    end,
})

AimbotTab:CreateSection("Advanced")

AimbotTab:CreateToggle({
    Name         = "Smooth Aim",
    CurrentValue = false,
    Flag         = "AimbotSmoothAim",
    Callback     = function(Value)
        smoothAim = Value
    end,
})

AimbotTab:CreateSlider({
    Name         = "Smoothness",
    Range        = {1, 20},
    Increment    = 1,
    Suffix       = "",
    CurrentValue = 4,
    Flag         = "AimbotSmoothness",
    Callback     = function(Value)
        smoothness = Value / 20  -- convert 1-20 to 0.05-1.0
    end,
})

AimbotTab:CreateToggle({
    Name         = "Aim Key (RMB Only)",
    CurrentValue = false,
    Flag         = "AimbotAimKey",
    Callback     = function(Value)
        aimKeyOnly = Value
    end,
})

AimbotTab:CreateToggle({
    Name         = "Aim Prediction",
    CurrentValue = false,
    Flag         = "AimbotPrediction",
    Callback     = function(Value)
        aimPrediction = Value
    end,
})

AimbotTab:CreateSection("FOV")

AimbotTab:CreateToggle({
    Name         = "Show FOV Circle",
    CurrentValue = false,
    Flag         = "AimbotFovCircle",
    Callback     = function(Value)
        fovCircle.Visible = Value
    end,
})

AimbotTab:CreateSlider({
    Name         = "FOV Radius",
    Range        = {10, 500},
    Increment    = 10,
    Suffix       = "px",
    CurrentValue = 180,
    Flag         = "AimbotFovRadius",
    Callback     = function(Value)
        aimbotFOV   = Value
        fovCircle.Radius = Value
    end,
})

-- ============================================================
-- TAB: ESP
-- ============================================================
local EspTab = Window:CreateTab("ESP | Wallhack", "rewind")
EspTab:CreateSection("Visibility")

EspTab:CreateToggle({
    Name         = "Enable ESP",
    CurrentValue = false,
    Flag         = "EspEnabled",
    Callback     = function(Value)
        ESP.Enabled = Value
    end,
})

EspTab:CreateToggle({
    Name         = "ESP Box",
    CurrentValue = false,
    Flag         = "EspBox",
    Callback     = function(Value)
        ESP.ShowBox = Value
    end,
})

EspTab:CreateToggle({
    Name         = "ESP Name",
    CurrentValue = false,
    Flag         = "EspName",
    Callback     = function(Value)
        ESP.ShowName = Value
    end,
})

EspTab:CreateToggle({
    Name         = "ESP Health",
    CurrentValue = false,
    Flag         = "EspHealth",
    Callback     = function(Value)
        ESP.ShowHealth = Value
    end,
})

EspTab:CreateToggle({
    Name         = "ESP Tracer",
    CurrentValue = false,
    Flag         = "EspTracer",
    Callback     = function(Value)
        ESP.ShowTracer = Value
    end,
})

EspTab:CreateToggle({
    Name         = "ESP Distance",
    CurrentValue = false,
    Flag         = "EspDistance",
    Callback     = function(Value)
        ESP.ShowDistance = Value
    end,
})

EspTab:CreateToggle({
    Name         = "ESP Skeleton",
    CurrentValue = false,
    Flag         = "EspSkeleton",
    Callback     = function(Value)
        ESP.ShowSkeletons = Value
    end,
})

EspTab:CreateToggle({
    Name         = "Team Check",
    CurrentValue = false,
    Flag         = "EspTeamCheck",
    Callback     = function(Value)
        ESP.TeamCheck = Value
    end,
})

EspTab:CreateDropdown({
    Name            = "ESP Box Type",
    Options         = {"2D", "Corner Box Esp"},
    CurrentOption   = {"2D"},
    MultipleOptions = false,
    Flag            = "EspBoxType",
    Callback        = function(Value)
        ESP.BoxType = Value
    end,
})

EspTab:CreateDropdown({
    Name            = "Tracer Position",
    Options         = {"Bottom", "Top", "Middle"},
    CurrentOption   = {"Bottom"},
    MultipleOptions = false,
    Flag            = "EspTracerPosition",
    Callback        = function(Value)
        ESP.TracerPosition = Value
    end,
})

-- ============================================================
-- TAB: MISC
-- ============================================================
local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateSection("Movement")

MiscTab:CreateToggle({
    Name         = "Infinite Jump",
    CurrentValue = false,
    Flag         = "MiscInfiniteJump",
    Callback     = function(Value)
        infiniteJump = Value
    end,
})

-- Walk speed: connect the lock signal once per character, not per slider move
local wsConnection = nil
local function connectWalkSpeedLock(hum)
    if wsConnection then wsConnection:Disconnect() end
    wsConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if _G.WS and hum.WalkSpeed ~= _G.WS then
            hum.WalkSpeed = _G.WS
        end
    end)
end

-- Re-hook on character respawn
localPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum and _G.WS then
        connectWalkSpeedLock(hum)
        hum.WalkSpeed = _G.WS
    end
end)

MiscTab:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 100},
    Increment    = 2,
    Suffix       = "studs/s",
    CurrentValue = 16,
    Flag         = "MiscWalkSpeed",
    Callback     = function(Value)
        _G.WS = Value
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        hum.WalkSpeed = _G.WS
        connectWalkSpeedLock(hum)
    end,
})

MiscTab:CreateSection("Hitbox")

MiscTab:CreateButton({
    Name     = "Expand Heads",
    Callback = function()
        resizeHeads()
        Rayfield:Notify({
            Title    = "Hitbox",
            Content  = "All heads resized to 5x5x5.",
            Duration = 3,
        })
    end,
})

MiscTab:CreateSection("World")

MiscTab:CreateToggle({
    Name         = "No Clip",
    CurrentValue = false,
    Flag         = "MiscNoclip",
    Callback     = function(Value)
        noclipEnabled = Value
        if noclipEnabled then startNoclip() end
    end,
})

MiscTab:CreateToggle({
    Name         = "Fly",
    CurrentValue = false,
    Flag         = "MiscFly",
    Callback     = function(Value)
        flyEnabled = Value
        if flyEnabled then
            startFly()
        end
    end,
})

MiscTab:CreateSlider({
    Name         = "Fly Speed",
    Range        = {10, 200},
    Increment    = 5,
    Suffix       = "studs/s",
    CurrentValue = 50,
    Flag         = "MiscFlySpeed",
    Callback     = function(Value)
        flySpeed = Value
    end,
})

MiscTab:CreateSlider({
    Name         = "Jump Power",
    Range        = {50, 500},
    Increment    = 10,
    Suffix       = "",
    CurrentValue = 50,
    Flag         = "MiscJumpPower",
    Callback     = function(Value)
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = Value end
    end,
})

MiscTab:CreateSection("Utility")

MiscTab:CreateToggle({
    Name         = "Fullbright",
    CurrentValue = false,
    Flag         = "MiscFullbright",
    Callback     = function(Value)
        fullbrightEnabled = Value
        setFullbright(Value)
    end,
})

MiscTab:CreateToggle({
    Name         = "Anti-AFK",
    CurrentValue = false,
    Flag         = "MiscAntiAfk",
    Callback     = function(Value)
        antiaafkEnabled = Value
    end,
})

MiscTab:CreateSection("Risky")

MiscTab:CreateToggle({
    Name         = "Auto-Heal [RISKY]",
    CurrentValue = false,
    Flag         = "MiscAutoHeal",
    Callback     = function(Value)
        autoHealEnabled = Value
        if autoHealEnabled then startAutoHeal() end
    end,
})

MiscTab:CreateToggle({
    Name         = "Click Teleport [RISKY]",
    CurrentValue = false,
    Flag         = "MiscClickTeleport",
    Callback     = function(Value)
        clickTeleportEnabled = Value
        if clickTeleportEnabled then
            startClickTeleport()
        elseif clickTeleportConn then
            clickTeleportConn:Disconnect()
            clickTeleportConn = nil
        end
    end,
})

MiscTab:CreateToggle({
    Name         = "Lag Switch [RISKY]",
    CurrentValue = false,
    Flag         = "MiscLagSwitch",
    Callback     = function(Value)
        lagSwitchEnabled = Value
        if Value then
            -- Pause all physics replication by freezing the HRP
            local char = localPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = true
            end
        else
            local char = localPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = false
            end
        end
    end,
})

MiscTab:CreateToggle({
    Name         = "Player Join/Leave Notifications",
    CurrentValue = false,
    Flag         = "MiscJoinLeave",
    Callback     = function(Value)
        notifyJoinLeave = Value
    end,
})

-- ============================================================
-- TAB: VISUAL
-- ============================================================
local VisualTab = Window:CreateTab("Visual", 4483362458)
VisualTab:CreateSection("Chams")

VisualTab:CreateToggle({
    Name         = "Enable Chams",
    CurrentValue = false,
    Flag         = "VisualChams",
    Callback     = function(Value)
        chamsEnabled = Value
        if not Value then applyChams(false) end
    end,
})

VisualTab:CreateColorPicker({
    Name         = "Chams Color",
    Color        = Color3.fromRGB(255, 0, 0),
    Flag         = "VisualChamsColor",
    Callback     = function(Value)
        chamsColor = Value
    end,
})

VisualTab:CreateSection("Crosshair")

VisualTab:CreateToggle({
    Name         = "Custom Crosshair",
    CurrentValue = false,
    Flag         = "VisualCrosshair",
    Callback     = function(Value)
        crosshairEnabled = Value
    end,
})

VisualTab:CreateColorPicker({
    Name         = "Crosshair Color",
    Color        = Color3.fromRGB(255, 255, 255),
    Flag         = "VisualCrosshairColor",
    Callback     = function(Value)
        for _, l in ipairs(chLines) do l.Color = Value end
    end,
})

VisualTab:CreateSection("Camera")

VisualTab:CreateSlider({
    Name         = "Field of View",
    Range        = {50, 120},
    Increment    = 5,
    Suffix       = "°",
    CurrentValue = 70,
    Flag         = "VisualFOV",
    Callback     = function(Value)
        workspace.CurrentCamera.FieldOfView = Value
    end,
})

VisualTab:CreateSection("World")

VisualTab:CreateSlider({
    Name         = "Time of Day",
    Range        = {0, 24},
    Increment    = 1,
    Suffix       = ":00",
    CurrentValue = 14,
    Flag         = "VisualTimeOfDay",
    Callback     = function(Value)
        game:GetService("Lighting").ClockTime = Value
    end,
})

-- ============================================================
-- TAB: SKIN CHANGER
-- Load the skin changer module (no custom GUI, uses Rayfield)
-- ============================================================
local SC = nil
local scInitialized = false

-- Skin changer loads only when user clicks the button (not at startup)
local function loadSkinChanger(callback)
    if SC then
        if callback then callback(true) end
        return
    end
    task.spawn(function()
        local ok, result = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/CewhoBey/actyxtest/refs/heads/main/skinchanger1.lua"))()
        end)
        if ok and result then
            SC = result
            task.spawn(function()
                scInitialized = SC.init()
                if callback then callback(scInitialized) end
            end)
        else
            warn("[SkinChanger] Module failed to load: " .. tostring(result))
            if callback then callback(false) end
        end
    end)
end

local SkinTab = Window:CreateTab("Skin Changer", 4483362458)

-- sorted weapon list for dropdown
local weaponNames = {}
for k in pairs({
    ["Assault Rifle"]=1,["Bow"]=1,["Burst Rifle"]=1,["Crossbow"]=1,["Distortion"]=1,
    ["Energy Rifle"]=1,["Flamethrower"]=1,["Grenade Launcher"]=1,["Gunblade"]=1,["Minigun"]=1,
    ["Paintball Gun"]=1,["RPG"]=1,["Shotgun"]=1,["Sniper"]=1,["Daggers"]=1,
    ["Energy Pistols"]=1,["Exogun"]=1,["Flare Gun"]=1,["Handgun"]=1,["Revolver"]=1,
    ["Shorty"]=1,["Slingshot"]=1,["Spray"]=1,["Uzi"]=1,["Warper"]=1,
    ["Battle Axe"]=1,["Chainsaw"]=1,["Fists"]=1,["Katana"]=1,["Knife"]=1,
    ["Riot Shield"]=1,["Scythe"]=1,["Trowel"]=1,["Flashbang"]=1,["Freeze Ray"]=1,
    ["Grenade"]=1,["Jump Pad"]=1,["Medkit"]=1,["Molotov"]=1,["Satchel"]=1,
    ["Smoke Grenade"]=1,["Subspace Tripmine"]=1,["War Horn"]=1,["Warpstone"]=1,["Permafrost"]=1,
}) do
    table.insert(weaponNames, k)
end
table.sort(weaponNames)

local selectedWeapon = weaponNames[1]

SkinTab:CreateSection("Weapon Skins")

SkinTab:CreateDropdown({
    Name            = "Select Weapon",
    Options         = weaponNames,
    CurrentOption   = {weaponNames[1]},
    MultipleOptions = false,
    Flag            = "SkinWeapon",
    Callback        = function(Value)
        selectedWeapon = Value
    end,
})

-- Helper: auto-load SC on first use
local function withSC(callback)
    if SC then callback() return end
    Rayfield:Notify({ Title = "Skin Changer", Content = "Loading skin engine...", Duration = 3 })
    loadSkinChanger(function(ok)
        if ok then callback()
        else Rayfield:Notify({ Title = "Skin Changer", Content = "Failed to initialize skin engine.", Duration = 4 }) end
    end)
end

SkinTab:CreateButton({
    Name     = "Initialize Skin Engine",
    Callback = function()
        loadSkinChanger(function(ok)
            Rayfield:Notify({
                Title   = "Skin Changer",
                Content = ok and "Skin engine ready!" or "Loaded (hooks may be inactive on this executor).",
                Duration = 5,
            })
        end)
    end,
})

SkinTab:CreateButton({
    Name     = "Show Available Skins",
    Callback = function()
        withSC(function()
            local skins = SC.SkinLists[selectedWeapon]
            if not skins then return end
            Rayfield:Notify({ Title = selectedWeapon .. " Skins", Content = table.concat(skins, ", "):sub(1, 200), Duration = 8 })
        end)
    end,
})

SkinTab:CreateInput({
    Name               = "Skin Name (exact)",
    PlaceholderText    = "e.g. AK-47, Karambit, Saber",
    RemoveTextAfterFocusLost = false,
    Flag               = "SkinNameInput",
    Callback           = function(Value)
        withSC(function()
            SC.equip(selectedWeapon, Value)
            Rayfield:Notify({ Title = "Skin Applied", Content = selectedWeapon .. " → " .. Value, Duration = 4 })
        end)
    end,
})

SkinTab:CreateSection("Wrap")

SkinTab:CreateInput({
    Name               = "Wrap Name (exact)",
    PlaceholderText    = "e.g. Gold, Damascus, Neon Lights",
    RemoveTextAfterFocusLost = false,
    Flag               = "WrapNameInput",
    Callback           = function(Value)
        withSC(function()
            SC.equipWrap(selectedWeapon, Value)
            Rayfield:Notify({ Title = "Wrap Applied", Content = selectedWeapon .. " wrap → " .. Value, Duration = 4 })
        end)
    end,
})

SkinTab:CreateButton({
    Name     = "List All Wraps",
    Callback = function()
        withSC(function()
            Rayfield:Notify({ Title = "Available Wraps", Content = table.concat(SC.WrapList, ", "):sub(1, 200), Duration = 8 })
        end)
    end,
})

SkinTab:CreateSection("Config")

SkinTab:CreateButton({
    Name     = "Save Skin Config",
    Callback = function()
        withSC(function()
            local ok = SC.saveConfig()
            Rayfield:Notify({ Title = "Config", Content = ok and "Saved!" or "Save failed (no filesystem access)", Duration = 4 })
        end)
    end,
})

SkinTab:CreateButton({
    Name     = "Load Skin Config",
    Callback = function()
        withSC(function()
            local ok = SC.loadConfig()
            Rayfield:Notify({ Title = "Config", Content = ok and "Config loaded!" or "No config file found", Duration = 4 })
        end)
    end,
})

SkinTab:CreateSection("Character Cosmetics")

SkinTab:CreateColorPicker({
    Name         = "Body Color",
    Color        = Color3.fromRGB(255, 255, 255),
    Flag         = "SkinBodyColor",
    Callback     = function(Value)
        local char = localPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Color = Value
            end
        end
    end,
})

SkinTab:CreateColorPicker({
    Name         = "Head Color",
    Color        = Color3.fromRGB(255, 220, 177),
    Flag         = "SkinHeadColor",
    Callback     = function(Value)
        local char = localPlayer.Character
        if not char then return end
        local head = char:FindFirstChild("Head")
        if head then head.Color = Value end
    end,
})

SkinTab:CreateButton({
    Name     = "Rainbow Character",
    Callback = function()
        local char = localPlayer.Character
        if not char then return end
        task.spawn(function()
            while char and char.Parent do
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Color = Color3.fromHSV(tick() % 1, 1, 1)
                    end
                end
                task.wait(0.05)
            end
        end)
    end,
})

SkinTab:CreateButton({
    Name     = "Remove All Accessories",
    Callback = function()
        local char = localPlayer.Character
        if not char then return end
        for _, acc in ipairs(char:GetChildren()) do
            if acc:IsA("Accessory") then acc:Destroy() end
        end
        Rayfield:Notify({ Title = "Skin Changer", Content = "All accessories removed.", Duration = 3 })
    end,
})

SkinTab:CreateButton({
    Name     = "Remove All Clothing",
    Callback = function()
        local char = localPlayer.Character
        if not char then return end
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
                obj:Destroy()
            end
        end
        Rayfield:Notify({ Title = "Skin Changer", Content = "Clothing removed.", Duration = 3 })
    end,
})

-- ============================================================
-- TAB: INFO
-- ============================================================
local InfoTab = Window:CreateTab("Info | Authors", 4483362458)
InfoTab:CreateLabel("Authors: x2zu.", 4483362458, Color3.fromRGB(255, 255, 255), false)
InfoTab:CreateLabel("UI Library: Rayfield", 4483362458, Color3.fromRGB(255, 255, 255), false)
InfoTab:CreateLabel("ESP Library: self-hosted", 4483362458, Color3.fromRGB(200, 200, 200), false)
