extends Node

# Global Signal Bus for decoupled game communication

# Player signals
signal player_health_changed(current: float, max_val: float)
signal player_sanity_changed(current: float, max_val: float)
signal player_stamina_changed(current: float, max_val: float)
signal player_noise_made(level: float, position: Vector3)
signal player_death_requested(reason: String)
signal player_died(reason: String)
signal player_entered_hiding(is_hiding: bool)

# Flashlight & Inventory signals
signal flashlight_toggled(is_on: bool)
signal flashlight_battery_changed(current: float, max_val: float)
signal inventory_updated(slots: Array)
signal item_equipped(slot_index: int, item_data: Dictionary)
signal item_used(item_data: Dictionary)

# Lampor AI signals
signal lampor_state_changed(state_name: String)
signal lampor_stare_detected(intensity: float)
signal lampor_nearby(distance: float)
signal lampor_screamer_triggered()
signal lampor_jumpscare()

# Dialog & UI signals
signal dialog_requested(text: String, duration: float)

# World & Objective signals
signal act_started(act_number: int, title: String)
signal objective_updated(objective_id: String, text: String, current: int, required: int, is_completed: bool)
signal torch_lit(torch_id: int, total_lit: int, total_required: int)
signal ritual_item_collected(item_name: String, count: int, total: int)
signal furnace_progress_updated(seconds_remaining: float, total_seconds: float)
signal time_tick(time_str: String, hour: int, minute: int)
signal game_won()
signal game_over(reason: String)
signal request_barricade_warning(door_node: Node, player_node: Node)

# Account, Multiplayer & Sandbox signals (v1.3.0)
signal coins_changed(new_coins: int)
signal account_state_changed()
signal multiplayer_rooms_updated(rooms: Array)
signal multiplayer_room_updated(room: Dictionary, players: Array)
signal multiplayer_game_started(room: Dictionary)
signal multiplayer_event_received(event_type: String, payload: Dictionary, sender_name: String)
signal multiplayer_disconnected(reason: String)
signal sandbox_panel_toggled(is_open: bool)

# Fate Card signals
signal fate_card_applied(card_data: Dictionary)
signal fate_cards_reset()
