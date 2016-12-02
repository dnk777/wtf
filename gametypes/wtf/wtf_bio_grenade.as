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

Entity @ClientThrowBioGrenade( Client @client )
{
    if ( @client == null )
        return null;

    // nodrop area
    if ( ( G_PointContents( client.getEnt().origin ) & CONTENTS_NODROP ) != 0 )
        return null;

    // first check that there's space for spawning the bomb in front of us
    Vec3 dir, start, end, r, u;

    client.getEnt().angles.angleVectors( dir, r, u );
    start = client.getEnt().origin + Vec3( 0, 0, client.getEnt().viewHeight ) + ( dir * 48 );
    end = ( start + ( 0.5 * ( bombMaxs + bombMins) ) ) + ( dir * 64 );

    Trace tr;

    if ( tr.doTrace( start, vec3Origin, vec3Origin, end, client.getEnt().entNum, MASK_PLAYERSOLID ) )
		return null;

	Entity @ent = @G_SpawnEntity( "bio_grenade_projectile" );
	
	@ent.touch = @bio_grenade_touch;
    ent.type = ET_GENERIC;
    ent.modelindex = G_ModelIndex( "models/objects/projectile/glauncher/grenadestrong.md3", false );
    ent.setSize( vec3Origin, vec3Origin );
    ent.team = client.getEnt().team;
    ent.ownerNum = client.playerNum;
    ent.origin = start;
    ent.solid = SOLID_TRIGGER;
    ent.clipMask = MASK_PLAYERSOLID;
    ent.moveType = MOVETYPE_TOSS;
    ent.svflags &= ~SVF_NOCLIENT;
    ent.health = 999;
    ent.mass = 50;
    ent.takeDamage = 0;
    
    // assign some frontal velocity to the grenade, as for being dropped by the player
    dir.normalize();
    dir *= 750;
    dir.z += 150;

    ent.velocity = dir;
    ent.linkEntity();

    return @ent;
}


void CTFT_SpawnBioSparksEmitter( int ownerNum, const Vec3 &in origin, int showToTeam, int shaderIndex )
{
	Entity @emitter = @G_SpawnEntity( "bio_grenade_sparks_emitter" );
	emitter.type = ET_PARTICLES;
	emitter.origin = origin;
	emitter.particlesSpeed = 140;
	emitter.particlesShaderIndex = shaderIndex;
	emitter.particlesSpread = 50;
	emitter.particlesSize = 8;
	emitter.particlesTime = 1;
	emitter.particlesFrequency = 15;
	emitter.particlesSpherical = true;
	emitter.particlesBounce = false;
	emitter.particlesGravity = false;
	emitter.particlesExpandEffect = false;
	emitter.svflags &= ~uint(SVF_NOCLIENT);
	emitter.svflags |= uint(SVF_ONLYTEAM);
	emitter.team = showToTeam;
	@emitter.think = bio_sparks_emitter_think;
	emitter.nextThink = levelTime + 700;
	emitter.linkEntity();
}

void bio_grenade_touch( Entity @self, Entity @other, const Vec3 planeNormal, int surfFlags )
{
	if ( G_PointContents( self.origin ) & (CONTENTS_NODROP|CONTENTS_LAVA|CONTENTS_SLIME) != 0 )
	{
		self.freeEntity();
		return;
	}

	Entity @owner = G_GetClient( self.ownerNum ).getEnt();
	if ( @owner == @other )
		return;

	other.splashDamage( owner, CTFT_BIO_GRENADE_RADIUS, 75, 50, 500, MOD_GRENADE_W );

	// Offset the emitter a bit (otherwise it looks poor).
	Vec3 origin = self.origin + 10 * planeNormal;

	// Spawn cloud emitter
	Entity @emitter = @G_SpawnEntity( "bio_grenade_cloud_emitter" );
	emitter.type = ET_PARTICLES;
	emitter.origin = origin;
	emitter.particlesSpeed = 70;
	emitter.particlesShaderIndex = prcBioCloudShaderIndex;
	emitter.particlesSpread = 50;
	emitter.particlesSize = 10;
	emitter.particlesTime = 2;
	emitter.particlesFrequency = 30;
	emitter.particlesSpherical = true;
	emitter.particlesBounce = true;
	emitter.particlesGravity = false;
	emitter.particlesExpandEffect = true;
	emitter.svflags &= ~uint(SVF_NOCLIENT);
	emitter.team = self.team;
	// Hack! ownerNum is overwritten for particles! Keep entity num of the owner in maxHealth.
	emitter.maxHealth = self.ownerNum + 1;
	emitter.count = CTFT_BIO_GRENADE_DECAY;
	@emitter.think = bio_cloud_emitter_think; 
	emitter.nextThink = levelTime + 1;
	emitter.linkEntity();

	int enemyTeam = ( self.team == TEAM_ALPHA ) ? TEAM_BETA : TEAM_ALPHA;

	CTFT_SpawnBioSparksEmitter( self.ownerNum, origin, self.team, prcBioTeamSparksShaderIndex );
	CTFT_SpawnBioSparksEmitter( self.ownerNum, origin, enemyTeam, prcBioEnemySparksShaderIndex );

	emitter.explosionEffect( 96 );
	G_Sound( emitter, CHAN_AUTO, prcBioEmissionSound, ATTN_NORM );

	self.freeEntity();
}

void bio_sparks_emitter_think( Entity @self )
{
	self.freeEntity();
}

void bio_cloud_emitter_think( Entity @self )
{
	if ( self.count < 0 )
	{
		self.freeEntity();
		return;
	}
	if ( self.count < CTFT_BIO_GRENADE_DECAY - 500 )
	{
		// Keep the entity but stop emitting particles
		self.particlesFrequency = 0;
	}
	self.count -= frameTime;
	self.nextThink = levelTime + 1;	

	// Hack! See spawning of this entity for description.
	Entity @owner = G_GetEntity( self.maxHealth );
	const float damagePerFrame = 150 * 0.001f * frameTime;
	const float knockbackPerFrame = 150 * 0.001f * frameTime;
	array<Entity @> @inradius = G_FindInRadius( self.origin, CTFT_BIO_GRENADE_RADIUS );
	for ( uint i = 0; i < inradius.size(); ++i )
	{
		Entity @ent = inradius[i];
		if ( @ent.client == null )
			continue;
		
		if ( ent.isGhosting() )
			continue;

		if ( !G_InPVS( self.origin, ent.origin ) )
			continue;

		if ( ent.team == self.team )
		{
			// TODO: Indicate it somehow for observers
			ent.health += 20 * 0.001f * frameTime;
			continue;
		}

		float distance = self.origin.distance( ent.origin );
		float damageScale = 0.6f + 0.4f * distance / CTFT_BIO_GRENADE_RADIUS;
		// Damage has "magnetic effect"
		Vec3 damageDir = self.origin - ent.origin;
		damageDir.normalize();
		ent.sustainDamage( self, owner, damageDir, damageScale * damagePerFrame, knockbackPerFrame, 100, 0 );
	}
}
