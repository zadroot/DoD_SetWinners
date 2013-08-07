/**
* DoD:S Set Winners by Root
*
* Description:
*   Simply sets winners in favor of team which had more tick points.
*
* Version 1.0
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1
#include <dodhooks>

// ====[ CONSTANTS ]==============================================================
#define PLUGIN_NAME    "DoD:S Set Winners"
#define PLUGIN_VERSION "1.0"

enum
{
	TEAM_ALLIES = 2,
	TEAM_AXIS,
	TEAM_SIZE
}

// ====[ VARIABLES ]==============================================================
new	Handle:PWT_Enabled,
	Handle:mp_timelimit,
	Handle:dod_bonusroundtime,
	Handle:dod_finishround_source,
	Handle:WinnersTimer,
	TeamPoints[TEAM_SIZE];

// ====[ PLUGIN ]=================================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Simply sets winners in favor of team which had more tick points",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
};


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ------------------------------------------------------------------------------- */
public OnPluginStart()
{
	CreateConVar("dod_setwinners_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	PWT_Enabled = CreateConVar("dod_setwinners_enabled", "1", "Whether or not set winners in favor of team which has more tick points", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	// Retrieve stock ConVars
	mp_timelimit           = FindConVar("mp_timelimit");
	dod_bonusroundtime     = FindConVar("dod_bonusroundtime");

	// And custom one to automatically disable plugin
	dod_finishround_source = FindConVar("dod_finishround_source");

	// Hook changes for mp_timelimit and dod_bonusround
	HookConVarChange(mp_timelimit,       OnTimeChanged);
	HookConVarChange(dod_bonusroundtime, OnTimeChanged);

	// Hook events to deal with tick points
	HookEvent("dod_tick_points", OnPointsReceive, EventHookMode_Post);
	HookEvent("dod_round_start", OnRoundStart, EventHookMode_PostNoCopy);
}


/* OnConfigsExecuted()
 *
 * When the map has loaded and all plugin configs are done executing.
 * ------------------------------------------------------------------------------- */
public OnConfigsExecuted()
{
	WinnersTimer = INVALID_HANDLE;
	CreateWinnersTimer(false);
}

/* OnTimeChanged()
 *
 * Called when timelimit or bonusround time values has changed.
 * ------------------------------------------------------------------------------- */
public OnTimeChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Create new round timer and set 'changed' bool as true to set time properly
	CreateWinnersTimer(true);
}

/* OnPointsReceive()
 *
 * When team is received tick points.
 * ------------------------------------------------------------------------------- */
public OnPointsReceive(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Add points for appropriate team
	TeamPoints[GetEventInt(event, "team")] += GetEventInt(event, "score");
}

/* OnRoundStart()
 *
 * When new round starts.
 * ------------------------------------------------------------------------------- */
public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Reset amount of points for both teams
	TeamPoints[TEAM_ALLIES] = TeamPoints[TEAM_AXIS] = 0;
}

/* Timer_SetWinners()
 *
 * Timer to set winning team.
 * ------------------------------------------------------------------------------- */
public Action:Timer_SetWinners(Handle:timer)
{
	WinnersTimer = INVALID_HANDLE;

	// Make sure dod_finishround_source convar is disabled (if even exists)
	if (dod_finishround_source != INVALID_HANDLE
	&& GetConVarBool(dod_finishround_source) == true)
	{
		// It's enabled - so now stop the timer to prevent SetWinningTeam callback
		return Plugin_Stop;
	}

	new winners; // Retrieve the winning team by tick points
	for (new i = 0; i < TEAM_SIZE; i++)
	{
		// If one team has more points than other, then we've got a winner!
		if (TeamPoints[i] > TeamPoints[winners]) winners = i;
	}

	// Does plugin is enabled and any tick points were received during last round?
	if (GetConVarBool(PWT_Enabled) && TeamPoints[winners] > 0)
	{
		// Yep, call DoD Hooks native to set winning team (too bad GameRules_SetProp not working)
		SetWinningTeam(winners);
	}

	return Plugin_Stop;
}

/* CreateWinnersTimer()
 *
 * Creates a global timer to set winning team.
 * ------------------------------------------------------------------------------- */
CreateWinnersTimer(bool:changed)
{
	// Get the time limit at this moment for a current map
	new timeleft;
	if (GetMapTimeLeft(timeleft))
	{
		// We cant GetMapTimeLeft during mapchanges
		// So when map is changed - set timeleft as timelimit value * 60
		if (changed == false) timeleft = GetConVarInt(mp_timelimit) * 60;

		// Retrieve the time of a bonus round
		new Float:bonustime = FloatSub(GetConVarFloat(dod_bonusroundtime), 1.0);

		// Timer is not yet killed? Then kill it immediately to prevent errors
		if (WinnersTimer != INVALID_HANDLE)
		{
			KillTimer(WinnersTimer);
			WinnersTimer = INVALID_HANDLE;
		}

		// Create global timer equal to (timelimit - bonusroundtime) to set winning team in a proper event
		WinnersTimer = CreateTimer(FloatSub(float(timeleft), bonustime), Timer_SetWinners, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}