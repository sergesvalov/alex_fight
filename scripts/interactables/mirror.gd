extends Node3D

var has_triggered = false

func _on_area_3d_body_entered(body: Node3D) -> void:
    if not has_triggered and body.is_in_group("player"):
        has_triggered = true
        var thought = "Это... мое лицо? На рубашке приколот бейдж: «АЛЕКС».\nЯ помню, как стрелять из лазера, но абсолютно не помню, как я здесь очутился."
        if DialogSystem.has_method("show_thought"):
            DialogSystem.show_thought(thought, 8.0)
