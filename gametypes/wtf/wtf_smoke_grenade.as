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

const uint WTF_SMOKE_EMITTER_EMISSION_TIME = 250;
const uint WTF_SMOKE_EMITTER_DECAY_TIME = 3000;

Entity @ClientThrowSmokeGrenade( Client @client )
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
    end = start + dir * 64;

    Trace tr;

    if ( tr.doTrace( start, vec3Origin, vec3Origin, end, client.getEnt().entNum, MASK_PLAYERSOLID ) )
		return null;

	Entity @ent = @G_SpawnEntity( "smoke_grenade" );
	
	@ent.think = smoke_grenade_think;
    ent.type = ET_GENERIC;
    ent.modelindex = G_ModelIndex( "models/objects/projectile/glauncher/grenadestrong.md3", false );
    ent.setSize( vec3Origin, vec3Origin );
    ent.team = client.getEnt().team;
    ent.ownerNum = client.playerNum;
    ent.origin = start;
    ent.solid = SOLID_NOT;
    ent.clipMask = MASK_PLAYERSOLID;
    ent.moveType = MOVETYPE_BOUNCEGRENADE;
    ent.svflags &= ~SVF_NOCLIENT;
    ent.health = 999;
    ent.mass = 50;
    ent.takeDamage = 0;
    ent.nextThink = levelTime + WTF_GRENADE_TIMEOUT;
    
    // assign some frontal velocity to the grenade, as for being dropped by the player
    dir.normalize();
    dir *= WTF_GRENADE_SPEED;

    ent.velocity = dir;
    ent.linkEntity();

    return @ent;
}

// Picks best position for an emitter
// (if an emitter is bounded by a solid, particles appearance is ugly)
Vec3 WTF_AdjustSmokeEmitterOrigin( const Entity @parentEntity )
{
	Vec3 mins(-24, -24, -24);
	Vec3 maxs(+24, +24, +24);

	Vec3 initialOrigin( parentEntity.origin );
	const int ignoreEntNum = parentEntity.entNum;

	Trace trace;
	trace.doTrace( initialOrigin, mins, maxs, initialOrigin, ignoreEntNum, MASK_PLAYERSOLID );
	if ( trace.fraction == 1.0f && !trace.startSolid )
		return initialOrigin;

	for ( int i = -1; i <= 1; ++i )
	{
		for ( int j = -1; j <= 1; ++j )
		{
			for ( int k = -1; k <= 1; ++k )
			{
				// Skip already tested exact initialOrigin position
				if ( i == 0 && j == 0 && k == 0 )
					continue;

				Vec3 origin( initialOrigin.x + 40.0f * i, initialOrigin.y + 40.0f * j, initialOrigin.z + 40.0f * k );
				trace.doTrace( origin, mins, maxs, origin, ignoreEntNum, MASK_PLAYERSOLID );
				if ( trace.fraction != 1.0f || trace.startSolid )
					continue;

				// Prevent spawning an emitter behind thin walls
				if ( !trace.doTrace( origin, vec3Origin, vec3Origin, initialOrigin, ignoreEntNum, MASK_SOLID ) )
					return origin;
			}
		}
	}

	return initialOrigin;
}

void smoke_grenade_think( Entity @grenade )
{
	Entity @emitter = @G_SpawnEntity( "smoke_emitter" );
    emitter.type = ET_PARTICLES;
    emitter.origin = WTF_AdjustSmokeEmitterOrigin( grenade );
    emitter.particlesSpeed = 160;
    emitter.particlesShaderIndex = G_ImageIndex( "gfx/wtf/smoke" );
    emitter.particlesSpread = 250;
    emitter.particlesSize = 90;
    emitter.particlesTime = ( WTF_SMOKE_EMITTER_EMISSION_TIME + WTF_SMOKE_EMITTER_DECAY_TIME ) / 1000;
    emitter.particlesFrequency = 48;
    emitter.particlesSpherical = true;
    emitter.particlesBounce = true;
    emitter.particlesGravity = true;
    emitter.particlesExpandEffect = true;
    emitter.svflags &= ~uint(SVF_NOCLIENT);
	emitter.team = grenade.team;
	emitter.count = 0;
	@emitter.think = smoke_emitter_think;
	emitter.nextThink = levelTime + WTF_SMOKE_EMITTER_EMISSION_TIME;

	grenade.freeEntity();

	emitter.linkEntity();
}

void smoke_emitter_think( Entity @emitter )
{
	// The emitter has already stopped emission WTF_SMOKE_EMITTER_DECAY_TIME ago
	if ( emitter.count != 0 )
	{
		emitter.freeEntity();
		return;
	}
	// Stop emitting particles but keep the entity for hidename cloud tests 
	emitter.nextThink = levelTime + WTF_SMOKE_EMITTER_DECAY_TIME;
	emitter.particlesFrequency = 0;
	emitter.count = 1;
}
