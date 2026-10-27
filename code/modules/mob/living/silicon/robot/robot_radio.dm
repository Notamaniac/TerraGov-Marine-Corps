/**
 * Cyborgs talk over the silicon radio every silicon carries, which has the channels of its encryption key.
 * The radio window lets the cyborg switch each of those channels on and off, and pick where a message starting with ; goes.
 */
///The channel a message starting with ; is sent on, RADIO_CHANNEL_COMMON means the radio's main frequency
/mob/living/silicon/robot
	var/default_radio_channel = RADIO_CHANNEL_COMMON

/mob/living/silicon/robot/radio(message, message_mode, list/spans, language)
	if(message_mode != MODE_ROBOT || default_radio_channel == RADIO_CHANNEL_COMMON || !radio)
		return ..()
	if(!(default_radio_channel in radio.channels) || !(radio.channels[default_radio_channel] & radio.FREQ_LISTENING))
		//Never let a message that was meant for a closed channel leak out on another one
		to_chat(src, span_warning("Your [default_radio_channel] channel is switched off, nothing was sent."))
		return REDUCE_RANGE
	radio.talk_into(src, message, default_radio_channel, spans, language)
	return REDUCE_RANGE

///Opens the radio window
/mob/living/silicon/robot/verb/open_radio()
	set category = "Cyborg"
	set name = "Radio Settings"

	if(stat == DEAD)
		return
	ui_interact(src)

/mob/living/silicon/robot/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BorgRadio", "Radio")
		ui.open()

/mob/living/silicon/robot/ui_state(mob/user)
	return GLOB.always_state

/mob/living/silicon/robot/ui_status(mob/user, datum/ui_state/state)
	if(user != src || stat == DEAD)
		return UI_CLOSE
	return UI_INTERACTIVE

/mob/living/silicon/robot/ui_data(mob/user)
	var/list/data = list()
	var/list/channel_data = list()
	if(radio)
		for(var/channel_name in radio.channels)
			channel_data += list(list(
				"name" = channel_name,
				"on" = !!(radio.channels[channel_name] & radio.FREQ_LISTENING),
			))
	data["channels"] = channel_data
	data["default_channel"] = default_radio_channel
	data["common"] = RADIO_CHANNEL_COMMON
	return data

/mob/living/silicon/robot/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !radio || stat == DEAD)
		return
	switch(action)
		if("toggle_channel")
			var/channel_name = params["channel"]
			if(!(channel_name in radio.channels))
				return FALSE
			set_radio_channel(channel_name, !(radio.channels[channel_name] & radio.FREQ_LISTENING))
			return TRUE
		if("all_channels")
			var/turn_on = !!params["on"]
			for(var/channel_name in radio.channels)
				set_radio_channel(channel_name, turn_on)
			return TRUE
		if("set_default")
			var/channel_name = params["channel"]
			if(channel_name != RADIO_CHANNEL_COMMON)
				if(!(channel_name in radio.channels))
					return FALSE
				if(!(radio.channels[channel_name] & radio.FREQ_LISTENING))
					balloon_alert(src, "channel is off")
					return FALSE
			default_radio_channel = channel_name
			to_chat(src, span_notice("Messages starting with ; now go to [channel_name]."))
			return TRUE

///Switches a channel of our radio on or off. A closed channel can not be the default one, the default falls back to Common
/mob/living/silicon/robot/proc/set_radio_channel(channel_name, turn_on)
	if(turn_on)
		radio.channels[channel_name] |= radio.FREQ_LISTENING
		return
	radio.channels[channel_name] &= ~radio.FREQ_LISTENING
	if(default_radio_channel == channel_name)
		default_radio_channel = RADIO_CHANNEL_COMMON
		to_chat(src, span_notice("[channel_name] was your default channel, messages starting with ; now go to Common."))
