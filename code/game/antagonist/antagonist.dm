/datum/antagonist

	// Text shown when becoming this antagonist.
	var/list/restricted_jobs =     list()   // Jobs that cannot be this antagonist (depending on config)
	var/list/protected_jobs =      list()   // As above.

	// Strings.
	var/welcome_text = "Cry havoc and let slip the dogs of war!"
	var/leader_welcome_text                 // Text shown to the leader, if any.
	var/victory_text                        // World output at roundend for victory.
	var/loss_text                           // As above for loss.
	var/victory_feedback_tag                // Used by the database for end of round loss.
	var/loss_feedback_tag                   // Used by the database for end of round loss.

	// Role data.
	var/id = "traitor"                      // Unique datum identifier.
	var/role_type = BE_TRAITOR              // Preferences option for this role.
	var/role_text = "Traitor"               // special_role text.
	var/role_text_plural = "Traitors"       // As above but plural.

	// Visual references.
	var/antag_indicator                     // icon_state for icons/mob/mob.dm visual indicator.
	var/faction_indicator                   // See antag_indicator, but for factionalized people only.
	var/faction_invisible                   // Can members of the faction identify other antagonists?

	// Faction data.
	var/faction_role_text                   // Role for sub-antags. Mandatory for faction role.
	var/faction_descriptor                  // Description of the cause. Mandatory for faction role.
	var/faction_verb                        // Verb added when becoming a member of the faction, if any.
	var/faction_welcome                     // Message shown to faction members.

	// Spawn values (autotraitor and game mode)
	var/hard_cap = 3                        // Autotraitor var. Won't spawn more than this many antags.
	var/hard_cap_round = 5                  // As above but 'core' round antags ie. roundstart.
	var/initial_spawn_req = 1               // Gamemode using this template won't start without this # candidates.
	var/initial_spawn_target = 3            // Gamemode will attempt to spawn this many antags.
	var/announced                           // Has an announcement been sent?
	var/spawn_announcement                  // When the datum spawn proc is called, does it announce to the world? (ie. xenos)
	var/spawn_announcement_title            // Report title.
	var/spawn_announcement_sound            // Report sound clip.
	var/spawn_announcement_delay            // Time between initial spawn and round announcement.

	// Misc.
	var/landmark_id                         // Spawn point identifier.
	var/mob_path = /mob/living/carbon/human // Mobtype this antag will use if none is provided.
	var/feedback_tag = "traitor_objective"  // End of round
	var/bantype = "Syndicate"               // Ban to check when spawning this antag.
	var/suspicion_chance = 50               // Prob of being on the initial Command report
	var/flags = 0                           // Various runtime options.

	// Used for setting appearance.
	var/list/valid_species =       list("Unathi","Tajara","Skrell","Human")

	// Runtime vars.
	var/datum/mind/leader                   // Current leader, if any.
	var/cur_max = 0                         // Autotraitor current effective maximum.
	var/spawned_nuke                        // Has a bomb been spawned?
	var/nuke_spawn_loc                      // If so, where should it be placed?
	var/list/current_antagonists = list()   // All marked antagonists for this type.
	var/list/pending_antagonists = list()   // Candidates that are awaiting finalized antag status.
	var/list/starting_locations =  list()   // Spawn points.
	var/list/global_objectives =   list()   // Universal objectives if any.
	var/list/candidates =          list()   // Potential candidates.
	var/list/faction_members =     list()   // Semi-antags (in-round revs, borer thralls)

	// ID card stuff.

	var/default_access = list()
	var/id_type = /obj/item/weapon/card/id

/datum/antagonist/New()
	..()
	cur_max = hard_cap
	get_starting_locations()
	if(!role_text_plural)
		role_text_plural = role_text
	if(config.protect_roles_from_antagonist)
		restricted_jobs |= protected_jobs

/datum/antagonist/proc/tick()
	return 1

/datum/antagonist/proc/get_candidates(var/ghosts_only)
	candidates = list() // Clear.

	// Prune restricted status. Broke it up for readability.
	// Note that this is done before jobs are handed out.
	for(var/datum/mind/player in ticker.mode.get_players_for_role(role_type, id))
		if(ghosts_only && !istype(player.current, /mob/dead))
			log_debug("[key_name(player)] is not eligible to become a [role_text]: Only ghosts may join as this role!")
		else if(player.special_role)
			log_debug("[key_name(player)] is not eligible to become a [role_text]: They already have a special role ([player.special_role])!")
		else if (player in pending_antagonists)
			log_debug("[key_name(player)] is not eligible to become a [role_text]: They have already been selected for this role!")
		else if(!can_become_antag(player))
			log_debug("[key_name(player)] is not eligible to become a [role_text]: They are blacklisted for this role!")
		else if(player_is_antag(player))
			log_debug("[key_name(player)] is not eligible to become a [role_text]: They are already an antagonist!")
		else
			candidates += player

	return candidates

/datum/antagonist/proc/attempt_random_spawn()
	build_candidate_list(flags & (ANTAG_OVERRIDE_MOB|ANTAG_OVERRIDE_JOB))
	attempt_spawn()
	finalize_spawn()

/datum/antagonist/proc/attempt_late_spawn(var/datum/mind/player)
	if(!can_late_spawn())
		return 0
	if(!istype(player))
		var/list/players = get_candidates(is_latejoin_template())
		if(players && players.len)
			player = pick(players)
	if(!istype(player))
		message_admins("AUTO[uppertext(ticker.mode.name)]: Failed to find a candidate for [role_text].")
		return 0
	player.current << "<span class='danger'><i>You have been selected this round as an antagonist!</i></span>"
	message_admins("AUTO[uppertext(ticker.mode.name)]: Selected [player] as a [role_text].")
	if(istype(player.current, /mob/dead))
		create_default(player.current)
	else
		add_antagonist(player,0,0,0,1,1)
	return 1

/datum/antagonist/proc/build_candidate_list(var/ghosts_only)
	// Get the raw list of potential players.
	update_current_antag_max()
	candidates = get_candidates(ghosts_only)

//Selects players that will be spawned in the antagonist role from the potential candidates
//Selected players are added to the pending_antagonists lists.
//Attempting to spawn an antag role with ANTAG_OVERRIDE_JOB should be done before jobs are assigned,
//so that they do not occupy regular job slots. All other antag roles should be spawned after jobs are
//assigned, so that job restrictions can be respected.
/datum/antagonist/proc/attempt_spawn(var/rebuild_candidates = 1)

	// Update our boundaries.
	if(!candidates.len)
		return 0

	//Grab candidates randomly until we have enough.
	while(candidates.len && pending_antagonists.len < initial_spawn_target)
		var/datum/mind/player = pick(candidates)
		candidates -= player
		draft_antagonist(player)

	return 1

/datum/antagonist/proc/draft_antagonist(var/datum/mind/player)
	//Check if the player can join in this antag role, or if the player has already been given an antag role.
	if(!can_become_antag(player) || player.special_role)
		log_debug("[player.key] was selected for [role_text] by lottery, but is not allowed to be that role.")
		return 0

	pending_antagonists |= player
	
	//Ensure that antags with ANTAG_OVERRIDE_JOB do not occupy job slots.
	if(flags & ANTAG_OVERRIDE_JOB)
		player.assigned_role = role_text
	
	//Ensure that a player cannot be drafted for multiple antag roles, taking up slots for antag roles that they will not fill.
	player.special_role = role_text
	
	return 1

//Spawns all pending_antagonists. This is done separately from attempt_spawn in case the game mode setup fails.
/datum/antagonist/proc/finalize_spawn()
	if(!pending_antagonists)
		return

	for(var/datum/mind/player in pending_antagonists)
		pending_antagonists -= player
		add_antagonist(player,0,0,1)

//Resets all pending_antagonists, clearing their special_role (and assigned_role if ANTAG_OVERRIDE_JOB is set)
/datum/antagonist/proc/reset()
	for(var/datum/mind/player in pending_antagonists)
		if(flags & ANTAG_OVERRIDE_JOB)
			player.assigned_role = null
		player.special_role = null
	pending_antagonists.Cut()
