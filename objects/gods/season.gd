extends Node

var season_on: bool = false
var season_data: Dictionary = {}
var save_path = "user://season.json"

const ROUND_NAMES: Array[String] = [
	"Division Semifinals",
	"Division Finals",
	"Conference Finals",
	"Open Practice Cup Final"
]

func has_saved_season() -> bool:
	return FileAccess.file_exists(save_path)

func load_season() -> void:
	if has_saved_season():
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file == null:
			return
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK and json.data is Dictionary:
			season_data = json.data
			_ensure_season_schema()

func _ensure_season_schema() -> void:
	if season_data.is_empty():
		return
	var dirty: bool = false
	if not season_data.has("phase"):
		season_data["phase"] = "regular"
		dirty = true
	if not season_data.has("series_length"):
		season_data["series_length"] = 3
		dirty = true
	if not season_data.has("period_length"):
		season_data["period_length"] = Globals.period_length
		dirty = true
	if not season_data.has("skater_stats") or not (season_data["skater_stats"] is Dictionary):
		season_data["skater_stats"] = {}
		dirty = true
	if not season_data.has("playoffs") or not (season_data["playoffs"] is Dictionary):
		season_data["playoffs"] = {}
		dirty = true
	if season_data.has("standings") and season_data["standings"] is Dictionary:
		for key in season_data["standings"]:
			var rec: Dictionary = season_data["standings"][key]
			if not rec.has("otl"):
				rec["otl"] = 0
				dirty = true
			if not rec.has("ties"):
				rec["ties"] = 0
				dirty = true
			if not rec.has("gf"):
				rec["gf"] = 0
				dirty = true
			if not rec.has("ga"):
				rec["ga"] = 0
				dirty = true
	var cur_week: int = int(season_data.get("current_week", 0))
	var sched: Array = season_data.get("schedule", [])
	if season_data["phase"] == "regular" and not sched.is_empty() and cur_week >= sched.size():
		start_playoffs()
		dirty = true
	if dirty:
		save_season()

func save_season() -> void:
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(season_data))

func new_season(player_team: int, series_length: int = 3, period_length: float = 120.0) -> void:
	var a = []
	var b = []
	var c = []
	var d = []

	for i in range(0, 32):
		var co = Stats.TEAMS[i]["division"]
		if co == "city":
			a.push_back(i)
		elif co == "coastal":
			b.push_back(i)
		elif co == "middle":
			c.push_back(i)
		elif co == "ocean":
			d.push_back(i)

	var good_teams = []
	good_teams.append(a[randi() % 8])
	good_teams.append(b[randi() % 8])
	good_teams.append(c[randi() % 8])
	good_teams.append(d[randi() % 8])

	var standings = {}
	for t in (a + b + c + d):
		standings[str(t)] = {"wins": 0, "losses": 0, "otl": 0, "ties": 0, "gf": 0, "ga": 0}

	var schedule = generate_schedule(a, b, c, d)

	season_data = {
		"player_team": player_team,
		"current_week": 0,
		"good_teams": good_teams,
		"standings": standings,
		"schedule": schedule,
		"phase": "regular",
		"series_length": series_length,
		"period_length": period_length,
		"skater_stats": {},
		"playoffs": {}
	}
	save_season()

func is_playoff_match() -> bool:
	return season_on and str(season_data.get("phase", "regular")) == "playoffs"

func get_series_wins_needed() -> int:
	var length: int = int(season_data.get("series_length", 3))
	return int(length / 2) + 1

func generate_schedule(a: Array, b: Array, c: Array, d: Array) -> Array:
	var sky = a + b
	var earth = c + d
	var schedule = []
	for w in range(16):
		var week = []
		for i in range(16):
			var t1 = sky[i]
			var t2 = earth[(i + w) % 16]
			if w < 8:
				week.append([t1, t2])
			else:
				week.append([t2, t1])
		schedule.append(week)
	for w in range(8):
		var week = []
		for i in range(8):
			var t1 = a[i]
			var t2 = b[(i + w) % 8]
			if w < 4:
				week.append([t1, t2])
			else:
				week.append([t2, t1])
			t1 = c[i]
			t2 = d[(i + w) % 8]
			if w < 4:
				week.append([t1, t2])
			else:
				week.append([t2, t1])
		schedule.append(week)
	var matchups = [
		[[0, 7], [1, 6], [2, 5], [3, 4]],
		[[0, 6], [7, 5], [1, 4], [2, 3]],
		[[0, 5], [6, 4], [7, 3], [1, 2]],
		[[0, 4], [5, 3], [6, 2], [7, 1]],
		[[0, 3], [4, 2], [5, 1], [6, 7]],
		[[0, 2], [3, 1], [4, 7], [5, 6]],
		[[0, 1], [2, 7], [3, 6], [4, 5]]
	]
	for _iter in range(2):
		for r in range(7):
			var week = []
			for div in [a, b, c, d]:
				for pair in matchups[r]:
					var t1 = div[pair[0]]
					var t2 = div[pair[1]]
					if _iter % 2 == 0:
						week.append([t1, t2])
					else:
						week.append([t2, t1])
			schedule.append(week)
	schedule.shuffle()
	return schedule

func get_team_points(team_id: int) -> int:
	var standings: Dictionary = season_data.get("standings", {})
	var rec: Dictionary = standings.get(str(team_id), {})
	var w: int = int(rec.get("wins", 0))
	var otl: int = int(rec.get("otl", 0))
	var ties: int = int(rec.get("ties", 0))
	return w * 2 + otl + ties

func get_sorted_standings() -> Array:
	var teams_records: Array = []
	var standings: Dictionary = season_data.get("standings", {})
	for team_id_str in standings:
		var rec: Dictionary = standings[team_id_str]
		var w: int = int(rec.get("wins", 0))
		var l: int = int(rec.get("losses", 0))
		var otl: int = int(rec.get("otl", 0))
		var ties: int = int(rec.get("ties", 0))
		var gf: int = int(rec.get("gf", 0))
		var ga: int = int(rec.get("ga", 0))
		teams_records.append({
			"id": int(team_id_str),
			"wins": w,
			"losses": l,
			"otl": otl,
			"ties": ties,
			"gf": gf,
			"ga": ga,
			"gd": gf - ga,
			"pts": w * 2 + otl + ties
		})
	teams_records.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		if a["wins"] != b["wins"]:
			return a["wins"] > b["wins"]
		if a["gd"] != b["gd"]:
			return a["gd"] > b["gd"]
		return a["id"] < b["id"]
	)
	return teams_records

func record_match(home: int, away: int, home_score: int, away_score: int, ended_in: String = "") -> void:
	var standings: Dictionary = season_data["standings"]
	var hrec: Dictionary = standings[str(home)]
	var arec: Dictionary = standings[str(away)]
	hrec["gf"] = int(hrec.get("gf", 0)) + home_score
	hrec["ga"] = int(hrec.get("ga", 0)) + away_score
	arec["gf"] = int(arec.get("gf", 0)) + away_score
	arec["ga"] = int(arec.get("ga", 0)) + home_score

	var is_extra_time: bool = (ended_in == "OT" or ended_in == "SO")
	if home_score > away_score:
		hrec["wins"] = int(hrec.get("wins", 0)) + 1
		if is_extra_time:
			arec["otl"] = int(arec.get("otl", 0)) + 1
		else:
			arec["losses"] = int(arec.get("losses", 0)) + 1
	elif home_score == away_score:
		hrec["ties"] = int(hrec.get("ties", 0)) + 1
		arec["ties"] = int(arec.get("ties", 0)) + 1
	else:
		arec["wins"] = int(arec.get("wins", 0)) + 1
		if is_extra_time:
			hrec["otl"] = int(hrec.get("otl", 0)) + 1
		else:
			hrec["losses"] = int(hrec.get("losses", 0)) + 1

func merge_match_skater_stats(match_stats: Dictionary) -> void:
	if not season_data.has("skater_stats") or not (season_data["skater_stats"] is Dictionary):
		season_data["skater_stats"] = {}
	var store: Dictionary = season_data["skater_stats"]
	for key in match_stats:
		var m: Dictionary = match_stats[key]
		if not store.has(key):
			store[key] = {
				"team_index": int(m.get("team_index", -1)),
				"number": int(m.get("number", 0)),
				"name": str(m.get("name", "")),
				"goals": 0,
				"assists": 0,
				"shots": 0,
				"hits": 0,
				"downs": 0,
				"penalties": 0,
				"fights_won": 0
			}
		var dest: Dictionary = store[key]
		if str(m.get("name", "")) != "":
			dest["name"] = str(m["name"])
		for stat_key in ["goals", "assists", "shots", "hits", "downs", "penalties", "fights_won"]:
			dest[stat_key] = int(dest.get(stat_key, 0)) + int(m.get(stat_key, 0))

func _add_sim_skater_stat(team_id: int, profile: Dictionary, stat_key: String, amount: int = 1) -> void:
	if profile.is_empty():
		return
	var num: int = int(profile.get("number", 0))
	if num <= 0:
		return
	var pname: String = str(profile.get("name", "Skater #%d" % num))
	var key: String = Globals.get_skater_stat_key(team_id, num)
	if not season_data.has("skater_stats") or not (season_data["skater_stats"] is Dictionary):
		season_data["skater_stats"] = {}
	var store: Dictionary = season_data["skater_stats"]
	if not store.has(key):
		store[key] = {
			"team_index": team_id,
			"number": num,
			"name": pname,
			"goals": 0,
			"assists": 0,
			"shots": 0,
			"hits": 0,
			"downs": 0,
			"penalties": 0,
			"fights_won": 0
		}
	store[key][stat_key] = int(store[key].get(stat_key, 0)) + amount

func _attribute_sim_team_stats(team_id: int, goals: int) -> void:
	var roster: Dictionary = Globals.get_team_roster(team_id)
	var skater_slots: Array = roster.get("skaters", [])
	if skater_slots.is_empty():
		return
	var pool: Array = []
	for slot in skater_slots:
		if slot is Array and slot.size() > 0 and slot[0] is Dictionary:
			pool.append(slot[0])
	if pool.is_empty():
		return
	for _g in range(goals):
		var scorer_idx: int = randi() % pool.size()
		_add_sim_skater_stat(team_id, pool[scorer_idx], "goals", 1)
		_add_sim_skater_stat(team_id, pool[scorer_idx], "shots", 1)
		if pool.size() > 1 and randf() < 0.75:
			var assist_idx: int = (scorer_idx + 1 + (randi() % (pool.size() - 1))) % pool.size()
			_add_sim_skater_stat(team_id, pool[assist_idx], "assists", 1)
	var extra_hits: int = randi_range(2, 6)
	for _h in range(extra_hits):
		var hitter: Dictionary = pool[randi() % pool.size()]
		_add_sim_skater_stat(team_id, hitter, "hits", 1)
		if randf() < 0.25:
			_add_sim_skater_stat(team_id, hitter, "downs", 1)
	if randf() < 0.35:
		_add_sim_skater_stat(team_id, pool[randi() % pool.size()], "penalties", 1)
	if randf() < 0.12:
		_add_sim_skater_stat(team_id, pool[randi() % pool.size()], "fights_won", 1)

func _simulate_game_result(home: int, away: int, is_playoff: bool = false) -> Dictionary:
	var good_teams: Array = season_data.get("good_teams", [])
	var home_win_prob: float = 0.52 # slight home-ice edge
	if home in good_teams and not (away in good_teams):
		home_win_prob = 0.72
	elif away in good_teams and not (home in good_teams):
		home_win_prob = 0.28

	var base_goals: int = randi_range(1, 4)
	var home_score: int = 0
	var away_score: int = 0
	for _i in range(base_goals):
		if randf() < home_win_prob:
			home_score += 1
		else:
			away_score += 1

	var ended_in: String = ""
	if home_score == away_score:
		if randf() < home_win_prob:
			home_score += 1
		else:
			away_score += 1
		ended_in = "OT" if (is_playoff or randf() < 0.6) else "SO"

	_attribute_sim_team_stats(home, home_score)
	_attribute_sim_team_stats(away, away_score)
	return {"home_score": home_score, "away_score": away_score, "ended_in": ended_in}

func simulate_other_matches() -> void:
	var week = int(season_data["current_week"])
	if week >= season_data["schedule"].size():
		return

	var matches = season_data["schedule"][week]
	var player_team = int(season_data["player_team"])

	for m in matches:
		var home = int(m[0])
		var away = int(m[1])
		if home == player_team or away == player_team:
			continue
		var res: Dictionary = _simulate_game_result(home, away, false)
		record_match(home, away, res["home_score"], res["away_score"], res["ended_in"])

func advance_week() -> void:
	season_data["current_week"] = int(season_data["current_week"]) + 1
	if int(season_data["current_week"]) >= season_data["schedule"].size():
		start_playoffs()
	else:
		save_season()

func start_playoffs() -> void:
	if str(season_data.get("phase", "regular")) == "playoffs" or str(season_data.get("phase", "regular")) == "champion":
		return
	var sorted: Array = get_sorted_standings()
	var divisions: Dictionary = {"city": [], "coastal": [], "middle": [], "ocean": []}
	for tr in sorted:
		var tid: int = int(tr["id"])
		var div_name: String = str(StatBook.TEAMS[tid].get("division", ""))
		if divisions.has(div_name):
			divisions[div_name].append(tid)

	var round0: Array = []
	var div_order: Array[String] = ["city", "coastal", "middle", "ocean"]
	for div_name in div_order:
		var seeds: Array = divisions[div_name]
		if seeds.size() >= 4:
			round0.append({
				"high": seeds[0],
				"low": seeds[3],
				"high_wins": 0,
				"low_wins": 0,
				"winner": -1,
				"label": div_name.capitalize() + " Semi 1"
			})
			round0.append({
				"high": seeds[1],
				"low": seeds[2],
				"high_wins": 0,
				"low_wins": 0,
				"winner": -1,
				"label": div_name.capitalize() + " Semi 2"
			})

	season_data["phase"] = "playoffs"
	season_data["playoffs"] = {
		"round": 0,
		"rounds": [round0],
		"champion": -1
	}
	if get_player_active_series().is_empty():
		simulate_remaining_playoffs()
	else:
		save_season()

func get_series_home_away(series: Dictionary) -> Array[int]:
	var games_played: int = int(series["high_wins"]) + int(series["low_wins"])
	# Home-ice pattern: H, H, A, A, H, A, H
	var high_is_home: bool = games_played in [0, 1, 4, 6]
	if high_is_home:
		return [int(series["high"]), int(series["low"])]
	return [int(series["low"]), int(series["high"])]

func get_player_active_series() -> Dictionary:
	if str(season_data.get("phase", "regular")) != "playoffs":
		return {}
	var playoffs: Dictionary = season_data.get("playoffs", {})
	var rounds: Array = playoffs.get("rounds", [])
	var r: int = int(playoffs.get("round", 0))
	if r < 0 or r >= rounds.size():
		return {}
	var player_team: int = int(season_data.get("player_team", -1))
	var cur_round: Array = rounds[r]
	for idx in range(cur_round.size()):
		var s: Dictionary = cur_round[idx]
		if int(s.get("winner", -1)) == -1 and (int(s["high"]) == player_team or int(s["low"]) == player_team):
			var ha: Array[int] = get_series_home_away(s)
			return {
				"round": r,
				"index": idx,
				"series": s,
				"home": ha[0],
				"away": ha[1],
				"game_number": int(s["high_wins"]) + int(s["low_wins"]) + 1
			}
	return {}

func _apply_series_game_winner(series: Dictionary, winner_team: int) -> void:
	var wins_needed: int = get_series_wins_needed()
	if winner_team == int(series["high"]):
		series["high_wins"] = int(series["high_wins"]) + 1
		if int(series["high_wins"]) >= wins_needed:
			series["winner"] = int(series["high"])
	elif winner_team == int(series["low"]):
		series["low_wins"] = int(series["low_wins"]) + 1
		if int(series["low_wins"]) >= wins_needed:
			series["winner"] = int(series["low"])

func _simulate_one_game_in_series(series: Dictionary) -> void:
	if int(series.get("winner", -1)) != -1:
		return
	var ha: Array[int] = get_series_home_away(series)
	var res: Dictionary = _simulate_game_result(ha[0], ha[1], true)
	var winner: int = ha[0] if int(res["home_score"]) >= int(res["away_score"]) else ha[1]
	_apply_series_game_winner(series, winner)

func _try_advance_playoff_round() -> void:
	var playoffs: Dictionary = season_data.get("playoffs", {})
	var rounds: Array = playoffs.get("rounds", [])
	var r: int = int(playoffs.get("round", 0))
	if r < 0 or r >= rounds.size():
		return
	var cur_round: Array = rounds[r]
	for s in cur_round:
		if int(s.get("winner", -1)) == -1:
			return

	if cur_round.size() == 1:
		playoffs["champion"] = int(cur_round[0]["winner"])
		season_data["phase"] = "champion"
		save_season()
		return

	var next_round: Array = []
	var labels_r1: Array[String] = ["City Final", "Coastal Final", "Middle Final", "Ocean Final"]
	var labels_r2: Array[String] = ["Eastern Conf Final", "Western Conf Final"]
	var next_r: int = r + 1
	var standings_rank: Dictionary = {}
	var sorted: Array = get_sorted_standings()
	for i in range(sorted.size()):
		standings_rank[int(sorted[i]["id"])] = i

	for i in range(0, cur_round.size(), 2):
		var w1: int = int(cur_round[i]["winner"])
		var w2: int = int(cur_round[i + 1]["winner"])
		var high_team: int = w1 if int(standings_rank.get(w1, 99)) <= int(standings_rank.get(w2, 99)) else w2
		var low_team: int = w2 if high_team == w1 else w1
		var label: String = "Final"
		if next_r == 1 and int(i / 2) < labels_r1.size():
			label = labels_r1[int(i / 2)]
		elif next_r == 2 and int(i / 2) < labels_r2.size():
			label = labels_r2[int(i / 2)]
		elif next_r == 3:
			label = "Open Practice Cup Final"
		next_round.append({
			"high": high_team,
			"low": low_team,
			"high_wins": 0,
			"low_wins": 0,
			"winner": -1,
			"label": label
		})

	rounds.append(next_round)
	playoffs["round"] = next_r
	save_season()

func record_playoff_game(home: int, away: int, home_score: int, away_score: int) -> void:
	var active: Dictionary = get_player_active_series()
	if active.is_empty():
		return
	var playoffs: Dictionary = season_data["playoffs"]
	var r: int = int(active["round"])
	var idx: int = int(active["index"])
	var cur_round: Array = playoffs["rounds"][r]
	var player_series: Dictionary = cur_round[idx]

	var winner: int = home if home_score >= away_score else away
	_apply_series_game_winner(player_series, winner)

	# Simulate one game in each other active series in the round
	for i in range(cur_round.size()):
		if i == idx:
			continue
		_simulate_one_game_in_series(cur_round[i])

	# If player's series just wrapped up, finish remaining series in this round so the bracket advances
	if int(player_series.get("winner", -1)) != -1:
		for i in range(cur_round.size()):
			while int(cur_round[i].get("winner", -1)) == -1:
				_simulate_one_game_in_series(cur_round[i])

	_try_advance_playoff_round()
	if str(season_data.get("phase", "regular")) == "playoffs" and get_player_active_series().is_empty():
		simulate_remaining_playoffs()
	else:
		save_season()

func simulate_remaining_playoffs() -> void:
	var guard: int = 0
	while str(season_data.get("phase", "regular")) == "playoffs" and guard < 8:
		guard += 1
		var playoffs: Dictionary = season_data.get("playoffs", {})
		var rounds: Array = playoffs.get("rounds", [])
		var r: int = int(playoffs.get("round", 0))
		if r < 0 or r >= rounds.size():
			break
		for s in rounds[r]:
			while int(s.get("winner", -1)) == -1:
				_simulate_one_game_in_series(s)
		_try_advance_playoff_round()
	save_season()

func _lookup_current_roster_name(team_id: int, number: int, fallback: String) -> String:
	var roster: Dictionary = Globals.get_team_roster(team_id)
	if roster.is_empty():
		return fallback
	var g = roster.get("goalie", {})
	if g is Dictionary and int(g.get("number", -1)) == number:
		return str(g.get("name", fallback))
	for slot in roster.get("skaters", []):
		if slot is Array:
			for profile in slot:
				if profile is Dictionary and int(profile.get("number", -1)) == number:
					return str(profile.get("name", fallback))
	return fallback

func get_league_leaders(sort_by: String = "points", limit: int = 20) -> Array:
	var store: Dictionary = season_data.get("skater_stats", {})
	var out: Array = []
	for key in store:
		var entry: Dictionary = store[key]
		var tid: int = int(entry.get("team_index", -1))
		var num: int = int(entry.get("number", 0))
		var g: int = int(entry.get("goals", 0))
		var a: int = int(entry.get("assists", 0))
		var pts: int = g + a
		var name_str: String = _lookup_current_roster_name(tid, num, str(entry.get("name", "Skater #%d" % num)))
		out.append({
			"team_index": tid,
			"number": num,
			"name": name_str,
			"goals": g,
			"assists": a,
			"points": pts,
			"shots": int(entry.get("shots", 0)),
			"hits": int(entry.get("hits", 0)),
			"downs": int(entry.get("downs", 0)),
			"penalties": int(entry.get("penalties", 0)),
			"fights_won": int(entry.get("fights_won", 0)),
		})
	out.sort_custom(func(a, b):
		var av: int = int(a.get(sort_by, 0))
		var bv: int = int(b.get(sort_by, 0))
		if av != bv:
			return av > bv
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return a["goals"] > b["goals"]
	)
	if out.size() > limit:
		return out.slice(0, limit)
	return out
