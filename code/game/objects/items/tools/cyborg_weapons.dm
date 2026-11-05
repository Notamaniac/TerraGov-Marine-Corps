/**
 * The weapons of a combat cyborg.
 * Guns need hands and a wielded grip all over their code, so a cyborg's guns are not guns. They fire the same projectiles, from a charge that refills over time.
 * Refilling is paid for by the cell of the cyborg carrying the weapon, and stops while the cyborg is out of power.
 */

/**
 * A gun that fires from a charge. Click anything to shoot at it.
 * Clicking an adjacent thing that is not alive does not shoot, so the cyborg can still use the things around it with the gun in its slot.
 */
/obj/item/cyborg_gun
	name = "cyborg gun"
	desc = "A gun that refills itself from the cyborg's power cell. Click to shoot."
	icon = 'icons/obj/items/guns/energy.dmi'
	icon_state = "tx7"
	w_class = WEIGHT_CLASS_NORMAL
	item_flags = NOBLUDGEON
	///The projectile it fires
	var/ammo_datum_type = /datum/ammo/energy/lasgun/marine
	var/fire_sound = 'sound/weapons/guns/fire/laser.ogg'
	///The IFF signal of its projectiles, they pass through whoever carries the same one on their ID
	var/iff_signal = NONE
	///What is left of the charge, a shot takes shot_cost of it
	var/charge = 120
	var/max_charge = 120
	var/shot_cost = 8
	///How much it refills each tick, while its cyborg has power
	var/regen = 2
	///Time between shots
	var/fire_delay = 3
	///When it can fire again
	var/next_fire = 0
	///GUN_FIREMODE_SEMIAUTO fires once per click, GUN_FIREMODE_AUTOMATIC keeps firing for as long as the button is held. Use the gun to switch
	var/fire_mode = GUN_FIREMODE_SEMIAUTO
	///Where we are firing at while the button is held down
	var/turf/auto_target
	///The cyborg whose mouse we listen to for automatic fire
	var/mob/living/silicon/robot/borg_owner
	actions_types = list(/datum/action/item_action/cyborg_firemode)

/obj/item/cyborg_gun/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)
	AddComponent(/datum/component/automatedfire/autofire, fire_delay, null, null, 3, fire_mode, CALLBACK(src, PROC_REF(set_bursting)), CALLBACK(src, PROC_REF(reset_fire)), CALLBACK(src, PROC_REF(auto_fire)))
	//The mouse button being held and let go are not clicks, so a gun that is carried by a cyborg listens to the mouse of it from the start
	if(iscyborg(loc))
		borg_owner = loc
		RegisterSignal(borg_owner, COMSIG_MOB_MOUSEDOWN, PROC_REF(start_auto_fire))
		RegisterSignal(borg_owner, COMSIG_MOB_MOUSEDRAG, PROC_REF(change_auto_target))
		RegisterSignal(borg_owner, COMSIG_MOB_MOUSEUP, PROC_REF(stop_auto_fire))

/obj/item/cyborg_gun/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(borg_owner)
		UnregisterSignal(borg_owner, list(COMSIG_MOB_MOUSEDOWN, COMSIG_MOB_MOUSEDRAG, COMSIG_MOB_MOUSEUP))
		borg_owner = null
	auto_target = null
	return ..()

//The slot of a cyborg shows the fire mode too
/obj/item/cyborg_gun/get_hud_label()
	return fire_mode == GUN_FIREMODE_AUTOMATIC ? "AUTO" : "SEMI"

//Using the gun switches between firing once per click and firing while the button is held
/obj/item/cyborg_gun/attack_self(mob/user)
	fire_mode = fire_mode == GUN_FIREMODE_AUTOMATIC ? GUN_FIREMODE_SEMIAUTO : GUN_FIREMODE_AUTOMATIC
	SEND_SIGNAL(src, COMSIG_GUN_FIRE_MODE_TOGGLE, fire_mode)
	user.balloon_alert(user, fire_mode == GUN_FIREMODE_AUTOMATIC ? "automatic" : "semi-automatic")
	playsound(user, 'sound/weapons/guns/interact/selector.ogg', 15, 1)
	for(var/datum/action/item_action/cyborg_firemode/firemode_action in actions)
		firemode_action.update_button_icon()

///Starts firing when the button goes down on something we can shoot at, if we are on automatic
/obj/item/cyborg_gun/proc/start_auto_fire(datum/source, atom/object, turf/location, control, params)
	SIGNAL_HANDLER
	if(fire_mode != GUN_FIREMODE_AUTOMATIC || borg_owner.selected_item != src || borg_owner.incapacitated() || borg_owner.out_of_power)
		return
	var/list/modifiers = params2list(params)
	if(modifiers["shift"] || modifiers["middle"] || modifiers["right"] || modifiers["alt"] || modifiers["ctrl"])
		return
	if(QDELETED(object) || object == borg_owner || (!isliving(object) && borg_owner.Adjacent(object)))
		return
	auto_target = get_turf_on_clickcatcher(object, borg_owner, params)
	if(!auto_target)
		return
	SEND_SIGNAL(src, COMSIG_GUN_FIRE)

///Aims at whatever the mouse is dragged over while we fire
/obj/item/cyborg_gun/proc/change_auto_target(datum/source, atom/src_object, atom/over_object, turf/src_location, turf/over_location, src_control, over_control, params)
	SIGNAL_HANDLER
	if(!auto_target)
		return
	var/turf/new_target = get_turf_on_clickcatcher(over_object, borg_owner, params)
	if(!new_target)
		return
	auto_target = new_target
	borg_owner.face_atom(auto_target)

///Stops firing when the button comes up
/obj/item/cyborg_gun/proc/stop_auto_fire(datum/source)
	SIGNAL_HANDLER
	if(!auto_target)
		return
	SEND_SIGNAL(src, COMSIG_GUN_STOP_FIRE)
	auto_target = null

///The autofire component asks us to fire. Returns AUTOFIRE_CONTINUE to keep going
/obj/item/cyborg_gun/proc/auto_fire()
	if(!auto_target || !borg_owner || borg_owner.selected_item != src || borg_owner.incapacitated() || borg_owner.out_of_power)
		return NONE
	borg_owner.face_atom(auto_target)
	if(!fire(auto_target, borg_owner, ignore_cooldown = TRUE))
		return NONE
	return AUTOFIRE_CONTINUE

///Called by the autofire component when it is done, nothing to tidy up here
/obj/item/cyborg_gun/proc/reset_fire()
	auto_target = null

///Called by the autofire component for bursts, which we do not have
/obj/item/cyborg_gun/proc/set_bursting(bursting)
	return

/obj/item/cyborg_gun/examine(mob/user)
	. = ..()
	. += span_notice("It has [round(charge / shot_cost)] shots left, out of [round(max_charge / shot_cost)].")

//The slot of a cyborg shows the shots we have left
/obj/item/cyborg_gun/get_hud_count()
	return round(charge / shot_cost)

///Refills the charge, which costs the cyborg's cell some power
/obj/item/cyborg_gun/process()
	if(charge >= max_charge)
		return
	var/refill = take_cyborg_refill(regen, max_charge - charge, CYBORG_WEAPON_CELL_COST)
	if(!refill)
		return
	charge += refill
	update_icon()

/obj/item/cyborg_gun/preattack(atom/target, mob/user, params)
	if(target == user || target == src)
		return ..()
	if(!isliving(target) && user.Adjacent(target))
		return ..()
	//On automatic the shots come from holding the button down, not from the click that lets go of it
	if(fire_mode != GUN_FIREMODE_AUTOMATIC)
		fire(target, user)
	return TRUE

//Anything out of reach is not clicked with the melee chain, only afterattack is called on the item
/obj/item/cyborg_gun/afterattack(atom/target, mob/user, has_proximity, click_parameters)
	. = ..()
	if(. || has_proximity || target == user)
		return
	if(fire_mode != GUN_FIREMODE_AUTOMATIC)
		fire(target, user)
	return TRUE

///Shoots at the target, if there is charge for it
/obj/item/cyborg_gun/proc/fire(atom/target, mob/living/user, ignore_cooldown = FALSE)
	if((!ignore_cooldown && next_fire > world.time) || !isturf(user.loc))
		return FALSE
	if(charge < shot_cost)
		user.balloon_alert(user, "recharging")
		return FALSE
	next_fire = world.time + fire_delay
	user.changeNext_move(fire_delay)
	charge -= shot_cost
	update_icon()
	var/atom/movable/projectile/shot = new(get_turf(user))
	shot.generate_bullet(ammo_datum_type)
	shot.def_zone = user.zone_selected
	shot.iff_signal = iff_signal
	playsound(user, fire_sound, 50, TRUE)
	user.log_message("fired [src] at [target]", LOG_ATTACK)
	shot.fire_at(target, user, src, shot.ammo.max_range, shot.projectile_speed)
	return TRUE

///A laser gun, hitscan bolts of the same kind as the marine lasrifle. Its sprite shows how much charge is left
/obj/item/cyborg_gun/laser
	name = "laser gun"
	desc = "A laser gun that refills itself from the cyborg's power cell. Click to shoot."
	icon = 'icons/obj/items_cyborg.dmi'
	icon_state = "laser_cyborg"

///The state of items_cyborg.dmi that shows how much charge is left, drawn over the gun
/obj/item/cyborg_gun/laser/proc/get_charge_state()
	if(charge < shot_cost)
		return "laser_cyborg_empty"
	return "laser_cyborg_charge[clamp(ceil(charge / max_charge * 4), 1, 4)]"

/obj/item/cyborg_gun/laser/update_overlays()
	. = ..()
	. += get_charge_state()

//The slot of a cyborg draws the charge over the gun too
/obj/item/cyborg_gun/laser/get_hud_overlay_states()
	return list(get_charge_state())

///A pistol of 9mm armour piercing rounds that pass through anyone carrying an ID with the TGMC IFF signal
/obj/item/cyborg_gun/pistol
	name = "IFF pistol"
	desc = "A pistol that refills itself from the cyborg's power cell. Its rounds pass through anyone carrying a TGMC IFF signal. Click to shoot."
	icon = 'icons/obj/items/guns/pistols.dmi'
	icon_state = "sp13"
	ammo_datum_type = /datum/ammo/bullet/pistol/ap
	fire_sound = 'sound/weapons/guns/fire/tp14.ogg'
	iff_signal = TGMC_LOYALIST_IFF
	charge = 120
	max_charge = 120
	shot_cost = 3
	regen = 3
	fire_delay = 2

/**
 * A power fist with a cell of its own, which refills over time.
 */
/obj/item/weapon/powerfist/cyborg

/obj/item/weapon/powerfist/cyborg/Initialize(mapload)
	. = ..()
	cell = new /obj/item/cell/lasgun/lasrifle(src)
	update_icon()
	START_PROCESSING(SSobj, src)

/obj/item/weapon/powerfist/cyborg/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

///How much charge a punch takes at the power setting we are on, the same sum the power fist itself does
/obj/item/weapon/powerfist/cyborg/proc/get_punch_cost()
	return setting * 20

//The slot of a cyborg shows how many punches are left at the power setting we are on
/obj/item/weapon/powerfist/cyborg/get_hud_count()
	return cell ? round(cell.charge / get_punch_cost()) : 0

/obj/item/weapon/powerfist/cyborg/process()
	if(!cell || cell.is_fully_charged())
		return
	var/refill = take_cyborg_refill(CYBORG_FIST_REGEN, cell.maxcharge - cell.charge, CYBORG_WEAPON_BATTERY_COST)
	if(refill)
		cell.give(refill)

/**
 * A stun baton that anyone can use, its cell refills over time.
 */
/obj/item/weapon/baton/cyborg
	has_user_lock = FALSE

/obj/item/weapon/baton/cyborg/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/weapon/baton/cyborg/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

//The slot of a cyborg shows how many stuns are left
/obj/item/weapon/baton/cyborg/get_hud_count()
	return bcell ? round(bcell.charge / hitcost) : 0

/obj/item/weapon/baton/cyborg/process()
	if(!bcell || bcell.is_fully_charged())
		return
	var/refill = take_cyborg_refill(CYBORG_BATON_REGEN, bcell.maxcharge - bcell.charge, CYBORG_WEAPON_BATTERY_COST)
	if(refill)
		bcell.give(refill)

///The button for switching a cyborg gun between semi-automatic and automatic, the cyborg has it while the gun is in one of its slots
/datum/action/item_action/cyborg_firemode
	use_obj_appeareance = FALSE
	///The fire mode our button shows
	var/shown_firemode

/datum/action/item_action/cyborg_firemode/update_button_icon()
	var/obj/item/cyborg_gun/gun = target
	if(!gun || gun.fire_mode == shown_firemode)
		return ..()
	shown_firemode = gun.fire_mode
	if(gun.fire_mode == GUN_FIREMODE_AUTOMATIC)
		button.name = "Automatic Firemode ([gun.name])"
		action_icon_state = "fmode_single_auto"
	else
		button.name = "Semi-Automatic Firemode ([gun.name])"
		action_icon_state = "fmode_single"
	return ..()

/datum/action/item_action/cyborg_firemode/handle_button_status_visuals()
	button.color = rgb(255,255,255,255)
