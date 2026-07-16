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

-- ── Apply skin ──────────────────────────────────────────────
local function applySkin(weaponName, skinName)
    if not weaponName or not skinName then return false end

    local weaponModel
    for _, desc in ipairs(viewModels:GetDescendants()) do
        if desc.Name == weaponName then
            weaponModel = desc
            break
        end
    end
    if not weaponModel then
        warn("[SkinChanger] Weapon not found: " .. weaponName)
        return false
    end

    local skinSource
    for _, desc in ipairs(viewModels:GetDescendants()) do
        if desc.Name == skinName then
            skinSource = desc
            break
        end
    end
    if not skinSource then
        warn("[SkinChanger] Skin not found: " .. skinName)
        return false
    end

    weaponModel:ClearAllChildren()
    for _, child in ipairs(skinSource:GetChildren()) do
        child:Clone().Parent = weaponModel
    end

    return true
end

-- ── Reset skin to default ───────────────────────────────────
local function resetSkin(weaponName)
    if not weaponName then return end
    local weaponModel
    for _, desc in ipairs(viewModels:GetDescendants()) do
        if desc.Name == weaponName then
            weaponModel = desc
            break
        end
    end
    if weaponModel then
        weaponModel:ClearAllChildren()
    end
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

-- ── List all children of a specific weapon folder ───────────
local function listSkinsForWeapon(weaponName)
    local weapon
    for _, child in ipairs(viewModels:GetChildren()) do
        if child.Name == weaponName then
            weapon = child
            break
        end
    end
    if not weapon then return {} end
    local names = {}
    for _, child in ipairs(weapon:GetChildren()) do
        table.insert(names, child.Name)
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
