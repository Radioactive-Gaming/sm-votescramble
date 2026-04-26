# SourceMod: TF2 Better Vote Scramble

A fork of [Dr. McKay's plugin](https://github.com/DoctorMcKay/sourcemod-plugins/commits/master/scripting/votescramble.sp).

A plugin that scrambles teams after the end of the current round. The plugin facilitates a server player vote once invoked. Upon a successful majority vote, the plugin invokes the stock scrambler after the humiliation round is completed.

## Commands

* `votescramble`:
  * **Description:** Votes for a team scramble.
  * **Parameters:** None.
 
## Configuration

### AutoExec

The main configuration file is located in `tf/cfg/sourcemod/plugin.votescramble.cfg`.

```
// Percentage required to initiate a team scramble
// -
// Default: "0.6"
sm_votescramble_percentage "0.6"

// Votes required to initiate a vote
// -
// Default: "3"
sm_votescramble_votes_required "3"
```

## Installation

Follow the standard SourceMod process for installation by adding:

- The compiled plugin `votescramble.smx` to `tf/addons/sourcemod/plugins/`.
- Reload all plugins or restart the server.

## Testing

The following testing scenarios are recommended when making code changes:

* Standard player:
	* Execute the command to initiate a voting session.
	* Execute the command after a voting session was initiated.
	* Execute the command a second time.
	* Execute the command after a successful scramble server vote.
