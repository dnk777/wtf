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

void ThrowSmokeGrenade( Client @client, cPlayer @player )
{
	if ( player.playerClass.tag != PLAYERCLASS_SUPPORT )
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

void ThrowBioGrenade( Client @client, cPlayer @player )
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

void ClassactionCommand( Client @client )
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
			ThrowBioGrenade( client, player );
			break;
		case PLAYERCLASS_RUNNER:
			player.throwOrUseTranslocator();
			break;
		case PLAYERCLASS_INFILTRATOR:
			player.activateInvisibility();			
			break;
		case PLAYERCLASS_SUPPORT:
			ThrowSmokeGrenade( client, player );
			break;
		case PLAYERCLASS_SNIPER:
			player.buildOrDestroyMotionDetector();
			break;
	}
}

