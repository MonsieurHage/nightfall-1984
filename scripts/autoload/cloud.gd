extends Node

## Client Supabase : comptes pseudo/mot de passe, sauvegarde en ligne, classement.
## La clé anon est publique ; la sécurité repose sur les règles RLS documentées
## dans docs/SUPABASE.md. Aucun secret n'est embedde ici.

signal auth_changed(signed_in: bool, pseudo: String)
signal login_succeeded(pseudo: String)
signal leaderboard_ready(rows: Array[Dictionary])
signal cloud_error(text: String)
signal sync_done()

const CONFIG_PATH := "res://data/supabase_config.json"
const RESERVED_PSEUDO := "monsieurhage"

var url: String = ""
var anon_key: String = ""
var configured: bool = false

var signed_in: bool = false
var pseudo: String = ""
var user_id: String = ""
var access_token: String = ""
var refresh_token: String = ""

var leaderboard: Array[Dictionary] = []
var last_error: String = ""

var _dirty: bool = false
var _sync_timer: float = 0.0


func _ready() -> void:
	var d: Dictionary = Game.load_json(CONFIG_PATH)
	url = String(d.get("url", "")).trim_suffix("/")
	anon_key = String(d.get("anon_key", ""))
	configured = url.begins_with("https://") and anon_key.length() > 30
	if not configured:
		push_warning("Supabase non configure : renseigner data/supabase_config.json")


func _process(delta: float) -> void:
	if not _dirty or not signed_in:
		return
	_sync_timer += delta
	if _sync_timer >= 8.0:
		_sync_timer = 0.0
		_dirty = false
		save_progress()


func queue_sync() -> void:
	if signed_in:
		_dirty = true


func _new_request() -> HTTPRequest:
	var req := HTTPRequest.new()
	req.timeout = 25.0
	add_child(req)
	return req


func _request(method: int, path: String, body: Variant = null, authenticated: bool = false, extra: Dictionary = {}) -> Dictionary:
	var headers: Array[String] = []
	headers.append("apikey: " + anon_key)
	headers.append("Content-Type: application/json")
	headers.append("Accept: application/json")
	headers.append("User-Agent: Nightfall1984/1.0")
	if authenticated and access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	for k in extra.keys():
		headers.append(String(k) + ": " + String(extra[k]))
	var payload := ""
	if body != null:
		payload = JSON.stringify(body)
	var req := _new_request()
	var err := req.request(url + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "error": "Requête impossible (codeGodot=%d)" % err}
	var result: Array = await req.request_completed
	req.queue_free()
	var code := int(result[0])
	var text := ""
	if result[3] is PackedByteArray:
		text = (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if code < 200 or code >= 300:
		var msg := text.substr(0, 240)
		if parsed is Dictionary:
			msg = String((parsed as Dictionary).get("msg", (parsed as Dictionary).get("message", msg)))
		last_error = "HTTP %d : %s" % [code, msg]
		return {"ok": false, "code": code, "error": last_error, "data": parsed}
	return {"ok": true, "code": code, "data": parsed}


static func _valid_pseudo(p: String) -> bool:
	if p.length() < 3 or p.length() > 20:
		return false
	for c in p:
		if not (c in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
			return false
	return true


func _email_for(p: String) -> String:
	return p + "@nightfall.local"


func sign_up(raw_pseudo: String, password: String) -> Dictionary:
	if not configured:
		return {"ok": false, "error": "Supabase non configure (voir docs/SUPABASE.md)"}
	var p := raw_pseudo.strip_edges().to_lower()
	if p == RESERVED_PSEUDO:
		return {"ok": false, "error": "Ce pseudo est reserve."}
	if not _valid_pseudo(p):
		return {"ok": false, "error": "Pseudo : 3 a 20 caracteres, minuscules, chiffres, - ou _."}
	if password.length() < 6:
		return {"ok": false, "error": "Mot de passe : 6 caracteres minimum."}
	var r := await _request(HTTPClient.METHOD_POST, "/auth/v1/signup", {
		"email": _email_for(p),
		"password": password,
		"data": {"pseudo": p}
	})
	if not bool(r.get("ok", false)):
		cloud_error.emit(String(r.get("error", "Erreur inconnue")))
		return r
	var session: Dictionary = {}
	if r.get("data") is Dictionary:
		session = (r["data"] as Dictionary).get("session", {})
	if session.is_empty():
		return {"ok": true, "need_confirm": true}
	_apply_session(session, p)
	await load_profile()
	return {"ok": true, "need_confirm": false}


func sign_in(raw_pseudo: String, password: String) -> Dictionary:
	if not configured:
		return {"ok": false, "error": "Supabase non configure (voir docs/SUPABASE.md)"}
	var p := raw_pseudo.strip_edges().to_lower()
	if p.is_empty() or password.is_empty():
		return {"ok": false, "error": "Renseignez le pseudo et le mot de passe."}
	var r := await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {
		"email": _email_for(p), "password": password
	})
	if not bool(r.get("ok", false)):
		cloud_error.emit(String(r.get("error", "Identifiants incorrects")))
		return r
	var session: Dictionary = {}
	if r.get("data") is Dictionary:
		session = r["data"] as Dictionary
	_apply_session(session, p)
	await load_profile()
	return {"ok": true}


func _apply_session(session: Dictionary, fallback_pseudo: String) -> void:
	access_token = String(session.get("access_token", ""))
	refresh_token = String(session.get("refresh_token", ""))
	var user: Dictionary = session.get("user", {})
	user_id = String(user.get("id", ""))
	var meta: Dictionary = user.get("user_metadata", {})
	var p := String(meta.get("pseudo", fallback_pseudo)).to_lower()
	if p.is_empty():
		p = fallback_pseudo
	pseudo = p
	signed_in = access_token != ""
	auth_changed.emit(signed_in, pseudo)


func load_profile() -> Dictionary:
	if not signed_in:
		return {}
	var r := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/profiles?select=pseudo,score,xp,level,save_data&id=eq." + user_id,
		null, true)
	if not bool(r.get("ok", false)):
		return {}
	var rows: Array = []
	if r.get("data") is Array:
		rows = r["data"] as Array
	if rows.is_empty():
		return {}
	var profile: Dictionary = rows[0]
	pseudo = String(profile.get("pseudo", pseudo))
	Game.apply_cloud_profile(profile)
	auth_changed.emit(true, pseudo)
	login_succeeded.emit(pseudo)
	return profile


func save_progress() -> void:
	if not signed_in or user_id == "":
		return
	var data := Game.build_save_data()
	var r := await _request(HTTPClient.METHOD_PATCH,
		"/rest/v1/profiles?id=eq." + user_id,
		{
			"score": Game.score,
			"xp": Game.xp,
			"level": Game.level,
			"save_data": data
		},
		true,
		{"Prefer": "return=minimal"})
	if bool(r.get("ok", false)):
		sync_done.emit()
	else:
		cloud_error.emit("Sauvegarde : " + String(r.get("error", "erreur")))


func fetch_leaderboard() -> void:
	var r := await _request(HTTPClient.METHOD_GET,
		"/rest/v1/profiles?select=pseudo,score,xp,level&order=score.desc&limit=50")
	if not bool(r.get("ok", false)):
		cloud_error.emit("Classement : " + String(r.get("error", "erreur")))
		return
	var raw: Array = []
	if r.get("data") is Array:
		raw = r["data"] as Array
	var rows: Array[Dictionary] = []
	var best_other := 0
	for item in raw:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		var who := String(d.get("pseudo", "?"))
		var sc := int(d.get("score", 0))
		if who != RESERVED_PSEUDO:
			best_other = maxi(best_other, sc)
		rows.append({
			"pseudo": who, "score": sc,
			"xp": int(d.get("xp", 0)), "level": int(d.get("level", 1))
		})

	# Marge pédagogique de 12 % : monsieurhage reste premier A L'AFFICHAGE
	# uniquement. Les scores reels des eleves ne sont jamais modifies en base.
	var target := maxi(int(ceil(float(best_other) * 1.12)), best_other + 1) if best_other > 0 else 1
	var found := false
	for d in rows:
		if String(d.get("pseudo", "")) == RESERVED_PSEUDO:
			d["score"] = maxi(int(d.get("score", 0)), target)
			found = true
	if not found:
		rows.append({"pseudo": RESERVED_PSEUDO, "score": target, "xp": 0, "level": 99})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	leaderboard = rows
	leaderboard_ready.emit(rows)


func sign_out() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	signed_in = false
	pseudo = ""
	Game.run_state.clear()
	auth_changed.emit(false, "")
