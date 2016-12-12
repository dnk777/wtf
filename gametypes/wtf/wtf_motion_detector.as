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

const Vec3 motionDetectorMins( -8, -8, -8 );
const Vec3 motionDetectorMaxs( +8, +8, +8 );

Entity @ClientThrowMotionDetector( Client @client )
{
    if ( @client == null )
        return null;

    // nodrop area
    if ( ( G_PointContents( client.getEnt().origin ) & CONTENTS_NODROP ) != 0 )
        return null;

    // first check that there's space for spawning the entity in front of us
    Vec3 dir, start, end, r, u;

    client.getEnt().angles.angleVectors( dir, r, u );
    start = client.getEnt().origin + Vec3( 0, 0, client.getEnt().viewHeight ) + ( dir * 48 );
    end = start + dir * 96;

    Trace tr;

    if ( tr.doTrace( start, motionDetectorMins, motionDetectorMaxs, end, client.getEnt().entNum, MASK_PLAYERSOLID ) )
		return null;

	Entity @ent = @G_SpawnEntity( "motion_detector" );
	
	@ent.stop = @motion_detector_stop;
	@ent.die = @motion_detector_die;
    ent.type = ET_GENERIC;
    ent.modelindex = G_ModelIndex( "models/wtf/motion_detector.md3", false );
    ent.setSize( motionDetectorMins, motionDetectorMaxs );
    ent.team = client.getEnt().team;
    ent.ownerNum = client.playerNum;
    ent.origin = start;
    ent.solid = SOLID_YES;
    ent.clipMask = MASK_SOLID;
    ent.moveType = MOVETYPE_TOSS;
	ent.takeDamage = DAMAGE_NO;
    ent.svflags &= ~SVF_NOCLIENT;
    ent.health = 10;
    ent.mass = 50;
    
    dir.normalize();
    dir *= CTFT_GRENADE_SPEED;

    ent.velocity = dir;
    ent.linkEntity();

	@ent.think = @motion_detector_think;
	ent.nextThink = levelTime + 128;

    return @ent;
}

void motion_detector_stop( Entity @self )
{
	if ( G_PointContents( self.origin ) & (CONTENTS_NODROP|CONTENTS_LAVA|CONTENTS_SLIME) != 0 )
	{		
		Client @ownerClient = @G_GetClient( self.ownerNum );
		if ( @ownerClient != null )
		{
			GetPlayer( ownerClient ).motionDetectorBuildingCanceled();
		}
		self.freeEntity();
		return;
	}

	@self.touch = null;
	// Become sticky
	self.moveType = MOVETYPE_NONE;
	self.takeDamage = DAMAGE_YES;
}

void motion_detector_die( Entity @self, Entity @inflictor, Entity @attacker )
{
	Client @ownerClient = @G_GetClient( self.ownerNum );
	if ( @ownerClient != null )
		GetPlayer( ownerClient ).motionDetectorDestroyed();
	
	self.freeEntity();
}

void motion_detector_think( Entity @self )
{
	Client @ownerClient = @G_GetClient( self.ownerNum );
	if ( @ownerClient == null )
		return;
	
	if ( ownerClient.state() < CS_SPAWNED )
	{
		motion_detector_die( self, null, null );
		return;
	}

	if ( ownerClient.getEnt().team != self.team )
	{
		motion_detector_die( self, null, null );
		return;
	}

	if ( GetPlayer( ownerClient ).playerClass.tag != PLAYERCLASS_SNIPER )
	{	
		motion_detector_die( self, null, null );
		return;
	}

	// No need to check it each frame
	self.nextThink = levelTime + 128; 
}
