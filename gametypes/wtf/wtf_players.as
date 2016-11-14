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

cPlayer[] gtPlayers( maxClients ); // gt info of each player

class cPlayer
{
    cPlayerClass @playerClass;
    Client @client;
    Entity @ent;
    cReviver @reviver;
    cTurret @turret;    
    cBomb @bomb;

    uint medicCooldownTime;
	uint gruntCooldownTime;
	uint supportCooldownTime;
    uint engineerBuildCooldownTime;
    uint shellCooldownTime;
    uint bombCooldownTime;
    uint respawnTime;
	float medicInfluence;
	float supportInfluence;
    bool invisibilityEnabled;
    float invisibilityLoad;
    int invisibilityWasUsingWeapon;
    uint invisibilityCooldownTime;
    uint hudMessageTimeout;

    cPlayer @deadcamMedic;
    uint deadcamMedicScanTime;

	double medicInfluenceScore;
	double supportInfluenceScore;

    cPlayer()
    {
        // initialize all as grunt
        @this.playerClass = @cPlayerClassInfos[PLAYERCLASS_GRUNT];
        @this.reviver = null;
        @this.turret = null;
        @this.bomb = null;
        this.resetTimers();
		
		this.medicInfluenceScore = 0.0;
		this.supportInfluenceScore = 0.0;
    }

    ~cPlayer() {}

    void resetTimers()
    {
        this.medicCooldownTime = 0;
		this.gruntCooldownTime = 0;
		this.supportCooldownTime = 0;
        this.engineerBuildCooldownTime = 0;
        this.shellCooldownTime = 0;
        this.bombCooldownTime = 0;
        this.respawnTime = 0;
		this.medicInfluence = 0.0f;
		this.supportInfluence = 0.0f;
        this.invisibilityEnabled = false;
        this.invisibilityLoad = 0;
        this.invisibilityCooldownTime = 0;
        this.hudMessageTimeout = 0;
        this.deadcamMedicScanTime = 0;

        this.invisibilityWasUsingWeapon = -1;
    }

    void printMessage( String &string )
    {
        this.client.printMessage( string );
    }

    void setHudMessage( String &message, int timeout, int placement )
    {
        if ( this.ent.team != TEAM_SPECTATOR && !this.ent.isGhosting() )
        {
            if ( placement == 0 )
                placement = STAT_MESSAGE_SELF;
            else if ( placement == 1 )
                placement = STAT_MESSAGE_ALPHA;
            else if ( placement == 2 )
                placement = STAT_MESSAGE_BETA;

            G_ConfigString( CS_GENERAL, message );
            this.client.setHUDStat( placement, CS_GENERAL );

            this.hudMessageTimeout = levelTime + timeout;
        }
    }

    void updateHUDstats()
    {
        this.client.setHUDStat( STAT_PROGRESS_SELF, 0 );
        this.client.setHUDStat( STAT_PROGRESS_OTHER, 0 );
        this.client.setHUDStat( STAT_IMAGE_SELF, 0 );
        this.client.setHUDStat( STAT_IMAGE_OTHER, 0 );
        this.client.setHUDStat( STAT_PROGRESS_ALPHA, 0 );
        this.client.setHUDStat( STAT_PROGRESS_BETA, 0 );
        this.client.setHUDStat( STAT_IMAGE_ALPHA, 0 );
        this.client.setHUDStat( STAT_IMAGE_BETA, 0 );
        this.client.setHUDStat( STAT_IMAGE_CLASSACTION1, 0 );
        this.client.setHUDStat( STAT_IMAGE_CLASSACTION2, 0 );
        this.client.setHUDStat( STAT_IMAGE_DROP_ITEM, 0 );

        if ( this.hudMessageTimeout < levelTime )
        {
            this.client.setHUDStat( STAT_MESSAGE_SELF, 0 );
            this.client.setHUDStat( STAT_MESSAGE_ALPHA, 0 );
            this.client.setHUDStat( STAT_MESSAGE_BETA, 0 );
        }

        float frac;

        if ( this.isEngineerCooldown() )
        {
            frac = float( this.engineerCooldownTimeLeft() ) / float( CTFT_ENGINEER_BUILD_COOLDOWN_TIME );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

        if ( this.isShellCooldown() )
        {
            frac = float( this.shellCooldownTimeLeft() ) / float( CTFT_SHELL_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

        if ( this.isBombCooldown() )
        {
            frac = float( this.bombCooldownTimeLeft() ) / float( CTFT_BOMB_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

        if ( this.playerClass.tag == PLAYERCLASS_SNIPER && this.invisibilityLoad > 0 )
        {
            frac = this.invisibilityLoad / CTFT_SNIPER_INVISIBILITY_MAXLOAD;
            if ( this.isInvisibilityCooldown() || this.invisibilityLoad < CTFT_SNIPER_INVISIBILITY_MINLOAD )
                this.client.setHUDStat( STAT_PROGRESS_SELF, -int( frac * 100 ) );
            else
                this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

        /****************************************
        * Flag state icons
        ****************************************/

        int alphaState = 0, betaState = 0; // 0 at base, 1 stolen, 2 dropped

        for ( cFlagBase @flagBase = @fbHead; @flagBase != null; @flagBase = @flagBase.next )
        {
            if ( flagBase.owner.team == TEAM_ALPHA )
            {
                if ( @flagBase.owner == @flagBase.carrier )
                    alphaState = 0;
                else if ( @flagBase.carrier.client != null )
                    alphaState = 1;
                else if ( @flagBase.carrier != null )
                    alphaState = 2;
            }

            if ( flagBase.owner.team == TEAM_BETA )
            {
                if ( @flagBase.owner == @flagBase.carrier )
                    betaState = 0;
                else if ( @flagBase.carrier.client != null )
                    betaState = 1;
                else if ( @flagBase.carrier != null )
                    betaState = 2;
            }
        }

        if ( ent.team == TEAM_ALPHA )
        {
            if ( @CTF_getBaseForCarrier( ent ) != null )
            {
                this.client.setHUDStat( STAT_IMAGE_OTHER, prcFlagIconCarrier );
                this.client.setHUDStat( STAT_IMAGE_DROP_ITEM, prcDropFlagIcon );
            }
            else if ( betaState == 2 )
                this.client.setHUDStat( STAT_IMAGE_OTHER, prcFlagIconLost );
            else if ( betaState == 1 )
                this.client.setHUDStat( STAT_IMAGE_OTHER, prcFlagIconStolen );

            if ( alphaState == 2 )
                this.client.setHUDStat( STAT_IMAGE_SELF, prcFlagIconLost );
            else if ( alphaState == 1 )
                this.client.setHUDStat( STAT_IMAGE_SELF, prcFlagIconStolen );

            this.client.setHUDStat( STAT_IMAGE_BETA, this.playerClass.iconIndex );

            this.client.setHUDStat( STAT_IMAGE_CLASSACTION1, this.playerClass.action1IconIndex );
            this.client.setHUDStat( STAT_IMAGE_CLASSACTION2, this.playerClass.action2IconIndex );
        }
        else if ( ent.team == TEAM_BETA )
        {
            if ( @CTF_getBaseForCarrier( ent ) != null )
            {
                this.client.setHUDStat( STAT_IMAGE_OTHER, prcFlagIconCarrier );
                this.client.setHUDStat( STAT_IMAGE_DROP_ITEM, prcDropFlagIcon );
            }
            else if ( alphaState == 2 )
                this.client.setHUDStat( STAT_IMAGE_OTHER, prcFlagIconLost );
            else if ( alphaState == 1 )
                this.client.setHUDStat( STAT_IMAGE_OTHER, prcFlagIconStolen );

            if ( betaState == 2 )
                this.client.setHUDStat( STAT_IMAGE_SELF, prcFlagIconLost );
            else if ( betaState == 1 )
                this.client.setHUDStat( STAT_IMAGE_SELF, prcFlagIconStolen );

            this.client.setHUDStat( STAT_IMAGE_BETA, this.playerClass.iconIndex );

            this.client.setHUDStat( STAT_IMAGE_CLASSACTION1, this.playerClass.action1IconIndex );
            this.client.setHUDStat( STAT_IMAGE_CLASSACTION2, this.playerClass.action2IconIndex );
        }
        else if ( this.client.chaseActive == false ) // don't bother with people in chasecam, they will get a copy of their chase target stat
        {
            if ( alphaState == 2 )
                this.client.setHUDStat( STAT_IMAGE_ALPHA, prcFlagIconLost );
            else if ( alphaState == 1 )
                this.client.setHUDStat( STAT_IMAGE_ALPHA, prcFlagIconStolen );
            else
                this.client.setHUDStat( STAT_IMAGE_ALPHA, prcFlagIcon );

            if ( betaState == 2 )
                this.client.setHUDStat( STAT_IMAGE_BETA, prcFlagIconLost );
            else if ( betaState == 1 )
                this.client.setHUDStat( STAT_IMAGE_BETA, prcFlagIconStolen );
            else
                this.client.setHUDStat( STAT_IMAGE_BETA, prcFlagIcon );
        }
    }

    void setPlayerClass( int class_tag )
    {
        if ( class_tag < 0 || class_tag >= PLAYERCLASS_TOTAL )
            return;

        @this.playerClass = @cPlayerClassInfos[class_tag];
    }

    bool setPlayerClass( String @className )
    {
        bool success = false;

		cPlayerClass @oldClass = @this.playerClass;

        if ( @className != null )
        {
            for ( int i = 0; i < PLAYERCLASS_TOTAL; i++ )
            {
                if ( cPlayerClassInfos[i].name == className )
                {
                    @this.playerClass = @cPlayerClassInfos[i];
                    success = true;
                    break;
                }
            }
        }

        if ( !success && @this.playerClass == null ) // never be null
            @this.playerClass = @cPlayerClassInfos[PLAYERCLASS_GRUNT];

		if ( @oldClass != null )
		{
			// Destroy an Engineer's turret
			if ( oldClass.tag == PLAYERCLASS_ENGINEER && this.playerClass.tag != PLAYERCLASS_ENGINEER )
			{
				if ( @this.turret != null )
				{
					this.turret.die( null, null );
				}
			}
		}

        return success;
    }

    void setPlayerClassCommand( String &argsString )
    {
        String token = argsString.getToken( 0 );

        if ( token.len() == 0 )
        {
            this.printMessage( "Usage: class <name>\n" );
            return;
        }

        if ( this.ent.team < TEAM_PLAYERS )
        {
            this.printMessage( "You must join a team before selecting a class\n" );
            return;
        }

        if ( this.setPlayerClass( token ) == false )
        {
            this.printMessage( "Unknown playerClass '" + token + "'\n" );
            return;
        }

        if ( match.getState() < MATCH_STATE_COUNTDOWN )
            client.respawn( false );
        else
            this.printMessage( "You will respawn as " + token + "\n" );

        // set for respawning
        if ( match.getState() != MATCH_STATE_WARMUP )
        {
            if ( this.respawnTime <= levelTime )
            {
                this.respawnTime = levelTime + CTFT_RESPAWN_TIME;
                this.client.respawn( true );
                this.ent.spawnqueueAdd();
                this.client.chaseCam( null, true );
            }
        }
    }

    void checkRespawnQueue()
    {
        if ( this.respawnTime == 0 )
            return;

        if ( (this.respawnTime - 1000) > levelTime )
        {
            int respawn = ( this.respawnTime - levelTime ) / 1000;
            if ( respawn > 0 )
                G_CenterPrintMsg( this.ent, "Respawning in " + respawn + " seconds" );
        }
        else
        {
            this.respawnTime = 0;
            this.client.respawn( false );
			G_CenterPrintMsg( this.ent, "\n" );
        }
    }

    bool spawnReviver()
    {
        @this.reviver = null;

        // find a free reviver
        for ( int i = 0; i < maxClients; i++ )
        {
            if ( gtRevivers[i].inuse == false )
            {
                @this.reviver = @gtRevivers[i];
                break;
            }
        }

        if ( @this.reviver == null )
            return false;

        if ( !this.reviver.Spawn( this ) )
            @this.reviver = null;

        return ( @this.reviver != null ) ? true : false;
    }

    void removeReviver()
    {
        if ( @this.reviver != null )
            this.reviver.Free();

        @this.reviver = null;
    }

    void refreshChasecam()
    {
        if ( match.getState() != MATCH_STATE_PLAYTIME )
            return;

        if ( this.ent.team < TEAM_ALPHA || this.ent.team > TEAM_BETA )
            return;

        if ( !this.ent.isGhosting() )
            return;

        // if the player has a reviver switch in and out from chasecam
        if ( @this.reviver != null )
        {
            bool scanned = false;
            bool visible;

            if ( this.deadcamMedicScanTime < levelTime )
            {
                this.deadcamMedicScanTime = levelTime + 300;

                // find the closest medic in your team
                Team @team = @G_GetTeam( this.ent.team );
                if ( @team == null )
                    return;

                // check for medics in the team and compare distances
                cPlayer @otherPlayer;
                float distance, bestDistance;
                @this.deadcamMedic = null;
                bestDistance = 2048; // max distance
                for ( int i = 0; @team.ent( i ) != null; i++ )
                {
                    if ( @team.ent( i ).client == null )
                        continue;

                    @otherPlayer = @GetPlayer( team.ent( i ).client.playerNum );
                    if ( @otherPlayer == null )
                        continue;

                    if ( otherPlayer.ent.isGhosting() )
                        continue;

                    if ( otherPlayer.playerClass.tag != PLAYERCLASS_MEDIC )
                        continue;

                    distance = otherPlayer.ent.origin.distance( this.ent.origin );
                    if ( distance < bestDistance )
                    {
                        bestDistance = distance;
                        @this.deadcamMedic = @otherPlayer;
                    }
                }
            }

            if ( @this.deadcamMedic != null )
            {
                if ( this.client.chaseActive ) // exit chasecam
                {
                    //this.client.chaseTeamonly = false;
                    this.client.chaseActive = false;
                }

                Vec3 lookAngles, lookOrigin;
                visible = CTFT_LookAtEntity( this.reviver.ent.origin, Vec3(0.0), this.deadcamMedic.ent, this.ent.entNum, true, 72, 32, lookOrigin, lookAngles );

                this.ent.origin = lookOrigin;
                this.ent.origin2 = lookOrigin;
                this.ent.angles = lookAngles;
                this.ent.linkEntity();
                // look at the selected medic (if not already done)
                //if ( !scanned )
                //{
                //    visible = GENERIC_LookAtEntity( this.ent, lookOrigin, this.deadcamMedic.ent, true, 72, 24 );
                //}
            }
            else // if no medic available go back into chasecam
            {
                //Entity @chaseTarget = @G_GetEntity( this.client.chaseTarget );
                //if ( @chaseTarget != null && @chaseTarget.client != null )
                //    this.client.chaseCam( chaseTarget.client.name, true );
                //else
                //    this.client.chaseCam( null, true );
            }

            return;
        }

        @this.deadcamMedic = null;
    }

    void refreshModel()
    {
        // refresh player models
        if ( this.ent.isGhosting() )
        {
            this.ent.modelindex = 0;
        }
        else
        {
            this.ent.setupModel( this.playerClass.playerModel );

            if ( this.invisibilityEnabled )
            {
                this.ent.skinNum = G_SkinIndex( "models/players/silverclaw/invisibility.skin" );
            }
        }
    }

    void refreshMovement()
    {
        if ( this.ent.isGhosting() )
        {
            // restore defaults
            this.client.pmoveDashSpeed = -1;
            this.client.pmoveMaxSpeed = -1;
            this.client.pmoveJumpSpeed = -1;
        }
        else
        {
            // set class values
            this.client.pmoveDashSpeed = this.playerClass.dashSpeed;
            this.client.pmoveMaxSpeed = this.playerClass.maxSpeed;
            this.client.pmoveJumpSpeed = this.playerClass.jumpSpeed;
            this.ent.mass = 200;

            // grunt class is slower when wearing a warshell
            if ( this.playerClass.tag == PLAYERCLASS_GRUNT )
            {
                if ( this.client.inventoryCount( POWERUP_SHELL ) > 0 )
                {
                    this.client.pmoveMaxSpeed = this.playerClass.maxSpeed - 40;
                    this.ent.mass = 350;
                    this.client.pmoveFeatures = this.client.pmoveFeatures & ~(PMFEAT_WALLJUMP|PMFEAT_DASH);
                }
                else
                {
                    this.client.pmoveFeatures = this.client.pmoveFeatures | PMFEAT_WALLJUMP | PMFEAT_DASH;
                    this.ent.mass = 325;
                }
            }

            /* Needs latest bins */
            this.client.takeStun = this.playerClass.takeStun;
            if ( this.invisibilityEnabled )
            {
                this.client.selectWeapon( WEAP_NONE );
                this.client.pmoveFeatures = this.client.pmoveFeatures & ~PMFEAT_WEAPONSWITCH;
                this.ent.effects |= EF_PLAYER_HIDENAME;
            }
        }
    }

	void clearInfluence()
	{
		this.medicInfluence = 0.0f;
		this.supportInfluence = 0.0f;	
	}

	void refreshInfluenceEmission()
	{
		if ( this.ent.isGhosting() )
			return;

		if ( this.playerClass.tag == PLAYERCLASS_MEDIC )
		{
			if ( !this.isMedicCooldown() )
				refreshMedicInfluenceEmission();
		}		
		else if ( this.playerClass.tag == PLAYERCLASS_SUPPORT )
		{
			if ( !this.isSupportCooldown() )
				refreshSupportInfluenceEmission();
		}
	}

	void refreshMedicInfluenceEmission()
	{
		Trace trace;
		array<Entity @> @inradius = G_FindInRadius( this.ent.origin, CTFT_MEDIC_INFLUENCE_RADIUS );
		for ( uint i = 0; i < inradius.size(); ++i )
		{
			Entity @entity = inradius[i];
			if ( @entity.client == null || entity.client.state() < CS_SPAWNED || entity.isGhosting() )
                continue;

            if ( entity.team != this.ent.team || @entity == @this.ent )
                continue;
			
			if ( trace.doTrace( this.ent.origin, vec3Origin, vec3Origin, entity.origin, entity.entNum, MASK_SOLID ) )
				continue;

			float distance = this.ent.origin.distance( entity.origin );
			float influence = 1.0f - 0.5f * distance / CTFT_MEDIC_INFLUENCE_RADIUS;
			
			cPlayer @player = GetPlayer( entity.client );
			player.medicInfluence += influence;
			
			// Add score only when a player needs health
			if ( entity.health < entity.maxHealth )			
				this.medicInfluenceScore += 0.00035 * influence * frameTime;
		}
	}

	void refreshSupportInfluenceEmission()
	{
		Trace trace;
		array<Entity @> @inradius = G_FindInRadius( this.ent.origin, CTFT_SUPPORT_INFLUENCE_RADIUS );
		for ( uint i = 0; i < inradius.size(); ++i )
		{
			Entity @entity = inradius[i];
			if ( @entity.client == null || entity.client.state() < CS_SPAWNED || entity.isGhosting() )
                continue;

            if ( entity.team != this.ent.team || @entity == @this.ent )
                continue;

			if ( trace.doTrace( this.ent.origin, vec3Origin, vec3Origin, entity.origin, entity.entNum, MASK_SOLID ) )
				continue;

			float distance = this.ent.origin.distance( entity.origin );
			float influence = 1.0f - 0.5f * distance / CTFT_SUPPORT_INFLUENCE_RADIUS;
			
			cPlayer @player = GetPlayer( entity.client );
			player.supportInfluence += influence; 
			
			// Add score only when a player needs refilling armor
			if ( entity.client.armor < player.playerClass.maxArmor )			
				this.supportInfluenceScore += 0.00045 * influence * frameTime;
		}
	}

	void refreshInfluenceAbsorption()
	{
		if ( this.medicInfluence > 1.0f )
			this.medicInfluence = 1.0f;

		if ( this.supportInfluence > 1.0f )
			this.supportInfluence = 1.0f;

		if ( this.medicInfluence > 0 )
			this.ent.effects |= EF_REGEN;
		else
			this.ent.effects &= ~EF_REGEN;

		if ( this.supportInfluence > 0 )
			this.ent.effects |= EF_QUAD;
		else
			this.ent.effects &= ~EF_QUAD;
	}

    void refreshRegeneration()
    {
        if ( this.ent.isGhosting() )
            return;

		// First, check generic health/armor regeneration due to medic/support influence

		if ( this.medicInfluence > 0 )
		{
			if ( this.ent.health < this.ent.maxHealth )
				this.ent.health += ( frameTime * this.medicInfluence * 0.017f );
		}

		if ( this.supportInfluence > 0 )
		{
			if ( this.client.armor < this.playerClass.maxArmor )
				this.client.armor += ( frameTime * this.supportInfluence * 0.017f );
		}

		// Then, check class-specific regeneration
		
		if ( this.playerClass.tag == PLAYERCLASS_MEDIC )
		{
			// Medic regens health unless in cooldown
            if ( !this.isMedicCooldown() )
            {
                // Medic regens health
                if ( this.ent.health < 100 ) 
                    this.ent.health += ( frameTime * 0.019f );
            }
		}
		else if ( this.playerClass.tag == PLAYERCLASS_SUPPORT )
		{
			// The Support regen armor
			if ( !this.isSupportCooldown() )
			{
				int maxArmor = this.playerClass.maxArmor;
				if ( this.client.armor < ( maxArmor - 25 ) )
				{
					this.client.armor += ( frameTime * 0.012f );
				}
				else if ( ( this.client.armor >= ( maxArmor - 25 ) ) && this.client.armor < maxArmor )
				{
					this.client.armor += ( frameTime * 0.0032f );
				}
			}
		}
		else if ( this.playerClass.tag == PLAYERCLASS_SNIPER )
		{
			// if carrying the flag, disable invisibility
            if ( ( this.ent.effects & EF_CARRIER ) != 0 )
                this.deactivateInvisibility();

            if ( this.isInvisibilityCooldown() )
                this.deactivateInvisibility();

            // load or unload visibility
            if ( this.invisibilityEnabled )
            {
                this.invisibilityLoad -= ( frameTime * 0.012f );
                if ( this.invisibilityLoad < 0 )
                {
                    this.invisibilityLoad = 0;
                    if ( this.invisibilityEnabled )
                        this.deactivateInvisibility();
                }
            }
            else
            {
                this.invisibilityLoad += ( frameTime * 0.006f );
                if ( this.invisibilityLoad > CTFT_SNIPER_INVISIBILITY_MAXLOAD )
                    this.invisibilityLoad = CTFT_SNIPER_INVISIBILITY_MAXLOAD;
            }
		}

		// Drain health/armor if if exceeds a class limit

		if ( this.ent.health > this.ent.maxHealth )
		{
        	this.ent.health -= ( frameTime * 0.006f );
			// fix possible rounding errors
			if( this.ent.health < this.ent.maxHealth )
				this.ent.health = this.ent.maxHealth;
		}

		if ( this.client.armor > this.playerClass.maxArmor ) 
		{
	    	this.client.armor -= ( frameTime * 0.004f );
			// fix possible rounding errors			
			if ( this.client.armor < this.playerClass.maxArmor ) 
				this.client.armor = this.playerClass.maxArmor;
		}
    }

    void tookDamage ( int attackerNum, float damage )
    {
        if ( this.playerClass.tag == PLAYERCLASS_GRUNT )
        {
            this.setGruntCooldown();
        }	
        else if ( this.playerClass.tag == PLAYERCLASS_MEDIC )
        {
            this.setMedicCooldown();
        }
        else if ( this.playerClass.tag == PLAYERCLASS_SNIPER )
        {
            this.setInvisibilityCooldown();
        }
		else if ( this.playerClass.tag == PLAYERCLASS_SUPPORT )
		{
			this.setSupportCooldown();
		}
    }

    void setMedicCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
            return;

        this.medicCooldownTime = levelTime + CTFT_MEDIC_COOLDOWN;
    }

    bool isMedicCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
            return false;

        return ( this.medicCooldownTime > levelTime ) ? true : false;
    }

    int medicCooldownTimeLeft()
    {
        if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
            return 0;

        if ( this.medicCooldownTime <= levelTime )
            return 0;

        return int( levelTime - this.medicCooldownTime );
    }
	
    void setGruntCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_GRUNT )
            return;

        this.gruntCooldownTime = levelTime + CTFT_GRUNT_COOLDOWN;
    }

    bool isGruntCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_GRUNT )
            return false;

        return ( this.gruntCooldownTime > levelTime ) ? true : false;
    }

    int gruntCooldownTimeLeft()
    {
        if ( this.playerClass.tag != PLAYERCLASS_GRUNT )
            return 0;

        if ( this.gruntCooldownTime <= levelTime )
            return 0;

        return int( levelTime - this.gruntCooldownTime );
    }	
	
	bool isSupportCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return false;

		return ( this.supportCooldownTime > levelTime ) ? true : false;
	}

	void setSupportCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_GRUNT )
			return;

		this.supportCooldownTime = levelTime + CTFT_SUPPORT_COOLDOWN;
	}

	int supportCooldownTimeLeft()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return 0;
		
		if ( this.supportCooldownTime <= levelTime )
			return 0;

		return int( levelTime - this.supportCooldownTime );
	}
   
    void setInvisibilityCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_SNIPER )
            return;

        this.invisibilityCooldownTime = levelTime + CTFT_INVISIBILITY_COOLDOWN;
    }

    bool isInvisibilityCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_SNIPER )
            return false;

        return ( this.invisibilityCooldownTime > levelTime ) ? true : false;
    }

    void setEngineerCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_ENGINEER )
            return;

        this.engineerBuildCooldownTime = levelTime + CTFT_ENGINEER_BUILD_COOLDOWN_TIME;
    }

    bool isEngineerCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_ENGINEER )
            return false;

        return ( engineerBuildCooldownTime > levelTime ) ? true : false;
    }

    int engineerCooldownTimeLeft()
    {
        if ( this.playerClass.tag != PLAYERCLASS_ENGINEER )
            return 0;

        if ( this.engineerBuildCooldownTime <= levelTime )
            return 0;

        return int( this.engineerBuildCooldownTime - levelTime );
    }

    void setBombCooldown()
    {
        this.bombCooldownTime = levelTime + CTFT_BOMB_COOLDOWN;
    }

    bool isBombCooldown()
    {
        return ( this.bombCooldownTime > levelTime ) ? true : false;
    }

    int bombCooldownTimeLeft()
    {
        if ( this.bombCooldownTime <= levelTime )
            return 0;

        return int( this.bombCooldownTime - levelTime );
    }

    void setShellCooldown( int baseTime )
    {
        this.shellCooldownTime = levelTime + CTFT_SHELL_COOLDOWN + baseTime;
    }

    bool isShellCooldown()
    {
        return ( this.shellCooldownTime > levelTime ) ? true : false;
    }

    int shellCooldownTimeLeft()
    {
        if ( this.shellCooldownTime <= levelTime )
            return 0;

        return int( this.shellCooldownTime - levelTime );
    }

    void activateInvisibility()
    {
        if ( this.ent.isGhosting() )
            return;

        if ( this.invisibilityEnabled )
        {
            this.deactivateInvisibility();
            return;
        }

        if ( this.isInvisibilityCooldown() )
            return;

        if ( ( this.ent.effects & EF_CARRIER ) != 0 )
        {
            this.printMessage( "Cannot use the skill now\n" );
            return;
        }

        if ( this.client.inventoryCount( POWERUP_SHELL ) > 0 )
        {
            this.printMessage( "Cannot use the skill now\n" );
            return;
        }

        if ( this.invisibilityLoad < CTFT_SNIPER_INVISIBILITY_MINLOAD )
        {
            this.printMessage( "Cannot use the skill yet\n" );
            return;
        }

        this.invisibilityEnabled = true;
        this.invisibilityWasUsingWeapon = this.ent.weapon;
        this.client.selectWeapon( WEAP_NONE );
        this.ent.effects |= EF_PLAYER_HIDENAME;


        this.ent.respawnEffect();

        // change me to something special? Like...
        //G_Sound( this.ent, CHAN_MUZZLEFLASH, G_SoundIndex( "sounds/world/tele_in" ), 0.3f );
    }

    void deactivateInvisibility()
    {
        if ( this.ent.isGhosting() )
            return;

        if ( !this.invisibilityEnabled )
            return;

        this.invisibilityEnabled = false;

        this.client.selectWeapon( this.invisibilityWasUsingWeapon );
        this.client.pmoveFeatures = this.client.pmoveFeatures | PMFEAT_WEAPONSWITCH;
        this.ent.effects &= ~EF_PLAYER_HIDENAME;

        this.ent.respawnEffect();

        // change me to something special? Like...
        //G_Sound( client.getEnt(), CHAN_MUZZLEFLASH, G_SoundIndex( "sounds/world/tele_in" ), 0.3f );
    }

    void activateShell()
    {
        if ( this.ent.isGhosting() )
            return;

        if ( this.isShellCooldown() )
        {
            this.printMessage( "Cannot use the skill yet\n" );
            return;
        }

        if ( this.client.armor < CTFT_BATTLESUIT_AP_COST )
        {
            this.printMessage( "You don't have enough armor to spawn battlesuit\n" );
        }
        else
        {
            this.client.armor -= CTFT_TURRET_AP_COST;

            if ( this.playerClass.tag == PLAYERCLASS_GRUNT )
            {
                this.client.inventorySetCount( POWERUP_SHELL, CTFT_BATTLESUIT_GRUNT_TIME );
                this.setShellCooldown( CTFT_BATTLESUIT_GRUNT_TIME * 1000 );
            }
            else
            {
                this.client.inventorySetCount( POWERUP_SHELL, CTFT_BATTLESUIT_GRUNT_TIME );
                this.setShellCooldown( CTFT_BATTLESUIT_RUNNER_TIME * 1000 );
            }

            G_Sound( this.ent, CHAN_MUZZLEFLASH, G_SoundIndex( "sounds/items/shell_spawn" ), 0.3f );
        }
    }

    void watchShell()
    {
        if ( this.ent.isGhosting() )
            return;

        if ( this.client.inventoryCount( POWERUP_SHELL ) > 0 )
        {
            if ( this.client.inventoryCount( POWERUP_SHELL ) == 1 )
                G_CenterPrintMsg( this.ent, "Protection weared off" );
            else
                G_CenterPrintMsg( this.ent, "Warshell wearing off in " + this.client.inventoryCount( POWERUP_SHELL ) + " seconds" );
        }
    }
}

cPlayer @GetPlayer( Client @client )
{
    if ( @client == null )
        return null;

    if ( client.playerNum < 0 || client.playerNum >= maxClients )
        return null;

    return @gtPlayers[ client.playerNum ];
}

cPlayer @GetPlayer( int i )
{
    if ( i < 0 || i >= maxClients )
        return null;

    return @gtPlayers[ i ];
}

void InitPlayers()
{
    GENERIC_InitPlayerClasses();

    // autoassign to each object in the array it's equivalent client.
    for ( int i = 0; i < maxClients; i++ )
    {
        @gtPlayers[ i ].client = @G_GetClient( i );
        @gtPlayers[ i ].ent = @G_GetEntity( i + 1 );
    }
}
