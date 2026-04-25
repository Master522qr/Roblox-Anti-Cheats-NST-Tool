--//====================================================//--
--// 😎 NST-Tool v1.0 OneFile 😎
--// There will be no cheaters running successfully!
--//
--// Place this Script into:
--// ServerScriptService/NST_Tool_OneFile
--//
--// IMPORTANT:
--// This is a SERVER-ONLY one-file build.
--// A clickable Roblox GUI normally requires a LocalScript.
--// This one-file version uses server commands, private console output,
--// anti-cheat checks, admin tools, language switching, and live config update.
--//====================================================//--

print("====================================")
print("😎 NST-Tool v1.0 😎")
print("There will be no cheaters running successfully!")
print("====================================")

--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TextChatService = game:GetService("TextChatService")

--// CONFIG
local Config = {
	Version = "1.0.0",
	Enabled = true,

	-- Recommended: use UserId, not username.
	OwnerUserIds = {
		123456789, -- CHANGE THIS TO YOUR USERID
	},

	OwnerName = "YOUR_ROBLOX_NICK", -- optional fallback

	Admins = {
		-- [123456789] = true,
	},

	Moderators = {
		-- [123456789] = true,
	},

	-- Item folders in ServerStorage.
	-- Example:
	-- ServerStorage
	-- ├─ Weapons
	-- ├─ Tools
	-- └─ AdminItems
	["pridmet-stv"] = "Weapons,Tools,AdminItems",

	DefaultLanguage = "Russian",

	Language = {
		AllowPlayerLanguageChange = true,
	},

	Speed = {
		CheckInterval = 0.25,
		GraceAfterSpawn = 3,

		DefaultWalkSpeed = 16,
		RunSpeed = 28,

		MaxExtraSpeed = 8,
		MaxTeleportDistance = 75,

		StrikesToKick = 4,
		StrictStrikesToKick = 2,
	},

	RemoteSecurity = {
		MaxCallsPerSecond = 12,
		MaxBadCalls = 3,
		KickOnHoneypot = true,
		KickOnUnauthorizedAdminRemote = true,
	},

	Ban = {
		ApplyToUniverse = true,
		Duration = 86400,
		DisplayReason = "NST-Tool: exploit behavior detected.",
		PrivateReason = "NST-Tool automatic moderation.",
		ExcludeAltAccounts = false,
	},

	LiveUpdate = {
		Enabled = true,
		DataStoreName = "NST_Tool_LiveUpdate",
		ConfigKey = "NST_LiveConfig",
		MessageTopic = "NST_LiveUpdate_Topic",
		CheckEverySeconds = 60,
		AllowRemoteCodeExecution = false,
	},

	Messages = {
		SpeedKick = "NST-Tool: speed exploit detected.",
		RemoteKick = "NST-Tool: remote exploit detected.",
		Unauthorized = "NST-Tool: unauthorized admin action.",
		Honeypot = "NST-Tool: exploit honeypot detected.",
		ServerLocked = "NST-Tool: server is locked.",
	}
}

--// INTERNAL STATE
local PlayerState = {}
local RemoteRate = {}
local BadRemoteCalls = {}
local Watchlist = {}
local Frozen = {}
local ServerLocked = false
local Accumulator = 0
local PlayerLanguage = {}

local PrivateMessageRemote
local AdminActionRemote
local LiveStore = DataStoreService:GetDataStore(Config.LiveUpdate.DataStoreName)

local LiveState = {
	AppliedVersion = Config.Version,
	LastUpdateTime = 0,
	LastUpdateBy = "system",
}

--// LANGUAGE
local Text = {
	Russian = {
		NoAccess = "Нет доступа к NST-Tool.",
		UnknownCommand = "Неизвестная команда.",
		LanguageChanged = "Язык изменён на русский.",
		AnticheatEnabled = "Античит включён.",
		AnticheatDisabled = "Античит отключён.",
		PlayerNotFound = "Игрок не найден.",
		Done = "Готово.",
		Help = [[
NST-Tool команды:

!nst help
!nst info Player
!nst version
!nst update 1.0.1
!nst update 1.0.2 strict
!nst update 1.0.3 extreme
!nst update 1.0.4 soft
!nst on
!nst off

!kick Player
!ban Player 86400
!unban UserId
!freeze Player
!unfreeze Player
!give Player Sword
!admin add Player
!admin remove Player
!mod add Player
!mod remove Player
!watch add Player
!watch remove Player
!lock on
!lock off
!language Russian
!language English

ВНИМАНИЕ:
Если писать команды в обычный чат через !, Roblox может показать саму команду другим игрокам.
Для полностью скрытых команд нужен отдельный LocalScript GUI или TextChatCommand.
]],
	},

	English = {
		NoAccess = "No access to NST-Tool.",
		UnknownCommand = "Unknown command.",
		LanguageChanged = "Language changed to English.",
		AnticheatEnabled = "Anti-cheat enabled.",
		AnticheatDisabled = "Anti-cheat disabled.",
		PlayerNotFound = "Player not found.",
		Done = "Done.",
		Help = [[
NST-Tool commands:

!nst help
!nst info Player
!nst version
!nst update 1.0.1
!nst update 1.0.2 strict
!nst update 1.0.3 extreme
!nst update 1.0.4 soft
!nst on
!nst off

!kick Player
!ban Player 86400
!unban UserId
!freeze Player
!unfreeze Player
!give Player Sword
!admin add Player
!admin remove Player
!mod add Player
!mod remove Player
!watch add Player
!watch remove Player
!lock on
!lock off
!language Russian
!language English

WARNING:
If you type ! commands into normal public chat, Roblox may show the command itself to other players.
For fully hidden commands you need a separate LocalScript GUI or TextChatCommand.
]],
	}
}

--// UTILS
local function splitCSV(text)
	local result = {}

	for part in string.gmatch(text or "", "([^,]+)") do
		part = string.gsub(part, "^%s+", "")
		part = string.gsub(part, "%s+$", "")

		if part ~= "" then
			table.insert(result, part)
		end
	end

	return result
end

local ItemFolders = splitCSV(Config["pridmet-stv"])

local function log(...)
	print("[NST-Tool]", ...)
end

local function warnLog(...)
	warn("[NST-Tool]", ...)
end

local function normalizeLanguage(language)
	if not language then
		return nil
	end

	local value = string.lower(tostring(language))

	if value == "russian" or value == "ru" or value == "русский" then
		return "Russian"
	end

	if value == "english" or value == "en" or value == "английский" then
		return "English"
	end

	return nil
end

local function getLanguage(player)
	return PlayerLanguage[player.UserId] or Config.DefaultLanguage or "Russian"
end

local function tr(player, key)
	local language = getLanguage(player)
	local pack = Text[language] or Text.Russian

	return pack[key] or Text.English[key] or key
end

local function privateMessage(player, message)
	if not player then
		return
	end

	print("[NST-Tool Private][" .. player.Name .. "] " .. tostring(message))

	if PrivateMessageRemote then
		pcall(function()
			PrivateMessageRemote:FireClient(player, tostring(message))
		end)
	end
end

local function privateKey(player, key)
	privateMessage(player, tr(player, key))
end

local function isOwner(player)
	if not player then
		return false
	end

	if player.Name == Config.OwnerName then
		return true
	end

	for _, userId in ipairs(Config.OwnerUserIds) do
		if player.UserId == userId then
			return true
		end
	end

	return false
end

local function isAdmin(player)
	if not player then
		return false
	end

	return isOwner(player) or Config.Admins[player.UserId] == true
end

local function isModerator(player)
	if not player then
		return false
	end

	return isAdmin(player) or Config.Moderators[player.UserId] == true
end

local function getRoot(character)
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function findPlayer(text)
	if not text then
		return nil
	end

	text = string.lower(tostring(text))

	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == text then
			return player
		end

		if string.lower(player.DisplayName) == text then
			return player
		end

		if string.sub(string.lower(player.Name), 1, #text) == text then
			return player
		end
	end

	return nil
end

local function safeKick(player, message)
	if player and player.Parent == Players then
		player:Kick(message or "NST-Tool: removed from server.")
	end
end

local function safeNumber(value, minValue, maxValue, fallback)
	value = tonumber(value)

	if not value then
		return fallback
	end

	if value < minValue then
		return minValue
	end

	if value > maxValue then
		return maxValue
	end

	return value
end

--// PLAYER INFO
local function getPlayerStats(player)
	local state = PlayerState[player]

	return {
		Strikes = state and state.strikes or 0,
		LastReason = state and state.lastReason or "none",
		IsWatchlisted = Watchlist[player.UserId] == true,
		IsFrozen = Frozen[player.UserId] == true,
		IsOwner = isOwner(player),
		IsAdmin = isAdmin(player),
		IsModerator = isModerator(player),
		AnticheatEnabled = Config.Enabled,
		LiveVersion = LiveState.AppliedVersion,
	}
end

--// BAN / UNBAN
local function banPlayer(admin, targetUserId, duration, reason)
	duration = tonumber(duration) or Config.Ban.Duration
	reason = reason or Config.Ban.DisplayReason

	local success, err = pcall(function()
		Players:BanAsync({
			UserIds = { targetUserId },
			ApplyToUniverse = Config.Ban.ApplyToUniverse,
			Duration = duration,
			DisplayReason = reason,
			PrivateReason = Config.Ban.PrivateReason,
			ExcludeAltAccounts = Config.Ban.ExcludeAltAccounts,
		})
	end)

	if success then
		log("Ban success:", targetUserId, "by", admin.Name)
	else
		warnLog("BanAsync failed:", err)
		privateMessage(admin, "BanAsync failed. Check BanningEnabled in Studio.")
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		safeKick(target, reason)
	end
end

local function unbanUser(admin, targetUserId)
	local success, err = pcall(function()
		Players:UnbanAsync({
			UserIds = { targetUserId },
			ApplyToUniverse = Config.Ban.ApplyToUniverse,
		})
	end)

	if success then
		log("Unban success:", targetUserId, "by", admin.Name)
	else
		warnLog("UnbanAsync failed:", err)
		privateMessage(admin, "UnbanAsync failed. Check BanningEnabled in Studio.")
	end
end

--// FREEZE
local function freezePlayer(target)
	if not target or not target.Character then
		return
	end

	local humanoid = getHumanoid(target.Character)
	if not humanoid then
		return
	end

	Frozen[target.UserId] = true
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	log("Frozen:", target.Name)
end

local function unfreezePlayer(target)
	if not target or not target.Character then
		return
	end

	local humanoid = getHumanoid(target.Character)
	if not humanoid then
		return
	end

	Frozen[target.UserId] = nil
	humanoid.WalkSpeed = Config.Speed.DefaultWalkSpeed
	humanoid.JumpPower = 50
	humanoid.JumpHeight = 7.2

	log("Unfrozen:", target.Name)
end

--// GIVE ITEM
local function findItem(itemName)
	if not itemName then
		return nil
	end

	for _, folderName in ipairs(ItemFolders) do
		local folder = ServerStorage:FindFirstChild(folderName)

		if folder then
			local item = folder:FindFirstChild(itemName)
			if item then
				return item
			end

			for _, child in ipairs(folder:GetChildren()) do
				if string.lower(child.Name) == string.lower(itemName) then
					return child
				end
			end
		end
	end

	return nil
end

local function giveItem(admin, target, itemName)
	if not target then
		return false
	end

	local item = findItem(itemName)

	if not item then
		warnLog("Item not found:", itemName)
		privateMessage(admin, "Item not found: " .. tostring(itemName))
		return false
	end

	local backpack = target:FindFirstChildOfClass("Backpack")
	if not backpack then
		privateMessage(admin, "Backpack not found.")
		return false
	end

	local clone = item:Clone()
	clone.Parent = backpack

	log(admin.Name .. " gave " .. item.Name .. " to " .. target.Name)
	return true
end

--// SPEED CHECK
local function resetPlayerState(player)
	local character = player.Character
	local root = getRoot(character)

	if not root then
		return
	end

	PlayerState[player] = {
		lastPosition = root.Position,
		lastTime = os.clock(),
		spawnedAt = os.clock(),
		strikes = 0,
		lastReason = "none",
	}
end

local function addStrike(player, reason)
	local state = PlayerState[player]
	if not state then
		return
	end

	state.strikes += 1
	state.lastReason = reason

	local neededStrikes = Watchlist[player.UserId]
		and Config.Speed.StrictStrikesToKick
		or Config.Speed.StrikesToKick

	warnLog(player.Name .. " strike " .. state.strikes .. "/" .. neededStrikes .. ": " .. reason)

	if state.strikes >= neededStrikes then
		state.strikes = 0
		safeKick(player, Config.Messages.SpeedKick)
	end
end

local function checkSpeed(player)
	if not Config.Enabled then
		return
	end

	if isAdmin(player) then
		return
	end

	local character = player.Character
	local root = getRoot(character)
	local humanoid = getHumanoid(character)

	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local state = PlayerState[player]
	if not state then
		resetPlayerState(player)
		return
	end

	local now = os.clock()
	local dt = now - state.lastTime

	if dt <= 0 then
		return
	end

	local ignoreUntil = player:GetAttribute("NST_IgnoreMovementUntil")
	if typeof(ignoreUntil) == "number" and now < ignoreUntil then
		state.lastPosition = root.Position
		state.lastTime = now
		return
	end

	if now - state.spawnedAt < Config.Speed.GraceAfterSpawn then
		state.lastPosition = root.Position
		state.lastTime = now
		return
	end

	local currentPosition = root.Position
	local previousPosition = state.lastPosition

	local horizontalDelta = Vector3.new(
		currentPosition.X - previousPosition.X,
		0,
		currentPosition.Z - previousPosition.Z
	)

	local distance = horizontalDelta.Magnitude
	local speed = distance / dt

	local allowedSpeed = Config.Speed.RunSpeed + Config.Speed.MaxExtraSpeed
	local humanoidAllowed = humanoid.WalkSpeed + Config.Speed.MaxExtraSpeed
	allowedSpeed = math.max(allowedSpeed, humanoidAllowed)

	if distance > Config.Speed.MaxTeleportDistance then
		addStrike(player, "teleport/snap movement: " .. math.floor(distance) .. " studs")
	elseif speed > allowedSpeed then
		addStrike(player, "speed: " .. math.floor(speed) .. " > " .. math.floor(allowedSpeed))
	end

	state.lastPosition = currentPosition
	state.lastTime = now
end

--// REMOTE SECURITY
local function checkRemoteRate(player)
	local now = os.clock()
	local userId = player.UserId

	RemoteRate[userId] = RemoteRate[userId] or {
		windowStart = now,
		count = 0,
	}

	local rate = RemoteRate[userId]

	if now - rate.windowStart >= 1 then
		rate.windowStart = now
		rate.count = 0
	end

	rate.count += 1

	return rate.count <= Config.RemoteSecurity.MaxCallsPerSecond
end

local function addBadRemoteCall(player, reason)
	local userId = player.UserId

	BadRemoteCalls[userId] = BadRemoteCalls[userId] or {
		count = 0,
		reasons = {},
	}

	BadRemoteCalls[userId].count += 1
	table.insert(BadRemoteCalls[userId].reasons, reason)

	warnLog("Bad remote call from", player.Name, reason)

	if BadRemoteCalls[userId].count >= Config.RemoteSecurity.MaxBadCalls then
		safeKick(player, Config.Messages.RemoteKick)
	end
end

--// LIVE UPDATE
local function parseVersion(version)
	local major, minor, patch = string.match(tostring(version), "^(%d+)%.(%d+)%.(%d+)$")

	return {
		major = tonumber(major) or 0,
		minor = tonumber(minor) or 0,
		patch = tonumber(patch) or 0,
	}
end

local function isNewerVersion(newVersion, currentVersion)
	local newV = parseVersion(newVersion)
	local curV = parseVersion(currentVersion)

	if newV.major ~= curV.major then
		return newV.major > curV.major
	end

	if newV.minor ~= curV.minor then
		return newV.minor > curV.minor
	end

	return newV.patch > curV.patch
end

local function applyLiveConfig(data, source)
	if typeof(data) ~= "table" then
		return false, "invalid live config"
	end

	if typeof(data.Version) ~= "string" then
		return false, "missing version"
	end

	if not isNewerVersion(data.Version, LiveState.AppliedVersion) and data.Force ~= true then
		return false, "not newer version"
	end

	-- Only safe fields are applied. No remote Lua code execution.
	if typeof(data.Enabled) == "boolean" then
		Config.Enabled = data.Enabled
	end

	if typeof(data.DefaultLanguage) == "string" then
		local language = normalizeLanguage(data.DefaultLanguage)
		if language then
			Config.DefaultLanguage = language
		end
	end

	if typeof(data.Speed) == "table" then
		Config.Speed.RunSpeed = safeNumber(data.Speed.RunSpeed, 8, 200, Config.Speed.RunSpeed)
		Config.Speed.MaxExtraSpeed = safeNumber(data.Speed.MaxExtraSpeed, 0, 100, Config.Speed.MaxExtraSpeed)
		Config.Speed.MaxTeleportDistance = safeNumber(data.Speed.MaxTeleportDistance, 10, 500, Config.Speed.MaxTeleportDistance)
		Config.Speed.StrikesToKick = safeNumber(data.Speed.StrikesToKick, 1, 20, Config.Speed.StrikesToKick)
		Config.Speed.StrictStrikesToKick = safeNumber(data.Speed.StrictStrikesToKick, 1, 20, Config.Speed.StrictStrikesToKick)
	end

	if typeof(data.RemoteSecurity) == "table" then
		Config.RemoteSecurity.MaxCallsPerSecond = safeNumber(
			data.RemoteSecurity.MaxCallsPerSecond,
			1,
			100,
			Config.RemoteSecurity.MaxCallsPerSecond
		)

		Config.RemoteSecurity.MaxBadCalls = safeNumber(
			data.RemoteSecurity.MaxBadCalls,
			1,
			20,
			Config.RemoteSecurity.MaxBadCalls
		)

		if typeof(data.RemoteSecurity.KickOnHoneypot) == "boolean" then
			Config.RemoteSecurity.KickOnHoneypot = data.RemoteSecurity.KickOnHoneypot
		end

		if typeof(data.RemoteSecurity.KickOnUnauthorizedAdminRemote) == "boolean" then
			Config.RemoteSecurity.KickOnUnauthorizedAdminRemote = data.RemoteSecurity.KickOnUnauthorizedAdminRemote
		end
	end

	if typeof(data.Messages) == "table" then
		if typeof(data.Messages.SpeedKick) == "string" then
			Config.Messages.SpeedKick = data.Messages.SpeedKick
		end

		if typeof(data.Messages.RemoteKick) == "string" then
			Config.Messages.RemoteKick = data.Messages.RemoteKick
		end

		if typeof(data.Messages.Unauthorized) == "string" then
			Config.Messages.Unauthorized = data.Messages.Unauthorized
		end
	end

	LiveState.AppliedVersion = data.Version
	LiveState.LastUpdateTime = os.time()
	LiveState.LastUpdateBy = tostring(data.UpdatedBy or source or "unknown")

	log("Live update applied:", LiveState.AppliedVersion, "source:", source or "unknown")
	return true, "applied"
end

local function loadLiveConfig(source)
	if not Config.LiveUpdate.Enabled then
		return false
	end

	local success, data = pcall(function()
		return LiveStore:GetAsync(Config.LiveUpdate.ConfigKey)
	end)

	if not success then
		warnLog("Live update load failed:", data)
		return false
	end

	if data then
		local ok, reason = applyLiveConfig(data, source or "datastore")
		if not ok then
			log("Live update skipped:", reason)
		end

		return ok
	end

	return false
end

local function publishLiveConfig(admin, newData)
	if not isOwner(admin) then
		privateKey(admin, "NoAccess")
		return false
	end

	if typeof(newData) ~= "table" then
		privateMessage(admin, "Invalid live config.")
		return false
	end

	if typeof(newData.Version) ~= "string" then
		privateMessage(admin, "Live config needs Version, example: 1.0.1")
		return false
	end

	newData.UpdatedAt = os.time()
	newData.UpdatedBy = admin.Name .. " / " .. admin.UserId
	newData.AllowRemoteCodeExecution = false

	local success, err = pcall(function()
		LiveStore:UpdateAsync(Config.LiveUpdate.ConfigKey, function(old)
			if typeof(old) == "table" and typeof(old.Version) == "string" then
				if not isNewerVersion(newData.Version, old.Version) and newData.Force ~= true then
					return old
				end
			end

			return newData
		end)
	end)

	if not success then
		warnLog("Live update save failed:", err)
		privateMessage(admin, "Live update save failed.")
		return false
	end

	applyLiveConfig(newData, "owner")

	pcall(function()
		MessagingService:PublishAsync(Config.LiveUpdate.MessageTopic, {
			Type = "NST_LIVE_UPDATE",
			Version = newData.Version,
			UpdatedBy = admin.UserId,
			Time = os.time(),
		})
	end)

	privateMessage(admin, "NST-Tool updated live to version " .. newData.Version)
	return true
end

local function startLiveUpdateListener()
	if not Config.LiveUpdate.Enabled then
		return
	end

	local subscribeSuccess, subscribeErr = pcall(function()
		MessagingService:SubscribeAsync(Config.LiveUpdate.MessageTopic, function(message)
			local data = message.Data

			if typeof(data) == "table" and data.Type == "NST_LIVE_UPDATE" then
				log("Live update signal received:", tostring(data.Version))
				loadLiveConfig("messaging")
			end
		end)
	end)

	if not subscribeSuccess then
		warnLog("MessagingService subscribe failed:", subscribeErr)
	end

	task.spawn(function()
		while task.wait(Config.LiveUpdate.CheckEverySeconds) do
			loadLiveConfig("periodic")
		end
	end)

	task.defer(function()
		loadLiveConfig("startup")
	end)
end

--// COMMAND EXECUTION
local executeNSTCommand

local function makeLiveConfig(newVersion, mode)
	local liveConfig = {
		Version = newVersion,
		Enabled = true,
		DefaultLanguage = Config.DefaultLanguage,

		Speed = {
			RunSpeed = Config.Speed.RunSpeed,
			MaxExtraSpeed = Config.Speed.MaxExtraSpeed,
			MaxTeleportDistance = Config.Speed.MaxTeleportDistance,
			StrikesToKick = Config.Speed.StrikesToKick,
			StrictStrikesToKick = Config.Speed.StrictStrikesToKick,
		},

		RemoteSecurity = {
			MaxCallsPerSecond = Config.RemoteSecurity.MaxCallsPerSecond,
			MaxBadCalls = Config.RemoteSecurity.MaxBadCalls,
			KickOnHoneypot = Config.RemoteSecurity.KickOnHoneypot,
			KickOnUnauthorizedAdminRemote = Config.RemoteSecurity.KickOnUnauthorizedAdminRemote,
		},

		Messages = {
			SpeedKick = Config.Messages.SpeedKick,
			RemoteKick = Config.Messages.RemoteKick,
			Unauthorized = Config.Messages.Unauthorized,
		}
	}

	mode = string.lower(tostring(mode or "normal"))

	if mode == "strict" then
		liveConfig.Speed.MaxExtraSpeed = 4
		liveConfig.Speed.StrikesToKick = 2
		liveConfig.Speed.StrictStrikesToKick = 1
		liveConfig.RemoteSecurity.MaxCallsPerSecond = 8
		liveConfig.RemoteSecurity.MaxBadCalls = 2

	elseif mode == "extreme" then
		liveConfig.Speed.MaxExtraSpeed = 2
		liveConfig.Speed.StrikesToKick = 1
		liveConfig.Speed.StrictStrikesToKick = 1
		liveConfig.RemoteSecurity.MaxCallsPerSecond = 5
		liveConfig.RemoteSecurity.MaxBadCalls = 1

	elseif mode == "soft" then
		liveConfig.Speed.MaxExtraSpeed = 12
		liveConfig.Speed.StrikesToKick = 6
		liveConfig.Speed.StrictStrikesToKick = 3
		liveConfig.RemoteSecurity.MaxCallsPerSecond = 20
		liveConfig.RemoteSecurity.MaxBadCalls = 5
	end

	return liveConfig
end

executeNSTCommand = function(player, message, fromPrivateConsole)
	if typeof(message) ~= "string" then
		return
	end

	if string.sub(message, 1, 1) ~= "!" then
		privateKey(player, "UnknownCommand")
		return
	end

	local args = {}
	for word in string.gmatch(message, "%S+") do
		table.insert(args, word)
	end

	local command = string.lower(args[1] or "")

	if command == "!language" then
		local language = normalizeLanguage(args[2])

		if language then
			PlayerLanguage[player.UserId] = language
			privateKey(player, "LanguageChanged")
		else
			privateMessage(player, "!language Russian / !language English")
		end

		return
	end

	if not isModerator(player) then
		privateKey(player, "NoAccess")
		return
	end

	if command == "!nst" then
		local sub = string.lower(args[2] or "")

		if sub == "help" then
			privateMessage(player, tr(player, "Help"))

		elseif sub == "info" then
			local target = findPlayer(args[3])

			if target then
				local stats = getPlayerStats(target)

				privateMessage(player,
					"NST Info: " .. target.Name ..
					"\nUserId: " .. target.UserId ..
					"\nStrikes: " .. stats.Strikes ..
					"\nLast reason: " .. stats.LastReason ..
					"\nWatchlisted: " .. tostring(stats.IsWatchlisted) ..
					"\nFrozen: " .. tostring(stats.IsFrozen) ..
					"\nOwner: " .. tostring(stats.IsOwner) ..
					"\nAdmin: " .. tostring(stats.IsAdmin) ..
					"\nModerator: " .. tostring(stats.IsModerator) ..
					"\nAnticheat enabled: " .. tostring(stats.AnticheatEnabled) ..
					"\nLive version: " .. tostring(stats.LiveVersion)
				)
			else
				privateKey(player, "PlayerNotFound")
			end

		elseif sub == "version" then
			privateMessage(player,
				"NST-Tool Core Version: " .. tostring(Config.Version) ..
				"\nLive Version: " .. tostring(LiveState.AppliedVersion) ..
				"\nAntiCheat Enabled: " .. tostring(Config.Enabled) ..
				"\nLast Update By: " .. tostring(LiveState.LastUpdateBy)
			)

		elseif sub == "update" then
			if not isOwner(player) then
				privateKey(player, "NoAccess")
				return
			end

			local newVersion = args[3] or "1.0.1"
			local mode = args[4] or "normal"
			publishLiveConfig(player, makeLiveConfig(newVersion, mode))

		elseif sub == "on" then
			if not isOwner(player) then
				privateKey(player, "NoAccess")
				return
			end

			Config.Enabled = true
			privateKey(player, "AnticheatEnabled")

		elseif sub == "off" then
			if not isOwner(player) then
				privateKey(player, "NoAccess")
				return
			end

			Config.Enabled = false
			privateKey(player, "AnticheatDisabled")

		else
			privateKey(player, "UnknownCommand")
		end

	elseif command == "!kick" then
		local target = findPlayer(args[2])
		if target then
			safeKick(target, "Kicked by NST-Tool moderator.")
			privateKey(player, "Done")
		else
			privateKey(player, "PlayerNotFound")
		end

	elseif command == "!ban" then
		if not isAdmin(player) then
			privateKey(player, "NoAccess")
			return
		end

		local target = findPlayer(args[2])
		local duration = tonumber(args[3]) or Config.Ban.Duration

		if target then
			banPlayer(player, target.UserId, duration, Config.Ban.DisplayReason)
			privateKey(player, "Done")
		else
			privateKey(player, "PlayerNotFound")
		end

	elseif command == "!unban" then
		if not isAdmin(player) then
			privateKey(player, "NoAccess")
			return
		end

		local userId = tonumber(args[2])

		if userId then
			unbanUser(player, userId)
			privateKey(player, "Done")
		else
			privateMessage(player, "Usage: !unban UserId")
		end

	elseif command == "!freeze" then
		local target = findPlayer(args[2])
		if target then
			freezePlayer(target)
			privateKey(player, "Done")
		else
			privateKey(player, "PlayerNotFound")
		end

	elseif command == "!unfreeze" then
		local target = findPlayer(args[2])
		if target then
			unfreezePlayer(target)
			privateKey(player, "Done")
		else
			privateKey(player, "PlayerNotFound")
		end

	elseif command == "!give" then
		if not isAdmin(player) then
			privateKey(player, "NoAccess")
			return
		end

		local target = findPlayer(args[2])
		local itemName = args[3]

		if target and itemName then
			if giveItem(player, target, itemName) then
				privateKey(player, "Done")
			end
		else
			privateMessage(player, "Usage: !give Player ItemName")
		end

	elseif command == "!admin" then
		if not isOwner(player) then
			privateKey(player, "NoAccess")
			return
		end

		local action = string.lower(args[2] or "")
		local target = findPlayer(args[3])

		if target and action == "add" then
			Config.Admins[target.UserId] = true
			privateKey(player, "Done")

		elseif target and action == "remove" then
			Config.Admins[target.UserId] = nil
			privateKey(player, "Done")

		else
			privateMessage(player, "Usage: !admin add Player / !admin remove Player")
		end

	elseif command == "!mod" then
		if not isAdmin(player) then
			privateKey(player, "NoAccess")
			return
		end

		local action = string.lower(args[2] or "")
		local target = findPlayer(args[3])

		if target and action == "add" then
			Config.Moderators[target.UserId] = true
			privateKey(player, "Done")

		elseif target and action == "remove" then
			Config.Moderators[target.UserId] = nil
			privateKey(player, "Done")

		else
			privateMessage(player, "Usage: !mod add Player / !mod remove Player")
		end

	elseif command == "!watch" then
		local action = string.lower(args[2] or "")
		local target = findPlayer(args[3])

		if target and action == "add" then
			Watchlist[target.UserId] = true
			privateKey(player, "Done")

		elseif target and action == "remove" then
			Watchlist[target.UserId] = nil
			privateKey(player, "Done")

		else
			privateMessage(player, "Usage: !watch add Player / !watch remove Player")
		end

	elseif command == "!lock" then
		if not isAdmin(player) then
			privateKey(player, "NoAccess")
			return
		end

		local action = string.lower(args[2] or "")

		if action == "on" then
			ServerLocked = true
			privateKey(player, "Done")

		elseif action == "off" then
			ServerLocked = false
			privateKey(player, "Done")

		else
			privateMessage(player, "Usage: !lock on / !lock off")
		end

	else
		privateKey(player, "UnknownCommand")
	end
end

--// REMOTES + HONEYPOTS
local function setupRemotes()
	local folder = ReplicatedStorage:FindFirstChild("NST_Remotes")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NST_Remotes"
		folder.Parent = ReplicatedStorage
	end

	PrivateMessageRemote = folder:FindFirstChild("PrivateMessage")
	if not PrivateMessageRemote then
		PrivateMessageRemote = Instance.new("RemoteEvent")
		PrivateMessageRemote.Name = "PrivateMessage"
		PrivateMessageRemote.Parent = folder
	end

	AdminActionRemote = folder:FindFirstChild("AdminAction")
	if not AdminActionRemote then
		AdminActionRemote = Instance.new("RemoteEvent")
		AdminActionRemote.Name = "AdminAction"
		AdminActionRemote.Parent = folder
	end

	AdminActionRemote.OnServerEvent:Connect(function(player, action, targetNameOrUserId, extra)
		if not checkRemoteRate(player) then
			safeKick(player, "NST-Tool: remote spam detected.")
			return
		end

		if action == "RunCommand" then
			if typeof(targetNameOrUserId) == "string" then
				executeNSTCommand(player, targetNameOrUserId, true)
			end
			return
		end

		if action == "SetLanguage" then
			local language = normalizeLanguage(targetNameOrUserId)
			if language then
				PlayerLanguage[player.UserId] = language
				privateKey(player, "LanguageChanged")
			end
			return
		end

		if action == "SetAnticheatEnabled" then
			if not isOwner(player) then
				addBadRemoteCall(player, "non-owner tried SetAnticheatEnabled")
				return
			end

			Config.Enabled = targetNameOrUserId == true

			if Config.Enabled then
				privateKey(player, "AnticheatEnabled")
			else
				privateKey(player, "AnticheatDisabled")
			end

			return
		end

		if not isModerator(player) then
			addBadRemoteCall(player, "unauthorized admin remote")
			if Config.RemoteSecurity.KickOnUnauthorizedAdminRemote then
				safeKick(player, Config.Messages.Unauthorized)
			end
			return
		end

		if typeof(action) ~= "string" then
			addBadRemoteCall(player, "invalid action type")
			return
		end

		local target

		if typeof(targetNameOrUserId) == "number" then
			target = Players:GetPlayerByUserId(targetNameOrUserId)
		elseif typeof(targetNameOrUserId) == "string" then
			target = findPlayer(targetNameOrUserId)
		end

		if action == "Kick" then
			if target then
				safeKick(target, "Kicked by NST-Tool moderator.")
				privateKey(player, "Done")
			else
				privateKey(player, "PlayerNotFound")
			end

		elseif action == "Freeze" then
			if target then
				freezePlayer(target)
				privateKey(player, "Done")
			else
				privateKey(player, "PlayerNotFound")
			end

		elseif action == "Unfreeze" then
			if target then
				unfreezePlayer(target)
				privateKey(player, "Done")
			else
				privateKey(player, "PlayerNotFound")
			end

		elseif action == "GiveItem" then
			if not isAdmin(player) then
				addBadRemoteCall(player, "non-admin tried GiveItem")
				return
			end

			if target and typeof(extra) == "string" then
				if giveItem(player, target, extra) then
					privateKey(player, "Done")
				end
			else
				privateKey(player, "PlayerNotFound")
			end

		elseif action == "Ban" then
			if not isAdmin(player) then
				addBadRemoteCall(player, "non-admin tried Ban")
				return
			end

			if target then
				banPlayer(player, target.UserId, Config.Ban.Duration, Config.Ban.DisplayReason)
				privateKey(player, "Done")
			else
				privateKey(player, "PlayerNotFound")
			end

		else
			addBadRemoteCall(player, "unknown action: " .. action)
		end
	end)

	local honeypotNames = {
		"GiveMoney",
		"GiveItem",
		"AdminCommand",
		"BanPlayer",
		"SetWalkSpeed",
		"FreeAdmin",
		"NST_Bypass",
	}

	for _, remoteName in ipairs(honeypotNames) do
		local remote = ReplicatedStorage:FindFirstChild(remoteName)

		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = ReplicatedStorage
		end

		remote.OnServerEvent:Connect(function(player)
			warnLog("HONEYPOT fired by", player.Name, "remote:", remoteName)

			if Config.RemoteSecurity.KickOnHoneypot then
				safeKick(player, Config.Messages.Honeypot)
			end
		end)
	end
end

--// OPTIONAL TEXT CHAT COMMAND SUPPORT
--// This creates /nst command if TextChatService supports it.
--// It is safer than typing ! commands directly into public chat.
local function setupTextChatCommand()
	local ok, err = pcall(function()
		local command = TextChatService:FindFirstChild("NSTCommand")

		if not command then
			command = Instance.new("TextChatCommand")
			command.Name = "NSTCommand"
			command.PrimaryAlias = "/nst"
			command.SecondaryAlias = "/n"
			command.Parent = TextChatService
		end

		command.Triggered:Connect(function(textSource, unfilteredText)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if not player then
				return
			end

			-- Usage example:
			-- /nst !nst help
			-- /nst !kick Player
			local cleaned = tostring(unfilteredText or "")
			cleaned = string.gsub(cleaned, "^/nst%s*", "")
			cleaned = string.gsub(cleaned, "^/n%s*", "")

			if cleaned == "" then
				cleaned = "!nst help"
			end

			executeNSTCommand(player, cleaned, true)
		end)
	end)

	if not ok then
		warnLog("TextChatCommand setup failed:", err)
	end
end

--// PLAYER EVENTS
local function setupPlayer(player)
	if ServerLocked and not isAdmin(player) then
		safeKick(player, Config.Messages.ServerLocked)
		return
	end

	PlayerLanguage[player.UserId] = Config.DefaultLanguage

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		resetPlayerState(player)

		if Frozen[player.UserId] then
			task.wait(0.5)
			freezePlayer(player)
		end
	end)

	-- WARNING:
	-- Public chat commands are disabled by default to avoid showing commands to everyone.
	-- If you want legacy chat commands, uncomment this block:
	--
	-- player.Chatted:Connect(function(message)
	-- 	executeNSTCommand(player, message, false)
	-- end)

	task.defer(function()
		if player.Character then
			resetPlayerState(player)
		end
	end)

	log("Player checked:", player.Name, player.UserId)

	if isModerator(player) then
		privateMessage(player, "NST-Tool loaded. Use /nst !nst help or enable a custom GUI client.")
	end
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	PlayerState[player] = nil
	RemoteRate[player.UserId] = nil
	BadRemoteCalls[player.UserId] = nil
	PlayerLanguage[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

--// MAIN START
setupRemotes()
setupTextChatCommand()
startLiveUpdateListener()

RunService.Heartbeat:Connect(function(dt)
	if not Config.Enabled then
		return
	end

	Accumulator += dt

	if Accumulator < Config.Speed.CheckInterval then
		return
	end

	Accumulator = 0

	for _, player in ipairs(Players:GetPlayers()) do
		checkSpeed(player)
	end
end)

log("NST-Tool OneFile loaded successfully.")
