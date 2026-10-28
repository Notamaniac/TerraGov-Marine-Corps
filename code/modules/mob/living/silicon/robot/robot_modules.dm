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
		/obj/item/tool/wrench,
		/obj/item/tool/screwdriver,
		/obj/item/tool/wirecutters,
		/obj/item/tool/crowbar,
		/obj/item/tool/weldingtool,
		/obj/item/stack/cable_coil,
		/obj/item/stack/sheet/metal/cyborg,
		/obj/item/stack/barbed_wire/cyborg,
		/obj/item/stack/razorwire/cyborg,
		/obj/item/stack/sheet/plasteel,
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
	for(var/item_type in module.item_types)
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
	if(stat == DEAD || !icon_exists(icon, "[base_state]_e"))
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

///One of our tools got destroyed or used up, a replacement is fabricated after a while
/mob/living/silicon/robot/proc/on_module_item_deleted(obj/item/source)
	SIGNAL_HANDLER
	if(QDELETED(src))
		return
	module_items -= source
	reservoir_stacks -= source
	forget_module_item(source)
	update_module_hud()
	addtimer(CALLBACK(src, PROC_REF(add_module_item), source.type), CYBORG_RESTOCK_INTERVAL)

///Tops up the stacks and welder fuel our module handed out
/mob/living/silicon/robot/proc/restock_module_items()
	if(!COOLDOWN_FINISHED(src, restock_cooldown))
		return
	COOLDOWN_START(src, restock_cooldown, CYBORG_RESTOCK_INTERVAL)
	//The reservoir refills as one, its stacks just show how much of it they could make
	if(metal_reserve < CYBORG_METAL_RESERVE_MAX)
		metal_reserve = min(metal_reserve + CYBORG_RESTOCK_AMOUNT, CYBORG_METAL_RESERVE_MAX)
		sync_reservoir()
	for(var/obj/item/module_item AS in module_items)
		if(is_reservoir_stack(module_item))
			continue
		if(istype(module_item, /obj/item/stack))
			var/obj/item/stack/restocked_stack = module_item
			if(restocked_stack.amount >= restocked_stack.max_amount)
				continue
			restocked_stack.amount = min(restocked_stack.amount + CYBORG_RESTOCK_AMOUNT, restocked_stack.max_amount)
			restocked_stack.update_weight()
			restocked_stack.update_icon()
			continue
		if(istype(module_item, /obj/item/tool/weldingtool))
			var/obj/item/tool/weldingtool/welder = module_item
			var/missing_fuel = welder.max_fuel - welder.get_fuel()
			if(missing_fuel > 0)
				welder.reagents.add_reagent(/datum/reagent/fuel, min(missing_fuel, CYBORG_RESTOCK_AMOUNT))

// ***************************************
// *********** Metal reservoir
// ***************************************
/**
 * Metal sheets, barbed wire and razor wire all draw on the one reservoir of metal of the cyborg that carries them.
 * A stack's amount is how many it could make from what is left, so using one of them lowers what the others show.
 * They never run out for good, the reservoir refills over time, and they can't be split or have anything added to them.
 */
///Is this one of the tools that draw on our metal reservoir
/mob/living/silicon/robot/proc/is_reservoir_stack(obj/item/checked_item)
	return istype(checked_item, /obj/item/stack/sheet/metal/cyborg) || istype(checked_item, /obj/item/stack/barbed_wire/cyborg) || istype(checked_item, /obj/item/stack/razorwire/cyborg)

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
