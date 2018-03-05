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

int CTFT_BASE_RESPAWN_TIME = 7000;
int CTFT_DISABLED_REVIVER_RESPAWN_PENALTY = 4000;
int CTFT_BUILD_AP_COST = 50;
int CTFT_CLUSTER_GRENADE_AP_COST = 50;
uint CTFT_BUILD_COOLDOWN_TIME = 1500;
float CTFT_GUNNER_INVISIBILITY_MINLOAD = 20;
float CTFT_GUNNER_INVISIBILITY_MAXLOAD = 100;
uint CTFT_INVISIBILITY_COOLDOWN = 1000;
uint WTF_GUNNER_DEPLOY_TIME = 1000;
uint WTF_SHELL_COOLDOWN = 6000;
uint CTFT_DETECTOR_GRENADE_COOLDOWN = 8000;
uint CTFT_FLAG_DISPENSER_COOLDOWN_TIME = 30000;
int CTFT_MEDIC_REGEN_COOLDOWN = 1200;
int CTFT_SUPPORT_REGEN_COOLDOWN = 1200;
uint WTF_TRANSLOCATOR_COOLDOWN = 2000;
uint WTF_TRANSLOCATOR_RETURN_TIME = WTF_TRANSLOCATOR_COOLDOWN + 3000;
uint WTF_ADRENALINE_TIME = 1750;
int CTFT_BLAST_COOLDOWN = 1000;
int CTFT_BLAST_AP_COST = 15;
int WTF_SMOKE_GRENADE_AP_COST = 50;
int WTF_ADRENALINE_AP_COST = 50;
int WTF_INSTA_SHOT_AP_COST = 25;
float CTFT_TRANSLOCATOR_HEALTH = 99;
float CTFT_RESPAWN_RADIUS = 384.0f;
float CTFT_BUILD_RADIUS = 160.0f;
float CTFT_BUILD_DESTROY_RADIUS = 96.0f;
float CTFT_MEDIC_INFLUENCE_BASE_RADIUS = 192.0f;
float CTFT_SUPPORT_INFLUENCE_BASE_RADIUS = 192.0f;

const int CTFT_BLAST_DAMAGE = 101;

const uint CTFT_BIO_GRENADE_COOLDOWN = 2000;
const uint CTFT_BIO_GRENADE_DECAY = 2000;
const float CTFT_BIO_GRENADE_RADIUS = 96.0f;
const int CTFT_BIO_GRENADE_HEALTH_COST = 50;

// Shared values for all grenades.
// Values should match GL projectile ones to aid aiming.
const float CTFT_GRENADE_SPEED = 1000;
const uint CTFT_GRENADE_TIMEOUT = 1250;

const int CTFT_GUNNER_MAX_LG_AMMO = 180;

const float CTFT_PLAYER_DETECTION_RADIUS = 512;
const int CTFT_MOTION_DETECTOR_AP_COST = 40;

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

int prcBouncePadActivateSound;
int prcBouncePadSpawnerModel;
int prcBouncePadNormalModel;
int prcBouncePadActivatedModel;

int prcAdrenalineTrailEmitterShaderIndex;

int prcBioCloudShaderIndex;
int prcBioTeamSparksShaderIndex;
int prcBioEnemySparksShaderIndex;
int prcBioEmissionSound;

int prcMotionDetectorSpriteImageIndex;
int prcMotionDetectorMinimapImageIndex;

int prcTransBodyNormalModelIndex;
int prcTransBodyDamagedModelIndex;
int prcTransInSoundIndex;
int prcTransOutSoundIndex;
int prcTransCheckSucceededSoundIndex;
int prcTransReturnedSoundIndex;

bool firstSpawn = false;

Cvar ctfAllowPowerupDrop( "ctf_powerupDrop", "0", CVAR_ARCHIVE );
Cvar wtfForceFullbrightSkins( "wtf_forceFullbrightSkins", "0", CVAR_ARCHIVE );

const String SELECT_CLASS_COMMAND = 
	"mecu \"Select class\"" 
	+ " Grunt \"class grunt\" Medic \"class medic\" Runner \"class runner\"" 
	+ " Gunner \"class gunner\" Support \"class support\" Sniper \"class sniper\"";

///*****************************************************************
/// LOCAL FUNCTIONS
///*****************************************************************

// a player has just died. The script is warned about it so it can account scores
void CTF_playerKilled( Entity @target, Entity @attacker, Entity @inflictor, bool suppressAwards )
{
    if ( @target.client == null )
        return;

    cFlagBase @flagBase = @CTF_getBaseForCarrier( target );

    // reset flag if carrying one
    if ( @flagBase != null )
    {
        if ( @attacker != null )
            flagBase.carrierKilled( attacker, target, suppressAwards );

        CTF_PlayerDropFlag( target, false );
    }
    else if ( @attacker != null )
    {
        @flagBase = @CTF_getBaseForTeam( attacker.team );

        // if not flag carrier, check whether victim was offending our flag base or friendly flag carrier
        if ( @flagBase != null )
            flagBase.offenderKilled( attacker, target, suppressAwards );		
    }

    if ( match.getState() != MATCH_STATE_PLAYTIME )
        return;

    // check for generic awards for the frag
    if( !suppressAwards && @attacker != null && attacker.team != target.team )
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
	else if ( cmdString == "classaction1" )
	{
		CTFT_Classaction1Command( client );
		return true;
	}
	else if ( cmdString == "classaction2" )
	{
		CTFT_Classaction2Command( client );
		return true;
	}
	else if ( cmdString == "altattack" )
	{
		CTFT_AltAttackCommand( client, argsString, argc );
		return true;
	}
	else if ( cmdString == "build" )
	{
		CTFT_BuildCommand( client, argsString, argc );
		return true;
	}
	else if ( cmdString == "destroy" )
	{
		CTFT_DestroyCommand( client, argsString, argc );
		return true;
	}
	else if ( cmdString == "deploy" )
	{
		CTFT_DeployCommand( client, argsString, argc );
		return true;
	}
	else if ( cmdString == "protect" )
	{
		CTFT_ProtectCommand( client, argsString, argc );
		return true;
	}
	else if ( cmdString == "supply" )
	{
		CTFT_SupplyCommand( client, argsString, argc );
		return true;
	}
	else if ( cmdString == "trans" )
	{
		CTFT_TransCommand( client, argsString, argc );
		return true;
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

		if ( votename == "wtf_force_fullbright_skins" )
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

            if ( voteArg == "0" && !wtfForceFullbrightSkins.boolean )
            {
                client.printMessage( "Forcing fullbright skins is already disallowed\n" );
                return false;
            }

            if ( voteArg == "1" && wtfForceFullbrightSkins.boolean )
            {
                client.printMessage( "Forcing fullbright skins is already allowed\n" );
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
		else if ( votename == "wtf_force_fullbright_skins" )
        {
            if ( argsString.getToken( 1 ).toInt() > 0 )
                wtfForceFullbrightSkins.set( 1 );
            else
                wtfForceFullbrightSkins.set( 0 );
        }

        return true;
    }

    return false;
}

void WTF_UpdateBotsExtraGoals()
{
    Entity @ent;
	Entity @reviver;
	Bot @bot;
	cPlayer @player;

	array<Entity @> @revivers = @G_FindByClassname( "reviver" );

	for( int i = 1; i <= maxClients; ++i )
	{
		@ent = @G_GetEntity( i );
		@bot = ent.client.getBot();
		if( @bot == null )
			continue;

		bot.clearOverriddenEntityWeights();

		WTF_UpdateFlagAndBaseWeights( ent, bot );

		@player = @GetPlayer( ent.client );
		// TODO: Link all players of the same class in lists
		if( player.playerClass.tag != PLAYERCLASS_MEDIC )
		{
			continue;
		}

		// Set a high weight for every reviver
		for( int j = 0; j < revivers.size(); ++j )
		{
			@reviver = @revivers[j];
			if( reviver.origin.distance( ent.origin ) < 512.0f )
			{
				if( G_InPVS( reviver.origin, ent.origin ) )
				{
					bot.overrideEntityWeight( reviver, reviver.team == ent.team ? 16.0f : 9.0f );
					continue;
				}
			}

			bot.overrideEntityWeight( reviver, reviver.team == ent.team ? 5.0f : 2.0f );
		}
	}
}


// Updates extra weights related to flags and bases that are not covered by defense/offense spots logic
void WTF_UpdateFlagAndBaseWeights( Entity @ent, Bot @bot )
{
    int enemyTeam;
    if ( ent.team == TEAM_ALPHA )
        enemyTeam = TEAM_BETA;
    else if ( ent.team == TEAM_BETA )
        enemyTeam = TEAM_ALPHA;
    else
        return;

    // Flags defence/offence/carrier support is managed by native code
    // using provided status of defence/offence spots.

    // The only thing should be managed in scripts is returning to a base.
    // (Carrier behaviour differs for custom gametypes).

    // Also dropped flags are managed here too.

    cFlagBase @teamBase = @CTF_getBaseForTeam( ent.team );

    if ( @teamBase != null )
    {
        // The bot is a carrier, so it should return to the team base
        if ( ( ent.effects & EF_CARRIER ) != 0 )
        {
            if ( @teamBase.owner != null )
            {
                // the flag is at our base, return to the base
                if ( ( teamBase.owner.effects & EF_CARRIER ) != 0 )
                {
                    bot.overrideEntityWeight( teamBase.owner, 9.0f );
                }
                // our flag is stolen
                else
                {
                    float botToHomeBaseDist = teamBase.owner.origin.distance( ent.origin );
                    // return to our base
                    if ( botToHomeBaseDist > 768.0f )
                    {
                        bot.overrideEntityWeight( teamBase.owner, 9.0f );
                    }
                    // do not camp at our flag spot, hide somewhere else
                    else
                    {
                        bot.overrideEntityWeight( teamBase.owner, 9.0f * ( botToHomeBaseDist / 768.0f ) );
                    }
                }
            }
        }

        // it's team flag, dropped somewhere
        if ( @teamBase.carrier != @teamBase.owner && @teamBase.carrier.client == null )
            bot.overrideEntityWeight( teamBase.carrier, 9.0f );
    }

    cFlagBase @enemyBase = @CTF_getBaseForTeam( enemyTeam );
    if ( @enemyBase != null )
    {
        // it's team flag, dropped somewhere
        if ( @enemyBase.carrier != @enemyBase.owner && @enemyBase.carrier.client == null )
            bot.overrideEntityWeight( enemyBase.carrier, 9.0f );
    }
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
                if ( player.reviver.triggered == true )
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

// This is a big HACK to buff LG damage in deployed mode!
// We can't call G_Damage() in GT_ScoreEvent() because GT_ScoreEvent() 
// is called inside G_Damage() and G_Damage() is not reentrant.
// For each entity we record 4 attackers that used the specified fire mode
// (if there were > 4 attackers the target is likely to be dead instantly, don't bother about data loss).
// Then we apply damage outside GT_ScoreEvent() in GT_ThinkRules()
int[] entitySpecialLGAttackers(4 * maxEntities);
int[] entitySpecialLGNumAttackers(maxEntities);

void CTFT_ApplySpecialLGDamage()
{
	for (int i = 0; i < maxEntities; ++i)
	{	
		int numAttackers = entitySpecialLGNumAttackers[i];
		if ( numAttackers > 0 )
		{
			Entity @target = @G_GetEntity( i );
			for (int j = 0; j < numAttackers; ++j)
			{
				Entity @attacker = @G_GetEntity( entitySpecialLGAttackers[4 * i + j] );
				Vec3 damageDir(target.origin);
				damageDir -= attacker.origin;
				damageDir.normalize();
				// Base LG damage is 7.0 units per shot
				// Base LG knockback is 14 knockback units per shot
				// Add extra 1.5x damage and knockback
				target.sustainDamage( attacker, attacker, damageDir, 10.5f, 21, 300, MOD_LASERGUN_W );
			}
		}
		entitySpecialLGNumAttackers[i] = 0;
	} 
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
		Entity @attacker = @G_GetEntity( arg3 );	

        if ( @target != null )
        {
			if ( @target.client != null )
			{
            	GetPlayer( target.client ).tookDamage( arg3, arg2 );
			}
        }

		if ( @attacker.client != null )
		{
			if ( GetPlayer( attacker.client ).isDeployed )
			{
				// Check whether this is actually LG damage 
				// (otherwise damage from projectiles fired before deployment might be counted).
				if ( arg2 == 7.0f )
				{
					if ( entitySpecialLGNumAttackers[arg1] < 4 )
					{
						entitySpecialLGAttackers[4 * arg1 + entitySpecialLGNumAttackers[arg1]++] = arg3;
					}
				}
			}
		}
    }
    else if ( score_event == "kill" )
    {
        Entity @target = G_GetEntity( args.getToken( 0 ).toInt() );
		Entity @inflictor = G_GetEntity( args.getToken( 1 ).toInt() );
		Entity @attacker = G_GetEntity( args.getToken( 2 ).toInt() );

        // Important - if turret ends up here without this, crash =P
        if ( @target == null || @target.client == null )
            return;

        // target, attacker, inflictor, suppressAwards
        CTF_playerKilled( target, attacker, inflictor, @attacker.client == null );

        // Class-specific death stuff
        cPlayer @targetPlayer = @GetPlayer( target.client );
		// Set base player respawn time
		targetPlayer.respawnTime = levelTime + CTFT_BASE_RESPAWN_TIME;
		// Shorten respawn time when fragged at the team base
		cFlagBase @targetBase = @CTF_getBaseForTeam( target.team );
		if ( @targetBase != null )
		{
			cFlagBase @enemyBase = @CTF_getBaseForTeam( target.team == TEAM_ALPHA ? TEAM_BETA : TEAM_ALPHA );
			if ( @enemyBase != null )
			{
				float baseToBaseDistance = targetBase.owner.origin.distance( enemyBase.owner.origin );
				float targetToBaseDistance = target.origin.distance( targetBase.owner.origin );
				if ( targetToBaseDistance < 0.16f * baseToBaseDistance )
					targetPlayer.respawnTime -= 2000;
				else if ( targetToBaseDistance < 0.33f * baseToBaseDistance )
					targetPlayer.respawnTime -= 1000;
			}
		}

        // Spawn respawn indicator
        if ( match.getState() == MATCH_STATE_PLAYTIME )
            targetPlayer.spawnReviver();

        if ( targetPlayer.playerClass.tag == PLAYERCLASS_SUPPORT )
		{
			CTFT_DeathDrop( target.client, "Armor Shard", 5 );
		}
		else if ( targetPlayer.playerClass.tag == PLAYERCLASS_GUNNER )
		{
			CTFT_DeathDrop( target.client, "Armor Shard", 5 );
		}
		else if ( targetPlayer.playerClass.tag == PLAYERCLASS_SNIPER )
		{
			CTFT_DeathDrop( target.client, "Armor Shard", 5 );
		}
		else if ( targetPlayer.playerClass.tag == PLAYERCLASS_MEDIC )
		{
			CTFT_DeathDrop( target.client, "50 Health" );
		}
		else if ( targetPlayer.playerClass.tag == PLAYERCLASS_GRUNT )
		{
			CTFT_DeathDrop( target.client, "Green Armor" );

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
                player.setAppropriateBotClass();
            }
            else
                client.execGameCommand( SELECT_CLASS_COMMAND );
        }

        // Set newly joined players to respawn queue
        if ( new_team == TEAM_ALPHA || new_team == TEAM_BETA )
            player.respawnTime = levelTime + CTFT_BASE_RESPAWN_TIME;
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
        client.inventoryGiveItem( WEAP_RIOTGUN );
    }
    // Medic
    else if ( player.playerClass.tag == PLAYERCLASS_MEDIC )
    {
        // Weapons
        client.inventoryGiveItem( WEAP_RIOTGUN );
        client.inventoryGiveItem( WEAP_MACHINEGUN );
		client.inventoryGiveItem( WEAP_GRENADELAUNCHER );
    }
    // Grunt
    else if ( player.playerClass.tag == PLAYERCLASS_GRUNT )
    {
        // Weapons
        client.inventoryGiveItem( WEAP_ROCKETLAUNCHER );
        client.inventoryGiveItem( WEAP_LASERGUN );
        client.inventoryGiveItem( WEAP_GRENADELAUNCHER );
    }
    // Gunner
    else if ( player.playerClass.tag == PLAYERCLASS_GUNNER )
    {
        // Weapons
        client.inventoryGiveItem( WEAP_LASERGUN );
        client.inventoryGiveItem( WEAP_PLASMAGUN );
        client.inventoryGiveItem( WEAP_GRENADELAUNCHER );
    }
	else if ( player.playerClass.tag == PLAYERCLASS_SUPPORT )
	{
		// Weapons
		client.inventoryGiveItem( WEAP_ELECTROBOLT );
		client.inventoryGiveItem( WEAP_SHOCKWAVE );
	}
	else if ( player.playerClass.tag == PLAYERCLASS_SNIPER )
	{
		// Weapons
		client.inventoryGiveItem( WEAP_INSTAGUN );		
		client.inventoryGiveItem( WEAP_ELECTROBOLT );
		client.inventoryGiveItem( WEAP_MACHINEGUN );
		// Remove GB
		client.inventorySetCount( WEAP_GUNBLADE, 0 );
		// Remove IG ammo
		client.inventorySetCount( AMMO_INSTAS, 0 );
	}

	ent.svflags |= SVF_FORCETEAM;

	CTF_SetVoicecommQuickMenu( @client, player.playerClass.tag );
	
    // add a teleportation effect
    ent.respawnEffect();

    if ( @player.reviver != null && player.reviver.triggered )
    {
        // when revived do not clear all timers
        player.respawnTime = 0;
        player.invisibilityEnabled = false;
        player.invisibilityLoad = 0;
        player.invisibilityCooldownTime = 0;
        player.hudMessageTimeout = 0;

		player.isDeployed = false;
		player.isDeployingUp = false;
		player.isDeployingDown = false;
        player.lastNormalModeWeapon = -1;
    }
    else
        player.resetTimers();

	// must be called after resetting deployed mode (since it depends of it)
	player.loadAmmo();
	// if was fragged in deployed mode, some weak lasers ammo might be left
	client.inventorySetCount( AMMO_WEAK_LASERS, 0 );

    // select rocket launcher if available
    client.selectWeapon( -1 ); // auto-select best weapon in the inventory

    player.removeReviver();

	player.printDescription();
	player.printNextTip();
}

// Sniper is the single truly defencive class
// Runner is the single truly offensive class
// Other classes are really versatile

float GT_PlayerOffensiveAbilitiesRating( const Client @client )
{
	switch( GetPlayer( client ).playerClass.tag )
	{
		case PLAYERCLASS_SNIPER:
			return 0.0f;
		case PLAYERCLASS_RUNNER:
			return 1.0f;
	}

	return 0.5f;
}

float GT_PlayerDefenciveAbilitiesRating( const Client @client )
{
	switch( GetPlayer( client ).playerClass.tag )
	{
		case PLAYERCLASS_SNIPER:
			return 1.0f;
		case PLAYERCLASS_RUNNER:
			return 0.0f;
		// Contrary to the offense rating, medics and supports
		// should have a distinct and lower defence score.
		case PLAYERCLASS_MEDIC:
		case PLAYERCLASS_SUPPORT:
			return 0.3f;
		case PLAYERCLASS_GUNNER:
		case PLAYERCLASS_GRUNT:
			return 0.6f;
	}

	return 0.5f;
}

int GT_GetScriptWeaponsNum( const Client @client ) 
{
	switch( GetPlayer( client ).playerClass.tag )
	{
		case PLAYERCLASS_GRUNT:
			return 1;
		case PLAYERCLASS_MEDIC:
			return 1;
		// Consider a smoke grenade as just a weapon until a squad action planner is implenented. 
		case PLAYERCLASS_SUPPORT:
			return 1;
	}
	
	return 0;
}

bool GT_GetScriptWeaponDef( const Client @client, int weaponNum, AIScriptWeaponDef &out weaponDef )
{
	if( weaponNum != 0 ) 
		return false;

	weaponDef.weaponNum = 0;
	// All these "weapons" are grenades
	weaponDef.aimType = AI_WEAPON_AIM_TYPE_DROP;
	weaponDef.projectileSpeed = 1000;
	// Don't even try to throw it further
	weaponDef.maxRange = 2500;
	
	switch( GetPlayer( client ).playerClass.tag )
	{
		case PLAYERCLASS_GRUNT:
			weaponDef.tier = 4;
			weaponDef.minRange = 128;
			weaponDef.bestRange = 768;
			weaponDef.splashRadius = 250;
			weaponDef.maxSelfDamage = 500;
			return true;
		case PLAYERCLASS_MEDIC:
			weaponDef.tier = 3;
			// Don't throw it being close to enemy and thus losing health in a volatile position
			weaponDef.minRange = 192;
			weaponDef.bestRange = 1000;
			weaponDef.splashRadius = 96;
			weaponDef.maxSelfDamage = 0;
			return true;
		case PLAYERCLASS_SUPPORT:
			weaponDef.tier = 4;
			// Same as for medic, moreover should force throwing it far away 
			weaponDef.minRange = 768;
			weaponDef.bestRange = 1200;
			// A huge fake value to force throwing it
			weaponDef.splashRadius = 500;
			weaponDef.maxSelfDamage = 0;
			return true;
	}
	
	return false;
}

int GT_GetScriptWeaponCooldown( const Client @client, int weaponNum )
{
	if( weaponNum != 0 ) 
		return 99999;

	Entity @ent = @client.getEnt();
	cPlayer @player = @GetPlayer( client );
	switch( player.playerClass.tag ) 
	{
		case PLAYERCLASS_GRUNT:
			if( client.armor < CTFT_CLUSTER_GRENADE_AP_COST ) 
				return 99999;

			if( ent.health < 75 && ( ent.effects & EF_SHELL ) == 0 ) 
				return 99999;

			return 0;
		case PLAYERCLASS_MEDIC:
			{
				if( ent.health < CTFT_BIO_GRENADE_HEALTH_COST + 25 )
					return 99999;

				if( player.isBioGrenadeCooldown() )
					return 99999;

			
				auto @selectedEnemies = @client.getBot().selectedEnemies;
				if( selectedEnemies.areValid() && selectedEnemies.areThreatening() )
					return 99999;
			}
			return 0;
		case PLAYERCLASS_SUPPORT:
			{
				if( client.armor < WTF_SMOKE_GRENADE_AP_COST )
					return 99999;

				if( ent.health < 75 )
					return 99999;

				// Don't throw being at our base
				float distanceToBotBase = 999999.0f;
				float distanceToNmyBase = 999999.0f;				
				for ( cFlagBase @flagBase = @fbHead; @flagBase != null; @flagBase = @flagBase.next )
    			{
					float distance = flagBase.owner.origin.distance( ent.origin );
					if( flagBase.team == ent.team )
						distanceToBotBase = distance;
					else 
						distanceToNmyBase = distance;					
				}
				// The only exception, throw at our base being a carrier
				if( distanceToBotBase < distanceToNmyBase )
				{
					if( ( ent.effects & EF_CARRIER ) != 0 )
						return 0;

					return 99999;
				}
				// Don't throw if there are no threatening enemies being in the middle of the map
				if( 2 * distanceToBotBase < 3 * distanceToNmyBase )
				{
					auto @selectedEnemies = @client.getBot().selectedEnemies;
					if( !( selectedEnemies.areValid() && selectedEnemies.areThreatening() ) )
						return 99999;
				}
			}
			
			return 0;
	}

	return 99999;
}

bool GT_SelectScriptWeapon( Client @client, int weaponNum )
{
	return weaponNum == 0;
}

bool GT_FireScriptWeapon( Client @client, int weaponNum )
{
	if( weaponNum != 0 )
		return false;

	cPlayer @player = GetPlayer( client );
	switch( player.playerClass.tag )
	{
		case PLAYERCLASS_GRUNT:
			CTFT_ThrowClusterGrenade( client, player );
			return true;
		case PLAYERCLASS_MEDIC:
			CTFT_ThrowBioGrenade( client, player );
			return true;
		case PLAYERCLASS_SUPPORT:
			CTFT_ThrowSmokeGrenade( client, player );
			return true;
	}

	return false;
}

void CTFT_UpdateHidenameEffects()
{
	// First clear the hidename effect for regular players and set the hidename effect for invisible players
	for ( int i = 0; i < maxClients; i++ )
	{
		cPlayer @player = GetPlayer( i );
		if ( player.client.state() < CS_SPAWNED )
			continue;

		if ( player.invisibilityEnabled )
			player.ent.effects |= EF_PLAYER_HIDENAME;
		else
			player.ent.effects &= ~EF_PLAYER_HIDENAME;
	}

	// Find all smoke emitters
	array<Entity @> @smokeEmitters = @G_FindByClassname( "smoke_emitter" );

	// We can't disable showing names of entities behind the smoke cloud.
	// It should be handled on engine level as this thing is tightly coupled with PVS stuff.
	// Best thing we can to is applying hidename effect to entities inside the cloud
	// and hope that clients are fair enough to have cg_showPlayerNames_zfar low.

	// For each smoke emitter
	for ( uint i = 0; i < smokeEmitters.size(); ++i )
	{
		// Find entities in the smoke cloud
		Entity @emitter = smokeEmitters[i];
		float radius = 32.0f;
		// The cloud is growing, so we need to adjust the radius
		if ( emitter.nextThink > levelTime )
		{
			// Ensure that the division below yields a float result
			float timeToNextThink = emitter.nextThink - levelTime;
			// If emitter has not finished emission yet ( count == 0 )
			if ( emitter.count == 0 )
				radius += 512.0f * ( 1.0f - timeToNextThink / CTFT_SMOKE_EMITTER_EMISSION_TIME );
			else
				radius += 512.0f + 384.0f * ( 1.0f - timeToNextThink / CTFT_SMOKE_EMITTER_DECAY_TIME );
		}

		array<Entity @> @inradius = @G_FindInRadius( smokeEmitters[i].origin, radius );
		for ( uint j = 0; j < inradius.size(); ++j )
		{
			Entity @ent = inradius[j];
			if ( @ent.client == null )
				continue;
			if ( ent.client.state() < CS_SPAWNED )
				continue;
			if ( ent.isGhosting() )
				continue;

			ent.effects |= EF_PLAYER_HIDENAME;
		}
	}
}

void CTFT_UpdateDetectionEntities()
{
	for ( int i = 0; i < maxClients; ++i )
	{
		GetPlayer( G_GetClient( i ) ).hideDetectionEntities();
	}

	// Make sure that Runners moving on ground cannot be detected
	const float speedLimit = cPlayerClassInfos[ PLAYERCLASS_RUNNER ].pmoveMaxSpeedOnGround;
	array<Entity @> @detectors = @G_FindByClassname( "motion_detector" );
	for ( uint i = 0; i < detectors.size(); ++i )
	{
		Entity @detector = detectors[i];
		array<Entity @> @inradius = @G_FindInRadius( detector.origin, CTFT_PLAYER_DETECTION_RADIUS );
		for ( uint j = 0; j < inradius.size(); ++j )
		{
			Entity @ent = inradius[j];
			if ( @ent.client == null )
				continue;
			if ( ent.isGhosting() )
				continue;
			if ( ent.team == detector.team )
				continue;
			// Skip slow targets 
			if ( ent.velocity.length() <= speedLimit )
				continue;
			// This test is not cheap, do it last after all possible rejections
			if ( !G_InPVS( detector.origin, ent.origin ) )
				continue;

			GetPlayer( ent.client ).showDetectionEntities();
		}
	}
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
    {
        if ( !match.checkExtendPlayTime() )
            match.launchState( match.getState() + 1 );
    }

	CTFT_ApplySpecialLGDamage();

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
		cPlayer @player = GetPlayer( i );
		player.clearInfluence();
		if ( player.client.state() == CS_SPAWNED && player.ent.isGhosting() )
		{
			if ( @player.translocator != null )
				player.returnTranslocator();
			// Prevent applying these commands after respawn
			player.hasPendingSupplyAmmoCommand = false;
			player.hasPendingSupplyAdrenalineCommand = false;
			player.isTranslocating = false;
			player.hasJustTranslocated = false;
		}
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
		player.watchDeployedMode();
        player.updateHUDstats();
		player.printNextTip();
    }

	CTFT_UpdateHidenameEffects();

	CTFT_UpdateDetectionEntities();

	WTF_UpdateBotsExtraGoals();
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
        CTFT_RemoveBombs();
		CTFT_RemoveTranslocators();
		CTFT_RemoveSmokeGrenades();
		CTFT_RemoveBouncePads();
		CTFT_RemoveMotionDetectors();
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
    CTFT_RemoveBombs();
	CTFT_RemoveTranslocators();
	CTFT_RemoveSmokeGrenades();
	CTFT_RemoveBouncePads();
	CTFT_RemoveMotionDetectors();
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

				// Return a translocator if it is thrown
				if ( @player.translocator != null )
				{
					player.returnTranslocator();
					// Prevent gaining extra armor at spawn when a translocator is returned
					if ( ent.client.armor >= player.playerClass.armor )
						ent.client.armor = player.playerClass.armor;
				}
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
	G_RegisterCommand( "classaction1" );
	G_RegisterCommand( "classaction2" );
	G_RegisterCommand( "build" );
	G_RegisterCommand( "destroy" );
	G_RegisterCommand( "deploy" );
	G_RegisterCommand( "altattack" );
	G_RegisterCommand( "protect" );
	G_RegisterCommand( "supply" );
	G_RegisterCommand( "trans" );

  
	// Make WTF assets pure

    G_ModelIndex( "scripts/wtf_gfx.shader", true );

    // Class Icons
    G_ImageIndex( "gfx/wtf/wtf_engineer" );
    G_ImageIndex( "gfx/wtf/wtf_medic" );
    G_ImageIndex( "gfx/wtf/wtf_runner" );
    G_ImageIndex( "gfx/wtf/wtf_support" );
    G_ImageIndex( "gfx/wtf/wtf_sniper" );

    // Reviver
    G_ModelIndex( "models/wtf/reviver.md3", true );
    G_ImageIndex( "models/wtf/reviver" );
    G_ImageIndex( "models/wtf/reviver_outline" );
    G_ImageIndex( "gfx/wtf/reviver_decal" );

	// Bouncepad
	prcBouncePadActivateSound = G_SoundIndex( "sounds/wtf/bouncepad", true );
	prcBouncePadSpawnerModel = G_ModelIndex( "models/wtf/bouncepad_spawner.md3", true );
	prcBouncePadNormalModel = G_ModelIndex( "models/wtf/bouncepad_normal.md3", true );
	prcBouncePadActivatedModel = G_ModelIndex( "models/wtf/bouncepad_activated.md3", true );

	// Smoke
	G_ImageIndex( "gfx/wtf/wtf_smoke" );

	// Adrenaline
	prcAdrenalineTrailEmitterShaderIndex = G_ImageIndex( "gfx/wtf/adrenaline_trail" );

	// Bio
	prcBioCloudShaderIndex = G_ImageIndex( "gfx/wtf/bio_cloud" );
	prcBioTeamSparksShaderIndex = G_ImageIndex( "gfx/wtf/bio_team_sparks" );
	prcBioEnemySparksShaderIndex = G_ImageIndex( "gfx/wtf/bio_enemy_sparks" );
	prcBioEmissionSound = G_SoundIndex( "sounds/wtf/bio_emission", true );

	prcMotionDetectorSpriteImageIndex = G_ImageIndex( "gfx/wtf/motion_detector_sprite" );
	prcMotionDetectorMinimapImageIndex = G_ImageIndex( "gfx/wtf/motion_detector_minimap" );

	// Translocator
    prcTransBodyNormalModelIndex = G_ModelIndex( "models/wtf/translocator_body_normal.md3", true );
    prcTransBodyDamagedModelIndex = G_ModelIndex( "models/wtf/translocator_body_damaged.md3", true );
	G_ImageIndex( "models/wtf/translocator_body_normal" );
    G_ImageIndex( "models/wtf/translocator_body_damaged" );
    G_ImageIndex( "models/wtf/translocator_light" );
    G_ImageIndex( "models/wtf/translocator_body_normal_colorpass" );
    G_ImageIndex( "models/wtf/translocator_body_normal_emit" );
	prcTransInSoundIndex = G_SoundIndex( "sounds/world/tele_in", true );
	prcTransOutSoundIndex = G_SoundIndex( "sounds/world/tele_in", true );
	prcTransCheckSucceededSoundIndex = G_SoundIndex( "sounds/menu/ok", true );
	prcTransReturnedSoundIndex = G_SoundIndex( "sounds/menu/back", true );

    InitPlayers();
    G_RegisterCallvote( "ctf_powerup_drop", "1 or 0", "bool", "Enables or disables the dropping of powerups at dying" );
	G_RegisterCallvote( "wtf_force_fullbright_skins", "1 or 0", "bool", "Enables or disables forcing of fullbright skins for players" );

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
