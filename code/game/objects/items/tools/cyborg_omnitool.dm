/**
 * The base of the omnitools cyborgs carry. It is one item that can turn into any of several tools.
 * Using it opens a radial menu of the tools it can be, picking one swaps the omnitool into it, and using it again reopens the menu.
 *
 * Each form is a real tool kept inside the omnitool. Plenty of code only accepts a tool by its typepath (iswrench() and so on),
 * so instead of imitating a tool the omnitool passes whatever it is used on to the real one, and copies its look and its tool_behaviour for the code that asks about those.
 * To make an omnitool, make a subtype and list the tools it can become in tool_forms.
 * A form that needs to be used on its own, like a welder that is lit by using it, can't be one: using the omnitool always opens the menu.
 */
/obj/item/tool/cyborg_omnitool
	name = "omnitool"
	desc = "A tool that reconfigures itself into whichever tool is needed. Use it to choose which."
	icon = 'icons/obj/items/tools.dmi'
	icon_state = "wrench"
	w_class = WEIGHT_CLASS_SMALL
	///The typepaths of the tools this can become. The first one is what it starts as
	var/list/tool_forms = list()
	///The real tools we can become, in the order of tool_forms
	var/list/obj/item/form_items = list()
	///The tool we are at the moment, one of form_items
	var/obj/item/active_form

/obj/item/tool/cyborg_omnitool/Initialize(mapload)
	. = ..()
	for(var/form_type in tool_forms)
		form_items += new form_type(src)
	if(length(form_items))
		set_form(form_items[1], silent = TRUE)

/obj/item/tool/cyborg_omnitool/Destroy()
	active_form = null
	QDEL_LIST(form_items)
	return ..()

/obj/item/tool/cyborg_omnitool/examine(mob/user)
	. = ..()
	if(active_form)
		. += span_notice("It is a [active_form.name] at the moment.")

///Turns us into one of our forms, copying how it looks and works
/obj/item/tool/cyborg_omnitool/proc/set_form(obj/item/new_form, silent = FALSE)
	if(!(new_form in form_items))
		return FALSE
	active_form = new_form
	name = "omnitool ([new_form.name])"
	desc = initial(desc)
	icon = new_form.icon
	icon_state = new_form.icon_state
	tool_behaviour = new_form.tool_behaviour
	toolspeed = new_form.toolspeed
	usesound = new_form.usesound
	force = new_form.force
	sharp = new_form.sharp
	attack_verb = new_form.attack_verb
	update_appearance()
	//A cyborg shows us on its HUD
	var/mob/living/silicon/robot/borg = loc
	if(istype(borg))
		borg.update_module_hud()
	if(!silent)
		play_tool_sound(src, 30)
	return TRUE

///Shows the radial menu of everything we can become. Returns the form that was picked, or null
/obj/item/tool/cyborg_omnitool/proc/show_form_menu(mob/user)
	var/list/choices = list()
	for(var/obj/item/form_item AS in form_items)
		choices[form_item.name] = image(icon = form_item.icon, icon_state = form_item.icon_state)
	var/choice = show_radial_menu(user, src, choices, custom_check = CALLBACK(src, PROC_REF(can_use_menu), user), require_near = TRUE, tooltips = TRUE)
	if(!choice)
		return null
	for(var/obj/item/form_item AS in form_items)
		if(form_item.name == choice)
			return form_item
	return null

///The menu closes itself when this stops being true
/obj/item/tool/cyborg_omnitool/proc/can_use_menu(mob/user)
	return !QDELETED(src) && !QDELETED(user) && user.is_holding(src) && !user.incapacitated()

//Using it always opens the menu, again and again
/obj/item/tool/cyborg_omnitool/attack_self(mob/user)
	if(!length(form_items))
		return
	var/obj/item/picked_form = show_form_menu(user)
	if(!picked_form || !can_use_menu(user))
		return
	set_form(picked_form)

//Whatever we are used on is handled by the real tool we currently are
/obj/item/tool/cyborg_omnitool/preattack(atom/target, mob/user, params)
	if(!active_form || target == src || target == active_form)
		return ..()
	active_form.melee_attack_chain(user, target, params, params2list(params)[RIGHT_CLICK])
	return TRUE

///An omnitool with the tools of an engineer
/obj/item/tool/cyborg_omnitool/engineering
	tool_forms = list(
		/obj/item/tool/wrench,
		/obj/item/tool/screwdriver,
		/obj/item/tool/wirecutters,
		/obj/item/tool/crowbar,
		/obj/item/tool/multitool,
	)

///An omnitool with every tool of a surgeon
/obj/item/tool/cyborg_omnitool/surgical
	tool_forms = list(
		/obj/item/tool/surgery/scalpel,
		/obj/item/tool/surgery/hemostat,
		/obj/item/tool/surgery/retractor,
		/obj/item/tool/surgery/cautery,
		/obj/item/tool/surgery/circular_saw,
		/obj/item/tool/surgery/surgicaldrill,
		/obj/item/tool/surgery/bonegel,
		/obj/item/tool/surgery/bonesetter,
		/obj/item/tool/surgery/FixOVein,
		/obj/item/tool/surgery/suture,
		/obj/item/tool/surgery/surgical_membrane,
	)
