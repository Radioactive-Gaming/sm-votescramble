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
#define     PLUGIN_VERSION      "1.5.0"

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

    cvarPercentage = CreateConVar("sm_votescramble_percentage", "0.6", "Percentage required to initiate a team scramble");
    cvarVotesRequired = CreateConVar("sm_votescramble_votes_required", "3", "Votes required to initiate a vote");

    // Create command listeners for global and team chats to catch the 'votescramble' command.
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");

    // Create hooks to execute a team scramble on round end.
    HookEvent("teamplay_round_win", Event_RoundEnd);
    HookEvent("teamplay_round_stalemate", Event_RoundEnd);
    HookEvent("teamplay_win_panel", Event_RoundEnd);

    // Import the server's humiliation round time to delay a scramble.
    mp_bonusroundtime = FindConVar("mp_bonusroundtime");

    // SourceMod core phrases used for responding to vote results.
    LoadTranslations("core.phrases");

    // Execute the configuration
    AutoExecConfig(true);
	LogMessage("[INFO] Plugin loaded.");

}

public void OnClientConnected(int client) {

    /**
     * Ensure the client's voting status is wiped on connection.
    */

    votedToScramble[client] = false;

}

public void Handler_CastVote(Handle menu, MenuAction action, int param1, int param2) {

    /**
     * Creates a MenuHandler for the server vote.
    */

    // Process the MenuAction.
    switch (action)
    {

        case MenuAction_End:
        {

            // Close after the end of the vote.
            CloseHandle(menu);

        }

        case MenuAction_VoteCancel:
        {

            // Notify players if nobody voted.
            if (param1 == VoteCancel_NoVotes) {

                PrintToChatAll("\x04[SM] \x01Team scramble vote failed: no votes were cast.");

            }

        }

        case MenuAction_VoteEnd:
        {

            char item[64];
            float percent;
            float limit;
            int votes;
            int totalVotes;

            // Retrieve voting data.
            GetMenuVoteInfo(param2, votes, totalVotes);
            GetMenuItem(menu, param1, item, sizeof(item));

            // Compare the number of votes to the voting threshold.
            percent = (float(votes)/float(totalVotes));
            limit = GetConVarFloat(cvarPercentage);

            if (FloatCompare(percent, limit) >= 0 && StrEqual(item, "yes")) {

                PrintToChatAll("\x04[SM] \x01The team scramble vote passed. Teams will be scrambled at the start of the next round.");
                scrambleTeams = true;

            } else {

                PrintToChatAll("\x04[SM] \x01The team scramble vote failed. Teams will not be scrambled.");

            }

        }

    }

}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {

    if (scrambleTeams) {

        float delay = GetConVarFloat(mp_bonusroundtime) - 7.0;

        if (delay < 0.0) {

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

    /**
     * A listener for the 'votescramble' command.
     *
     * This loads on plugin start and continues to listen until the plugin is
     * terminated.
    */

    char message[MAX_MESSAGE_LENGTH];
    bool validCommand;

    // Sanitize the command input.
    GetCmdArgString(message, sizeof(message));
    StripQuotes(message);
    TrimString(message);
    ReplaceString(message, sizeof(message), "!", "", false);
    validCommand = StrEqual(message, "votescramble", false);

    if (!validCommand) {

        return Plugin_Continue;

    } else {

        bool hasAccess;

        // Check if the client is permitted to execute the votescramble command.
        hasAccess = CheckCommandAccess(client, "votescramble", 0);

        if (hasAccess) {

            // Return if a scramble decision has already been made.
            if (scrambleTeams) {

                PrintToChatDelay(client, "\x04[SM] \x01 A previous scramble vote has succeeded. Teams will be scrambled when the round ends.");

                return Plugin_Continue;

            } else {

                // Check if a client has already issued the 'votescramble' command in the current vote cycle.
                if (votedToScramble[client]) {

                    PrintToChatDelay(client, "\x04[SM] \x01You have already voted to scramble the teams during this round.");

                    return Plugin_Continue;

                } else {

                    bool voteInProgress;

                    // Check if a vote is currently in progress on the server.
                    voteInProgress = IsVoteInProgress();


                    if (voteInProgress) {

                        PrintToChatDelay(client, "\x04[SM] \x01 Vote submitted. Please wait for the current vote to end.");

                    } else {

                        int totalVotes = GetTotalVotes();
                        int votesRequired = GetConVarInt(cvarVotesRequired);

                        PrintToChatAllDelay(client, "{green}[SM] {teamcolor}%N {default}has voted to scramble the teams. [{lightgreen}%i{default}/{lightgreen}%i {default}votes required]", client, totalVotes, votesRequired);

                        // Call the server vote.
                        if (totalVotes >= votesRequired) {

                            InitiateVote();

                        }

                    }

                    votedToScramble[client] = true;

                    return Plugin_Continue;

                }

            }

        } else {

            ReplyToCommand(client, "[SM] %t.", "You do not have access to the 'votescramble' command.");

            return Plugin_Continue;

        }

    }

}

public Action Timer_PrintToChat(Handle timer, any pack) {

    char message[512];

    ResetPack(pack);
    int client = GetClientOfUserId(ReadPackCell(pack));

    if (client == 0) {

        CloseHandle(pack);

    } else {

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

    if (client == 0) {

        CloseHandle(pack);

    } else {

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

    for (int i = 1; i <= MaxClients; i++) {

        if (IsClientInGame(i) && !IsFakeClient(i) && votedToScramble[i]) {

            total++;

        }

    }

    return total;

}

void InitiateVote() {

    /**
     * Creates a voting menu for a team scramble.
     *
     * All voting status is cleared for all players prior to the vote being displayed.
     *
    */

    for (int i = 1; i <= MaxClients; i++) {

        votedToScramble[i] = false;

    }

    Handle menu = CreateMenu(Handler_CastVote);
    SetMenuTitle(menu, "Scramble teams at the end of the round?");
    AddMenuItem(menu, "yes", "Yes");
    AddMenuItem(menu, "no", "No");
    SetMenuExitButton(menu, false);
    VoteMenuToAll(menu, 20);

}
