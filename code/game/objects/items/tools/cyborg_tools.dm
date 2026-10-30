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
 * Turns sheets of metal and plasteel into the reservoirs of the cyborg using it, and the sheets are used up.
 * Nothing else refills a cyborg, see the metal reservoir in robot_modules.dm.
 */
/obj/item/cyborg_sheet_snatcher
	name = "sheet snatcher"
	desc = "Pulls sheets of metal or plasteel apart and stores them in a cyborg's reservoirs. Use it on a sheet, the sheets are used up."
	icon = 'icons/obj/items/sheet_snatcher.dmi'
	icon_state = "sheet_snatcher"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/cyborg_sheet_snatcher/preattack(atom/target, mob/user, params)
	var/mob/living/silicon/robot/borg = user
	if(!istype(borg) || !istype(target, /obj/item/stack/sheet) || !borg.Adjacent(target))
		return ..()
	snatch(target, borg)
	return TRUE

///Takes as many sheets as the matching reservoir has room for
/obj/item/cyborg_sheet_snatcher/proc/snatch(obj/item/stack/sheet/sheet, mob/living/silicon/robot/borg)
	var/is_metal = istype(sheet, /obj/item/stack/sheet/metal) && !istype(sheet, /obj/item/stack/sheet/metal/cyborg)
	var/is_plasteel = istype(sheet, /obj/item/stack/sheet/plasteel) && !istype(sheet, /obj/item/stack/sheet/plasteel/cyborg)
	if(!is_metal && !is_plasteel)
		balloon_alert(borg, "only metal and plasteel")
		return
	var/room = is_metal ? CYBORG_METAL_RESERVE_MAX - borg.metal_reserve : CYBORG_PLASTEEL_RESERVE_MAX - borg.plasteel_reserve
	if(room <= 0)
		balloon_alert(borg, "reservoir full")
		return
	var/taken = min(sheet.get_amount(), room)
	if(!taken || !sheet.use(taken))
		return
	if(is_metal)
		borg.metal_reserve += taken
	else
		borg.plasteel_reserve += taken
	borg.sync_reservoir()
	playsound(borg, 'sound/items/deconstruct.ogg', 25, TRUE)
	borg.balloon_alert(borg, "+[taken] [is_metal ? "metal" : "plasteel"]")

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
