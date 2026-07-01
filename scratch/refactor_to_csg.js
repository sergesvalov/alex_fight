const fs = require('fs');

const filePath = 'scenes/levels/hotel_siberia/base_hotel_level.tscn';
let content = fs.readFileSync(filePath, 'utf8');

const meshMap = {
    "BoxMesh_floor": { size: "Vector3(10, 0.5, 10)", material: 'SubResource("StandardMaterial3D_floor")' },
    "BoxMesh_wall": { size: "Vector3(10, 4, 1)", material: 'SubResource("StandardMaterial3D_wall")' },
    "BoxMesh_wall_half": { size: "Vector3(3.5, 4, 1)", material: 'SubResource("StandardMaterial3D_wall")' },
    "BoxMesh_corridor_floor": { size: "Vector3(6, 0.5, 40)", material: 'SubResource("StandardMaterial3D_floor")' },
    "BoxMesh_corridor_wall": { size: "Vector3(1, 4, 40)", material: 'SubResource("StandardMaterial3D_wall")' },
    "BoxMesh_corridor_wall_end": { size: "Vector3(6, 4, 1)", material: 'SubResource("StandardMaterial3D_wall")' },
};

const targetNodes = [];
const staticBodyPattern = /\[node name="([^"]+)" type="StaticBody3D" parent="NavigationRegion3D\/HotelGeometry"\]\r?\n([\s\S]*?)(?=\r?\n\[node|$)/g;

let match;
while ((match = staticBodyPattern.exec(content)) !== null) {
    const name = match[1];
    const body = match[2];
    const transformMatch = body.match(/transform = ([^\r\n]+)/);
    const transformStr = transformMatch ? transformMatch[1] : null;
    targetNodes.push({ name, transformStr, fullMatch: match[0] });
}

const nodesToConvert = [];
for (const node of targetNodes) {
    const meshRegex = new RegExp(`\\[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D\\/HotelGeometry\\/${node.name}"\\]\\r?\\n(?:[\\s\\S]*?\\r?\\n)?mesh = SubResource\\("([^"]+)"\\)`);
    const meshMatch = content.match(meshRegex);
    if (meshMatch) {
        const meshId = meshMatch[1];
        if (meshMap[meshId]) {
            node.meshId = meshId;
            nodesToConvert.push(node);
        }
    }
}

let newContent = content;
for (const node of nodesToConvert) {
    newContent = newContent.replace(node.fullMatch + "\n", "");
    newContent = newContent.replace(node.fullMatch + "\r\n", "");
    
    const colRegex = new RegExp(`\\[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D\\/HotelGeometry\\/${node.name}"\\]\\r?\\n([\\s\\S]*?)(?=\\r?\\n\\[node|$)`);
    const colMatch = newContent.match(colRegex);
    if (colMatch) {
        newContent = newContent.replace(colMatch[0] + "\n", "");
        newContent = newContent.replace(colMatch[0] + "\r\n", "");
    }
    
    const meshRegex = new RegExp(`\\[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D\\/HotelGeometry\\/${node.name}"\\]\\r?\\n([\\s\\S]*?)(?=\\r?\\n\\[node|$)`);
    const meshMatch = newContent.match(meshRegex);
    if (meshMatch) {
        newContent = newContent.replace(meshMatch[0] + "\n", "");
        newContent = newContent.replace(meshMatch[0] + "\r\n", "");
    }
}

let csgBlocks = `[node name="CorridorCSG" type="CSGCombiner3D" parent="NavigationRegion3D/HotelGeometry"]
use_collision = true
collision_layer = 2
`;

for (const node of nodesToConvert) {
    const size = meshMap[node.meshId].size;
    const material = meshMap[node.meshId].material;
    
    csgBlocks += `\n[node name="${node.name}" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry/CorridorCSG"]\n`;
    if (node.transformStr) {
        csgBlocks += `transform = ${node.transformStr}\n`;
    }
    csgBlocks += `size = ${size}\n`;
    csgBlocks += `material = ${material}\n`;
}

// Convert line endings in csgBlocks to match the file (let's just use \r\n to be safe)
csgBlocks = csgBlocks.replace(/\r?\n/g, '\r\n');

newContent = newContent.replace('[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]', '[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]\r\n\r\n' + csgBlocks);

fs.writeFileSync(filePath, newContent, 'utf8');
console.log("Refactored " + nodesToConvert.length + " nodes to CSG!");
