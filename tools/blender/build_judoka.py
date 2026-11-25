# Génère le modèle de judoka (corps CC0 Quaternius + judogi généré) au format GLB.
# Usage : blender -b --python build_judoka.py -- <dossier_ubc> <sortie.glb>
#
# Le judogi est créé à partir de la peau du personnage : les faces du torse,
# des bras et des jambes sont dupliquées, lissées puis gonflées le long des
# normales. Les poids de skinning sont conservés, donc le kimono suit le
# squelette sans travail supplémentaire. La ceinture est un anneau généré,
# ajusté à la taille de la veste.
import bpy, bmesh, sys, math, os
from mathutils import Vector, kdtree

argv = sys.argv[sys.argv.index("--") + 1:]
UBC, OUT = argv[0], argv[1]
BASE = os.path.join(UBC, "Base Characters", "Godot - UE")
HAIR = os.path.join(UBC, "Hairstyles", "Rigged to Head Bone", "glTF (Godot -Unreal)")
HAIR_NAME = argv[2] if len(argv) > 2 else "Hair_SimpleParted,Hair_Buzzed"
TEX_SIZE = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(BASE, "Superhero_Male_FullBody.gltf"))
for o in list(bpy.data.objects):
    if o.type == "MESH" and o.parent is None:
        bpy.data.objects.remove(o)  # icosphère parasite
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
body = bpy.data.objects["SuperHero_Male"]
body.name = "Body"

# ---------------------------------------------------------------- cheveux
# Plusieurs coiffures dans le même modèle (Hair_<nom>) : le jeu n'en affiche qu'une.
for hair_name in HAIR_NAME.split(","):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HAIR, hair_name + ".gltf"))
    for o in set(bpy.data.objects) - before:
        if o.type == "MESH":
            o.parent = arm
            o.matrix_parent_inverse.identity()
            for m in o.modifiers:
                if m.type == "ARMATURE":
                    m.object = arm
            if not any(m.type == "ARMATURE" for m in o.modifiers):
                mod = o.modifiers.new("Armature", "ARMATURE")
                mod.object = arm
            o.name = "Hair_" + hair_name.replace("Hair_", "")
    for o in set(bpy.data.objects) - before:
        if o.type in ("ARMATURE", "EMPTY") and o.name in bpy.data.objects:
            bpy.data.objects.remove(o)

# ---------------------------------------------------------------- classement des sommets
me = body.data
gname = {g.index: g.name for g in body.vertex_groups}

def dominant(v):
    best, bw = None, 0.0
    for g in v.groups:
        if g.weight > bw:
            best, bw = gname[g.group], g.weight
    return best

def wsum(v, names):
    return sum(g.weight for g in v.groups if gname[g.group] in names)

TORSO = {"spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"}
ARM = {"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"}
LEG = {"pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"}

def v_opening(co, margin=0.0):
    # Ouverture en V du col (avant = -Y)
    if co.y > 0.02 or co.z < 1.30 - margin:
        return False
    half = 0.012 + (co.z - 1.30) * 0.34 + margin
    return abs(co.x) < half

jacket, pants = set(), set()
for v in me.vertices:
    co = v.co
    d = dominant(v)
    neck = wsum(v, {"neck_01", "Head"})
    if neck > 0.35 or co.z > 1.53:
        continue
    if abs(co.x) > 0.64:          # manches arrêtées avant le poignet
        continue
    if d in TORSO or d in ARM or (wsum(v, TORSO | ARM) > 0.3):
        if not v_opening(co):
            jacket.add(v.index)
        continue
    if d in LEG:
        if co.z < 0.16:            # bas du pantalon au-dessus de la cheville
            continue
        pants.add(v.index)
        if co.z > 0.80 and not v_opening(co):   # pans de la veste
            jacket.add(v.index)

# ---------------------------------------------------------------- création des coques
def make_shell(name, vids, offset_fn, smooth_iter=6):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    keep = set(vids)
    dead = [f for f in bm.faces if not all(v.index in keep for v in f.verts)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.normal_update()
    orig = {v: v.co.copy() for v in bm.verts}
    nrm = {v: v.normal.copy() for v in bm.verts}
    offs = {v: offset_fn(orig[v]) for v in bm.verts}
    for v in bm.verts:
        v.co = orig[v] + nrm[v] * offs[v]
    # lissage : efface la musculature, donne un aspect de tissu
    for _ in range(smooth_iter):
        new = {}
        for v in bm.verts:
            if v.is_boundary:
                new[v] = v.co.copy()
                continue
            avg = Vector()
            for e in v.link_edges:
                avg += e.other_vert(v).co
            avg /= len(v.link_edges)
            new[v] = v.co.lerp(avg, 0.5)
        for v in bm.verts:
            c = new[v]
            # ne jamais rentrer dans la peau
            depth = (c - orig[v]).dot(nrm[v])
            if depth < offs[v] * 0.75:
                c = c + nrm[v] * (offs[v] * 0.75 - depth)
            v.co = c
    m2 = bpy.data.meshes.new(name)
    bm.to_mesh(m2)
    bm.free()
    ob = bpy.data.objects.new(name, m2)
    bpy.context.collection.objects.link(ob)
    ob.parent = arm
    # recopie des groupes de sommets (bmesh conserve la couche deform)
    for g in body.vertex_groups:
        ob.vertex_groups.new(name=g.name)
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob

def jacket_off(co):
    o = 0.028
    if abs(co.x) > 0.2:                      # manches amples
        o = 0.034 if abs(co.x) < 0.45 else 0.030
    if co.z < 1.0:
        o = 0.036                            # pans par-dessus le pantalon
    # revers : bord épaissi autour de l'ouverture en V
    if v_opening(co, 0.035) and co.y < 0.0:
        o += 0.008
    return o

def pants_off(co):
    return 0.022 if co.z > 0.5 else 0.020

j = make_shell("Judogi_Jacket", jacket, jacket_off)
p = make_shell("Judogi_Pants", pants, pants_off, smooth_iter=5)

# ---------------------------------------------------------------- matériaux
def flat_mat(name, rgb, rough=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m

gi = flat_mat("Gi", (0.92, 0.92, 0.90))
for ob in (j, p):
    ob.data.materials.clear()
    ob.data.materials.append(gi)

# ---------------------------------------------------------------- ceinture
BZ, BH, BT = 1.025, 0.045, 0.010
jv = [j.matrix_world @ v.co for v in j.data.vertices if abs(v.co.z - BZ) < 0.03 and abs(v.co.x) < 0.25]
N = 56
radii = []
cx = sum(v.x for v in jv) / len(jv)
cy = sum(v.y for v in jv) / len(jv)
for i in range(N):
    a = 2 * math.pi * i / N
    d = Vector((math.cos(a), math.sin(a), 0))
    r = 0.0
    for v in jv:
        w = Vector((v.x - cx, v.y - cy, 0))
        if w.length > 1e-4 and w.normalized().dot(d) > 0.985:
            r = max(r, w.length)
    radii.append(r)
for i in range(N):  # bouche les trous éventuels
    if radii[i] == 0.0:
        radii[i] = max(radii[(i - 1) % N], radii[(i + 1) % N], 0.15)
radii = [(radii[i - 1] + radii[i] * 2 + radii[(i + 1) % N]) / 4 + 0.004 for i in range(N)]

bm = bmesh.new()
rows = []
for (z, dr) in ((BZ - BH / 2, 0), (BZ + BH / 2, 0), (BZ + BH / 2, BT), (BZ - BH / 2, BT)):
    row = []
    for i in range(N):
        a = 2 * math.pi * i / N
        r = radii[i] + dr
        row.append(bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, z)))
    rows.append(row)
for k in range(4):
    r0, r1 = rows[k], rows[(k + 1) % 4]
    for i in range(N):
        bm.faces.new((r0[i], r0[(i + 1) % N], r1[(i + 1) % N], r1[i]))

def box(center, size, rot=0.0):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = []
    for dz in (-hz, hz):
        for (dx, dy) in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)):
            x = dx * math.cos(rot) - dz * math.sin(rot)
            z = dx * math.sin(rot) + dz * math.cos(rot)
            vs.append(bm.verts.new((center[0] + x, center[1] + dy, center[2] + z)))
    f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    for idx in f:
        bm.faces.new([vs[i] for i in idx])

# nœud et pans devant (avant = -Y)
front = cy - radii[N * 3 // 4] - BT - 0.006
box((cx, front, BZ), (0.06, 0.022, 0.05))
box((cx - 0.045, front + 0.004, BZ - 0.13), (0.042, 0.008, 0.22), rot=0.18)
box((cx + 0.05, front + 0.004, BZ - 0.12), (0.042, 0.008, 0.20), rot=-0.14)
bm.normal_update()
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm_mesh = bpy.data.meshes.new("Belt")
bm.to_mesh(bm_mesh)
bm.free()
belt = bpy.data.objects.new("Belt", bm_mesh)
bpy.context.collection.objects.link(belt)
belt.parent = arm
for name in ("pelvis", "spine_01"):
    belt.vertex_groups.new(name=name)
for v in belt.data.vertices:
    belt.vertex_groups["pelvis"].add([v.index], 0.6, "REPLACE")
    belt.vertex_groups["spine_01"].add([v.index], 0.4, "REPLACE")
mod = belt.modifiers.new("Armature", "ARMATURE")
mod.object = arm
belt.data.materials.append(flat_mat("Belt", (0.05, 0.05, 0.05), 0.8))

# ---------------------------------------------------------------- peau cachée supprimée
covered = set()
for i in jacket | pants:
    co = me.vertices[i].co
    if abs(co.x) > 0.58 or co.z < 0.24 or co.z > 1.45 or v_opening(co, 0.05):
        continue
    covered.add(i)
bm = bmesh.new()
bm.from_mesh(me)
dead = [f for f in bm.faces if all(v.index in covered for v in f.verts)]
bmesh.ops.delete(bm, geom=dead, context="FACES")
bm.to_mesh(me)
bm.free()

# ---------------------------------------------------------------- textures allégées pour le mobile
for img in bpy.data.images:
    if img.size[0] > TEX_SIZE:
        img.scale(TEX_SIZE, TEX_SIZE)

for ob in bpy.data.objects:
    if ob.type == "MESH":
        tris = sum(len(pl.vertices) - 2 for pl in ob.data.polygons)
        print("MESH", ob.name, "tris", tris)

bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_animations=False,
    export_skins=True, export_apply=False, export_yup=True,
    export_image_format="JPEG", export_jpeg_quality=88,
)
print("EXPORT_OK", OUT)
