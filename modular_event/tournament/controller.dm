GLOBAL_LIST_EMPTY(tournament_controllers)

/// Controller for the tournament
/obj/machinery/computer/tournament_controller
	name = "tournament controller"
	desc = "contact mothblocks if you want to learn more"

	/// The arena ID to be looking for
	var/arena_id = ARENA_DEFAULT_ID

	var/list/valid_team_spawns = list()

	var/static/list/arena_templates

	var/loading = FALSE

/obj/machinery/computer/tournament_controller/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()

	if (arena_id in GLOB.tournament_controllers)
		stack_trace("Tournament controller had arena_id \"[arena_id]\", which is reused!")
		return INITIALIZE_HINT_QDEL

	GLOB.tournament_controllers[arena_id] = src

	if (isnull(arena_templates))
		arena_templates = list()
		INVOKE_ASYNC(src, .proc/load_arena_templates)

/obj/machinery/computer/tournament_controller/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "TournamentController")
		ui.open()

/obj/machinery/computer/tournament_controller/ui_static_data(mob/user)
	return list(
		"arena_templates" = assoc_to_keys(arena_templates),
		"team_names" = assoc_to_keys(GLOB.tournament_teams),
	)

/obj/machinery/computer/tournament_controller/ui_act(action, list/params)
	. = ..()
	if (.)
		return .

	switch (action)
		if ("load_arena")
			load_arena(usr, params["arena_template"])
			return TRUE
		if ("spawn_teams")
			spawn_teams(usr, list(params["team_a"], params["team_b"]))
			return TRUE

/obj/machinery/computer/tournament_controller/ui_state(mob/user)
	return GLOB.admin_state

/obj/machinery/computer/tournament_controller/ui_status(mob/user)
	return GLOB.admin_state.can_use_topic(src, user)

/obj/machinery/computer/tournament_controller/proc/get_landmark_turf(landmark_tag)
	for(var/obj/effect/landmark/arena/arena_landmark in GLOB.landmarks_list)
		if (arena_landmark.arena_id == arena_id && arena_landmark.landmark_tag == landmark_tag && isturf(arena_landmark.loc))
			return arena_landmark.loc

/obj/machinery/computer/tournament_controller/proc/get_load_point()
	var/turf/corner_a = get_landmark_turf(ARENA_CORNER_A)
	var/turf/corner_b = get_landmark_turf(ARENA_CORNER_B)
	return locate(min(corner_a.x, corner_b.x), min(corner_a.y, corner_b.y), corner_a.z)

/obj/machinery/computer/tournament_controller/proc/load_arena_templates()
	var/arena_dir = "_maps/toolbox_arenas/"
	var/list/default_arenas = flist(arena_dir)
	for(var/arena_file in default_arenas)
		var/simple_name = replacetext(replacetext(arena_file, arena_dir, ""), ".dmm", "")
		var/datum/map_template/map_template = new("[arena_dir]/[arena_file]", simple_name)
		arena_templates[simple_name] = map_template

/obj/machinery/computer/tournament_controller/proc/load_arena(mob/user, arena_template_name)
	if (loading)
		to_chat(user, span_warning("An arena is already loading."))
		return

	var/datum/map_template/template = arena_templates[arena_template_name]
	if(!template)
		to_chat(user, span_warning("The arena \"[arena_template_name]\" does not exist."))
		return

	// MOTHBLOCKS TODO: clear_arena()
	var/turf/corner_a = get_landmark_turf(ARENA_CORNER_A)
	var/turf/corner_b = get_landmark_turf(ARENA_CORNER_B)
	var/width = abs(corner_a.x - corner_b.x) + 1
	var/height = abs(corner_a.y - corner_b.y) + 1
	if(template.width > width || template.height > height)
		to_chat(user, span_warning("Arena template is too big for the current arena!"))
		return

	loading = TRUE
	var/bounds = template.load(get_load_point())
	loading = FALSE

	if (!bounds)
		to_chat(user, span_warning("Something went wrong while loading the map."))
		return

	message_admins("[key_name_admin(user)] loaded [arena_template_name] event arena for [arena_id] arena.")
	log_admin("[key_name(user)] loaded [arena_template_name] event arena for [arena_id] arena.")

/obj/machinery/computer/tournament_controller/proc/spawn_teams(mob/user, list/team_names)
	var/index = 1

	for (var/team_name in team_names)
		var/datum/tournament_team/team = GLOB.tournament_teams[team_name]
		if (!istype(team))
			to_chat(user, span_warning("Couldn't find team: [team_name]"))
			return

		for (var/client/client as anything in team.get_clients())
			var/mob/living/carbon/human/contestant_mob = client?.mob

			if (!ishuman(contestant_mob))
				contestant_mob = new

			client?.prefs?.apply_prefs_to(contestant_mob)
			contestant_mob.equipOutfit(team.outfit)
			contestant_mob.forceMove(pick(valid_team_spawns[index]))
			contestant_mob.key = client?.key
			contestant_mob.reset_perspective()

		index += 1

	var/message = "loaded [team_names.len] teams ([team_names.Join(", ")]) for [arena_id] arena."
	message_admins("[key_name_admin(user)] [message]")
	log_admin("[key_name(user)] [message]")

/obj/machinery/arena_spawn/LateInitialize()
	. = ..()

	var/obj/machinery/computer/tournament_controller/tournament_controller = GLOB.tournament_controllers[arena_id]
	if (isnull(tournament_controller))
		stack_trace("Arena spawn had an invalid arena_id: \"[arena_id]\"")
		qdel(src)
		return

	var/list/spawn_locations = list()

	var/area/area = get_area(src)
	for (var/obj/effect/landmark/thunderdome/thunderdome_landmark in area)
		spawn_locations += get_turf(thunderdome_landmark)

	tournament_controller.valid_team_spawns += list(spawn_locations)

/obj/effect/landmark/thunderdome/one/Initialize()
	..()
	return INITIALIZE_HINT_NORMAL

/obj/effect/landmark/thunderdome/two/Initialize()
	..()
	return INITIALIZE_HINT_NORMAL

/obj/machinery/arena_spawn/attack_ghost(mob/user)
	return
