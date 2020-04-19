#include "script_component.hpp"
/*
 * Author: nkenny
 * Deploy static weapons
 *
 * Arguments:
 * 0: Units <ARRAY>
 * 1: Danger pos
 *
 * Return Value:
 * units in array
 *
 * Example:
 * [units bob, getPos angryJoe] call lambs_danger_fnc_leaderStaticDeploy;
 *
 * Public: No
*/

params ["_units", "_pos"];

// prevent deployment of static weapons
if (GVAR(disableAIDeployStaticWeapons) || {_units isEqualTo []}) exitWith {_units};

// find gunner
private _gunner = _units findIf {unitBackpack _x isKindOf "Weapon_Bag_Base"};
if (_gunner isEqualTo -1) exitWith {_units};

// define gunner
_gunner = _units deleteAt _gunner;

// crudely and unapologetically lifted from BIS_fnc_unpackStaticWeapon by Rocket and Killzone_Kid
private _cfgBase = configFile >> "CfgVehicles" >> backpack _gunner >> "assembleInfo" >> "base";
private _compatibleBases = if (isText _cfgBase) then {[getText _cfgBase]} else {getArray _cfgBase};

// find assistant
private _assistant = _units findIf {

    backpack _x in _compatibleBases;

};

// define assistant
if (_assistant isEqualTo -1) exitWith {_units + [_gunner]};
_assistant = _units deleteAt _assistant;

// Manoeuvre gunner 
private _EH = _gunner addEventHandler ["WeaponAssembled", {
        params ["_unit", "_weapon"];
        
        // get in weapon 
        _unit assignAsGunner _weapon;
        _unit moveInGunner _weapon;

        // check artillery
        if (GVAR(Loaded_WP) && {_weapon getVariable [QGVAR(isArtillery), getNumber (configFile >> "CfgVehicles" >> (typeOf _weapon) >> "artilleryScanner") > 0]}) then {
            [group _unit] call EFUNC(wp,taskArtilleryRegister);
        };

        // remove EH
        _unit removeEventHandler ["WeaponAssembled", _thisEventHandler];
    }
];

// callout
[formationLeader _gunner, "aware", "AssembleThatWeapon"] call FUNC(doCallout);

// find position ~ kept simple for now!
private _weaponPos = [ getpos _gunner, 0, 15, 2, 0, 0.19, 0, [], [getpos (leader _gunner), getpos (leader _gunner)]] call BIS_fnc_findSafePos;
_weaponPos set [2, 0];

// ready units
{
    doStop _x;
    _x setUnitPosWeak "MIDDLE";
    _x setVariable [QGVAR(forceMove), true];
    _x setVariable [QGVAR(currentTask), "Deploy Static Weapon"];
    _x doMove _weaponPos;
    //_x setDestination [_weaponPos, "LEADER DIRECT", false];

} foreach [_gunner, _assistant];

// do it
[
    {
        // condition
        params ["_gunner", "_assistant", "_pos", "_weaponPos", ""];
        (unitReady _gunner || {_gunner distance2d _assistant < 3}) || {fleeing _gunner} || {fleeing _assistant}
    },
    {
        // on near gunner
        params ["_gunner", "_assistant", "_pos", ""];
        if (fleeing _gunner || {fleeing _assistant} || {!(_gunner call FUNC(isAlive))}) exitWith {false};

        // assemble weapon
        _gunner action ["PutBag", _assistant];
        _gunner action ["Assemble", unitBackpack _assistant];

        // organise weapon and gunner
        (vehicle _gunner) setDir (_gunner getDir _pos);
        (vehicle _gunner) doWatch _pos;

        // assistant
        _assistant doWatch _pos;
        [_assistant, ["gesturePoint"]] call FUNC(gesture);

    },
    [_gunner, _assistant, _pos, _weaponPos, _EH], 8,
    {
        // on timeout
        params ["_gunner", "_assistant", "", "", "_EH"];
        {
            _x doFollow (leader _x);
        } foreach ([_gunner, _assistant] select { _x call FUNC(isAlive) });
        _gunner removeEventHandler ["WeaponAssembled", _EH];
    }
] call CBA_fnc_waitUntilAndExecute;

// end
_units