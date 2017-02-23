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

const int MAX_TRANSLOCATORS = 32; 

cTranslocator[] gtTranslocators( MAX_TRANSLOCATORS );

const Vec3 playerBoxMins( -16, -16, -24 );
const Vec3 playerBoxMaxs( +16, +16, +40 );

// Width and depth should match player box ones (plus-minus some delta).
// (if a translocator is fit in the enviornment, player should fit too if there is enough height) 
const Vec3 translocatorMins( playerBoxMins.x - 0.5f, playerBoxMins.y - 0.5f, -4 );
const Vec3 translocatorMaxs( playerBoxMaxs.x + 0.5f, playerBoxMaxs.y + 0.5f, +4 );
// An offset that should be added to translocator entity origin to produce an initial suggested player origin.
// A player is intended to be spawned 1 unit above a ground and 1 unit below a ceiling (if any).
const Vec3 translocationOriginOffset( 0, 0, translocatorMins.z - playerBoxMins.z + 1.0f );
// These bounds are used for testing an actual translocation box
const Vec3 translocationTestMins( playerBoxMins.x, playerBoxMins.y, playerBoxMins.z - 1.0f );
const Vec3 translocationTestMaxs( playerBoxMaxs.x, playerBoxMaxs.y, playerBoxMaxs.z + 1.0f );

class cTranslocator
{
    bool inuse;
    Entity @bodyEnt;
    cPlayer @player;
	uint returnTime;

    void Init()
    {
        // set up with default values
        this.inuse = false;
        @this.player = null;
		this.returnTime = 0;
    }

    cTranslocator()
    {
        this.Init();
    }

    ~cTranslocator()
    {
        this.Free();
    }

    void Free()
    {
		if ( @this.player != null )
		{
			this.player.translocatorHasBeenReturned();
			@this.player = null;
		}
		
        if ( @this.bodyEnt != null )
		{
			this.bodyEnt.freeEntity();
			@this.bodyEnt = null;
		}

        this.Init();
    }

    bool Spawn( Vec3 origin, Client @client )
    {
        if ( @client == null )
            return false;

        // try to position the bomb in the world.
        Trace tr;

        // check the initial position is not inside solid

        if ( tr.doTrace( origin, bombMins , bombMaxs, origin, -1, MASK_PLAYERSOLID ) )
            return false;

        if ( tr.startSolid || tr.allSolid )
            return false; // initial position is inside solid, we can not spawn the bomb

        // proceed setting up
        this.Init();

        @this.player = @GetPlayer( client );

        @this.bodyEnt = @G_SpawnEntity( "translocator_body" );
		@this.bodyEnt.pain = translocator_body_pain;
		@this.bodyEnt.die = translocator_body_die;
		@this.bodyEnt.think = translocator_body_think;
        this.bodyEnt.type = ET_GENERIC;
        this.bodyEnt.modelindex = prcTransBodyNormalModelIndex;
        this.bodyEnt.setSize( translocatorMins, translocatorMaxs );
        this.bodyEnt.team = this.player.ent.team;
        this.bodyEnt.ownerNum = this.player.client.playerNum;
        this.bodyEnt.origin = origin;
        this.bodyEnt.solid = SOLID_YES;
        this.bodyEnt.clipMask = MASK_PLAYERSOLID;
        this.bodyEnt.moveType = MOVETYPE_TOSS;
        this.bodyEnt.svflags &= ~SVF_NOCLIENT;
        this.bodyEnt.health = CTFT_TRANSLOCATOR_HEALTH;
        this.bodyEnt.mass = 25;
        this.bodyEnt.takeDamage = 1;
        this.bodyEnt.nextThink = levelTime + 1;
        this.bodyEnt.linkEntity();

        // the count field will be used to store the index of the cbomb object
        // int the list. If the object is part of the list, ofc. This is just for
        // quickly accessing it.
        int index = -1;
        for ( int i = 0; i < MAX_TRANSLOCATORS; i++ )
        {
            if ( @gtTranslocators[i] == @this )
            {
                index = i;
                break;
            }
        }

		this.returnTime = levelTime + CTFT_RUNNER_ABILITY_COOLDOWN + 15000;
        @this.player = @player;
        this.bodyEnt.count = index;
        this.inuse = true;
		
        return true; // a translocator has been correctly spawned
    }

	void pain( Entity @other, float kick, float damage )
	{
		this.bodyEnt.modelindex = prcTransBodyDamagedModelIndex;
	}

    void die( Entity @inflictor, Entity @attacker )
    {
        if ( !this.inuse )
            return;

        this.Free();
    }

	// Returns null if teleportation cannot be done.
	// Note: player should be unlinked
	array<Entity @> @getPlayerBoxTelefraggableEntities( const Vec3 &in origin )
	{	
		if ( !this.inuse || @this.bodyEnt == null || @this.player == null )
			return null;
		
		// Based on the native KillBox() (g_utils.cpp).

		array<Entity @> result( 0 );
		// Contains temporarily unlinked entities.
		// We can't always do kill these entities as in KillBox()
		// because this method is used for translocator position validation too.
		array<Entity @> unlinkedEntities( 0 );
		
		bool failed = false;
		Trace trace;
		// While there are no entities in the box		
		while ( true )
		{
			trace.doTrace( origin, translocationTestMins, translocationTestMaxs, origin, this.bodyEnt.entNum, MASK_PLAYERSOLID );
			if ( ( trace.fraction == 1.0f && !trace.startSolid ) )
				break;

			// A world is in the box
			if ( trace.entNum == 0 )
			{
				failed = true;
				break;
			}
			
			Entity @ent = @G_GetEntity( trace.entNum );
			// Skip non-solid entities			
			if ( ent.solid != SOLID_YES )
			{
				ent.unlinkEntity();
				unlinkedEntities.insertLast( ent );
				continue;
			}
			// Skip owner
			if ( @ent == @this.player.ent )
			{
				ent.unlinkEntity();
				unlinkedEntities.insertLast( ent );
				continue;
			}

			// Wouldn't kill the entity
			if ( ent.takeDamage == 0 )
			{
				failed = true;
				break;
			};
			
			ent.unlinkEntity();
			unlinkedEntities.insertLast( ent );
			result.insertLast( ent );
		}

		// Link entities again
		for ( uint i = 0; i < unlinkedEntities.size(); ++i )
		{
			unlinkedEntities[i].linkEntity();
		}
		
		return failed ? null : @result;
	}
}

void translocator_body_pain( Entity @ent, Entity @other, float kick, float damage )
{
	if ( ent.count >= 0 && ent.count < MAX_TRANSLOCATORS )
		gtTranslocators[ent.count].pain( other, kick, damage );
}

void translocator_body_die( Entity @self, Entity @inflictor, Entity @attacker )
{
    if ( self.count >= 0 && self.count < MAX_TRANSLOCATORS )
        gtTranslocators[self.count].die( inflictor, attacker );
}

void translocator_body_think( Entity @self )
{
    // if for some reason the translocator moved to bad area, kill it
    if ( ( G_PointContents( self.origin ) & (CONTENTS_SOLID|CONTENTS_NODROP|CONTENTS_LAVA|CONTENTS_SLIME) ) != 0 )
    {
        translocator_body_die( self, @G_GetEntity(0), @G_GetEntity(0) );
        return;
    }

	if ( self.count < 0 || self.count >= MAX_TRANSLOCATORS )
	{
		translocator_body_die( self, @G_GetEntity(0), @G_GetEntity(0) );
        return;
	}

	cTranslocator @trans = gtTranslocators[self.count];
	if ( trans.returnTime > levelTime )
	{
		self.nextThink = levelTime + 1;
		return;
	}
	
	if ( @trans.player != null )
	{
		// Do not return translocator if it has been activated
		if ( trans.player.isTranslocating || trans.player.hasJustTranslocated )
		{
			self.nextThink = levelTime + 1;
		}
		else
		{
			trans.player.returnTranslocator();
		}
		return;
	}	
	
	translocator_body_die( self, @G_GetEntity(0), @G_GetEntity(0) );
}

cTranslocator @ClientThrowTranslocator( Client @client )
{
    if ( @client == null )
        return null;

    cTranslocator @trans = null;

    // find an unused bomb slot
    for ( int i = 0; i < MAX_TRANSLOCATORS; i++ )
    {
        if ( gtTranslocators[i].inuse == false )
        {
            @trans = @gtTranslocators[i];
            break;
        }
    }

    if ( @trans == null )
    {
        // let the clients read this, so they complaint to us in case it's happening
        client.printMessage( "GT ERROR: ClientThrowTranslocator(): MAX_TRANSLOCATORS reached. Can't spawn a translocator.\n" );
        return null;
    }

    // nodrop area
    if ( ( G_PointContents( client.getEnt().origin ) & CONTENTS_NODROP ) != 0 )
        return null;

    // first check that there's space for spawning the translocator in front of us
    Vec3 dir, start, end, r, u;

    client.getEnt().angles.angleVectors( dir, r, u );
    start = client.getEnt().origin + Vec3( 0, 0, client.getEnt().viewHeight ) + ( dir * 64 );
    end = ( start + ( 0.5 * ( translocatorMaxs + translocatorMins) ) ) + ( dir * 96 );

    Trace tr;

    if ( tr.doTrace( start, translocatorMins, translocatorMaxs, end, client.getEnt().entNum, MASK_PLAYERSOLID ) )
		return null;

    if ( !trans.Spawn( start, client ) ) // can't spawn a translocator in that position. Blocked by something
        return null;

    dir.normalize();
    dir *= 1450;
	dir.z += 150;

    trans.bodyEnt.velocity = dir;
    trans.bodyEnt.linkEntity();

    return @trans;
}
