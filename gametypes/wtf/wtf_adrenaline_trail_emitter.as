void WTF_AddAdrenalineTrailEmitter( Entity @target )
{
	Entity @emitter = @G_SpawnEntity( "adrenaline_trail_emitter" );
	emitter.type = ET_PARTICLES;
	emitter.origin = target.origin;
	emitter.angles = vec3Origin - target.angles;
	emitter.particlesSpeed = 120;
	emitter.particlesShaderIndex = prcAdrenalineTrailEmitterShaderIndex;
	emitter.particlesSpread = 100;
	emitter.particlesSize = 3;
	emitter.particlesTime = 1;
	emitter.particlesFrequency = 15;
	emitter.particlesSpherical = false;
	emitter.particlesBounce = false;
	emitter.particlesGravity = false;
	emitter.particlesExpandEffect = false;
	emitter.svflags &= ~uint(SVF_NOCLIENT);
	emitter.team = target.team;
	// Hack! ownerNum is overwritten for particles! Keep entity num of the owner in maxHealth.
	emitter.maxHealth = target.entNum;
	emitter.count = WTF_ADRENALINE_TIME;
	@emitter.think = @wtf_adrenaline_emitter_think; 
	emitter.nextThink = levelTime + 1;
	emitter.linkEntity();
}

void wtf_adrenaline_emitter_think( Entity @emitter )
{
	int ownerNum = emitter.maxHealth;
	if ( ownerNum < 1 || ownerNum > maxClients )
	{
		emitter.freeEntity();
		return;
	}
	
	Entity @owner = @G_GetEntity( ownerNum );
	if ( owner.isGhosting() )
	{
		emitter.freeEntity();
		return;
	}

	emitter.count -= frameTime;
	if ( emitter.count < 0 )
	{
		emitter.freeEntity();
		return;
	} 

	
	// update emitter origin/angles	
	emitter.origin = owner.origin;
	emitter.angles = vec3Origin - owner.angles;
	emitter.linkEntity();

	// schedule next update
	emitter.nextThink = levelTime + 1;
}
