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

const int PLAYERCLASS_GRUNT = 0;
const int PLAYERCLASS_MEDIC = 1;
const int PLAYERCLASS_RUNNER = 2;
const int PLAYERCLASS_ENGINEER = 3;
const int PLAYERCLASS_SUPPORT = 4;
const int PLAYERCLASS_SNIPER = 5;

const int PLAYERCLASS_TOTAL = 6;

int[] playerClasses( maxClients ); // class of each player

// definition of the classes
class cPlayerClass
{
    int tag;
    int maxHealth;
	int armor;
	int maxArmor;
    int maxSpeed;
    int dashSpeed;
    int jumpSpeed;
    bool takeStun;
    int iconIndex;
    bool initialized;
    String name;
    String playerModel;
    int action1IconIndex;
    int action2IconIndex;

    cPlayerClass()
    {
        this.maxSpeed = -1;
        this.dashSpeed = -1;
        this.jumpSpeed = -1;
        this.maxHealth = 100;
		this.armor = 0;
		this.maxArmor = 50;
        this.takeStun = true;
        this.initialized = false;
        this.iconIndex = 0;
        this.tag = 0;
        this.action1IconIndex = 0;
        this.action2IconIndex = 0;
    }

    ~cPlayerClass() {}

    void setup( String &class_name, int tag, String &model, int health, int armor, int maxArmor, int maxSpeed, int dashSpeed, bool stun,
        const String &icon, const String @action1Icon, const String @action2Icon )
    {
        this.name = class_name;
        this.playerModel = model;
        this.maxHealth = health;
		this.armor = armor;
		this.maxArmor = maxArmor;
        this.dashSpeed = dashSpeed;
        this.maxSpeed = maxSpeed;
        this.takeStun = stun;

        if ( tag < 0 || tag >= PLAYERCLASS_TOTAL )
            G_Print( "WARNING: cPlayerClass::setup with a invalid tag " + tag + "\n" );
        else
            this.tag = tag;

        // precache
        G_ModelIndex( this.playerModel, true );
        this.iconIndex = G_ImageIndex( icon );
        if( @action1Icon != null )
            this.action1IconIndex = G_ImageIndex( action1Icon );
        if( @action2Icon != null )
            this.action2IconIndex = G_ImageIndex( action2Icon );

        this.initialized = true;
    }
}

cPlayerClass[] cPlayerClassInfos( PLAYERCLASS_TOTAL );

// Initialize player classes

void GENERIC_InitPlayerClasses()
{
    // precache the runner invisibility skin
    G_SkinIndex( "models/players/silverclaw/invisibility.skin" );

    for ( int i = 0; i < maxClients; i++ )
        playerClasses[ i ] = PLAYERCLASS_GRUNT;

    cPlayerClassInfos[ PLAYERCLASS_GRUNT ].setup(
        "Grunt",					// name
        PLAYERCLASS_GRUNT,
        "$models/players/bigvic",	// player model
        100,						// initial health
        25,						    // initial armor
		125,                        // max armor
        240,						// speed
        320,						// dash speed
        true,						// can be stunned
        "gfx/hud/icons/playerclass/wtf_grunt",
        "gfx/hud/icons/classactions/grunt1",
        "gfx/hud/icons/classactions/grunt2"
    );

    cPlayerClassInfos[ PLAYERCLASS_MEDIC ].setup(
        "Medic",					// name
        PLAYERCLASS_MEDIC,
        "$models/players/monada",	// player model
        100,						// initial health
        0,						    // initial armor
		75,                         // max armor
        300,						// speed
        400,						// dash speed
        true,						// can be stunned
        "gfx/hud/icons/playerclass/wtf_medic",
        "gfx/hud/icons/classactions/medic1",
        null
    );

    cPlayerClassInfos[ PLAYERCLASS_RUNNER ].setup(
        "Runner",					// name
        PLAYERCLASS_RUNNER,
        "$models/players/viciious",	// player model
        100,						// initial health
        0,						    // initial armor
		50,                         // max armor
        350,						// speed
        450,						// dash speed
        false,						// can be stunned
        "gfx/hud/icons/playerclass/wtf_runner",
        "gfx/hud/icons/classactions/runner1",
        "gfx/hud/icons/classactions/runner2"
    );

    cPlayerClassInfos[ PLAYERCLASS_ENGINEER ].setup(
        "Engineer",					// name
        PLAYERCLASS_ENGINEER,
        "$models/players/bobot",	// player model
        100,						// initial health
        50,						    // initial armor
		75,                         // max armor
        280,						// speed
        330,						// dash speed
        true,						// can be stunned
        "gfx/hud/icons/playerclass/wtf_engineer",
        "gfx/hud/icons/classactions/engineer1",
        "gfx/hud/icons/classactions/engineer2"
    );

	cPlayerClassInfos[ PLAYERCLASS_SUPPORT ].setup(
		"Support",                  // name
		PLAYERCLASS_SUPPORT,
		"$models/players/padpork",  // player model
		100,                        // initial health
		25,                         // initial armor
		100,                        // max armor
		275,                        // speed
		320,                        // dash speed
		true,                       // can be stunned
		"gfx/hud/icons/playerclass/wtf_support",
		null,
		null
	);

	cPlayerClassInfos[ PLAYERCLASS_SNIPER ].setup(
		"Sniper",                     // name
		PLAYERCLASS_SNIPER,
		"$models/players/silverclaw", // player model
		100,                          // initial health
		25,                           // initial armor
		50,                           // max armor
		240,                          // speed
		320,                          // dash speed
		true,                         // can be stunned
		"gfx/hud/icons/playerclass/wtf_sniper",
		null,
		null	
	);
}


