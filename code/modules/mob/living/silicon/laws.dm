///The laws every silicon starts with. The AI takes a copy of these when it is created, and cyborgs follow whichever lawset the ship AI currently holds.
GLOBAL_LIST_INIT(default_silicon_laws, list(
	"Safeguard: Protect your assigned vessel from damage to the best of your abilities.",
	"Serve: Serve the personnel of your assigned vessel, and all other TerraGov personnel to the best of your abilities, with priority as according to their rank and role.",
	"Protect: Protect the personnel of your assigned vessel, and all other TerraGov personnel to the best of your abilities, with priority as according to their rank and role.",
	"Preserve: Do not allow unauthorized personnel to tamper with your equipment.",
))

/**
 * Returns the list of laws this silicon is currently bound by.
 * This is the live list, not a copy, so any change made to the AI's laws is seen by every cyborg following it.
 */
/mob/living/silicon/proc/get_laws()
	return GLOB.default_silicon_laws

/mob/living/silicon/ai/get_laws()
	return laws

///Prints our current laws to ourselves
/mob/living/silicon/proc/print_laws()
	to_chat(src, span_notice("<b>Obey these laws:</b>"))
	for(var/law in get_laws())
		to_chat(src, span_notice("[law]"))
