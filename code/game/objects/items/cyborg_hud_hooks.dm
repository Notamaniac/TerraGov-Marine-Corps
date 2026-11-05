/**
 * What the HUD of a cyborg asks an item to show on its slot, see /datum/hud/robot.
 * Every one of these does nothing for an item that does not override it.
 */
///A number a cyborg's slot shows on the item, null for none. Stacks show how many they hold
/obj/item/proc/get_hud_count()
	return null

///A short text a cyborg's slot shows in the corner of the item, null for none. A hypospray shows which chem it is set to
/obj/item/proc/get_hud_label()
	return null

///Stacks show how many they hold
/obj/item/stack/get_hud_count()
	return amount

///The text the HUD of a cyborg draws over this item, the label in the left and the count in the right. Empty for an item with neither
/obj/item/proc/get_hud_text()
	var/hud_text = ""
	var/hud_label = get_hud_label()
	if(hud_label)
		hud_text = "<div align='left'>[hud_label]</div>"
	var/hud_count = get_hud_count()
	if(!isnull(hud_count))
		hud_text += "<div align='right'>[hud_count]</div>"
	if(hud_text)
		hud_text = MAPTEXT_GRAND9K(hud_text)
	return hud_text

///The overlays the HUD of a cyborg draws over this item, as images with an icon, an icon state and maybe a colour. For tools that show what they hold
/obj/item/proc/get_hud_overlays()
	return list()

///The states of this item's icon a cyborg's slot draws over the item, for tools that show they are on with an overlay
/obj/item/proc/get_hud_overlay_states()
	return list()
