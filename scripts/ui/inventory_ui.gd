extends Panel

@onready var grid = $ScrollContainer/GridContainer
@onready var close_btn = $CloseButton

func _ready():
    # Populate with empty slots for a standard look
    for i in range(25):
        var slot = ColorRect.new()
        slot.custom_minimum_size = Vector2(90, 90)
        slot.color = Color(0.15, 0.15, 0.15, 0.9)
        
        # Add a border
        var border = ReferenceRect.new()
        border.editor_only = false
        border.border_color = Color(0.4, 0.4, 0.4, 1)
        border.border_width = 2.0
        border.layout_mode = 1
        border.anchors_preset = 15
        border.anchor_right = 1.0
        border.anchor_bottom = 1.0
        slot.add_child(border)
        
        grid.add_child(slot)
        
    close_btn.pressed.connect(close)

func open():
    show()
    # Pause the game while inventory is open
    get_tree().paused = true

func close():
    hide()
    # Resume the game
    get_tree().paused = false
