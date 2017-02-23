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
const int PLAYERCLASS_GUNNER = 3;
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
	// HACK! We want:
	// 1) Reduce strafejumping acceleration for some classes
	// 2) Keep reasonably high speed on ground to avoid player frustration caused by ruined dodging
	// 3) Be compatible with vanilla Warsow 2.1 binaries
	// Ideally we should be able to set strafejumping acceleration from the script, 
	// but is is absent in the mentioned binaries. We use the following hack:
	// If a player is in air, this.client.pmoveMaxSpeed is set to this.pmoveMaxSpeedInAir 
	// If a player is on ground, this.client.pmoveMaxSpeed is set to this.pmoveMaxSpeedOnGround
	// These values should not differ significantly to avoid prediction errors.

	int pmoveMaxSpeedInAir;
	int pmoveMaxSpeedOnGround;
    int dashSpeed;
    int jumpSpeed;
    bool takeStun;
    int iconIndex;
    bool initialized;
    String name;
    String playerModel;
    int action1IconIndex;
    int action2IconIndex;

	const String[] @description;

    cPlayerClass()
    {
		this.pmoveMaxSpeedInAir = -1;
		this.pmoveMaxSpeedOnGround = -1;
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

	void setup( String &class_name, int tag, String &model, int health, int armor, int maxArmor, 
				int maxSpeedInAir, int maxSpeedOnGround, int dashSpeed, bool stun, 
				const String &icon, const String @action1Icon, const String @action2Icon, 
			    const String[] @description )
    {
        this.name = class_name;
        this.playerModel = model;
        this.maxHealth = health;
		this.armor = armor;
		this.maxArmor = maxArmor;
        this.dashSpeed = dashSpeed;
        this.pmoveMaxSpeedInAir = maxSpeedInAir;
		this.pmoveMaxSpeedOnGround = maxSpeedOnGround;
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

		@this.description = description;

        this.initialized = true;
    }
}

cPlayerClass[] cPlayerClassInfos( PLAYERCLASS_TOTAL );

// All classes (with an exception to the Runner that stands alone)
// can be divided in two these groups by movement parameters.

// "Slow" classes (the Grunt, the Engineer and the Sniper)
const int SLOW_MAX_SPEED_IN_AIR = 260;
const int SLOW_MAX_SPEED_ON_GROUND = 320;
const int SLOW_DASH_SPEED = 450;

// "Fast" classes (the Medic and the Support)
const int FAST_MAX_SPEED_IN_AIR = 300;
const int FAST_MAX_SPEED_ON_GROUND = 330;
const int FAST_DASH_SPEED = 450;

// AS does not have array literals, so we have to define descriptions separately

const String[] gruntDescription =
{
	"You're spawned as ^1GRUNT^7. This is a tank class with slow movement, strong armor and weapons.\n",
    "Command ^6altattack^7: Throw a cluster grenade\n",
	"Command ^6protect^7: Use a protection Warshell\n",
	"Note that you cannot use dash, walljump and aircontrol being protected by a shell",
	"Generic command ^8classaction1^7: Same as ^6protect^7\n",
	"Generic command ^8classaction2^7: Same as ^6altattack^7\n" 
};

const String[] medicDescription =
{
	"You're spawned as ^2MEDIC^7. This is a supportive class with health regenration\n",
	"You heal teammates in your aura radius\n",
	"You can revive dead teammates by walking over their reviver marker\n",
	"You can disable enemy revivers by walking over their reviver marker\n",
	"Command ^6altattack^7: Throw a bio grenade that heals teammates and hurts enemies\n",	
	"Command ^6supply^7: Give an adrenaline yourself and teammates in your aura\n",	
	"The adrenaline boosts teammates speed for a couple of seconds and gives some health\n",
	"Generic command ^8classaction1^7: Same as ^6altattack^7\n",
	"Generic command ^8classaction2^7: Same as ^6supply^7\n"
};

const String[] runnerDescription =
{
	"You're spawned as ^3RUNNER^7. This is the fastest offensive class.\n",
	"Command ^6protect^7: Throw a smoke grenade\n",
	"Command ^6trans throw^7: Throw (or return and throw) a translocator\n",
	"Command ^6trans check^7: Check the translocator status\n",
	"Command ^6trans return^7: Force returning a translocator\n",
	"Command ^6trans use^7: Teleport to the translocator origin\n",
	"A translocator gets returned automatically in a few seconds\n",
	"Your translocator may be damaged. Consider checking it first before using it.\n",
	"Generic command ^8classaction1^7: Throws your translocator, if it is thrown uses it\n",
	"Generic command ^8classaction2^7: Same as ^6protect^7\n"
};

const String[] gunnerDescription = 
{
	"You're spawned as ^8GUNNER^7. This is a class with the most powerful weapon.\n",
	"You can switch 3 player modes: normal, invisible and deployed\n",
	"In deployed mode you can barely move but have a protection shell and a powerful laser beam\n",
	"Take a good position in normal or invisible mode and wreck your enemies in deployed one\n",
	"Command ^6protect^7: Toggle invisibility\n",
	"Command ^6deploy^7: Toggle deployed mode\n",
	"Generic command ^8classaction1^7: Same as ^6protect^7\n",
	"Generic command ^8classaction2^7: Same as ^6deploy^7\n"
};

const String[] supportDescription =
{
	"You're spawned as ^4SUPPORT^7. This is a supportive class with armor regeneration.\n",
	"You repair teammates armor in your aura radius\n",
	"Command ^6altattack^7: Fire a powerful energy blast\n",
	"Consider setting ^2cg_particles 1^7 to make the blast clearly visible\n",
	"Command ^6supply^7: Give ammo yourself and teammates in your aura\n",
	"Generic command ^8classaction1^7: Same as ^6altattack^7\n",
	"Generic command ^8classaction2^7: Same as ^6supply^7\n" 
};

const String[] sniperDescription =
{
	"You're spawned as ^5SNIPER^7. This is a defencive class with best weapons for far-range fights.\n",
	"You can also build some useful entities: motion detectors and bounce pads\n",
	"The motion detector reveals fast moving nearby enemies and highlights ones for you and your team\n",
	"The bounce pad pushes players in air preserving their horizontal velocity\n",
	"Command ^6supply^7: Buy an instagun shot\n",
	"You can't carry more than 3 instagun shots\n",
	"Command ^6build detector^7: Build a motion detector\n",
	"Command ^6build pad^7: Build a bounce pad\n",
	"Command ^6destroy detector^7: Destroy the built motion detector\n",
	"Command ^6destroy pad^7: Destroy the built bounce pad\n",
	"Commands ^6build status^7, ^6destroy status^7: Print built entities status\n",
	"Generic command ^8classaction1^7: Build a motion detector, then a bounce pad, then destroy both ones^7\n",
	"Generic command ^8classaction2^7: Same as ^6supply^7\n"
};

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
        100,						// initial armor
		125,                        // max armor
        SLOW_MAX_SPEED_IN_AIR,
		SLOW_MAX_SPEED_ON_GROUND,
		SLOW_DASH_SPEED,
        true,						// can be stunned
        "gfx/wtf/wtf_grunt",
        "gfx/wtf/wtf_grunt1",
        "gfx/wtf/wtf_grunt2",
		gruntDescription
    );

    cPlayerClassInfos[ PLAYERCLASS_MEDIC ].setup(
        "Medic",					// name
        PLAYERCLASS_MEDIC,
        "$models/players/monada",	// player model
        100,						// initial health
        0,						    // initial armor
		75,                         // max armor
        FAST_MAX_SPEED_IN_AIR,
		FAST_MAX_SPEED_ON_GROUND,
		FAST_DASH_SPEED,
        true,						// can be stunned
        "gfx/wtf/wtf_medic",
        "gfx/wtf/medic1",
        null,
		medicDescription
    );

    cPlayerClassInfos[ PLAYERCLASS_RUNNER ].setup(
        "Runner",					// name
        PLAYERCLASS_RUNNER,
        "$models/players/viciious",	// player model
        100,						// initial health
        0,						    // initial armor
		50,                         // max armor
        370,						// pmoveMaxSpeedInAir
		370,                        // pmoveMaxSpeedOnGround
        475,						// dash speed
        false,						// can be stunned
        "gfx/wtf/wtf_runner",
        "gfx/wtf/runner1",
        "gfx/wtf/runner2",
		runnerDescription
    );

    cPlayerClassInfos[ PLAYERCLASS_GUNNER ].setup(
        "Gunner",			     	  // name
        PLAYERCLASS_GUNNER,
        "$models/players/silverclaw", // player model
        100,						  // initial health
        50,						      // initial armor
		75,                           // max armor
        SLOW_MAX_SPEED_IN_AIR,
		SLOW_MAX_SPEED_ON_GROUND,
		SLOW_DASH_SPEED,
        true,					  	  // can be stunned
        "gfx/wtf/wtf_gunner",
        "gfx/wtf/gunner1",
        "gfx/wtf/gunner2",
		gunnerDescription
    );

	cPlayerClassInfos[ PLAYERCLASS_SUPPORT ].setup(
		"Support",                  // name
		PLAYERCLASS_SUPPORT,
		"$models/players/padpork",  // player model
		100,                        // initial health
		0,                          // initial armor
		75,                         // max armor
		FAST_MAX_SPEED_IN_AIR,
		FAST_MAX_SPEED_ON_GROUND,
		FAST_DASH_SPEED,
		true,                       // can be stunned
		"gfx/wtf/wtf_support",
		null,
		null,
		supportDescription
	);

	cPlayerClassInfos[ PLAYERCLASS_SNIPER ].setup(
		"Sniper",                     // name
		PLAYERCLASS_SNIPER,
		"$models/players/bobot",      // player model
		100,                          // initial health
		50,                           // initial armor
		50,                           // max armor
		SLOW_MAX_SPEED_IN_AIR,
		SLOW_MAX_SPEED_ON_GROUND,
		SLOW_DASH_SPEED,
		true,                         // can be stunned
		"gfx/wtf/wtf_sniper",
		null,
		null,
		sniperDescription
	);
}


