--!strict
-- Ambiance jour/nuit (002-premier-increment-jouable, FR-024, FR-025 ; research R6). Le serveur
-- tweene Lighting à chaque changement de phase : ses propriétés se répliquent comme celles de
-- Workspace, aucun contrôleur client n'est nécessaire (une seule source de vérité, principe III).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)
local MatchService = require(script.Parent.MatchService)

type Phase = Types.Phase

-- Constantes esthétiques : pas des valeurs d'équilibrage (comme Catalog.COLORS).
local DAY_FOG_COLOR = Color3.fromRGB(200, 210, 220)
local NIGHT_FOG_COLOR = Color3.fromRGB(10, 12, 20)
local DAY_CLOCK_TIME = 14
local NIGHT_CLOCK_TIME = 0

local log = Log.new("Ambiance")

local AmbianceService = { Name = "AmbianceService", Priority = 52 }

local function applyAmbiance(phase: Phase, animate: boolean)
	local night = phase == "Night"
	local brightness: number = Config.get("Ambiance", if night then "NightBrightness" else "DayBrightness")
	local fogEnd: number = Config.get("Ambiance", if night then "NightFogEnd" else "DayFogEnd")
	local clockTime = if night then NIGHT_CLOCK_TIME else DAY_CLOCK_TIME
	local fogColor = if night then NIGHT_FOG_COLOR else DAY_FOG_COLOR

	if not animate then
		Lighting.Brightness = brightness
		Lighting.ClockTime = clockTime
		Lighting.FogEnd = fogEnd
		Lighting.FogColor = fogColor
		return
	end

	local duration: number = Config.get("Ambiance", "TransitionDuration", MatchService.isTestProfile())
	TweenService:Create(Lighting, TweenInfo.new(duration), {
		Brightness = brightness,
		ClockTime = clockTime,
		FogEnd = fogEnd,
		FogColor = fogColor,
	}):Play()
end

function AmbianceService.Init()
	MatchService.PhaseStarted:Connect(function(phase: Phase, _night: number)
		applyAmbiance(phase, true)
	end)
	applyAmbiance(MatchService.getPhase(), false) -- état initial, sans transition à jouer
	log:info("Ambiance prête")
end

return AmbianceService
