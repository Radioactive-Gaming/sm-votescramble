/**
 * votescramble.sp
 * License: GNU General Public License v3.0
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>

////////////////////////////////////////////////////////////////////////////////
//
// VARIABLES
//
////////////////////////////////////////////////////////////////////////////////

#define     PLUGIN_AUTHOR       "Dr. McKay, X8ETr1x"
#define     PLUGIN_DESC         "A vote scramble system that uses TF2's built-in scrambler when the next round begins."
#define     PLUGIN_NAME         "Better Vote Scramble"
#define     PLUGIN_URL          "https://github.com/Radioactive-Gaming/sm-votescramble"
#define     PLUGIN_VERSION      "1.4.0"

// CVar handles, defined in OnPluginStart().
Handle      cvarPercentage;
Handle      cvarVotesRequired;
Handle      mp_bonusroundtime;

bool votedToScramble[MAXPLAYERS + 1];
bool scrambleTeams;

////////////////////////////////////////////////////////////////////////////////
//
// ENUMS
//
////////////////////////////////////////////////////////////////////////////////

public Plugin myinfo = {
    name		= PLUGIN_NAME,
    author		= PLUGIN_AUTHOR,
    description	= PLUGIN_DESC,
    version		= PLUGIN_VERSION,
    url			= PLUGIN_URL
}

////////////////////////////////////////////////////////////////////////////////
//
// MAIN
//
////////////////////////////////////////////////////////////////////////////////

public void OnPluginStart() {
	cvarPercentage = CreateConVar("better_votescramble_percentage", "0.6", "Percentage required to initiate a team scramble");
	cvarVotesRequired = CreateConVar("better_votescramble_votes_required", "3", "Votes required to initiate a vote");
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_round_stalemate", Event_RoundEnd);
	HookEvent("teamplay_win_panel", Event_RoundEnd);
	
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	
	LoadTranslations("core.phrases");
}

public void OnClientConnected(int client) {
	votedToScramble[client] = false;
}

public void Handler_CastVote(Handle menu, MenuAction action, int param1, int param2) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	} else if(action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes) {
		PrintToChatAll("\x04[SM] \x01Team scramble vote failed: no votes were cast.");
	} else if(action == MenuAction_VoteEnd) {
		char item[64];
		float percent;
        float limit;
        int votes;
        int totalVotes;

		GetMenuVoteInfo(param2, votes, totalVotes);
		GetMenuItem(menu, param1, item, sizeof(item));

		percent = (float(votes)/float(totalVotes));
		limit = GetConVarFloat(cvarPercentage);

		if(FloatCompare(percent, limit) >= 0 && StrEqual(item, "yes")) {
			PrintToChatAll("\x04[SM] \x01The vote was successful. Teams will be scrambled at the start of the next round.");
			scrambleTeams = true;
		} else {
			PrintToChatAll("\x04[SM] \x01The vote failed.");
		}
	}
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {
	if(scrambleTeams) {
		float delay = GetConVarFloat(mp_bonusroundtime) - 7.0;
		if(delay < 0.0) {
			delay = 0.0;
		}

		scrambleTeams = false;
		CreateTimer(delay, Timer_Scramble);
	}
}

////////////////////////////////////////////////////////////////////////////////
//
// ACTIONS
//
////////////////////////////////////////////////////////////////////////////////

public Action Command_Say(int client, const char[] command, int argc) {
	char message[256];

	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);
	if(!StrEqual(message, "votescramble", false) && !StrEqual(message, "!votescramble", false)) {
		return Plugin_Continue;
	}
	if(!CheckCommandAccess(client, "votescramble", 0)) {
		ReplyToCommand(client, "[SM] %t.", "No Access");
		return Plugin_Continue;
	}
	if(votedToScramble[client]) {
		PrintToChatDelay(client, "\x04[SM] \x01You have already voted to scramble the teams.");
		return Plugin_Continue;
	}
	if(IsVoteInProgress()) {
		PrintToChatDelay(client, "\x04[SM] \x01Please wait for the current vote to end.");
		return Plugin_Continue;
	}
	if(scrambleTeams) {
		PrintToChatDelay(client, "\x04[SM] \x01A previous scramble vote has succeeded. Teams will be scrambled when the round ends.");
		return Plugin_Continue;
	}
	votedToScramble[client] = true;
	PrintToChatAllDelay(client, "{green}[SM] {teamcolor}%N {default}has voted to scramble the teams. [{lightgreen}%i{default}/{lightgreen}%i {default}votes required]", client, GetTotalVotes(), GetConVarInt(cvarVotesRequired));
	if(GetTotalVotes() >= GetConVarInt(cvarVotesRequired)) {
		InitiateVote();
	}
	return Plugin_Continue;
}

public Action Timer_PrintToChat(Handle timer, any pack) {
	char message[512];

    ResetPack(pack);
	int client = GetClientOfUserId(ReadPackCell(pack));
	if(client == 0) {
		CloseHandle(pack);
	}
	else {
        ReadPackString(pack, message, sizeof(message));
        CloseHandle(pack);
        PrintToChat(client, message);
    }

    return Plugin_Handled;

}

public Action Timer_PrintToChatAll(Handle timer, any pack) {
    char message[512];

    ResetPack(pack);
	int client = GetClientOfUserId(ReadPackCell(pack));
	if(client == 0) {
		CloseHandle(pack);
	}
	else {
        ReadPackString(pack, message, sizeof(message));
        CloseHandle(pack);
        CPrintToChatAllEx(client, message);
    }

    return Plugin_Handled;
}

public Action Timer_Scramble(Handle timer) {
	ServerCommand("mp_scrambleteams 2");
	PrintToChatAll("\x04[SM] \x01Scrambling the teams due to vote.");

    return Plugin_Handled;
}

////////////////////////////////////////////////////////////////////////////////
//
// LOCAL FUNCTIONS
//
////////////////////////////////////////////////////////////////////////////////

void PrintToChatDelay(int client, const char[] format, any ...) {
	char buffer[512];
    Handle pack = CreateDataPack();

	VFormat(buffer, sizeof(buffer), format, 3);
	WritePackCell(pack, GetClientUserId(client));
	WritePackString(pack, buffer);
	CreateTimer(0.0, Timer_PrintToChat, pack);
}

void PrintToChatAllDelay(int client, const char[] format, any ...) {
	char buffer[512];
	Handle pack = CreateDataPack();

    VFormat(buffer, sizeof(buffer), format, 3);
	WritePackCell(pack, GetClientUserId(client));
	WritePackString(pack, buffer);
	CreateTimer(0.0, Timer_PrintToChatAll, pack);
}

int GetTotalVotes() {
	int total = 0;
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && !IsFakeClient(i) && votedToScramble[i]) {
			total++;
		}
	}
	return total;
}

void InitiateVote() {
	for(int i = 1; i <= MaxClients; i++) {
		votedToScramble[i] = false;
	}
    Handle menu = CreateMenu(Handler_CastVote);
	SetMenuTitle(menu, "Scramble teams at the end of the round?");
	AddMenuItem(menu, "yes", "Yes");
	AddMenuItem(menu, "no", "No");
	SetMenuExitButton(menu, false);
	VoteMenuToAll(menu, 20);
}
