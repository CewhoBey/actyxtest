-- changer1.lua — Rivals Skin Changer (no require, no UI)
-- Swaps weapon viewmodel children directly in PlayerScripts.Assets.ViewModels
-- Works on all executors since it only uses Instance API

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

-- Wait for ViewModels to be available
local viewModels
local ok = pcall(function()
    viewModels = lp.PlayerScripts:WaitForChild("Assets", 10):WaitForChild("ViewModels", 10)
end)

if not ok or not viewModels then
    warn("[SkinChanger] ViewModels folder not found — executor may not support PlayerScripts access")
    return
end

-- ── Skin options per weapon ─────────────────────────────────
local skinOptions = {
    ["Assault Rifle"] = {"AK-47", "AUG", "Tommy Gun", "Phoenix Rifle", "Boneclaw Rifle", "AKEY-47"},
    ["Bow"] = {"Compound Bow", "Raven Bow", "Dream Bow", "Bat Bow", "Frostbite Bow", "Key Bow", "Glorious Bow"},
    ["Burst Rifle"] = {"Aqua Burst", "Electro Rifle", "FAMAS", "Pine Burst", "Spectral Burst"},
    ["Chainsaw"] = {"Blobsaw", "Handsaws", "Mega Drill", "Buzzsaw"},
    ["RPG"] = {"Nuke Launcher", "Spaceship Launcher", "Squid Launcher", "Pumpkin Launcher"},
    ["Exogun"] = {"Singularity", "Exogourd", "Ray Gun", "Repulsor", "Midnight Festive Exogun"},
    ["Fists"] = {"Boxing Gloves", "Brass Knuckles", "Fists of Hurt", "Pumpkin Claws"},
    ["Flamethrower"] = {"Lamethrower", "Pixel Flamethrower", "Glitterthrower", "Snowblower"},
    ["Flare Gun"] = {"Dynamite Gun", "Firework Gun", "Banana Flare"},
    ["Freeze Ray"] = {"Bubble Ray", "Temporal Ray", "Gum Ray"},
    ["Grenade"] = {"Water Balloon", "Whoopee Cushion", "Dynamite", "Soul Grenade"},
    ["Grenade Launcher"] = {"Swashbuckler", "Uranium Launcher", "Gearnade Launcher"},
    ["Handgun"] = {"Blaster", "Gumball Handgun", "Pumpkin Handgun", "Gingerbread Handgun"},
    ["Katana"] = {"Lightning Bolt", "Saber", "Stellar Katana", "Pixel Katana", "Keytana"},
    ["Minigun"] = {"Lasergun 3000", "Pixel Minigun", "Fighter Jet", "Pumpkin Minigun"},
    ["Paintball Gun"] = {"Boba Gun", "Slime Gun", "Ketchup Gun"},
    ["Revolver"] = {"Sheriff", "Desert Eagle", "Peppergun", "Boneclaw Revolver"},
    ["Slingshot"] = {"Goalpost", "Stick", "Harp", "Boneshot"},
    ["Uzi"] = {"Electro Uzi", "Water Uzi", "Money Gun", "Pine Uzi"},
    ["Sniper"] = {"Pixel Sniper", "Hyper Sniper", "Event Horizon", "Eyething Sniper", "Keyper"},
    ["Knife"] = {"Karambit", "Chancla", "Balisong", "Machete", "Keyrambit"},
    ["Shotgun"] = {"Balloon Shotgun", "Cactus Shotgun", "Broomstick Shotgun", "Hyper Shotgun"},
    ["Crossbow"] = {"Pixel Crossbow", "Violin Crossbow", "Crossbone", "Harpoon Crossbow"},
    ["Daggers"] = {"Aces", "Paper Planes", "Shurikens", "Bat Daggers", "Cookies"},
    ["Distortion"] = {"Plasma Distortion", "Cyber Distortion", "Magma Distortion"},
    ["Energy Rifle"] = {"Hacker Rifle", "Void Rifle", "Hydro Rifle"},
    ["Energy Pistols"] = {"Void Pistols", "Hydro Pistols", "Soul Pistols"},
    ["Gunblade"] = {"Hyper Gunblade", "Gunsaw", "Boneblade", "Crude Gunblade"},
    ["Battle Axe"] = {"The Shred", "Ban Axe", "Cerulean Axe", "Nordic Axe"},
    ["Riot Shield"] = {"Door", "Masterpiece", "Sled", "Tombstone Shield"},
    ["Scythe"] = {"Scythe of Death", "Sakura Scythe", "Bat Scythe", "Keythe"},
    ["Trowel"] = {"Plastic Shovel", "Paintbrush", "Snow Shovel"},
    ["Medkit"] = {"Sandwich", "Medkitty"},
    ["Molotov"] = {"Torch", "Lava Lamp"},
    ["Satchel"] = {"Notebook Satchel", "Suspicious Gift", "Advanced Satchel"},
    ["Smoke Grenade"] = {"Emoji Cloud", "Balance", "Hourglass"},
    ["War Horn"] = {"Trumpet", "Air Horn", "Megaphone", "Mammoth Horn"},
    ["Warpstone"] = {"Cyber Warpstone", "Electropunk Warpstone", "Warpbone"},
    ["Flashbang"] = {"Pixel Flashbang"},
    ["Warper"] = {"Glitch Warper"},
    ["Subspace Tripmine"] = {"Spring", "DIY Tripmine"},
}

-- ── Copy visual properties from source part to target part ──
local function copyVisuals(src, tgt)
    -- Copy mesh
    pcall(function()
        if src:IsA("MeshPart") and tgt:IsA("MeshPart") then
            tgt.MeshId      = src.MeshId
            tgt.TextureID   = src.TextureID
            tgt.Color       = src.Color
            tgt.Material    = src.Material
            tgt.Size        = src.Size
        elseif src:IsA("SpecialMesh") and tgt:FindFirstChildOfClass("SpecialMesh") then
            local sm = tgt:FindFirstChildOfClass("SpecialMesh")
            sm.MeshId       = src.MeshId
            sm.TextureId    = src.TextureId
            sm.Scale        = src.Scale
        elseif src:IsA("BasePart") and tgt:IsA("BasePart") then
            tgt.Color       = src.Color
            tgt.Material    = src.Material
        end
    end)
    -- Copy textures/decals
    for _, child in ipairs(src:GetChildren()) do
        if child:IsA("SpecialMesh") then
            local existing = tgt:FindFirstChildOfClass("SpecialMesh")
            if existing then
                pcall(function()
                    existing.MeshId   = child.MeshId
                    existing.TextureId = child.TextureId
                    existing.Scale    = child.Scale
                end)
            end
        elseif child:IsA("Texture") or child:IsA("Decal") then
            local existing = tgt:FindFirstChild(child.Name)
            if existing then
                pcall(function() existing.Texture = child.Texture end)
            else
                pcall(function() child:Clone().Parent = tgt end)
            end
        end
    end
end

-- ── Recursively apply visuals from skin tree to weapon tree ──
local function applyVisualsRecursive(skinModel, weaponModel)
    for _, skinChild in ipairs(skinModel:GetChildren()) do
        local weaponChild = weaponModel:FindFirstChild(skinChild.Name)
        if weaponChild then
            copyVisuals(skinChild, weaponChild)
            applyVisualsRecursive(skinChild, weaponChild)
        end
    end
end

-- ── Stored original visuals for reset ───────────────────────
local originalVisuals = {}

local function captureOriginals(model, store)
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("MeshPart") or child:IsA("BasePart") then
            store[child] = {
                MeshId    = pcall(function() return child.MeshId end) and child.MeshId or nil,
                TextureID = pcall(function() return child.TextureID end) and child.TextureID or nil,
                Color     = child.Color,
                Material  = child.Material,
            }
        end
    end
end

-- ── Apply skin ──────────────────────────────────────────────
local function applySkin(weaponName, skinName)
    if not weaponName or not skinName then return false end

    local weaponModel
    for _, desc in ipairs(viewModels:GetDescendants()) do
        if desc.Name == weaponName then weaponModel = desc break end
    end
    if not weaponModel then
        warn("[SkinChanger] Weapon not found: " .. weaponName)
        return false
    end

    local skinSource
    for _, desc in ipairs(viewModels:GetDescendants()) do
        if desc.Name == skinName then skinSource = desc break end
    end
    if not skinSource then
        warn("[SkinChanger] Skin not found: " .. skinName)
        return false
    end

    -- Capture originals before first skin change
    if not originalVisuals[weaponName] then
        originalVisuals[weaponName] = {}
        captureOriginals(weaponModel, originalVisuals[weaponName])
    end

    -- Apply visuals recursively, preserving part names/hierarchy
    applyVisualsRecursive(skinSource, weaponModel)
    return true
end

-- ── Reset skin to default ───────────────────────────────────
local function resetSkin(weaponName)
    if not weaponName then return end
    local originals = originalVisuals[weaponName]
    if not originals then return end
    for part, data in pairs(originals) do
        pcall(function()
            if data.MeshId    then part.MeshId    = data.MeshId    end
            if data.TextureID then part.TextureID = data.TextureID end
            part.Color    = data.Color
            part.Material = data.Material
        end)
    end
    originalVisuals[weaponName] = nil
end

-- ── List all top-level folders in ViewModels ────────────────
local function listWeapons()
    local names = {}
    for _, child in ipairs(viewModels:GetChildren()) do
        table.insert(names, child.Name)
    end
    table.sort(names)
    return names
end

-- ── List all descendants of a specific weapon folder ────────
local function listSkinsForWeapon(weaponName)
    local weapon
    -- Search all descendants since weapon folders may be nested
    for _, desc in ipairs(viewModels:GetDescendants()) do
        if desc.Name == weaponName then
            weapon = desc
            break
        end
    end
    if not weapon then return {} end
    local names = {}
    -- List both children and descendants to find skin folders
    for _, child in ipairs(weapon:GetDescendants()) do
        -- Only list folders/models that could be skins (not deep mesh/texture children)
        if child:IsA("Model") or child:IsA("Folder") or (child.Parent == weapon) then
            table.insert(names, child.Name .. " [" .. child.ClassName .. "]")
        end
    end
    table.sort(names)
    return names
end

-- ── Apply wrap (searches for wrap folder inside weapon) ──────
local function applyWrap(weaponName, wrapName)
    if not weaponName or not wrapName then return false end
    -- Wraps are stored similarly to skins in the ViewModels tree
    local weaponModel
    for _, desc in ipairs(viewModels:GetDescendants()) do
        if desc.Name == weaponName then
            weaponModel = desc
            break
        end
    end
    if not weaponModel then return false end

    local wrapSource
    for _, desc in ipairs(viewModels:GetDescendants()) do
        if desc.Name == wrapName then
            wrapSource = desc
            break
        end
    end
    if not wrapSource then return false end

    -- Apply wrap textures/meshes on top of existing weapon children
    for _, child in ipairs(wrapSource:GetChildren()) do
        local existing = weaponModel:FindFirstChild(child.Name)
        if existing then
            existing:Destroy()
        end
        child:Clone().Parent = weaponModel
    end
    return true
end

-- ── Return public API ───────────────────────────────────────
return {
    skinOptions    = skinOptions,
    applySkin      = applySkin,
    resetSkin      = resetSkin,
    applyWrap      = applyWrap,
    listWeapons    = listWeapons,
    listSkinsForWeapon = listSkinsForWeapon,
}
