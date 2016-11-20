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

const int MAX_BOUNCE_PADS = 6;

cBouncePad[] gtBouncePads( MAX_BOUNCE_PADS );

// Let the trigger dimensions be equal. 
// The pad can be built on walls and even on the ceiling.
const Vec3 bouncePadTriggerMins( -40, -40, -40 );
const Vec3 bouncePadTriggerMaxs( +40, +40, +40 );

// Use smaller box for body than for trigger (otherwise one will hit it instead of the trigger)
const Vec3 bouncePadBodyMins( -16, -16, -16 );
const Vec3 bouncePadBodyMaxs( +16, +16, +16 );

const Vec3 bouncePadSpawnerMins( -1, -1, -1 );
const Vec3 bouncePadSpawnerMaxs( +1, +1, +1 );

class cBouncePad
{
    bool inuse;
	
	Entity @spawnerEnt;
	Entity @triggerEnt;
    Entity @bodyEnt;
    cPlayer @player;
	Vec3 normal;
	Vec3 normalVelocity;

	uint activatedTime;
	uint[] lastTouchTime( maxEntities );

    void Init()
    {
        // set up with default values
        this.inuse = false;
        @this.player = null;

		this.activatedTime = 0;
		for ( int i = 0; i < maxEntities; ++i )
			lastTouchTime[i] = 0;
    }

    cBouncePad()
    {
        this.Init();
    }

    ~cBouncePad()
    {
        this.Free();
    }

    void Free()
    {
		if ( @this.spawnerEnt != null )
		{
			this.spawnerEnt.freeEntity();
			@this.spawnerEnt = null;
		}

		if ( @this.triggerEnt != null )
		{
			this.triggerEnt.freeEntity();
			@this.triggerEnt = null;
		}

        if ( @this.bodyEnt != null )
        {
            this.bodyEnt.freeEntity();
            @this.bodyEnt = null;
        }

		if ( @this.player != null && @this.player.bouncePad != null )
            @this.player.bouncePad = null;       

        this.Init();
    }

    bool SpawnBody( Client @client )
    {
        if ( @client == null )
            return false;

		if ( @this.spawnerEnt == null )
			return false;
		
		if ( ( G_PointContents( this.spawnerEnt.origin ) & (CONTENTS_SOLID|CONTENTS_NODROP) ) != 0 )
			return false;

        // try to position the bomb in the world.
        Trace tr;

        // check the initial position is not inside solid
		Vec3 origin = spawnerEnt.origin;
		Vec3 halfSpawnerMins = 0.5f * bouncePadSpawnerMins;
		Vec3 halfSpawnerMaxs = 0.5f * bouncePadSpawnerMaxs;
        if ( tr.doTrace( origin, halfSpawnerMins, halfSpawnerMaxs, origin, this.spawnerEnt.entNum, MASK_SOLID ) )
			return false;

        if ( tr.startSolid || tr.allSolid )
            return false;

        // proceed setting up
        this.Init();
		// fix this.inuse reset by Init() (this bounce pad becomes used before the body is spawned).
		this.inuse = true;

        @this.player = @GetPlayer( client );

		@this.triggerEnt = @G_SpawnEntity( "bounce_pad_trigger" );
		@this.triggerEnt.touch = bounce_pad_trigger_touch;
		this.triggerEnt.type = ET_GENERIC;
		this.triggerEnt.setSize( bouncePadTriggerMins, bouncePadTriggerMaxs );
		this.triggerEnt.angles = this.normal.toAngles();
		this.triggerEnt.team = this.player.ent.team;
		this.triggerEnt.ownerNum = this.player.client.playerNum;
		this.triggerEnt.origin = origin;
		this.triggerEnt.solid = SOLID_TRIGGER;
		this.triggerEnt.clipMask = MASK_PLAYERSOLID;
		this.triggerEnt.moveType = MOVETYPE_NONE;
		this.triggerEnt.svflags |= SVF_NOCLIENT;
		this.triggerEnt.linkEntity();

        @this.bodyEnt = @G_SpawnEntity( "bounce_pad_body" );
		@this.bodyEnt.think = bounce_pad_body_think;
		@this.bodyEnt.die = bounce_pad_body_die;
        this.bodyEnt.type = ET_GENERIC;
        this.bodyEnt.modelindex = prcBouncePadNormalModel;
        this.bodyEnt.setSize( bouncePadBodyMins, bouncePadBodyMaxs );
		this.bodyEnt.angles = this.normal.toAngles();
        this.bodyEnt.team = this.player.ent.team;
        this.bodyEnt.ownerNum = this.player.client.playerNum;
        this.bodyEnt.origin = origin;
        this.bodyEnt.solid = SOLID_YES;
        this.bodyEnt.clipMask = MASK_PLAYERSOLID;
        this.bodyEnt.moveType = MOVETYPE_NONE;
        this.bodyEnt.svflags &= ~SVF_NOCLIENT;
        this.bodyEnt.health = CTFT_BOUNCE_PAD_HEALTH;
        this.bodyEnt.mass = 99999;
        this.bodyEnt.takeDamage = 1;
		this.bodyEnt.nextThink = levelTime + 1;
        this.bodyEnt.linkEntity();

        // the count field will be used to store the index of the cBouncePad object
        // int the list. If the object is part of the list, ofc. This is just for
        // quickly accessing it.
		this.triggerEnt.count = this.spawnerEnt.count;
        this.bodyEnt.count = this.spawnerEnt.count;

		// do not hold the spawner reference entire pad lifetime (it gets freed by a caller).
		@this.spawnerEnt = null;

        return true; // a bounce pad has been correctly spawned
    }

    void die( Entity @inflictor, Entity @attacker )
    {
        if ( !this.inuse )
			return;

		if ( @this.player != null )
			this.player.centerPrintMessage( S_COLOR_RED + "Your bounce pad has been destroyed\n" );

        this.Free();
    }

	void touch( Entity @other )
	{
		if ( @other == null )
        	return;

		// Split conditions in two to fit line width
		if ( other.moveType != MOVETYPE_TOSS && other.moveType != MOVETYPE_PLAYER )
		{
			if ( other.moveType != MOVETYPE_BOUNCE && other.moveType != MOVETYPE_BOUNCEGRENADE )
				return;
		}

		if ( levelTime - this.lastTouchTime[other.entNum] < 96 )
			return;
		
		// Let us assume that the entity velocity contains of two parts: tangential and normal ones.
		// Keep the tangential part and replace normal part by this.normalVelocity.
		// Do not just reflect the entity velocity using the pad normal, it feels bad in game.
		
		Vec3 normalPart = ( other.velocity * this.normal ) * this.normal;
		Vec3 tangentialPart = other.velocity - normalPart;

		// Prevent other than the Runner classes to use this pad for acceleration.
		// Otherwise these classes will be able to do speed flag caps, and its not our aim.
		if ( @other.client != null && GetPlayer( other.client ).playerClass.tag != PLAYERCLASS_RUNNER )
			tangentialPart *= 0.95f;

		other.velocity = tangentialPart + this.normalVelocity;

		this.activatedTime = levelTime + 128;
		this.lastTouchTime[other.entNum] = levelTime;

		G_Sound( other, CHAN_AUTO, prcBouncePadActivateSound, 0.4f );

		// Apply a damage if an enemy entity used this
		if ( other.takeDamage != 0 && other.team != this.bodyEnt.team )
			other.sustainDamage( null, null, this.normal, 50, 50, 500, 0 );
	}

	void think()
	{
		// I'm not sure if it is the right approach to handle client left events
		if ( @this.player != null && @this.player.client != null )
		{
			if ( this.player.client.state() < CS_SPAWNED || this.player.ent.team != this.bodyEnt.team )
			{
				@this.player.bouncePad = null;
				@this.player = null;
				this.die( null, null );
				return;
			}
		}

		if ( this.activatedTime > levelTime )
			this.bodyEnt.modelindex = prcBouncePadActivatedModel;
		else
			this.bodyEnt.modelindex = prcBouncePadNormalModel;
	}

	void setNormal( const Vec3 &in normal )
	{
		this.normal = normal;
		this.normalVelocity = 700.0f * normal;
	}
}

void bounce_pad_trigger_touch( Entity @ent, Entity @other, const Vec3 planeNormal, int surfFlags )
{
	if ( ent.count >= 0 && ent.count < MAX_BOUNCE_PADS )
		gtBouncePads[ent.count].touch( other );
}

void bounce_pad_body_die( Entity @self, Entity @inflictor, Entity @attacker )
{
    if ( self.count >= 0 && self.count < MAX_BOUNCE_PADS )
        gtBouncePads[self.count].die( inflictor, attacker );
}

void bounce_pad_body_think( Entity @self )
{
    // if for some reason the bounce pad moved to inside a solid, kill it
    if ( ( G_PointContents( self.origin ) & (CONTENTS_SOLID|CONTENTS_NODROP) ) != 0 )
    {
        bounce_pad_body_die( self, @G_GetEntity(0), @G_GetEntity(0) );
        return;
    }

	if ( self.count < 0 || self.count >= MAX_BOUNCE_PADS )
	{
		bounce_pad_body_die( self, @G_GetEntity(0), @G_GetEntity(0) );
        return;
	}

	gtBouncePads[self.count].think();

    self.nextThink = levelTime + 1; 
}

cBouncePad @ClientDropBouncePad( Client @client )
{
    if ( @client == null )
        return null;

    cBouncePad @bouncePad = null;

    // find an unused bounce pad slot
	int slot = 0;
    for ( ; slot < MAX_BOUNCE_PADS; slot++ )
    {
        if ( !gtBouncePads[slot].inuse )
        {
            @bouncePad = @gtBouncePads[slot];
            break;
        }
    }

    if ( @bouncePad == null )
    {
        // let the clients read this, so they complaint to us in case it's happening
        client.printMessage( "GT ERROR: ClientSpawnBouncePad: MAX_BOUNCE_PADS reached. Can't spawn a bounce pad.\n" );
        return null;
    }

    // nodrop area
    if ( ( G_PointContents( client.getEnt().origin ) & CONTENTS_NODROP ) != 0 )
        return null;

    // first check that there's space for spawning the pad in front of us
    Vec3 dir, start, end, r, u;

    client.getEnt().angles.angleVectors( dir, r, u );
    start = client.getEnt().origin + Vec3( 0, 0, client.getEnt().viewHeight );
    end = ( start + ( 0.5 * ( bouncePadSpawnerMaxs + bouncePadSpawnerMaxs ) ) ) + ( dir * 64 );

    Trace tr;

    if ( tr.doTrace( start, bouncePadSpawnerMins, bouncePadSpawnerMaxs, end, client.getEnt().entNum, MASK_PLAYERSOLID ) )
		return null;

	// assign some frontal velocity to the pad spawner, as for being dropped by the player
    float speed = client.getEnt().velocity.length();
    dir *= speed + 250;
    dir.z += 75;

	Entity @spawner = @G_SpawnEntity( "bounce_pad_spawner" );
	@spawner.touch = bounce_pad_spawner_touch;
	@spawner.stop = bounce_pad_spawner_stop;
	spawner.type = ET_GENERIC;
	spawner.modelindex = prcBouncePadSpawnerModel;
	spawner.setSize( bouncePadSpawnerMins, bouncePadSpawnerMaxs );
	spawner.velocity = dir;
	spawner.team = client.getEnt().team;
	spawner.ownerNum = client.playerNum;
	spawner.count = slot;
	spawner.origin = end;
	spawner.solid = SOLID_TRIGGER;
	spawner.clipMask = MASK_SOLID;
	spawner.moveType = MOVETYPE_TOSS;
	spawner.svflags &= ~SVF_NOCLIENT;
	spawner.takeDamage = 0;
	spawner.linkEntity();

	@bouncePad.player = GetPlayer( client );
	@bouncePad.spawnerEnt = spawner;
	bouncePad.inuse = true;

	return @bouncePad;
}

void bounce_pad_spawner_touch( Entity @ent, Entity @other, const Vec3 planeNormal, int surfFlags )
{
	if ( @ent == null )
		return;

	if ( @other == null )
		return;

	if ( ent.count < 0 || ent.count >= MAX_BOUNCE_PADS )
		return;

	cBouncePad @bouncePad = gtBouncePads[ent.count];
	// This slot should be already reserved (but no body entity should be spawned yet)	
	if ( !bouncePad.inuse )
		return;

	bouncePad.setNormal( planeNormal );

	ent.moveType = MOVETYPE_NONE;
}

void bounce_pad_spawner_stop( Entity @spawner )
{
	if ( @spawner == null )
		return;

	if ( spawner.count >= 0 && spawner.count < MAX_BOUNCE_PADS )
	{		
		Client @client = @G_GetClient( spawner.ownerNum );		
		cBouncePad @bouncePad = gtBouncePads[spawner.count];
		// This slot should be already reserved (but no body entity should be spawned yet)
		if ( bouncePad.inuse )
		{
			if ( bouncePad.SpawnBody( client ) )
			{
				spawner.freeEntity();
				return;
			}					
		}
		
		cPlayer @player = GetPlayer( client );
		if ( @player != null )
			player.bouncePadSpawningHasFailed();

		bouncePad.Free();
	}

	spawner.freeEntity();
}
