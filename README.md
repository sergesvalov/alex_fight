# Alex Fight

> 3D-шутер | Godot 4.7 | Android | Ретрофутуризм

Коридорный шутер с элементами survival horror. Действие разворачивается в заброшенной провинциальной гостинице в Сибири. Герой — полицейский без памяти — ищет выход, собирает кассеты с голопроекциями и сталкивается с монстром на выходе.

---

## 📋 Документация

- **[GDD.md](GDD.md)** — полный Game Design Document и техническая архитектура (Godot 4.7, GDScript, Mobile UX)
- **[MECHANICS.md](MECHANICS.md)** — описание основных игровых механик, управления и боевки
- **[.agents/AGENTS.md](.agents/AGENTS.md)** — технический контекст и правила проекта для AI-агентов

---

## 🛠️ Стек

| Компонент | Технология |
|---|---|
| Движок | Godot 4.7 |
| Рендер | Vulkan Mobile |
| Физика | Godot Jolt Physics |
| Платформа | Android 8.0+ |
| Язык | GDScript |

---

## 🚀 Быстрый старт

1. Открыть проект в **Godot 4.7**
2. Импортировать (`Project → Import`)
3. Запустить `scenes/levels/hotel_siberia/hotel_level.tscn`
4. Для сборки на Android: `Project → Export → Android`

---

## 📁 Структура

```
alex_fight/
├── GDD.md              ← Game Design Document
├── README.md           ← этот файл
├── scenes/
├── scripts/
├── assets/
└── shaders/
```
