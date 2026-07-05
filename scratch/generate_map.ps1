$ErrorActionPreference = 'Stop'

function Parse-Vector3 ($s) {
    $s = $s.Replace("Vector3(", "").Replace(")", "")
    $parts = $s.Split(",")
    return [float]$parts[0].Trim(), [float]$parts[1].Trim(), [float]$parts[2].Trim()
}

function Parse-Transform ($s) {
    $s = $s.Replace("Transform3D(", "").Replace(")", "")
    $parts = $s.Split(",")
    return [float]$parts[9].Trim(), [float]$parts[10].Trim(), [float]$parts[11].Trim()
}

function Parse-Tscn ($filepath) {
    $walls = @()
    $props = @()
    
    $lines = Get-Content -Path $filepath -Encoding UTF8
    
    $curr_name = ""
    $curr_pos = $null
    $curr_size = $null
    $curr_type = ""
    
    foreach ($line in $lines) {
        if ($line.StartsWith("[node name=")) {
            if ($curr_name -and $curr_pos) {
                if ($curr_size) {
                    $walls += @{name=$curr_name; pos=$curr_pos; size=$curr_size}
                } elseif ($curr_type) {
                    $props += @{name=$curr_name; pos=$curr_pos; type=$curr_type}
                }
            }
            
            if ($line -match 'name="([^"]+)"') {
                $curr_name = $matches[1]
            } else {
                $curr_name = ""
            }
            
            $curr_pos = $null
            $curr_size = $null
            $curr_type = ""
            
            if ($line -match "CSGBox3D") {
                $curr_type = "wall"
            } elseif ($line -match 'instance=ExtResource\("([^"]+)"\)') {
                $type_parts = $matches[1].Split("_")
                $curr_type = $type_parts[-1]
            }
        } elseif ($line.StartsWith("transform =")) {
            $curr_pos = Parse-Transform ($line.Split("=")[1])
        } elseif ($line.StartsWith("size =")) {
            $curr_size = Parse-Vector3 ($line.Split("=")[1])
        }
    }
    
    if ($curr_name -and $curr_pos) {
        if ($curr_size) {
            $walls += @{name=$curr_name; pos=$curr_pos; size=$curr_size}
        } elseif ($curr_type) {
            $props += @{name=$curr_name; pos=$curr_pos; type=$curr_type}
        }
    }
    
    return @{walls=$walls; props=$props}
}

$db = Parse-Tscn "scenes/levels/hotel_siberia/blocks/double_room.tscn"
$db_walls = $db.walls
$db_props = $db.props

$sg = Parse-Tscn "scenes/levels/hotel_siberia/blocks/single_room.tscn"
$sg_walls = $sg.walls
$sg_props = $sg.props

$global_rooms = @()
$generatorLines = Get-Content -Path "scripts/levels/hotel_level_generator.gd" -Encoding UTF8
$curr_type = ""

foreach ($line in $generatorLines) {
    if ($line -match 'inst\.name = "(Double|Single)Room_(\d+)"') {
        $curr_type = $matches[1].ToLower()
    }
    if ($curr_type -ne "" -and $line -match 'inst\.position = Vector3\(([^,]+),([^,]+),([^)]+)\)') {
        $px = [float]$matches[1].Replace("* f_scale","").Trim()
        $py = [float]$matches[2].Replace("* f_scale","").Trim()
        $pz = [float]$matches[3].Replace("* f_scale","").Trim()
        $global_rooms += @{type=$curr_type; pos=@($px, $py, $pz)}
        $curr_type = ""
    }
}

$all_walls = @()
$all_props = @()

foreach ($r in $global_rooms) {
    [float]$bx = $r.pos[0]
    [float]$by = $r.pos[1]
    [float]$bz = $r.pos[2]
    
    $walls = if ($r.type -eq "double") { $db_walls } else { $sg_walls }
    $props = if ($r.type -eq "double") { $db_props } else { $sg_props }
    
    foreach ($w in $walls) {
        [float]$lx = $w.pos[0]
        [float]$ly = $w.pos[1]
        [float]$lz = $w.pos[2]
        $all_walls += @{name=$w.name; pos=@($bx+$lx, $by+$ly, $bz+$lz); size=$w.size; type="box"}
    }
    
    foreach ($p in $props) {
        if ($p.type -eq "wall") { continue }
        [float]$lx = $p.pos[0]
        [float]$ly = $p.pos[1]
        [float]$lz = $p.pos[2]
        $all_props += @{name=$p.name; pos=@($bx+$lx, $by+$ly, $bz+$lz); type=$p.type}
    }
}

$prop_sizes = @{
    "bed" = @(2.0, 0.5, 2.0)
    "wardrobe" = @(1.0, 2.0, 1.0)
    "table" = @(1.0, 1.0, 1.0)
    "chair" = @(0.5, 1.0, 0.5)
    "door" = @(1.0, 2.2, 1.0)
}

function Render-Map ($y_level) {
    [float]$min_x = -15.0; [float]$max_x = 15.0
    [float]$min_z = -45.0; [float]$max_z = 35.0
    [float]$step = 0.5
    
    $w = [Math]::Floor(($max_x - $min_x) / $step)
    $h = [Math]::Floor(($max_z - $min_z) / $step)
    
    $grid = New-Object 'char[,]' $h, $w
    for ($zi=0; $zi -lt $h; $zi++) {
        for ($xi=0; $xi -lt $w; $xi++) {
            $grid[$zi, $xi] = ' '
        }
    }
    
    foreach ($r in $all_walls) {
        if ($r.name -match "Hole") { continue }
        
        [float]$px = $r.pos[0]; [float]$py = $r.pos[1]; [float]$pz = $r.pos[2]
        [float]$sx = $r.size[0]; [float]$sy = $r.size[1]; [float]$sz = $r.size[2]
        
        if ($y_level -ge ($py - $sy/2) -and $y_level -le ($py + $sy/2)) {
            $x1 = [Math]::Floor(($px - $sx/2 - $min_x) / $step)
            $x2 = [Math]::Ceiling(($px + $sx/2 - $min_x) / $step)
            $z1 = [Math]::Floor(($pz - $sz/2 - $min_z) / $step)
            $z2 = [Math]::Ceiling(($pz + $sz/2 - $min_z) / $step)
            
            $x1 = [Math]::Max(0, [Math]::Min($w-1, $x1))
            $x2 = [Math]::Max(0, [Math]::Min($w-1, $x2))
            $z1 = [Math]::Max(0, [Math]::Min($h-1, $z1))
            $z2 = [Math]::Max(0, [Math]::Min($h-1, $z2))
            
            for ($zi=$z1; $zi -lt $z2; $zi++) {
                for ($xi=$x1; $xi -lt $x2; $xi++) {
                    $grid[$zi, $xi] = '#'
                }
            }
        }
    }
    
    foreach ($p in $all_props) {
        [float]$px = $p.pos[0]; [float]$py = $p.pos[1]; [float]$pz = $p.pos[2]
        if ($prop_sizes.ContainsKey($p.type)) {
            $sz_arr = $prop_sizes[$p.type]
        } else {
            $sz_arr = @(1.0, 1.0, 1.0)
        }
        [float]$sx = $sz_arr[0]; [float]$sy = $sz_arr[1]; [float]$sz = $sz_arr[2]
        
        if ($y_level -ge ($py - $sy/2) -and $y_level -le ($py + $sy/2)) {
            $x1 = [Math]::Floor(($px - $sx/2 - $min_x) / $step)
            $x2 = [Math]::Ceiling(($px + $sx/2 - $min_x) / $step)
            $z1 = [Math]::Floor(($pz - $sz/2 - $min_z) / $step)
            $z2 = [Math]::Ceiling(($pz + $sz/2 - $min_z) / $step)
            
            $x1 = [Math]::Max(0, [Math]::Min($w-1, $x1))
            $x2 = [Math]::Max(0, [Math]::Min($w-1, $x2))
            $z1 = [Math]::Max(0, [Math]::Min($h-1, $z1))
            $z2 = [Math]::Max(0, [Math]::Min($h-1, $z2))
            
            $char = if ($p.type -eq "door") { 'D' } else { $p.type.Substring(0,1).ToUpper() }
            
            for ($zi=$z1; $zi -lt $z2; $zi++) {
                for ($xi=$x1; $xi -lt $x2; $xi++) {
                    $grid[$zi, $xi] = $char
                }
            }
        }
    }
    
    $res = ""
    for ($zi=0; $zi -lt $h; $zi++) {
        $line = ""
        for ($xi=0; $xi -lt $w; $xi++) {
            $line += $grid[$zi, $xi]
        }
        $res += $line + "`n"
    }
    return $res
}

$output = "`n`n## Actual Geometry Maps`n`n"
$output += "### Map at Floor Level (Y=0.0)`n```text`n" + (Render-Map 0.0) + "````n`n"
$output += "### Map at 1 Meter (Y=1.0)`n```text`n" + (Render-Map 1.0) + "````n`n"
$output += "### Map at Wall/Ceiling intersection (Y=4.0)`n```text`n" + (Render-Map 4.0) + "````n`n"

$output += @"
### Object Descriptions
- **#**: Walls (Solid CSGBox3D structures defining the rooms and corridors).
- **.**: Floor/Ceiling areas.
- **B**: Bed. A large interactable furniture object where characters can rest or hide.
- **W**: Wardrobe. A tall wooden storage unit.
- **T**: Table. A standard desk/table.
- **C**: Chair. An interactable physics object.
- **D**: Door. The interactive doors placed at room entrances and WCs. 
"@

$agentsText = Get-Content -Path ".agents\AGENTS.md" -Raw
$agentsText = $agentsText -replace "(?s)## Actual Geometry Maps.*", $output
Set-Content -Path ".agents\AGENTS.md" -Value $agentsText -Encoding UTF8

Write-Host "Updated AGENTS.md successfully!"
