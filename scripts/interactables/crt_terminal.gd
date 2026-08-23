# scripts/interactables/crt_terminal.gd
# One of these stands in the corridor of every floor except 1 (empty_box_mode, no rooms at all)
# and the roof (not a floor) - see hotel_level_generator.gd's _add_floor_terminal(). Interacting
# shows one of the CRT-terminal log entries already written in LORE.md ("Текстовые логи в
# CRT-терминалах") but never actually wired to anything - crt_screen.gdshader (the shader that
# would have driven a proper terminal screen effect) was deleted as unused dead code earlier in
# this same session, before this script existed to need it.
extends Area3D

const LOGS: Array[String] = [
	"Системы сбоят. Цербер-Альфа перешёл в автономный режим. Он не выпускает нас. Он считает нас зараженными. Кто-то заблокировал лифты.",
	"Аномалия реагирует на воспоминания. Мы думали, это просто искривление пространства, но она читает нас. Коридор на 4-м этаже... я иду по нему уже час, и он не кончается. Она не хочет, чтобы мы ушли.",
	"Задержан посторонний. Бывший коп, Нечаев. Откуда он узнал про Сектор-7? Посадите его в 408-й до прибытия начальства.",
]

func interact(_player: Node) -> void:
	DialogSystem.show_thought(LOGS[randi() % LOGS.size()], 6.0)
