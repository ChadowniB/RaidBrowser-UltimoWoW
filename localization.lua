-- Localization (WotLK 3.3.5a)
-- Usage: local L = RaidBrowser.L; L.KEY returns localized string.
-- English is default; Spanish (esES) overrides.

RaidBrowser.L = RaidBrowser.L or {}
local L = RaidBrowser.L

-- Default (enUS / fallback)
local enUS = {
	RAID = "Raid",
	JOIN = "Join",
	FIND_RAID = "Find Raid",

	LAST_SENT = "Last sent: %d seconds ago",
	YOU_ARE_SAVED_FOR = "\nYou are |cffff0000saved|cffffd100 for %s",
	YOU_ARE_NOT_SAVED_FOR = "\nYou are |cff00ffffnot saved|cffffd100 for %s",
	LOCKOUT_EXPIRES_IN = "Lockout expires in %s",

	SECONDS_ZERO = "00 seconds",
	DAY_SINGULAR = "day",
	DAY_PLURAL = "days",
	HOUR_SINGULAR = "hr",
	HOUR_PLURAL = "hrs",
	MIN_SINGULAR = "min",
	MIN_PLURAL = "mins",

	ACTIVE = "Active",
	PRIMARY = "Primary",
	SECONDARY = "Secondary",
	FREE_SLOT = "Free slot",
	SAVE_RAID_GEAR = "Save Raid Gear",
	RAIDSET_SAVED = "Raidset saved: %s %sgs",

	LOADED = "loaded. Type /rb to toggle the raid browser.",
	PATTERN_MATCHED = "Pattern matched: %s",
	ROLE_PATTERN_FOUND = "Role pattern found for %s: %s",
	RAID_FOUND = "Raid found! %s: %s",
	MULTIPLE_RAIDS_FOUND = "Multiple raids found! %s - %s",
}

-- Spanish (esES)
local esES = {
	RAID = "Banda",
	JOIN = "Unirse",
	FIND_RAID = "Buscar banda",

	LAST_SENT = "Último envío: hace %d segundos",
	YOU_ARE_SAVED_FOR = "\nEstás |cffff0000guardado|cffffd100 para %s",
	YOU_ARE_NOT_SAVED_FOR = "\nNo estás |cff00ffffguardado|cffffd100 para %s",
	LOCKOUT_EXPIRES_IN = "El bloqueo termina en %s",

	SECONDS_ZERO = "00 segundos",
	DAY_SINGULAR = "día",
	DAY_PLURAL = "días",
	HOUR_SINGULAR = "h",
	HOUR_PLURAL = "h",
	MIN_SINGULAR = "min",
	MIN_PLURAL = "min",

	ACTIVE = "Activo",
	PRIMARY = "Primario",
	SECONDARY = "Secundario",
	FREE_SLOT = "Espacio libre",
	SAVE_RAID_GEAR = "Guardar equipo",
	RAIDSET_SAVED = "Conjunto guardado: %s %sGS",

	LOADED = "cargado. Escribe /rb para abrir/cerrar el navegador de bandas.",
	PATTERN_MATCHED = "Patrón coincidente: %s",
	ROLE_PATTERN_FOUND = "Patrón de rol encontrado para %s: %s",
	RAID_FOUND = "¡Banda encontrada! %s: %s",
	MULTIPLE_RAIDS_FOUND = "¡Varias bandas encontradas! %s - %s",
}

local function merge(dst, src)
	for k, v in pairs(src) do
		dst[k] = v
	end
end

-- Load defaults, then apply locale overrides
merge(L, enUS)

local locale = GetLocale and GetLocale() or "enUS"
if locale == "esES" then
	merge(L, esES)
end
