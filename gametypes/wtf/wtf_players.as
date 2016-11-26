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
	cBouncePad @bouncePad;   
    cBomb @bomb;
	cTranslocator @translocator;

    uint medicRegenCooldownTime;
	uint gruntAbilityCooldownTime;
	uint supportRegenCooldownTime;
    uint engineerBuildCooldownTime;
	uint blastCooldownTime;    
	uint runnerAbilityCooldownTime;
	uint flagDispenserCooldownTime;
	uint adrenalineTime;
    uint respawnTime;
	bool isHealingTeammates;
	bool hasReceivedAmmo;
	bool hasReceivedAdrenaline;
	bool hasPendingSupplyAmmoCommand;
	bool hasPendingSupplyAdrenalineCommand;
	bool isTranslocating;     // A player entity is on its old origin and a teleport effect is shown
	bool hasJustTranslocated; // A player entity is on its new origin and a teleport effect is shown
	Vec3 translocationOrigin; // A translocator can be killed while translocation, so we save destination origin 
	float medicInfluence;
	float supportInfluence;
	float adrenalineBaseSpeedBoost;
	float adrenalineDashSpeedBoost;
    bool invisibilityEnabled;
    float invisibilityLoad;
    int invisibilityWasUsingWeapon;
    uint invisibilityCooldownTime;
    uint hudMessageTimeout;
	uint nextTipDescriptionLine;
	uint nextTipTime;

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
		@this.bouncePad = null;
        @this.bomb = null;
		@this.translocator = null;
        this.resetTimers();
		
		this.medicInfluenceScore = 0.0;
		this.supportInfluenceScore = 0.0;
    }

    ~cPlayer() {}

    void resetTimers()
    {
        this.medicRegenCooldownTime = 0;
		this.gruntAbilityCooldownTime = 0;
		this.supportRegenCooldownTime = 0;
        this.engineerBuildCooldownTime = 0;
   		this.blastCooldownTime = 0;
		this.runnerAbilityCooldownTime = 0;
		this.flagDispenserCooldownTime = 0;
		this.adrenalineTime = 0;
        this.respawnTime = 0;
		this.isHealingTeammates = false;
		this.hasReceivedAmmo = false;
		this.hasReceivedAdrenaline = false;
		this.hasPendingSupplyAmmoCommand = false;
		this.hasPendingSupplyAdrenalineCommand = false;
		this.isTranslocating = false;
		this.hasJustTranslocated = false;
		this.medicInfluence = 0.0f;
		this.supportInfluence = 0.0f;
		this.adrenalineBaseSpeedBoost = 0.0f;
		this.adrenalineDashSpeedBoost = 0.0f;
        this.invisibilityEnabled = false;
        this.invisibilityLoad = 0;
        this.invisibilityCooldownTime = 0;
        this.hudMessageTimeout = 0;
		this.nextTipDescriptionLine = 0;
		this.nextTipTime = 0;
        this.deadcamMedicScanTime = 0;

        this.invisibilityWasUsingWeapon = -1;
    }

    void printMessage( String &string )
    {
        this.client.printMessage( string );
    }

	// Should be used for printing important messages. Defers next tip (if any).
	void centerPrintMessage( String &string )
	{
		G_CenterPrintMsg( this.ent, string );
		if ( this.nextTipTime >= levelTime && levelTime - this.nextTipTime < 2500 )
			this.nextTipTime = levelTime + 2500;
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

        if ( this.isEngineerBuildCooldown() )
        {
            frac = float( this.engineerBuildCooldownTimeLeft() ) / float( CTFT_ENGINEER_BUILD_COOLDOWN_TIME );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

        if ( this.isGruntAbilityCooldown() )
        {
            frac = float( this.gruntAbilityCooldownTimeLeft() ) / float( CTFT_GRUNT_ABILITY_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

		if ( this.isMedicRegenCooldown() )
        {
            frac = float( this.medicRegenCooldownTimeLeft() ) / float( CTFT_MEDIC_REGEN_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

		if ( this.isSupportRegenCooldown() )
        {
            frac = float( this.supportCooldownTimeLeft() ) / float( CTFT_SUPPORT_REGEN_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

		if ( this.isBlastCooldown() )
		{
			frac = float( this.blastCooldownTimeLeft() ) / float( CTFT_BLAST_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_OTHER, int( frac * 100 ) );
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
			// Destroy entities build by an engineer
			if ( oldClass.tag == PLAYERCLASS_ENGINEER && this.playerClass.tag != PLAYERCLASS_ENGINEER )
			{
				if ( @this.turret != null )
					this.turret.die( null, null );

				if ( @this.bouncePad != null )
					this.bouncePad.die( null, null );
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
                this.respawnTime = levelTime + CTFT_BASE_RESPAWN_TIME;
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

                // find the closest medic in any team
                cPlayer @otherPlayer;
                float distance, bestDistance;
                @this.deadcamMedic = null;
                bestDistance = 2048; // max distance
                for ( int i = 0; i < maxClients; i++ )
                {
					Client @otherClient = @G_GetClient( i );
					if ( @otherClient == null || otherClient.state() < CS_SPAWNED )
						continue;
		
					if ( otherClient.team < TEAM_ALPHA || otherClient.getEnt().isGhosting() )
						continue;

                    @otherPlayer = @GetPlayer( client );

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
			// Player models differ and clients apply fullbright skins only if they can override a model first.
			// Thus forcing fullbright models on the server side is the only option, isn't it?
			if ( wtfForceFullbrightSkins.boolean )
				this.ent.setupModel( this.playerClass.playerModel, "fullbright" );
			else
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
			if ( this.isTranslocating )
			{
				this.ent.respawnEffect();
				G_Sound( this.ent, CHAN_MUZZLEFLASH, G_SoundIndex( "sounds/world/tele_in" ), 0.4f );

				this.isTranslocating = false;
				this.hasJustTranslocated = true;
				return;
			}

			if ( this.hasJustTranslocated )
			{
				if ( ( this.ent.effects & EF_CARRIER ) != 0 )			
					CTF_PlayerDropFlag( this.ent, false );

				this.ent.unlinkEntity();

				Vec3 originOffset( 0, 0, translocatorMins.z - playerBoxMins.z + 1.0f );
				// translocator might have been pushed away during a frame,
				// so use the stored translocation origin only if there is not translocator.
				// (we have to show a player teleportation anyway, thats why we always modify player's origin).
				if ( @this.translocator != null )
					this.ent.origin = this.translocator.bodyEnt.origin + originOffset;
				else
					this.ent.origin = this.translocationOrigin + originOffset;			

				this.ent.respawnEffect();
				G_Sound( this.ent, CHAN_MUZZLEFLASH, G_SoundIndex( "sounds/world/tele_in" ), 0.4f );

				// if the translocator has been killed during translocation
				if ( @this.translocator == null )
				{
					this.centerPrintMessage( S_COLOR_RED + "Your translocator was destroyed!\n" );
					this.ent.linkEntity();
					// kill player
					this.ent.sustainDamage( null, null, Vec3( 0, 0, 1 ), 9999.0f, 50.0f, 1000.0f, 0 );
				}
				// if the translocator is damaged	
				else if ( this.translocator.bodyEnt.health < CTFT_TRANSLOCATOR_HEALTH )
				{
					this.centerPrintMessage( S_COLOR_RED + "Your translocator was damaged!\n" );
					this.ent.linkEntity();
					// kill player
					this.ent.sustainDamage( null, null, Vec3( 0, 0, 1 ), 9999.0f, 50.0f, 1000.0f, 0 );
					this.translocator.Free();
				}
				else
				{
					array<Entity @> @telefraggableEntities = @this.translocator.getPlayerBoxTelefraggableEntities();
					// looks like the destination is in solid					
					if ( @telefraggableEntities == null )
					{
						this.returnTranslocator();
					}
					else
					{
						// kill all entities that should be telefragged
						for ( uint i = 0; i < telefraggableEntities.size(); ++i )
						{
							Entity @ent = telefraggableEntities[i];
							ent.sustainDamage( this.ent, this.ent, Vec3( 0, 0, 1 ), 9999.0f, 50.0f, 1000.0f, 0 ); 
						}
						this.translocator.Free();
					}
					this.ent.linkEntity();
				}

				this.hasJustTranslocated = false;
				return;
			}

            this.client.pmoveDashSpeed = this.playerClass.dashSpeed;
            this.client.pmoveJumpSpeed = this.playerClass.jumpSpeed;

			// No adrenaline (the most common case)
			if ( this.adrenalineTime <= levelTime )
			{
				// Apply the hack described in classes definition
				if ( @this.ent.groundEntity == null )
					this.client.pmoveMaxSpeed = this.playerClass.pmoveMaxSpeedInAir;
				else
					this.client.pmoveMaxSpeed = this.playerClass.pmoveMaxSpeedOnGround;
			}
			else
			{
				// Choose the best speed and add some bonus value
				if ( this.playerClass.pmoveMaxSpeedInAir < this.playerClass.pmoveMaxSpeedOnGround )
					this.client.pmoveMaxSpeed = this.playerClass.pmoveMaxSpeedOnGround + 20;
				else
					this.client.pmoveMaxSpeed = this.playerClass.pmoveMaxSpeedInAir + 20;
			}

			this.ent.mass = 200;

            // there used to be a grunt Warshell slowdown code
			// the Grunt is very slow anyway, do not make him even slower
            if ( this.playerClass.tag == PLAYERCLASS_GRUNT )
                this.ent.mass = 325;

            /* Needs latest bins */
            this.client.takeStun = this.playerClass.takeStun;
            if ( this.invisibilityEnabled )
            {
                this.client.selectWeapon( WEAP_NONE );
                this.client.pmoveFeatures = this.client.pmoveFeatures & ~PMFEAT_WEAPONSWITCH;
            }
        }
    }

	void clearInfluence()
	{
		this.medicInfluence = 0.0f;
		this.supportInfluence = 0.0f;
		this.isHealingTeammates = false;
		this.hasReceivedAmmo = false;
		this.hasReceivedAdrenaline = false;
	}

	void refreshInfluenceEmission()
	{
		if ( this.ent.isGhosting() )
			return;

		if ( this.playerClass.tag == PLAYERCLASS_MEDIC )
		{
			if ( !this.isMedicRegenCooldown() )
				refreshMedicInfluenceEmission();
		}		
		else if ( this.playerClass.tag == PLAYERCLASS_SUPPORT )
		{
			if ( !this.isSupportRegenCooldown() )
				refreshSupportInfluenceEmission();
		}
	}

	void refreshMedicInfluenceEmission()
	{
		float radius = CTFT_MEDIC_INFLUENCE_BASE_RADIUS;
		float speed = this.ent.velocity.length();
		if ( speed > this.playerClass.dashSpeed )
			radius += 0.75f * ( speed - this.playerClass.dashSpeed );

		Trace trace;
		int numAffectedTeammates = 0;
		array<Entity @> @inradius = G_FindInRadius( this.ent.origin, radius );
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
			float influence = 1.0f - 0.3f * distance / radius;
			
			cPlayer @player = GetPlayer( entity.client );
			player.medicInfluence += influence;

			// Add score only when a player needs health
			if ( entity.health < entity.maxHealth )
			{
				this.isHealingTeammates = true;
				this.medicInfluenceScore += 0.00035 * influence * frameTime;
			}

			player.hasReceivedAdrenaline = this.hasPendingSupplyAdrenalineCommand;
		}

		if ( this.hasPendingSupplyAdrenalineCommand )
		{
			if ( numAffectedTeammates > 0 )
				this.client.stats.addScore( numAffectedTeammates );

			// Give some adrenaline itself
			this.hasReceivedAdrenaline = true;
			// Reset this later to skip printing a message to itself
			// this.hasPendingSupplyAdrenalineCommand = false;
		}
	}

	void refreshSupportInfluenceEmission()
	{
		float radius = CTFT_SUPPORT_INFLUENCE_BASE_RADIUS;
		float speed = this.ent.velocity.length();
		if ( speed > this.playerClass.dashSpeed )
			radius += 0.75f * ( speed - this.playerClass.dashSpeed );

		Trace trace;
		int numAffectedTeammates = 0;
		array<Entity @> @inradius = G_FindInRadius( this.ent.origin, radius );
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
			float influence = 1.0f - 0.3f * distance / radius;
			
			cPlayer @player = GetPlayer( entity.client );
			player.supportInfluence += influence; 
			numAffectedTeammates++;

			// Add score only when a player needs refilling armor
			if ( entity.client.armor < player.playerClass.maxArmor )
			{
				this.isHealingTeammates = true;
				this.supportInfluenceScore += 0.00045 * influence * frameTime;
			}

			player.hasReceivedAmmo = this.hasPendingSupplyAmmoCommand;
		}

		if ( this.hasPendingSupplyAmmoCommand )
		{
			// Some teammates might have already full load of ammo but we don't care
			if ( numAffectedTeammates > 0 )
				this.client.stats.addScore( numAffectedTeammates );

			// Give some ammo itself
			this.hasReceivedAmmo = true;
			// Reset this later to skip printing a message to itself
			// this.hasPendingSupplyAmmoCommand = false;
		}
	}

	void refreshInfluenceAbsorption()
	{
		if ( this.medicInfluence > 1.0f )
			this.medicInfluence = 1.0f;

		if ( this.supportInfluence > 1.0f )
			this.supportInfluence = 1.0f;

		if ( this.medicInfluence > 0 && ( this.ent.effects & EF_PLAYER_HIDENAME ) == 0 )
			this.ent.effects |= EF_REGEN;
		else
			this.ent.effects &= ~EF_REGEN;

		if ( this.supportInfluence > 0 && ( this.ent.effects & EF_PLAYER_HIDENAME ) == 0 )
			this.ent.effects |= EF_QUAD;
		else
			this.ent.effects &= ~EF_QUAD;

		if ( this.hasReceivedAmmo )
		{
			this.loadAmmo();
			// loadAmmo() does not play this sound because it might be confusing on respawn when it is called too			
			G_Sound( this.ent, CHAN_AUTO, G_SoundIndex( "sounds/items/weapon_pickup" ), 0.4f );
			this.hasReceivedAmmo = false;

			if ( !this.hasPendingSupplyAmmoCommand )
				this.centerPrintMessage( S_COLOR_CYAN + "A teammate gave you some ammo!\n" );
		}

		if ( this.hasReceivedAdrenaline )
		{
			this.adrenalineTime = levelTime + 1750;
			this.ent.health += 50;
			G_Sound( this.ent, CHAN_AUTO, G_SoundIndex( "sounds/items/regen_pickup" ), 0.4f );					
			this.hasReceivedAdrenaline = false;

			if ( !this.hasPendingSupplyAdrenalineCommand )
				this.centerPrintMessage( S_COLOR_MAGENTA + "You gained some adrenaline! Be quick!\n" );
		}

		this.hasPendingSupplyAmmoCommand = false;
		this.hasPendingSupplyAdrenalineCommand = false;
	}

    void refreshRegeneration()
    {
        if ( this.ent.isGhosting() )
            return;

		// First, check generic health/armor regeneration due to medic/support influence

		if ( this.medicInfluence > 0 )
		{
			if ( this.ent.health < this.ent.maxHealth )
				this.ent.health += ( frameTime * this.medicInfluence * 0.021f );
		}

		if ( this.supportInfluence > 0 )
		{
			if ( this.client.armor < this.playerClass.maxArmor )
				this.client.armor += ( frameTime * this.supportInfluence * 0.019f );
		}

		// Then, check class-specific regeneration
		
		if ( this.playerClass.tag == PLAYERCLASS_MEDIC )
		{
			// Medic regens health unless in cooldown
            if ( !this.isMedicRegenCooldown() )
            {
                // Medic regens health
                if ( this.ent.health < 100 ) 
				{
					float healthGain = 0.0f;
					if ( this.isHealingTeammates )
						healthGain = frameTime * 0.006f;
					else          	
						healthGain = frameTime * 0.019f;

					if ( ( this.ent.effects & EF_CARRIER ) != 0 )
						healthGain *= 0.55f;

					this.ent.health += healthGain;		
				}
            }
		}
		else if ( this.playerClass.tag == PLAYERCLASS_SUPPORT )
		{
			// The Support regen armor
			if ( !this.isSupportRegenCooldown() )
			{
				int maxArmor = this.playerClass.maxArmor;
				float armorGain = 0.0f;
				if ( this.client.armor < ( maxArmor / 3.0f ) )
				{
					if ( this.isHealingTeammates )
						armorGain = frameTime * 0.005f;
					else
						armorGain = frameTime * 0.010f;
				}
				else if ( this.client.armor < 2 * ( maxArmor / 3.0f ) )
				{
					if ( this.isHealingTeammates )
						armorGain = frameTime * 0.0035f;
					else
						armorGain = frameTime * 0.0045f;
				}
				else if ( this.client.armor < maxArmor )
				{
					if ( this.isHealingTeammates )
						armorGain = frameTime * 0.0012f;
					else
						armorGain = frameTime * 0.0021f;
				}

				if ( ( this.ent.effects & EF_CARRIER ) != 0 )
					armorGain *= 0.55f;

				this.client.armor += armorGain;
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
                this.invisibilityLoad -= ( frameTime * 0.055f );
                if ( this.invisibilityLoad < 0 )
                {
                    this.invisibilityLoad = 0;
                    if ( this.invisibilityEnabled )
                        this.deactivateInvisibility();
                }
            }
            else
            {
                this.invisibilityLoad += ( frameTime * 0.033f );
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
        if ( this.playerClass.tag == PLAYERCLASS_MEDIC )
        {
            this.setMedicRegenCooldown();
        }
        else if ( this.playerClass.tag == PLAYERCLASS_SNIPER )
        {
            this.setInvisibilityCooldown();
        }
		else if ( this.playerClass.tag == PLAYERCLASS_SUPPORT )
		{
			this.setSupportRegenCooldown();
		}
    }

    void setMedicRegenCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
            return;

        this.medicRegenCooldownTime = levelTime + CTFT_MEDIC_REGEN_COOLDOWN;
    }

    bool isMedicRegenCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
            return false;

        return ( this.medicRegenCooldownTime > levelTime ) ? true : false;
    }

    int medicRegenCooldownTimeLeft()
    {
        if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
            return 0;

        if ( this.medicRegenCooldownTime <= levelTime )
            return 0;

        return int( levelTime - this.medicRegenCooldownTime );
    }
	
	bool isSupportRegenCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return false;

		return ( this.supportRegenCooldownTime > levelTime ) ? true : false;
	}

	void setSupportRegenCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return;

		this.supportRegenCooldownTime = levelTime + CTFT_SUPPORT_REGEN_COOLDOWN;
	}

	int supportCooldownTimeLeft()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return 0;
		
		if ( this.supportRegenCooldownTime <= levelTime )
			return 0;

		return int( levelTime - this.supportRegenCooldownTime );
	}

	bool isBlastCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return false;

		return ( this.blastCooldownTime > levelTime ) ? true : false;
	}

	void setBlastCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return;

		this.blastCooldownTime = levelTime + CTFT_BLAST_COOLDOWN;
	}

	int blastCooldownTimeLeft()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return 0;
		
		if ( this.blastCooldownTime <= levelTime )
			return 0;

		return int( levelTime - this.blastCooldownTime );
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

    void setEngineerBuildCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_ENGINEER )
            return;

        this.engineerBuildCooldownTime = levelTime + CTFT_ENGINEER_BUILD_COOLDOWN_TIME;
    }

    bool isEngineerBuildCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_ENGINEER )
            return false;

        return ( engineerBuildCooldownTime > levelTime ) ? true : false;
    }

    int engineerBuildCooldownTimeLeft()
    {
        if ( this.playerClass.tag != PLAYERCLASS_ENGINEER )
            return 0;

        if ( this.engineerBuildCooldownTime <= levelTime )
            return 0;

        return int( this.engineerBuildCooldownTime - levelTime );
    }

	void setRunnerAbilityCooldown()
	{
		this.runnerAbilityCooldownTime = levelTime + CTFT_RUNNER_ABILITY_COOLDOWN;
	}

	bool isRunnerAbilityCooldown()
	{
		return this.runnerAbilityCooldownTime > levelTime;
	}

	int runnerCooldownTimeLeft()
    {
        if ( this.runnerAbilityCooldownTime <= levelTime )
            return 0;

        return int( this.runnerAbilityCooldownTime - levelTime );
    }

    void setGruntAbilityCooldown()
    {
        this.gruntAbilityCooldownTime = levelTime + CTFT_GRUNT_ABILITY_COOLDOWN;
    }

    bool isGruntAbilityCooldown()
    {
        return ( this.gruntAbilityCooldownTime > levelTime ) ? true : false;
    }

    int gruntAbilityCooldownTimeLeft()
    {
        if ( this.gruntAbilityCooldownTime <= levelTime )
            return 0;

        return int( this.gruntAbilityCooldownTime - levelTime );
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
	
		if ( this.playerClass.tag != PLAYERCLASS_GRUNT )
		{
			this.printMessage( "This ability is not available for your class\n" );
			return;
		}

        if ( this.isGruntAbilityCooldown() )
        {
            this.printMessage( "Cannot activate shell yet\n" );
            return;
        }

		// Costs same as a cluster grenade
        if ( this.client.armor < CTFT_CLUSTER_GRENADE_AP_COST )
        {
            this.printMessage( "You don't have enough armor to activate a shell\n" );
        }
        else
        {
            this.client.armor -= CTFT_CLUSTER_GRENADE_AP_COST;
            this.client.inventorySetCount( POWERUP_SHELL, 4 );
            this.setGruntAbilityCooldown();

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
                this.centerPrintMessage( "Protection weared off" );
            else
                this.centerPrintMessage( "Warshell wearing off in " + this.client.inventoryCount( POWERUP_SHELL ) + " seconds" );
        }
    }

	void checkAndLoadAmmo( int ammoTag, int minCount )
	{
		if ( client.inventoryCount( ammoTag ) < minCount )
			client.inventorySetCount( ammoTag, minCount );
	}

	void loadAmmo( bool fullLoad = true )
	{
		if ( this.playerClass.tag == PLAYERCLASS_RUNNER )
		{
		    // Enable gunblade blast
			client.inventorySetCount( AMMO_GUNBLADE, 1 );
			if ( fullLoad )
			{
				client.inventorySetCount( AMMO_ROCKETS, 9 );
				client.inventorySetCount( AMMO_SHELLS, 9 );
			}
			else
			{
				this.checkAndLoadAmmo( AMMO_ROCKETS, 5 );
				this.checkAndLoadAmmo( AMMO_SHELLS, 5 );
			}
		}
		else if ( this.playerClass.tag == PLAYERCLASS_MEDIC )
		{
		   	// Enable gunblade blast
			client.inventorySetCount( AMMO_GUNBLADE, 1 );
			if ( fullLoad )
			{
		    	client.inventorySetCount( AMMO_PLASMA, 100 );
				client.inventorySetCount( AMMO_BULLETS, 150 );
				client.inventorySetCount( AMMO_GRENADES, 10 );
			}
			else
			{
				this.checkAndLoadAmmo( AMMO_PLASMA, 50 );
				this.checkAndLoadAmmo( AMMO_BULLETS, 100 );
				this.checkAndLoadAmmo( AMMO_GRENADES, 5 );
			}
		}
		else if ( this.playerClass.tag == PLAYERCLASS_GRUNT )
		{
			if ( fullLoad )
			{
		    	client.inventorySetCount( AMMO_ROCKETS, 15 );
				client.inventorySetCount( AMMO_LASERS, 100 );
				client.inventorySetCount( AMMO_GRENADES, 15 );
			}
			else
			{
				this.checkAndLoadAmmo( AMMO_ROCKETS, 7 );
				this.checkAndLoadAmmo( AMMO_LASERS, 75 );
				this.checkAndLoadAmmo( AMMO_GRENADES, 7 );
			}
		}
		else if ( this.playerClass.tag == PLAYERCLASS_ENGINEER )
		{
			if ( fullLoad )
			{
				client.inventorySetCount( AMMO_ROCKETS, 5 );
				client.inventorySetCount( AMMO_PLASMA, 125 );
				client.inventorySetCount( AMMO_SHELLS, 15 );
			}
			else
			{
				this.checkAndLoadAmmo( AMMO_ROCKETS, 3 );
				this.checkAndLoadAmmo( AMMO_PLASMA, 75 );
				this.checkAndLoadAmmo( AMMO_SHELLS, 7 );
			}
		}
		else if ( this.playerClass.tag == PLAYERCLASS_SUPPORT )
		{
			// Enable gunblade blast
			client.inventorySetCount( AMMO_GUNBLADE, 1 );
			if ( fullLoad )
			{
				client.inventorySetCount( AMMO_LASERS, 100 );
				client.inventorySetCount( AMMO_SHELLS, 15 );
			}
			else
			{
				this.checkAndLoadAmmo( AMMO_LASERS, 50 );
				this.checkAndLoadAmmo( AMMO_SHELLS, 7 );
			}
		}
		else if ( this.playerClass.tag == PLAYERCLASS_SNIPER )
		{
			if ( fullLoad )
			{
				client.inventorySetCount( AMMO_BOLTS, 13 );
				client.inventorySetCount( AMMO_BULLETS, 125 );
			}
			else
			{
				this.checkAndLoadAmmo( AMMO_BOLTS, 7 );
				this.checkAndLoadAmmo( AMMO_BULLETS, 75 );
			}
		}
	}

	void throwTranslocator()
	{
		if ( this.playerClass.tag != PLAYERCLASS_RUNNER )
		{
			client.printMessage( "This action is not available for your class\n" );
			return;
		}

		if ( this.isTranslocating || this.hasJustTranslocated )
			return;

		if ( @this.translocator != null )
		{
			// Perform an auto-return
			if ( !this.isRunnerAbilityCooldown() )
			{
				this.returnTranslocator();
			}
			else
			{
				client.printMessage( "You cannot throw another translocator yet\n" );
				return;
			}
		}

		if ( client.armor < CTFT_TRANSLOCATOR_AP_COST )
		{
			client.printMessage( "You do not have enough armor to throw a translocator\n" );
			return;
		}

		@this.translocator = @ClientThrowTranslocator( client );
		if ( @this.translocator == null )
			return;
		
		client.armor -= CTFT_TRANSLOCATOR_AP_COST;
		this.setRunnerAbilityCooldown();
		
		G_Sound( this.ent, CHAN_MUZZLEFLASH, G_SoundIndex( "sounds/weapons/grenlaunch_strong" ), 0.4f );
	}

	void checkTranslocator()
	{
		if ( this.playerClass.tag != PLAYERCLASS_RUNNER )
		{
			client.printMessage( "This action is not available for your class\n" );
			return;
		}

		if ( this.isTranslocating || this.hasJustTranslocated )
			return;

		if ( @this.translocator == null )
			return;

		if ( this.translocator.bodyEnt.health < CTFT_TRANSLOCATOR_HEALTH )
		{
			client.printMessage( S_COLOR_YELLOW + "Your translocator was damaged!\n" );
			this.returnTranslocator();
			return;
		}

		if ( @this.translocator.getPlayerBoxTelefraggableEntities() == null )
		{
			this.returnTranslocator();
			return;
		}

		G_LocalSound( this.client, CHAN_AUTO, G_SoundIndex( "sounds/menu/ok" ) );
	}

	void returnTranslocator()
	{
		if ( this.playerClass.tag != PLAYERCLASS_RUNNER )
		{
			client.printMessage( "This action is not available for your class\n" );
			return;
		}

		if ( this.isTranslocating || this.hasJustTranslocated )
			return;

		if ( @this.translocator == null )
			return;

		this.translocator.Free();
		@this.translocator = null;
	}

	void useTranslocator()
	{
		if ( this.playerClass.tag != PLAYERCLASS_RUNNER )
		{
			client.printMessage( "This action is not available for your class\n" );
			return;
		}

		if ( this.isTranslocating || this.hasJustTranslocated )
			return;

		if ( @this.translocator == null )
			return;

		if ( @this.translocator.getPlayerBoxTelefraggableEntities() == null )
		{
			this.returnTranslocator();
			return;
		};

		this.isTranslocating = true;
		this.translocationOrigin = this.translocator.bodyEnt.origin;
	}

	void translocatorHasBeenReturned()
	{
		G_LocalSound( this.client, CHAN_AUTO, G_SoundIndex( "sounds/menu/back" ) );
		client.printMessage( S_COLOR_CYAN + "Your translocator has been returned\n" );
		@this.translocator = null;
		if ( !this.hasJustTranslocated )
			client.armor += CTFT_TRANSLOCATOR_AP_COST;
	}

	void bouncePadSpawningHasFailed()
	{
		@this.bouncePad = null;
		client.printMessage( "Can't spawn a bounce pad here\n" );
		this.engineerBuildCooldownTime = 0;
		// Return armor spent on throwing a bounce pad spawner
		client.armor += CTFT_TURRET_AP_COST;
	}

	void printDescription()
	{
		// Print all description lines to the players's console
		for ( uint i = 0; i < this.playerClass.description.size(); ++i )
			G_PrintMsg( this.ent, this.playerClass.description[i] );
	}

	void printNextTip()
	{
		if ( this.ent.isGhosting() )
			return;

		if ( match.getState() > MATCH_STATE_WARMUP )
			return;

		if ( this.nextTipTime > levelTime )
			return;

		if ( this.nextTipDescriptionLine >= this.playerClass.description.size() )
			return;

		G_CenterPrintMsg( this.ent, this.playerClass.description[this.nextTipDescriptionLine] );
		this.nextTipDescriptionLine++;
		this.nextTipTime = levelTime + 2400;
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
