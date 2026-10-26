/datum/keybinding/cyborg
	category = CATEGORY_CYBORG
	weight = WEIGHT_MOB
	description = ""

///Selects the tool in a slot, or lowers it if it is already selected
/datum/keybinding/cyborg/toggle_slot
	///The slot this key is for, set by the subtypes
	var/slot_num = 1

/datum/keybinding/cyborg/toggle_slot/down(client/user)
	if(!iscyborg(user.mob))
		return FALSE
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = user.mob
	borg.toggle_slot(slot_num)
	return TRUE

//The number keys already pick intents, so the slots go on Ctrl+number
/datum/keybinding/cyborg/toggle_slot/slot_one
	hotkey_keys = list("Ctrl1")
	name = "cyborg_slot_one"
	full_name = "Use module slot 1"
	keybind_signal = COMSIG_KB_CYBORG_SLOT_ONE_DOWN
	slot_num = 1

/datum/keybinding/cyborg/toggle_slot/slot_two
	hotkey_keys = list("Ctrl2")
	name = "cyborg_slot_two"
	full_name = "Use module slot 2"
	keybind_signal = COMSIG_KB_CYBORG_SLOT_TWO_DOWN
	slot_num = 2

/datum/keybinding/cyborg/toggle_slot/slot_three
	hotkey_keys = list("Ctrl3")
	name = "cyborg_slot_three"
	full_name = "Use module slot 3"
	keybind_signal = COMSIG_KB_CYBORG_SLOT_THREE_DOWN
	slot_num = 3

/datum/keybinding/cyborg/stow_active
	hotkey_keys = list("Q")
	name = "cyborg_stow_active"
	full_name = "Stow the active tool"
	description = "Puts the tool you are holding back on the module panel."
	keybind_signal = COMSIG_KB_CYBORG_STOW_DOWN

/datum/keybinding/cyborg/stow_active/down(client/user)
	if(!iscyborg(user.mob))
		return FALSE
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = user.mob
	var/active_slot = borg.get_selected_slot()
	if(active_slot)
		borg.unequip_slot(active_slot)
	return TRUE

/datum/keybinding/cyborg/cycle_lamp
	hotkey_keys = list("CtrlF")
	name = "cyborg_cycle_lamp"
	full_name = "Cycle headlamp"
	description = "Steps your headlamp up a brightness level, and turns it off after the brightest."
	keybind_signal = COMSIG_KB_CYBORG_LAMP_DOWN

/datum/keybinding/cyborg/cycle_lamp/down(client/user)
	if(!iscyborg(user.mob))
		return FALSE
	. = ..()
	if(.)
		return
	var/mob/living/silicon/robot/borg = user.mob
	borg.cycle_lamp()
	return TRUE
