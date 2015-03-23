#include <sourcemod>
#include <sdktools>

/*
	1.0:
		- Release
*/

public Plugin:myinfo =
{
	name        = "Spawn Points [SP]",
	author      = "[GFL]Roy (Christian Deacon)",
	description = "Enforces a minimum amount of spawns for teams.",
	version     = "1.0",
	url         = "http://GFLClan.com/"
};

new Handle:g_cvarTSpawns = INVALID_HANDLE;
new icvarTSpawns;
new Handle:g_cvarCTSpawns = INVALID_HANDLE;
new icvarCTSpawns;
new Handle:g_cvarTeams = INVALID_HANDLE;
new icvarTeams;
new Handle:g_cvarCourse = INVALID_HANDLE;
new bool:bcvarCourse;
new Handle:g_cvarDebug = INVALID_HANDLE;
new bool:bcvarDebug;
new Handle:g_cvarAuto = INVALID_HANDLE;
new bool:bcvarAuto;
new Handle:g_cvarMapStartDelay = INVALID_HANDLE;
new Float:fcvarMapStartDelay;

new bool:bMapStart;

public OnPluginStart()
{
	g_cvarTSpawns = CreateConVar("sm_SP_spawns_t", "32", "Amount of spawn points to enforce on T.");
	g_cvarCTSpawns = CreateConVar("sm_SP_spawns_ct", "32", "Amount of spawn points to enforce on CT.");
	g_cvarTeams = CreateConVar("sm_SP_teams", "1", "0 = Disabled, 1 = All Teams, 2 = Terrorist only, 3 = Counter-Terrorist only.");
	g_cvarCourse = CreateConVar("sm_SP_course", "1", "1 = When T or CT spawns are at 0, the opposite team will get double the spawn points.");
	g_cvarDebug = CreateConVar("sm_SP_debug", "0", "1 = Enable debugging.");
	g_cvarAuto = CreateConVar("sm_SP_auto", "0", "1 = Add the spawn points as soon as a ConVar is changed.");
	g_cvarMapStartDelay = CreateConVar("sm_SP_mapstart_delay", "1.0", "The delay of the timer on map start to add in spawn points.");
	
	HookConVarChange(g_cvarTSpawns, CVarChanged);
	HookConVarChange(g_cvarCTSpawns, CVarChanged);
	HookConVarChange(g_cvarTeams, CVarChanged);
	HookConVarChange(g_cvarCourse, CVarChanged);
	HookConVarChange(g_cvarDebug, CVarChanged);
	HookConVarChange(g_cvarAuto, CVarChanged);
	HookConVarChange(g_cvarMapStartDelay, CVarChanged);
	
	GetValues();
	bMapStart = false;
	
	RegAdminCmd("sm_addspawns", Command_AddSpawns, ADMFLAG_ROOT);
	
	AutoExecConfig(true, "sm_SP");
}

public Action:Command_AddSpawns(client, args) {
	AddMapSpawns();
	
	if (client == 0) {
		PrintToServer("[SP] Added map spawns!");
	} else {
		PrintToChat(client, "\x02[SP] \x03Added map spawns!");
	}
	
	return Plugin_Handled;
}

public CVarChanged(Handle:convar, const String:oldv[], const String:newv[]) {
	OnConfigsExecuted();
}

public OnConfigsExecuted() {
	GetValues();
	
	// Messy way but whatever, best solution I could think of.
	if (!bMapStart) {
		if (fcvarMapStartDelay > 0.0) {
			CreateTimer(fcvarMapStartDelay, timer_DelayAddSpawnPoints);
		}
		bMapStart = true;
	}
	
	if (bcvarAuto && bMapStart) {
		AddMapSpawns();
	}
}

public Action:timer_DelayAddSpawnPoints(Handle:timer) {
	AddMapSpawns();
}

stock GetValues() {
	icvarTSpawns = GetConVarInt(g_cvarTSpawns);
	icvarCTSpawns = GetConVarInt(g_cvarCTSpawns);
	icvarTeams = GetConVarInt(g_cvarTeams);
	bcvarCourse = GetConVarBool(g_cvarCourse);
	bcvarDebug = GetConVarBool(g_cvarDebug);
	bcvarAuto = GetConVarBool(g_cvarAuto);
	fcvarMapStartDelay = GetConVarFloat(g_cvarMapStartDelay);
}

stock AddMapSpawns() {
	new iTSpawns = 0;
	new iCTSpawns = 0;
	
	new idTSpawns = 0;
	new idCTSpawns = 0;
	
	new Float:fVecCt[3];
	new Float:fVecT[3];
	new Float:angVec[3];
	decl String:sClassName[64];
	
	for (new i = MaxClients; i < GetMaxEntities(); i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i) && GetEdictClassname(i, sClassName, sizeof(sClassName)))
		{
			if (StrEqual(sClassName, "info_player_terrorist"))
			{
				iTSpawns++;
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", fVecT);
			}
			else if (StrEqual(sClassName, "info_player_counterterrorist"))
			{
				iCTSpawns++;
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", fVecCt);
			}
		}
	}
	
	if (bcvarDebug) {
		LogMessage("There are %d/%d CT points and %d/%d T points", iCTSpawns, icvarCTSpawns, iTSpawns, icvarTSpawns);
	}
	
	if (bcvarCourse) {
		if (iCTSpawns == 0 && iTSpawns > 0) {
			icvarTSpawns *= 2;
		}
		
		if (iTSpawns == 0 && iCTSpawns > 0) {
			icvarCTSpawns *= 2;
		}
	}
	
	if(iCTSpawns && iCTSpawns < icvarCTSpawns && iCTSpawns > 0)
	{
		if (icvarTeams == 1 || icvarTeams == 3) {
			for(new i = iCTSpawns; i < icvarCTSpawns; i++)
			{
				new entity = CreateEntityByName("info_player_counterterrorist");
				if (DispatchSpawn(entity))
				{
					TeleportEntity(entity, fVecCt, angVec, NULL_VECTOR);
					if (bcvarDebug) {
						LogMessage("+1 CT spawn added!");
					}
				}
			}
		}
	}
	
	if(iTSpawns && iTSpawns < icvarTSpawns && iTSpawns > 0)
	{
		if (icvarTeams == 1 || icvarTeams == 2) {
			for(new i = iTSpawns; i < icvarTSpawns; i++)
			{
				new entity = CreateEntityByName("info_player_terrorist");
				if (DispatchSpawn(entity))
				{
					TeleportEntity(entity, fVecT, angVec, NULL_VECTOR);
					if (bcvarDebug) {
						LogMessage("+1 T spawn added!");
					}
				}
			}
		}
	}
	if (bcvarDebug) {
		
		for (new i = MaxClients; i < GetMaxEntities(); i++)
		{
			if (IsValidEdict(i) && IsValidEntity(i) && GetEdictClassname(i, sClassName, sizeof(sClassName)))
			{
				if (StrEqual(sClassName, "info_player_terrorist"))
				{
					idTSpawns++;
				}
				else if (StrEqual(sClassName, "info_player_counterterrorist"))
				{
					idCTSpawns++;
				}
			}
		}
		LogMessage("There are now %d CT spawns and %d T spawns", idCTSpawns, idTSpawns);
	}
}
