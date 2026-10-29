///How long it takes to bring a cyborg back online with a multitool
#define CYBORG_REVIVE_TIME (5 SECONDS)
///Trait source for everything a cyborg module handed out
#define CYBORG_MODULE_TRAIT "cyborg_module"

/**
 * A cyborg. It joins as the Cyborg job, picks a module on spawn, and is bound by whatever laws the ship AI currently holds.
 * Not to be confused with the combat robot species, which is a human subtype and what isrobot() checks for.
 */
/mob/living/silicon/robot
	name = "Cyborg"
	real_name = "Cyborg"
	desc = "A TerraGov cyborg, built to serve alongside the marines."
	icon = 'icons/mob/cyborg.dmi'
	icon_state = "robot"
	bubble_icon = "robot"
	density = TRUE
	maxHealth = 250
	health = 250
	faction = FACTION_TERRAGOV
	status_flags = CANSTUN|CANKNOCKOUT|CANPUSH
	has_unlimited_silicon_privilege = TRUE
	hud_type = /datum/hud/robot
	///The module we picked, null until the player chooses one
	var/datum/robot_module/module
	///Every tool our module gave us. They always stay inside us, equipping one only decides which slot shows it
	var/list/obj/item/module_items = list()
	///The tools in our slots, null for an empty slot. One entry per slot
	var/list/obj/item/slot_items = list(null, null, null)
	///Is the slot knocked out by damage, one entry per slot. Damaged cyborgs lose their last slot first
	var/list/slot_disabled = list(FALSE, FALSE, FALSE)
	///The tool we are currently using, always one of slot_items
	var/obj/item/selected_item
	///How bright our headlamp is, 0 is off. See robot_lamp.dm
	var/lamp_level = 0
	///The name the player gave us in the character setup, if any. While there is one a module does not rename us
	var/custom_name
	///The metal in our reservoir, which the metal sheets, barbed wire and razor wire of our module are made out of
	var/metal_reserve = CYBORG_METAL_RESERVE_MAX
	///The plasteel in our reservoir, which the plasteel sheets of our module are made out of
	var/plasteel_reserve = CYBORG_PLASTEEL_RESERVE_MAX
	///Our module's tools that draw on the reservoirs
	var/list/obj/item/stack/reservoir_stacks = list()
	///Is our cover pried open
	var/cover_open = FALSE
	///Is our cover locked. A cyborg is locked by default, swiping an ID with engineering access toggles it
	var/cover_locked = TRUE
	///The power cell that runs us, it is drained every tick and we shut down when it is empty or gone
	var/obj/item/cell/cell
	///The type of the cell we start with
	var/cell_type = /obj/item/cell/high
	///Have we warned that our power is running low
	var/low_power_warned = FALSE
	///Set while our cell is empty or missing. Without power we can't use our tools or our headlamp, we get both back once there is power again
	var/out_of_power = FALSE

/mob/living/silicon/robot/Initialize(mapload)
	. = ..()
	real_name = "[initial(real_name)] [rand(100, 999)]"
	name = real_name
	cell = new cell_type(src)
	//Spawned through the job system we are given skills anyway. Building reads them though, so a borg created any other way still needs some
	if(!skills)
		set_skills(getSkillsType(/datum/skills/synthetic))
	var/datum/atom_hud/squad_hud = GLOB.huds[DATA_HUD_SQUAD_TERRAGOV]
	squad_hud.add_hud_to(src)
	update_cyborg_icon()

/mob/living/silicon/robot/Destroy()
	QDEL_NULL(cell)
	selected_item = null
	slot_items.Cut()
	for(var/obj/item/module_item AS in module_items)
		qdel(module_item)
	module_items.Cut()
	QDEL_NULL(module)
	return ..()

/mob/living/silicon/robot/Login()
	. = ..()
	if(!module)
		INVOKE_ASYNC(src, PROC_REF(prompt_module_choice))

/mob/living/silicon/robot/examine(mob/user)
	. = ..()
	if(module)
		. += span_notice("It is a [module.name] model.")
	. += span_notice("Its cover is [cover_open ? "open" : "closed"] and [cover_locked ? "locked" : "unlocked"].")
	if(cover_open)
		. += cell ? span_notice("Its power cell reads [round(cell.percent())]%.") : span_warning("Its power cell is missing.")
	if(stat == DEAD)
		. += span_deadsay("It is powered down.")
		return
	if(getBruteLoss() > maxHealth * 0.25)
		. += span_warning("Its plating is dented and scored.")
	if(getFireLoss() > maxHealth * 0.25)
		. += span_warning("Its wiring is scorched.")

// ***************************************
// *********** Health and death
// ***************************************
/mob/living/silicon/robot/update_stat()
	. = ..()
	if(status_flags & GODMODE)
		return
	if(stat != DEAD && health <= 0)
		death()

/mob/living/silicon/robot/updatehealth()
	. = ..()
	update_damage_effects()
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.update_health()

/mob/living/silicon/robot/on_death()
	set_remote_interface(FALSE)
	selected_item = null
	update_sight()
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.close_panel()
		robot_hud.update_slots()
	notransform = FALSE
	set_lamp_level(0, silent = TRUE)
	update_cyborg_icon() //Eyes and lamp go dark
	to_chat(src, "<b>[span_deadsay("<p style='font-size:1.5em'><big>You have been shut down.</big></p>")]</b>")
	return ..()

// ***************************************
// *********** Gibbing
// ***************************************
//Cyborgs fall apart into robot debris (silicon spawn_gibs) with oil instead of blood
/mob/living/silicon/robot/get_blood_color()
	return "#030303"

//The silicon gib animation flicks a state that mob.dmi doesn't have, so the debris and a burst of sparks are all there is to see
/mob/living/silicon/robot/gib_animation()
	var/datum/effect_system/spark_spread/sparks = new
	sparks.set_up(5, 0, get_turf(src))
	sparks.start()

//Cyborgs don't breathe
/mob/living/silicon/robot/adjustOxyLoss(amount)
	return FALSE

/mob/living/silicon/robot/setOxyLoss(amount)
	return FALSE

/mob/living/silicon/robot/Life(seconds_per_tick, times_fired)
	. = ..()
	if(stat == DEAD)
		return
	drain_cell()
	if(stat == DEAD)
		return
	//Stack counts on the slots change as the tools get used
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.update_slots()

/mob/living/silicon/robot/attackby(obj/item/I, mob/living/user, params)
	if(user.a_intent != INTENT_HELP)
		return ..()

	if(istype(I, /obj/item/card/id))
		return try_swipe_id(user, I)

	if(istype(I, /obj/item/cell))
		return try_insert_cell(user, I)

	if(is_cover_tool(I))
		return toggle_cover(user, I)

	if(is_reboot_tool(I))
		return try_reboot(user, I)

	if(istype(I, /obj/item/tool/weldingtool))
		if(!getBruteLoss())
			to_chat(user, span_notice("[src] has no structural damage to repair."))
			return TRUE
		var/obj/item/tool/weldingtool/welder = I
		if(!welder.isOn())
			to_chat(user, span_warning("You need to turn [welder] on first."))
			return TRUE
		if(!do_after(user, 2 SECONDS, NONE, src, BUSY_ICON_FRIENDLY))
			return TRUE
		if(!welder.remove_fuel(1, user))
			return TRUE
		heal_overall_damage(brute = 30, updating_health = TRUE)
		user.visible_message(span_notice("[user] patches some dents on [src] with [welder]."), span_notice("You patch some dents on [src] with [welder]."))
		return TRUE

	if(istype(I, /obj/item/stack/cable_coil))
		if(!getFireLoss())
			to_chat(user, span_notice("[src] has no wiring damage to repair."))
			return TRUE
		var/obj/item/stack/cable_coil/coil = I
		if(!do_after(user, 2 SECONDS, NONE, src, BUSY_ICON_FRIENDLY))
			return TRUE
		if(!coil.use(1))
			return TRUE
		heal_overall_damage(burn = 30, updating_health = TRUE)
		user.visible_message(span_notice("[user] splices some burnt wiring in [src]."), span_notice("You splice some burnt wiring in [src]."))
		return TRUE

	return ..()

//An open cover lets anyone with a free hand pull our cell out
/mob/living/silicon/robot/attack_hand(mob/living/user)
	if(user.a_intent == INTENT_HELP && cover_open && cell)
		remove_cell(user)
		return TRUE
	return ..()

///Prints how damaged we are to ourselves
/mob/living/silicon/robot/verb/check_integrity()
	set category = "Cyborg"
	set name = "Check Integrity"

	if(stat == DEAD)
		return
	to_chat(src, span_notice("Integrity: [round(health / maxHealth * 100)]% (structural damage [round(getBruteLoss())], wiring damage [round(getFireLoss())])."))
	to_chat(src, span_notice("Power: [cell ? "[round(cell.percent())]%" : "no power cell"][out_of_power ? " (out of power)" : ""]."))

// ***************************************
// *********** Rebooting
// ***************************************
/**
 * A cyborg that has been shut down can be brought back. A crowbar opens or closes its cover, and with the cover open a multitool reboots it.
 * It will not reboot while it is damaged: its plating has to be welded and its wiring spliced back to full first.
 */
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
	if(cover_locked)
		balloon_alert(user, "cover is locked")
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
	if(!cell)
		balloon_alert(user, "no power cell")
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
	if(stat != DEAD || !cover_open || !cell || !can_reboot(user))
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
	cover_locked = TRUE
	revive()
	notransform = FALSE
	update_damage_effects()
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

// ***************************************
// *********** Power
// ***************************************
/**
 * Our power cell is drained every tick. When it is empty or gone we are out_of_power: our tools and headlamp stop working until there is power again.
 * Its cover is locked, an ID with engineering access unlocks it, and with the cover open the cell can be pulled out and replaced.
 * Rebooting needs a cell and tops it up to full, see revive().
 * Running out of power does not shut us down, it only sets the out_of_power flag.
 */
///Fills our power cell to the top. Returns FALSE if we have none
/mob/living/silicon/robot/proc/recharge_cell()
	if(!cell)
		return FALSE
	cell.charge = cell.maxcharge
	cell.update_appearance(UPDATE_ICON)
	update_power_state()
	return TRUE

//Being brought back always means a full cell, an admin revive even makes one if it is missing
/mob/living/silicon/robot/revive(admin_revive = FALSE)
	if(admin_revive && !cell)
		cell = new cell_type(src)
	. = ..()
	recharge_cell()

///Takes this tick's power from the cell. If it can't give it we are out of power
/mob/living/silicon/robot/proc/drain_cell()
	if(status_flags & GODMODE)
		return
	if(!cell?.use(CYBORG_CELL_DRAIN))
		set_out_of_power(TRUE)
		return
	set_out_of_power(FALSE)
	if(cell.percent() > CYBORG_LOW_POWER_PERCENT)
		low_power_warned = FALSE
		return
	if(low_power_warned)
		return
	low_power_warned = TRUE
	to_chat(src, span_danger("Warning: power at [round(cell.percent())]%."))

///Checks whether our cell can run us and sets the out_of_power flag to match
/mob/living/silicon/robot/proc/update_power_state()
	set_out_of_power(!cell || cell.charge < CYBORG_CELL_DRAIN)

///Sets or clears the out_of_power flag. Losing power turns the headlamp off and puts the tool we hold down
/mob/living/silicon/robot/proc/set_out_of_power(new_value)
	if(out_of_power == new_value)
		return
	out_of_power = new_value
	if(!out_of_power)
		low_power_warned = FALSE
		to_chat(src, span_notice("Power restored. Your tools and headlamp are back online."))
		return
	to_chat(src, span_danger("Power failure! Your tools and headlamp are offline."))
	set_lamp_level(0, silent = TRUE)
	if(istype(selected_item, /obj/item/tool/weldingtool))
		var/obj/item/tool/weldingtool/welder = selected_item
		if(welder.welding)
			welder.toggle()
	deselect_active()

///Swiping an ID with engineering access locks or unlocks our cover
/mob/living/silicon/robot/proc/try_swipe_id(mob/living/user, obj/item/card/id/swiped_id)
	if(!(ACCESS_MARINE_ENGINEERING in swiped_id.access))
		balloon_alert(user, "access denied")
		return TRUE
	if(cover_open && !cover_locked)
		balloon_alert(user, "close the cover first")
		return TRUE
	cover_locked = !cover_locked
	playsound(src, 'sound/machines/ping.ogg', 25, TRUE)
	user.visible_message(span_notice("[user] swipes [swiped_id] over [src]."), span_notice("You [cover_locked ? "lock" : "unlock"] [src]'s cover."))
	return TRUE

///Puts a cell in us if we have none and our cover is open
/mob/living/silicon/robot/proc/try_insert_cell(mob/living/user, obj/item/cell/new_cell)
	if(!cover_open)
		balloon_alert(user, "cover is closed")
		return TRUE
	if(cell)
		balloon_alert(user, "already has a cell")
		return TRUE
	if(!user.transferItemToLoc(new_cell, src))
		return TRUE
	cell = new_cell
	low_power_warned = FALSE
	update_power_state()
	user.visible_message(span_notice("[user] puts [new_cell] in [src]."), span_notice("You put [new_cell] in [src]."))
	return TRUE

///Pulls our cell out, which shuts us down if we are active
/mob/living/silicon/robot/proc/remove_cell(mob/living/user)
	user.visible_message(span_notice("[user] starts pulling the power cell out of [src]."), span_notice("You start pulling the power cell out of [src]."))
	if(!do_after(user, CYBORG_CELL_REMOVE_TIME, NONE, src, BUSY_ICON_BUILD))
		return
	if(!cover_open || !cell)
		return
	var/obj/item/cell/old_cell = cell
	cell = null
	if(!user.put_in_hands(old_cell))
		old_cell.forceMove(drop_location())
	user.visible_message(span_notice("[user] pulls the power cell out of [src]."), span_notice("You pull the power cell out of [src]."))
	update_power_state()

// ***************************************
// *********** Laws
// ***************************************
///Returns the AI we take our laws from, the first living one, or null if there is none
/mob/living/silicon/robot/proc/get_law_source()
	for(var/mob/living/silicon/ai/source_ai AS in GLOB.ai_list)
		if(QDELETED(source_ai) || source_ai.stat == DEAD)
			continue
		return source_ai
	return null

/mob/living/silicon/robot/get_laws()
	var/mob/living/silicon/ai/source_ai = get_law_source()
	if(!source_ai)
		return GLOB.default_silicon_laws
	return source_ai.laws

/mob/living/silicon/robot/verb/show_laws()
	set category = "Cyborg"
	set name = "Show Laws"

	if(stat == DEAD)
		return
	print_laws()
	var/mob/living/silicon/ai/source_ai = get_law_source()
	if(source_ai)
		to_chat(src, span_notice("Your laws are synced to [source_ai]."))
	else
		to_chat(src, span_warning("There is no active AI to sync with, you are bound by the default lawset."))

/mob/living/silicon/robot/verb/state_laws()
	set category = "Cyborg"
	set name = "State Laws"

	if(stat == DEAD || incapacitated())
		return

	if(tgui_alert(src, "Are you sure you want to announce your laws over the radio?", "State Laws", list("Yes", "No")) != "Yes")
		return

	say("; Current Active Lawset:")

	var/delay = 1 SECONDS
	for(var/law in get_laws())
		addtimer(CALLBACK(src, TYPE_PROC_REF(/atom/movable, say), "; [law]"), delay)
		delay += 1 SECONDS

// ***************************************
// *********** Interaction
// ***************************************
/mob/living/silicon/robot/get_active_held_item()
	return selected_item

//We have no way to throw anything, our tools never leave us
/mob/living/silicon/robot/throw_item(atom/target)
	return FALSE

/mob/living/silicon/robot/UnarmedAttack(atom/A, has_proximity, modifiers)
	if(HAS_TRAIT(src, TRAIT_HANDS_BLOCKED))
		return
	//Anything you want to do to a living thing needs a tool
	if(isliving(A))
		return
	A.attack_hand(src)
