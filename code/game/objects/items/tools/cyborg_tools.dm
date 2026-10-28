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
	return list()
