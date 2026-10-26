///How many tools fit on one row of the module panel
#define CYBORG_PANEL_COLUMNS 4

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

/datum/hud/robot/New(mob/living/silicon/robot/owner, ui_style = 'icons/mob/screen/cyborg.dmi', ui_color = "#ffffff", ui_alpha = 230)
	. = ..()
	//Our icons only exist in one style, whatever the player picked in their preferences
	ui_style = 'icons/mob/screen/cyborg.dmi'

	//Tool slots and the module button stay on screen in every HUD mode, the cyborg is useless without them
	module_button = new(null, src)
	always_visible_inventory += module_button
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

/datum/hud/robot/Destroy()
	var/client/hud_client = mymob?.client
	hud_client?.screen -= panel_entries
	QDEL_LIST(panel_entries)
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
		return
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
	return ..()

///Changes what we show, only redrawing if something actually changed
/atom/movable/screen/robot/module_slot/proc/set_item(obj/item/new_item, new_selected)
	var/new_text = ""
	if(istype(new_item, /obj/item/stack))
		var/obj/item/stack/new_stack = new_item
		new_text = MAPTEXT_TINY_UNICODE("<div align='right'>[new_stack.amount]</div>")
	if(shown_item == new_item && selected == new_selected && maptext == new_text)
		return
	shown_item = new_item
	selected = new_selected
	maptext = new_text
	name = new_item ? "module [slot_num]: [new_item.name]" : "module [slot_num]"
	update_icon()

/atom/movable/screen/robot/module_slot/update_icon_state()
	. = ..()
	icon_state = "inv[slot_num][selected ? " +a" : ""]"

/atom/movable/screen/robot/module_slot/update_overlays()
	. = ..()
	if(shown_item)
		. += mutable_appearance(shown_item.icon, shown_item.icon_state)

//Left click readies or stows the tool, right click puts it back on the panel
/atom/movable/screen/robot/module_slot/Click(location, control, params)
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = usr
	var/list/modifiers = params2list(params)
	if(modifiers[RIGHT_CLICK])
		borg.unequip_slot(slot_num)
		return
	borg.toggle_slot(slot_num)

/atom/movable/screen/robot/tool_entry
	name = "tool"
	icon_state = "blank"
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
