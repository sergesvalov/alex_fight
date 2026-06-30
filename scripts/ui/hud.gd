extends CanvasLayer

func _ready() -> void:
    var inv_btn = find_child("InventoryButton", true, false)
    var inv_ui = find_child("InventoryUI", true, false)
    if inv_btn and inv_ui:
        inv_btn.pressed.connect(inv_ui.open)

