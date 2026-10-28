///How long it takes to bring a cyborg back online with a multitool
#define CYBORG_REVIVE_TIME (5 SECONDS)

/**
 * A cyborg that has been shut down can be brought back. A crowbar opens or closes its cover, and with the cover open a multitool reboots it.
 * It will not reboot while it is damaged: its plating has to be welded and its wiring spliced back to full first.
 */
/mob/living/silicon/robot
	///Is our cover pried open. Only possible while we are shut down
	var/cover_open = FALSE

///Does the tool open covers
/mob/living/silicon/robot/proc/is_cover_tool(obj/item/tool)
	return tool.tool_behaviour == TOOL_CROWBAR

///Does the tool reboot us
/mob/living/silicon/robot/proc/is_reboot_tool(obj/item/tool)
	return tool.tool_behaviour == TOOL_MULTITOOL

///Is there damage a welder or cable can still fix
/mob/living/silicon/robot/proc/has_repairable_damage()
	return getBruteLoss() > 0 || getFireLoss() > 0

///Opens or closes our cover. Returns TRUE if the tool was used on us
/mob/living/silicon/robot/proc/toggle_cover(mob/living/user, obj/item/tool)
	if(stat != DEAD)
		balloon_alert(user, "cover is locked while active")
		return TRUE
	tool.play_tool_sound(src, 50)
	cover_open = !cover_open
	user.visible_message(span_notice("[user] [cover_open ? "pries open" : "closes"] [src]'s cover."), span_notice("You [cover_open ? "pry open" : "close"] [src]'s cover."))
	return TRUE

///Reboots us, if the cover is open and every bit of damage has been repaired. Returns TRUE if the tool was used on us
/mob/living/silicon/robot/proc/try_reboot(mob/living/user, obj/item/tool)
	if(stat != DEAD)
		balloon_alert(user, "already active")
		return TRUE
	if(!cover_open)
		balloon_alert(user, "open the cover first")
		return TRUE
	if(!can_reboot(user))
		return TRUE
	user.visible_message(span_notice("[user] starts rebooting [src]."), span_notice("You start rebooting [src]."))
	if(!do_after(user, CYBORG_REVIVE_TIME, NONE, src, BUSY_ICON_MEDICAL))
		return TRUE
	//Things can change while we work
	if(stat != DEAD || !cover_open || !can_reboot(user))
		return TRUE
	reboot()
	user.visible_message(span_notice("[user] reboots [src]."), span_notice("You reboot [src]."))
	return TRUE

///Tells the user what is still broken and returns FALSE if the cyborg can not be rebooted yet
/mob/living/silicon/robot/proc/can_reboot(mob/living/user)
	if(!has_repairable_damage())
		return TRUE
	var/list/missing = list()
	if(getBruteLoss() > 0)
		missing += "weld its plating ([round(getBruteLoss())] structural damage left)"
	if(getFireLoss() > 0)
		missing += "splice its wiring ([round(getFireLoss())] wiring damage left)"
	balloon_alert(user, "still damaged")
	to_chat(user, span_warning("[src] cannot reboot while it is damaged. You still need to [english_list(missing)]."))
	return FALSE

///Brings us back online
/mob/living/silicon/robot/proc/reboot()
	cover_open = FALSE
	revive()
	notransform = FALSE
	update_cyborg_icon()
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.update_health()
		robot_hud.update_slots()
	var/datum/effect_system/spark_spread/sparks = new
	sparks.set_up(4, 0, src)
	sparks.attach(src)
	sparks.start()
	playsound(src, 'sound/machines/ping.ogg', 40, TRUE)
	to_chat(src, span_notice("<b>You have been rebooted. All systems nominal.</b>"))

#undef CYBORG_REVIVE_TIME
