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

    local function checkTarget(target)
        if not (target and target ~= character) then return end
        if not (target:IsA("Model") and target:FindFirstChildOfClass("Humanoid") and target:FindFirstChild(aimAtPart)) then return end

        local humanoid = target:FindFirstChildOfClass("Humanoid")
        if humanoid.Health <= 0 then return end

        local targetRoot = target[aimAtPart]
        local dist = (targetRoot.Position - localRoot.Position).Magnitude

        if dist >= shortestDistance then return end

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

        local target = getClosestTarget()
        if target and target:FindFirstChild(aimAtPart) then
            local humanoid = target:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                lookAt(target[aimAtPart].Position)
            end
        end
    end)
end

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

-- ============================================================
-- TAB: INFO
-- ============================================================
local InfoTab = Window:CreateTab("Info | Authors", 4483362458)
InfoTab:CreateLabel("Authors: x2zu.", 4483362458, Color3.fromRGB(255, 255, 255), false)
InfoTab:CreateLabel("UI Library: Rayfield", 4483362458, Color3.fromRGB(255, 255, 255), false)
InfoTab:CreateLabel("ESP Library: self-hosted", 4483362458, Color3.fromRGB(200, 200, 200), false)
