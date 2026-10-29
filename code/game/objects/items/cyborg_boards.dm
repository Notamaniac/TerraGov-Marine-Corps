/**
 * Circuit boards that are installed in a cyborg to change it. The cover has to be open.
 * To make a board, make a subtype and give it can_install() and install().
 */
/obj/item/cyborg_board
	name = "cyborg board"
	desc = "A circuit board that is installed in a cyborg through its open cover."
	icon = 'icons/obj/items/circuitboards.dmi'
	//Placeholder sprite
	icon_state = "cyborg_upgrade"
	w_class = WEIGHT_CLASS_SMALL
	///How long it takes to install
	var/install_time = 2 SECONDS
	///Is the board used up when it is installed
	var/consumed = TRUE

///Can this board be installed in the cyborg. Tells the user why not
/obj/item/cyborg_board/proc/can_install(mob/living/silicon/robot/borg, mob/living/user)
	return TRUE

///Does what the board does to the cyborg. Returns FALSE if nothing happened
/obj/item/cyborg_board/proc/install(mob/living/silicon/robot/borg, mob/living/user)
	return FALSE

///Installs the board in a cyborg, if its cover is open. Returns TRUE if the board was used on it
/obj/item/cyborg_board/proc/try_install(mob/living/silicon/robot/borg, mob/living/user)
	if(!borg.cover_open)
		borg.balloon_alert(user, "open the cover first")
		return TRUE
	if(!can_install(borg, user))
		return TRUE
	user.visible_message(span_notice("[user] starts installing [src] in [borg]."), span_notice("You start installing [src] in [borg]."))
	if(!do_after(user, install_time, NONE, borg, BUSY_ICON_BUILD))
		return TRUE
	//Things can change while we work
	if(!borg.cover_open || !can_install(borg, user))
		return TRUE
	if(!install(borg, user))
		return TRUE
	user.visible_message(span_notice("[user] installs [src] in [borg]."), span_notice("You install [src] in [borg]."))
	if(consumed)
		qdel(src)
	return TRUE

///Puts a cyborg back to having no module, so it picks one again
/obj/item/cyborg_board/reset
	name = "cyborg module reset board"
	desc = "A circuit board that wipes the module of a cyborg, which then picks a new one. The cyborg's cover has to be open to install it."

/obj/item/cyborg_board/reset/can_install(mob/living/silicon/robot/borg, mob/living/user)
	if(!borg.module)
		borg.balloon_alert(user, "no module to reset")
		return FALSE
	return TRUE

/obj/item/cyborg_board/reset/install(mob/living/silicon/robot/borg, mob/living/user)
	return borg.reset_module()
