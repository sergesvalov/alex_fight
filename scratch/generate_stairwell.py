import os

file_content = """[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/levels/seamless_teleporter.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/textures/hotel_carpet.jpg" id="2_carpet"]
[ext_resource type="Texture2D" path="res://assets/textures/hotel_wallpaper.jpg" id="3_wallpaper"]
[ext_resource type="PackedScene" path="res://entities/props/door.tscn" id="4_door"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_floor"]
albedo_texture = ExtResource("2_carpet")
uv1_scale = Vector3(10, 10, 10)
uv1_triplanar = true

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_wall"]
albedo_texture = ExtResource("3_wallpaper")
uv1_scale = Vector3(20, 2, 2)
roughness = 0.9

[sub_resource type="BoxShape3D" id="BoxShape3D_teleport"]
size = Vector3(3.5, 1.0, 3.5)

[node name="Stairwell" type="CSGCombiner3D"]
use_collision = true
collision_layer = 2

[node name="LandingSouth" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.25, -1.75)
size = Vector3(7, 0.5, 3.5)
material = SubResource("StandardMaterial3D_floor")

[node name="LandingEast" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.75, -0.25, -5.25)
size = Vector3(3.5, 0.5, 3.5)
material = SubResource("StandardMaterial3D_floor")

[node name="NorthRamp" type="CSGPolygon3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -7)
polygon = PackedVector2Array(0, 0, 3.5, -2.5, 3.5, -3, 0, -0.5)
depth = 3.5
material = SubResource("StandardMaterial3D_floor")

[node name="NWHalfLanding" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.75, -2.75, -5.25)
size = Vector3(3.5, 0.5, 3.5)
material = SubResource("StandardMaterial3D_floor")

[node name="WestRamp" type="CSGPolygon3D" parent="."]
transform = Transform3D(-4.37114e-08, 0, 1, 0, 1, 0, -1, 0, -4.37114e-08, 0, 0, -3.5)
polygon = PackedVector2Array(0, -2.5, 3.5, -5, 3.5, -5.5, 0, -3)
depth = 3.5
material = SubResource("StandardMaterial3D_floor")

[node name="WallNorth" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -7.25)
size = Vector3(7, 10, 0.5)
material = SubResource("StandardMaterial3D_wall")

[node name="WallWest" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.75, 0, -3.5)
size = Vector3(0.5, 10, 7)
material = SubResource("StandardMaterial3D_wall")

[node name="WallEast" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3.75, 0, -3.5)
size = Vector3(0.5, 10, 7)
material = SubResource("StandardMaterial3D_wall")

[node name="WallSouth" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0.25)
size = Vector3(7, 10, 0.5)
material = SubResource("StandardMaterial3D_wall")

[node name="DoorHole" type="CSGBox3D" parent="WallSouth"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.4375, 0)
operation = 2
size = Vector3(1.84, 2.875, 1)

[node name="MainDoor" parent="." instance=ExtResource("4_door")]

[node name="TeleportUpper" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.75, 3.0, -5.25)
script = ExtResource("1_script")
teleport_offset = Vector3(0, -5, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="TeleportUpper"]
shape = SubResource("BoxShape3D_teleport")

[node name="TeleportLower" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.75, -2.0, -1.75)
script = ExtResource("1_script")
teleport_offset = Vector3(0, 5, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="TeleportLower"]
shape = SubResource("BoxShape3D_teleport")

[node name="LightMain" type="OmniLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.75, 3, -1.75)
omni_range = 10.0

[node name="LightHalf" type="OmniLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.75, 1, -5.25)
omni_range = 10.0

[node name="LightLower" type="OmniLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.75, -2, -1.75)
omni_range = 10.0
"""

with open("c:/wndr/repo/alex_fight/scenes/levels/hotel_siberia/stairwell.tscn", "w") as f:
    f.write(file_content)
