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

const int ALL_DISABLED_MOVEMENT_FEATURES =
	PMFEAT_WEAPONSWITCH|PMFEAT_WALK|PMFEAT_CROUCH|PMFEAT_JUMP|PMFEAT_DASH|PMFEAT_WALLJUMP|PMFEAT_AIRCONTROL;

const int GUNNER_DEPLOY_DISABLED_MOVEMENT_FEATURES =
	PMFEAT_WEAPONSWITCH|PMFEAT_WALK|PMFEAT_CROUCH|PMFEAT_JUMP|PMFEAT_DASH|PMFEAT_WALLJUMP|PMFEAT_AIRCONTROL;

const int GRUNT_SHELL_DISABLED_MOVEMENT_FEATURES = PMFEAT_DASH|PMFEAT_WALLJUMP|PMFEAT_AIRCONTROL;

class cPlayer
{
	PlayerInventoryTracker inventoryTracker;
    cPlayerClass @playerClass;
    Client @client;
    Entity @ent;
    cReviver @reviver;
	cTranslocator @translocator;
	Entity @motionDetector;

	Entity @detectionSprite;
	Entity @detectionMinimap;

    int64 medicRegenCooldownTime;
	int64 shellActivationCooldownTime;
	int64 supportRegenCooldownTime;
    int64 buildCooldownTime;
	int64 smokeGrenadeCooldownTime;
	int64 bioGrenadeCooldownTime;
	int64 translocatorCooldownTime;
	int64 flagDispenserCooldownTime;
    int64 respawnTime;
	int64 repeatedCommandTime;  // Prevents unitended execution of some non-idempotent commands twice
	bool isHealingTeammates;
	bool isTranslocating;     // A player entity is on its old origin and a teleport effect is shown
	bool hasJustTranslocated; // A player entity is on its new origin and a teleport effect is shown
	Vec3 translocationOrigin; // A translocator can be killed while translocation, so we save destination origin 
	float medicInfluence;
	float supportInfluence;
    bool invisibilityEnabled;
    float invisibilityLoad;
    int64 invisibilityCooldownTime;
    int64 hudMessageTimeout;
	uint nextTipDescriptionLine;
	int64 nextTipTime;

    cPlayer @deadcamMedic;
    int64 deadcamMedicScanTime;

	double medicInfluenceScore;
	double supportInfluenceScore;

    cPlayer()
    {
		@this.inventoryTracker.player = @this;
        // initialize all as grunt
        @this.playerClass = @cPlayerClassInfos[PLAYERCLASS_GRUNT];
        @this.reviver = null;
		@this.translocator = null;
		@this.motionDetector = null;
		@this.detectionSprite = null;
		@this.detectionMinimap = null;
        this.resetTimers();
		
		this.medicInfluenceScore = 0.0;
		this.supportInfluenceScore = 0.0;
    }

    ~cPlayer() {}

    void resetTimers()
    {
        this.medicRegenCooldownTime = 0;
		this.shellActivationCooldownTime = 0;
		this.supportRegenCooldownTime = 0;
        this.buildCooldownTime = 0;
		this.smokeGrenadeCooldownTime = 0;
		this.bioGrenadeCooldownTime = 0;
		this.translocatorCooldownTime = 0;
		this.flagDispenserCooldownTime = 0;
        this.respawnTime = 0;
		this.repeatedCommandTime = 0;
		this.isHealingTeammates = false;
		this.isTranslocating = false;
		this.hasJustTranslocated = false;
		this.medicInfluence = 0.0f;
		this.supportInfluence = 0.0f;
        this.invisibilityEnabled = false;
        this.invisibilityLoad = 0;
        this.invisibilityCooldownTime = 0;
        this.hudMessageTimeout = 0;
		this.nextTipDescriptionLine = 0;
		this.nextTipTime = 0;
        this.deadcamMedicScanTime = 0;
    }

    void printMessage( String &string )
    {
        this.client.printMessage( string );
    }

	// Should be used for printing important messages. Defers next tip (if any).
	void centerPrintMessage( String &string )
	{
		G_CenterPrintMsg( this.ent, string );
		if ( this.nextTipTime >= levelTime && levelTime - this.nextTipTime < 3000 )
			this.nextTipTime = levelTime + 3000;
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

        if ( this.isBuildCooldown() )
        {
            frac = float( this.buildCooldownTimeLeft() ) / float( WTF_BUILD_COOLDOWN_TIME );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

        if ( this.isShellActivationCooldown() )
        {
            frac = float( this.shellActivationCooldownTimeLeft() ) / float( WTF_SHELL_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

		if ( this.isTranslocatorCooldown() )
		{
			frac = float( this.translocatorCooldownTimeLeft() ) / float ( WTF_TRANSLOCATOR_COOLDOWN );
			this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
		}

		if ( this.isMedicRegenCooldown() )
        {
            frac = float( this.medicRegenCooldownTimeLeft() ) / float( WTF_MEDIC_REGEN_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

		if ( this.isSupportRegenCooldown() )
        {
            frac = float( this.supportCooldownTimeLeft() ) / float( WTF_SUPPORT_REGEN_COOLDOWN );
            this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
        }

		if ( this.isBioGrenadeCooldown() )
		{
            this.client.setHUDStat( STAT_PROGRESS_OTHER, this.bioCooldownProgress() );
		}

		if ( this.isSmokeGrenadeCooldown() )
		{
			this.client.setHUDStat( STAT_PROGRESS_OTHER, this.smokeCooldownProgress() );
		}

        if ( this.playerClass.tag == PLAYERCLASS_INFILTRATOR )
        {
			if ( this.invisibilityLoad > 0 )
			{
				frac = this.invisibilityLoad / WTF_INFILTRATOR_INVIS_MAXLOAD;
				if ( this.isInvisibilityCooldown() || this.invisibilityLoad < WTF_INFILTRATOR_INVIS_MINLOAD )
					this.client.setHUDStat( STAT_PROGRESS_SELF, -int( frac * 100 ) );
				else
					this.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
			}
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

        return success;
    }

    void handlePlayerClassCommand( String &argsString )
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
                this.respawnTime = levelTime + WTF_BASE_RESPAWN_TIME;
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
                visible = WTF_LookAtEntity( this.reviver.ent.origin, Vec3(0.0), this.deadcamMedic.ent, this.ent.entNum, true, 72, 32, lookOrigin, lookAngles );

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

	// Accepts an initial suggested translocation origin
	// Returns null if translocation cannot be done after all tries.
	// Returns non-null array of entities that might/should be telefragged in translocation.
	// The returned array might be empty in case when there is no entities to telefrag.
	array<Entity @> @testTranslocation( const Vec3 &in initialOrigin, Vec3 &out adjustedOrigin )
	{
		array<Entity @> @entities = @this.translocator.getPlayerBoxTelefraggableEntities( initialOrigin );
		if ( @entities != null )
		{
			adjustedOrigin = initialOrigin;
			return entities;
		}

		// the common case of translocation failure is when a translocator is just below a solid ceiling.
		// try using lower translocation origin.

		// do not try move the origin down if translocator is on a solid ground.
		if ( @this.translocator.bodyEnt.groundEntity != null )
		{
			if ( this.translocator.bodyEnt.groundEntity.entNum == 0 )
				return this.trySideOffsetsForTranslocation( initialOrigin, adjustedOrigin );
		}

		Vec3 loweredOrigin( initialOrigin );
		loweredOrigin.z -= ( playerBoxMaxs.z - playerBoxMins.z );
		@entities = @this.translocator.getPlayerBoxTelefraggableEntities( loweredOrigin );
		if ( @entities != null )
		{
			adjustedOrigin = loweredOrigin;
			return entities;
		}

		@entities = this.trySideOffsetsForTranslocation( initialOrigin, adjustedOrigin );
		if ( @entities != null )
			return entities;

		return this.trySideOffsetsForTranslocation( loweredOrigin, adjustedOrigin );
	}

	array<Entity @> @trySideOffsetsForTranslocation( const Vec3 &in initialOrigin, Vec3 &out adjustedOrigin )
	{
		array<Entity @> @entities;
		const int numAngularSteps = 19;
		float angularStep = 3.1416f / numAngularSteps;
		// Randomize initial angular offset
		float angle = -3.1416f * ( -0.5f + random() );
		// Interleave offset sign to avoid wasting cycles on consequential tesing in "bad" areas.
		float xSign = -1.0f;
		float ySign = +1.0f;
		for ( int angularStepNum = 0; angularStepNum < numAngularSteps; ++angularStepNum )
		{
			Vec3 testedOrigin( initialOrigin );
			// Note: if the radius is increased from this, there is a chance 
            // a player can be teleported behind thin/curved patch walls.
			// I have tried adding additional traces from a tested origin to the trans origin 
			// but they do not wark for unknown reason.
			// So just limit the tested origins radius to 24 units.
			testedOrigin.x += 24.0f * xSign * sin( angle );
			testedOrigin.y += 24.0f * ySign * cos( angle );
			@entities = this.translocator.getPlayerBoxTelefraggableEntities( testedOrigin );
			if ( @entities != null )
			{
				adjustedOrigin = testedOrigin;
				return entities;
			}
			angle += angularStep;
			xSign = -xSign;
			ySign = -ySign;
		}

		return null;
	}

	void handleIsTranslocatingState()
	{
		this.addTranslocationEffect( prcTransInSoundIndex );

		this.isTranslocating = false;
		this.hasJustTranslocated = true;
		return;
	}

	// The player entity must be already linked to a desired origin
	void addTranslocationEffect( int soundIndex )
	{
		this.ent.respawnEffect();
		G_Sound( this.ent, CHAN_MUZZLEFLASH, soundIndex, 0.4f );
	}

	void handleJustTranslocatedState()
	{
		this.hasJustTranslocated = false;

		if ( ( this.ent.effects & EF_CARRIER ) != 0 )
			CTF_PlayerDropFlag( this.ent, false );

		this.ent.unlinkEntity();

		// if the translocator has been killed during translocation
		if ( @this.translocator == null )
		{
			this.centerPrintMessage( S_COLOR_RED + "Your translocator was destroyed!\n" );
			// move the player entity, use the saved translocation origin
			this.ent.origin = this.translocationOrigin;
			this.ent.linkEntity();
			this.addTranslocationEffect( prcTransOutSoundIndex );
			// kill the player
			this.ent.sustainDamage( null, null, Vec3( 0, 0, 1 ), 9999.0f, 50.0f, 1000.0f, 0 );
			return;
		}

		// if the translocator is damaged
		if ( this.translocator.bodyEnt.health < WTF_TRANSLOCATOR_HEALTH )
		{
			this.centerPrintMessage( S_COLOR_RED + "Your translocator was damaged!\n" );
			// move the player entity, use an actual translocator origin
			this.ent.origin = this.translocator.bodyEnt.origin + translocationOriginOffset;
			this.ent.linkEntity();
			this.addTranslocationEffect( prcTransOutSoundIndex );
			// kill the player
			this.ent.sustainDamage( null, null, Vec3( 0, 0, 1 ), 9999.0f, 50.0f, 1000.0f, 0 );
			this.translocator.Free();
			return;
		}

		Vec3 initialOrigin( this.translocator.bodyEnt.origin );
		initialOrigin += translocationOriginOffset;
		Vec3 adjustedOrigin;

		array<Entity @> @telefraggableEntities = @this.testTranslocation( initialOrigin, adjustedOrigin );
		// if translocation cannot be done
		if ( @telefraggableEntities == null )
		{
			this.returnTranslocator();
			return;
		}

		// kill all entities that should be telefragged
		for ( uint i = 0; i < telefraggableEntities.size(); ++i )
		{
			Entity @ent = telefraggableEntities[i];
			ent.sustainDamage( this.ent, this.ent, Vec3( 0, 0, 1 ), 9999.0f, 50.0f, 1000.0f, 0 );
		}

		// move the player entity
		this.ent.origin = adjustedOrigin;
		this.ent.linkEntity();
		this.addTranslocationEffect( prcTransOutSoundIndex );
		// this call leads to resetting translocator cooldown
		this.translocator.Free();
		// set cooldown after translocation
		this.setTranslocatorCooldown();
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
			this.client.pmoveFeatures = this.client.pmoveFeatures | ALL_DISABLED_MOVEMENT_FEATURES;
			if ( this.playerClass.tag == PLAYERCLASS_RUNNER )
			{
				this.client.pmoveFeatures = this.client.pmoveFeatures | PMFEAT_CROUCHSLIDING;
			}
			else
			{
				this.client.pmoveFeatures = this.client.pmoveFeatures & ~PMFEAT_CROUCHSLIDING;
			}

			if ( this.isTranslocating )
			{
				handleIsTranslocatingState();
				return;
			}

			if ( this.hasJustTranslocated )
			{
				handleJustTranslocatedState();
				return;
			}

            this.client.pmoveJumpSpeed = this.playerClass.jumpSpeed;

			
			// Apply the hack described in classes definition
			if ( @this.ent.groundEntity == null )
				this.client.pmoveMaxSpeed = this.playerClass.pmoveMaxSpeedInAir;
			else
				this.client.pmoveMaxSpeed = this.playerClass.pmoveMaxSpeedOnGround;

			this.client.pmoveDashSpeed = this.playerClass.dashSpeed;
			

            if ( this.playerClass.tag == PLAYERCLASS_GRUNT )
			{
				// Disable dash/walljump/aircontrol features while wearing a shell
				if ( this.client.inventoryCount( POWERUP_SHELL ) > 0 )
				{
					this.client.pmoveFeatures = this.client.pmoveFeatures & ~GRUNT_SHELL_DISABLED_MOVEMENT_FEATURES;
					this.ent.mass = 350;
				}
				else
					this.ent.mass = 250;
			}
			else
				this.ent.mass = 200;

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
		float radius = WTF_MEDIC_INFLUENCE_BASE_RADIUS;
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
		}
	}

	void refreshSupportInfluenceEmission()
	{
		float radius = WTF_SUPPORT_INFLUENCE_BASE_RADIUS;
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
		}
	}

	void refreshInfluenceAbsorption()
	{
		if ( this.medicInfluence > 1.0f )
			this.medicInfluence = 1.0f;

		if ( this.supportInfluence > 1.0f )
			this.supportInfluence = 1.0f;

		this.ent.effects &= ~( EF_QUAD | EF_REGEN | EF_GODMODE );
		if ( !this.invisibilityEnabled )
		{
			if ( this.medicInfluence > 0 )
				this.ent.effects |= EF_REGEN;

			if ( this.supportInfluence > 0 )
				this.ent.effects |= EF_GODMODE;
		}
	}

    void refreshRegeneration()
    {
        if ( this.ent.isGhosting() )
            return;

		// First, check generic health/armor regeneration due to medic/support influence

		if ( this.medicInfluence > 0 )
		{
			if ( this.ent.health < this.ent.maxHealth )
				this.ent.health += ( frameTime * this.medicInfluence * 0.025f );
		}

		if ( this.supportInfluence > 0 )
		{
			if ( this.client.armor < this.playerClass.maxArmor )
				this.client.armor += ( frameTime * this.supportInfluence * 0.025f );
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
		else if ( this.playerClass.tag == PLAYERCLASS_INFILTRATOR )
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
                if ( this.invisibilityLoad > WTF_INFILTRATOR_INVIS_MAXLOAD )
                    this.invisibilityLoad = WTF_INFILTRATOR_INVIS_MAXLOAD;
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
        else if ( this.playerClass.tag == PLAYERCLASS_INFILTRATOR )
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

        this.medicRegenCooldownTime = levelTime + WTF_MEDIC_REGEN_COOLDOWN;
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

		this.supportRegenCooldownTime = levelTime + WTF_SUPPORT_REGEN_COOLDOWN;
	}

	int supportCooldownTimeLeft()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return 0;
		
		if ( this.supportRegenCooldownTime <= levelTime )
			return 0;

		return int( levelTime - this.supportRegenCooldownTime );
	}

	bool isSmokeGrenadeCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return false;

		return this.smokeGrenadeCooldownTime > levelTime;
	}

	void setSmokeGrenadeCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return;

		this.smokeGrenadeCooldownTime = levelTime + 3000;
	}

	int smokeCooldownProgress()
	{
		if ( this.playerClass.tag != PLAYERCLASS_SUPPORT )
			return 0;

		if ( this.smokeGrenadeCooldownTime <= levelTime )
			return 0;

		return int( 100 * ( levelTime - this.smokeGrenadeCooldownTime ) / 3000.0f );
	}

	bool isBioGrenadeCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
			return false;

		return ( this.bioGrenadeCooldownTime > levelTime ) ? true : false;
	}

	void setBioGrenadeCooldown()
	{
		if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
			return;

		this.bioGrenadeCooldownTime = levelTime + 2000;
	}

	int bioCooldownProgress()
	{
		if ( this.playerClass.tag != PLAYERCLASS_MEDIC )
			return 0;

		if ( this.bioGrenadeCooldownTime <= levelTime )
			return 0;

		return int( 100 * ( levelTime - this.bioGrenadeCooldownTime ) / 2000.0f );
	}

    void setInvisibilityCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_INFILTRATOR )
            return;

        this.invisibilityCooldownTime = levelTime + WTF_INFILTRATOR_INVIS_COOLDOWN;
    }

    bool isInvisibilityCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_INFILTRATOR )
            return false;

        return ( this.invisibilityCooldownTime > levelTime ) ? true : false;
    }

    void setBuildCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_SNIPER )
            return;

        this.buildCooldownTime = levelTime + WTF_BUILD_COOLDOWN_TIME;
    }

    bool isBuildCooldown()
    {
        if ( this.playerClass.tag != PLAYERCLASS_SNIPER )
            return false;

        return ( this.buildCooldownTime > levelTime ) ? true : false;
    }

    int buildCooldownTimeLeft()
    {
        if ( this.playerClass.tag != PLAYERCLASS_SNIPER )
            return 0;

        if ( this.buildCooldownTime <= levelTime )
            return 0;

        return int( this.buildCooldownTime - levelTime );
    }

	void setTranslocatorCooldown()
	{
		this.translocatorCooldownTime = levelTime + WTF_TRANSLOCATOR_COOLDOWN;
	}

	bool isTranslocatorCooldown()
	{
		return this.translocatorCooldownTime > levelTime;
	}

	int translocatorCooldownTimeLeft()
    {
        if ( this.translocatorCooldownTime <= levelTime )
            return 0;

        return int( this.translocatorCooldownTime - levelTime );
    }

    void setShellActivationCooldown()
    {
        this.shellActivationCooldownTime = levelTime + WTF_SHELL_COOLDOWN;
    }

    bool isShellActivationCooldown()
    {
        return ( this.shellActivationCooldownTime > levelTime ) ? true : false;
    }

    int shellActivationCooldownTimeLeft()
    {
        if ( this.shellActivationCooldownTime <= levelTime )
            return 0;

        return int( this.shellActivationCooldownTime - levelTime );
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

        if ( this.invisibilityLoad < WTF_INFILTRATOR_INVIS_MINLOAD )
        {
            this.printMessage( "Cannot use the skill yet\n" );
            return;
        }

        this.invisibilityEnabled = true;
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

        this.client.selectWeapon( -1 );
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

        if ( this.isShellActivationCooldown() )
        {
            this.printMessage( "Cannot activate shell yet\n" );
            return;
        }

		this.client.inventorySetCount( POWERUP_SHELL, 3 );
        this.setShellActivationCooldown();
        G_Sound( this.ent, CHAN_MUZZLEFLASH, G_SoundIndex( "sounds/items/shell_spawn" ), 0.3f );
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

	void throwTranslocator()
	{
		if ( this.playerClass.tag != PLAYERCLASS_RUNNER )
		{
			client.printMessage( "This action is not available for your class\n" );
			return;
		}

		if ( this.isTranslocating || this.hasJustTranslocated )
			return;

		if ( this.isTranslocatorCooldown() )
		{
			client.printMessage( "You can't throw a translocator yet\n" );
			return;
		}

		if ( @this.translocator != null )
		{
			this.returnTranslocator();
			return;
		}

		@this.translocator = @ClientThrowTranslocator( client );
		if ( @this.translocator == null )
			return;
		
		this.setTranslocatorCooldown();
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

		if ( this.translocator.bodyEnt.health < WTF_TRANSLOCATOR_HEALTH )
		{
			client.printMessage( S_COLOR_YELLOW + "Your translocator was damaged!\n" );
			this.returnTranslocator();
			return;
		}

		Vec3 initialOrigin( this.translocator.bodyEnt.health );
		initialOrigin += translocationOriginOffset;
		Vec3 adjustedOrigin;
		if ( @this.testTranslocation( initialOrigin, adjustedOrigin ) == null )
		{
			this.returnTranslocator();
			return;
		}

		G_LocalSound( this.client, CHAN_AUTO, prcTransCheckSucceededSoundIndex );
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

		Vec3 initialOrigin( this.translocator.bodyEnt.origin );
		initialOrigin += translocationOriginOffset;
		Vec3 adjustedOrigin;
		if ( @this.testTranslocation( initialOrigin, adjustedOrigin ) == null )
		{
			this.returnTranslocator();
			return;
		};

		this.isTranslocating = true;
		this.translocationOrigin = adjustedOrigin;
	}

	void throwOrUseTranslocator() 
	{
		if ( this.repeatedCommandTime > levelTime )
			return;

		if ( @this.translocator == null )
			this.throwTranslocator();
		else
			this.useTranslocator();

		this.repeatedCommandTime = levelTime + 200;
	}

	void translocatorHasBeenReturned()
	{
		G_LocalSound( this.client, CHAN_AUTO, prcTransReturnedSoundIndex );
		client.printMessage( S_COLOR_CYAN + "Your translocator has been returned\n" );
		@this.translocator = null;
		this.translocatorCooldownTime = 0;
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

	void showDetectionEntities()
	{
		if ( @this.detectionSprite != null )
		{
			// Just update the sprite origin
			this.detectionSprite.origin = this.ent.origin;
			this.detectionSprite.linkEntity();	
		}
		else
		{ 
			@this.detectionSprite = @G_SpawnEntity( "player_detection_sprite" );
			this.detectionSprite.type = ET_RADAR;
			this.detectionSprite.solid = SOLID_NOT;
			this.detectionSprite.team = ( this.ent.team == TEAM_ALPHA ) ? TEAM_BETA : TEAM_ALPHA;
			this.detectionSprite.modelindex = prcMotionDetectorSpriteImageIndex;
			this.detectionSprite.frame = 120;
			this.detectionSprite.origin = this.ent.origin;
			this.detectionSprite.svflags = ( this.detectionSprite.svflags & ~uint(SVF_NOCLIENT) ) | uint(SVF_ONLYTEAM|SVF_BROADCAST);
			this.detectionSprite.linkEntity();
		}

		if ( @this.detectionMinimap != null )
		{
			// Just update the entity origin
			this.detectionMinimap.origin = this.ent.origin;
			this.detectionMinimap.linkEntity();
		}
		else
		{
			@this.detectionMinimap = @G_SpawnEntity( "player_detection_minimap" );
			this.detectionMinimap.type = ET_MINIMAP_ICON;
			this.detectionMinimap.solid = SOLID_NOT;
			this.detectionMinimap.team = ( this.ent.team == TEAM_ALPHA ) ? TEAM_BETA : TEAM_ALPHA;
			this.detectionMinimap.modelindex = prcMotionDetectorMinimapImageIndex;
			this.detectionMinimap.frame = 20;
			this.detectionMinimap.origin = this.ent.origin;
			this.detectionMinimap.svflags = ( this.detectionMinimap.svflags & ~uint(SVF_NOCLIENT) ) | uint(SVF_ONLYTEAM|SVF_BROADCAST);
			this.detectionMinimap.linkEntity();
		}
	}

	void hideDetectionEntities()
	{
		if ( @this.detectionSprite != null )
		{
			this.detectionSprite.freeEntity();
			@this.detectionSprite = null;
		}
		
		if ( @this.detectionMinimap != null )
		{
			this.detectionMinimap.freeEntity();
			@this.detectionMinimap = null;
		}
	}

	void buildOrDestroyMotionDetector()
	{
		if ( this.repeatedCommandTime > levelTime )
			return;

		if ( @this.motionDetector == null )
			this.buildMotionDetector();
		else
			this.destroyMotionDetector();

		this.repeatedCommandTime = levelTime + 300;
	}

	void buildMotionDetector()
	{
		if ( this.buildCooldownTime >= levelTime )
			return;

		if ( @this.motionDetector != null )
		{
			client.printMessage( "You have already built a motion detector\n" );
			return;
		}

		if ( this.isBuildCooldown() )
    	{
        	client.printMessage( "You cannot build yet\n" );
        	return;
    	}

		if ( this.client.armor < WTF_BUILD_AP_COST )
		{
			client.printMessage( "You do not have enough armor to build a motion detector\n" );
			return;
		}

		@this.motionDetector = @ClientThrowMotionDetector( this.client );
		if ( @this.motionDetector == null )
			return;

		this.setBuildCooldown();
		this.client.armor -= WTF_BUILD_AP_COST;
	}

	void destroyMotionDetector()
	{
		if ( @this.motionDetector == null )
		{
			client.printMessage( "There is no your motion detector\n" );
			return;
		}

		motion_detector_die( this.motionDetector, null, null );
		this.motionDetectorBuildingCanceled();
		this.setBuildCooldown();	
		return;
	}

	void motionDetectorBuildingCanceled()
	{
		this.client.armor += WTF_BUILD_AP_COST;
		@this.motionDetector = null;
	}

	void motionDetectorDestroyed()
	{
		this.centerPrintMessage( S_COLOR_RED + "Your motion detector has been destroyed" );
		@this.motionDetector = null;
	}

	void setAppropriateBotClass()
	{
		// The native code bot team logic assigns at least a single defender to a defense spot.
		// Thus, if a team has only a single bot, it should have a class that suits defense well.
		int numBotsInTeam = 0;
		int numDefClassBotsInTeam = 0;
		// Medics and supports are vital for a team
		int numMedicsInTeam = 0;
		int numSupportsInTeam = 0;
		Team @teamList = @G_GetTeam( this.ent.team );
		int teamSize = teamList.numPlayers;
		for( int i = 0; i < teamSize; ++i )
		{
			Entity @ent = @teamList.ent( i );
			cPlayer @player = @GetPlayer( ent.client );
			int classTag = player.playerClass.tag;
			if( classTag == PLAYERCLASS_MEDIC )
			{
				numMedicsInTeam++;
			}
			else if( classTag == PLAYERCLASS_SUPPORT )
			{
				numSupportsInTeam++;
			}

			if( @ent.client.getBot() == null )
			{
				continue;
			}

			numBotsInTeam++;
			if( classTag == PLAYERCLASS_SNIPER || classTag == PLAYERCLASS_INFILTRATOR )
			{
				numDefClassBotsInTeam++;
			}
		}

		// If there is no bots with classes that are suitable for defence
		if( numDefClassBotsInTeam == 0 )
		{
			setPlayerClass( random() > 0.5f ? PLAYERCLASS_SNIPER : PLAYERCLASS_INFILTRATOR );
			return;
		}

		// If there are no vital class players in the team

		if( numMedicsInTeam == 0 )
		{
			setPlayerClass( PLAYERCLASS_MEDIC );
			return;
		}

		if( numSupportsInTeam == 0 )
		{
			setPlayerClass( PLAYERCLASS_SUPPORT );
			return;
		}

		// If the control flow has reached here, there are
        // at least a single defender, Medic and Support in the team.

		// TODO: We wish there were static assertions on class tags values

		// Never add extra Snipers to the team.
		const int lowerTagBound = PLAYERCLASS_SNIPER + 1;

		// Never assign bot classes to Runner unless there is enough bots
		// so the poor bot Runner play can be shadowed by the classes variety.
		const int upperTagBound = numBotsInTeam < 5 ? PLAYERCLASS_RUNNER - 1 : PLAYERCLASS_RUNNER;

		int tag = lowerTagBound;
		for( int j = 0; j < 2; ++j )
		{
			tag = int( lowerTagBound + random() * ( upperTagBound - lowerTagBound + 0.499f ) );
			if( tag > upperTagBound )
			{
				tag = upperTagBound;
			}
			// The tag is Grunt, Gunner or Runner, good enough
			if( tag != PLAYERCLASS_MEDIC && tag != PLAYERCLASS_SUPPORT )
			{
				break;
			}
			// If tag is Medic or Support, try again once
		}

		setPlayerClass( tag );
	}

	void throwSmokeGrenade()
	{
		if ( this.isSmokeGrenadeCooldown() )
		{
			client.printMessage( "You can't throw a grenade yet\n" );
			return;
		}

		if( @ClientThrowSmokeGrenade( client ) != null )
		{
			this.setSmokeGrenadeCooldown();
		}
	}

	void throwBioGrenade()
	{
		if ( this.isBioGrenadeCooldown() )
		{
			client.printMessage( "You can't throw a grenade yet\n" );
			return;
		}

		if ( @ClientThrowBioGrenade( client ) != null )
		{
			this.setBioGrenadeCooldown();
		}
	}

	void handleClassactionCommand( String &argsString )
	{
		if ( this.client.getEnt().isGhosting() )
		{
			return;
		}

		// TODO: Should be a virtual method of an overridden player class
		switch ( this.playerClass.tag )
		{
			case PLAYERCLASS_GRUNT:
				this.activateShell();
				break;
			case PLAYERCLASS_MEDIC:
				this.throwBioGrenade();
				break;
			case PLAYERCLASS_RUNNER:
				this.throwOrUseTranslocator();
				break;
			case PLAYERCLASS_INFILTRATOR:
				this.activateInvisibility();
				break;
			case PLAYERCLASS_SUPPORT:
				this.throwSmokeGrenade();
				break;
			case PLAYERCLASS_SNIPER:
				this.buildOrDestroyMotionDetector();
				break;
		}
	}
}

cPlayer @GetPlayer( const Client @client )
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
