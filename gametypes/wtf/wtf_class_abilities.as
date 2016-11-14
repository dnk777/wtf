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

void CTFT_DropTurret( Client @client )
{
	if( @client == null )
		return;

    if ( client.getEnt().isGhosting() )
        return;

	cPlayer @player = @GetPlayer( client );

    if ( player.playerClass.tag != PLAYERCLASS_ENGINEER )
        return;

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
			
        client.stats.addScore( 2 );
    }
}

// KIKI WAnts BIG BOOM!!
void CTFT_DropBomb( Client @client )
{
	if( @client == null )
		return;

    if ( client.getEnt().isGhosting() )
        return;

    cPlayer @player = @GetPlayer( client );

	if( @player.bomb != null )
	{
		if ( player.bomb.explodeTime > 0 )
			return;
			
		player.bomb.setExplode();
		return;
	}

    if ( player.isBombCooldown() )
    {
        client.printMessage( "You can't throw a bomb yet\n" );
        return;
    }

    if ( client.armor < ( CTFT_TURRET_AP_COST ) )
    {
        client.printMessage( "You don't have enough armor to spawn a bomb\n" );
    }
    else
    {
        cBomb @bomb = ClientDropBomb( client );
        if ( @bomb != null )
        {
            client.armor = client.armor - ( CTFT_TURRET_AP_COST ); // Costs the same as turret
			player.setBombCooldown();
			@player.bomb = bomb;
        }
    }
}
