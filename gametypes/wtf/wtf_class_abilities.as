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

    if ( player.playerClass.tag != PLAYERCLASS_SNIPER )
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
		player.printBuiltEntitiesStatus();
		return;
	}

	if ( token == "detector" )
	{
		player.buildMotionDetector();
		return;
	}

	if ( token == "pad" )
	{
		player.buildBouncePad();
		return;
	}

	client.printMessage( "Illegal command usage. Available arguments: ^6detector^7, ^6pad^7, ^6status^7.\n" );
}

void CTFT_DestroyCommand( Client @client, const String &argsString, int argc )
{
	if( @client == null )
		return;

    if ( client.getEnt().isGhosting() )
        return;

	cPlayer @player = @GetPlayer( client );

    if ( player.playerClass.tag != PLAYERCLASS_SNIPER )
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
		player.printBuiltEntitiesStatus();
		return;
	}

	if ( token == "detector" )
	{
		player.destroyMotionDetector();
		return;
	}

	if ( token == "pad" )
	{
		player.destroyBouncePad();
		return;
	}

	client.printMessage( "Illegal command usage. Available arguments: ^6detector^7, ^6pad^7, ^6status^7.\n" );
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

	if ( @player.bomb != null )
	{
		client.printMessage( "You can't throw another grenade yet\n" );
		return;
	}

    if ( client.armor < CTFT_CLUSTER_GRENADE_AP_COST )
    {
        client.printMessage( "You don't have enough armor to throw a grenade\n" );
		return;
    }
    
    cBomb @bomb = ClientDropBomb( client );
    if ( @bomb != null )
    {
        client.armor -= CTFT_CLUSTER_GRENADE_AP_COST;
		@player.bomb = bomb;
    }
}

void CTFT_ThrowSmokeGrenade( Client @client, cPlayer @player )
{
	if ( player.playerClass.tag != PLAYERCLASS_RUNNER )
	{
		client.printMessage( "This command is not available for your class\n" );
		return;
	}

    if ( client.armor < WTF_SMOKE_GRENADE_AP_COST )
    {
        client.printMessage( "You don't have enough armor to throw a grenade\n" );
    }
    else
    {
        Entity @grenade = ClientThrowSmokeGrenade( client );
        if ( @grenade != null )
		{
            client.armor -= WTF_SMOKE_GRENADE_AP_COST;
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
	if ( client.armor < WTF_ADRENALINE_AP_COST )
	{
		client.printMessage( "You do not have enough armor to supply adrenaline\n" );
		return;
	}

	player.hasPendingSupplyAdrenalineCommand = true;
	client.armor -= WTF_ADRENALINE_AP_COST;
}

void CTFT_BuyInstaShot( Client @client, cPlayer @player )
{
	if ( client.armor < WTF_INSTA_SHOT_AP_COST )
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

	client.armor -= WTF_INSTA_SHOT_AP_COST;
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
			if ( player.repeatedCommandTime <= levelTime )
			{
				player.repeatedCommandTime = levelTime + 250;
				if ( @player.translocator == null )
					player.throwTranslocator();
				else
					player.useTranslocator();
			}
			break;
		case PLAYERCLASS_GUNNER:
			player.activateInvisibility();			
			break;
		case PLAYERCLASS_SUPPORT:
			CTFT_Blast( client, player );
			break;
		case PLAYERCLASS_SNIPER:
			if ( player.repeatedCommandTime > levelTime )
				break;

			player.repeatedCommandTime = levelTime + 250;
			if ( @player.motionDetector == null )
			{
				player.buildMotionDetector();
			}
			else if ( @player.bouncePad == null )
			{
				player.buildBouncePad();
				// Add an extra delay to prevent destroying built entities by confusion
				player.repeatedCommandTime += 350;
			}
			else 
			{	
				// We have to destroy all built entities together, not the first/last built.
				// Otherwise next command will just rebuild a destroyed entity, and another one will be kept.
				// Use specialized commands for full control over building/destroying entities.
				player.destroyMotionDetector();
				player.destroyBouncePad();
			}
			player.printBuiltEntitiesStatus();
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

