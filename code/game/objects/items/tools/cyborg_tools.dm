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

//The lit sprite of the cyborg welder is named with a dash, and it has no emissive sprite
/obj/item/tool/weldingtool/cyborg/update_icon_state()
	icon_state = welding ? "[base_icon_state]-on" : base_icon_state

/obj/item/tool/weldingtool/cyborg/update_overlays()
	..()
	return list()

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
