/*
Copyright (C) 2009-2010 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

// Capture the flag Tactics
// by kiki & jal :>

const float CTF_AUTORETURN_TIME = 30.0f;
const int CTF_BONUS_RECOVERY = 2;
const int CTF_BONUS_STEAL = 1;
const int CTF_BONUS_CAPTURE = 10;
const int CTF_BONUS_CARRIER_KILL = 2;
const int CTF_BONUS_CARRIER_PROTECT = 2;
const int CTF_BONUS_FLAG_DEFENSE = 1;

const float CTF_FLAG_RECOVERY_BONUS_DISTANCE = 512.0f;
const float CTF_CARRIER_KILL_BONUS_DISTANCE = 512.0f;
const float CTF_OBJECT_DEFENSE_BONUS_DISTANCE = 512.0f;

int CTFT_RESPAWN_TIME = 15000;
int CTFT_TURRET_AP_COST = 50;
int CTFT_TURRET_STRONG_AP_COST = 125;
uint CTFT_ENGINEER_BUILD_COOLDOWN_TIME = 15000;
float CTFT_SNIPER_INVISIBILITY_MINLOAD = 20;
float CTFT_SNIPER_INVISIBILITY_MAXLOAD = 100;
uint CTFT_INVISIBILITY_COOLDOWN = 1000;
int CTFT_BATTLESUIT_AP_COST = 50;
int CTFT_BATTLESUIT_RUNNER_TIME = 3; 	// in seconds
int CTFT_BATTLESUIT_GRUNT_TIME = 8;		// in seconds
int CTFT_MEDIC_COOLDOWN = 1200;
int CTFT_GRUNT_COOLDOWN = 1500;
int CTFT_SUPPORT_COOLDOWN = 1200;
int CTFT_SHELL_COOLDOWN = 10000;
int CTFT_BOMB_COOLDOWN = 20000;
float CTFT_RESPAWN_RADIUS = 384.0f;
float CTFT_BUILD_RADIUS = 160.0f;
float CTFT_BUILD_DESTROY_RADIUS = 96.0f;
float CTFT_MEDIC_INFLUENCE_RADIUS = 192.0f;
float CTFT_SUPPORT_INFLUENCE_RADIUS = 192.0f;

// precache images and sounds

int prcShockIcon;
int prcShellIcon;
int prcAlphaFlagIcon;
int prcBetaFlagIcon;
int prcFlagIcon;
int prcFlagIconStolen;
int prcFlagIconLost;
int prcFlagIconCarrier;
int prcDropFlagIcon;

int prcFlagIndicatorDecal;

int prcAnnouncerRecovery01;
int prcAnnouncerRecovery02;
int prcAnnouncerRecoveryTeam;
int prcAnnouncerRecoveryEnemy;
int prcAnnouncerFlagTaken;
int prcAnnouncerFlagTakenTeam01;
int prcAnnouncerFlagTakenTeam02;
int prcAnnouncerFlagTakenEnemy01;
int prcAnnouncerFlagTakenEnemy02;
int prcAnnouncerFlagScore01;
int prcAnnouncerFlagScore02;
int prcAnnouncerFlagScoreTeam01;
int prcAnnouncerFlagScoreTeam02;
int prcAnnouncerFlagScoreEnemy01;
int prcAnnouncerFlagScoreEnemy02;

bool firstSpawn = false;

Cvar ctfAllowPowerupDrop( "ctf_powerupDrop", "0", CVAR_ARCHIVE );

const String SELECT_CLASS_COMMAND = 
	"mecu \"Select class\"" 
	+ " Grunt \"class grunt\" Medic \"class medic\" Runner \"class runner\"" 
	+ " Engineer \"class engineer\" Support \"class support\" Sniper \"class sniper\"";

///*****************************************************************
/// LOCAL FUNCTIONS
///*****************************************************************

// a player has just died. The script is warned about it so it can account scores
void CTF_playerKilled( Entity @target, Entity @attacker, Entity @inflictor )
{
    if ( @target.client == null )
        return;

    cFlagBase @flagBase = @CTF_getBaseForCarrier( target );

    // reset flag if carrying one
    if ( @flagBase != null )
    {
        if ( @attacker != null )
            flagBase.carrierKilled( attacker, target );

        CTF_PlayerDropFlag( target, false );
    }
    else if ( @attacker != null )
    {
        @flagBase = @CTF_getBaseForTeam( attacker.team );

        // if not flag carrier, check whether victim was offending our flag base or friendly flag carrier
        if ( @flagBase != null )
            flagBase.offenderKilled( attacker, target );		
    }

    if ( match.getState() != MATCH_STATE_PLAYTIME )
        return;

    // check for generic awards for the frag
    if( @attacker != null && attacker.team != target.team )
		award_playerKilled( @target, @attacker, @inflictor );	
}

void CTF_SetVoicecommQuickMenu( Client @client, int playerClass )
{
	// TODO: Add actions	
	// TODO: Add more useful messages
	String menuStr = 
		'"Area secured" "vsay_team areasecured" ' + 
		'"Go to quad" "vsay_team gotoquad" ' + 
		'"Go to powerup" "vsay_team gotopowerup" ' +		
		'"Need offense" "vsay_team needoffense" ' + 
		'"Need defense" "vsay_team needdefense" ' + 
		'"On offense" "vsay_team onoffense" ' + 
		'"On defense" "vsay_team ondefense" ';

	GENERIC_SetQuickMenu( @client, menuStr );
}

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "drop" )
    {
        String token;

        for ( int i = 0; i < argc; i++ )
        {
            token = argsString.getToken( i );
            if ( token.len() == 0 )
                break;

            if ( token == "flag" )
            {
                if ( ( client.getEnt().effects & EF_CARRIER ) == 0 )
                    client.printMessage( "You don't have the flag\n" );
                else
                    CTF_PlayerDropFlag( client.getEnt(), true );
            }
            else
            {
                GENERIC_CommandDropItem( client, token );
            }
        }

        return true;
    }
    else if( cmdString == "cvarinfo" )
    {
    	GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
    	return true;
    }
    else if ( cmdString == "gametypemenu" )
    {
        if ( client.getEnt().team < TEAM_PLAYERS )
        {
            G_PrintMsg( client.getEnt(), "You must join a team before selecting a class\n" );
            return true;
        }

        client.execGameCommand( SELECT_CLASS_COMMAND );
        return true;
    }
    else if ( cmdString == "class" )
    {
        if ( @client != null )
            GetPlayer( client ).setPlayerClassCommand( argsString );
        return true;
    }
	else if ( cmdString == "build" )
	{
		CTFT_BuildCommand( client, argsString, argc );
	}
	else if ( cmdString == "destroy" )
	{
		CTFT_DestroyCommand( client, argsString, argc );
	}
    // example of registered command
    else if ( cmdString == "gametype" )
    {
        String response = "";
        Cvar fs_game( "fs_game", "", 0 );
        String manifest = gametype.manifest;

        response += "\n";
        response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
        response += "----------------\n";
        response += "Version: " + gametype.version + "\n";
        response += "Author: " + gametype.author + "\n";
        response += "Mod: " + fs_game.string + (!manifest.empty() ? " (manifest: " + manifest + ")" : "") + "\n";
        response += "----------------\n";

        G_PrintMsg( client.getEnt(), response );
        return true;
    }
    else if ( cmdString == "callvotevalidate" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "ctf_powerup_drop" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !ctfAllowPowerupDrop.boolean )
            {
                client.printMessage( "Powerup drop is already disallowed\n" );
                return false;
            }

            if ( voteArg == "1" && ctfAllowPowerupDrop.boolean )
            {
                client.printMessage( "Powerup drop is already allowed\n" );
                return false;
            }

            return true;
        }

        client.printMessage( "Unknown callvote " + votename + "\n" );
        return false;
    }
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "ctf_powerup_drop" )
        {
            if ( argsString.getToken( 1 ).toInt() > 0 )
                ctfAllowPowerupDrop.set( 1 );
            else
                ctfAllowPowerupDrop.set( 0 );
        }

        return true;
    }

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity @ent )
{
    Entity @goal;
    Bot @bot;
    float baseFactor;
    float alphaDist, betaDist, homeDist;

    @bot = @ent.client.getBot();
    if ( @bot == null )
        return false;

    float offensiveStatus = GENERIC_OffensiveStatus( ent );

    // play defensive when being a flag carrier
    if ( ( ent.effects & EF_CARRIER ) != 0 )
        offensiveStatus = 0.33f;

    cFlagBase @alphaBase = @CTF_getBaseForTeam( TEAM_ALPHA );
    cFlagBase @betaBase = @CTF_getBaseForTeam( TEAM_BETA );

    // for carriers, find the raw distance to base
    if ( ( ( ent.effects & EF_CARRIER ) != 0 ) && @alphaBase != null && @betaBase != null )
    {
        if ( ent.team == TEAM_ALPHA )
            homeDist = ent.origin.distance( alphaBase.owner.origin );
        else
            homeDist = ent.origin.distance( betaBase.owner.origin );
    }

    // loop all the goal entities
    for ( int i = AI::GetNextGoal( AI::GetRootGoal() ); i != AI::GetRootGoal(); i = AI::GetNextGoal( i ) )
    {
        @goal = @AI::GetGoalEntity( i );

        // by now, always full-ignore not solid entities
        if ( goal.solid == SOLID_NOT )
        {
            bot.setGoalWeight( i, 0 );
            continue;
        }

        if ( @goal.client != null )
        {
            bot.setGoalWeight( i, GENERIC_PlayerWeight( ent, goal ) * offensiveStatus );
            continue;
        }

        // when being a flag carrier have a tendency to stay around your own base
        baseFactor = 1.0f;

        if ( ( ( ent.effects & EF_CARRIER ) != 0 ) && @alphaBase != null && @betaBase != null )
        {
            alphaDist = goal.origin.distance( alphaBase.owner.origin );
            betaDist = goal.origin.distance( betaBase.owner.origin );

            if ( ( ent.team == TEAM_ALPHA ) && ( alphaDist + 64 < betaDist || alphaDist < homeDist + 128 ) )
                baseFactor = 5.0f;
            else if ( ( ent.team == TEAM_BETA ) && ( betaDist + 64 < alphaDist || betaDist < homeDist + 128 ) )
                baseFactor = 5.0f;
            else
                baseFactor = 0.5f;
        }

        if ( @goal.item != null )
        {
            // all the following entities are items
            if ( ( goal.item.type & IT_WEAPON ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_WeaponWeight( ent, goal ) * baseFactor );
            }
            else if ( ( goal.item.type & IT_AMMO ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_AmmoWeight( ent, goal ) * baseFactor );
            }
            else if ( ( goal.item.type & IT_ARMOR ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_ArmorWeight( ent, goal ) * baseFactor );
            }
            else if ( ( goal.item.type & IT_HEALTH ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_HealthWeight( ent, goal ) * baseFactor );
            }
            else if ( ( goal.item.type & IT_POWERUP ) != 0 )
            {
                bot.setGoalWeight( i, bot.getItemWeight( goal.item ) * offensiveStatus * baseFactor );
            }

            continue;
        }

        // the entities spawned from scripts never have linked items,
        // so the flags are weighted here

        cFlagBase @flagBase = @CTF_getBaseForOwner( goal );

        if ( @flagBase != null && @flagBase.owner != null )
        {
            // enemy or team?

            if ( flagBase.owner.team != ent.team ) // enemy base
            {
                if ( @flagBase.owner == @flagBase.carrier ) // enemy flag is at base
                {
                    bot.setGoalWeight( i, 12.0f * offensiveStatus );
                }
                else
                {
                    bot.setGoalWeight( i, 0 );
                }
            }
            else // team
            {
                // flag is at base and this bot has the enemy flag
                if ( ( ent.effects & EF_CARRIER ) != 0 && ( goal.effects & EF_CARRIER ) != 0 )
                {
                    bot.setGoalWeight( i, 3.5f * baseFactor );
                }
                else
                {
                    bot.setGoalWeight( i, 0 );
                }
            }

            continue;
        }

        if ( goal.classname == "ctf_flag" )
        {
            // ** please, note, no item has a weight above 1.0 **
            // ** these are really huge weights **

            // it's my flag, dropped somewhere
            if ( goal.team == ent.team )
            {
                bot.setGoalWeight( i, 5.0f * baseFactor );
            }
            // it's enemy flag, dropped somewhere
            else if ( goal.team != ent.team )
            {
                bot.setGoalWeight( i, 3.5f * offensiveStatus * baseFactor );
            }

            continue;
        }

        // we don't know what entity is this, so ignore it
        bot.setGoalWeight( i, 0 );
    }

    return true; // handled by the script
}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    bool spawnFromReviver = true;

    if ( @self.client == null )
        return null;
	
    if ( firstSpawn )
    {
		Entity @spot;
		
        if ( self.team == TEAM_ALPHA )
            @spot = @GENERIC_SelectBestRandomSpawnPoint( self, "team_CTF_alphaplayer" );
        else
			@spot = @GENERIC_SelectBestRandomSpawnPoint( self, "team_CTF_betaplayer" );
			
		if( @spot != null )
			return @spot;
    }

    if ( spawnFromReviver )
    {
        if ( @self.client != null )
        {
            cPlayer @player = GetPlayer( self.client );

            // see if this guy has a reviver
            if ( @player.reviver != null )
            {
                if ( player.reviver.revived == true )
                    return player.reviver.ent;
            }
        }
    }

    if ( self.team == TEAM_ALPHA )
        return GENERIC_SelectBestRandomSpawnPoint( self, "team_CTF_alphaspawn" );

    return GENERIC_SelectBestRandomSpawnPoint( self, "team_CTF_betaspawn" );
}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
	cPlayer @player;
    int i, t, classIcon;

    for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );

        // &t = team tab, team tag, team score, team ping
        entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";
        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;

        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @ent = @team.ent( i );

            classIcon = 0;
            if ( @ent.client != null && ent.client.state() >= CS_SPAWNED )
                classIcon = GetPlayer( ent.client ).playerClass.iconIndex;

            int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

            //G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %l 48 %p l1 %r l1" );
            //G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Ping C R" );
 
			@player = GetPlayer( ent.client );
			double rawExtraScore = 0.0f;
			rawExtraScore += ent.client.stats.totalDamageGiven * 0.01;
			rawExtraScore += player.medicInfluenceScore;
			rawExtraScore += player.supportInfluenceScore;
			int shownScore = ent.client.stats.score + int( rawExtraScore );

            // "Name Score Ping C R"
            entry = "&p " + playerID + " "
                    + ent.client.clanName + " "
                    + shownScore + " "
                    + ent.client.ping + " "
                    + classIcon + " "
                    + ( ent.client.isReady() ? "1" : "0" ) + " ";

            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;
        }
    }

    return scoreboardMessage;
}

// Some game actions get reported to the script as score events.
// Warning: client can be null
void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {
        int arg1 = args.getToken( 0 ).toInt();
        float arg2 = args.getToken( 1 ).toFloat();
        int arg3 = args.getToken( 2 ).toInt();

        Entity @target = @G_GetEntity( arg1 );

        if ( @target != null )
        {
			if ( @target.client != null )
			{
            	/* will not work without latest bins*/
            	GetPlayer( target.client ).tookDamage( arg3, arg2 );
			}
			// Hack: IG should not inflict more than 125 damage units on turrets
			else if ( arg2 == 200.0f )
			{
				// We did a cheap numeric test first to cut off this string comparison
				if ( target.classname == "turret_body" )
					target.health += 75.0f;
			}
        }
    }
    else if ( score_event == "kill" )
    {
        Entity @attacker = null;
        if ( @client != null )
            @attacker = @client.getEnt();

        int arg1 = args.getToken( 0 ).toInt();
        int arg2 = args.getToken( 1 ).toInt();
        Entity @ent = G_GetEntity( arg1 );

        // Important - if turret ends up here without this, crash =P
        if ( @ent == null || @ent.client == null )
            return;

        // target, attacker, inflictor
        CTF_playerKilled( ent, attacker, G_GetEntity( arg2 ) );

        // Class-specific death stuff
        cPlayer @targetPlayer = @GetPlayer( ent.client );
        targetPlayer.respawnTime = levelTime + CTFT_RESPAWN_TIME;

        // Spawn respawn indicator
        if ( match.getState() == MATCH_STATE_PLAYTIME )
            targetPlayer.spawnReviver();

        if ( targetPlayer.playerClass.tag == PLAYERCLASS_MEDIC )
            CTFT_DeathDrop( ent.client, "5 Health" );

        if ( targetPlayer.playerClass.tag == PLAYERCLASS_GRUNT )
        {
            CTFT_DeathDrop( ent.client, "Armor Shard" );

            // Explode all cluster bombs belonging to this grunt when dying
            cBomb @bomb = null;
            Entity @tmp = null;
            for ( int i = 0; i < MAX_BOMBS; i++ )
            {
                if ( gtBombs[i].inuse == true )
                {
                    @bomb = @gtBombs[i];

                    if ( @targetPlayer == @bomb.player )
                        bomb.die(tmp, tmp);
                }
            }
        }
    }
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
	Client @client = @ent.client;

    if ( @client == null )
        return;

    cPlayer @player = @GetPlayer( client );

    if ( old_team != new_team )
    {
        player.removeReviver();

        // show the class selection menu
        if ( old_team == TEAM_SPECTATOR )
        {
            if ( @client.getBot() != null )
            {
                player.setPlayerClass( rand() % PLAYERCLASS_TOTAL );
            }
            else
                client.execGameCommand( SELECT_CLASS_COMMAND );
        }

        // Set newly joined players to respawn queue
        if ( new_team == TEAM_ALPHA || new_team == TEAM_BETA )
            player.respawnTime = levelTime + CTFT_RESPAWN_TIME;
    }

    if ( ent.isGhosting() )
    {
		ent.svflags &= ~SVF_FORCETEAM;
	
        if ( match.getState() == MATCH_STATE_PLAYTIME )
        {
            Entity @chaseTarget = @G_GetEntity( client.chaseTarget );
            if ( @chaseTarget != null && @chaseTarget.client != null )
                client.chaseCam( chaseTarget.client.name, true );
            else
                client.chaseCam( null, true );
        }
        return;
    }

    // Reset health and armor before setting abilities.
    ent.health = 100;
    ent.client.armor = player.playerClass.armor;

    // Assign movement abilities for classes

    // fixme: move methods to player
    player.refreshModel();
    player.refreshMovement();

	client.inventorySetCount( WEAP_GUNBLADE, 1 );

    // Runner
    if ( player.playerClass.tag == PLAYERCLASS_RUNNER )
    {
        // Weapons
        client.inventoryGiveItem( WEAP_ROCKETLAUNCHER );
        client.inventoryGiveItem( WEAP_ELECTROBOLT );
        // Enable gunblade blast
    	client.inventorySetCount( AMMO_GUNBLADE, 1 );

		// Ammo (set an exact amount we need)
		client.inventorySetCount( AMMO_ROCKETS, 7 );
		client.inventorySetCount( AMMO_BOLTS, 7 );

        // Armor
        client.inventoryGiveItem( ARMOR_GA );

        G_PrintMsg( ent , "You're spawned as ^3RUNNER^7.\n");
		// TODO: Provide extended class description       	
		// TODO: Print actions to the client		
    }
    // Medic
    else if ( player.playerClass.tag == PLAYERCLASS_MEDIC )
    {
        // Weapons
        client.inventoryGiveItem( WEAP_PLASMAGUN );
        client.inventoryGiveItem( WEAP_MACHINEGUN );
        // Enable gunblade blast
    	client.inventorySetCount( AMMO_GUNBLADE, 1 );

        // Ammo (set an exact amount we need)
        client.inventorySetCount( AMMO_PLASMA, 150 );
		client.inventorySetCount( AMMO_BULLETS, 150 );

        G_PrintMsg( ent , "You're spawned as ^2MEDIC^7.\n");
		// TODO: Provide extended class description
        // TODO: Print actions to the client
    }
    // Grunt
    else if ( player.playerClass.tag == PLAYERCLASS_GRUNT )
    {
        // Weapons
        client.inventoryGiveItem( WEAP_ROCKETLAUNCHER );
        client.inventoryGiveItem( WEAP_LASERGUN );
        client.inventoryGiveItem( WEAP_GRENADELAUNCHER );
        
        // Ammo
        client.inventoryGiveItem( AMMO_ROCKETS );
        client.inventoryGiveItem( AMMO_LASERS );
		client.inventorySetCount( AMMO_GRENADES, 10 );
		
        G_PrintMsg( ent , "You're spawned as ^1GRUNT^7.\n");
        // TODO: Provide extended class description
		// TODO: Print actions to the client
    }
    // Engineer
    else if ( player.playerClass.tag == PLAYERCLASS_ENGINEER )
    {
        // Weapons
        client.inventoryGiveItem( WEAP_ROCKETLAUNCHER );
        client.inventoryGiveItem( WEAP_PLASMAGUN );
        client.inventoryGiveItem( WEAP_RIOTGUN );

		// Ammo
		client.inventorySetCount( AMMO_ROCKETS, 10 );
		client.inventoryGiveItem( AMMO_PLASMA );
		client.inventoryGiveItem( AMMO_SHELLS );

        G_PrintMsg( ent , "You're spawned as ^4ENGINEER^7. This is a defencive class with an ability to build entities\n");
		G_PrintMsg( ent , "Command `^6build turret^7`: Spawn a turret\n");
		G_PrintMsg( ent , "Command `^6destroy turret^7`: Destroy a turret\n");
    }
	else if ( player.playerClass.tag == PLAYERCLASS_SUPPORT )
	{
		// Weapons
		client.inventoryGiveItem( WEAP_LASERGUN );
		client.inventoryGiveItem( WEAP_RIOTGUN );
		 // Enable gunblade blast
    	client.inventorySetCount( AMMO_GUNBLADE, 1 );

		G_PrintMsg( ent, "You're spawned as ^8SUPPORT^7.\n");
		// TODO: Provide extended class description
		// TODO: Print actions to the client
	}
	else if ( player.playerClass.tag == PLAYERCLASS_SNIPER )
	{
		// Weapons
		client.inventoryGiveItem( WEAP_INSTAGUN );		
		client.inventoryGiveItem( WEAP_ELECTROBOLT );
		client.inventoryGiveItem( WEAP_MACHINEGUN );
		// Remove GB
		client.inventorySetCount( WEAP_GUNBLADE, 0 );

		// Ammo (set an exact amount we need)
		client.inventorySetCount( AMMO_INSTAS, 3 );
		client.inventorySetCount( AMMO_BOLTS, 10 );
		client.inventorySetCount( AMMO_BULLETS, 100 );
		
		G_PrintMsg( ent, "You're spawned as ^5SNIPER^7.\n");
		// TODO: Provide extended class description
		// TODO: Print actions to the client
	}


    // select rocket launcher if available
    client.selectWeapon( -1 ); // auto-select best weapon in the inventory

	ent.svflags |= SVF_FORCETEAM;

	CTF_SetVoicecommQuickMenu( @client, player.playerClass.tag );
	
    // add a teleportation effect
    ent.respawnEffect();

    if ( @player.reviver != null && player.reviver.revived )
    {
        // when revived do not clear all timers
        player.shellCooldownTime = 0;
        player.respawnTime = 0;
        player.invisibilityEnabled = false;
        player.invisibilityLoad = 0;
        player.invisibilityCooldownTime = 0;
        player.hudMessageTimeout = 0;

        player.invisibilityWasUsingWeapon = -1;
    }
    else
        player.resetTimers();

    player.removeReviver();
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
    {
        if ( !match.checkExtendPlayTime() )
            match.launchState( match.getState() + 1 );
    }

    GENERIC_Think();
    CTFT_RespawnQueuedPlayers();

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
    {
        return;
    }

    for ( cFlagBase @flagBase = @fbHead; @flagBase != null; @flagBase = @flagBase.next )
    {
        flagBase.thinkRules();
    }

	// We have to split the naiive single loop to avoid overwriting influence of other players. 

	for ( int i = 0; i < maxClients; i++ )
	{
		GetPlayer( i ).clearInfluence();
	}

	for ( int i = 0; i < maxClients; i++ )
    {
        // update model and movement
        cPlayer @player = @GetPlayer( i );
        if ( player.client.state() < CS_SPAWNED )
            continue;

        // fixme : move methods to player
        player.refreshChasecam();
        player.refreshModel();
        player.refreshMovement();
		player.refreshInfluenceEmission();
    }
	
    for ( int i = 0; i < maxClients; i++ )
    {
        
        cPlayer @player = @GetPlayer( i );
        if ( player.client.state() < CS_SPAWNED )
            continue;

        // fixme : move methods to player
		player.refreshInfluenceAbsorption();
        player.refreshRegeneration();
        player.watchShell();
        player.updateHUDstats();
    }
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP
            && incomingMatchState < MATCH_STATE_POSTMATCH )
        match.startAutorecord();

    if ( match.getState() == MATCH_STATE_POSTMATCH )
        match.stopAutorecord();

    // check maxHealth rule
    for ( int i = 0; i < maxClients; i++ )
    {
        Entity @ent = @G_GetClient( i ).getEnt();
        if ( ent.client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            if ( ent.health > ent.maxHealth ) {
                ent.health -= ( frameTime * 0.001f );
				// fix possible rounding errors
				if( ent.health < ent.maxHealth ) {
					ent.health = ent.maxHealth;
				}
			}
        }
    }

    return true;
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{
    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        CTFT_SetUpWarmup();
		SpawnIndicators::Create( "team_CTF_alphaplayer", TEAM_ALPHA );
		SpawnIndicators::Create( "team_CTF_alphaspawn", TEAM_ALPHA );
		SpawnIndicators::Create( "team_CTF_betaplayer", TEAM_BETA );
		SpawnIndicators::Create( "team_CTF_betaspawn", TEAM_BETA );		
        break;

    case MATCH_STATE_COUNTDOWN:
        GENERIC_SetUpCountdown();
		SpawnIndicators::Delete();
        break;

    case MATCH_STATE_PLAYTIME:
        GENERIC_SetUpMatch();
        CTFT_SetUpMatch();
        break;

    case MATCH_STATE_POSTMATCH:
        GENERIC_SetUpEndMatch();
        CTFT_RemoveTurrets();
        CTFT_RemoveBombs();
        CTFT_RemoveRevivers();
        break;

    default:
        break;
    }
}

void CTFT_SetUpWarmup()
{
    GENERIC_SetUpWarmup();

    // set spawnsystem type to instant while players join
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );
}

void CTFT_SetUpMatch()
{
    // Reset flags
    CTF_ResetFlags();
    CTFT_ResetRespawnQueue();
    CTFT_RemoveTurrets();
    CTFT_RemoveBombs();
    CTFT_RemoveItemsByName("25 Health");
    CTFT_RemoveItemsByName("Yellow Armor");
    CTFT_RemoveItemsByName("5 Health");
    CTFT_RemoveItemsByName("Armor Shard");

    // set spawnsystem type to not respawn the players when they die
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_HOLD, 0, 0, false );

    // clear scores

    Entity @ent;
    Team @team;
	cPlayer @player;
    int i;

    for ( i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
    {
        @team = @G_GetTeam( i );
        team.stats.clear();

        // respawn all clients inside the playing teams
        for ( int j = 0; @team.ent( j ) != null; j++ )
        {
            @ent = @team.ent( j );
            ent.client.stats.clear(); // clear player scores & stats
			@player = GetPlayer( ent.client );
			if ( @player != null )
			{
				player.medicInfluenceScore = 0.0f;
				player.supportInfluenceScore = 0.0f;
			}
        }
    }
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
}

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{

}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{
    gametype.title = "WTF";
    gametype.version = "0.01";
    gametype.author = "Warsow Development Team";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"wctf1 wctf3 wctf4 wctf5 wctf6\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"1\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"0\"\n"
                 + "set g_timelimit \"20\"\n"
                 + "set g_warmup_timelimit \"1\"\n"
                 + "set g_match_extendedtime \"5\"\n"
                 + "set g_allow_falldamage \"1\"\n"
                 + "set g_allow_selfdamage \"1\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"1\"\n"
                 + "set g_teams_maxplayers \"5\"\n"
                 + "set g_teams_allow_uneven \"0\"\n"
                 + "set g_countdown_time \"5\"\n"
                 + "set g_maxtimeouts \"3\" // -1 = unlimited\n"
                 + "set ctf_powerupDrop \"0\"\n"
                 + "\necho \"" + gametype.name + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

    gametype.spawnableItemsMask = 0;
    if ( gametype.isInstagib )
        gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);

    gametype.respawnableItemsMask = gametype.spawnableItemsMask ;
    gametype.dropableItemsMask = ( gametype.spawnableItemsMask | IT_HEALTH | IT_ARMOR ) ;
    gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );


    gametype.isTeamBased = true;
    gametype.isRace = false;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 20;
    gametype.armorRespawn = 25;
    gametype.weaponRespawn = 5;
    gametype.healthRespawn = 25;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 20;
    gametype.ultrahealthRespawn = 40;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = false;
    gametype.canForceModels = false;
    gametype.canShowMinimap = true;
    gametype.teamOnlyMinimap = true;
    gametype.customDeadBodyCam = true; // needs new bins!

	gametype.mmCompatible = true;
	
    gametype.spawnpointRadius = 256;

    if ( gametype.isInstagib )
        gametype.spawnpointRadius *= 2;

    // set spawnsystem type
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %l 48 %p l1 %r l1" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Ping C R" );

    // precache images and sounds
    prcShockIcon = G_ImageIndex( "gfx/hud/icons/powerup/quad" );
    prcShellIcon = G_ImageIndex( "gfx/hud/icons/powerup/warshell" );
    prcAlphaFlagIcon = G_ImageIndex( "gfx/hud/icons/flags/iconflag_alpha" );
    prcBetaFlagIcon = G_ImageIndex( "gfx/hud/icons/flags/iconflag_beta" );
    prcFlagIcon = G_ImageIndex( "gfx/hud/icons/flags/iconflag" );
    prcFlagIconStolen = G_ImageIndex( "gfx/hud/icons/flags/iconflag_stolen" );
    prcFlagIconLost = G_ImageIndex( "gfx/hud/icons/flags/iconflag_lost" );
    prcFlagIconCarrier = G_ImageIndex( "gfx/hud/icons/flags/iconflag_carrier" );
    prcDropFlagIcon = G_ImageIndex( "gfx/hud/icons/drop/flag" );

    prcFlagIndicatorDecal = G_ImageIndex( "gfx/indicators/radar_decal" );

    prcAnnouncerRecovery01 = G_SoundIndex( "sounds/announcer/ctf/recovery01" );
    prcAnnouncerRecovery02 = G_SoundIndex( "sounds/announcer/ctf/recovery02" );
    prcAnnouncerRecoveryTeam = G_SoundIndex( "sounds/announcer/ctf/recovery_team" );
    prcAnnouncerRecoveryEnemy = G_SoundIndex( "sounds/announcer/ctf/recovery_enemy" );
    prcAnnouncerFlagTaken = G_SoundIndex( "sounds/announcer/ctf/flag_taken" );
    prcAnnouncerFlagTakenTeam01 = G_SoundIndex( "sounds/announcer/ctf/flag_taken_team01" );
    prcAnnouncerFlagTakenTeam02 = G_SoundIndex( "sounds/announcer/ctf/flag_taken_team02" );
    prcAnnouncerFlagTakenEnemy01 = G_SoundIndex( "sounds/announcer/ctf/flag_taken_enemy_01" );
    prcAnnouncerFlagTakenEnemy02 = G_SoundIndex( "sounds/announcer/ctf/flag_taken_enemy_02" );
    prcAnnouncerFlagScore01 = G_SoundIndex( "sounds/announcer/ctf/score01" );
    prcAnnouncerFlagScore02 = G_SoundIndex( "sounds/announcer/ctf/score02" );
    prcAnnouncerFlagScoreTeam01 = G_SoundIndex( "sounds/announcer/ctf/score_team01" );
    prcAnnouncerFlagScoreTeam02 = G_SoundIndex( "sounds/announcer/ctf/score_team02" );
    prcAnnouncerFlagScoreEnemy01 = G_SoundIndex( "sounds/announcer/ctf/score_enemy01" );
    prcAnnouncerFlagScoreEnemy02 = G_SoundIndex( "sounds/announcer/ctf/score_enemy02" );

    // add commands
    G_RegisterCommand( "drop" );
    G_RegisterCommand( "gametype" );
    G_RegisterCommand( "gametypemenu" );
    G_RegisterCommand( "class" );
    G_RegisterCommand( "build" );
    G_RegisterCommand( "destroy" );

    // Make turret models pure
    G_ModelIndex( "models/objects/turret/base.md3", true );
    G_ModelIndex( "models/objects/turret/gun.md3", true );
    G_ModelIndex( "models/objects/turret/flash.md3", true );

    InitPlayers();
    G_RegisterCallvote( "ctf_powerup_drop", "1 or 0", "bool", "Enables or disables the dropping of powerups at dying" );

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
