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

void CTFT_BuildCommand( Client @client, const String &argsString, int argc )
{
	if( @client == null )
		return;

    if ( client.getEnt().isGhosting() )
        return;

	cPlayer @player = @GetPlayer( client );

    if ( player.playerClass.tag != PLAYERCLASS_ENGINEER )
    {
		client.printMessage( "This command is not available for your class\n" );
		return;
	}

	if ( argc != 1 )
	{
		client.printMessage( "Illegal command usage (a single argument is expected)\n" );
		return;
	}

	String token = argsString.getToken( 0 );

	if ( token == "turret" )
	{
		CTFT_BuildTurret( client, player );
		return;
	}

	client.printMessage( "Illegal command usage. Available arguments: `turret`" );
}

void CTFT_DestroyCommand( Client @client, const String &argsString, int argc )
{
	if( @client == null )
		return;

    if ( client.getEnt().isGhosting() )
        return;

	cPlayer @player = @GetPlayer( client );

    if ( player.playerClass.tag != PLAYERCLASS_ENGINEER )
    {
		client.printMessage( "This command is not available for your class\n" );
		return;
	}

	if ( argc != 1 )
	{
		client.printMessage( "Illegal command usage (a single argument is expected)\n" );
		return;
	}

	String token = argsString.getToken( 0 );

	if ( token == "turret" )
	{
		CTFT_DestroyTurret( client, player );
		return;
	}

	client.printMessage( "Illegal command usage. Available arguments: `turret`" );
}

void CTFT_BuildTurret( Client @client, cPlayer @player )
{
    if ( @player.turret != null )
    {
        client.printMessage( "You have already spawned a turret\n" );
        return;
    }

    if ( player.isEngineerCooldown() )
    {
        client.printMessage( "You cannot spawn a turret yet\n" );
        return;
    }

	for ( cFlagBase @flagBase = @fbHead; @flagBase != null; @flagBase = @flagBase.next )
	{
		if( flagBase.owner.origin.distance( client.getEnt().origin ) < CTFT_BUILD_RADIUS )
		{
			client.printMessage( "Too close to the flag, cannot spawn a turret.\n" );
			return;
		}
	}

    if ( client.armor < CTFT_TURRET_AP_COST )
    {
        client.printMessage( "You don't have enough armor to spawn a turret\n" );
		return;
    }
        
    cTurret @turret = ClientDropTurret( client );
    if ( @turret != null )
    {
        turret.refireDelay = 100;
        turret.yawSpeed = 270.0f;
        turret.pitchSpeed = 170.0f;
        turret.gunOffset = 24;
		
        @turret.client = @client;
        client.armor = client.armor - CTFT_TURRET_AP_COST;

        @player.turret = @turret;
        // have a delay before being able to build again
        player.setEngineerCooldown();
		
		// Disabled since the ability to destroy a turret is added 
		// (otherwise an engineer can gain scores by building a turret and immediately destroying it)
        // client.stats.addScore( 2 );
    }
}

void CTFT_DestroyTurret( Client @client, cPlayer @player )
{
	if ( @player.turret == null )
	{
		client.printMessage( "There is no your turret\n" );
		return;
	}

	player.turret.die( null, null );
	@player.turret = null;
	player.engineerBuildCooldownTime = 0;
	client.armor += CTFT_TURRET_AP_COST;
}

void CTFT_AltAttackCommand( Client @client, const String &argsString, int argc )
{
	if ( @client == null )
		return;
	
	if ( client.getEnt().isGhosting() )
		return;

	cPlayer @player = @GetPlayer( client );

	if ( player.playerClass.tag == PLAYERCLASS_GRUNT )
	{
		CTFT_ThrowClusterGrenade( client, player );
		return;
	}

	if ( player.playerClass.tag == PLAYERCLASS_RUNNER )
	{
		CTFT_Blast( client, player );
		return;
	}

	client.printMessage( "This command is not available for your class\n" );
}

// KIKI WAnts BIG BOOM!!
void CTFT_ThrowClusterGrenade( Client @client, cPlayer @player )
{
	if ( player.playerClass.tag != PLAYERCLASS_GRUNT )
	{
		client.printMessage( "This command is not available for your class\n" );
		return;
	}

    if ( player.isGruntCooldown() )
    {
        client.printMessage( "You can't throw a bomb yet\n" );
        return;
    }

    if ( client.armor < ( CTFT_TURRET_AP_COST ) )
    {
        client.printMessage( "You don't have enough armor to throw a grenade\n" );
    }
    else
    {
        cBomb @bomb = ClientDropBomb( client );
        if ( @bomb != null )
        {
            client.armor = client.armor - ( CTFT_TURRET_AP_COST ); // Costs the same as turret
			player.setGruntCooldown();
			@player.bomb = bomb;
        }
    }
}

void CTFT_Blast( Client @client, cPlayer @player )
{
	if ( player.isBlastCooldown() )
	{
		client.printMessage( "You can't fire a blast yet\n" );
		return;
	}

	if ( client.armor < CTFT_BLAST_AP_COST )
	{
		client.printMessage( "You don't have enough armor to fire a blast\n" );
		return;
	}

	Entity @ent = client.getEnt();
	if ( @G_FireWeakBolt( ent.origin, ent.angles, 8000, CTFT_BLAST_DAMAGE, 100, 1000, ent ) != null )
	{
		player.setBlastCooldown();
		client.armor -= CTFT_BLAST_AP_COST;
	}
}

void CTFT_ProtectCommand( Client @client, const String &argsString, int argc )
{
	if ( @client == null )
		return;
	
	if ( client.getEnt().isGhosting() )
		return;

	cPlayer @player = @GetPlayer( client );

	if ( player.playerClass.tag == PLAYERCLASS_GRUNT )
	{
		player.activateShell();
		return;
	}

	if ( player.playerClass.tag == PLAYERCLASS_SNIPER )
	{
		player.activateInvisibility();
		return;
	}

	client.printMessage( "This command is not available for your class\n" );
}

void CTFT_SupplyCommand( Client @client, const String &argsString, int argc )
{
	if ( @client == null )
		return;

	if ( client.getEnt().isGhosting() )
		return;

	cPlayer @player = @GetPlayer( client );

	if ( player.playerClass.tag == PLAYERCLASS_MEDIC )
	{
		CTFT_SupplyAdrenaline( client, player );
		return;
	}

	if ( player.playerClass.tag == PLAYERCLASS_SUPPORT )
	{
		CTFT_SupplyAmmo( client, player );
		return;
	}
	
	if ( player.playerClass.tag == PLAYERCLASS_SNIPER )
	{
		CTFT_BuyInstaShot( client, player );	
		return;
	}

	client.printMessage( "This command is not available for your class\n" );
}

void CTFT_SupplyAmmo( Client @client, cPlayer @player )
{
	if ( client.armor < 85 )
	{
		client.printMessage( "You do not have enough armor to supply ammo\n" );
		return;
	}

	player.hasPendingSupplyAmmoCommand = true;
	client.armor -= 85;
}

void CTFT_SupplyAdrenaline( Client @client, cPlayer @player )
{
	if ( client.armor < 50 )
	{
		client.printMessage( "You do not have enough armor to supply adrenaline\n" );
		return;
	}

	if ( player.ent.health < 75 )
	{
		client.printMessage( "You do not have enough health to supply adrenaline\n" );
		return;
	}

	player.hasPendingSupplyAdrenalineCommand = true;
	client.armor -= 50;
	player.ent.health -= 50;
}

void CTFT_BuyInstaShot( Client @client, cPlayer @player )
{
	if ( client.armor < 45 )
	{
		client.printMessage( "You do not have enough armor to buy an insta shot\n");
		return;
	}
	
	if ( player.buyAmmoCooldownTime > levelTime )
	{
		client.printMessage( "You can't buy an insta shot yet\n" );
		return;
	}

	int instaAmmoCount = client.inventoryCount( AMMO_INSTAS );
	if ( instaAmmoCount >= 3 )
	{
		client.printMessage( "You can't have more than 3 insta shots\n" );
		return;
	}

	client.armor -= 45;
	client.inventorySetCount( AMMO_INSTAS, instaAmmoCount + 1 );
	player.buyAmmoCooldownTime = levelTime + 3000 + 5000 * instaAmmoCount;
}

