double_room_step = 12.0
single_room_step = 7.2
corridor_width = 7.0

print("CorrWallW:")
prev_z = 0.0
for i in range(6):
    c_z = -6.0 - i * double_room_step
    gap_start = c_z + 1.5
    gap_end = c_z - 0.3
    length = prev_z - gap_start
    center = (prev_z + gap_start) / 2.0
    print(f"  Wall {i+1}: length={length}, center_z={center}, spans from {center + length/2} to {center - length/2}")
    prev_z = gap_end

print("CorrWallE:")
prev_z = 0.0
for i in range(9):
    c_z = -3.6 - i * single_room_step
    gap_start = c_z + 1.5
    gap_end = c_z - 0.3
    length = prev_z - gap_start
    center = (prev_z + gap_start) / 2.0
    print(f"  Wall {i+1}: length={length}, center_z={center}, spans from {center + length/2} to {center - length/2}")
    prev_z = gap_end
