# Ray-traced product shot of the rack. Run through product/render.sh, which exports the meshes first.
#   render.py <meshes dir> <out.png> <shot> <width> <samples> [black|white|clear]
import bpy, bmesh, math, sys, os
from mathutils import Matrix

d, out, shot, res, samples = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])

# model dimensions, written by render.sh, in mm
D, PANEL_T, FAN_Y, *PZ = [float(v) / 1000 for v in open(os.path.join(d, "dims.txt")).read().split(",")]
CENTRE = (0, FAN_Y)
PANEL_Z = {"fan_panel": (PZ[0], PZ[1]), "nuc_panel": (PZ[2], PZ[3])}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = samples
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 8
scene.render.resolution_x = res
scene.render.resolution_y = int(res * 0.75)
scene.render.filepath = out
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"


def plastic(name, color, rough, bevel=0.0003, bump=0.0, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metallic
    normal = None
    if bevel:
        bev = nt.nodes.new("ShaderNodeBevel")
        bev.samples = 6
        bev.inputs["Radius"].default_value = bevel
        normal = bev.outputs["Normal"]
    if bump:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 9000
        noise.inputs["Detail"].default_value = 2
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        bp.inputs["Distance"].default_value = 0.00005
        nt.links.new(noise.outputs["Fac"], bp.inputs["Height"])
        if normal:
            nt.links.new(normal, bp.inputs["Normal"])
        normal = bp.outputs["Normal"]
    if normal:
        nt.links.new(normal, b.inputs["Normal"])
    return m


def nodes_for(m):
    nt = m.node_tree
    N, L = nt.nodes, nt.links

    def mnode(op, a, b=None):
        n = N.new("ShaderNodeMath")
        n.operation = op
        for i, v in enumerate([a, b]):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                L.new(v, n.inputs[i])
        return n.outputs[0]

    def vnode(op, a, b=None, scale=None):
        n = N.new("ShaderNodeVectorMath")
        n.operation = op
        for i, v in enumerate([a, b]):
            if v is None:
                continue
            if isinstance(v, tuple):
                n.inputs[i].default_value = v
            else:
                L.new(v, n.inputs[i])
        if scale is not None:
            if isinstance(scale, (int, float)):
                n.inputs["Scale"].default_value = scale
            else:
                L.new(scale, n.inputs["Scale"])
        return n.outputs

    return N, L, mnode, vnode


# light passes straight through for shadow rays, so the inside and the floor behind are lit
def see_through_shadows(m, shader, tint):
    N, L = m.node_tree.nodes, m.node_tree.links
    lp = N.new("ShaderNodeLightPath")
    tr = N.new("ShaderNodeBsdfTransparent")
    tr.inputs["Color"].default_value = (*tint, 1)
    mix = N.new("ShaderNodeMixShader")
    L.new(lp.outputs["Is Shadow Ray"], mix.inputs["Fac"])
    L.new(shader, mix.inputs[1])
    L.new(tr.outputs["BSDF"], mix.inputs[2])
    L.new(mix.outputs["Shader"], N["Material Output"].inputs["Surface"])


# printed translucent PETG: milky, with layer lines along the print direction (object Y)
def translucent(name, color, bed_face=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L, mnode, vnode = nodes_for(m)
    b = N["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.2
    b.inputs["Transmission Weight"].default_value = 0.86
    b.inputs["IOR"].default_value = 1.57
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs[0])
    geo = N.new("ShaderNodeNewGeometry")
    # object space normal, so it works for panels that were laid flat or moved
    vt = N.new("ShaderNodeVectorTransform")
    vt.vector_type = "NORMAL"
    vt.convert_from = "WORLD"
    vt.convert_to = "OBJECT"
    L.new(geo.outputs["Normal"], vt.inputs[0])
    facing = mnode("POWER", mnode("ABSOLUTE", vnode("DOT_PRODUCT", vt.outputs[0], (0, 1, 0))["Value"]), 4)
    # layer lines: a fine ripple across every face that is not a top or bottom layer
    ripple = mnode("MULTIPLY", mnode("ABSOLUTE", mnode("SINE", mnode("MULTIPLY", sep.outputs["Y"], math.pi / 0.2))),
                   mnode("SUBTRACT", 1, facing))
    if bed_face:
        fine = N.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 2500
        flat_tex = mnode("MULTIPLY", mnode("MULTIPLY", fine.outputs["Fac"], 0.35), facing)
    else:
        u = mnode("MULTIPLY", mnode("ADD", sep.outputs["X"], sep.outputs["Z"]), math.pi / (0.42 * math.sqrt(2)))
        flat_tex = mnode("MULTIPLY", mnode("MULTIPLY", mnode("ABSOLUTE", mnode("SINE", u)), 0.3), facing)
    bev = N.new("ShaderNodeBevel")
    bev.samples = 4
    bev.inputs["Radius"].default_value = 0.0003
    bp = N.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 1.0
    bp.inputs["Distance"].default_value = 0.00012
    L.new(mnode("ADD", mnode("MULTIPLY", ripple, 0.35), flat_tex), bp.inputs["Height"])
    L.new(bev.outputs["Normal"], bp.inputs["Normal"])
    L.new(bp.outputs["Normal"], b.inputs["Normal"])
    see_through_shadows(m, b.outputs["BSDF"], [0.45 + 0.45 * c for c in color])
    return m


# gyroid infill inside the thick parts: wavy cloudy sheets, clear in between
def infill(name, color, period=5.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L, mnode, vnode = nodes_for(m)
    b = N["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.6
    b.inputs["Transmission Weight"].default_value = 0.45
    tc = N.new("ShaderNodeTexCoord")
    v = vnode("SCALE", tc.outputs["Object"], scale=2 * math.pi / period)["Vector"]
    sepc = N.new("ShaderNodeSeparateXYZ")
    L.new(vnode("COSINE", v)["Vector"], sepc.inputs[0])
    rot = N.new("ShaderNodeCombineXYZ")
    for i, k in enumerate("YZX"):
        L.new(sepc.outputs[k], rot.inputs[i])
    g = vnode("DOT_PRODUCT", vnode("SINE", v)["Vector"], rot.outputs[0])["Value"]
    wall = mnode("LESS_THAN", mnode("ABSOLUTE", g), 0.3)
    clear = N.new("ShaderNodeBsdfTransparent")
    mix = N.new("ShaderNodeMixShader")
    L.new(wall, mix.inputs["Fac"])
    L.new(clear.outputs["BSDF"], mix.inputs[1])
    L.new(b.outputs["BSDF"], mix.inputs[2])
    see_through_shadows(m, mix.outputs["Shader"], (0.9, 0.9, 0.9))
    return m


def emissive(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0, 0, 0, 1)
    b.inputs["Emission Color"].default_value = (*color, 1)
    b.inputs["Emission Strength"].default_value = strength
    return m


def load(name, mat, matrix):
    bpy.ops.wm.stl_import(filepath=os.path.join(d, name + ".stl"), global_scale=0.001)
    o = bpy.context.selected_objects[0]
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(35))
    me.materials.append(mat)
    o.matrix_world = matrix @ o.matrix_world  # the import leaves the mm to m scale on the object
    return o


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def spin(deg, about=CENTRE):
    return T(about[0], about[1], 0) @ Matrix.Rotation(math.radians(deg), 4, "Z") @ T(-about[0], -about[1], 0)


# a panel lying on the floor, front face up, centred on (x, y)
def flat(name, x, y, yaw):
    z0, z1 = PANEL_Z[name]
    return T(x, y, 0) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ T(0, (z0 + z1) / 2, -(D - PANEL_T)) @ Matrix.Rotation(math.radians(90), 4, "X")


CASE = {"black": ((0.012, 0.012, 0.014), 0.42), "white": ((0.80, 0.80, 0.77), 0.55)}
CLEAR = (0.93, 0.96, 0.98)
shared = {}


def mats(variant):
    if not shared:
        shared.update(
            nuc=plastic("nuc", (0.006, 0.006, 0.007), 0.3, bevel=0.0006),
            metal=plastic("metal", (0.55, 0.56, 0.58), 0.3, bevel=0, metallic=1.0),
            blue=plastic("blue", (0.01, 0.06, 0.45), 0.35, bevel=0),
            dark=plastic("dark", (0.002, 0.002, 0.002), 0.5, bevel=0),
            led=emissive("led", (0.6, 1.0, 0.75), 60),
            beige=plastic("beige", (0.78, 0.69, 0.52), 0.45),
            brown=plastic("brown", (0.15, 0.045, 0.025), 0.4),
            filter=plastic("filter", (0.012, 0.012, 0.012), 0.6),
            mesh=plastic("mesh", (0.03, 0.03, 0.03), 0.8, bevel=0),
        )
    if variant == "clear":
        return translucent("case", CLEAR), translucent("panels", CLEAR, bed_face=True)
    col, rough = CASE[variant]
    m = plastic("case-" + variant, col, rough, bump=0.25)
    return m, m


def case(variant, base=Matrix.Identity(4), mode="closed"):
    cm, pm = mats(variant)
    s = shared
    move = {}
    if mode == "exploded":
        for n in ["fan_frame", "fan_rotor", "filter", "filter_mesh"]:
            move[n] = T(0, 0.150, 0)
        move["filter"] = move["filter_mesh"] = T(0, 0.150, -0.012)
        for n in ["nuc_body", "nuc_metal", "nuc_blue", "nuc_dark", "nuc_led"]:
            move[n] = T(0, 0.150, 0.012)
        move["fan_panel"] = T(0, 0.245, 0)
        move["nuc_panel"] = T(0, 0.245, 0.012)
    if mode == "open":
        move["fan_panel"] = flat("fan_panel", 0.045, 0.215, 14)
        move["nuc_panel"] = flat("nuc_panel", -0.035, 0.275, -9)
    if variant == "clear" and os.environ.get("INFILL", "1") == "1":
        load("core", infill("infill", CLEAR), base)
    parts = [("body", cm), ("fan_panel", pm), ("nuc_panel", pm), ("nuc_body", s["nuc"]), ("nuc_metal", s["metal"]),
             ("nuc_blue", s["blue"]), ("nuc_dark", s["dark"]), ("nuc_led", s["led"]), ("fan_frame", s["beige"]),
             ("fan_rotor", s["brown"]), ("filter", s["filter"]), ("filter_mesh", s["mesh"])]
    for name, mat in parts:
        load(name, mat, base @ move.get(name, Matrix.Identity(4)))


SHOTS = {
    # name: (camera, target, lens, backdrop, light scale, f-stop or None)
    "hero": ((-0.30, 0.60, 0.25), (0, 0.07, 0.047), 85, 0.21, 1.0, None),
    "rear": ((-0.30, 0.60, 0.25), (0, 0.07, 0.047), 85, 0.21, 1.0, None),
    "exploded": ((-0.62, 0.74, 0.40), (0.0, 0.180, 0.05), 64, 0.21, 1.0, None),
    "open": ((-0.34, 0.76, 0.35), (0.0, 0.150, 0.03), 74, 0.21, 1.0, None),
    "detail": ((-0.15, 0.285, 0.125), (-0.028, 0.126, 0.068), 85, 0.21, 1.0, 11),
    "colours": ((0.0, 0.92, 0.33), (0.0, 0.07, 0.045), 85, 0.12, 0.8, None),
}
cam_loc, cam_at, lens, bg, k, fstop = SHOTS[shot]
variant = sys.argv[6] if len(sys.argv) > 6 else "black"
if variant == "clear":
    bg, k = 0.06, 0.42
    scene.cycles.max_bounces = 24
    scene.cycles.transmission_bounces = 24
    scene.cycles.transparent_max_bounces = 24

if shot == "rear":
    case(variant, spin(180))
elif shot == "exploded":
    case(variant, mode="exploded")
elif shot == "open":
    case(variant, mode="open")
elif shot == "colours":
    case("black", T(-0.088, 0, 0) @ spin(14))
    case("white", T(0.088, 0, 0) @ spin(-14))
else:
    case(variant)

# seamless backdrop: floor that curves up into a wall behind the case
prof = [(2.5, 0.0), (-0.45, 0.0)]
r = 0.35
for i in range(1, 17):
    a = math.radians(90 * i / 16)
    prof.append((-0.45 - r * math.sin(a), r - r * math.cos(a)))
prof.append((-0.45 - r, 2.5))
verts = [(x, y, z) for (y, z) in prof for x in (-4, 4)]
faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(len(prof) - 1)]
me = bpy.data.meshes.new("backdrop")
me.from_pydata(verts, [], faces)
for p in me.polygons:
    p.use_smooth = True
back = bpy.data.objects.new("backdrop", me)
scene.collection.objects.link(back)
me.materials.append(plastic("backdrop", (bg, bg * 1.03, bg * 1.1), 0.7, bevel=0))

world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.04
scene.world = world


def empty(name, loc):
    o = bpy.data.objects.new(name, None)
    o.location = loc
    scene.collection.objects.link(o)
    return o


centre = empty("centre", (0, 0.10, 0.047))
look = empty("look", cam_at)


def aim(o, at):
    c = o.constraints.new("TRACK_TO")
    c.target = at
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"


def area(name, loc, size, power, color=(1, 1, 1)):
    l = bpy.data.lights.new(name, "AREA")
    l.shape = "RECTANGLE"
    l.size, l.size_y = size
    l.energy = power * k
    l.color = color
    o = bpy.data.objects.new(name, l)
    o.location = loc
    scene.collection.objects.link(o)
    aim(o, centre)


area("key", (0.45, 0.60, 0.55), (0.5, 0.5), 16, (1.0, 0.97, 0.93))
area("fill", (-0.6, 0.50, 0.2), (0.6, 0.6), 3, (0.9, 0.95, 1.0))
area("rim", (-0.25, -0.5, 0.5), (0.5, 0.3), 14)
area("top", (0.0, 0.15, 0.7), (0.7, 0.7), 5)

cam = bpy.data.cameras.new("cam")
cam.lens = lens
cam.sensor_width = 36
if fstop:
    cam.dof.use_dof = True
    cam.dof.focus_object = look
    cam.dof.aperture_fstop = fstop
co = bpy.data.objects.new("cam", cam)
co.location = cam_loc
scene.collection.objects.link(co)
aim(co, look)
scene.camera = co

bpy.ops.render.render(write_still=True)
