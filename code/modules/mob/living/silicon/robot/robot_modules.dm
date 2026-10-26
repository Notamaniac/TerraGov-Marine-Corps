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

/datum/robot_module/engineer
	name = "Combat Engineer"
	desc = "Builds and repairs. Carries the engineer's toolkit, cable and building materials."
	name_prefix = "Builder"
	hud_icon_state = "engineer"
	item_types = list(
		/obj/item/tool/wrench,
		/obj/item/tool/screwdriver,
		/obj/item/tool/wirecutters,
		/obj/item/tool/crowbar,
		/obj/item/tool/weldingtool,
		/obj/item/stack/cable_coil,
		/obj/item/stack/sheet/metal,
		/obj/item/stack/sheet/plasteel,
	)

/datum/robot_module/medical
	name = "Field Medic"
	desc = "Treats the wounded. Carries a health analyzer and a supply of dressings, and sees the medical HUD."
	name_prefix = "Medic"
	hud_icon_state = "medical"
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

	var/list/choices = list()
	for(var/module_name in GLOB.cyborg_modules)
		choices += module_name
	var/choice = tgui_input_list(src, "Which module will you operate with? This cannot be changed later.", "Choose Module", choices)
	if(!choice || module || QDELETED(src))
		return
	if(!GLOB.cyborg_modules[choice])
		return
	set_module(GLOB.cyborg_modules[choice])

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
	return TRUE

// ***************************************
// *********** Tools
// ***************************************
///Creates one of our module's tools and keeps it inside us
/mob/living/silicon/robot/proc/add_module_item(item_type)
	if(QDELETED(src) || stat == DEAD)
		return
	var/obj/item/new_item = new item_type(src)
	if(istype(new_item, /obj/item/stack))
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
	forget_module_item(source)
	update_module_hud()
	addtimer(CALLBACK(src, PROC_REF(add_module_item), source.type), CYBORG_RESTOCK_INTERVAL)

///Tops up the stacks and welder fuel our module handed out
/mob/living/silicon/robot/proc/restock_module_items()
	if(!COOLDOWN_FINISHED(src, restock_cooldown))
		return
	COOLDOWN_START(src, restock_cooldown, CYBORG_RESTOCK_INTERVAL)
	for(var/obj/item/module_item AS in module_items)
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
