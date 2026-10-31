/**
 * The weapons of a combat cyborg.
 * Guns need hands and a wielded grip all over their code, so a cyborg's guns are not guns. They fire the same projectiles, from a charge that refills over time.
 * Refilling is paid for by the cell of the cyborg carrying the weapon, and stops while the cyborg is out of power.
 */

///Takes the cost of refilling a weapon out of the cell of the cyborg carrying it. Returns whether it could be paid
/obj/item/proc/pay_cyborg_cell(cost)
	var/mob/living/silicon/robot/borg = loc
	if(!istype(borg) || !borg.cell || borg.out_of_power)
		return FALSE
	return borg.cell.use(cost)

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

/obj/item/cyborg_gun/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/cyborg_gun/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

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
	var/refill = min(regen, max_charge - charge)
	if(!pay_cyborg_cell(refill * CYBORG_WEAPON_CELL_COST))
		return
	charge += refill

/obj/item/cyborg_gun/preattack(atom/target, mob/user, params)
	if(target == user || target == src)
		return ..()
	if(!isliving(target) && user.Adjacent(target))
		return ..()
	fire(target, user)
	return TRUE

///Shoots at the target, if there is charge for it
/obj/item/cyborg_gun/proc/fire(atom/target, mob/living/user)
	if(next_fire > world.time || !isturf(user.loc))
		return FALSE
	if(charge < shot_cost)
		user.balloon_alert(user, "recharging")
		return FALSE
	next_fire = world.time + fire_delay
	user.changeNext_move(fire_delay)
	charge -= shot_cost
	var/atom/movable/projectile/shot = new(get_turf(user))
	shot.generate_bullet(ammo_datum_type)
	shot.def_zone = user.zone_selected
	shot.iff_signal = iff_signal
	playsound(user, fire_sound, 50, TRUE)
	user.log_message("fired [src] at [target]", LOG_ATTACK)
	shot.fire_at(target, user, src, shot.ammo.max_range, shot.projectile_speed)
	return TRUE

///A laser gun, hitscan bolts of the same kind as the marine lasrifle
/obj/item/cyborg_gun/laser
	name = "laser gun"
	desc = "A laser gun that refills itself from the cyborg's power cell. Click to shoot."

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

//The slot of a cyborg shows how many punches are left at the power setting we are on
/obj/item/weapon/powerfist/cyborg/get_hud_count()
	return cell ? round(cell.charge / (setting * 20)) : 0

/obj/item/weapon/powerfist/cyborg/process()
	if(!cell || cell.is_fully_charged())
		return
	var/refill = min(CYBORG_FIST_REGEN, cell.maxcharge - cell.charge)
	if(!pay_cyborg_cell(refill * CYBORG_WEAPON_BATTERY_COST))
		return
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
	var/refill = min(CYBORG_BATON_REGEN, bcell.maxcharge - bcell.charge)
	if(!pay_cyborg_cell(refill * CYBORG_WEAPON_BATTERY_COST))
		return
	bcell.give(refill)
