# -*- coding: utf-8 -*-
"""
NIGHTFALL 1984 -- generateur procedurally d'assets 3D originaux (Blender 5.3 headless).

Usage :
    blender -b -P tools/blender/generate_assets.py -- --out assets/models

Produit 6 fichiers GLB 2.0 (metres, Y-up, objets orientes vers -Z apres export) :
    endoskeleton.glb  drone.glb  boss.glb  weapons.glb  props.glb  player_hands.glb

Toutes les geometries sont construites ici, sans asset tiers, sans texture externe
et sans element graphique protege. Reproductible : aucun hasard non seme.
"""

import argparse
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

TAU = math.tau
SEED = 1984

# ---------------------------------------------------------------------------
# Materiaux PBR (noms stables, aucun fichier de texture externe)
# ---------------------------------------------------------------------------

MATERIAL_SPECS = {
    "chrome": dict(base=(0.70, 0.74, 0.78, 1.0), metal=1.0, rough=0.18),
    "dark_steel": dict(base=(0.055, 0.062, 0.070, 1.0), metal=0.88, rough=0.42),
    "brushed_metal": dict(base=(0.40, 0.43, 0.47, 1.0), metal=0.92, rough=0.30),
    "gunmetal": dict(base=(0.14, 0.16, 0.18, 1.0), metal=0.85, rough=0.35),
    "weathered_steel": dict(base=(0.20, 0.21, 0.22, 1.0), metal=0.72, rough=0.62),
    "black_plastic": dict(base=(0.018, 0.020, 0.024, 1.0), metal=0.05, rough=0.55),
    "rubber": dict(base=(0.010, 0.012, 0.014, 1.0), metal=0.0, rough=0.86),
    "tinted_glass": dict(base=(0.010, 0.045, 0.060, 1.0), metal=0.35, rough=0.06),
    "circuit_green": dict(base=(0.015, 0.16, 0.06, 1.0), metal=0.25, rough=0.50),
    "gold": dict(base=(0.65, 0.42, 0.10, 1.0), metal=1.0, rough=0.28),
    "bone_white": dict(base=(0.60, 0.62, 0.63, 1.0), metal=0.10, rough=0.65),
    "warning_red": dict(base=(0.38, 0.012, 0.010, 1.0), metal=0.35, rough=0.42),
    "red_emissive": dict(
        base=(0.30, 0.010, 0.006, 1.0), metal=0.0, rough=0.25,
        emissive=(1.0, 0.015, 0.008, 1.0), strength=1.0,
    ),
    "emissive_cyan": dict(
        base=(0.010, 0.10, 0.12, 1.0), metal=0.0, rough=0.20,
        emissive=(0.00, 0.82, 1.00, 1.0), strength=1.0,
    ),
    "emissive_green": dict(
        base=(0.010, 0.12, 0.030, 1.0), metal=0.0, rough=0.20,
        emissive=(0.10, 1.00, 0.28, 1.0), strength=1.0,
    ),
    "emissive_amber": dict(
        base=(0.16, 0.07, 0.010, 1.0), metal=0.0, rough=0.25,
        emissive=(1.00, 0.42, 0.04, 1.0), strength=1.0,
    ),
}

MATERIALS = {}


def init_scene():
    """Scene vide, unites metriques."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials):
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.unit_settings.length_unit = "METERS"


def init_materials():
    global MATERIALS
    MATERIALS = {}
    for name, spec in MATERIAL_SPECS.items():
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        mat.diffuse_color = spec["base"]
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = spec["base"]
        shader.inputs["Metallic"].default_value = spec["metal"]
        shader.inputs["Roughness"].default_value = spec["rough"]
        if "emissive" in spec:
            shader.inputs["Emission Color"].default_value = spec["emissive"]
            shader.inputs["Emission Strength"].default_value = spec.get("strength", 1.0)
        MATERIALS[name] = mat
    return MATERIALS


# ---------------------------------------------------------------------------
# Builders de maillage : primitatives convexes + torus, pivots explicites
# ---------------------------------------------------------------------------

AXIS_ROT = {
    "X": Matrix.Rotation(math.pi / 2.0, 3, "Y"),
    "Y": Matrix.Rotation(-math.pi / 2.0, 3, "X"),
    "Z": Matrix.Identity(3),
}


def _rotation(rot):
    if rot is None:
        return None
    if isinstance(rot, Matrix):
        return rot
    rx, ry, rz = rot
    return (
        Matrix.Rotation(rx, 3, "X")
        @ Matrix.Rotation(ry, 3, "Y")
        @ Matrix.Rotation(rz, 3, "Z")
    )


def direction_rot(direction):
    """Rotation amenant l'axe local +Z sur `direction`."""
    d = Vector(direction)
    if d.length < 1e-9:
        return Matrix.Identity(3)
    return Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()


class Builder:
    """Accumule des primitives dans un seul maillage, avec indices de materiaux."""

    def __init__(self, name, materials, quality=1.0):
        self.name = name
        self.mat_keys = list(materials)
        self.quality = float(quality)
        self.verts = []
        self.faces = []
        self.mat_ids = []
        self.smooth = []

    def _place(self, verts, center, rot):
        matrix = _rotation(rot)
        out = []
        for p in verts:
            v = Vector(p)
            if matrix is not None:
                v = matrix @ v
            v += Vector(center)
            out.append((v.x, v.y, v.z))
        return out

    def _orient(self, indices):
        a = Vector(self.verts[indices[0]])
        b = Vector(self.verts[indices[1]])
        c = Vector(self.verts[indices[2]])
        normal = (b - a).cross(c - a)
        centroid = sum((Vector(self.verts[i]) for i in indices), Vector()) / len(indices)
        if normal.dot(centroid) < 0.0:
            return tuple(reversed(indices))
        return indices

    def _add(self, verts, faces, material, center=(0, 0, 0), rot=None,
             smooth=True, orient=True):
        if material not in self.mat_keys:
            raise KeyError("Materiau '%s' absent de %s" % (material, self.name))
        mid = self.mat_keys.index(material)
        offset = len(self.verts)
        self.verts.extend(self._place(verts, center, rot))
        for face in faces:
            if len(face) < 3:
                continue
            indices = tuple(offset + i for i in face)
            if orient:
                indices = self._orient(indices)
            self.faces.append(indices)
            self.mat_ids.append(mid)
            self.smooth.append(bool(smooth))

    # -- primitives ---------------------------------------------------------

    def box(self, center, size, material, bevel=0.0, rot=None):
        hx, hy, hz = (float(s) * 0.5 for s in size)
        b = max(0.0, min(float(bevel), hx * 0.7, hy * 0.7, hz * 0.7))
        if b < 1e-5:
            verts = [(sx * hx, sy * hy, sz * hz)
                     for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]

            def ix(sx, sy, sz):
                return (0 if sx < 0 else 1) * 4 + (0 if sy < 0 else 1) * 2 + (0 if sz < 0 else 1)

            faces = [
                tuple(ix(-1, sy, sz) for sy, sz in ((-1, -1), (-1, 1), (1, 1), (1, -1))),
                tuple(ix(1, sy, sz) for sy, sz in ((-1, -1), (-1, 1), (1, 1), (1, -1))),
                tuple(ix(sx, -1, sz) for sx, sz in ((-1, -1), (-1, 1), (1, 1), (1, -1))),
                tuple(ix(sx, 1, sz) for sx, sz in ((-1, -1), (-1, 1), (1, 1), (1, -1))),
                tuple(ix(sx, sy, -1) for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))),
                tuple(ix(sx, sy, 1) for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))),
            ]
        else:
            corner = {}
            verts = []
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (-1, 1):
                        for axis, p in (
                            ("x", (sx * hx, sy * (hy - b), sz * (hz - b))),
                            ("y", (sx * (hx - b), sy * hy, sz * (hz - b))),
                            ("z", (sx * (hx - b), sy * (hy - b), sz * hz)),
                        ):
                            corner[(sx, sy, sz, axis)] = len(verts)
                            verts.append(p)
            faces = []

            def quad(points):
                faces.append(tuple(corner[k] for k in points))

            for sx in (-1, 1):
                quad([(sx, sy, sz, "x") for sy, sz in ((-1, -1), (-1, 1), (1, 1), (1, -1))])
            for sy in (-1, 1):
                quad([(sx, sy, sz, "y") for sx, sz in ((-1, -1), (-1, 1), (1, 1), (1, -1))])
            for sz in (-1, 1):
                quad([(sx, sy, sz, "z") for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))])
            for sy in (-1, 1):
                for sz in (-1, 1):
                    quad([(-1, sy, sz, "y"), (1, sy, sz, "y"),
                          (1, sy, sz, "z"), (-1, sy, sz, "z")])
            for sx in (-1, 1):
                for sz in (-1, 1):
                    quad([(sx, -1, sz, "x"), (sx, 1, sz, "x"),
                          (sx, 1, sz, "z"), (sx, -1, sz, "z")])
            for sx in (-1, 1):
                for sy in (-1, 1):
                    quad([(sx, sy, -1, "x"), (sx, sy, 1, "x"),
                          (sx, sy, 1, "y"), (sx, sy, -1, "y")])
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (-1, 1):
                        faces.append(tuple(corner[(sx, sy, sz, a)] for a in "xyz"))
        self._add(verts, faces, material, center, rot, smooth=False, orient=True)

    def cyl(self, center, radius, depth, material, segments=12, rot=None,
            radius_top=None, smooth=True):
        segments = max(6, int(round(segments * self.quality)))
        top = radius if radius_top is None else radius_top
        half = float(depth) * 0.5
        verts = []
        for z, r in ((-half, radius), (half, top)):
            for i in range(segments):
                a = TAU * i / segments
                verts.append((r * math.cos(a), r * math.sin(a), z))
        faces = []
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((i, j, segments + j, segments + i))
        c0 = len(verts)
        verts.append((0.0, 0.0, -half))
        c1 = len(verts)
        verts.append((0.0, 0.0, half))
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((c0, j, i))
            faces.append((c1, segments + i, segments + j))
        self._add(verts, faces, material, center, rot,
                  smooth=smooth, orient=True)

    def tube(self, a, b, radius, material, segments=10, radius_top=None):
        va, vb = Vector(a), Vector(b)
        d = vb - va
        length = d.length
        if length < 1e-6:
            return
        self.cyl((va + vb) * 0.5, radius, length, material,
                 segments=segments, rot=direction_rot(d), radius_top=radius_top)

    def sphere(self, center, radius, material, segments=12, rings=8,
               scale=(1.0, 1.0, 1.0), rot=None, smooth=True):
        segments = max(6, int(round(segments * self.quality)))
        rings = max(4, int(round(rings * self.quality)))
        sx, sy, sz = scale
        verts = [(0.0, 0.0, radius * sz)]
        for j in range(1, rings):
            phi = math.pi * j / rings
            for i in range(segments):
                theta = TAU * i / segments
                verts.append((radius * sx * math.sin(phi) * math.cos(theta),
                              radius * sy * math.sin(phi) * math.sin(theta),
                              radius * sz * math.cos(phi)))
        bottom = len(verts)
        verts.append((0.0, 0.0, -radius * sz))
        faces = []
        for i in range(segments):
            ni = (i + 1) % segments
            faces.append((0, 1 + i, 1 + ni))
            last = 1 + (rings - 2) * segments
            faces.append((bottom, last + ni, last + i))
        for j in range(rings - 2):
            for i in range(segments):
                ni = (i + 1) % segments
                a = 1 + j * segments + i
                b = 1 + j * segments + ni
                c = 1 + (j + 1) * segments + ni
                d = 1 + (j + 1) * segments + i
                faces.append((a, b, c, d))
        self._add(verts, faces, material, center, rot, smooth=smooth, orient=True)

    def torus(self, center, major, minor, material, major_seg=16, minor_seg=6,
              start=0.0, sweep=TAU, rot=None, smooth=True):
        major_seg = max(6, int(round(major_seg * self.quality)))
        minor_seg = max(4, int(round(minor_seg * self.quality)))
        closed = abs(sweep) >= TAU - 1e-6
        rings = major_seg if closed else major_seg + 1
        verts = []
        for i in range(rings):
            theta = start + sweep * i / major_seg
            for j in range(minor_seg):
                phi = TAU * j / minor_seg
                r = major + minor * math.cos(phi)
                verts.append((r * math.cos(theta), r * math.sin(theta),
                              minor * math.sin(phi)))
        faces = []
        for i in range(major_seg):
            ni = (i + 1) % rings
            for j in range(minor_seg):
                nj = (j + 1) % minor_seg
                face = (i * minor_seg + j, ni * minor_seg + j,
                        ni * minor_seg + nj, i * minor_seg + nj)
                faces.append(face if sweep >= 0 else tuple(reversed(face)))
        self._add(verts, faces, material, center, rot, smooth=smooth, orient=False)

    # -- utilitaires --------------------------------------------------------

    def bolt(self, at, radius=0.008, material="brushed_metal", axis="Z"):
        self.cyl(at, radius, radius * 0.7, material, segments=8, rot=AXIS_ROT[axis], smooth=False)

    def rivet_row(self, a, b, count, radius=0.006, material="brushed_metal"):
        va, vb = Vector(a), Vector(b)
        for i in range(count):
            t = (i + 0.5) / count
            self.sphere(va.lerp(vb, t), radius, material, segments=6, rings=4)

    def finish(self, location=(0.0, 0.0, 0.0)):
        """Cree l'objet Blender ; `location` est le pivot (centre d'articulation)."""
        mesh = bpy.data.meshes.new(self.name + "_mesh")
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        for polygon, mid, smooth in zip(mesh.polygons, self.mat_ids, self.smooth):
            polygon.material_index = mid
            polygon.use_smooth = smooth
        for key in self.mat_keys:
            mesh.materials.append(MATERIALS[key])
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        return obj


def tri_count(obj):
    return sum(len(poly.vertices) - 2 for poly in obj.data.polygons)


def export_group(filename, objects, out_dir):
    """Export GLB 2.0, unite 1 = 1 m, conversion Z-up -> Y-up du plugin officiel."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    filepath = os.path.join(out_dir, filename + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
        export_normals=True,
        export_tangents=False,
        export_texcoords=False,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=False,
        export_draco_mesh_compression_enable=False,
        export_use_gltfpack=False,
    )
    return filepath


# === ASSET BUILDERS ===


def build_endoskeleton():
    """Squelette articule, 1.80 m, 15 objets nommes, pivots = centres articulaires."""
    out = []

    # --- Crane : pivot = articulation du cou (z = 1.55) -------------------
    b = Builder("Head", ["chrome", "dark_steel", "red_emissive",
                         "tinted_glass", "bone_white"])
    b.cyl((0, 0, 0.015), 0.030, 0.100, "dark_steel", 10)
    b.cyl((0, 0, 0.065), 0.038, 0.018, "chrome", 12)
    b.sphere((0, 0.005, 0.150), 0.100, "chrome", 16, 10, scale=(0.95, 1.05, 1.0))
    b.box((0, 0.072, 0.130), (0.150, 0.060, 0.105), "chrome", 0.012)
    b.box((0, 0.066, 0.065), (0.132, 0.090, 0.060), "dark_steel", 0.012)
    b.box((0, 0.070, 0.032), (0.116, 0.078, 0.024), "chrome", 0.008)
    for i in range(6):
        b.box(((i - 2.5) * 0.019, 0.106, 0.058), (0.013, 0.012, 0.022),
              "bone_white", 0.002)
    for s in (-1, 1):
        b.cyl((0.040 * s, 0.081, 0.165), 0.026, 0.014, "dark_steel", 12,
              rot=AXIS_ROT["Y"])
        b.sphere((0.040 * s, 0.093, 0.165), 0.016, "red_emissive", 12, 8)
        b.cyl((0.100 * s, 0.000, 0.120), 0.028, 0.018, "chrome", 12,
              rot=AXIS_ROT["X"])
        for k in range(3):
            b.box((0.087 * s, -0.020 + k * 0.020, 0.185),
                  (0.010, 0.012, 0.030), "dark_steel", 0.002)
    b.box((0, 0.100, 0.192), (0.165, 0.038, 0.020), "chrome", 0.006)
    b.box((0, 0.000, 0.238), (0.012, 0.190, 0.012), "dark_steel", 0.003)
    b.cyl((0, -0.060, 0.120), 0.022, 0.030, "tinted_glass", 10, rot=AXIS_ROT["Y"])
    out.append(b.finish((0.0, 0.0, 1.550)))

    # --- Torse : pivot = articulation lombaire (z = 1.08) ----------------
    b = Builder("Torso", ["chrome", "dark_steel", "brushed_metal",
                          "gunmetal", "red_emissive"])
    for i in range(6):
        z = 0.018 + i * 0.061
        b.cyl((0, -0.055, z), 0.029, 0.045, "dark_steel", 10)
        b.cyl((0, -0.055, z + 0.028), 0.036, 0.012, "chrome", 10)
    b.box((0, -0.010, 0.205), (0.210, 0.150, 0.280), "dark_steel", 0.030)
    for i in range(5):
        z = 0.100 + i * 0.050
        major = 0.113 + i * 0.011
        b.torus((0, 0.000, z), major, 0.008, "chrome", 14, 5,
                start=-math.pi / 2.0, sweep=math.pi)
        b.torus((0, 0.000, z), major, 0.008, "chrome", 14, 5,
                start=-math.pi / 2.0, sweep=-math.pi)
    b.box((0, 0.148, 0.205), (0.036, 0.026, 0.240), "chrome", 0.008)
    for s in (-1, 1):
        b.box((0.086 * s, 0.072, 0.275), (0.140, 0.055, 0.145),
              "brushed_metal", 0.015, rot=(0, 0.10 * s, 0))
        b.tube((0.140 * s, -0.060, 0.030), (0.190 * s, 0.055, 0.280),
               0.013, "chrome", 10)
        b.tube((0.150 * s, -0.050, 0.120), (0.180 * s, 0.045, 0.230),
               0.019, "dark_steel", 10)
        b.sphere((0.236 * s, 0, 0.400), 0.047, "chrome", 14, 9)
        b.cyl((0.245 * s, 0, 0.400), 0.056, 0.052, "dark_steel", 12,
              rot=AXIS_ROT["X"])
        b.bolt((0.190 * s, 0.075, 0.295), 0.010, "brushed_metal", "Y")
    b.box((0, -0.124, 0.200), (0.230, 0.036, 0.300), "gunmetal", 0.020)
    for k in range(5):
        b.box((0, -0.146, 0.110 + k * 0.048), (0.170, 0.010, 0.018), "dark_steel")
    b.cyl((0, 0, 0.425), 0.030, 0.060, "dark_steel", 12)
    b.sphere((0, 0.169, 0.218), 0.013, "red_emissive", 10, 7)
    b.tube((0.050, -0.080, 0.010), (0.050, -0.080, 0.380), 0.009, "rubber"
           if "rubber" in b.mat_keys else "dark_steel", 8)
    out.append(b.finish((0.0, 0.0, 1.080)))

    # --- Bassin : pivot = centre du bassin (z = 0.94) ---------------------
    b = Builder("Pelvis", ["chrome", "dark_steel", "brushed_metal", "gunmetal"])
    b.box((0, 0, 0), (0.260, 0.175, 0.160), "dark_steel", 0.026)
    for s in (-1, 1):
        b.box((0.130 * s, 0.000, 0.035), (0.100, 0.165, 0.120),
              "chrome", 0.018, rot=(0, 0.18 * s, 0.10 * s))
        b.sphere((0.105 * s, 0, -0.020), 0.046, "chrome", 14, 9)
        b.cyl((0.128 * s, 0, -0.020), 0.034, 0.025, "dark_steel", 12,
              rot=AXIS_ROT["X"])
        b.tube((0.075 * s, -0.065, -0.055), (0.110 * s, 0.060, 0.070),
               0.012, "brushed_metal", 8)
        b.bolt((0.150 * s, 0.070, 0.060), 0.009)
    b.cyl((0, -0.030, 0.105), 0.046, 0.145, "gunmetal", 12)
    b.box((0, 0.088, -0.020), (0.180, 0.030, 0.075), "gunmetal", 0.010)
    out.append(b.finish((0.0, 0.0, 0.940)))

    # --- Membres ----------------------------------------------------------
    for side, s in (("L", -1), ("R", 1)):
        b = Builder("UpperArm_" + side,
                    ["chrome", "dark_steel", "brushed_metal", "gunmetal"])
        b.sphere((0, 0, 0), 0.046, "chrome", 14, 9)
        b.tube((0, 0, -0.015), (0.012 * s, 0, -0.290), 0.029, "chrome", 12)
        b.tube((0, 0, -0.080), (0.012 * s, 0, -0.225), 0.036, "dark_steel", 12)
        b.box((0.012 * s, 0.012, -0.150), (0.078, 0.074, 0.190),
              "brushed_metal", 0.013, rot=(0, 0.06 * s, 0))
        b.tube((0.045 * s, -0.012, -0.030), (0.050 * s, -0.012, -0.270),
               0.010, "chrome", 8)
        b.tube((0.025 * s, 0.032, -0.050), (0.028 * s, 0.030, -0.250),
               0.008, "gunmetal", 8)
        b.sphere((0.012 * s, 0, -0.300), 0.036, "chrome", 12, 8)
        b.rivet_row((0.040 * s, 0.050, -0.090), (0.045 * s, 0.050, -0.215), 3)
        out.append(b.finish((0.235 * s, 0.0, 1.480)))

        b = Builder("LowerArm_" + side,
                    ["chrome", "dark_steel", "brushed_metal", "gunmetal"])
        b.sphere((0, 0, 0), 0.036, "chrome", 12, 8)
        b.tube((0, 0, -0.010), (0, 0, -0.260), 0.025, "chrome", 12)
        b.tube((0.034 * s, 0.004, -0.020), (0.032 * s, 0.004, -0.255),
               0.014, "dark_steel", 8)
        b.box((0.006 * s, 0.014, -0.130), (0.076, 0.076, 0.180),
              "brushed_metal", 0.012)
        b.box((0, -0.038, -0.140), (0.050, 0.022, 0.150), "gunmetal", 0.008)
        b.sphere((0, 0, -0.280), 0.028, "chrome", 12, 8)
        b.tube((0.020 * s, -0.030, -0.040), (0.020 * s, -0.030, -0.240),
               0.006, "gunmetal", 8)
        out.append(b.finish((0.247 * s, 0.0, 1.180)))

        b = Builder("Hand_" + side, ["chrome", "dark_steel", "brushed_metal"])
        b.sphere((0, 0, 0), 0.027, "chrome", 12, 8)
        b.box((0, 0, -0.046), (0.072, 0.052, 0.090), "chrome", 0.010)
        b.box((0, 0.020, -0.090), (0.076, 0.046, 0.018), "dark_steel", 0.005)
        for i in range(4):
            x = (i - 1.5) * 0.018
            a = (x, 0.008, -0.098)
            m = (x, 0.032, -0.132)
            t = (x, 0.020, -0.166)
            b.tube(a, m, 0.010, "chrome", 8)
            b.tube(m, t, 0.008, "brushed_metal", 8)
            b.sphere(m, 0.010, "dark_steel", 8, 6)
        b.tube((0.043 * s, 0, -0.048), (0.056 * s, 0.046, -0.104),
               0.012, "chrome", 8)
        out.append(b.finish((0.247 * s, 0.0, 0.900)))

        b = Builder("UpperLeg_" + side,
                    ["chrome", "dark_steel", "brushed_metal", "gunmetal"])
        b.sphere((0, 0, 0), 0.050, "chrome", 14, 9)
        b.tube((0, 0, -0.010), (0, 0, -0.440), 0.041, "chrome", 12)
        b.box((0, 0.010, -0.220), (0.104, 0.108, 0.300),
              "brushed_metal", 0.018, rot=(0, 0.04 * s, 0))
        b.tube((0.058 * s, -0.030, -0.060), (0.058 * s, -0.030, -0.370),
               0.013, "gunmetal", 8)
        b.tube((0.044 * s, 0.055, -0.080), (0.044 * s, 0.055, -0.350),
               0.010, "chrome", 8)
        b.sphere((0, 0, -0.440), 0.046, "chrome", 14, 9)
        b.bolt((0.048 * s, 0.065, -0.270), 0.010)
        out.append(b.finish((0.105 * s, 0.0, 0.920)))

        b = Builder("LowerLeg_" + side,
                    ["chrome", "dark_steel", "brushed_metal", "gunmetal"])
        b.sphere((0, 0, 0), 0.045, "chrome", 14, 9)
        b.tube((0, 0, -0.010), (0, 0, -0.400), 0.034, "chrome", 12)
        b.box((0, 0.014, -0.190), (0.090, 0.092, 0.300),
              "brushed_metal", 0.015)
        b.tube((0, -0.048, -0.050), (0, -0.048, -0.350), 0.012, "gunmetal", 8)
        b.tube((0.050 * s, 0, -0.060), (0.050 * s, 0, -0.330), 0.009, "chrome", 8)
        b.sphere((0, 0, -0.420), 0.031, "chrome", 12, 8)
        out.append(b.finish((0.108 * s, 0.0, 0.480)))

        b = Builder("Foot_" + side,
                    ["chrome", "dark_steel", "gunmetal", "rubber"])
        b.sphere((0, 0, 0), 0.031, "chrome", 12, 8)
        b.box((0, -0.042, -0.026), (0.096, 0.112, 0.056), "dark_steel", 0.010)
        b.box((0, 0.055, -0.035), (0.102, 0.220, 0.046), "gunmetal", 0.012)
        b.box((0, 0.055, -0.054), (0.106, 0.226, 0.012), "rubber", 0.004)
        for k in range(3):
            b.box(((k - 1) * 0.032, 0.185, -0.040), (0.029, 0.062, 0.028),
                  "chrome", 0.006)
        b.box((0.050 * s, -0.010, -0.020), (0.010, 0.110, 0.060), "chrome", 0.004)
        out.append(b.finish((0.108 * s, 0.0, 0.060)))

    return out


def build_drone():
    """Sentinelle volante ~0.8 m, pivot = centre geometrique."""
    b = Builder("Drone", ["chrome", "dark_steel", "brushed_metal", "gunmetal",
                          "black_plastic", "tinted_glass", "red_emissive"],
                quality=1.45)
    b.box((0, 0, 0), (0.270, 0.320, 0.180), "gunmetal", 0.035)
    b.sphere((0, 0, -0.010), 0.145, "dark_steel", 16, 10, scale=(1.05, 1.15, 0.85))
    b.box((0, -0.020, 0.080), (0.200, 0.220, 0.030), "brushed_metal", 0.010)
    b.cyl((0, 0.170, 0.005), 0.056, 0.050, "chrome", 16, rot=AXIS_ROT["Y"])
    b.cyl((0, 0.199, 0.005), 0.042, 0.014, "black_plastic", 16, rot=AXIS_ROT["Y"])
    b.sphere((0, 0.209, 0.005), 0.028, "red_emissive", 14, 9)
    b.torus((0, 0.183, 0.005), 0.049, 0.006, "chrome", 16, 6, rot=AXIS_ROT["Y"])
    b.sphere((0, 0, 0.070), 0.110, "tinted_glass", 16, 10,
             scale=(1.05, 1.20, 0.55))
    b.cyl((0, 0, -0.112), 0.042, 0.018, "tinted_glass", 14)
    for s in (-1, 1):
        b.box((0.140 * s, 0.000, 0.020), (0.008, 0.150, 0.014), "red_emissive", 0.003)
        for k in range(3):
            b.box((0.138 * s, -0.060 + k * 0.060, -0.055),
                  (0.010, 0.030, 0.020), "brushed_metal", 0.003)
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = (0.100 * sx, 0.100 * sy, 0.000)
            c = (0.330 * sx, 0.330 * sy, 0.015)
            b.tube(a, c, 0.017, "chrome", 10)
            b.tube(a, c, 0.023, "dark_steel", 10, )
            b.torus(c, 0.072, 0.010, "dark_steel", 18, 6)
            b.cyl(c, 0.024, 0.034, "chrome", 12)
            for angle in (0.0, math.pi / 2.0):
                b.box((c[0], c[1], 0.026), (0.128, 0.020, 0.006),
                      "brushed_metal", 0.003, rot=(0, 0, angle))
            b.sphere((c[0], c[1], 0.038), 0.012, "red_emissive", 8, 6)
    b.tube((0, -0.020, 0.110), (0.020, -0.020, 0.250), 0.005, "dark_steel", 8)
    b.sphere((0.020, -0.020, 0.255), 0.012, "red_emissive", 8, 6)
    return [b.finish((0.0, 0.0, 0.0))]


def build_boss():
    """Gardien geant 4.2 m, pivot = base (sol), cible WeakPoint separee."""
    b = Builder("Boss", ["chrome", "dark_steel", "brushed_metal", "gunmetal",
                         "weathered_steel", "black_plastic", "red_emissive",
                         "emissive_cyan", "tinted_glass"], quality=1.9)
    for s in (-1, 1):
        x = 0.380 * s
        # Pied, jambe, cuisse
        b.box((x, 0.140, 0.105), (0.470, 0.640, 0.210), "gunmetal", 0.045)
        b.box((x, 0.310, 0.065), (0.380, 0.180, 0.090), "chrome", 0.020)
        for k in range(3):
            b.box((x + (k - 1) * 0.130, 0.415, 0.070), (0.110, 0.120, 0.095),
                  "brushed_metal", 0.014)
        b.tube((x, 0.000, 0.190), (x, 0.000, 1.020), 0.175, "dark_steel", 16,
               radius_top=0.140)
        b.box((x, 0.165, 0.620), (0.350, 0.110, 0.720), "chrome", 0.040,
              rot=(0.05, 0, 0))
        b.tube((x + 0.175 * s, -0.100, 0.280), (x + 0.150 * s, -0.100, 0.900),
               0.045, "brushed_metal", 10)
        b.sphere((x, 0.000, 1.080), 0.190, "chrome", 18, 12)
        b.tube((x, 0.000, 1.100), (x, 0.000, 1.940), 0.205, "dark_steel", 16,
               radius_top=0.165)
        b.box((x, 0.150, 1.540), (0.400, 0.150, 0.720), "brushed_metal", 0.050)
        b.tube((x + 0.200 * s, -0.120, 1.200), (x + 0.170 * s, -0.120, 1.820),
               0.050, "chrome", 10)
        b.box((x, -0.155, 1.520), (0.250, 0.050, 0.520), "gunmetal", 0.018)
        for k in range(4):
            b.box((x, -0.185, 1.320 + k * 0.130), (0.180, 0.012, 0.045),
                  "black_plastic", 0.004)

    # Bassin et torse
    b.box((0, 0.000, 2.050), (1.020, 0.580, 0.460), "dark_steel", 0.070)
    for s in (-1, 1):
        b.box((0.470 * s, 0.010, 2.040), (0.240, 0.520, 0.400), "chrome", 0.040,
              rot=(0, 0.12 * s, 0))
        b.sphere((0.390 * s, 0.000, 2.020), 0.170, "chrome", 14, 9)
    b.box((0, 0.000, 2.730), (1.320, 0.680, 1.180), "gunmetal", 0.090)
    b.box((0, 0.010, 2.260), (0.880, 0.470, 0.400), "dark_steel", 0.050)
    b.box((0, -0.340, 2.750), (1.000, 0.070, 0.900), "weathered_steel", 0.030)
    for k in range(6):
        b.box((0, -0.385, 2.450 + k * 0.120), (0.780, 0.014, 0.055),
              "black_plastic", 0.004)
    for s in (-1, 1):
        b.box((0.415 * s, 0.315, 2.930), (0.480, 0.150, 0.640),
              "chrome", 0.055, rot=(0, 0.13 * s, 0))
        b.box((0.620 * s, 0.180, 3.240), (0.360, 0.120, 0.280),
              "brushed_metal", 0.030)
        b.box((0.415 * s, 0.400, 2.720), (0.420, 0.020, 0.060),
              "red_emissive", 0.006)
        b.tube((0.330 * s, -0.220, 2.300), (0.330 * s, -0.220, 3.200),
               0.045, "rubber" if "rubber" in b.mat_keys else "black_plastic", 10)
        for k in range(4):
            b.bolt((0.560 * s, 0.395, 2.690 + k * 0.150), 0.022,
                   "brushed_metal", "Y")

    # Coeur d'energie
    b.box((0, 0.325, 2.905), (0.400, 0.190, 0.470), "dark_steel", 0.040)
    b.torus((0, 0.435, 2.905), 0.185, 0.026, "chrome", 24, 8, rot=AXIS_ROT["Y"])
    b.sphere((0, 0.430, 2.905), 0.130, "emissive_cyan", 18, 12)
    b.torus((0, 0.435, 2.905), 0.075, 0.012, "red_emissive", 18, 6,
            rot=AXIS_ROT["Y"])
    b.cyl((0, 0.435, 2.905), 0.040, 0.380, "dark_steel", 16, rot=AXIS_ROT["Y"])

    # Epaules, bras, canons
    for s in (-1, 1):
        x = 0.880 * s
        b.box((x, 0.000, 3.280), (0.620, 0.680, 0.540), "chrome", 0.070)
        b.box((x, 0.010, 3.500), (0.540, 0.620, 0.110), "brushed_metal", 0.025)
        for k in range(3):
            b.box((x + 0.080 * s, -0.250 + k * 0.120, 3.570),
                  (0.380, 0.060, 0.090), "dark_steel", 0.012)
        b.tube((x, 0.000, 3.240), (1.050 * s, 0.000, 2.650), 0.140,
               "dark_steel", 14)
        b.sphere((1.050 * s, 0.000, 2.650), 0.155, "chrome", 14, 9)
        b.box((1.050 * s, 0.200, 2.620), (0.390, 0.740, 0.390),
              "gunmetal", 0.045)
        b.box((1.050 * s, 0.200, 2.830), (0.330, 0.600, 0.060),
              "brushed_metal", 0.015)
        b.box((1.050 * s, 0.360, 2.620), (0.020, 0.400, 0.180),
              "red_emissive", 0.004)
        b.tube((1.050 * s, 0.520, 2.620), (1.050 * s, 1.020, 2.620),
               0.105, "chrome", 16)
        b.tube((1.050 * s, 0.560, 2.620), (1.050 * s, 0.980, 2.620),
               0.068, "dark_steel", 14)
        b.torus((1.050 * s, 1.020, 2.620), 0.100, 0.020, "dark_steel", 18, 6,
                rot=AXIS_ROT["Y"])
        b.cyl((1.050 * s, 1.005, 2.620), 0.055, 0.010, "emissive_cyan", 14,
              rot=AXIS_ROT["Y"])
        for k in range(3):
            b.torus((1.050 * s, 0.680 + k * 0.100, 2.620), 0.110, 0.010,
                    "brushed_metal", 16, 6, rot=AXIS_ROT["Y"])

    # Tete et crete (sommet a 4.20 m)
    b.cyl((0, 0.000, 3.480), 0.180, 0.160, "dark_steel", 16)
    b.box((0, 0.020, 3.750), (0.460, 0.460, 0.400), "chrome", 0.060)
    b.box((0, 0.235, 3.740), (0.370, 0.100, 0.240), "dark_steel", 0.025)
    for s in (-1, 1):
        b.sphere((0.115 * s, 0.285, 3.790), 0.038, "red_emissive", 12, 8)
        b.box((0.195 * s, 0.000, 3.700), (0.070, 0.300, 0.220),
              "brushed_metal", 0.018)
    b.box((0, 0.250, 3.625), (0.330, 0.100, 0.090), "gunmetal", 0.015)
    b.box((0, -0.010, 3.960), (0.120, 0.340, 0.380), "dark_steel", 0.020)
    b.box((0, -0.010, 4.080), (0.060, 0.240, 0.180), "chrome", 0.012)
    b.tube((0, -0.020, 4.100), (0, -0.020, 4.190), 0.008, "dark_steel", 8)
    b.sphere((0, -0.020, 4.195), 0.014, "red_emissive", 8, 6)

    # Details de surface : lignes de panneaux, rivets, gaines, ailettes
    for s in (-1, 1):
        for k in range(7):
            z = 2.360 + k * 0.125
            b.box((0.545 * s, 0.400, z), (0.022, 0.012, 0.065),
                  "dark_steel", 0.003)
            b.bolt((0.505 * s, 0.412, z + 0.045), 0.014,
                   "brushed_metal", "Y")
            b.box((0.545 * s, -0.365, z), (0.022, 0.012, 0.065),
                  "dark_steel", 0.003)
        for k in range(8):
            z = 1.180 + k * 0.105
            b.box((0.380 * s, 0.228, z), (0.250, 0.010, 0.018),
                  "black_plastic", 0.002)
        for k in range(4):
            y = -0.260 + k * 0.055
            b.box((0.910 * s, y, 3.570), (0.420, 0.026, 0.070),
                  "dark_steel", 0.006)
        b.tube((0.800 * s, -0.280, 3.260), (1.030 * s, -0.250, 2.700),
               0.024, "black_plastic", 12)
        b.tube((0.560 * s, -0.330, 2.350), (0.350 * s, -0.330, 3.180),
               0.028, "black_plastic", 12)
        b.tube((0.180 * s, -0.380, 2.350), (0.180 * s, -0.380, 3.150),
               0.034, "dark_steel", 12)
        for k in range(5):
            b.box((0.150 * s, -0.400, 2.420 + k * 0.140),
                  (0.090, 0.010, 0.040), "brushed_metal", 0.003)
        for k in range(4):
            b.bolt((0.240 * s, 0.410, 2.540 + k * 0.190), 0.018,
                   "brushed_metal", "Y")
    out = [b.finish((0.0, 0.0, 0.0))]

    # Cible faible : pivot au centre de la sphere
    wp = Builder("WeakPoint", ["red_emissive", "chrome"])
    wp.sphere((0, 0, 0), 0.078, "red_emissive", 18, 12)
    wp.torus((0, 0, 0), 0.095, 0.010, "chrome", 18, 6, rot=AXIS_ROT["Y"])
    out.append(wp.finish((0.0, 0.520, 2.905)))
    return out


def build_weapons():
    """Trois armes originales, pivot = poignee, canon vers +Y Blender (-Z glTF)."""
    out = []

    # --- Pistolet compact --------------------------------------------------
    b = Builder("Pistol", ["chrome", "dark_steel", "brushed_metal",
                           "gunmetal", "black_plastic", "rubber",
                           "red_emissive"], quality=1.45)
    b.box((0, 0.000, -0.070), (0.052, 0.075, 0.150), "black_plastic", 0.010,
          rot=(-0.18, 0, 0))
    for s in (-1, 1):
        b.box((0.028 * s, -0.005, -0.070), (0.008, 0.055, 0.110), "rubber", 0.004,
              rot=(-0.18, 0, 0))
    b.box((0, 0.090, 0.005), (0.062, 0.225, 0.085), "gunmetal", 0.014)
    b.box((0, 0.100, 0.047), (0.068, 0.235, 0.045), "chrome", 0.010)
    for k in range(7):
        b.box((0, -0.005 + k * 0.012, 0.070), (0.058, 0.004, 0.010),
              "dark_steel", 0.001)
    b.cyl((0, 0.220, 0.005), 0.016, 0.055, "dark_steel", 12, rot=AXIS_ROT["Y"])
    b.torus((0, 0.245, 0.005), 0.016, 0.005, "chrome", 12, 6, rot=AXIS_ROT["Y"])
    b.torus((0, -0.020, -0.035), 0.036, 0.006, "brushed_metal", 14, 6,
            rot=AXIS_ROT["X"])
    b.box((0, -0.005, -0.030), (0.012, 0.012, 0.045), "chrome", 0.003)
    b.sphere((0, 0.205, 0.078), 0.008, "red_emissive", 8, 6)
    b.bolt((0.035, 0.170, 0.020), 0.006, "brushed_metal", "X")
    out.append(b.finish((0.0, 0.0, 0.0)))

    # --- Fusil a plasma ----------------------------------------------------
    b = Builder("Rifle", ["chrome", "dark_steel", "brushed_metal", "gunmetal",
                          "black_plastic", "rubber", "emissive_cyan",
                          "tinted_glass"], quality=1.45)
    b.box((0, 0.050, 0.000), (0.078, 0.430, 0.110), "gunmetal", 0.018)
    b.box((0, -0.255, -0.020), (0.075, 0.260, 0.130), "black_plastic", 0.022)
    b.box((0, -0.080, -0.120), (0.060, 0.075, 0.155), "black_plastic", 0.012,
          rot=(-0.20, 0, 0))
    b.torus((0, -0.060, -0.055), 0.045, 0.006, "brushed_metal", 14, 6,
            rot=AXIS_ROT["X"])
    b.box((0, -0.020, -0.115), (0.075, 0.185, 0.090), "dark_steel", 0.012)
    for k in range(3):
        b.box((0, -0.080 + k * 0.055, -0.162), (0.055, 0.035, 0.010),
              "emissive_cyan", 0.003)
    b.tube((0, 0.250, 0.005), (0, 0.640, 0.005), 0.026, "chrome", 14)
    b.tube((0, 0.270, 0.005), (0, 0.610, 0.005), 0.017, "dark_steel", 12)
    for k in range(6):
        b.torus((0, 0.290 + k * 0.058, 0.005), 0.031, 0.005,
                "brushed_metal", 14, 6, rot=AXIS_ROT["Y"])
    b.cyl((0, 0.645, 0.005), 0.040, 0.045, "dark_steel", 16, rot=AXIS_ROT["Y"])
    b.cyl((0, 0.670, 0.005), 0.028, 0.008, "emissive_cyan", 14, rot=AXIS_ROT["Y"])
    b.box((0, 0.060, 0.105), (0.095, 0.020, 0.012), "brushed_metal", 0.003)
    b.cyl((0, 0.045, 0.135), 0.030, 0.150, "dark_steel", 14, rot=AXIS_ROT["Y"])
    b.cyl((0, 0.123, 0.135), 0.024, 0.006, "tinted_glass", 14, rot=AXIS_ROT["Y"])
    for s in (-1, 1):
        b.box((0.046 * s, 0.000, -0.030), (0.010, 0.340, 0.060),
              "brushed_metal", 0.005)
    out.append(b.finish((0.0, 0.0, 0.0)))

    # --- Pistolet a retrecissement ----------------------------------------
    b = Builder("ShrinkRay", ["chrome", "dark_steel", "brushed_metal",
                              "gunmetal", "black_plastic", "gold",
                              "emissive_green", "tinted_glass"], quality=1.45)
    coil = "gold"
    b.box((0, 0.050, 0.000), (0.085, 0.270, 0.120), "chrome", 0.022)
    b.box((0, -0.055, -0.115), (0.060, 0.075, 0.150), "black_plastic", 0.012,
          rot=(-0.20, 0, 0))
    b.torus((0, -0.035, -0.050), 0.044, 0.006, "brushed_metal", 14, 6,
            rot=AXIS_ROT["X"])
    b.box((0, 0.030, -0.075), (0.070, 0.170, 0.080), "dark_steel", 0.012)
    for k in range(3):
        b.box((0, -0.020 + k * 0.050, -0.118), (0.052, 0.030, 0.008),
              "emissive_green", 0.002)
    b.tube((0, 0.185, 0.005), (0, 0.440, 0.005), 0.028, "dark_steel", 12)
    for k in range(5):
        y = 0.200 + k * 0.055
        b.torus((0, y, 0.005), 0.055, 0.011, coil, 18, 7, rot=AXIS_ROT["Y"])
        b.torus((0, y + 0.012, 0.005), 0.040, 0.005, "emissive_green", 14, 6,
                rot=AXIS_ROT["Y"])
    b.torus((0, 0.445, 0.005), 0.062, 0.014, "chrome", 18, 7, rot=AXIS_ROT["Y"])
    b.sphere((0, 0.462, 0.005), 0.048, "emissive_green", 16, 11)
    b.torus((0, 0.462, 0.005), 0.052, 0.006, "tinted_glass", 16, 6,
            rot=AXIS_ROT["Y"])
    b.cyl((0, 0.000, 0.085), 0.034, 0.016, "dark_steel", 16, rot=AXIS_ROT["Z"])
    b.box((0, 0.000, 0.093), (0.050, 0.008, 0.006), "emissive_green", 0.002)
    for s in (-1, 1):
        b.box((0.048 * s, 0.070, 0.020), (0.008, 0.180, 0.055),
              "brushed_metal", 0.004)
    out.append(b.finish((0.0, 0.0, 0.0)))
    return out


def build_props():
    """16 accessoires d'environnement, noms exacts, petits details PBR."""
    out = []

    # 1. Caisse (pivot base)
    b = Builder("Crate", ["weathered_steel", "dark_steel", "brushed_metal",
                          "warning_red"])
    b.box((0, 0, 0.300), (0.620, 0.620, 0.600), "weathered_steel", 0.028)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((0.275 * sx, 0.275 * sy, 0.300), (0.070, 0.070, 0.600),
                  "dark_steel", 0.010)
    for z in (0.080, 0.300, 0.520):
        for y in (-0.315, 0.315):
            b.box((0, y, z), (0.560, 0.014, 0.050), "brushed_metal", 0.004)
        for x in (-0.315, 0.315):
            b.box((x, 0, z), (0.014, 0.560, 0.050), "brushed_metal", 0.004)
    for sx in (-1, 1):
        b.torus((0.325 * sx, 0, 0.300), 0.060, 0.010, "dark_steel", 14, 6,
                rot=AXIS_ROT["X"])
    b.box((0, 0.322, 0.520), (0.180, 0.010, 0.035), "warning_red", 0.003)
    b.rivet_row((-0.240, 0.325, 0.270), (0.240, 0.325, 0.270), 7)
    out.append(b.finish((0, 0, 0)))

    # 2. Fut (pivot base)
    b = Builder("Barrel", ["gunmetal", "dark_steel", "brushed_metal",
                           "warning_red", "rubber"])
    b.cyl((0, 0, 0.450), 0.180, 0.900, "gunmetal", 20)
    for z in (0.050, 0.300, 0.620, 0.850):
        b.torus((0, 0, z), 0.181, 0.018, "dark_steel", 20, 7)
    b.torus((0, 0, 0.460), 0.184, 0.026, "warning_red", 20, 7)
    b.cyl((0, 0, 0.905), 0.166, 0.018, "dark_steel", 20)
    b.cyl((0, 0, 0.916), 0.130, 0.006, "brushed_metal", 16)
    b.cyl((0, 0, 0.005), 0.170, 0.012, "rubber", 18)
    for k in range(8):
        a = TAU * k / 8
        b.sphere((0.181 * math.cos(a), 0.181 * math.sin(a), 0.300),
                 0.014, "brushed_metal", 8, 6)
    out.append(b.finish((0, 0, 0)))

    # 3. Console (pivot base)
    b = Builder("Console", ["gunmetal", "dark_steel", "brushed_metal",
                            "black_plastic", "emissive_cyan", "red_emissive"])
    b.box((0, 0, 0.060), (0.900, 0.600, 0.120), "dark_steel", 0.020)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((0.390 * sx, 0.250 * sy, 0.330), (0.060, 0.060, 0.560),
                  "gunmetal", 0.008)
    b.box((0, 0.000, 0.680), (0.880, 0.580, 0.090), "gunmetal", 0.025,
          rot=(-0.32, 0, 0))
    b.box((0, 0.145, 0.740), (0.520, 0.030, 0.300), "black_plastic", 0.010,
          rot=(-0.32, 0, 0))
    b.box((0, 0.163, 0.742), (0.470, 0.008, 0.255), "emissive_cyan", 0.002,
          rot=(-0.32, 0, 0))
    for row in range(2):
        for col in range(7):
            b.cyl((-0.240 + col * 0.080, 0.250 + row * 0.060, 0.560 - row * 0.045),
                  0.014, 0.012, "brushed_metal", 10, rot=AXIS_ROT["Y"])
    b.cyl((0.360, 0.250, 0.560), 0.030, 0.016, "red_emissive", 12,
          rot=AXIS_ROT["Y"])
    for sx in (-1, 1):
        for k in range(5):
            b.box((0.430 * sx, -0.260 + k * 0.045, 0.240),
                  (0.010, 0.020, 0.240), "black_plastic", 0.003)
    out.append(b.finish((0, 0, 0)))

    # 4. Ecran (pivot base)
    b = Builder("Monitor", ["gunmetal", "dark_steel", "brushed_metal",
                            "black_plastic", "emissive_cyan", "tinted_glass"])
    b.cyl((0, 0, 0.040), 0.150, 0.050, "dark_steel", 16)
    b.box((0, 0, 0.010), (0.340, 0.300, 0.020), "gunmetal", 0.008)
    b.box((0, 0.000, 0.350), (0.540, 0.360, 0.460), "gunmetal", 0.040)
    b.box((0, 0.180, 0.360), (0.470, 0.050, 0.390), "dark_steel", 0.018)
    b.box((0, 0.208, 0.360), (0.410, 0.008, 0.330), "emissive_cyan", 0.002)
    for sx in (-1, 1):
        b.box((0.245 * sx, 0.205, 0.360), (0.018, 0.010, 0.350), "tinted_glass", 0.003)
    b.cyl((0.215, 0.205, 0.155), 0.018, 0.015, "brushed_metal", 12,
          rot=AXIS_ROT["Y"])
    for k in range(6):
        b.box((0, -0.190, 0.200 + k * 0.050), (0.400, 0.012, 0.020),
              "black_plastic", 0.003)
    out.append(b.finish((0, 0, 0)))

    # 5. Grille de ventilation (pivot centre, face avant +Y)
    b = Builder("VentGrate", ["dark_steel", "brushed_metal", "black_plastic",
                              "warning_red"])
    b.box((0, 0, 0), (0.620, 0.060, 0.420), "dark_steel", 0.012)
    b.box((0, 0.035, 0), (0.550, 0.010, 0.350), "black_plastic", 0.004)
    for k in range(9):
        b.box((0, 0.052, -0.153 + k * 0.038), (0.540, 0.016, 0.020),
              "brushed_metal", 0.003, rot=(0.38, 0, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.cyl((0.275 * sx, 0.038, 0.178 * sz), 0.012, 0.008,
                  "brushed_metal", 8, rot=AXIS_ROT["Y"])
    b.box((0, 0.040, -0.190), (0.500, 0.006, 0.014), "warning_red", 0.002)
    out.append(b.finish((0, 0, 0)))

    # 6. Tuyau (pivot centre, axe X)
    b = Builder("Pipe", ["gunmetal", "dark_steel", "brushed_metal",
                         "warning_red", "rubber"])
    b.cyl((0, 0, 0), 0.078, 1.000, "gunmetal", 18, rot=AXIS_ROT["X"])
    for x in (-0.480, 0.480):
        b.cyl((x, 0, 0), 0.118, 0.045, "dark_steel", 18, rot=AXIS_ROT["X"])
        for k in range(8):
            a = TAU * k / 8
            b.bolt((x, 0.096 * math.cos(a), 0.096 * math.sin(a)),
                   0.010, "brushed_metal", "X")
    b.cyl((0, 0, 0), 0.088, 0.060, "brushed_metal", 18, rot=AXIS_ROT["X"])
    b.torus((0.120, 0, 0), 0.080, 0.010, "warning_red", 16, 6,
            rot=AXIS_ROT["X"])
    b.torus((-0.120, 0, 0), 0.080, 0.010, "rubber", 16, 6, rot=AXIS_ROT["X"])
    out.append(b.finish((0, 0, 0)))

    # 7. Baie de serveurs (pivot base)
    b = Builder("ServerRack", ["dark_steel", "gunmetal", "brushed_metal",
                               "black_plastic", "emissive_cyan",
                               "emissive_green", "red_emissive"])
    b.box((0, 0, 0.970), (0.760, 0.640, 1.940), "dark_steel", 0.030)
    for sx in (-1, 1):
        b.box((0.335 * sx, 0.315, 0.970), (0.050, 0.030, 1.800),
              "brushed_metal", 0.006)
    for k in range(12):
        z = 0.180 + k * 0.145
        b.box((0, 0.322, z), (0.620, 0.020, 0.105), "gunmetal", 0.006)
        for j in range(6):
            b.box((-0.230 + j * 0.080, 0.335, z), (0.055, 0.006, 0.050),
                  "black_plastic", 0.002)
        led = ("emissive_cyan", "emissive_green", "red_emissive")[k % 3]
        b.sphere((0.265, 0.340, z), 0.009, led, 8, 6)
    for sx in (-1, 1):
        b.box((0.310 * sx, 0.350, 1.700), (0.025, 0.060, 0.300),
              "brushed_metal", 0.005)
    for k in range(7):
        b.box((0, -0.325, 1.400 + k * 0.070), (0.560, 0.010, 0.028),
              "black_plastic", 0.002)
    out.append(b.finish((0, 0, 0)))

    # 8. Carte d'acces (pivot centre)
    b = Builder("Keycard", ["black_plastic", "dark_steel", "gold",
                            "emissive_cyan"])
    b.box((0, 0, 0), (0.086, 0.008, 0.056), "black_plastic", 0.003)
    b.box((0, 0.005, 0.016), (0.080, 0.003, 0.011), "dark_steel", 0.001)
    b.box((0.018, 0.005, -0.010), (0.022, 0.003, 0.016), "gold", 0.002)
    b.box((-0.028, 0.005, -0.014), (0.014, 0.003, 0.022), "emissive_cyan", 0.001)
    b.torus((0.031, 0, -0.022), 0.004, 0.0015, "gold", 10, 5, rot=AXIS_ROT["Y"])
    out.append(b.finish((0, 0, 0)))

    # 9. Puce memoire (pivot centre)
    b = Builder("MemoryChip", ["circuit_green", "black_plastic", "gold",
                               "brushed_metal"])
    b.box((0, 0, 0), (0.110, 0.008, 0.072), "circuit_green", 0.002)
    for k in range(10):
        for sz in (-1, 1):
            b.box((-0.045 + k * 0.010, 0, 0.040 * sz), (0.006, 0.003, 0.012),
                  "gold", 0.001)
    for x, z, w, h in ((-0.025, 0.005, 0.038, 0.030),
                       (0.028, -0.010, 0.030, 0.022),
                       (0.030, 0.020, 0.022, 0.014)):
        b.box((x, 0.006, z), (w, 0.007, h), "black_plastic", 0.002)
    for k in range(4):
        b.box((-0.040 + k * 0.026, 0.006, -0.028), (0.008, 0.004, 0.006),
              "brushed_metal", 0.001)
    out.append(b.finish((0, 0, 0)))

    # 10. Trousse de secours (pivot centre, face avant +Y)
    b = Builder("Medkit", ["bone_white", "dark_steel", "warning_red",
                           "brushed_metal", "rubber"])
    b.box((0, 0, 0), (0.300, 0.210, 0.190), "bone_white", 0.018)
    b.box((0, 0, 0.060), (0.310, 0.220, 0.022), "dark_steel", 0.006)
    b.torus((0, 0, 0.130), 0.050, 0.009, "rubber", 14, 6, rot=AXIS_ROT["Y"])
    for sx in (-1, 1):
        b.box((0.090 * sx, 0.107, 0.060), (0.026, 0.014, 0.040),
              "brushed_metal", 0.004)
    b.box((0, 0.108, -0.010), (0.028, 0.006, 0.100), "warning_red", 0.002)
    b.box((0, 0.108, -0.010), (0.100, 0.006, 0.028), "warning_red", 0.002)
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.box((0.130 * sx, 0.108, 0.080 * sz), (0.030, 0.010, 0.030),
                  "dark_steel", 0.004)
    out.append(b.finish((0, 0, 0)))

    # 11. Batterie (pivot centre)
    b = Builder("Battery", ["dark_steel", "chrome", "warning_red",
                            "brushed_metal", "emissive_green"])
    b.cyl((0, 0, 0), 0.046, 0.120, "dark_steel", 16)
    b.cyl((0, 0, 0.065), 0.019, 0.022, "chrome", 12)
    b.cyl((0, 0, -0.064), 0.044, 0.010, "chrome", 16)
    for z in (-0.040, 0.040):
        b.torus((0, 0, z), 0.047, 0.007, "warning_red", 16, 6)
    for k in range(4):
        b.box((0, 0.047, -0.028 + k * 0.018), (0.030, 0.004, 0.010),
              "emissive_green", 0.001)
    out.append(b.finish((0, 0, 0)))

    # 12. Camera de surveillance (pivot centre)
    b = Builder("Camera", ["gunmetal", "dark_steel", "brushed_metal",
                           "chrome", "tinted_glass", "red_emissive"])
    b.box((0, 0, 0), (0.300, 0.340, 0.190), "gunmetal", 0.022)
    b.box((0, 0.050, 0.110), (0.340, 0.260, 0.030), "dark_steel", 0.010)
    b.cyl((0, 0.200, 0), 0.072, 0.060, "chrome", 18, rot=AXIS_ROT["Y"])
    b.cyl((0, 0.233, 0), 0.056, 0.010, "tinted_glass", 16, rot=AXIS_ROT["Y"])
    b.torus((0, 0.228, 0), 0.064, 0.008, "brushed_metal", 16, 6,
            rot=AXIS_ROT["Y"])
    b.box((0, -0.160, 0.100), (0.120, 0.100, 0.080), "dark_steel", 0.010)
    b.cyl((0, -0.160, 0.170), 0.040, 0.060, "brushed_metal", 12)
    b.sphere((0.100, 0.180, 0.060), 0.010, "red_emissive", 8, 6)
    for k in range(4):
        b.box((0, -0.180, -0.070 + k * 0.035), (0.220, 0.010, 0.014),
              "dark_steel", 0.002)
    out.append(b.finish((0, 0, 0)))

    # 13. Tourelle (pivot base)
    b = Builder("Turret", ["dark_steel", "gunmetal", "chrome",
                           "brushed_metal", "red_emissive"])
    b.cyl((0, 0, 0.040), 0.190, 0.080, "dark_steel", 18)
    for k in range(8):
        a = TAU * k / 8
        b.bolt((0.160 * math.cos(a), 0.160 * math.sin(a), 0.085), 0.012)
    b.cyl((0, 0, 0.220), 0.075, 0.300, "gunmetal", 14)
    b.box((0, 0, 0.440), (0.280, 0.320, 0.220), "gunmetal", 0.026)
    for s in (-1, 1):
        b.tube((0.075 * s, 0.140, 0.440), (0.075 * s, 0.380, 0.440),
               0.026, "chrome", 12)
        b.torus((0.075 * s, 0.380, 0.440), 0.028, 0.006, "dark_steel", 12, 6,
                rot=AXIS_ROT["Y"])
    b.sphere((0, 0.170, 0.440), 0.030, "red_emissive", 12, 8)
    for s in (-1, 1):
        for k in range(3):
            b.box((0.145 * s, -0.030 + k * 0.050, 0.440),
                  (0.008, 0.030, 0.150), "brushed_metal", 0.003)
    out.append(b.finish((0, 0, 0)))

    # 14. Porte (pivot base)
    b = Builder("Door", ["gunmetal", "dark_steel", "brushed_metal",
                         "tinted_glass", "warning_red", "emissive_cyan"])
    for x in (-0.630, 0.630):
        b.box((x, 0, 1.150), (0.080, 0.180, 2.300), "dark_steel", 0.012)
    b.box((0, 0, 2.310), (1.340, 0.180, 0.080), "dark_steel", 0.010)
    b.box((0, 0, 1.150), (1.180, 0.090, 2.220), "gunmetal", 0.022)
    b.box((0, 0.050, 1.690), (0.440, 0.020, 0.520), "tinted_glass", 0.010)
    b.box((0, 0.064, 1.690), (0.360, 0.008, 0.440), "dark_steel", 0.005)
    for z in (0.350, 1.150, 2.050):
        b.box((0, 0.055, z), (1.100, 0.018, 0.060), "brushed_metal", 0.005)
    for z in (0.400, 1.150, 1.950):
        b.cyl((-0.610, 0, z), 0.036, 0.100, "brushed_metal", 12)
    b.box((0.430, 0.070, 1.050), (0.045, 0.060, 0.240), "brushed_metal", 0.008)
    b.cyl((0.430, 0.105, 1.050), 0.055, 0.020, "dark_steel", 12,
          rot=AXIS_ROT["Y"])
    b.box((0, 0.055, 2.130), (0.900, 0.010, 0.050), "warning_red", 0.003)
    b.box((0, 0.055, 0.100), (0.900, 0.010, 0.020), "emissive_cyan", 0.002)
    out.append(b.finish((0, 0, 0)))

    # 15. Vanne (pivot centre du volant)
    b = Builder("Valve", ["warning_red", "chrome", "dark_steel",
                          "brushed_metal"])
    b.torus((0, 0, 0), 0.160, 0.020, "warning_red", 20, 8, rot=AXIS_ROT["Y"])
    for k in range(5):
        a = TAU * k / 5
        b.tube((0, 0, 0), (0.150 * math.cos(a), 0, 0.150 * math.sin(a)),
               0.012, "chrome", 8)
    b.cyl((0, 0, 0), 0.038, 0.060, "dark_steel", 14, rot=AXIS_ROT["Y"])
    b.cyl((0, -0.120, 0), 0.060, 0.160, "brushed_metal", 16, rot=AXIS_ROT["Y"])
    b.cyl((0, -0.210, 0), 0.085, 0.030, "dark_steel", 16, rot=AXIS_ROT["Y"])
    for k in range(6):
        a = TAU * k / 6
        b.bolt((0.070 * math.cos(a), -0.205, 0.070 * math.sin(a)),
               0.008, "chrome", "Y")
    out.append(b.finish((0, 0, 0)))

    # 16. Enseigne au neon (pivot centre, motif abstrait sans texte ni logo)
    b = Builder("NeonSign", ["dark_steel", "black_plastic", "brushed_metal",
                             "emissive_cyan", "red_emissive"])
    b.box((0, 0, 0), (0.740, 0.080, 0.340), "dark_steel", 0.014)
    b.box((0, 0.045, 0), (0.680, 0.010, 0.280), "black_plastic", 0.004)
    b.tube((-0.250, 0.065, -0.080), (0.250, 0.065, -0.080),
           0.012, "emissive_cyan", 10)
    b.tube((-0.250, 0.065, 0.080), (0.250, 0.065, 0.080),
           0.012, "emissive_cyan", 10)
    b.tube((-0.250, 0.065, -0.080), (-0.250, 0.065, 0.080),
           0.012, "emissive_cyan", 10)
    b.tube((0.250, 0.065, -0.080), (0.250, 0.065, 0.080),
           0.012, "emissive_cyan", 10)
    b.tube((-0.180, 0.070, 0.000), (0.180, 0.070, 0.000),
           0.010, "red_emissive", 10)
    for sx in (-1, 1):
        b.box((0.320 * sx, -0.060, 0.120), (0.030, 0.100, 0.040),
              "brushed_metal", 0.005)
    out.append(b.finish((0, 0, 0)))

    return out


def build_player_hands():
    """Avant-bras gantes FPS, pivot = poignet, direction +Y Blender (-Z glTF)."""
    out = []
    for side, s in (("L", -1), ("R", 1)):
        b = Builder("Hand_" + side,
                    ["black_plastic", "rubber", "chrome", "dark_steel",
                     "brushed_metal"])
        b.tube((0, -0.300, 0.015), (0, -0.015, 0.010), 0.052,
               "black_plastic", 14, radius_top=0.044)
        for k in range(3):
            b.torus((0, -0.265 + k * 0.026, 0.014), 0.051, 0.007,
                    "rubber", 14, 6, rot=AXIS_ROT["Y"])
        b.box((0.030 * s, -0.170, 0.052), (0.076, 0.200, 0.020),
              "dark_steel", 0.010)
        b.cyl((0, -0.012, 0.008), 0.046, 0.050, "rubber", 14,
              rot=AXIS_ROT["Y"])
        b.box((0, 0.036, 0.000), (0.088, 0.095, 0.056), "black_plastic", 0.014)
        b.box((0, 0.074, 0.022), (0.080, 0.030, 0.018), "brushed_metal", 0.006)
        for i in range(4):
            x = (i - 1.5) * 0.020
            a = (x, 0.076, 0.010)
            m = (x, 0.106, -0.016)
            t = (x, 0.096, -0.050)
            b.tube(a, m, 0.011, "black_plastic", 10)
            b.tube(m, t, 0.009, "black_plastic", 10)
            b.sphere(m, 0.011, "rubber", 8, 6)
            b.box((x, 0.101, -0.054), (0.018, 0.020, 0.007), "chrome", 0.002)
        b.tube((0.050 * s, 0.028, 0.000), (0.065 * s, 0.076, -0.026),
               0.014, "black_plastic", 10)
        b.tube((0.065 * s, 0.076, -0.026), (0.055 * s, 0.104, -0.046),
               0.011, "black_plastic", 10)
        out.append(b.finish((0.105 * s, 0.0, 0.0)))
    return out


# === ASSET BUILDERS ===


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Generateur GLB Nightfall 1984")
    parser.add_argument("--out", required=True, help="Dossier de sortie des GLB")
    options = parser.parse_args(args)

    out_dir = os.path.abspath(options.out)
    os.makedirs(out_dir, exist_ok=True)

    init_scene()
    init_materials()

    # Construction puis export UN par UN : les noms d'objets restent exacts
    # (Blender ajouterait sinon .001 aux Hand_L/Hand_R des mains FPS).
    group_builders = [
        ("endoskeleton", build_endoskeleton),
        ("drone", build_drone),
        ("boss", build_boss),
        ("weapons", build_weapons),
        ("props", build_props),
        ("player_hands", build_player_hands),
    ]

    total_bytes = 0
    for filename, builder in group_builders:
        objects = builder()
        path = export_group(filename, objects, out_dir)
        size = os.path.getsize(path)
        triangles = sum(tri_count(obj) for obj in objects)
        total_bytes += size
        if size <= 5120:
            raise RuntimeError("GLB trop petit: %s (%d octets)" % (path, size))
        print("NF_ASSET %-14s objects=%-3d tris=%-6d bytes=%d"
              % (filename + ".glb", len(objects), triangles, size))
        for obj in objects:
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)
    print("NF_TOTAL bytes=%d files=%d" % (total_bytes, len(group_builders)))


if __name__ == "__main__":
    main()
