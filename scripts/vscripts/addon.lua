PREFIX = '[TECHIES] '

GameMode = nil
THINK_TIME=0.1
MAX_KILLS = 75

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
  self.timers = {}
  self.Countdown = 0
  self.isEntSpawned = false
  self.StopThink = false
  self.scoreRadiant = 0
  self.scoreDire = 0

  GameRules:SetUseUniversalShopMode( true )
  --GameRules:SetGoldPerTick(10)
  print(PREFIX..'Rules set!')

  ListenToGameEvent('player_connect_full', Dynamic_Wrap(Addon, 'onPlayerLoaded'), self)
  ListenToGameEvent('player_connect', Dynamic_Wrap(Addon, 'onPlayerConnect'), self)
  ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(Addon, 'onGameStateChanged'), self)
  ListenToGameEvent('entity_killed', Dynamic_Wrap(Addon, 'OnEntityKilled'), self)
  ListenToGameEvent('npc_spawned', Dynamic_Wrap(Addon, 'OnNPCSpawned'), self)
  print(PREFIX..'Hooks registered!')

  print(PREFIX..'Commands registered!')

  PrecacheUnitByName('npc_precache_everything')
  print(PREFIX..'Everything precached!')
end


function Addon:onPlayerLoaded(keys)

  Addon:CaptureGameMode()
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
  --ply:SetDeathXP(0)
  ply:AddExperience(3200, true)
  --for lvl=0,6,1 do
  --  ply:HeroLevelUp(false)
  --end
  ply:SetGold(1000, true)
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
    Addon:ShowCenterMessage("75 KILLS TO WIN",10)
    self.roshmid = CreateUnitByName( "npc_dota_roshan", Vector(-611,-258,74), true, nil, nil, DOTA_TEAM_NEUTRALS )
    self.roshtop = CreateUnitByName( "npc_dota_roshan", Vector(-6360,2835,233), true, nil, nil, DOTA_TEAM_NEUTRALS )
    self.roshbot = CreateUnitByName( "npc_dota_roshan", Vector(6234,-2621,230), true, nil, nil, DOTA_TEAM_NEUTRALS )
  end
end

function Addon:OnEntityKilled( keys )
  local killedUnit = EntIndexToHScript( keys.entindex_killed )
  local killerEntity = nil
  if keys.entindex_attacker ~= nil then
    killerEntity = EntIndexToHScript( keys.entindex_attacker )
  else
    return
  end
  local killedTeam = killedUnit:GetTeam()
  local killerTeam = killerEntity:GetTeam()

  if killedUnit:IsRealHero() == true then
    local death_count_down = 8
    killedUnit:SetTimeUntilRespawn(death_count_down)

    Addon:CreateTimer(DoUniqueString("respawn"), {
      endTime = GameRules:GetGameTime() + 1,
      useGameTime = true,
      callback = function(reflex, args)
        death_count_down = death_count_down - 1
        if death_count_down == 0 then
          --Respawn hero after 8 seconds
          killedUnit:RespawnHero(false,false,false)
          return
        else
          killedUnit:SetTimeUntilRespawn(death_count_down)
          return GameRules:GetGameTime() + 1
        end
      end
    })

    if killedTeam == DOTA_TEAM_BADGUYS then
      if killerTeam == 2 then
        self.scoreRadiant = self.scoreRadiant + 1
      end
    elseif killedTeam == DOTA_TEAM_GOODGUYS then
      if killerTeam == 3 then
        self.scoreDire = self.scoreDire + 1
      end
    end
    if self.scoreDire >= MAX_KILLS then
      GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
      GameRules:MakeTeamLose(DOTA_TEAM_GOODGUYS)
      GameRules:Defeated()
    end
    if self.scoreRadiant >= MAX_KILLS  then
      GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
      GameRules:MakeTeamLose(DOTA_TEAM_BADGUYS)
      GameRules:Defeated()
    end
  end
end

function Addon:CreateTimer(name, args)
  if not args.endTime or not args.callback then
    print("Invalid timer created: "..name)
    return
  end

  -- Store the timer
  self.timers[name] = args
end

function Addon:CaptureGameMode()
  if GameMode == nil then
    GameMode = GameRules:GetGameModeEntity()    
    GameMode:SetRecommendedItemsDisabled( true )
    GameMode:SetCustomBuybackCostEnabled( true )
    GameMode:SetCustomBuybackCooldownEnabled( true )
    GameMode:SetBuybackEnabled( false )

    print( '[TECHIES] Beginning Think' ) 
    GameMode:SetContextThink("TechiesThink", Dynamic_Wrap(Addon, 'Think' ), 0.1 )
  end 
end

function Addon:Think()
  -- If the game's over, it's over.
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    return
  end

  -- Track game time, since the dt passed in to think is actually wall-clock time not simulation time.
  local now = GameRules:GetGameTime()
  --print("now: " .. now)
  if Addon.t0 == nil then
    Addon.t0 = now
  end
  local dt = now - Addon.t0
  Addon.t0 = now

  --Addon:thinkState( dt )

  -- Process timers
  for k,v in pairs(Addon.timers) do
    local bUseGameTime = false
    if v.useGameTime and v.useGameTime == true then
      bUseGameTime = true;
    end
    -- Check if the timer has finished
    if (bUseGameTime and GameRules:GetGameTime() > v.endTime) or (not bUseGameTime and Time() > v.endTime) then
      -- Remove from timers list
      Addon.timers[k] = nil

      -- Run the callback
      local status, nextCall = pcall(v.callback, Addon, v)

      -- Make sure it worked
      if status then
        -- Check if it needs to loop
        if nextCall then
          -- Change it's end time
          v.endTime = nextCall
          Addon.timers[k] = v
        end

      else
        -- Nope, handle the error
        Addon:HandleEventError('Timer', k, nextCall)
      end
    end
  end

  return THINK_TIME
end

function Addon:OnNPCSpawned( keys )
  local spawnedUnit = EntIndexToHScript( keys.entindex )
end
