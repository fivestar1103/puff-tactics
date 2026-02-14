extends Node

const CACHE_DIRECTORY_PATH: String = "user://pvp_cache"
const PLAYER_PROFILE_CACHE_PATH: String = "user://pvp_cache/player_profile.json"

const LEADERBOARDS_TABLE: String = "leaderboards"
const PVP_GHOSTS_TABLE: String = "pvp_ghosts"
const PVP_RESULTS_TABLE: String = "pvp_results"

const DEFAULT_ELO: float = 1000.0
const MATCHMAKING_ELO_WINDOW: float = 150.0
const MATCHMAKING_CANDIDATE_LIMIT: int = 24
const ELO_K_FACTOR: float = 32.0
const TEAM_SIZE: int = 4

const WEIGHT_ATTACK_VALUE: String = "attack_value"
const WEIGHT_SURVIVAL_RISK: String = "survival_risk"
const WEIGHT_POSITIONAL_ADVANTAGE: String = "positional_advantage"
const WEIGHT_BUMP_OPPORTUNITY: String = "bump_opportunity"

const DEFAULT_GHOST_TEAM: Array[String] = [
	"res://src/resources/puffs/base/cloud_tank.tres",
	"res://src/resources/puffs/base/flame_melee.tres",
	"res://src/resources/puffs/base/droplet_ranged.tres",
	"res://src/resources/puffs/base/leaf_healer.tres"
]

const DEFAULT_GHOST_AI_WEIGHTS: Dictionary = {
	WEIGHT_ATTACK_VALUE: 1.2,
	WEIGHT_SURVIVAL_RISK: 1.0,
	WEIGHT_POSITIONAL_ADVANTAGE: 0.8,
	WEIGHT_BUMP_OPPORTUNITY: 1.35
}

var _last_match_context: Dictionary = {}


func find_match_for_player(player_team_paths: Array[String], player_ai_weights: Dictionary = {}) -> Dictionary:
	var identity: Dictionary = _resolve_player_identity()
	var player_profile: Dictionary = await _load_player_profile(identity)
	var candidate_rows: Array[Dictionary] = await _request_leaderboard_candidates(float(player_profile.get("elo", DEFAULT_ELO)))
	var opponent_profile: Dictionary = _pick_best_candidate(candidate_rows, player_profile)
	var opponent_ghost: Dictionary = await _fetch_opponent_ghost(opponent_profile, player_team_paths, player_ai_weights)

	var match_context: Dictionary = {
		"ok": true,
		"player_profile": player_profile,
		"opponent_profile": opponent_profile,
		"opponent_ghost": opponent_ghost,
		"used_fallback_ghost": bool(opponent_ghost.get("is_fallback", false))
	}
	_last_match_context = match_context.duplicate(true)
	return match_context


func upload_player_ghost(
	team_paths: Array[String],
	ai_weights: Dictionary,
	battle_context: Dictionary = {}
) -> Dictionary:
	var identity: Dictionary = _resolve_player_identity()
	var player_profile: Dictionary = await _load_player_profile(identity)
	var leaderboard_id: String = str(player_profile.get("leaderboard_id", "")).strip_edges()
	var normalized_team_paths: Array[String] = _normalize_team_paths(team_paths, DEFAULT_GHOST_TEAM)
	var normalized_ai_weights: Dictionary = _normalize_ai_weights(ai_weights, DEFAULT_GHOST_AI_WEIGHTS)

	var payload: Dictionary = {
		"leaderboard_id": leaderboard_id,
		"user_id": str(identity.get("user_id", "")),
		"guest_id": str(identity.get("guest_id", "")),
		"team_paths": normalized_team_paths,
		"ai_weights": normalized_ai_weights,
		"updated_at_unix": int(Time.get_unix_time_from_system()),
		"last_battle_id": str(battle_context.get("battle_id", "")),
		"last_battle_log_path": str(battle_context.get("battle_log_path", ""))
	}

	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null or not supabase_client.has_method("request_rest"):
		return {
			"ok": false,
			"error": "SupabaseClient autoload is unavailable.",
			"ghost": payload
		}

	var query_params: Dictionary = {"on_conflict": "leaderboard_id"}
	var response: Dictionary = await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_POST,
		PVP_GHOSTS_TABLE,
		query_params,
		payload,
		["Prefer: resolution=merge-duplicates,return=representation"]
	)
	if not bool(response.get("ok", false)):
		response = await supabase_client.call(
			"request_rest",
			HTTPClient.METHOD_POST,
			PVP_GHOSTS_TABLE,
			{},
			payload,
			["Prefer: return=representation"]
		)

	await _update_leaderboard_ghost_snapshot(player_profile, normalized_team_paths, normalized_ai_weights)

	return {
		"ok": bool(response.get("ok", false)),
		"error": str(response.get("error", "")),
		"ghost": payload,
		"response": response
	}


func record_battle_result(
	match_context: Dictionary,
	player_won: bool,
	battle_context: Dictionary = {}
) -> Dictionary:
	var identity: Dictionary = _resolve_player_identity()
	var player_profile: Dictionary = {}
	var opponent_profile: Dictionary = {}

	var player_profile_variant: Variant = match_context.get("player_profile", {})
	if player_profile_variant is Dictionary:
		player_profile = player_profile_variant.duplicate(true)
	if player_profile.is_empty():
		player_profile = await _load_player_profile(identity)

	var opponent_profile_variant: Variant = match_context.get("opponent_profile", {})
	if opponent_profile_variant is Dictionary:
		opponent_profile = opponent_profile_variant.duplicate(true)
	if opponent_profile.is_empty():
		opponent_profile = {
			"leaderboard_id": "",
			"user_id": "",
			"guest_id": "",
			"elo": DEFAULT_ELO,
			"wins": 0,
			"losses": 0
		}

	var player_elo_before: float = float(player_profile.get("elo", DEFAULT_ELO))
	var opponent_elo_before: float = float(opponent_profile.get("elo", DEFAULT_ELO))
	var elo_delta: int = _calculate_elo_delta(player_elo_before, opponent_elo_before, player_won)
	var player_elo_after: float = maxf(0.0, player_elo_before + float(elo_delta))
	var opponent_elo_after: float = maxf(0.0, opponent_elo_before - float(elo_delta))

	var post_result_response: Dictionary = await _post_pvp_result(
		player_profile,
		opponent_profile,
		player_won,
		elo_delta,
		player_elo_before,
		player_elo_after,
		opponent_elo_before,
		opponent_elo_after,
		battle_context
	)

	var player_update: Dictionary = await _update_leaderboard_entry(
		player_profile,
		player_elo_after,
		1 if player_won else 0,
		0 if player_won else 1
	)
	var opponent_update: Dictionary = {}
	if _profile_has_identity(opponent_profile):
		opponent_update = await _update_leaderboard_entry(
			opponent_profile,
			opponent_elo_after,
			0 if player_won else 1,
			1 if player_won else 0
		)

	if bool(player_update.get("ok", false)):
		var updated_profile_variant: Variant = player_update.get("profile", {})
		if updated_profile_variant is Dictionary:
			_save_cached_player_profile(updated_profile_variant)
	else:
		var fallback_profile: Dictionary = player_profile.duplicate(true)
		fallback_profile["elo"] = player_elo_after
		fallback_profile["wins"] = int(player_profile.get("wins", 0)) + (1 if player_won else 0)
		fallback_profile["losses"] = int(player_profile.get("losses", 0)) + (0 if player_won else 1)
		_save_cached_player_profile(fallback_profile)

	return {
		"ok": bool(post_result_response.get("ok", false))
			and bool(player_update.get("ok", false))
			and (opponent_update.is_empty() or bool(opponent_update.get("ok", false))),
		"error": str(
			post_result_response.get(
				"error",
				player_update.get("error", opponent_update.get("error", ""))
			)
		),
		"elo_delta": elo_delta,
		"player_elo_before": player_elo_before,
		"player_elo_after": player_elo_after,
		"opponent_elo_before": opponent_elo_before,
		"opponent_elo_after": opponent_elo_after,
		"result_posted": bool(post_result_response.get("ok", false)),
		"leaderboard_updated": bool(player_update.get("ok", false))
	}


func get_last_match_context() -> Dictionary:
	return _last_match_context.duplicate(true)


func _load_player_profile(identity: Dictionary) -> Dictionary:
	var cached_profile: Dictionary = _load_cached_player_profile()
	if _profile_matches_identity(cached_profile, identity):
		cached_profile = _normalize_profile_identity(cached_profile, identity)

	var remote_response: Dictionary = await _fetch_player_profile_from_leaderboards(identity)
	if bool(remote_response.get("ok", false)):
		var data_variant: Variant = remote_response.get("data", [])
		if data_variant is Array:
			var rows: Array = data_variant
			if not rows.is_empty() and rows[0] is Dictionary:
				var row: Dictionary = rows[0]
				var normalized_profile: Dictionary = _normalize_leaderboard_row(row, identity)
				_save_cached_player_profile(normalized_profile)
				return normalized_profile

	if not cached_profile.is_empty() and _profile_matches_identity(cached_profile, identity):
		return cached_profile

	var fallback_profile: Dictionary = {
		"leaderboard_id": "",
		"user_id": str(identity.get("user_id", "")),
		"guest_id": str(identity.get("guest_id", "")),
		"elo": DEFAULT_ELO,
		"wins": 0,
		"losses": 0,
		"ghost_team": [],
		"ghost_ai_weights": {}
	}
	_save_cached_player_profile(fallback_profile)
	return fallback_profile


func _fetch_player_profile_from_leaderboards(identity: Dictionary) -> Dictionary:
	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null or not supabase_client.has_method("request_rest"):
		return {
			"ok": false,
			"error": "SupabaseClient autoload is unavailable.",
			"data": []
		}

	var query_params: Dictionary = {
		"select": "id,user_id,guest_id,elo,wins,losses,ghost_team,ghost_ai_weights",
		"limit": 1
	}

	var user_id: String = str(identity.get("user_id", "")).strip_edges()
	var guest_id: String = str(identity.get("guest_id", "")).strip_edges()
	if not user_id.is_empty():
		query_params["user_id"] = "eq.%s" % user_id
	elif not guest_id.is_empty():
		query_params["guest_id"] = "eq.%s" % guest_id
	else:
		return {
			"ok": false,
			"error": "No user or guest identity available for leaderboard lookup.",
			"data": []
		}

	return await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_GET,
		LEADERBOARDS_TABLE,
		query_params
	)


func _request_leaderboard_candidates(player_elo: float) -> Array[Dictionary]:
	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null or not supabase_client.has_method("request_rest"):
		return []

	var min_elo: float = maxf(0.0, player_elo - MATCHMAKING_ELO_WINDOW)
	var max_elo: float = player_elo + MATCHMAKING_ELO_WINDOW
	var query_params: Dictionary = {
		"select": "id,user_id,guest_id,elo,wins,losses,ghost_team,ghost_ai_weights",
		"and": "(elo.gte.%0.2f,elo.lte.%0.2f)" % [min_elo, max_elo],
		"order": "elo.asc",
		"limit": MATCHMAKING_CANDIDATE_LIMIT
	}

	var response: Dictionary = await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_GET,
		LEADERBOARDS_TABLE,
		query_params
	)

	var rows: Array[Dictionary] = _extract_dictionary_rows(response)
	if not rows.is_empty():
		return rows

	var fallback_response: Dictionary = await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_GET,
		LEADERBOARDS_TABLE,
		{
			"select": "id,user_id,guest_id,elo,wins,losses,ghost_team,ghost_ai_weights",
			"order": "elo.asc",
			"limit": MATCHMAKING_CANDIDATE_LIMIT
		}
	)
	return _extract_dictionary_rows(fallback_response)


func _pick_best_candidate(candidate_rows: Array[Dictionary], player_profile: Dictionary) -> Dictionary:
	var player_elo: float = float(player_profile.get("elo", DEFAULT_ELO))
	var best_profile: Dictionary = {}
	var best_delta: float = 999999.0

	for row in candidate_rows:
		var candidate: Dictionary = _normalize_leaderboard_row(row)
		if _is_same_profile(candidate, player_profile):
			continue

		var candidate_elo: float = float(candidate.get("elo", DEFAULT_ELO))
		var elo_delta: float = absf(candidate_elo - player_elo)
		if best_profile.is_empty() or elo_delta < best_delta:
			best_profile = candidate
			best_delta = elo_delta

	if not best_profile.is_empty():
		return best_profile

	return {
		"leaderboard_id": "",
		"user_id": "",
		"guest_id": "training_bot",
		"elo": player_elo,
		"wins": 0,
		"losses": 0,
		"ghost_team": DEFAULT_GHOST_TEAM.duplicate(),
		"ghost_ai_weights": DEFAULT_GHOST_AI_WEIGHTS.duplicate(true)
	}


func _fetch_opponent_ghost(
	opponent_profile: Dictionary,
	fallback_team: Array[String],
	fallback_ai_weights: Dictionary
) -> Dictionary:
	var embedded_team_variant: Variant = opponent_profile.get("ghost_team", [])
	var has_embedded_team: bool = false
	if embedded_team_variant is Array:
		var embedded_team: Array = embedded_team_variant
		has_embedded_team = not embedded_team.is_empty()
	if has_embedded_team:
		var embedded_team_paths: Array[String] = _normalize_team_paths(embedded_team_variant, fallback_team)
		var embedded_weights: Dictionary = _normalize_ai_weights(opponent_profile.get("ghost_ai_weights", {}), fallback_ai_weights)
		return {
			"ghost_id": str(opponent_profile.get("leaderboard_id", "")),
			"team_paths": embedded_team_paths,
			"ai_weights": embedded_weights,
			"source": "leaderboards",
			"is_fallback": false
		}

	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null or not supabase_client.has_method("request_rest"):
		return _build_fallback_ghost(fallback_team, fallback_ai_weights)

	var leaderboard_id: String = str(opponent_profile.get("leaderboard_id", "")).strip_edges()
	if leaderboard_id.is_empty():
		return _build_fallback_ghost(fallback_team, fallback_ai_weights)

	var response: Dictionary = await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_GET,
		PVP_GHOSTS_TABLE,
		{
			"select": "id,leaderboard_id,user_id,guest_id,team_paths,ai_weights,updated_at_unix",
			"leaderboard_id": "eq.%s" % leaderboard_id,
			"order": "updated_at_unix.desc",
			"limit": 1
		}
	)
	if not bool(response.get("ok", false)):
		return _build_fallback_ghost(fallback_team, fallback_ai_weights)

	var data_variant: Variant = response.get("data", [])
	if not (data_variant is Array):
		return _build_fallback_ghost(fallback_team, fallback_ai_weights)

	var rows: Array = data_variant
	if rows.is_empty() or not (rows[0] is Dictionary):
		return _build_fallback_ghost(fallback_team, fallback_ai_weights)

	var row: Dictionary = rows[0]
	return {
		"ghost_id": str(row.get("id", "")),
		"team_paths": _normalize_team_paths(row.get("team_paths", []), fallback_team),
		"ai_weights": _normalize_ai_weights(row.get("ai_weights", {}), fallback_ai_weights),
		"source": "pvp_ghosts",
		"is_fallback": false
	}


func _build_fallback_ghost(team_paths: Array[String], ai_weights: Dictionary) -> Dictionary:
	var reversed_team: Array[String] = []
	for index in range(team_paths.size() - 1, -1, -1):
		reversed_team.append(team_paths[index])
	var normalized_team: Array[String] = _normalize_team_paths(reversed_team, DEFAULT_GHOST_TEAM)
	var normalized_ai_weights: Dictionary = _normalize_ai_weights(ai_weights, DEFAULT_GHOST_AI_WEIGHTS)

	return {
		"ghost_id": "local_fallback",
		"team_paths": normalized_team,
		"ai_weights": normalized_ai_weights,
		"source": "local_fallback",
		"is_fallback": true
	}


func _post_pvp_result(
	player_profile: Dictionary,
	opponent_profile: Dictionary,
	player_won: bool,
	elo_delta: int,
	player_elo_before: float,
	player_elo_after: float,
	opponent_elo_before: float,
	opponent_elo_after: float,
	battle_context: Dictionary
) -> Dictionary:
	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null or not supabase_client.has_method("request_rest"):
		return {
			"ok": false,
			"error": "SupabaseClient autoload is unavailable."
		}

	var payload: Dictionary = {
		"battle_id": str(battle_context.get("battle_id", "")),
		"battle_log_path": str(battle_context.get("battle_log_path", "")),
		"winner": "player" if player_won else "opponent",
		"player_won": player_won,
		"player_leaderboard_id": str(player_profile.get("leaderboard_id", "")),
		"opponent_leaderboard_id": str(opponent_profile.get("leaderboard_id", "")),
		"player_elo_before": player_elo_before,
		"player_elo_after": player_elo_after,
		"opponent_elo_before": opponent_elo_before,
		"opponent_elo_after": opponent_elo_after,
		"elo_delta": elo_delta,
		"completed_at_unix": int(Time.get_unix_time_from_system())
	}

	return await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_POST,
		PVP_RESULTS_TABLE,
		{},
		payload,
		["Prefer: return=minimal"]
	)


func _update_leaderboard_entry(profile: Dictionary, elo_after: float, wins_delta: int, losses_delta: int) -> Dictionary:
	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null or not supabase_client.has_method("request_rest"):
		return {
			"ok": false,
			"error": "SupabaseClient autoload is unavailable.",
			"profile": profile
		}

	var next_wins: int = int(profile.get("wins", 0)) + wins_delta
	var next_losses: int = int(profile.get("losses", 0)) + losses_delta
	var payload: Dictionary = {
		"elo": elo_after,
		"wins": maxi(0, next_wins),
		"losses": maxi(0, next_losses),
		"updated_at_unix": int(Time.get_unix_time_from_system())
	}

	var leaderboard_id: String = str(profile.get("leaderboard_id", "")).strip_edges()
	var response: Dictionary = {}

	if not leaderboard_id.is_empty():
		response = await supabase_client.call(
			"request_rest",
			HTTPClient.METHOD_PATCH,
			LEADERBOARDS_TABLE,
			{"id": "eq.%s" % leaderboard_id},
			payload,
			["Prefer: return=representation"]
		)
	else:
		payload["user_id"] = str(profile.get("user_id", ""))
		payload["guest_id"] = str(profile.get("guest_id", ""))
		response = await supabase_client.call(
			"request_rest",
			HTTPClient.METHOD_POST,
			LEADERBOARDS_TABLE,
			{},
			payload,
			["Prefer: return=representation"]
		)

	if not bool(response.get("ok", false)):
		return {
			"ok": false,
			"error": str(response.get("error", "Failed to update leaderboard entry.")),
			"profile": profile
		}

	var data_variant: Variant = response.get("data", [])
	if data_variant is Array:
		var rows: Array = data_variant
		if not rows.is_empty() and rows[0] is Dictionary:
			var updated_row: Dictionary = rows[0]
			var normalized_profile: Dictionary = _normalize_leaderboard_row(updated_row, profile)
			return {
				"ok": true,
				"error": "",
				"profile": normalized_profile
			}

	var fallback_profile: Dictionary = profile.duplicate(true)
	fallback_profile["elo"] = elo_after
	fallback_profile["wins"] = maxi(0, next_wins)
	fallback_profile["losses"] = maxi(0, next_losses)
	return {
		"ok": true,
		"error": "",
		"profile": fallback_profile
	}


func _update_leaderboard_ghost_snapshot(profile: Dictionary, team_paths: Array[String], ai_weights: Dictionary) -> void:
	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null or not supabase_client.has_method("request_rest"):
		return

	var leaderboard_id: String = str(profile.get("leaderboard_id", "")).strip_edges()
	if leaderboard_id.is_empty():
		return

	await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_PATCH,
		LEADERBOARDS_TABLE,
		{"id": "eq.%s" % leaderboard_id},
		{
			"ghost_team": team_paths,
			"ghost_ai_weights": ai_weights,
			"updated_at_unix": int(Time.get_unix_time_from_system())
		},
		["Prefer: return=minimal"]
	)


func _resolve_supabase_client() -> Node:
	return get_node_or_null("/root/SupabaseClient")


func _resolve_player_identity() -> Dictionary:
	var user_id: String = ""
	var guest_id: String = ""
	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client != null:
		if supabase_client.has_method("get_authenticated_user_id"):
			user_id = str(supabase_client.call("get_authenticated_user_id")).strip_edges()
		if supabase_client.has_method("get_guest_id"):
			guest_id = str(supabase_client.call("get_guest_id")).strip_edges()

	return {
		"user_id": user_id,
		"guest_id": guest_id
	}


func _calculate_elo_delta(player_elo: float, opponent_elo: float, player_won: bool) -> int:
	var expected_score: float = _compute_expected_score(player_elo, opponent_elo)
	var actual_score: float = 1.0 if player_won else 0.0
	return int(round(ELO_K_FACTOR * (actual_score - expected_score)))


func _compute_expected_score(rating_a: float, rating_b: float) -> float:
	var exponent: float = (rating_b - rating_a) / 400.0
	return 1.0 / (1.0 + pow(10.0, exponent))


func _normalize_leaderboard_row(row: Dictionary, fallback_identity: Dictionary = {}) -> Dictionary:
	return {
		"leaderboard_id": str(row.get("id", row.get("leaderboard_id", ""))).strip_edges(),
		"user_id": str(row.get("user_id", fallback_identity.get("user_id", ""))).strip_edges(),
		"guest_id": str(row.get("guest_id", fallback_identity.get("guest_id", ""))).strip_edges(),
		"elo": float(row.get("elo", DEFAULT_ELO)),
		"wins": int(row.get("wins", 0)),
		"losses": int(row.get("losses", 0)),
		"ghost_team": row.get("ghost_team", []),
		"ghost_ai_weights": row.get("ghost_ai_weights", {})
	}


func _normalize_team_paths(raw_team_variant: Variant, fallback_team: Array[String]) -> Array[String]:
	var normalized: Array[String] = []
	if raw_team_variant is Array:
		var raw_team: Array = raw_team_variant
		for team_path_variant in raw_team:
			var team_path: String = str(team_path_variant).strip_edges()
			if team_path.is_empty():
				continue
			normalized.append(team_path)

	if normalized.is_empty():
		for fallback_path in fallback_team:
			var trimmed_path: String = str(fallback_path).strip_edges()
			if trimmed_path.is_empty():
				continue
			normalized.append(trimmed_path)

	if normalized.is_empty():
		normalized = DEFAULT_GHOST_TEAM.duplicate()

	var fill_source: Array[String] = normalized.duplicate()
	if fill_source.is_empty():
		fill_source = DEFAULT_GHOST_TEAM.duplicate()

	var fill_index: int = 0
	while normalized.size() < TEAM_SIZE:
		normalized.append(fill_source[fill_index % fill_source.size()])
		fill_index += 1

	while normalized.size() > TEAM_SIZE:
		normalized.remove_at(normalized.size() - 1)

	return normalized


func _normalize_ai_weights(raw_weights_variant: Variant, fallback_weights: Dictionary) -> Dictionary:
	var fallback: Dictionary = fallback_weights.duplicate(true)
	if fallback.is_empty():
		fallback = DEFAULT_GHOST_AI_WEIGHTS.duplicate(true)

	var normalized: Dictionary = {
		WEIGHT_ATTACK_VALUE: maxf(0.0, float(fallback.get(WEIGHT_ATTACK_VALUE, DEFAULT_GHOST_AI_WEIGHTS[WEIGHT_ATTACK_VALUE]))),
		WEIGHT_SURVIVAL_RISK: maxf(0.0, float(fallback.get(WEIGHT_SURVIVAL_RISK, DEFAULT_GHOST_AI_WEIGHTS[WEIGHT_SURVIVAL_RISK]))),
		WEIGHT_POSITIONAL_ADVANTAGE: maxf(0.0, float(fallback.get(WEIGHT_POSITIONAL_ADVANTAGE, DEFAULT_GHOST_AI_WEIGHTS[WEIGHT_POSITIONAL_ADVANTAGE]))),
		WEIGHT_BUMP_OPPORTUNITY: maxf(0.0, float(fallback.get(WEIGHT_BUMP_OPPORTUNITY, DEFAULT_GHOST_AI_WEIGHTS[WEIGHT_BUMP_OPPORTUNITY])))
	}

	if not (raw_weights_variant is Dictionary):
		return normalized

	var raw_weights: Dictionary = raw_weights_variant
	for key in [
		WEIGHT_ATTACK_VALUE,
		WEIGHT_SURVIVAL_RISK,
		WEIGHT_POSITIONAL_ADVANTAGE,
		WEIGHT_BUMP_OPPORTUNITY
	]:
		if not raw_weights.has(key):
			continue
		normalized[key] = maxf(0.0, float(raw_weights.get(key, normalized[key])))

	return normalized


func _extract_dictionary_rows(response: Dictionary) -> Array[Dictionary]:
	if not bool(response.get("ok", false)):
		return []

	var rows_variant: Variant = response.get("data", [])
	if not (rows_variant is Array):
		return []

	var rows: Array = rows_variant
	var normalized_rows: Array[Dictionary] = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		normalized_rows.append(row_variant)

	return normalized_rows


func _is_same_profile(candidate: Dictionary, current_profile: Dictionary) -> bool:
	var candidate_id: String = str(candidate.get("leaderboard_id", "")).strip_edges()
	var current_id: String = str(current_profile.get("leaderboard_id", "")).strip_edges()
	if not candidate_id.is_empty() and candidate_id == current_id:
		return true

	var candidate_user_id: String = str(candidate.get("user_id", "")).strip_edges()
	var current_user_id: String = str(current_profile.get("user_id", "")).strip_edges()
	if not candidate_user_id.is_empty() and candidate_user_id == current_user_id:
		return true

	var candidate_guest_id: String = str(candidate.get("guest_id", "")).strip_edges()
	var current_guest_id: String = str(current_profile.get("guest_id", "")).strip_edges()
	if not candidate_guest_id.is_empty() and candidate_guest_id == current_guest_id:
		return true

	return false


func _profile_matches_identity(profile: Dictionary, identity: Dictionary) -> bool:
	if profile.is_empty():
		return false

	var profile_user_id: String = str(profile.get("user_id", "")).strip_edges()
	var identity_user_id: String = str(identity.get("user_id", "")).strip_edges()
	if not identity_user_id.is_empty() and profile_user_id == identity_user_id:
		return true

	var profile_guest_id: String = str(profile.get("guest_id", "")).strip_edges()
	var identity_guest_id: String = str(identity.get("guest_id", "")).strip_edges()
	if not identity_guest_id.is_empty() and profile_guest_id == identity_guest_id:
		return true

	return identity_user_id.is_empty() and identity_guest_id.is_empty()


func _profile_has_identity(profile: Dictionary) -> bool:
	if not str(profile.get("leaderboard_id", "")).strip_edges().is_empty():
		return true
	if not str(profile.get("user_id", "")).strip_edges().is_empty():
		return true
	if not str(profile.get("guest_id", "")).strip_edges().is_empty():
		return true
	return false


func _normalize_profile_identity(profile: Dictionary, identity: Dictionary) -> Dictionary:
	var normalized: Dictionary = profile.duplicate(true)
	if normalized.is_empty():
		return normalized

	if str(normalized.get("user_id", "")).strip_edges().is_empty():
		normalized["user_id"] = str(identity.get("user_id", "")).strip_edges()
	if str(normalized.get("guest_id", "")).strip_edges().is_empty():
		normalized["guest_id"] = str(identity.get("guest_id", "")).strip_edges()
	return normalized


func _load_cached_player_profile() -> Dictionary:
	var payload_variant: Variant = _read_json_file(PLAYER_PROFILE_CACHE_PATH)
	if not (payload_variant is Dictionary):
		return {}
	return payload_variant.duplicate(true)


func _save_cached_player_profile(profile: Dictionary) -> void:
	if profile.is_empty():
		return
	_ensure_cache_directory()
	_write_json_file(PLAYER_PROFILE_CACHE_PATH, _to_json_safe(profile))


func _ensure_cache_directory() -> void:
	var dir_error: int = DirAccess.make_dir_recursive_absolute(CACHE_DIRECTORY_PATH)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_warning("Unable to create PvP cache directory: %s" % CACHE_DIRECTORY_PATH)


func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var raw_text: String = file.get_as_text()
	file.close()
	if raw_text.is_empty():
		return null

	var parser: JSON = JSON.new()
	var parse_error: int = parser.parse(raw_text)
	if parse_error != OK:
		push_warning("Failed to parse JSON file: %s" % path)
		return null

	return parser.data


func _write_json_file(path: String, payload: Variant) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to write JSON file: %s" % path)
		return

	file.store_string(JSON.stringify(payload))
	file.close()


func _to_json_safe(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is Vector2i:
		var cell: Vector2i = value
		return {"x": cell.x, "y": cell.y}
	if value is Vector2:
		var point: Vector2 = value
		return {"x": point.x, "y": point.y}
	if value is Array:
		var array_value: Array = value
		var normalized_array: Array = []
		for item in array_value:
			normalized_array.append(_to_json_safe(item))
		return normalized_array
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var normalized_dictionary: Dictionary = {}
		for key_variant in dictionary_value.keys():
			var key: String = str(_to_json_safe(key_variant))
			normalized_dictionary[key] = _to_json_safe(dictionary_value[key_variant])
		return normalized_dictionary
	return value
