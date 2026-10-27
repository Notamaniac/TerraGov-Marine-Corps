///How far away a cyborg can use machines through its AI interface, they still have to be in view
#define CYBORG_REMOTE_RANGE 7

/**
 * A cyborg can switch on the same remote interface the AI uses. While it is on, clicking a machine that is in view
 * runs the AI's version of the click on it: plain click is attack_ai, ctrl bolts, shift opens and ctrl+shift electrifies and so on.
 * It only takes over clicks on machines, so mobs and turfs still behave normally. A plain click on a machine next to us while a tool is
 * selected still goes to the tool, so deselect the tool to use the interface on a machine that is within reach.
 */
/mob/living/silicon/robot
	///Is the AI interface on
	var/remote_interface = FALSE

/mob/living/silicon/robot/verb/toggle_remote_interface()
	set category = "Cyborg"
	set name = "AI Interaction"

	if(stat == DEAD)
		return
	set_remote_interface(!remote_interface)

///Switches the AI interface on or off
/mob/living/silicon/robot/proc/set_remote_interface(new_state)
	if(new_state == remote_interface)
		return
	remote_interface = new_state
	if(remote_interface)
		RegisterSignal(src, COMSIG_MOB_CLICKON, PROC_REF(on_remote_click))
		to_chat(src, span_notice("AI interface on. Clicking a machine in view now works it the way the AI does. A plain click on a machine next to you still uses the tool you have selected."))
	else
		UnregisterSignal(src, COMSIG_MOB_CLICKON)
		to_chat(src, span_notice("AI interface off."))
	balloon_alert(src, "AI interface [remote_interface ? "on" : "off"]")

/mob/living/silicon/robot/proc/on_remote_click(datum/source, atom/clicked, params)
	SIGNAL_HANDLER
	if(!istype(clicked, /obj/machinery))
		return NONE
	var/list/modifiers = params2list(params)
	//Alt is left alone so it can still be used to look at what is on a tile
	if(modifiers["alt"])
		return NONE
	//Register a plain click while having an item selected, so we can still weld, cut wires while holding a tool, and still use ctrl/shift click and so on to unbolt/open doors
	if(selected_item && !modifiers["shift"] && !modifiers["ctrl"] && !modifiers["middle"] && Adjacent(clicked))
		return NONE
	if(stat == DEAD || incapacitated())
		return COMSIG_MOB_CLICK_CANCELED
	if(world.time <= next_move)
		return COMSIG_MOB_CLICK_CANCELED
	if(get_dist(src, clicked) > CYBORG_REMOTE_RANGE || !(clicked in view(CYBORG_REMOTE_RANGE, src)))
		balloon_alert(src, "out of range")
		return COMSIG_MOB_CLICK_CANCELED
	changeNext_move(CLICK_CD_RAPID)
	//Machines can sleep, a do_after or an input list, and signal handlers must not
	INVOKE_ASYNC(src, PROC_REF(remote_interact), clicked, modifiers)
	return COMSIG_MOB_CLICK_CANCELED

///Does what the AI would have done by clicking the machine with these modifiers
/mob/living/silicon/robot/proc/remote_interact(obj/machinery/target, list/modifiers)
	if(QDELETED(target) || QDELETED(src))
		return
	if(modifiers["shift"] && modifiers["ctrl"])
		target.AICtrlShiftClick(src)
	else if(modifiers["middle"])
		target.AIMiddleClick(src)
	else if(modifiers["shift"])
		target.AIShiftClick(src)
	else if(modifiers["ctrl"])
		target.AICtrlClick(src)
	else
		target.attack_ai(src)

#undef CYBORG_REMOTE_RANGE
