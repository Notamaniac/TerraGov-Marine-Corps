/**
 * The engineering tools as a cyborg carries them. They are the ordinary tools, only drawn with the cyborg sprites,
 * so they stay a subtype and every check for the tool's typepath still accepts them.
 */
/obj/item/tool/wrench/cyborg
	icon = 'icons/obj/items_cyborg.dmi'
	icon_state = "toolkit_engiborg_wrench"

/obj/item/tool/screwdriver/cyborg
	icon = 'icons/obj/items_cyborg.dmi'
	icon_state = "toolkit_engiborg_screwdriver"
	random_color = FALSE

/obj/item/tool/screwdriver/cyborg/Initialize(mapload)
	. = ..()
	pixel_y = 0

/obj/item/tool/wirecutters/cyborg
	icon = 'icons/obj/items_cyborg.dmi'
	icon_state = "toolkit_engiborg_cutters"

/obj/item/tool/wirecutters/cyborg/Initialize(mapload)
	. = ..()
	//The wirecutters pick a random colour of their own sprite, ours has only one
	icon_state = initial(icon_state)

/obj/item/tool/crowbar/cyborg
	icon = 'icons/obj/items_cyborg.dmi'
	icon_state = "toolkit_engiborg_crowbar"

/obj/item/tool/multitool/cyborg
	icon = 'icons/obj/items_cyborg.dmi'
	icon_state = "toolkit_engiborg_multitool"

/obj/item/tool/weldingtool/cyborg
	icon = 'icons/obj/items_cyborg.dmi'
	icon_state = "indwelder_cyborg"
	base_icon_state = "indwelder_cyborg"

//The flame of the cyborg welder is a sprite of its own that is drawn over the welder, not a sprite of a lit welder. It has no emissive sprite
/obj/item/tool/weldingtool/cyborg/update_icon_state()
	icon_state = base_icon_state

/obj/item/tool/weldingtool/cyborg/update_overlays()
	..()
	return welding ? list("[base_icon_state]-on") : list()

/obj/item/tool/weldingtool/cyborg/get_hud_overlay_states()
	return welding ? list("[base_icon_state]-on") : list()

/**
 * Turns loose metal, plasteel and wire into the reservoirs of the cyborg using it, and they are used up.
 * The reservoir tools of a cyborg do the same when used on them, see the metal reservoir in robot_modules.dm.
 */
/obj/item/cyborg_sheet_snatcher
	name = "sheet snatcher"
	desc = "Pulls sheets of metal or plasteel, and wire, apart and stores them in a cyborg's reservoirs. Use it on them, they are used up."
	icon = 'icons/obj/items/sheet_snatcher.dmi'
	icon_state = "sheet_snatcher"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/cyborg_sheet_snatcher/preattack(atom/target, mob/user, params)
	var/mob/living/silicon/robot/borg = user
	if(!istype(borg) || !istype(target, /obj/item/stack) || !borg.Adjacent(target))
		return ..()
	if(!borg.absorb_into_reservoir(target))
		borg.balloon_alert(borg, "can't convert that")
	return TRUE

/**
 * The hand of a cyborg. While it is the selected tool and holds an item, that item is what the cyborg holds, so clicking
 * something uses the item on it. With nothing in it, clicking an item on the whitelist picks it up.
 * Using it (the use key, or the Activate Held Object verb) drops what it holds.
 */
/obj/item/cyborg_manipulator
	name = "manipulator"
	desc = "A robotic hand. Click a suitable item to pick it up, then click something to use the item on it. Use the manipulator itself to drop the item."
	icon = 'icons/obj/items_cyborg.dmi'
	//Placeholder sprite
	icon_state = "sili"
	w_class = WEIGHT_CLASS_SMALL
	item_flags = NOBLUDGEON
	///The item it is holding, only trust get_held()
	var/obj/item/held_item
	///The types of item it can pick up, subtypes included. Add to this list to let it hold more
	var/static/list/whitelist = typecacheof(list(
		/obj/item/circuitboard,
		/obj/item/frame/apc,
		/obj/item/cell,
	))

/obj/item/cyborg_manipulator/Destroy()
	var/obj/item/dropped_item = get_held()
	if(dropped_item)
		dropped_item.forceMove(get_turf(src))
	held_item = null
	return ..()

/obj/item/cyborg_manipulator/examine(mob/user)
	. = ..()
	var/obj/item/shown_held = get_held()
	. += shown_held ? span_notice("It is holding [shown_held].") : span_notice("It is empty.")

///What it is holding, an item that was taken out of it by anything is forgotten
/obj/item/cyborg_manipulator/proc/get_held()
	if(held_item && held_item.loc != src)
		held_item = null
	return held_item

///Can it pick this up
/obj/item/cyborg_manipulator/proc/can_hold(atom/target)
	return is_type_in_typecache(target, whitelist)

///Takes an item into the manipulator if it is empty and the item is on the whitelist. Returns whether it did
/obj/item/cyborg_manipulator/proc/try_hold(obj/item/new_item)
	if(QDELETED(new_item) || get_held() || !can_hold(new_item))
		return FALSE
	new_item.forceMove(src)
	held_item = new_item
	update_borg_hud(loc)
	return TRUE

///Tells the cyborg's HUD what we hold
/obj/item/cyborg_manipulator/proc/update_borg_hud(mob/user)
	var/mob/living/silicon/robot/borg = user
	if(istype(borg))
		borg.update_module_hud()

//Empty, it picks things up. Holding something, anything that reaches this uses the item instead
/obj/item/cyborg_manipulator/preattack(atom/target, mob/user, params)
	var/obj/item/shown_held = get_held()
	if(shown_held)
		if(target == shown_held)
			return TRUE
		shown_held.melee_attack_chain(user, target, params, params2list(params)[RIGHT_CLICK])
		update_borg_hud(user)
		return TRUE
	if(!isitem(target) || !user.Adjacent(target))
		return ..()
	if(!can_hold(target))
		user.balloon_alert(user, "can't hold that")
		return TRUE
	var/obj/item/picked_item = target
	if(picked_item.anchored || !isturf(picked_item.loc))
		user.balloon_alert(user, "can't pick that up")
		return TRUE
	picked_item.forceMove(src)
	held_item = picked_item
	user.visible_message(span_notice("[user] picks up [picked_item]."), span_notice("You pick up [picked_item]."))
	playsound(user, 'sound/machines/click.ogg', 15, TRUE)
	update_borg_hud(user)
	return TRUE

///Drops what it holds
/obj/item/cyborg_manipulator/attack_self(mob/user)
	var/obj/item/dropped_item = get_held()
	if(!dropped_item)
		user.balloon_alert(user, "nothing to drop")
		return
	dropped_item.forceMove(user.drop_location())
	held_item = null
	user.visible_message(span_notice("[user] drops [dropped_item]."), span_notice("You drop [dropped_item]."))
	update_borg_hud(user)

/**
 * The manipulator of a field medic. It holds the things a medic hands around, bottles, beakers, pills and blood bags, so they can be loaded into the chem machines and hung on an IV drip.
 * Empty, it also works as a hand on machines, which is how the chem machines are opened, and takes the bag off an IV drip.
 */
/obj/item/cyborg_manipulator/medical
	name = "medical manipulator"
	desc = "A robotic hand for medical supplies. Click a bottle, beaker, pill or blood bag to pick it up, then click something to use it on that. Use the manipulator itself to drop what it holds. Empty, click a machine to use it, or an IV drip to take its bag."
	///The types of item it can pick up, subtypes included
	var/static/list/medical_whitelist = typecacheof(list(
		/obj/item/reagent_containers/glass/bottle,
		/obj/item/reagent_containers/glass/beaker,
		/obj/item/reagent_containers/pill,
		/obj/item/reagent_containers/blood,
	))

/obj/item/cyborg_manipulator/medical/can_hold(atom/target)
	return is_type_in_typecache(target, medical_whitelist)

/obj/item/cyborg_manipulator/medical/preattack(atom/target, mob/user, params)
	if(get_held() || !ismachinery(target) || !user.Adjacent(target))
		return ..()
	//Empty, an IV drip gives up its bag
	var/obj/machinery/iv_drip/drip = target
	if(istype(drip))
		var/obj/item/reagent_containers/bag = drip.beaker
		if(bag)
			drip.remove_beaker()
			try_hold(bag)
			user.visible_message(span_notice("[user] takes [bag] off [drip]."), span_notice("You take [bag] off [drip]."))
			return TRUE
	//Any other machine is used the way a hand would use it
	user.UnarmedAttack(target, TRUE, params2list(params))
	return TRUE

/**
 * Drains an APC's cell into the cell of the cyborg using it. Every module carries one, see base_item_types in robot_modules.dm.
 * Use it on an APC, it keeps pulling until the cyborg is full, the APC is empty or the cyborg is interrupted.
 */
/obj/item/cyborg_tesla
	name = "tesla charger"
	desc = "Drains the cell of an APC to charge a cyborg. Use it on an APC."
	icon = 'icons/obj/machines/deployable/sentry/tesla.dmi'
	//Placeholder sprite
	icon_state = "tesla_coil_handheld"
	w_class = WEIGHT_CLASS_SMALL
	item_flags = NOBLUDGEON

/obj/item/cyborg_tesla/preattack(atom/target, mob/user, params)
	var/mob/living/silicon/robot/borg = user
	if(!istype(borg) || !istype(target, /obj/machinery/power/apc) || !borg.Adjacent(target))
		return ..()
	drain_apc(target, borg)
	return TRUE

///Pulls charge out of the APC until something stops it
/obj/item/cyborg_tesla/proc/drain_apc(obj/machinery/power/apc/apc, mob/living/silicon/robot/borg)
	if(!borg.cell)
		borg.balloon_alert(borg, "no power cell")
		return
	if(!apc.cell || (apc.machine_stat & BROKEN))
		borg.balloon_alert(borg, "apc has no cell")
		return
	if(borg.cell.is_fully_charged())
		borg.balloon_alert(borg, "already full")
		return
	borg.visible_message(span_notice("[borg] touches [apc] with [src]."), span_notice("You start drawing power from [apc]."))
	while(!QDELETED(apc) && !QDELETED(borg) && borg.cell && apc.cell && !borg.cell.is_fully_charged())
		if(!do_after(borg, CYBORG_TESLA_PULSE_TIME, NONE, apc, BUSY_ICON_BUILD))
			return
		if(!borg.cell || !apc.cell)
			return
		var/taken = min(CYBORG_TESLA_DRAIN, apc.cell.charge, borg.cell.maxcharge - borg.cell.charge)
		if(taken <= 0 || !apc.cell.use(taken))
			borg.balloon_alert(borg, "apc is drained")
			return
		borg.cell.give(taken)
		borg.update_power_state()
		var/datum/effect_system/spark_spread/sparks = new
		sparks.set_up(2, 0, apc)
		sparks.attach(apc)
		sparks.start()
		playsound(apc, 'sound/effects/sparks2.ogg', 25, TRUE)
	if(borg.cell?.is_fully_charged())
		borg.balloon_alert(borg, "fully charged")

/**
 * A hypospray for the basic chems. They all draw on one reservoir inside it, which refills over time for as long as the cyborg carrying it has power.
 * Using it opens a radial menu to choose the chem, clicking a living thing injects it.
 */
/obj/item/cyborg_hypospray
	name = "cyborg hypospray"
	desc = "A hypospray with a reservoir that refills from the cyborg's power cell. Use it to choose a chem, click someone to inject them."
	icon = 'icons/obj/items/syringe.dmi'
	icon_state = "hypo"
	w_class = WEIGHT_CLASS_SMALL
	item_flags = NOBLUDGEON
	///What is left in the reservoir, any chem can use it
	var/chem_charge = CYBORG_HYPO_MAX_CHARGE
	///What it is called before the chem it is set to
	var/label = "cyborg hypospray"
	///The chem it injects
	var/selected_chem = /datum/reagent/medicine/bicaridine
	///How much one injection gives
	var/dose = 5
	///The chems it can make
	var/static/list/chems = list(
		/datum/reagent/medicine/bicaridine,
		/datum/reagent/medicine/tricordrazine,
		/datum/reagent/medicine/dylovene,
		/datum/reagent/medicine/kelotane,
		/datum/reagent/medicine/inaprovaline,
	)

///The chems it can make
/obj/item/cyborg_hypospray/proc/get_chems()
	return chems

/obj/item/cyborg_hypospray/Initialize(mapload)
	. = ..()
	update_chem_name()
	START_PROCESSING(SSobj, src)

/obj/item/cyborg_hypospray/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/cyborg_hypospray/examine(mob/user)
	. = ..()
	. += span_notice("It is set to [get_chem_name()]. The reservoir holds [round(chem_charge)]/[CYBORG_HYPO_MAX_CHARGE] units, an injection uses [dose].")

//The slot of a cyborg shows what is left in the reservoir
/obj/item/cyborg_hypospray/get_hud_count()
	return round(chem_charge)

//The slot of a cyborg shows the first two letters of the chem we are set to
/obj/item/cyborg_hypospray/get_hud_label()
	return uppertext(copytext(get_chem_name(), 1, 3))

///Refills the reservoir, which costs the cyborg's cell some charge
/obj/item/cyborg_hypospray/process()
	if(chem_charge >= CYBORG_HYPO_MAX_CHARGE)
		return
	var/mob/living/silicon/robot/borg = loc
	if(!istype(borg) || !borg.cell || borg.out_of_power)
		return
	var/refill = min(CYBORG_HYPO_REGEN, CYBORG_HYPO_MAX_CHARGE - chem_charge)
	if(!borg.cell.use(refill * CYBORG_HYPO_CELL_COST))
		return
	chem_charge += refill

///The name of the chem we are set to
/obj/item/cyborg_hypospray/proc/get_chem_name()
	var/datum/reagent/chem_type = selected_chem
	return initial(chem_type.name)

///Names the hypospray after the chem it is set to
/obj/item/cyborg_hypospray/proc/update_chem_name()
	name = "[label] ([get_chem_name()])"

//Opens the radial menu of chems
/obj/item/cyborg_hypospray/attack_self(mob/user)
	var/list/choices = list()
	for(var/datum/reagent/chem_type AS in get_chems())
		var/image/chem_image = image(icon = icon, icon_state = icon_state)
		chem_image.color = initial(chem_type.color)
		choices[initial(chem_type.name)] = chem_image
	var/choice = show_radial_menu(user, src, choices, custom_check = CALLBACK(src, PROC_REF(can_use_menu), user), require_near = TRUE, tooltips = TRUE)
	if(!choice || !can_use_menu(user))
		return
	for(var/datum/reagent/chem_type AS in get_chems())
		if(initial(chem_type.name) != choice)
			continue
		selected_chem = chem_type
		update_chem_name()
		user.balloon_alert(user, "set to [choice]")
		var/mob/living/silicon/robot/borg = user
		if(istype(borg))
			borg.update_module_hud()
		return

///The menu closes itself when this stops being true
/obj/item/cyborg_hypospray/proc/can_use_menu(mob/user)
	return !QDELETED(src) && !QDELETED(user) && user.is_holding(src) && !user.incapacitated()

//Clicking a living thing injects it
/obj/item/cyborg_hypospray/preattack(atom/target, mob/user, params)
	if(!isliving(target) || !user.Adjacent(target))
		return ..()
	inject(target, user)
	return TRUE

///Injects the chem we are set to, if the reservoir has enough
/obj/item/cyborg_hypospray/proc/inject(mob/living/target, mob/user)
	if(chem_charge < dose)
		user.balloon_alert(user, "reservoir is recharging")
		return
	if(iscarbon(target))
		var/mob/living/carbon/carbon_target = target
		if((carbon_target.species.species_flags & NO_CHEM_METABOLIZATION) || (carbon_target.species.species_flags & IS_SYNTHETIC))
			carbon_target.balloon_alert(user, "can't inject (robot)")
			return
	if(!target.can_inject(user, TRUE, user.zone_selected, TRUE))
		return
	if(target.faction != user.faction && !target.incapacitated())
		user.visible_message(span_notice("[user] attempts to inject [target] with [src]."), span_notice("You attempt to inject [target] with [src]."))
		if(!do_after(user, SKILL_TASK_VERY_EASY, NONE, target, BUSY_ICON_HOSTILE) || !user.Adjacent(target))
			return
	if(chem_charge < dose)
		return
	log_combat(user, target, "injected", src, "Reagents: [get_chem_name()]")
	user.changeNext_move(3)
	playsound(loc, 'sound/items/hypospray.ogg', 50, TRUE)
	var/datum/reagents/injection = new(dose)
	injection.add_reagent(selected_chem, dose)
	injection.reaction(target, INJECT)
	injection.trans_to(target, dose)
	qdel(injection)
	chem_charge -= dose
	user.balloon_alert(user, "injects [target]")
	to_chat(target, span_warning("You feel a tiny prick!"))
	to_chat(user, span_notice("[dose] units of [get_chem_name()] injected. [round(chem_charge)] units left in the reservoir."))

/**
 * The second hypospray of a field medic, for the harder cases. It works like the first, with its own reservoir.
 */
/obj/item/cyborg_hypospray/advanced
	name = "advanced cyborg hypospray"
	label = "advanced cyborg hypospray"
	selected_chem = /datum/reagent/medicine/alkysine
	///The chems it can make
	var/static/list/advanced_chems = list(
		/datum/reagent/medicine/alkysine,
		/datum/reagent/medicine/meralyne,
		/datum/reagent/medicine/dermaline,
		/datum/reagent/medicine/imidazoline,
		/datum/reagent/hypervene,
		/datum/reagent/medicine/quickclot,
	)

/obj/item/cyborg_hypospray/advanced/get_chems()
	return advanced_chems

/**
 * The roller bed rack of a cyborg. It holds one folded roller bed. Clicking a loose folded one, or a roller bed that nobody is on, folds it into the rack,
 * clicking an empty tile or using the rack puts the bed down.
 */
/obj/item/roller_holder/cyborg
	name = "roller bed rack"
	desc = "A rack for carrying a collapsed roller bed. Click a roller bed to pick it up, click a free tile or use the rack to put it down."

//The slot of a cyborg shows whether it holds a bed
/obj/item/roller_holder/cyborg/get_hud_count()
	return held ? 1 : 0

/obj/item/roller_holder/cyborg/preattack(atom/target, mob/user, params)
	if(!user.Adjacent(target))
		return ..()
	if(istype(target, /obj/item/roller))
		var/obj/item/roller/loose_roller = target
		if(loose_roller.rollertype != /obj/structure/bed/roller)
			return ..()
		if(held)
			user.balloon_alert(user, "already holding one")
			return TRUE
		pick_up_roller(loose_roller, user)
		return TRUE
	if(istype(target, /obj/structure/bed/roller))
		var/obj/structure/bed/roller/bed = target
		if(bed.foldabletype != /obj/item/roller)
			return ..()
		if(held)
			user.balloon_alert(user, "already holding one")
			return TRUE
		if(LAZYLEN(bed.buckled_mobs) || bed.buckled_bodybag)
			user.balloon_alert(user, "someone is on it")
			return TRUE
		var/obj/item/roller/folded_roller = new(src)
		pick_up_roller(folded_roller, user)
		qdel(bed)
		return TRUE
	if(isturf(target))
		if(!held)
			user.balloon_alert(user, "the rack is empty")
			return TRUE
		var/turf/target_turf = target
		if(target_turf.density)
			user.balloon_alert(user, "no room")
			return TRUE
		for(var/atom/atom_to_check AS in target_turf)
			if(atom_to_check.density)
				user.balloon_alert(user, "no room")
				return TRUE
		var/obj/structure/bed/roller/placed_bed = new(target_turf)
		to_chat(user, span_notice("You deploy [placed_bed]."))
		QDEL_NULL(held)
		return TRUE
	return ..()

///Puts a folded roller bed in the rack
/obj/item/roller_holder/cyborg/proc/pick_up_roller(obj/item/roller/folded_roller, mob/user)
	to_chat(user, span_notice("You pick up [folded_roller]."))
	folded_roller.forceMove(src)
	held = folded_roller
