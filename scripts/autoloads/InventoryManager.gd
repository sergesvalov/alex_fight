# autoloads/InventoryManager.gd
extends Node

signal ammo_changed(shots_in_chamber: int, reserve_ammo: int)
signal item_added(item_name: String)

# Шотган: патроны в стволе и в запасе
var shots_in_chamber: int = 2   # Текущие патроны в стволе (макс. 2)
var reserve_ammo: int = 8       # Запасные патроны

const MAX_CHAMBER: int = 2      # Шотган двустволка

func spend_shot() -> bool:
    if shots_in_chamber <= 0:
        return false
    shots_in_chamber -= 1
    ammo_changed.emit(shots_in_chamber, reserve_ammo)
    return true

func reload() -> void:
    var needed: int = MAX_CHAMBER - shots_in_chamber
    var can_reload: int = min(needed, reserve_ammo)
    shots_in_chamber += can_reload
    reserve_ammo -= can_reload
    ammo_changed.emit(shots_in_chamber, reserve_ammo)

func add_ammo(amount: int) -> void:
    reserve_ammo += amount
    ammo_changed.emit(shots_in_chamber, reserve_ammo)
