$width = 25.3
$length = 60.0
$thickness = 0.2

$min_x = -$width/2 - $thickness
$max_x = $width/2 + $thickness
$min_z = -$length/2 - $thickness
$max_z = $length/2 + $thickness

$map_str = "## Actual Geometry Maps`n`n"
$levels = @(0.0, 1.0, 4.0)

function Intersects($min1, $max1, $min2, $max2) {
    return ($max1 -ge $min2) -and ($min1 -le $max2)
}

$aabbs = @()

# Outer Walls
$aabbs += @{ name="Wall_North"; x_min=$min_x; x_max=$max_x; z_min=$min_z; z_max=$min_z+$thickness }
$aabbs += @{ name="Wall_South"; x_min=$min_x; x_max=$max_x; z_min=$max_z-$thickness; z_max=$max_z }
$aabbs += @{ name="Wall_West";  x_min=$min_x; x_max=$min_x+$thickness; z_min=$min_z; z_max=$max_z }
$aabbs += @{ name="Wall_East";  x_min=$max_x-$thickness; x_max=$max_x; z_min=$min_z; z_max=$max_z }

# Maint Room
$aabbs += @{ name="Maint_Inner_South"; x_min=9.65; x_max=12.65; z_min=-20.0-$thickness/2; z_max=-20.0+$thickness/2 }
$aabbs += @{ name="Maint_Inner_West_North"; x_min=9.65-$thickness/2; x_max=9.65+$thickness/2; z_min=-30.0; z_max=-24.0 }
$aabbs += @{ name="Maint_Inner_West_South"; x_min=9.65-$thickness/2; x_max=9.65+$thickness/2; z_min=-22.0; z_max=-20.0 }
$aabbs += @{ name="Maint_Inner_West_Lintel"; x_min=9.65-$thickness/2; x_max=9.65+$thickness/2; z_min=-24.0; z_max=-22.0; y_min=2.2 }

# Elevator
$aabbs += @{ name="Elevator_Inner_East"; x_min=9.45-$thickness/2; x_max=9.45+$thickness/2; z_min=-30.0; z_max=-25.0 }
$aabbs += @{ name="Elevator_Inner_West"; x_min=4.95-$thickness/2; x_max=4.95+$thickness/2; z_min=-30.0; z_max=-25.0 }
$aabbs += @{ name="Elevator_Inner_South_West"; x_min=4.95; x_max=6.2; z_min=-25.0-$thickness/2; z_max=-25.0+$thickness/2 }
$aabbs += @{ name="Elevator_Inner_South_East"; x_min=8.2; x_max=9.45; z_min=-25.0-$thickness/2; z_max=-25.0+$thickness/2 }
$aabbs += @{ name="Elevator_Inner_South_Lintel"; x_min=6.2; x_max=8.2; z_min=-25.0-$thickness/2; z_max=-25.0+$thickness/2; y_min=2.2 }

# North Stairs block — inst.position = (1.05, 0, -30.0)
# Local block bounds: X=[-3.7..+3.7], Z=[0.0..4.9]
# Global: X = local.X + 1.05, Z = local.Z + (-30.0)
# WallEast  local X=+3.7  → global X=+4.75
# WallWest  local X=-3.7  → global X=-2.65
# WallNorth local Z= 0.1  → global Z=-29.9
# WallSouth local Z= 4.9  → global Z=-25.1
# CenterDivider local X=0 → global X=+1.05, Z=[0..4.0] → global Z=[-30..-26]
# DoorHoleEast: X=+2.8±0.7 → global X=[+3.15..+4.45], Y=0..2.2 (lower entry)
# DoorHoleWest: X=-2.8±0.7 → global X=[-2.45..-1.15], Y=4.5..6.7 (upper exit)

$stair_ox = 1.05   # inst.position.X
$stair_oz = -30.0  # inst.position.Z

$aabbs += @{ name="Stairs_WallEast";   x_min=$stair_ox+3.6; x_max=$stair_ox+3.8; z_min=$stair_oz+0.0; z_max=$stair_oz+4.9 }
$aabbs += @{ name="Stairs_WallWest";   x_min=$stair_ox-3.8; x_max=$stair_ox-3.6; z_min=$stair_oz+0.0; z_max=$stair_oz+4.9 }
$aabbs += @{ name="Stairs_WallNorth";  x_min=$stair_ox-3.8; x_max=$stair_ox+3.8; z_min=$stair_oz+0.0; z_max=$stair_oz+0.2 }
# South wall with two door holes — represented as three segments (left of east door, between doors, right of west door):
$aabbs += @{ name="Stairs_WallSouth_EastPart";  x_min=$stair_ox+3.15; x_max=$stair_ox+3.8; z_min=$stair_oz+4.8; z_max=$stair_oz+4.9 }
$aabbs += @{ name="Stairs_WallSouth_MidPart";   x_min=$stair_ox-1.15; x_max=$stair_ox+1.75; z_min=$stair_oz+4.8; z_max=$stair_oz+4.9 }
$aabbs += @{ name="Stairs_WallSouth_WestPart";  x_min=$stair_ox-3.8; x_max=$stair_ox-2.45; z_min=$stair_oz+4.8; z_max=$stair_oz+4.9 }
# Lintels above doors (Y>=2.2)
$aabbs += @{ name="Stairs_WallSouth_EastLintel"; x_min=$stair_ox+1.75; x_max=$stair_ox+3.15; z_min=$stair_oz+4.8; z_max=$stair_oz+4.9; y_min=2.2 }
$aabbs += @{ name="Stairs_WallSouth_WestLintel"; x_min=$stair_ox-2.45; x_max=$stair_ox-1.15; z_min=$stair_oz+4.8; z_max=$stair_oz+4.9; y_min=4.5 }
# Center divider (full height, stops before mid-landing)
$aabbs += @{ name="Stairs_CenterDivider"; x_min=$stair_ox-0.1; x_max=$stair_ox+0.1; z_min=$stair_oz+1.0; z_max=$stair_oz+4.9 }

# Double Room 401
$aabbs += @{ name="Room401_WC_West"; x_min=-7.75-$thickness/2; x_max=-7.75+$thickness/2; z_min=-30.0; z_max=-25.0 }
$aabbs += @{ name="Room401_WC_South_West"; x_min=-7.75; x_max=-6.0; z_min=-25.0-$thickness/2; z_max=-25.0+$thickness/2 }
$aabbs += @{ name="Room401_WC_South_East"; x_min=-5.0; x_max=-2.85; z_min=-25.0-$thickness/2; z_max=-25.0+$thickness/2 }
$aabbs += @{ name="Room401_WC_South_Lintel"; x_min=-6.0; x_max=-5.0; z_min=-25.0-$thickness/2; z_max=-25.0+$thickness/2; y_min=2.2 }
$aabbs += @{ name="Room401_Inner_North"; x_min=-12.55; x_max=-2.75; z_min=-29.9-$thickness/2; z_max=-29.9+$thickness/2 }
$aabbs += @{ name="Room401_Inner_South"; x_min=-12.55; x_max=-2.75; z_min=-20.0-$thickness/2; z_max=-20.0+$thickness/2 }
$aabbs += @{ name="Room401_Inner_East_North"; x_min=-2.85-$thickness/2; x_max=-2.85+$thickness/2; z_min=-30.0; z_max=-22.5 }
$aabbs += @{ name="Room401_Inner_East_South"; x_min=-2.85-$thickness/2; x_max=-2.85+$thickness/2; z_min=-20.5; z_max=-20.0 }
$aabbs += @{ name="Room401_Inner_East_Lintel"; x_min=-2.85-$thickness/2; x_max=-2.85+$thickness/2; z_min=-22.5; z_max=-20.5; y_min=2.2 }

foreach ($y in $levels) {
    $map_str += "### Map at Y=$y`n````	ext`n"
    
    for ($z = [math]::Floor($min_z) - 1; $z -le [math]::Ceiling($max_z) + 1; $z++) {
        $row = ""
        for ($x = [math]::Floor($min_x)*2 - 2; $x -le [math]::Ceiling($max_x)*2 + 2; $x++) {
            $cell_xmin = ($x / 2.0) - 0.25
            $cell_xmax = ($x / 2.0) + 0.25
            $cell_zmin = $z - 0.5
            $cell_zmax = $z + 0.5
            
            $is_wall = $false
            
            foreach ($aabb in $aabbs) {
                if ($aabb.ContainsKey("y_min") -and $y -lt $aabb.y_min) { continue }
                if ((Intersects $cell_xmin $cell_xmax $aabb.x_min $aabb.x_max) -and 
                    (Intersects $cell_zmin $cell_zmax $aabb.z_min $aabb.z_max)) {
                    $is_wall = $true
                    break
                }
            }
            if ($is_wall) { $row += "#" } else {
                $real_x = $x / 2.0
                if ($real_x -gt $min_x -and $real_x -lt $max_x -and $z -gt $min_z -and $z -lt $max_z) {
                    $row += "."
                } else {
                    $row += " "
                }
            }
        }
        $map_str += $row + "`n"
    }
    $map_str += "````
`n"
}
$map_str | Out-File -Encoding UTF8 new_map.txt


