///How often a cyborg tops up the consumables its module handed out
#define CYBORG_RESTOCK_INTERVAL (10 SECONDS)
///How much of each consumable a cyborg regains per restock
#define CYBORG_RESTOCK_AMOUNT 2
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
	///Cooldown for topping up our consumables
	COOLDOWN_DECLARE(restock_cooldown)

/mob/living/silicon/robot/Initialize(mapload)
	. = ..()
	real_name = "[initial(real_name)] [rand(100, 999)]"
	name = real_name
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
