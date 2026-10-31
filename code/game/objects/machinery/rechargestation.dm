/obj/machinery/recharge_station
	name = "cyborg recharging station"
	icon = 'icons/obj/objects.dmi'
	icon_state = "borgcharger0"
	density = TRUE
	anchored = TRUE
	use_power = 0

/obj/machinery/recharge_station/Initialize(mapload)
	. = ..()
	replace_with_functional()
	return INITIALIZE_HINT_QDEL

///This one is only a prop. Swaps itself for a charger that works, wherever it is placed
/obj/machinery/recharge_station/proc/replace_with_functional()
	var/obj/machinery/cyborg_charger/charger = new(loc)
	charger.setDir(dir)

/**
 * A station that charges the cell of the cyborg inside it. A cyborg climbs in by clicking the station or dragging itself onto it, and leaves by trying to move.
 * It takes the power it gives from the area it is in, so it does nothing without power.
 */
/obj/machinery/cyborg_charger
	name = "cyborg recharging station"
	desc = "A station that recharges the power cell of the cyborg inside it. Click it to climb in, move to climb out."
	icon = 'icons/obj/objects.dmi'
	icon_state = "borgcharger0"
	density = TRUE
	anchored = TRUE
	use_power = IDLE_POWER_USE
	idle_power_usage = 50
	power_channel = EQUIP
	///The cyborg inside
	var/mob/living/silicon/robot/charging_borg

/obj/machinery/cyborg_charger/Destroy()
	eject_borg()
	return ..()

/obj/machinery/cyborg_charger/update_icon_state()
	. = ..()
	icon_state = "borgcharger[charging_borg ? 1 : 0]"

/obj/machinery/cyborg_charger/examine(mob/user)
	. = ..()
	if(charging_borg)
		. += span_notice("[charging_borg] is inside.")

/obj/machinery/cyborg_charger/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	if(iscyborg(user))
		move_inside(user)
		return
	if(charging_borg)
		eject_borg()

/obj/machinery/cyborg_charger/MouseDrop_T(mob/dropped, mob/user)
	. = ..()
	if(dropped == user && iscyborg(user))
		move_inside(user)

///A cyborg climbs in
/obj/machinery/cyborg_charger/proc/move_inside(mob/living/silicon/robot/borg)
	if(charging_borg)
		balloon_alert(borg, "occupied")
		return
	if(borg.stat == DEAD || borg.incapacitated() || !borg.Adjacent(src))
		return
	borg.visible_message(span_notice("[borg] starts climbing into [src]."), span_notice("You start climbing into [src]."))
	if(!do_after(borg, 1 SECONDS, NONE, src, BUSY_ICON_GENERIC))
		return
	if(charging_borg || QDELETED(borg) || !borg.Adjacent(src))
		return
	borg.stop_pulling()
	borg.forceMove(src)
	charging_borg = borg
	start_processing()
	update_icon()
	to_chat(borg, span_notice("You settle into [src]. Try to move to climb out."))

///The cyborg inside climbs out
/obj/machinery/cyborg_charger/proc/eject_borg()
	if(!charging_borg)
		return
	var/mob/living/silicon/robot/leaving = charging_borg
	charging_borg = null
	stop_processing()
	if(!QDELETED(leaving) && leaving.loc == src)
		leaving.forceMove(get_turf(src))
	update_icon()

/obj/machinery/cyborg_charger/relaymove(mob/living/user, direct)
	if(user != charging_borg)
		return
	eject_borg()

/obj/machinery/cyborg_charger/process()
	if(!charging_borg || QDELETED(charging_borg) || charging_borg.loc != src)
		charging_borg = null
		update_icon()
		return PROCESS_KILL
	if(machine_stat & (BROKEN|NOPOWER))
		return
	var/obj/item/cell/borg_cell = charging_borg.cell
	if(!borg_cell || borg_cell.is_fully_charged())
		return
	var/given = min(CYBORG_CHARGER_RATE, borg_cell.maxcharge - borg_cell.charge)
	borg_cell.give(given)
	use_power(given / GLOB.CELLRATE)
	charging_borg.update_power_state()
	if(borg_cell.is_fully_charged())
		to_chat(charging_borg, span_notice("Your cell is fully charged."))
