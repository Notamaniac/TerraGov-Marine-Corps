///The modules a cyborg can choose from, keyed by the name shown to the player
GLOBAL_LIST_INIT(cyborg_modules, list(
	"Combat Engineer" = /datum/robot_module/engineer,
	"Field Medic" = /datum/robot_module/medical,
))

/**
 * Describes what a cyborg gets when it picks a module.
 * To add a module, make a subtype and add it to GLOB.cyborg_modules.
 */
/datum/robot_module
	var/name = "Standard"
	///Shown to the player when they are choosing
	var/desc = ""
	///What the cyborg is called once it picks us, followed by a serial number
	var/name_prefix = "Unit"
	///Typepaths of every tool we hand out. Stacks are refilled over time, welders are refuelled
	var/list/item_types = list()
	///The tools every module hands out, before its own item_types
	var/list/base_item_types = list(/obj/item/cyborg_tesla)
	///DATA_HUD_* defines this module adds to the cyborg
	var/list/huds = list()
	///The icon state of the module button on the cyborg HUD, from icons/mob/screen/cyborg.dmi
	var/hud_icon_state = "nomod"
	///The icon state our cyborg body uses in icons/mob/cyborg.dmi. "[cyborg_base_icon]_e" is its eyes and "[cyborg_base_icon]_transform" the animation
	var/cyborg_base_icon = "robot"
	///How long the "[cyborg_base_icon]_transform" animation lasts, it has to match the length of the state in the dmi
	var/transform_time = 0 SECONDS

/datum/robot_module/engineer
	name = "Combat Engineer"
	desc = "Builds and repairs. Carries the engineer's toolkit, cable and building materials. Light your welder, then click a selected sheet or press the use key to open its construction menu."
	name_prefix = "Builder"
	hud_icon_state = "engineer"
	cyborg_base_icon = "engineer"
	transform_time = 4.5 SECONDS
	item_types = list(
		/obj/item/tool/weldingtool/cyborg,
		/obj/item/tool/cyborg_omnitool/engineering,
		/obj/item/tool/cyborg_omnitool/engineering,
		/obj/item/stack/cable_coil,
		/obj/item/stack/sheet/metal/cyborg,
		/obj/item/stack/barbed_wire/cyborg,
		/obj/item/stack/razorwire/cyborg,
		/obj/item/stack/sheet/plasteel/cyborg,
		/obj/item/cyborg_sheet_snatcher,
		/obj/item/cyborg_manipulator,
		/obj/item/cyborg_meson_scanner,
		/obj/item/flash
	)

/datum/robot_module/medical
	name = "Field Medic"
	desc = "Treats the wounded. Carries a health analyzer and a supply of dressings, and sees the medical HUD."
	name_prefix = "Medic"
	hud_icon_state = "medical"
	cyborg_base_icon = "medical"
	transform_time = 3.6 SECONDS
	item_types = list(
		/obj/item/healthanalyzer,
		/obj/item/stack/medical/heal_pack/advanced/bruise_pack,
		/obj/item/stack/medical/heal_pack/advanced/burn_pack,
		/obj/item/stack/medical/splint,
		/obj/item/cyborg_hypospray,
		/obj/item/cyborg_manipulator/medical,
		/obj/item/roller_holder/cyborg,
		/obj/item/tool/cyborg_omnitool/surgical,
		/obj/item/tool/cyborg_omnitool/surgical,
	)
	huds = list(DATA_HUD_MEDICAL_OBSERVER)

// ***************************************
// *********** Picking a module
// ***************************************
/mob/living/silicon/robot/verb/choose_module()
	set category = "Cyborg"
	set name = "Choose Module"

	prompt_module_choice()

///Asks the player which module they want. Only works once
/mob/living/silicon/robot/proc/prompt_module_choice()
	if(module)
		to_chat(src, span_warning("You already have the [module.name] module."))
		return
	if(!client)
		return

	var/choice
	if(client.prefs.toggles_gameplay & (RADIAL_MEDICAL|RADIAL_STACKS|RADIAL_LASERGUNS))
		choice = show_module_radial()
	else
		var/list/choices = list()
		for(var/module_name in GLOB.cyborg_modules)
			choices += module_name
		choice = tgui_input_list(src, "Which module will you operate with? This cannot be changed later.", "Choose Module", choices)
	if(!choice || module || QDELETED(src))
		return
	if(!GLOB.cyborg_modules[choice])
		return
	set_module(GLOB.cyborg_modules[choice])

///Shows the modules as a radial menu, each one drawn as the body we would turn into. Returns the name of the one picked, or null
/mob/living/silicon/robot/proc/show_module_radial()
	var/list/choices = list()
	for(var/module_name in GLOB.cyborg_modules)
		var/datum/robot_module/module_type = GLOB.cyborg_modules[module_name]
		choices[module_name] = image(icon = 'icons/mob/cyborg.dmi', icon_state = initial(module_type.cyborg_base_icon), dir = SOUTH)
	return show_radial_menu(src, src, choices, custom_check = CALLBACK(src, PROC_REF(can_choose_module)), tooltips = TRUE)

///The radial menu closes itself when this stops being true
/mob/living/silicon/robot/proc/can_choose_module()
	return !module && !QDELETED(src) && stat != DEAD

///Gives us a module and everything that comes with it
/mob/living/silicon/robot/proc/set_module(module_type)
	if(module)
		return FALSE
	module = new module_type
	for(var/item_type in module.base_item_types + module.item_types)
		add_module_item(item_type)
	for(var/hud_define in module.huds)
		var/datum/atom_hud/module_hud = GLOB.huds[hud_define]
		module_hud.add_hud_to(src)

	//A name chosen by the player is kept, otherwise we are named after the module
	if(!custom_name)
		var/old_name = real_name
		fully_replace_character_name(old_name, "[module.name_prefix] [rand(100, 999)]")
		update_names_joined_list(real_name, old_name)

	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.update_module_button()
		robot_hud.toggle_panel()

	to_chat(src, span_notice("You are now a [module.name]. Click a tool on the panel above your slots to equip it, then click its slot to use it."))
	print_laws()
	var/mob/living/silicon/ai/source_ai = get_law_source()
	if(source_ai)
		to_chat(src, span_notice("Your laws are synced to [source_ai]."))
	play_module_transform()
	return TRUE

///Takes our module away, with everything it gave us, so we are as we were before we chose one and have to choose again
/mob/living/silicon/robot/proc/reset_module()
	if(!module)
		return FALSE
	for(var/hud_define in module.huds)
		var/datum/atom_hud/module_hud = GLOB.huds[hud_define]
		module_hud.remove_hud_from(src)
	//These are removed on purpose, they must not be replaced
	for(var/obj/item/module_item AS in module_items)
		UnregisterSignal(module_item, COMSIG_QDELETING)
		qdel(module_item)
	module_items.Cut()
	reservoir_stacks.Cut()
	for(var/slot_num in 1 to CYBORG_SLOT_COUNT)
		slot_items[slot_num] = null
	selected_item = null
	QDEL_NULL(module)

	if(!custom_name)
		var/old_name = real_name
		fully_replace_character_name(old_name, "[initial(real_name)] [rand(100, 999)]")
		update_names_joined_list(real_name, old_name)

	update_cyborg_icon()
	close_module_panel()
	update_module_hud()
	var/datum/hud/robot/robot_hud = hud_used
	if(istype(robot_hud))
		robot_hud.update_module_button()
	to_chat(src, span_warning("Your module has been wiped, you have to choose a new one."))
	//A shut down cyborg is asked once it is rebooted
	if(client && stat != DEAD)
		INVOKE_ASYNC(src, PROC_REF(prompt_module_choice))
	return TRUE

///Plays the animation of our body being rebuilt for the module, we cannot move or act until it is over
/mob/living/silicon/robot/proc/play_module_transform()
	if(!module?.transform_time || !icon_exists(icon, "[module.cyborg_base_icon]_transform"))
		update_cyborg_icon()
		return
	notransform = TRUE
	close_module_panel()
	cut_overlays() //The eyes are off while we are being rebuilt
	icon_state = "[module.cyborg_base_icon]_transform"
	flick("[module.cyborg_base_icon]_transform", src)
	playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
	var/datum/effect_system/spark_spread/sparks = new
	sparks.set_up(5, 0, src)
	sparks.attach(src)
	sparks.start()
	visible_message(span_notice("[src] whirs and clanks as its chassis reconfigures itself."), span_notice("Your chassis reconfigures itself for the [module.name] module..."))
	addtimer(CALLBACK(src, PROC_REF(finish_module_transform)), module.transform_time)

///The animation is over, give control back and show the new body
/mob/living/silicon/robot/proc/finish_module_transform()
	if(QDELETED(src))
		return
	notransform = FALSE
	update_cyborg_icon()
	playsound(src, 'sound/machines/ping.ogg', 30, TRUE)

///Sets our body to the one of our module and puts the eyes on it. Dead cyborgs have their eyes off
/mob/living/silicon/robot/proc/update_cyborg_icon()
	cut_overlays()
	var/base_state = module ? module.cyborg_base_icon : initial(icon_state)
	icon_state = base_state
	//An open cover shows whether our cell is in
	if(cover_open)
		add_overlay(cell ? "ov-opencover +c" : "ov-opencover -c")
	if(stat == DEAD || inactive_shell || !icon_exists(icon, "[base_state]_e"))
		return
	add_overlay("[base_state]_e")
	if(lamp_level && icon_exists(icon, "[base_state]_l"))
		add_overlay("[base_state]_l")

// ***************************************
// *********** Tools
// ***************************************
///Creates one of our module's tools and keeps it inside us
/mob/living/silicon/robot/proc/add_module_item(item_type)
	if(QDELETED(src) || stat == DEAD)
		return
	var/obj/item/new_item = new item_type(src)
	if(is_reservoir_stack(new_item))
		reservoir_stacks += new_item
		sync_reservoir()
	else if(istype(new_item, /obj/item/stack))
		var/obj/item/stack/new_stack = new_item
		new_stack.amount = new_stack.max_amount
		new_stack.update_weight()
		new_stack.update_icon()
	ADD_TRAIT(new_item, TRAIT_NODROP, CYBORG_MODULE_TRAIT)
	RegisterSignal(new_item, COMSIG_QDELETING, PROC_REF(on_module_item_deleted))
	module_items += new_item
	update_module_hud()

///One of our tools got destroyed or used up, it is not replaced
/mob/living/silicon/robot/proc/on_module_item_deleted(obj/item/source)
	SIGNAL_HANDLER
	if(QDELETED(src))
		return
	module_items -= source
	reservoir_stacks -= source
	forget_module_item(source)
	update_module_hud()

// ***************************************
// *********** Metal reservoir
// ***************************************
/**
 * Metal sheets, barbed wire and razor wire all draw on the one reservoir of metal of the cyborg that carries them.
 * A stack's amount is how many it could make from what is left, so using one of them lowers what the others show.
 * The plasteel sheets have a reservoir of their own. Nothing refills them by itself.
 * They can't be split. Using one on loose metal, plasteel or wire next to us converts what it is used on into reservoir, and uses it up.
 */
///Is this one of the tools that draw on our metal reservoir
/mob/living/silicon/robot/proc/is_reservoir_stack(obj/item/checked_item)
	return istype(checked_item, /obj/item/stack/sheet/metal/cyborg) || istype(checked_item, /obj/item/stack/barbed_wire/cyborg) || istype(checked_item, /obj/item/stack/razorwire/cyborg) || istype(checked_item, /obj/item/stack/sheet/plasteel/cyborg)

///Converts a loose stack into whichever reservoir it belongs to and uses it up. Returns FALSE if it is not something we can convert, and tells us if we are full
/mob/living/silicon/robot/proc/absorb_into_reservoir(obj/item/stack/source)
	if(QDELETED(source) || is_reservoir_stack(source))
		return FALSE
	var/is_plasteel = FALSE
	var/metal_value = 0
	if(istype(source, /obj/item/stack/sheet/plasteel))
		is_plasteel = TRUE
		metal_value = 1
	else if(istype(source, /obj/item/stack/sheet/metal))
		metal_value = 1
	else if(istype(source, /obj/item/stack/barbed_wire))
		metal_value = CYBORG_BARBED_WIRE_COST
	else if(istype(source, /obj/item/stack/razorwire))
		metal_value = CYBORG_RAZORWIRE_COST
	else
		return FALSE
	var/room = is_plasteel ? CYBORG_PLASTEEL_RESERVE_MAX - plasteel_reserve : CYBORG_METAL_RESERVE_MAX - metal_reserve
	var/convertible = floor(room / metal_value)
	if(convertible <= 0)
		balloon_alert(src, "reservoir full")
		return TRUE
	var/taken = min(source.get_amount(), convertible)
	if(!taken || !source.use(taken))
		return TRUE
	if(is_plasteel)
		plasteel_reserve += taken
	else
		metal_reserve += taken * metal_value
	sync_reservoir()
	playsound(src, 'sound/items/deconstruct.ogg', 25, TRUE)
	balloon_alert(src, "+[taken * metal_value] [is_plasteel ? "plasteel" : "metal"]")
	return TRUE

///What the stacks of the reservoir do when used on something: loose stacks next to us are converted. Returns TRUE if that is what happened
/proc/convert_into_reservoir(atom/target, mob/user)
	var/mob/living/silicon/robot/borg = user
	if(!istype(borg) || !istype(target, /obj/item/stack) || !isturf(target.loc) || !borg.Adjacent(target))
		return FALSE
	return borg.absorb_into_reservoir(target)

///Makes every tool that draws on the reservoir show what it holds
/mob/living/silicon/robot/proc/sync_reservoir()
	for(var/obj/item/stack/reservoir_stack AS in reservoir_stacks)
		reservoir_stack.amount = reservoir_stack.get_amount()
		reservoir_stack.update_weight()
		reservoir_stack.update_icon()
	update_module_hud()

///How many of a stack costing metal_cost each could be made from the reservoir of the cyborg carrying it
/proc/get_reservoir_amount(obj/item/stack/stack, metal_cost)
	var/mob/living/silicon/robot/borg = stack.loc
	if(!istype(borg))
		return 0
	return floor(borg.metal_reserve / metal_cost)

///Takes used of a stack costing metal_cost each out of the reservoir of the cyborg carrying it
/proc/use_reservoir(obj/item/stack/stack, used, metal_cost)
	var/mob/living/silicon/robot/borg = stack.loc
	if(!istype(borg) || used > get_reservoir_amount(stack, metal_cost))
		return FALSE
	borg.metal_reserve -= used * metal_cost
	borg.sync_reservoir()
	return TRUE

///How many plasteel sheets the reservoir of the cyborg carrying a stack holds
/proc/get_plasteel_reserve_amount(obj/item/stack/stack)
	var/mob/living/silicon/robot/borg = stack.loc
	if(!istype(borg))
		return 0
	return borg.plasteel_reserve

///Takes used sheets out of the plasteel reservoir of the cyborg carrying a stack
/proc/use_plasteel_reserve(obj/item/stack/stack, used)
	var/mob/living/silicon/robot/borg = stack.loc
	if(!istype(borg) || used > borg.plasteel_reserve)
		return FALSE
	borg.plasteel_reserve -= used
	borg.sync_reservoir()
	return TRUE

/obj/item/stack/sheet/plasteel/cyborg
	max_amount = CYBORG_PLASTEEL_RESERVE_MAX
	merge_type = /obj/item/stack/sheet/plasteel/cyborg

/obj/item/stack/sheet/plasteel/cyborg/get_amount()
	return get_plasteel_reserve_amount(src)

/obj/item/stack/sheet/plasteel/cyborg/use(used)
	return use_plasteel_reserve(src, used)

/obj/item/stack/sheet/plasteel/cyborg/add(extra)
	return FALSE

/obj/item/stack/sheet/plasteel/cyborg/change_stack(mob/user, new_amount)
	return

/obj/item/stack/sheet/plasteel/cyborg/preattack(atom/target, mob/user, params)
	return convert_into_reservoir(target, user) || ..()

/obj/item/stack/sheet/metal/cyborg
	max_amount = CYBORG_METAL_RESERVE_MAX
	merge_type = /obj/item/stack/sheet/metal/cyborg

/obj/item/stack/sheet/metal/cyborg/get_amount()
	return get_reservoir_amount(src, 1)

/obj/item/stack/sheet/metal/cyborg/use(used)
	return use_reservoir(src, used, 1)

/obj/item/stack/sheet/metal/cyborg/add(extra)
	return FALSE

/obj/item/stack/sheet/metal/cyborg/change_stack(mob/user, new_amount)
	return

/obj/item/stack/sheet/metal/cyborg/preattack(atom/target, mob/user, params)
	return convert_into_reservoir(target, user) || ..()

/obj/item/stack/barbed_wire/cyborg
	max_amount = CYBORG_METAL_RESERVE_MAX / CYBORG_BARBED_WIRE_COST
	merge_type = /obj/item/stack/barbed_wire/cyborg

/obj/item/stack/barbed_wire/cyborg/get_amount()
	return get_reservoir_amount(src, CYBORG_BARBED_WIRE_COST)

/obj/item/stack/barbed_wire/cyborg/use(used)
	return use_reservoir(src, used, CYBORG_BARBED_WIRE_COST)

/obj/item/stack/barbed_wire/cyborg/add(extra)
	return FALSE

/obj/item/stack/barbed_wire/cyborg/change_stack(mob/user, new_amount)
	return

/obj/item/stack/barbed_wire/cyborg/preattack(atom/target, mob/user, params)
	return convert_into_reservoir(target, user) || ..()

/obj/item/stack/razorwire/cyborg
	max_amount = CYBORG_METAL_RESERVE_MAX / CYBORG_RAZORWIRE_COST
	merge_type = /obj/item/stack/razorwire/cyborg

/obj/item/stack/razorwire/cyborg/get_amount()
	return get_reservoir_amount(src, CYBORG_RAZORWIRE_COST)

/obj/item/stack/razorwire/cyborg/use(used)
	return use_reservoir(src, used, CYBORG_RAZORWIRE_COST)

/obj/item/stack/razorwire/cyborg/add(extra)
	return FALSE

/obj/item/stack/razorwire/cyborg/change_stack(mob/user, new_amount)
	return

/obj/item/stack/razorwire/cyborg/preattack(atom/target, mob/user, params)
	return convert_into_reservoir(target, user) || ..()

// ***************************************
// *********** Meson scanner
// ***************************************
/**
 * Gives the cyborg meson vision for as long as it is the tool the cyborg has selected, the same as a pair of optical meson goggles.
 * The sight itself is set by the cyborg, see update_sight() in robot_inventory.dm.
 */
/obj/item/cyborg_meson_scanner
	name = "optical meson scanner"
	desc = "Scans the surroundings with meson radiation, letting a cyborg see the structure of what is around it. Only works while it is the tool you have selected."
	icon = 'icons/obj/clothing/glasses.dmi'
	icon_state = "meson"
	w_class = WEIGHT_CLASS_SMALL
