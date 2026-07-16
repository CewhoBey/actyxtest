-- // Rivals Unlock All + AC Bypass | Axiom Rebuild
-- // Based on open source swish-hub/rivals-ac

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local controllers = lp.PlayerScripts.Controllers

-- // AC BYPASS
-- AC bypass (kick/shutdown block) — only on executors that support getrawmetatable
pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if self == lp and (m == "Kick" or m == "kick") then return end
        if m:lower():find("kick") or m == "Shutdown" then return end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end)

local hooked = 0
pcall(function()
    local ls3 = ReplicatedFirst:WaitForChild("LocalScript3", 5)
    if not ls3 then return end
    for _, f in getgc(false) do
        if typeof(f) == "function" then
            local ok, env = pcall(getfenv, f)
            if ok and env then
                local scr = rawget(env, "script")
                if scr and (scr == ls3 or tostring(scr):find("LoadingScreen")) then
                    local ok2, cs = pcall(debug.getconstants, f)
                    if ok2 then
                        for _, k in cs do
                            if typeof(k) == "string" and (k:find("TakeTheL") or k:find("ban") or k:find("kick")) then
                                hookfunction(f, function() end)
                                hooked += 1
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)
print("[Axiom] AC hooks neutralized: " .. hooked)

-- // MODULE REQUIRES — all wrapped in pcall to avoid corrupting game modules on failure
local EnumLibrary, CosmeticLibrary, ItemLibrary, DataController

pcall(function()
    EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 10))
    if EnumLibrary and EnumLibrary.WaitForEnumBuilder then
        EnumLibrary:WaitForEnumBuilder()
    end
end)
pcall(function()
    CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 10))
end)
pcall(function()
    ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 10))
end)
pcall(function()
    DataController = require(controllers:WaitForChild("PlayerDataController", 10))
end)

if not CosmeticLibrary or not DataController then
    warn("[Axiom] Core modules unavailable on this executor — skin injection inactive.")
    return
end

-- // STATE
local equipped = {}
local favorites = {}
local constructingWeapon = nil
local viewingProfile = nil
local lastUsedWeapon = nil

-- // CONFIG PERSISTENCE
local SAVE_PATH = "unlockall/config.json"

local function saveConfig()
    if not writefile then return end
    pcall(function()
        local config = { equipped = {}, favorites = favorites }
        for weapon, cosmetics in pairs(equipped) do
            config.equipped[weapon] = {}
            for cType, cData in pairs(cosmetics) do
                if cData and cData.Name then
                    config.equipped[weapon][cType] = {
                        name = cData.Name,
                        seed = cData.Seed,
                        inverted = cData.Inverted
                    }
                end
            end
        end
        makefolder("unlockall")
        writefile(SAVE_PATH, HttpService:JSONEncode(config))
    end)
end

local function loadConfig()
    if not readfile or not isfile or not isfile(SAVE_PATH) then return end
    pcall(function()
        local config = HttpService:JSONDecode(readfile(SAVE_PATH))
        if config.equipped then
            for weapon, cosmetics in pairs(config.equipped) do
                equipped[weapon] = {}
                for cType, cData in pairs(cosmetics) do
                    local base = CosmeticLibrary.Cosmetics[cData.name]
                    if base then
                        local clone = {}
                        for k, v in pairs(base) do clone[k] = v end
                        clone.Name = cData.name
                        clone.Seed = cData.seed
                        clone.Inverted = cData.inverted
                        equipped[weapon][cType] = clone
                    end
                end
            end
        end
        favorites = config.favorites or {}
    end)
end

-- // COSMETIC CLONE
local function cloneCosmetic(name, cosmeticType, options)
    local base = CosmeticLibrary.Cosmetics[name]
    if not base then return nil end
    local data = {}
    for k, v in pairs(base) do data[k] = v end
    data.Name = name
    data.Type = data.Type or cosmeticType
    data.Seed = data.Seed or math.random(1, 1000000)
    if EnumLibrary then
        local ok, enumId = pcall(EnumLibrary.ToEnum, EnumLibrary, name)
        if ok and enumId then
            data.Enum = enumId
            data.ObjectID = data.ObjectID or enumId
        end
    end
    if options then
        if options.inverted ~= nil then data.Inverted = options.inverted end
        if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
    end
    return data
end

-- // OWNERSHIP SPOOF
CosmeticLibrary.OwnsCosmeticNormally = function() return true end
CosmeticLibrary.OwnsCosmeticUniversally = function() return true end
CosmeticLibrary.OwnsCosmeticForWeapon = function() return true end

local origOwns = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if name:find("MISSING_") then return origOwns(self, inventory, name, weapon) end
    return true
end

-- // DATA CONTROLLER HOOKS
local origGet = DataController.Get
DataController.Get = function(self, key)
    local data = origGet(self, key)
    if key == "CosmeticInventory" then
        local proxy = {}
        if data then for k, v in pairs(data) do proxy[k] = v end end
        return setmetatable(proxy, { __index = function() return true end })
    end
    if key == "FavoritedCosmetics" then
        local result = data and table.clone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do result[weapon][name] = isFav end
        end
        return result
    end
    return data
end

local origGetWeaponData = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = origGetWeaponData(self, weaponName)
    if not data then return nil end
    local merged = {}
    for k, v in pairs(data) do merged[k] = v end
    merged.Name = weaponName
    if equipped[weaponName] then
        for cType, cData in pairs(equipped[weaponName]) do
            merged[cType] = cData
        end
    end
    return merged
end

-- // REMOTE INTERCEPT
local FighterController
pcall(function() FighterController = require(controllers:WaitForChild("FighterController", 10)) end)

if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    local replicationRemotes = remotes and remotes:FindFirstChild("Replication")
    local fighterRemotes = replicationRemotes and replicationRemotes:FindFirstChild("Fighter")
    local useItemRemote = fighterRemotes and fighterRemotes:FindFirstChild("UseItem")

    if equipRemote then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
            local args = {...}

            if useItemRemote and self == useItemRemote then
                local objectID = args[1]
                if FighterController then
                    pcall(function()
                        local fighter = FighterController:GetFighter(lp)
                        if fighter and fighter.Items then
                            for _, item in pairs(fighter.Items) do
                                if item:Get("ObjectID") == objectID then
                                    lastUsedWeapon = item.Name
                                    break
                                end
                            end
                        end
                    end)
                end
            end

            if self == equipRemote then
                local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                    local inventory = DataController:Get("CosmeticInventory")
                    if inventory and rawget(inventory, cosmeticName) then
                        return oldNamecall(self, ...)
                    end
                end
                equipped[weaponName] = equipped[weaponName] or {}
                if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                    equipped[weaponName][cosmeticType] = nil
                    if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                else
                    local cloned = cloneCosmetic(cosmeticName, cosmeticType, {
                        inverted = options.IsInverted,
                        favoritesOnly = options.OnlyUseFavorites
                    })
                    if cloned then equipped[weaponName][cosmeticType] = cloned end
                end
                task.defer(function()
                    pcall(function() DataController.CurrentData:Replicate("WeaponInventory") end)
                    task.wait(0.2)
                    saveConfig()
                end)
                return
            end

            if self == favoriteRemote then
                favorites[args[1]] = favorites[args[1]] or {}
                favorites[args[1]][args[2]] = args[3] or nil
                saveConfig()
                task.spawn(function()
                    pcall(function() DataController.CurrentData:Replicate("FavoritedCosmetics") end)
                end)
                return
            end

            return oldNamecall(self, ...)
        end)
    end
end

-- // VIEWMODEL HOOKS
local ClientItem
pcall(function()
    ClientItem = require(lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
end)

if ClientItem and ClientItem._CreateViewModel then
    local origCreateViewModel = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        constructingWeapon = (weaponPlayer == lp) and weaponName or nil
        if weaponPlayer == lp and equipped[weaponName] and equipped[weaponName].Skin and viewmodelRef then
            local dataKey = self:ToEnum("Data")
            local skinKey = self:ToEnum("Skin")
            local nameKey = self:ToEnum("Name")
            if viewmodelRef[dataKey] then
                viewmodelRef[dataKey][skinKey] = equipped[weaponName].Skin
                viewmodelRef[dataKey][nameKey] = equipped[weaponName].Skin.Name
            elseif viewmodelRef.Data then
                viewmodelRef.Data.Skin = equipped[weaponName].Skin
                viewmodelRef.Data.Name = equipped[weaponName].Skin.Name
            end
        end
        local result = origCreateViewModel(self, viewmodelRef)
        constructingWeapon = nil
        return result
    end
end

local viewModelModule = lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
if viewModelModule then
    local ClientViewModel = require(viewModelModule)
    if ClientViewModel.GetWrap then
        local origGetWrap = ClientViewModel.GetWrap
        ClientViewModel.GetWrap = function(self)
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == lp and equipped[weaponName] and equipped[weaponName].Wrap then
                return equipped[weaponName].Wrap
            end
            return origGetWrap(self)
        end
    end

    local origNew = ClientViewModel.new
    ClientViewModel.new = function(replicatedData, clientItem)
        local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
        local weaponName = constructingWeapon or clientItem.Name
        if weaponPlayer == lp and equipped[weaponName] then
            local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
            local dataKey = ReplicatedClass:ToEnum("Data")
            replicatedData[dataKey] = replicatedData[dataKey] or {}
            local cosmetics = equipped[weaponName]
            if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end
            if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end
            if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
        end
        local result = origNew(replicatedData, clientItem)
        if weaponPlayer == lp and equipped[weaponName] and equipped[weaponName].Wrap and result._UpdateWrap then
            result:_UpdateWrap()
            task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end)
        end
        return result
    end
end

-- // ITEM LIBRARY IMAGE FIX
local origGetVMImage = ItemLibrary.GetViewModelImageFromWeaponData
ItemLibrary.GetViewModelImageFromWeaponData = function(self, weaponData, highRes)
    if not weaponData then return origGetVMImage(self, weaponData, highRes) end
    local weaponName = weaponData.Name
    local hasSkin = equipped[weaponName] and equipped[weaponName].Skin
    local matchesSkin = weaponData.Skin and hasSkin and weaponData.Skin == equipped[weaponName].Skin
    local profileView = viewingProfile == lp and hasSkin
    if (matchesSkin or profileView) and hasSkin then
        local skinInfo = self.ViewModels[equipped[weaponName].Skin.Name]
        if skinInfo then
            return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image
        end
    end
    return origGetVMImage(self, weaponData, highRes)
end

-- // VIEW PROFILE HOOK
pcall(function()
    local ViewProfile = require(lp.PlayerScripts.Modules.Pages.ViewProfile)
    if ViewProfile and ViewProfile.Fetch then
        local origFetch = ViewProfile.Fetch
        ViewProfile.Fetch = function(self, targetPlayer)
            viewingProfile = targetPlayer
            return origFetch(self, targetPlayer)
        end
    end
end)

-- // FINISHER FIX
local ClientEntity
pcall(function() ClientEntity = require(lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientEntity) end)
if ClientEntity and ClientEntity.ReplicateFromServer then
    local origReplicate = ClientEntity.ReplicateFromServer
    ClientEntity.ReplicateFromServer = function(self, action, ...)
        if action == "FinisherEffect" then
            local args = {...}
            local killerName = args[3]
            local decodedKiller = killerName
            if type(killerName) == "userdata" and EnumLibrary and EnumLibrary.FromEnum then
                local ok, decoded = pcall(EnumLibrary.FromEnum, EnumLibrary, killerName)
                if ok and decoded then decodedKiller = decoded end
            end
            local isOurKill = tostring(decodedKiller) == lp.Name or tostring(decodedKiller):lower() == lp.Name:lower()
            if isOurKill and lastUsedWeapon and equipped[lastUsedWeapon] and equipped[lastUsedWeapon].Finisher then
                local finisherData = equipped[lastUsedWeapon].Finisher
                local finisherEnum = finisherData.Enum
                if not finisherEnum and EnumLibrary then
                    local ok, result = pcall(EnumLibrary.ToEnum, EnumLibrary, finisherData.Name)
                    if ok and result then finisherEnum = result end
                end
                if finisherEnum then
                    args[1] = finisherEnum
                    return origReplicate(self, action, unpack(args))
                end
            end
        end
        return origReplicate(self, action, ...)
    end
end

loadConfig()
print("[Axiom] Unlock all loaded clean boss man.")
