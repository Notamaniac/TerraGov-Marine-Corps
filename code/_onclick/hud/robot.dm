///How many tools fit on one row of the module panel
#define CYBORG_PANEL_COLUMNS 4
///How many pixels of a module slot, from each edge, count as its frame. A click inside that is on the slot, a click further in is on the tool
#define CYBORG_SLOT_ITEM_MARGIN 8

/**
 * The cyborg HUD. Same layout as TGstation's: the module button and three tool slots along the bottom,
 * with the module panel opening above them, health on the right, and the intent and pull buttons.
 * Icons are TGstation's screen_cyborg.dmi (CC BY-SA 3.0).
 */
/datum/hud/robot
	///The button that picks a module, or opens the tool panel once we have one
	var/atom/movable/screen/robot/module_button/module_button
	///The three tool slots, in order
	var/list/atom/movable/screen/robot/module_slot/slots = list()
	///The tools shown on the open panel, one per tool that is not in a slot
	var/list/atom/movable/screen/robot/tool_entry/panel_entries = list()
	///Is the tool panel open
	var/panel_open = FALSE
	///Puts the selected tool away, only on our screen while the tool panel is open
	var/atom/movable/screen/robot/store_button/store_button
	///Steps the headlamp through its brightness levels
	var/atom/movable/screen/robot/lamp_button/lamp_button
	///Opens the radio window
	var/atom/movable/screen/robot/radio_button/radio_button
	///Shows how much charge our cell has left, only while it is low
	var/atom/movable/screen/robot/battery/battery_icon

/datum/hud/robot/New(mob/living/silicon/robot/owner, ui_style = 'icons/mob/screen/cyborg.dmi', ui_color = "#ffffff", ui_alpha = 230)
	. = ..()
	//Our icons only exist in one style, whatever the player picked in their preferences
	ui_style = 'icons/mob/screen/cyborg.dmi'

	//Tool slots and the module button stay on screen in every HUD mode, the cyborg is useless without them
	module_button = new(null, src)
	always_visible_inventory += module_button
	lamp_button = new(null, src)
	always_visible_inventory += lamp_button
	radio_button = new(null, src)
	always_visible_inventory += radio_button
	battery_icon = new(null, src)
	always_visible_inventory += battery_icon
	//Not in any of the hud lists, refresh_panel puts it on the screen when the panel opens
	store_button = new(null, src)
	for(var/slot_num in 1 to CYBORG_SLOT_COUNT)
		var/atom/movable/screen/robot/module_slot/slot = new(null, src, slot_num)
		slots += slot
		always_visible_inventory += slot

	var/atom/movable/screen/using = new /atom/movable/screen/act_intent/corner(null, src)
	using.icon_state = owner.a_intent
	using.alpha = ui_alpha
	static_inventory += using
	action_intent = using

	pull_icon = new /atom/movable/screen/pull(null, src)
	pull_icon.icon = ui_style
	pull_icon.update_icon()
	hotkeybuttons += pull_icon

	healths = new /atom/movable/screen/healths/robot(null, src)
	infodisplay += healths

	update_module_button()
	update_slots()
	update_health()
	update_battery()

/datum/hud/robot/Destroy()
	var/client/hud_client = mymob?.client
	hud_client?.screen -= panel_entries
	hud_client?.screen -= store_button
	QDEL_LIST(panel_entries)
	QDEL_NULL(store_button)
	lamp_button = null
	radio_button = null
	battery_icon = null
	module_button = null
	slots.Cut()
	return ..()

//F12 rebuilds the client's whole screen, so the panel has to be put back afterwards
/datum/hud/robot/show_hud(version = 0, mob/viewmob)
	. = ..()
	if(!.)
		return
	if(panel_open)
		refresh_panel()

///Shows the module we picked on the module button
/datum/hud/robot/proc/update_module_button()
	var/mob/living/silicon/robot/borg = mymob
	module_button.icon_state = borg.module ? borg.module.hud_icon_state : "nomod"

///Shows what is in each slot, and which of them is selected
/datum/hud/robot/proc/update_slots()
	var/mob/living/silicon/robot/borg = mymob
	for(var/slot_num in 1 to length(slots))
		var/atom/movable/screen/robot/module_slot/slot = slots[slot_num]
		var/obj/item/slot_item = borg.slot_items[slot_num]
		slot.set_item(slot_item, slot_item && slot_item == borg.selected_item)
		slot.set_disabled(borg.slot_disabled[slot_num])

///Shows whether the headlamp is on and at what level
/datum/hud/robot/proc/update_lamp()
	var/mob/living/silicon/robot/borg = mymob
	lamp_button?.update_level(borg.lamp_level)

///Shows the charge of our cell, but only below CYBORG_BATTERY_ICON_PERCENT
/datum/hud/robot/proc/update_battery()
	var/mob/living/silicon/robot/borg = mymob
	battery_icon?.update_charge(borg)

///Shows our health
/datum/hud/robot/proc/update_health()
	var/atom/movable/screen/healths/robot/robot_health = healths
	robot_health?.update_health(mymob)

///Opens the tool panel if it was closed and closes it if it was open
/datum/hud/robot/proc/toggle_panel()
	panel_open = !panel_open
	refresh_panel()

///Closes the tool panel
/datum/hud/robot/proc/close_panel()
	if(!panel_open)
		return
	panel_open = FALSE
	refresh_panel()

///Rebuilds the tool panel, which lists every tool of ours that is not in a slot
/datum/hud/robot/proc/refresh_panel()
	var/client/hud_client = mymob?.client
	hud_client?.screen -= panel_entries
	QDEL_LIST(panel_entries)
	if(!panel_open)
		hud_client?.screen -= store_button
		return
	hud_client?.screen += store_button
	var/mob/living/silicon/robot/borg = mymob
	var/index = 0
	for(var/obj/item/tool AS in borg.module_items)
		if(borg.get_slot_of(tool))
			continue
		var/atom/movable/screen/robot/tool_entry/entry = new(null, src, tool)
		var/column = index % CYBORG_PANEL_COLUMNS
		var/row = round(index / CYBORG_PANEL_COLUMNS)
		entry.screen_loc = "CENTER+[column - 2]:16,SOUTH+[row + 1]:5"
		panel_entries += entry
		index++
	hud_client?.screen += panel_entries

// ***************************************
// *********** Screen objects
// ***************************************
/atom/movable/screen/robot
	icon = 'icons/mob/screen/cyborg.dmi'
	mouse_over_pointer = MOUSE_HAND_POINTER

/atom/movable/screen/robot/Click(location, control, params)
	if(isobserver(usr) || usr != hud?.mymob || usr.incapacitated())
		return TRUE

/atom/movable/screen/robot/module_button
	name = "cyborg module"
	icon_state = "nomod"
	screen_loc = ui_borg_module_button

/atom/movable/screen/robot/module_button/Click(location, control, params)
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = usr
	if(!borg.module)
		INVOKE_ASYNC(borg, TYPE_PROC_REF(/mob/living/silicon/robot, prompt_module_choice))
		return
	var/datum/hud/robot/robot_hud = hud
	robot_hud.toggle_panel()

//Left click steps the headlamp up a level, right click turns it off
/atom/movable/screen/robot/lamp_button
	name = "headlamp"
	icon_state = "lamp_off"
	screen_loc = ui_borg_lamp
	maptext_width = 32
	maptext_y = 2

/atom/movable/screen/robot/lamp_button/proc/update_level(level)
	icon_state = level ? "lamp_on" : "lamp_off"
	maptext = level ? MAPTEXT("[level]") : ""
	name = "headlamp ([GLOB.cyborg_lamp_names[level + 1]])"

/atom/movable/screen/robot/lamp_button/Click(location, control, params)
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = usr
	if(params2list(params)[RIGHT_CLICK])
		borg.set_lamp_level(0)
		return
	borg.cycle_lamp()

//Opens the radio window
/atom/movable/screen/robot/radio_button
	name = "radio"
	icon_state = "radio"
	screen_loc = ui_borg_radio

/atom/movable/screen/robot/radio_button/Click(location, control, params)
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = usr
	borg.ui_interact(borg)

//Shows the charge of our cell while it is low, it is off the screen otherwise
/atom/movable/screen/robot/battery
	name = "battery"
	icon = 'icons/mob/screen/cyborg_battery.dmi'
	icon_state = "battery3"

/atom/movable/screen/robot/battery/proc/update_charge(mob/living/silicon/robot/borg)
	var/percent = borg.cell ? borg.cell.percent() : 0
	if(borg.cell && percent >= CYBORG_BATTERY_ICON_PERCENT)
		screen_loc = null
		return
	screen_loc = ui_borg_battery
	if(!borg.cell || borg.out_of_power)
		icon_state = "battery0"
		name = "battery (empty)"
		return
	name = "battery ([round(percent)]%)"
	if(percent >= 50)
		icon_state = "battery3"
	else if(percent >= 25)
		icon_state = "battery2"
	else
		icon_state = "battery1"

//Puts the tool we are holding back on the panel
/atom/movable/screen/robot/store_button
	name = "store"
	icon_state = "store"
	screen_loc = ui_borg_inv_stow

/atom/movable/screen/robot/store_button/Click(location, control, params)
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = usr
	var/active_slot = borg.get_selected_slot()
	if(!active_slot)
		borg.balloon_alert(borg, "not holding anything")
		return
	borg.unequip_slot(active_slot)

///A number a cyborg's slot shows on the item, null for none. Stacks show how many they hold
/obj/item/proc/get_hud_count()
	return null

///The states of this item's icon a cyborg's slot draws over the item, for tools that show they are on with an overlay
/obj/item/proc/get_hud_overlay_states()
	return list()

/atom/movable/screen/robot/module_slot
	name = "module"
	icon_state = "inv1"
	maptext_width = 32
	maptext_y = 2
	///Which of the three slots this is
	var/slot_num = 1
	///The tool we show, if any
	var/obj/item/shown_item
	///Is our tool the one the cyborg is using
	var/selected = FALSE
	///The icon and icon state of the tool as we last drew it, a tool changes how it looks when it is switched on or turns into another one
	var/shown_icon
	var/shown_icon_state
	///The overlays of the tool as we last drew them, joined into one text
	var/shown_overlays = ""
	///The item a manipulator in the slot holds, which is drawn on it
	var/obj/item/shown_held
	///Is the slot knocked out by damage
	var/disabled = FALSE

/atom/movable/screen/robot/module_slot/Initialize(mapload, datum/hud/hud_owner, slot_num = 1)
	. = ..()
	src.slot_num = slot_num
	name = "module [slot_num]"
	icon_state = "inv[slot_num]"
	switch(slot_num)
		if(1)
			screen_loc = ui_borg_inv1
		if(2)
			screen_loc = ui_borg_inv2
		if(3)
			screen_loc = ui_borg_inv3

/atom/movable/screen/robot/module_slot/Destroy()
	shown_item = null
	shown_held = null
	shown_icon = null
	return ..()

///Changes what we show, only redrawing if something actually changed
/atom/movable/screen/robot/module_slot/proc/set_item(obj/item/new_item, new_selected)
	var/new_text = ""
	if(istype(new_item, /obj/item/stack))
		var/obj/item/stack/new_stack = new_item
		new_text = MAPTEXT_TINY_UNICODE("<div align='right'>[new_stack.amount]</div>")
	if(!new_text && new_item)
		var/hud_count = new_item.get_hud_count()
		if(!isnull(hud_count))
			new_text = MAPTEXT_TINY_UNICODE("<div align='right'>[hud_count]</div>")
	var/obj/item/cyborg_manipulator/hand = new_item
	var/obj/item/new_held = istype(hand) ? hand.get_held() : null
	var/new_overlays = new_item ? jointext(new_item.get_hud_overlay_states(), ",") : ""
	if(shown_overlays == new_overlays && shown_item == new_item && selected == new_selected && maptext == new_text && shown_icon == new_item?.icon && shown_icon_state == new_item?.icon_state && shown_held == new_held)
		return
	shown_overlays = new_overlays
	shown_held = new_held
	shown_item = new_item
	shown_icon = new_item?.icon
	shown_icon_state = new_item?.icon_state
	selected = new_selected
	maptext = new_text
	name = disabled ? "module [slot_num] (offline)" : (new_item ? "module [slot_num]: [new_item.name]" : "module [slot_num]")
	update_icon()

///A slot knocked out by damage is drawn dark red
/atom/movable/screen/robot/module_slot/proc/set_disabled(new_disabled)
	if(disabled == new_disabled)
		return
	disabled = new_disabled
	color = disabled ? "#702020" : null
	name = disabled ? "module [slot_num] (offline)" : (shown_item ? "module [slot_num]: [shown_item.name]" : "module [slot_num]")

/atom/movable/screen/robot/module_slot/update_icon_state()
	. = ..()
	icon_state = "inv[slot_num][selected ? " +a" : ""]"

/atom/movable/screen/robot/module_slot/update_overlays()
	. = ..()
	if(shown_item)
		. += mutable_appearance(shown_item.icon, shown_item.icon_state)
		for(var/overlay_state in shown_item.get_hud_overlay_states())
			. += mutable_appearance(shown_item.icon, overlay_state)
	if(shown_held)
		var/mutable_appearance/held_appearance = mutable_appearance(shown_held.icon, shown_held.icon_state)
		held_appearance.transform = matrix().Scale(0.6, 0.6)
		. += held_appearance

//A slot knocked out by damage does nothing. Left click readies the tool. On a ready tool, a click on the tool uses it (opens the construction menu of a sheet and so on) and a click on the frame lowers it. Right click puts it back on the panel
/atom/movable/screen/robot/module_slot/Click(location, control, params)
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = usr
	var/list/modifiers = params2list(params)
	//Shift click examines the tool in the slot, whether or not the slot works
	if(modifiers["shift"])
		if(shown_item)
			borg.examinate(shown_item)
		return
	if(disabled)
		borg.balloon_alert(borg, "slot offline")
		return
	if(modifiers[RIGHT_CLICK])
		borg.unequip_slot(slot_num)
		return
	//Clicking the tool itself, the middle of the slot, uses it. Clicking the frame around it lowers it, or readies it if it was not selected
	if(shown_item && shown_item == borg.selected_item && is_click_on_item(modifiers))
		borg.activate_selected_item()
		return
	borg.toggle_slot(slot_num)

///Did this click land on the tool drawn in the middle of the slot rather than on the frame around it
/atom/movable/screen/robot/module_slot/proc/is_click_on_item(list/modifiers)
	var/click_x = text2num(modifiers["icon-x"])
	var/click_y = text2num(modifiers["icon-y"])
	if(isnull(click_x) || isnull(click_y))
		return FALSE
	return ISINRANGE(click_x, CYBORG_SLOT_ITEM_MARGIN, world.icon_size - CYBORG_SLOT_ITEM_MARGIN) \
		&& ISINRANGE(click_y, CYBORG_SLOT_ITEM_MARGIN, world.icon_size - CYBORG_SLOT_ITEM_MARGIN)

/atom/movable/screen/robot/tool_entry
	name = "tool"
	icon_state = "template"
	///The tool this entry stands for
	var/obj/item/tool

/atom/movable/screen/robot/tool_entry/Initialize(mapload, datum/hud/hud_owner, obj/item/new_tool)
	. = ..()
	tool = new_tool
	name = tool.name
	desc = tool.desc
	update_icon()

/atom/movable/screen/robot/tool_entry/Destroy()
	tool = null
	return ..()

/atom/movable/screen/robot/tool_entry/update_overlays()
	. = ..()
	if(tool)
		. += mutable_appearance(tool.icon, tool.icon_state)

/atom/movable/screen/robot/tool_entry/Click(location, control, params)
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = usr
	//Shift click examines the tool
	if(params2list(params)["shift"])
		borg.examinate(tool)
		return
	borg.equip_module_item(tool)

/atom/movable/screen/healths/robot
	icon = 'icons/mob/screen/cyborg.dmi'

///Picks the health picture that matches how damaged the cyborg is
/atom/movable/screen/healths/robot/proc/update_health(mob/living/silicon/robot/borg)
	if(borg.stat == DEAD || borg.maxHealth <= 0)
		icon_state = "health7"
		return
	var/percent = borg.health / borg.maxHealth * 100
	if(percent >= 100)
		icon_state = "health0"
	else if(percent >= 80)
		icon_state = "health1"
	else if(percent >= 60)
		icon_state = "health2"
	else if(percent >= 40)
		icon_state = "health3"
	else if(percent >= 20)
		icon_state = "health4"
	else if(percent >= 0)
		icon_state = "health5"
	else
		icon_state = "health6"
