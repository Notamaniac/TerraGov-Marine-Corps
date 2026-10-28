///How often a cyborg tops up the consumables its module handed out
#define CYBORG_RESTOCK_INTERVAL (10 SECONDS)
///How much of each consumable a cyborg regains per restock
#define CYBORG_RESTOCK_AMOUNT 2
///How long it takes to bring a cyborg back online with a multitool
#define CYBORG_REVIVE_TIME (5 SECONDS)
///How much metal a cyborg's reservoir holds. Metal sheets, barbed wire and razor wire are all made out of it
#define CYBORG_METAL_RESERVE_MAX 100
///How much metal one barbed wire takes from the reservoir
#define CYBORG_BARBED_WIRE_COST 1
///How much metal one razor wire takes from the reservoir
#define CYBORG_RAZORWIRE_COST 2
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
	///The tool we are currently using, always one of slot_items
	var/obj/item/selected_item
	///How bright our headlamp is, 0 is off. See robot_lamp.dm
	var/lamp_level = 0
	///The metal in our reservoir, which the metal sheets, barbed wire and razor wire of our module are made out of
	var/metal_reserve = CYBORG_METAL_RESERVE_MAX
	///Our module's tools that draw on the reservoir
	var/list/obj/item/stack/reservoir_stacks = list()
	///Is our cover pried open. Only possible while we are shut down
	var/cover_open = FALSE
	///Cooldown for topping up our consumables
	COOLDOWN_DECLARE(restock_cooldown)

/mob/living/silicon/robot/Initialize(mapload)
	. = ..()
	real_name = "[initial(real_name)] [rand(100, 999)]"
	name = real_name
	//Spawned through the job system we are given skills anyway. Building reads them though, so a borg created any other way still needs some
	if(!skills)
		set_skills(getSkillsType(/datum/skills/synthetic))
	var/datum/atom_hud/squad_hud = GLOB.huds[DATA_HUD_SQUAD_TERRAGOV]
	squad_hud.add_hud_to(src)
	update_cyborg_icon()

/mob/living/silicon/robot/Destroy()
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
	if(stat == DEAD)
		. += span_deadsay("It is powered down.")
		. += span_notice("Its cover is [cover_open ? "open" : "closed"].")
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
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.update_health()

/mob/living/silicon/robot/on_death()
	set_remote_interface(FALSE)
	selected_item = null
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
	restock_module_items()
	//Stack counts on the slots change as the tools get used and restocked
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.update_slots()

/mob/living/silicon/robot/attackby(obj/item/I, mob/living/user, params)
	if(user.a_intent != INTENT_HELP)
		return ..()

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

///Prints how damaged we are to ourselves
/mob/living/silicon/robot/verb/check_integrity()
	set category = "Cyborg"
	set name = "Check Integrity"

	if(stat == DEAD)
		return
	to_chat(src, span_notice("Integrity: [round(health / maxHealth * 100)]% (structural damage [round(getBruteLoss())], wiring damage [round(getFireLoss())])."))

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
