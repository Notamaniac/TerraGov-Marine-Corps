/**
 * A cyborg has CYBORG_SLOT_COUNT slots. Its module's tools all stay inside it, putting a tool in a slot only decides what it shows on the HUD,
 * and selecting a slot decides which tool it clicks with.
 */

///Tells the HUD to redraw the slots and, if it is open, the tool panel
/mob/living/silicon/robot/proc/update_module_hud()
	var/datum/hud/robot/robot_hud = hud_used
	if(!istype(robot_hud))
		return
	robot_hud.update_slots()
	robot_hud.refresh_panel()

///Returns the number of the slot a tool is in, or 0 if it is not in one
/mob/living/silicon/robot/proc/get_slot_of(obj/item/checked_item)
	if(!checked_item)
		return 0
	return slot_items.Find(checked_item)

///Returns the number of the selected slot, or 0 if nothing is selected
/mob/living/silicon/robot/proc/get_selected_slot()
	return get_slot_of(selected_item)

///Puts one of our module's tools in the first free slot, selecting it if we were not holding anything
/mob/living/silicon/robot/proc/equip_module_item(obj/item/tool)
	if(stat == DEAD || incapacitated())
		return FALSE
	if(!(tool in module_items))
		return FALSE
	if(get_slot_of(tool))
		to_chat(src, span_warning("Your [tool.name] is already equipped."))
		return FALSE
	var/free_slot = 0
	for(var/slot_num in 1 to CYBORG_SLOT_COUNT)
		if(!slot_items[slot_num])
			free_slot = slot_num
			break
	if(!free_slot)
		to_chat(src, span_warning("All of your slots are full, stow something first."))
		return FALSE
	slot_items[free_slot] = tool
	to_chat(src, span_notice("You equip your [tool.name] in slot [free_slot]."))
	if(selected_item)
		update_module_hud()
	else
		select_slot(free_slot)
	return TRUE

///Takes the tool out of a slot and puts it back on the panel
/mob/living/silicon/robot/proc/unequip_slot(slot_num)
	if(slot_num < 1 || slot_num > CYBORG_SLOT_COUNT)
		return FALSE
	var/obj/item/stowed_item = slot_items[slot_num]
	if(!stowed_item)
		return FALSE
	if(stowed_item == selected_item)
		selected_item = null
	slot_items[slot_num] = null
	to_chat(src, span_notice("You stow your [stowed_item.name]."))
	update_module_hud()
	return TRUE

///Makes the tool in a slot the thing we click with
/mob/living/silicon/robot/proc/select_slot(slot_num)
	if(slot_num < 1 || slot_num > CYBORG_SLOT_COUNT)
		return FALSE
	var/obj/item/new_item = slot_items[slot_num]
	if(!new_item)
		return FALSE
	selected_item = new_item
	to_chat(src, span_notice("You ready your [new_item.name]."))
	update_module_hud()
	return TRUE

///Stops using whatever we are holding, it stays in its slot
/mob/living/silicon/robot/proc/deselect_active()
	if(!selected_item)
		return FALSE
	to_chat(src, span_notice("You lower your [selected_item.name]."))
	selected_item = null
	update_module_hud()
	return TRUE

///Selects the slot if it is not selected, otherwise lowers its tool
/mob/living/silicon/robot/proc/toggle_slot(slot_num)
	if(stat == DEAD || incapacitated())
		return FALSE
	if(slot_num < 1 || slot_num > CYBORG_SLOT_COUNT || !slot_items[slot_num])
		return FALSE
	if(get_selected_slot() == slot_num)
		return deselect_active()
	return select_slot(slot_num)

///Moves on to the next slot that has a tool in it, wrapping around
/mob/living/silicon/robot/proc/cycle_slots()
	if(stat == DEAD || incapacitated())
		return FALSE
	var/start_slot = get_selected_slot()
	for(var/offset in 1 to CYBORG_SLOT_COUNT)
		var/slot_num = ((start_slot + offset - 1) % CYBORG_SLOT_COUNT) + 1
		if(slot_items[slot_num] && slot_num != start_slot)
			return select_slot(slot_num)
	return FALSE

//Swapping hands cycles through our slots instead
/mob/living/silicon/robot/swap_hand()
	cycle_slots()

// ***************************************
// *********** Using the tool in a slot
// ***************************************

/mob/living/silicon/robot/proc/activate_selected_item()
	if(stat == DEAD || incapacitated() || !selected_item)
		return FALSE
	selected_item.attack_self(src)
	update_module_hud()
	return TRUE

///The use key and the Activate Held Object verb. We hold nothing in our hands, so use the selected tool instead
/mob/living/silicon/robot/mode()
	if(next_move > world.time)
		return
	activate_selected_item()
	if(next_move <= world.time)
		changeNext_move(CLICK_CD_FASTEST)

///Closes the tool panel on our HUD
/mob/living/silicon/robot/proc/close_module_panel()
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.close_panel()

///The tool equipped to its slot is gone, drop it from our slots and put a fresh one back later
/mob/living/silicon/robot/proc/forget_module_item(obj/item/gone_item)
	var/slot_num = get_slot_of(gone_item)
	if(slot_num)
		slot_items[slot_num] = null
	if(selected_item == gone_item)
		selected_item = null

// ***************************************
// *********** Verbs, for when the HUD is hidden
// ***************************************
/mob/living/silicon/robot/verb/equip_tool()
	set category = "Cyborg"
	set name = "Equip Tool"

	if(stat == DEAD || incapacitated())
		return
	if(!length(module_items))
		to_chat(src, span_warning("You have no module installed, use Choose Module first."))
		return

	var/list/items_by_name = list()
	for(var/obj/item/module_item AS in module_items)
		if(get_slot_of(module_item))
			continue
		items_by_name[module_item.name] = module_item
	if(!length(items_by_name))
		to_chat(src, span_warning("Everything you have is already equipped."))
		return
	var/choice = tgui_input_list(src, "Which tool do you want to equip?", "Equip Tool", items_by_name)
	if(!choice || !items_by_name[choice])
		return
	equip_module_item(items_by_name[choice])

/mob/living/silicon/robot/verb/stow_tool()
	set category = "Cyborg"
	set name = "Stow Tool"

	if(stat == DEAD)
		return
	var/active_slot = get_selected_slot()
	if(!active_slot)
		to_chat(src, span_warning("You are not holding anything."))
		return
	unequip_slot(active_slot)

 // ***************************************
 // *********** Using the tool in a slot
 // ***************************************
/**
* The tool in our selected slot stands in for a hand. Plenty of code asks a mob what it holds by looking at its l_hand and r_hand,
 * which we never use, so every one of those helpers is answered from selected_item instead.
 */
/mob/living/silicon/robot/get_held_item()
	return selected_item

/mob/living/silicon/robot/get_inactive_held_item()
	return null

/mob/living/silicon/robot/get_held_items()
	. = list()
	if(selected_item)
		. += selected_item

/mob/living/silicon/robot/is_holding(obj/item/checked_item)
	return !!checked_item && checked_item == selected_item

///Wirecutters, multitools and the like only count while they are the selected tool
/mob/living/silicon/robot/is_holding_tool_quality(quality)
	if(selected_item?.tool_behaviour == quality)
		return selected_item
	return null
