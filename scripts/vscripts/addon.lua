PREFIX = '[TECHIES] '

GameMode = nil

if Addon == nil then
	print ( PREFIX..'Creating Game Mode..' )
	Addon = {}
	Addon.szEntityClassName = "techies"
	Addon.szNativeClassName = "dota_base_game_mode"
	Addon.__index = Addon
end

function Addon:new( o )
	o = o or {}
	setmetatable( o, Addon )
	return o
end

function Addon:InitGameMode()
	print(PREFIX..'Initialization...')
	Addon:onEnable()
	local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
	math.randomseed(tonumber(timeTxt))

	print(PREFIX..'Done precaching!') 
	print(PREFIX..'DONE INITIALIZATION!\n\n')
end


function Addon:HandleEventError(name, event, err)

	-- Log to console
	print(PREFIX..err)

	-- Ensure we have data
	name = tostring(name or 'unknown')
	event = tostring(event or 'unknown')
	err = tostring(err or 'unknown')

	-- Tell everyone there was an error
	Say(nil, name .. ' threw an error on event '..event, false)
	Say(nil, err, false)

	-- Prevent loop arounds
	if not self.errorHandled then
		-- Store that we handled an error
		self.errorHandled = true
	end
end

function Addon:ShowCenterMessage(msg,dur)
	local msg = {
		message = msg,
		duration = dur
	}
	FireGameEvent("show_center_message",msg)
end

function GetNick(ply)
	return Addon.Nickname[ply]
end

function Addon:onEnable() -- This function called when mod is initializing

		-- Variables
	self.Players = {} -- Mirana's list
	self.PlayersIDs = {} -- Player's steamid list
	self.NicknameUserId = {}
	self.Nickname = {}
	self.Countdown = 0
	self.isEntSpawned = false
	self.StopThink = false
	
	GameRules:SetUseUniversalShopMode( true )
	print(PREFIX..'Rules set!')
	
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(Addon, 'onPlayerLoaded'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(Addon, 'onPlayerConnect'), self)
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(Addon, 'onGameStateChanged'), self)
	print(PREFIX..'Hooks registered!')
	
	print(PREFIX..'Commands registered!')

	PrecacheUnitByName('npc_precache_everything')
	print(PREFIX..'Everything precached!')
end


function Addon:onPlayerLoaded(keys)

	if GameMode == nil then
		GameMode = GameRules:GetGameModeEntity()
	end
	
	local ply = EntIndexToHScript(keys.index+1)
	local playerID = ply:GetPlayerID()

	if PlayerResource:IsBroadcaster(playerID) then
		return
	end
	
	if self.PlayersIDs[playerID] ~= nil then
		return
	end

	if playerID == -1 then
		ply:SetTeam(DOTA_TEAM_GOODGUYS)
		playerID = ply:GetPlayerID()
	end
	self.PlayersIDs[playerID] = 1337
	ply = CreateHeroForPlayer('npc_dota_hero_techies', ply)
	table.insert(self.Players,ply)
	
	self.Nickname[ply] = self.NicknameUserId[keys.userid]
end

function Addon:onPlayerConnect(keys)
	self.NicknameUserId[keys.userid] = keys.name
end

function Addon:onGameStateChanged()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then -- All players is loaded
		SendToServerConsole('sv_cheats 1')
		SendToServerConsole('dota_dev forcegamestart')
		SendToServerConsole('sv_cheats 0')
	end
end
