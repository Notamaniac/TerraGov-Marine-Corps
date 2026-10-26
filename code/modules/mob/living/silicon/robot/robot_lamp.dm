///The headlamp is off
#define CYBORG_LAMP_OFF 0
///The brightest the headlamp goes, it has this many levels above off
#define CYBORG_LAMP_MAX_LEVEL 3

///Light range of each headlamp level, level 0 is off
GLOBAL_LIST_INIT(cyborg_lamp_ranges, list(0, 3, 5, 7))
///Light power of each headlamp level
GLOBAL_LIST_INIT(cyborg_lamp_powers, list(0, 1, 1.5, 2))
///What each headlamp level is called
GLOBAL_LIST_INIT(cyborg_lamp_names, list("off", "low", "medium", "high"))

/**
 * Every cyborg has a headlamp with CYBORG_LAMP_MAX_LEVEL brightness levels.
 * The HUD button, the keybind and the verb all step it up a level, and after the brightest it turns off again.
 */
/mob/living/silicon/robot/proc/set_lamp_level(new_level, silent = FALSE)
	new_level = clamp(new_level, CYBORG_LAMP_OFF, CYBORG_LAMP_MAX_LEVEL)
	if(stat == DEAD)
		new_level = CYBORG_LAMP_OFF
	if(new_level == lamp_level)
		return FALSE
	lamp_level = new_level
	set_light(GLOB.cyborg_lamp_ranges[lamp_level + 1], GLOB.cyborg_lamp_powers[lamp_level + 1])
	if(!notransform)
		update_cyborg_icon()
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.update_lamp()
	if(!silent)
		playsound(src, 'sound/items/flashlight.ogg', 25, TRUE)
		balloon_alert(src, "headlamp [GLOB.cyborg_lamp_names[lamp_level + 1]]")
	return TRUE

///Steps the headlamp up a level, or turns it off if it was already at its brightest
/mob/living/silicon/robot/proc/cycle_lamp()
	if(stat == DEAD || incapacitated())
		return FALSE
	return set_lamp_level(lamp_level >= CYBORG_LAMP_MAX_LEVEL ? CYBORG_LAMP_OFF : lamp_level + 1)

/mob/living/silicon/robot/verb/toggle_headlamp()
	set category = "Cyborg"
	set name = "Cycle Headlamp"

	cycle_lamp()

#undef CYBORG_LAMP_OFF
#undef CYBORG_LAMP_MAX_LEVEL
