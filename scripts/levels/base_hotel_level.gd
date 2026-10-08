# scripts/levels/base_hotel_level.gd
# Root of a hotel level scene (base_hotel_level.tscn and the per-floor hotel_level_N.tscn that
# inherit it). Deliberately empty: the level itself - all ten stacked floors, rooms, tapes, the
# secret exit door - is built by hotel_level_generator.gd on NavigationRegion3D/HotelGeometry,
# enemies by the Enemies node's enemy_spawner.gd, mouse capture by the MouseManager autoload.
extends Node3D
