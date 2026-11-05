// ***************************************
// *********** Metal reservoir
// ***************************************
/**
 * Metal sheets, barbed wire and razor wire all draw on the one reservoir of metal of the cyborg that carries them.
 * A stack's amount is how many it could make from what is left, so using one of them lowers what the others show.
 * The plasteel sheets have a reservoir of their own. Nothing refills them by itself.
 * They can't be split. Using one on loose metal, plasteel or wire next to us converts what it is used on into reservoir, and uses it up.
 * When the reservoir has nothing for one of them it stays at 0 and can't be used, it is not deleted like an ordinary stack, which would lose the tool for good.
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
		metal_value = get_cyborg_wire_cost(/obj/item/stack/barbed_wire)
	else if(istype(source, /obj/item/stack/razorwire))
		metal_value = get_cyborg_wire_cost(/obj/item/stack/razorwire)
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

///A stack of a cyborg that has nothing left can't be used, it stays at 0 and is not deleted. Returns whether it has any
/proc/cyborg_stack_has_amount(obj/item/stack/stack, mob/user)
	if(stack.get_amount() >= 1)
		return TRUE
	user?.balloon_alert(user, "out of [stack.name]")
	return FALSE

///What the stacks of a cyborg do when they are used on something, before anything else: convert a loose stack, or do nothing if they are empty. Returns TRUE if that was it
/proc/cyborg_stack_preattack(obj/item/stack/stack, atom/target, mob/user)
	if(convert_into_reservoir(target, user))
		return TRUE
	return !cyborg_stack_has_amount(stack, user)

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

/obj/item/stack/sheet/plasteel/cyborg/zero_amount()
	return FALSE

/obj/item/stack/sheet/plasteel/cyborg/attack_self(mob/user)
	if(!cyborg_stack_has_amount(src, user))
		return
	return ..()

/obj/item/stack/sheet/plasteel/cyborg/preattack(atom/target, mob/user, params)
	if(cyborg_stack_preattack(src, target, user))
		return TRUE
	return ..()

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

/obj/item/stack/sheet/metal/cyborg/zero_amount()
	return FALSE

/obj/item/stack/sheet/metal/cyborg/attack_self(mob/user)
	if(!cyborg_stack_has_amount(src, user))
		return
	return ..()

/obj/item/stack/sheet/metal/cyborg/preattack(atom/target, mob/user, params)
	if(cyborg_stack_preattack(src, target, user))
		return TRUE
	return ..()

///How much metal one of a wire type costs in the metal recipes, the metal it takes over the amount it makes
/proc/get_cyborg_wire_cost(wire_type)
	var/datum/stack_recipe/recipe = GLOB.metal_recipes[wire_type]
	return recipe.req_amount / recipe.res_amount

/obj/item/stack/barbed_wire/cyborg
	merge_type = /obj/item/stack/barbed_wire/cyborg

//The recipe is only known at runtime, so the most we can hold is worked out here
/obj/item/stack/barbed_wire/cyborg/Initialize(mapload, new_amount)
	max_amount = CYBORG_METAL_RESERVE_MAX / get_cyborg_wire_cost(/obj/item/stack/barbed_wire)
	return ..()

/obj/item/stack/barbed_wire/cyborg/get_amount()
	return get_reservoir_amount(src, get_cyborg_wire_cost(/obj/item/stack/barbed_wire))

/obj/item/stack/barbed_wire/cyborg/use(used)
	return use_reservoir(src, used, get_cyborg_wire_cost(/obj/item/stack/barbed_wire))

/obj/item/stack/barbed_wire/cyborg/add(extra)
	return FALSE

/obj/item/stack/barbed_wire/cyborg/change_stack(mob/user, new_amount)
	return

/obj/item/stack/barbed_wire/cyborg/zero_amount()
	return FALSE

/obj/item/stack/barbed_wire/cyborg/attack_self(mob/user)
	if(!cyborg_stack_has_amount(src, user))
		return
	return ..()

/obj/item/stack/barbed_wire/cyborg/preattack(atom/target, mob/user, params)
	if(cyborg_stack_preattack(src, target, user))
		return TRUE
	return ..()

/obj/item/stack/razorwire/cyborg
	merge_type = /obj/item/stack/razorwire/cyborg

/obj/item/stack/razorwire/cyborg/Initialize(mapload, new_amount)
	max_amount = CYBORG_METAL_RESERVE_MAX / get_cyborg_wire_cost(/obj/item/stack/razorwire)
	return ..()

/obj/item/stack/razorwire/cyborg/get_amount()
	return get_reservoir_amount(src, get_cyborg_wire_cost(/obj/item/stack/razorwire))

/obj/item/stack/razorwire/cyborg/use(used)
	return use_reservoir(src, used, get_cyborg_wire_cost(/obj/item/stack/razorwire))

/obj/item/stack/razorwire/cyborg/add(extra)
	return FALSE

/obj/item/stack/razorwire/cyborg/change_stack(mob/user, new_amount)
	return

/obj/item/stack/razorwire/cyborg/zero_amount()
	return FALSE

/obj/item/stack/razorwire/cyborg/attack_self(mob/user)
	if(!cyborg_stack_has_amount(src, user))
		return
	return ..()

/obj/item/stack/razorwire/cyborg/preattack(atom/target, mob/user, params)
	if(cyborg_stack_preattack(src, target, user))
		return TRUE
	return ..()
