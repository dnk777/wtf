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

	// hack for entities status
	if ( token == "status" )
	{
		CTFT_PrintBuiltEntitiesStatus( client, player );
		return;
	}

	if ( player.isEngineerBuildCooldown() )
    {
        client.printMessage( "You cannot build yet\n" );
        return;
    }

	for ( cFlagBase @flagBase = @fbHead; @flagBase != null; @flagBase = @flagBase.next )
	{
		if( flagBase.owner.origin.distance( client.getEnt().origin ) < CTFT_BUILD_RADIUS )
		{
			client.printMessage( "Too close to the flag, cannot build here\n" );
			return;
		}
	}

    if ( client.armor < CTFT_TURRET_AP_COST )
    {
        client.printMessage( "You don't have enough armor to build\n" );
		return;
    }


	if ( token == "turret" )
	{
		CTFT_BuildTurret( client, player );
		return;
	}

	if ( token == "pad" )
	{
		CTFT_BuildBouncePad( client, player );
		return;
	}

	client.printMessage( "Illegal command usage. Available arguments: ^6turret^7, ^6pad^7, ^6status^7.\n" );
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

	// hack for entities status
	if ( token == "status" )
	{
		CTFT_PrintBuiltEntitiesStatus( client, player );
		return;
	}

	if ( token == "turret" )
	{
		CTFT_DestroyTurret( client, player );
		return;
	}

	if ( token == "pad" )
	{
		CTFT_DestroyBouncePad( client, player );
		return;
	}

	client.printMessage( "Illegal command usage. Available arguments: ^6turret^7, ^6pad^7, ^6status^7.\n" );
}

void CTFT_BuildTurret( Client @client, cPlayer @player )
{
    if ( @player.turret != null )
    {
        client.printMessage( "You have already built a turret\n" );
        return;
    }

    cTurret @turret = ClientDropTurret( client );
	if ( @turret == null )
		return;

    @turret.client = @client;
    client.armor = client.armor - CTFT_TURRET_AP_COST;

    @player.turret = @turret;
    // have a delay before being able to build again
    player.setEngineerBuildCooldown();

	if ( player.turretHealthWhenDestroyed < CTFT_TURRET_HEALTH )
	{
		if ( levelTime - player.turretDestroyedAtTime < CTFT_FAST_REPAIR_TIME )
		{
			if ( player.turretHealthWhenDestroyed < 0 )
				player.turretHealthWhenDestroyed = 0;

			uint bonus = uint( 0.01f * ( CTFT_TURRET_HEALTH - player.turretHealthWhenDestroyed ) );
			if ( bonus > 0 )
			{
				player.client.stats.addScore( bonus );
				player.client.addAward( S_COLOR_CYAN + "Fast repair!" );
			} 
		}
	}
}

void CTFT_BuildBouncePad( Client @client, cPlayer @player )
{
	if ( @player.bouncePad != null )
	{
		client.printMessage( "You have already built a bounce pad\n" );
		return;
	}

	cBouncePad @bouncePad = ClientDropBouncePad( client );
	if ( @bouncePad == null )
		return;

	client.armor -= CTFT_TURRET_AP_COST;

	@player.bouncePad = bouncePad;
	player.setEngineerBuildCooldown();

	if ( player.bouncePadHealthWhenDestroyed < CTFT_BOUNCE_PAD_HEALTH )
	{
		if ( levelTime - player.bouncePadDestroyedAtTime < CTFT_FAST_REPAIR_TIME )
		{
			if ( player.bouncePadHealthWhenDestroyed < 0 )
				player.bouncePadHealthWhenDestroyed = 0;

			uint bonus = uint( 0.03f * ( CTFT_BOUNCE_PAD_HEALTH - player.bouncePadHealthWhenDestroyed ) );
			if ( bonus > 0 )
			{
				player.client.stats.addScore( bonus );
				player.client.addAward( S_COLOR_CYAN + "Fast repair!" );
			} 
		}
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
	player.engineerBuildCooldownTime = levelTime + 750;
	client.armor += CTFT_TURRET_AP_COST;
}

void CTFT_DestroyBouncePad( Client @client, cPlayer @player )
{
	if ( @player.bouncePad == null )
	{
		client.printMessage( "There is no your bounce pad\n" );
		return;
	}

	player.bouncePad.die( null, null );
	@player.bouncePad = null;
	player.engineerBuildCooldownTime = levelTime + 750;
	client.armor += CTFT_TURRET_AP_COST;
}

void CTFT_PrintBuiltEntitiesStatus( Client @client, cPlayer @player )
{
	String message = "Built entites status: turret ";
	if ( @player.turret != null && @player.turret.bodyEnt != null )
	{
		int health = int( player.turret.bodyEnt.health );
		if ( health >= ( 2 * CTFT_TURRET_HEALTH ) / 3 )
			message += "^2";
		else if ( health > CTFT_TURRET_HEALTH / 3 )
			message += "^3";
		else
			message += "^1";
		message += health;
		message += "^7/";
		message += CTFT_TURRET_HEALTH;
	}
	else
		message += "not built";

	message += ", bounce pad ";
	if ( @player.bouncePad != null && @player.bouncePad.bodyEnt != null )
	{
		int health = int( player.bouncePad.bodyEnt.health );
		if ( health >= ( 2 * CTFT_BOUNCE_PAD_HEALTH ) / 3 )
			message += "^2";
		else if ( health > CTFT_BOUNCE_PAD_HEALTH / 3 )
			message += "^3";
		else
			message += "^1";
		message += health;
		message += "^7/";
		message += CTFT_BOUNCE_PAD_HEALTH;
	}
	else
		message += "not built";

	message += "\n";
	client.printMessage( message );
}

void CTFT_DeployCommand( Client @client, const String &argsString, int argc )
{
	if ( @client == null )
		return;

	if ( client.getEnt().isGhosting() )
		return;

	cPlayer @player = @GetPlayer( client );
	if ( player.playerClass.tag == PLAYERCLASS_GUNNER )
	{
		player.deploy();
		return;
	}

	client.printMessage( "This command is not available for your class\n" );
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

	if ( player.playerClass.tag == PLAYERCLASS_MEDIC )
	{
		CTFT_ThrowBioGrenade( client, player );
		return;
	}

	if ( player.playerClass.tag == PLAYERCLASS_SUPPORT )
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

    if ( player.isGruntAbilityCooldown() )
    {
        client.printMessage( "You can't throw a cluster grenade yet\n" );
        return;
    }

    if ( client.armor < CTFT_CLUSTER_GRENADE_AP_COST )
    {
        client.printMessage( "You don't have enough armor to throw a grenade\n" );
    }
    else
    {
        cBomb @bomb = ClientDropBomb( client );
        if ( @bomb != null )
        {
            client.armor -= CTFT_CLUSTER_GRENADE_AP_COST;
			player.setGruntAbilityCooldown();
			@player.bomb = bomb;
        }
    }
}

void CTFT_ThrowSmokeGrenade( Client @client, cPlayer @player )
{
	if ( player.playerClass.tag != PLAYERCLASS_RUNNER )
	{
		client.printMessage( "This command is not available for your class\n" );
		return;
	}

    if ( client.armor < CTFT_SMOKE_GRENADE_AP_COST )
    {
        client.printMessage( "You don't have enough armor to throw a grenade\n" );
    }
    else
    {
        Entity @grenade = ClientThrowSmokeGrenade( client );
        if ( @grenade != null )
		{
            client.armor -= CTFT_SMOKE_GRENADE_AP_COST;
        }
    }
}

void CTFT_ThrowBioGrenade( Client @client, cPlayer @player )
{
	if ( player.playerClass.tag != PLAYERCLASS_MEDIC )
	{
		client.printMessage( "This command is not available for your class\n" );
		return;
	}

	if ( player.isBioGrenadeCooldown() )
	{
		client.printMessage( "You can't throw a grenade yet\n" );
		return;
	}

    if ( player.ent.health < CTFT_BIO_GRENADE_HEALTH_COST + 15 )
    {
        client.printMessage( "You don't have enough health to throw a grenade\n" );
		return;
    }
    
	if ( @ClientThrowBioGrenade( client ) != null )
	{
        player.ent.health -= CTFT_BIO_GRENADE_HEALTH_COST;
		player.setBioGrenadeCooldown();
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
	Vec3 fireOrigin( ent.origin );
	fireOrigin.z += ent.viewHeight;
	if ( @G_FireWeakBolt( fireOrigin, ent.angles, 8000, CTFT_BLAST_DAMAGE, 100, 1000, ent ) != null )
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

	if ( player.playerClass.tag == PLAYERCLASS_RUNNER )
	{
		CTFT_ThrowSmokeGrenade( client, player );
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
	if ( client.armor < player.playerClass.maxArmor - 25 )
	{
		client.printMessage( "You do not have enough armor to supply ammo\n" );
		return;
	}

	player.hasPendingSupplyAmmoCommand = true;
	client.armor -= ( player.playerClass.maxArmor - 25 );
}

void CTFT_SupplyAdrenaline( Client @client, cPlayer @player )
{
	if ( client.armor < 50 )
	{
		client.printMessage( "You do not have enough armor to supply adrenaline\n" );
		return;
	}

	player.hasPendingSupplyAdrenalineCommand = true;
	client.armor -= 50;
}

void CTFT_BuyInstaShot( Client @client, cPlayer @player )
{
	if ( client.armor < 45 )
	{
		client.printMessage( "You do not have enough armor to buy an insta shot\n");
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
}

void CTFT_TransCommand( Client @client, String &argsString, int argc )
{
	if ( @client == null )
		return;

	if ( client.getEnt().isGhosting() )
		return;

	cPlayer @player = GetPlayer( client );

	if ( player.playerClass.tag != PLAYERCLASS_RUNNER )
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

	if ( token == "throw" )
	{
		player.throwTranslocator();
		return;
	}
	if ( token == "check" )
	{
		player.checkTranslocator();
		return;
	}
	if ( token == "return" )
	{
		player.returnTranslocator();
		return;
	}
	if ( token == "use" )
	{
		player.useTranslocator();
		return;
	}

	client.printMessage( "Illegal command usage. Available arguments: ^6throw^7, ^6check^7, ^6return^7, ^6use^7\n" );
}

void CTFT_Classaction1Command( Client @client )
{
	if ( @client == null )
		return;

	if ( client.getEnt().isGhosting() )
		return;

	cPlayer @player = GetPlayer( client );

	switch ( player.playerClass.tag )
	{
		case PLAYERCLASS_GRUNT:
			player.activateShell();
			break;
		case PLAYERCLASS_MEDIC:
			CTFT_ThrowBioGrenade( client, player );
			break;
		case PLAYERCLASS_RUNNER:
			if ( @player.translocator == null )
				player.throwTranslocator();
			else
				player.useTranslocator();
			break;
		case PLAYERCLASS_GUNNER:
			player.activateInvisibility();			
			break;
		case PLAYERCLASS_SUPPORT:
			CTFT_Blast( client, player );
			break;
		case PLAYERCLASS_SNIPER:
			CTFT_BuyInstaShot( client, player );
			break;
	}
}

void CTFT_Classaction2Command( Client @client )
{
	if ( @client == null )
		return;

	if ( client.getEnt().isGhosting() )
		return;

	cPlayer @player = GetPlayer( client );

	switch ( player.playerClass.tag )
	{
		case PLAYERCLASS_GRUNT:
			CTFT_ThrowClusterGrenade( client, player );
			break;
		case PLAYERCLASS_MEDIC:
			CTFT_SupplyAdrenaline( client, player );
			break;
		case PLAYERCLASS_RUNNER:
			CTFT_ThrowSmokeGrenade( client, player );
			break;
		case PLAYERCLASS_GUNNER:
			player.deploy();			
			break;
		case PLAYERCLASS_SUPPORT:
			CTFT_SupplyAmmo( client, player );
			break;
		case PLAYERCLASS_SNIPER:
			CTFT_BuyInstaShot( client, player );
			break;
	}
}

