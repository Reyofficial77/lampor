#!/usr/bin/env python3
"""
Procedural Adult Male Survivor 3D Mesh & PBR Albedo Texture Generator for LAMPOR.

Generates:
  1. tools/characters/output/adult_male_mesh.json
     - Godot/glTF Y-up coordinate space, facing +Z, Left = +X, Right = -X
     - Total height = 1.76m, feet flat at y = 0.0, T-pose arms at y = 1.40m
     - Two separate meshes: "body-mesh" and "head-mesh" (FPP-safe separation)
     - Per-vertex "regions" array ("torso", "arm_l", "arm_r", "leg_l", "leg_r", "neck", "head")
     - Smooth area-weighted normals welded across UV seams
  2. assets/models/player/adult_male_albedo.png (1024x1024 RGBA/RGB PNG)
     - Non-overlapping UV islands strictly inside [0.005, 0.995] with >=12px bleed padding
     - glTF UV v=0 at top of PNG (matching PIL py = v * (H - 1))

UV ATLAS LAYOUT (1024x1024, all coordinates strictly inside [0.020, 0.980]):
  - FACE_SKIN:    u=[0.020, 0.480], v=[0.020, 0.480]  (Face portrait, jaw, ears, upper neck)
  - HAIR:         u=[0.520, 0.980], v=[0.020, 0.240]  (Short layered dark hair)
  - LIMB_SKIN:    u=[0.520, 0.980], v=[0.270, 0.480]  (Forearms, hands, lower neck)
  - JACKET_BODY:  u=[0.020, 0.460], v=[0.515, 0.845]  (Field jacket torso, collar, pockets)
  - JACKET_SLEEVE:u=[0.480, 0.720], v=[0.515, 0.725]  (Upper sleeves & rolled cuffs)
  - UNDERSHIRT:   u=[0.480, 0.720], v=[0.745, 0.845]  (Dark ribbed undershirt)
  - TROUSERS:     u=[0.740, 0.980], v=[0.515, 0.845]  (Charcoal-navy cargo trousers)
  - BELT:         u=[0.020, 0.340], v=[0.870, 0.980]  (Brown leather belt & loops)
  - BUCKLE:       u=[0.360, 0.460], v=[0.870, 0.980]  (Brass buckle & jacket buttons)
  - BOOT_LEATHER: u=[0.480, 0.760], v=[0.870, 0.980]  (Muddy brown-black leather boots)
  - BOOT_LACES:   u=[0.780, 0.880], v=[0.870, 0.980]  (Laced tongue & eyelets)
  - BOOT_SOLE:    u=[0.900, 0.980], v=[0.870, 0.980]  (Dark rubber lug sole & heel)
"""

import json
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter


# ---------------------------------------------------------------------------
# Paths & Contract Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
OUTPUT_JSON_PATH = os.path.join(SCRIPT_DIR, "output", "adult_male_mesh.json")
OUTPUT_PNG_PATH = os.path.join(REPO_ROOT, "assets", "models", "player", "adult_male_albedo.png")

TEX_SIZE = 1024

UV_ISLANDS = {
    "face_skin":     (0.020, 0.480, 0.020, 0.480),
    "hair":          (0.520, 0.980, 0.020, 0.240),
    "limb_skin":     (0.520, 0.980, 0.270, 0.480),
    "jacket_body":   (0.020, 0.460, 0.515, 0.845),
    "jacket_sleeve": (0.480, 0.720, 0.515, 0.725),
    "undershirt":    (0.480, 0.720, 0.745, 0.845),
    "trousers":      (0.740, 0.980, 0.515, 0.845),
    "belt":          (0.020, 0.340, 0.870, 0.980),
    "buckle":        (0.360, 0.460, 0.870, 0.980),
    "boot_leather":  (0.480, 0.760, 0.870, 0.980),
    "boot_laces":    (0.780, 0.880, 0.870, 0.980),
    "boot_sole":     (0.900, 0.980, 0.870, 0.980),
}

JOINTS = {
    "Hips":       [0.0, 0.94, 0.0],
    "Torso":      [0.0, 1.12, 0.0],
    "Chest":      [0.0, 1.32, 0.0],
    "Neck":       [0.0, 1.49, 0.0],
    "Head":       [0.0, 1.60, 0.01],
    "Shoulder.L": [0.08, 1.40, 0.0],
    "UpperArm.L": [0.21, 1.40, 0.0],
    "LowerArm.L": [0.49, 1.40, -0.01],
    "Hand.L":     [0.75, 1.40, 0.0],
    "Shoulder.R": [-0.08, 1.40, 0.0],
    "UpperArm.R": [-0.21, 1.40, 0.0],
    "LowerArm.R": [-0.49, 1.40, -0.01],
    "Hand.R":     [-0.75, 1.40, 0.0],
    "UpperLeg.L": [0.105, 0.90, 0.0],
    "LowerLeg.L": [0.105, 0.49, 0.01],
    "Foot.L":     [0.105, 0.09, 0.02],
    "UpperLeg.R": [-0.105, 0.90, 0.0],
    "LowerLeg.R": [-0.105, 0.49, 0.01],
    "Foot.R":     [-0.105, 0.09, 0.02],
}

ALLOWED_REGIONS = {"torso", "arm_l", "arm_r", "leg_l", "leg_r", "neck", "head"}

HEAD_Y_MIN = 1.475
HEAD_Y_MAX = 1.745
TORSO_Y_MIN = 0.955
TORSO_Y_MAX = 1.452


# ---------------------------------------------------------------------------
# Math Utilities
# ---------------------------------------------------------------------------

def clamp(val, lo, hi):
    return lo if val < lo else (hi if val > hi else val)


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(edge0, edge1, x):
    if edge1 == edge0:
        return 0.0
    t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def gauss(x, center, width):
    if width <= 0.0:
        return 0.0
    d = (x - center) / width
    return math.exp(-0.5 * d * d)


def v_add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def v_cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def v_dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def v_len(a):
    return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])


def v_norm(a):
    l = v_len(a)
    if l < 1e-12:
        return (0.0, 1.0, 0.0)
    return (a[0] / l, a[1] / l, a[2] / l)


def map_uv(island_name, u_local, v_local):
    u0, u1, v0, v1 = UV_ISLANDS[island_name]
    u = clamp(lerp(u0, u1, clamp(u_local, 0.0, 1.0)), u0, u1)
    v = clamp(lerp(v0, v1, clamp(v_local, 0.0, 1.0)), v0, v1)
    return (u, v)


def face_uv_from_y_theta(y, theta):
    """Shared projection between 3D head mesh and 2D face texture painter."""
    u_local = 0.5 + theta / (2.0 * math.pi)
    v_local = (HEAD_Y_MAX - y) / (HEAD_Y_MAX - HEAD_Y_MIN)
    return map_uv("face_skin", u_local, v_local)


def jacket_uv_from_y_theta(y, theta):
    """Shared projection between 3D torso jacket and 2D jacket texture painter."""
    u_local = 0.5 + theta / (2.0 * math.pi)
    v_local = (TORSO_Y_MAX - y) / (TORSO_Y_MAX - TORSO_Y_MIN)
    return map_uv("jacket_body", u_local, v_local)


# ---------------------------------------------------------------------------
# MeshBuilder with Smooth Area-Weighted Normals & Winding Audit
# ---------------------------------------------------------------------------

class MeshBuilder:
    """Builds watertight smooth-normal submeshes and audits winding."""

    def __init__(self, name):
        self.name = name
        self.positions = []
        self.uvs = []
        self.indices = []
        self.regions = []
        self.smooth_groups = []
        self.submeshes = []  # (label, vert_start, vert_end, idx_start, idx_end, is_closed)

    def _add_vertex(self, pos, uv, region, smooth_group):
        if region not in ALLOWED_REGIONS:
            raise ValueError(f"Invalid region '{region}'")
        idx = len(self.positions)
        self.positions.append((float(pos[0]), float(pos[1]), float(pos[2])))
        self.uvs.append((float(uv[0]), float(uv[1])))
        self.regions.append(region)
        self.smooth_groups.append(smooth_group)
        return idx

    def _add_tri(self, i0, i1, i2, mirror_winding=False):
        if mirror_winding:
            self.indices.extend((i0, i2, i1))
        else:
            self.indices.extend((i0, i1, i2))

    def add_lofted_tube(
        self,
        label,
        rings,
        smooth_group,
        cap_start=True,
        cap_end=True,
        start_center=None,
        end_center=None,
        start_cap_region=None,
        end_cap_region=None,
        start_cap_uv=None,
        end_cap_uv=None,
        mirror_x=False,
    ):
        """
        Loft a closed-ring tube.
        Each entry in `rings` is a dict:
          {
            "points": [(x,y,z), ...]  # length N, ordered CCW around tube axis +A
            "uvs": [(u,v), ...]       # length N+1 (seam duplicated at j=N)
            "regions": [str, ...]     # length N (or single string via "region")
          }
        Tube must advance along +A from rings[0] to rings[-1] so normals face outward.
        If `mirror_x=True`, all X coords are negated and triangle winding is flipped.
        """
        if len(rings) < 2:
            raise ValueError(f"Lofted tube '{label}' requires >= 2 rings")

        n_seg = len(rings[0]["points"])
        v_start = len(self.positions)
        i_start = len(self.indices)

        ring_indices = []
        for r in rings:
            pts = r["points"]
            uvs = r["uvs"]
            if len(pts) != n_seg:
                raise ValueError(f"Inconsistent ring segment count in '{label}'")
            if len(uvs) != n_seg + 1:
                raise ValueError(f"Expected N+1 UVs in '{label}', got {len(uvs)}")
            regs = r.get("regions")
            if regs is None:
                reg = r["region"]
                regs = [reg] * n_seg

            row = []
            for j in range(n_seg + 1):
                jj = j % n_seg
                px, py, pz = pts[jj]
                if mirror_x:
                    px = -px
                idx = self._add_vertex((px, py, pz), uvs[j], regs[jj], smooth_group)
                row.append(idx)
            ring_indices.append(row)

        for ri in range(len(ring_indices) - 1):
            r0 = ring_indices[ri]
            r1 = ring_indices[ri + 1]
            for j in range(n_seg):
                a = r0[j]
                b = r0[j + 1]
                c = r1[j + 1]
                d = r1[j]
                self._add_tri(a, b, c, mirror_winding=mirror_x)
                self._add_tri(a, c, d, mirror_winding=mirror_x)

        if cap_start:
            r0_pts = rings[0]["points"]
            if start_center is None:
                cx = sum(p[0] for p in r0_pts) / n_seg
                cy = sum(p[1] for p in r0_pts) / n_seg
                cz = sum(p[2] for p in r0_pts) / n_seg
                c_pos = (cx, cy, cz)
            else:
                c_pos = start_center
            if mirror_x:
                c_pos = (-c_pos[0], c_pos[1], c_pos[2])

            c_reg = start_cap_region or (rings[0].get("region") or rings[0]["regions"][0])
            if start_cap_uv is None:
                c_uv = (
                    sum(u[0] for u in rings[0]["uvs"][:-1]) / n_seg,
                    sum(u[1] for u in rings[0]["uvs"][:-1]) / n_seg,
                )
            else:
                c_uv = start_cap_uv

            c_idx = self._add_vertex(c_pos, c_uv, c_reg, smooth_group)
            row0 = ring_indices[0]
            for j in range(n_seg):
                self._add_tri(c_idx, row0[j + 1], row0[j], mirror_winding=mirror_x)

        if cap_end:
            r1_pts = rings[-1]["points"]
            if end_center is None:
                cx = sum(p[0] for p in r1_pts) / n_seg
                cy = sum(p[1] for p in r1_pts) / n_seg
                cz = sum(p[2] for p in r1_pts) / n_seg
                c_pos = (cx, cy, cz)
            else:
                c_pos = end_center
            if mirror_x:
                c_pos = (-c_pos[0], c_pos[1], c_pos[2])

            c_reg = end_cap_region or (rings[-1].get("region") or rings[-1]["regions"][0])
            if end_cap_uv is None:
                c_uv = (
                    sum(u[0] for u in rings[-1]["uvs"][:-1]) / n_seg,
                    sum(u[1] for u in rings[-1]["uvs"][:-1]) / n_seg,
                )
            else:
                c_uv = end_cap_uv

            c_idx = self._add_vertex(c_pos, c_uv, c_reg, smooth_group)
            row1 = ring_indices[-1]
            for j in range(n_seg):
                self._add_tri(c_idx, row1[j], row1[j + 1], mirror_winding=mirror_x)

        v_end = len(self.positions)
        i_end = len(self.indices)
        self.submeshes.append((label, v_start, v_end, i_start, i_end, cap_start and cap_end))

    def add_bevel_box(
        self,
        label,
        center,
        half_extents,
        bevel,
        uv_island,
        region,
        smooth_group,
        rot_x=0.0,
        rot_y=0.0,
        mirror_x=False,
    ):
        """
        Build a clean watertight bevelled prism lofted along Y so seams & shading are crisp.
        """
        hx, hy, hz = half_extents
        bx = min(bevel, hx * 0.45)
        bz = min(bevel, hz * 0.45)
        by = min(bevel, hy * 0.45)

        # 12-point rounded rectangle in XZ, ordered CCW around +Y (starting +Z)
        raw_pts = [
            (0.0, hz),
            (hx - bx, hz),
            (hx, hz - bz),
            (hx, 0.0),
            (hx, -(hz - bz)),
            (hx - bx, -hz),
            (0.0, -hz),
            (-(hx - bx), -hz),
            (-hx, -(hz - bz)),
            (-hx, 0.0),
            (-hx, hz - bz),
            (-(hx - bx), hz),
        ]
        # Verify strictly increasing theta = atan2(x, z) -> Z x X = +Y!
        # Wait: atan2(x, z) at (0, +hz) is 0, at (+hx, 0) is +pi/2, at (0, -hz) is +-pi.
        # That matches R_u=+Z, R_v=+X!

        layers = [
            (-hy, 1.0 - 0.35 * (by / max(hy, 1e-6))),
            (-hy + by, 1.0),
            (hy - by, 1.0),
            (hy, 1.0 - 0.35 * (by / max(hy, 1e-6))),
        ]

        cx, cy, cz = center
        cos_rx, sin_rx = math.cos(rot_x), math.sin(rot_x)
        cos_ry, sin_ry = math.cos(rot_y), math.sin(rot_y)

        rings = []
        n_seg = len(raw_pts)
        for li, (ly, scale) in enumerate(layers):
            v_loc = 1.0 - (ly + hy) / max(2.0 * hy, 1e-6)
            pts = []
            uvs = []
            for j in range(n_seg):
                px = raw_pts[j][0] * scale
                py = ly
                pz = raw_pts[j][1] * scale
                # Rotate around X then Y
                ry1 = py * cos_rx - pz * sin_rx
                rz1 = py * sin_rx + pz * cos_rx
                rx2 = px * cos_ry + rz1 * sin_ry
                rz2 = -px * sin_ry + rz1 * cos_ry
                pts.append((cx + rx2, cy + ry1, cz + rz2))
                uvs.append(map_uv(uv_island, j / n_seg, v_loc))
            uvs.append(map_uv(uv_island, 1.0, v_loc))
            rings.append({"points": pts, "uvs": uvs, "region": region})

        self.add_lofted_tube(
            label,
            rings,
            smooth_group=smooth_group,
            cap_start=True,
            cap_end=True,
            mirror_x=mirror_x,
        )

    def compute_normals(self):
        """Area-weighted vertex normals welded by (rounded pos, smooth_group)."""
        accum = {}
        for i in range(0, len(self.indices), 3):
            i0, i1, i2 = self.indices[i], self.indices[i + 1], self.indices[i + 2]
            p0 = self.positions[i0]
            p1 = self.positions[i1]
            p2 = self.positions[i2]
            fn = v_cross(v_sub(p1, p0), v_sub(p2, p0))
            for idx in (i0, i1, i2):
                p = self.positions[idx]
                key = (
                    round(p[0], 5),
                    round(p[1], 5),
                    round(p[2], 5),
                    self.smooth_groups[idx],
                )
                prev = accum.get(key)
                if prev is None:
                    accum[key] = fn
                else:
                    accum[key] = (prev[0] + fn[0], prev[1] + fn[1], prev[2] + fn[2])

        normals = []
        for idx, p in enumerate(self.positions):
            key = (
                round(p[0], 5),
                round(p[1], 5),
                round(p[2], 5),
                self.smooth_groups[idx],
            )
            n = v_norm(accum.get(key, (0.0, 1.0, 0.0)))
            normals.append([round(n[0], 6), round(n[1], 6), round(n[2], 6)])
        return normals

    def audit_submeshes(self):
        """Verify every closed submesh has positive signed volume and non-degenerate tris."""
        for label, vs, ve, is_, ie, is_closed in self.submeshes:
            signed_vol6 = 0.0
            for k in range(is_, ie, 3):
                i0, i1, i2 = self.indices[k], self.indices[k + 1], self.indices[k + 2]
                p0 = self.positions[i0]
                p1 = self.positions[i1]
                p2 = self.positions[i2]
                area2 = v_len(v_cross(v_sub(p1, p0), v_sub(p2, p0)))
                if area2 < 1e-11:
                    raise AssertionError(f"Degenerate triangle in {self.name}/{label} at tri {k//3}")
                if is_closed:
                    signed_vol6 += v_dot(p0, v_cross(p1, p2))
            if is_closed and signed_vol6 <= 0.0:
                raise AssertionError(
                    f"Inverted winding in {self.name}/{label}: signed_vol={signed_vol6 / 6.0:.8f}"
                )

    def to_dict(self):
        self.audit_submeshes()
        normals = self.compute_normals()
        return {
            "positions": [[round(p[0], 6), round(p[1], 6), round(p[2], 6)] for p in self.positions],
            "normals": normals,
            "uvs": [[round(u[0], 6), round(u[1], 6)] for u in self.uvs],
            "indices": list(self.indices),
            "regions": list(self.regions),
        }


# ---------------------------------------------------------------------------
# Generic Limb / Tube Helper
# ---------------------------------------------------------------------------

def build_oriented_tube_rings(samples, n_seg, axis_dir, ref_u, uv_island, region, u_offset=0.0):
    """
    Build rings along an arbitrary axis `axis_dir` using right-handed frame (ref_u, ref_v, axis_dir).
    Each entry in `samples` is:
      (center_vec3, r_u, r_v, v_local, optional_shape_fn)
    `optional_shape_fn(theta, rx, ry)` returns `(dx_u, dx_v)` override or modifier.
    """
    a = v_norm(axis_dir)
    ru = v_norm(v_sub(ref_u, v_mul(a, v_dot(ref_u, a))))
    rv = v_cross(a, ru)  # wait: check ru x rv = a!
    # Check: a x ru = rv => ru x rv = ru x (a x ru) = a*(ru.ru) - ru*(ru.a) = a! Yes!

    rings = []
    for item in samples:
        center, r_u, r_v, v_loc = item[:4]
        mod_fn = item[4] if len(item) > 4 else None
        pts = []
        uvs = []
        for j in range(n_seg):
            theta = (2.0 * math.pi * j) / n_seg
            cu = r_u * math.cos(theta)
            cv = r_v * math.sin(theta)
            if mod_fn is not None:
                cu, cv = mod_fn(theta, cu, cv)
            p = v_add(center, v_add(v_mul(ru, cu), v_mul(rv, cv)))
            pts.append(p)
            u_loc = (j / n_seg + u_offset) % 1.0
            uvs.append(map_uv(uv_island, u_loc, v_loc))
        uvs.append(map_uv(uv_island, 1.0, v_loc))
        rings.append({"points": pts, "uvs": uvs, "region": region})
    return rings


# ---------------------------------------------------------------------------
# Anatomy Builders: Body Mesh
# ---------------------------------------------------------------------------

def build_pelvis_and_torso(mb):
    """Build trouser pelvis, belt+buckle, field jacket, collar, pockets, undershirt, lower neck."""
    # 1. Trouser Pelvis / Hip Seat (y = 0.830 .. 0.948), region = "torso"
    n_pelvis = 24
    pelvis_y = [0.830, 0.850, 0.875, 0.902, 0.928, 0.948]
    pelvis_rings = []
    for y in pelvis_y:
        t = (y - 0.830) / (0.948 - 0.830)
        # Keep crotch bridge narrow at y=0.830, flare smoothly across hips y=0.865..0.948
        rx = lerp(0.062, 0.168, smoothstep(0.0, 0.60, t))
        rz = lerp(0.088, 0.118, smoothstep(0.0, 0.72, t))
        cz = lerp(-0.006, 0.0, t)
        v_loc = lerp(0.28, 0.04, t)

        pts = []
        uvs = []
        for j in range(n_pelvis):
            theta = -math.pi + (2.0 * math.pi * j) / n_pelvis
            glute = 1.0 + 0.08 * gauss(y, 0.895, 0.03) * max(0.0, -math.cos(theta))
            hip_sq = 1.0 + 0.03 * math.cos(4.0 * theta)
            x = rx * math.sin(theta) * hip_sq
            z = cz + rz * math.cos(theta) * glute * hip_sq
            pts.append((x, y, z))
            uvs.append(map_uv("trousers", j / n_pelvis, v_loc))
        uvs.append(map_uv("trousers", 1.0, v_loc))
        pelvis_rings.append({"points": pts, "uvs": uvs, "region": "torso"})

    mb.add_lofted_tube(
        "pelvis_trousers",
        pelvis_rings,
        smooth_group="trousers_pelvis",
        cap_start=True,
        cap_end=True,
        start_center=(0.0, 0.826, -0.006),
    )

    # 2. Brown Leather Belt (y = 0.934 .. 0.970), region = "torso"
    n_belt = 28
    belt_y = [0.934, 0.942, 0.962, 0.970]
    belt_rings = []
    for bi, y in enumerate(belt_y):
        t = (y - 0.934) / (0.970 - 0.934)
        # Bevel slight inset at top/bottom edge
        bevel_r = 0.003 if (bi == 0 or bi == 3) else 0.008
        rx = 0.168 + bevel_r
        rz = 0.118 + bevel_r
        pts = []
        uvs = []
        for j in range(n_belt):
            theta = -math.pi + (2.0 * math.pi * j) / n_belt
            sq = 1.0 + 0.03 * math.cos(4.0 * theta)
            x = rx * math.sin(theta) * sq
            z = rz * math.cos(theta) * sq
            pts.append((x, y, z))
            uvs.append(map_uv("belt", j / n_belt, 1.0 - t))
        uvs.append(map_uv("belt", 1.0, 1.0 - t))
        belt_rings.append({"points": pts, "uvs": uvs, "region": "torso"})

    mb.add_lofted_tube("leather_belt", belt_rings, smooth_group="belt", cap_start=True, cap_end=True)

    # Belt loops (4 bevelled leather straps around front/sides/back)
    for lx, lz, ry in [(-0.075, 0.120, -0.35), (0.075, 0.120, 0.35), (-0.165, 0.0, -1.57), (0.165, 0.0, 1.57)]:
        mb.add_bevel_box(
            "belt_loop",
            center=(lx, 0.952, lz),
            half_extents=(0.011, 0.023, 0.010),
            bevel=0.003,
            uv_island="belt",
            region="torso",
            smooth_group="belt_loops",
            rot_y=ry,
        )

    # Brass Belt Buckle + Leather Tongue (front center at z ~ +0.127)
    mb.add_bevel_box(
        "brass_buckle",
        center=(0.0, 0.952, 0.129),
        half_extents=(0.032, 0.024, 0.008),
        bevel=0.003,
        uv_island="buckle",
        region="torso",
        smooth_group="buckle",
    )
    mb.add_bevel_box(
        "buckle_tongue",
        center=(0.034, 0.952, 0.125),
        half_extents=(0.016, 0.017, 0.005),
        bevel=0.002,
        uv_island="belt",
        region="torso",
        smooth_group="belt_loops",
        rot_y=0.18,
    )

    # 3. Main Torso & Weathered Field Jacket (y = 0.955 .. 1.452), region = "torso"
    n_torso = 32
    torso_levels = [
        # (y, rx, rz, z_off)
        (0.955, 0.167, 0.115, 0.000),
        (0.985, 0.169, 0.116, 0.000),
        (1.045, 0.172, 0.118, -0.002),
        (1.120, 0.181, 0.125, -0.002),  # Torso joint
        (1.195, 0.194, 0.132, 0.000),
        (1.260, 0.205, 0.138, 0.004),
        (1.320, 0.214, 0.137, 0.004),   # Chest joint
        (1.368, 0.218, 0.127, 0.002),
        (1.400, 0.214, 0.114, 0.000),   # Shoulder / Arm centerline
        (1.425, 0.184, 0.098, -0.002),  # Smooth shoulder-to-trapezius blend
        (1.440, 0.122, 0.080, -0.002),
        (1.452, 0.068, 0.066, -0.001),
    ]

    torso_rings = []
    for y, rx, rz, cz in torso_levels:
        pts = []
        uvs = []
        for j in range(n_torso):
            theta = -math.pi + (2.0 * math.pi * j) / n_torso
            ct = math.cos(theta)
            st = math.sin(theta)

            # Rectangular-organic chest/waist cross-section
            sq = 1.0 + 0.045 * math.cos(4.0 * theta)
            # Pectoral shelf across upper chest front (+Z)
            pec = 1.0 + 0.065 * gauss(y, 1.29, 0.048) * max(0.0, ct) * (0.4 + 0.6 * abs(math.sin(2.0 * theta)))
            # Center sternum groove & slight spine groove (-Z)
            sternum = -0.005 * gauss(y, 1.29, 0.05) * gauss(theta, 0.0, 0.16)
            spine = -0.008 * smoothstep(1.00, 1.38, y) * gauss(abs(theta), math.pi, 0.24)
            # Upper V-neck dip at front center so undershirt shows cleanly
            v_cut = -0.012 * smoothstep(1.33, 1.43, y) * gauss(theta, 0.0, 0.28)

            x = rx * st * sq
            z = cz + rz * ct * sq * pec + sternum + spine + v_cut
            pts.append((x, y, z))
            uvs.append(jacket_uv_from_y_theta(y, theta))
        uvs.append(jacket_uv_from_y_theta(y, math.pi))
        torso_rings.append({"points": pts, "uvs": uvs, "region": "torso"})

    mb.add_lofted_tube(
        "field_jacket_torso",
        torso_rings,
        smooth_group="jacket_torso",
        cap_start=True,
        cap_end=True,
        start_center=(0.0, 0.950, 0.0),
        end_center=(0.0, 1.448, 0.0),
    )

    # 4. Dark Undershirt V-Neck Chest Insert (y = 1.305 .. 1.454), region = "torso"
    n_under = 16
    under_levels = [
        (1.305, 0.042, 0.125),
        (1.355, 0.055, 0.128),
        (1.405, 0.062, 0.106),
        (1.438, 0.064, 0.078),
        (1.454, 0.060, 0.064),
    ]
    under_rings = []
    for y, rx, rz in under_levels:
        t = (y - 1.305) / (1.454 - 1.305)
        pts = []
        uvs = []
        for j in range(n_under):
            theta = -math.pi + (2.0 * math.pi * j) / n_under
            pts.append((rx * math.sin(theta), y, 0.015 + rz * math.cos(theta) * (0.65 if math.cos(theta) < 0 else 1.0)))
            uvs.append(map_uv("undershirt", j / n_under, 1.0 - t))
        uvs.append(map_uv("undershirt", 1.0, 1.0 - t))
        under_rings.append({"points": pts, "uvs": uvs, "region": "torso"})
    mb.add_lofted_tube("undershirt_insert", under_rings, smooth_group="undershirt", cap_start=True, cap_end=True)

    # 5. Turned-Down Field Jacket Collar (y = 1.425 .. 1.482, open front V), region = "torso"
    # Max y=1.482 (< 1.49 Neck) so FPP never clips collar
    n_col = 26
    col_levels = [
        (1.425, 0.070, 0.068, 0.000),
        (1.448, 0.080, 0.077, -0.003),
        (1.472, 0.085, 0.080, -0.006),
        (1.482, 0.074, 0.070, -0.004),
    ]
    col_rings = []
    for ci, (y, rx, rz, zoff) in enumerate(col_levels):
        t = ci / (len(col_levels) - 1)
        pts = []
        uvs = []
        for j in range(n_col):
            theta = -math.pi + (2.0 * math.pi * j) / n_col
            front_tuck = 1.0 - 0.34 * gauss(theta, 0.0, 0.34)
            # Slight lapel point dip in front above y=1.455
            lapel_y = y - (0.014 * gauss(abs(theta), 0.42, 0.18) if ci >= 2 else 0.0)
            pts.append((rx * math.sin(theta) * front_tuck, lapel_y, zoff + rz * math.cos(theta) * front_tuck))
            uvs.append(map_uv("jacket_body", 0.5 + theta / (2.0 * math.pi), 0.12 - 0.08 * t))
        uvs.append(map_uv("jacket_body", 1.0, 0.12 - 0.08 * t))
        col_rings.append({"points": pts, "uvs": uvs, "region": "torso"})
    mb.add_lofted_tube("jacket_collar", col_rings, smooth_group="collar", cap_start=True, cap_end=True)

    # 6. Front Storm Placket & 4 Brass/Horn Buttons (y = 0.965 .. 1.330)
    mb.add_bevel_box(
        "jacket_placket",
        center=(0.0, 1.150, 0.130),
        half_extents=(0.024, 0.185, 0.014),
        bevel=0.004,
        uv_island="jacket_body",
        region="torso",
        smooth_group="jacket_placket",
        rot_x=-0.06,
    )
    for by, bz in [(1.02, 0.128), (1.11, 0.134), (1.20, 0.141), (1.29, 0.145)]:
        mb.add_bevel_box(
            "jacket_button",
            center=(0.0, by, bz),
            half_extents=(0.008, 0.008, 0.004),
            bevel=0.002,
            uv_island="buckle",
            region="torso",
            smooth_group="jacket_button",
        )

    # 7. Left & Right Chest Flap Pockets + Lower Hip Pockets
    for sign in (1.0, -1.0):
        # Chest pocket body + flap
        mb.add_bevel_box(
            "chest_pocket",
            center=(sign * 0.095, 1.255, 0.133),
            half_extents=(0.040, 0.044, 0.011),
            bevel=0.003,
            uv_island="jacket_body",
            region="torso",
            smooth_group="jacket_pocket",
            rot_y=sign * 0.30,
            rot_x=-0.10,
        )
        mb.add_bevel_box(
            "chest_pocket_flap",
            center=(sign * 0.096, 1.292, 0.138),
            half_extents=(0.042, 0.013, 0.013),
            bevel=0.003,
            uv_island="jacket_body",
            region="torso",
            smooth_group="jacket_pocket_flap",
            rot_y=sign * 0.30,
            rot_x=-0.10,
        )
        # Lower hip pocket body + flap
        mb.add_bevel_box(
            "hip_pocket",
            center=(sign * 0.105, 1.035, 0.112),
            half_extents=(0.044, 0.046, 0.011),
            bevel=0.003,
            uv_island="jacket_body",
            region="torso",
            smooth_group="jacket_hip_pocket",
            rot_y=sign * 0.48,
        )
        mb.add_bevel_box(
            "hip_pocket_flap",
            center=(sign * 0.106, 1.074, 0.115),
            half_extents=(0.046, 0.013, 0.013),
            bevel=0.003,
            uv_island="jacket_body",
            region="torso",
            smooth_group="jacket_hip_flap",
            rot_y=sign * 0.48,
        )

    # 8. Lower Neck Base inside body-mesh (y = 1.415 .. 1.492)
    # Buried lower portion (y <= 1.44) tagged "torso", exposed lower neck (y > 1.44) tagged "neck"
    n_neck = 24
    neck_levels = [1.415, 1.440, 1.466, 1.492]
    neck_rings = []
    for y in neck_levels:
        t = (y - 1.415) / (1.492 - 1.415)
        rx = lerp(0.062, 0.050, t)
        rz = lerp(0.064, 0.052, t)
        reg = "torso" if y <= 1.442 else "neck"
        pts = []
        uvs = []
        for j in range(n_neck):
            theta = -math.pi + (2.0 * math.pi * j) / n_neck
            pts.append((rx * math.sin(theta), y, rz * math.cos(theta)))
            uvs.append(map_uv("limb_skin", j / n_neck, lerp(0.45, 0.05, t)))
        uvs.append(map_uv("limb_skin", 1.0, lerp(0.45, 0.05, t)))
        neck_rings.append({"points": pts, "uvs": uvs, "region": reg})
    mb.add_lofted_tube(
        "lower_neck_base",
        neck_rings,
        smooth_group="lower_neck",
        cap_start=True,
        cap_end=True,
        end_cap_region="neck",
    )


def arm_centerline_yz(x):
    """Smooth centerline passing through UpperArm(0.21,1.40,0), LowerArm(0.49,1.40,-0.01), Hand(0.75,1.40,0)."""
    # Parabolic curve in z passing through (0.21, 0), (0.49, -0.01), (0.75, 0)
    # Using Lagrange interpolation on t = (x - 0.21) / (0.75 - 0.21)
    # At x=0.49, t_mid = 0.28 / 0.54 = 0.51852
    t = clamp((x - 0.21) / 0.54, 0.0, 1.0)
    t_mid = 0.28 / 0.54
    z = -0.01 * (t * (1.0 - t)) / (t_mid * (1.0 - t_mid)) if x > 0.21 else 0.0
    return (1.40, z)


def build_arm(mb, side="L"):
    """Build sleeve, rolled cuff, forearm, and sculpted hand (palm + thumb + 4 grouped fingers)."""
    mirror_x = (side == "R")
    reg = "arm_l" if side == "L" else "arm_r"
    n_arm = 20

    # 1. Jacket Upper Sleeve (x = 0.155 .. 0.445)
    sleeve_x = [0.155, 0.180, 0.210, 0.245, 0.295, 0.345, 0.395, 0.428, 0.445]
    sleeve_samples = []
    for x in sleeve_x:
        cy, cz = arm_centerline_yz(x)
        t = (x - 0.155) / (0.445 - 0.155)
        if x < 0.21:
            st = (x - 0.155) / (0.210 - 0.155)
            ry = lerp(0.058, 0.064, smoothstep(0.0, 1.0, st))
            rz = lerp(0.056, 0.063, smoothstep(0.0, 1.0, st))
            # Slightly drop shoulder center near torso so top trapezius-to-deltoid slope is seamless
            cy -= 0.008 * (1.0 - smoothstep(0.0, 1.0, st))
        elif x < 0.26:
            ry = lerp(0.064, 0.059, (x - 0.21) / 0.05)
            rz = lerp(0.063, 0.058, (x - 0.21) / 0.05)
        else:
            bt = (x - 0.26) / (0.445 - 0.26)
            ry = lerp(0.059, 0.054, bt) + 0.004 * math.sin(bt * math.pi)
            rz = lerp(0.058, 0.053, bt) + 0.004 * math.sin(bt * math.pi)

        def sleeve_mod(theta, cu, cv, xx=x):
            fold = 1.0 + 0.035 * math.sin(3.0 * theta + xx * 18.0)
            return cu * fold, cv * fold

        sleeve_samples.append(((x, cy, cz), ry, rz, t, sleeve_mod))

    sleeve_rings = build_oriented_tube_rings(
        sleeve_samples, n_arm, axis_dir=(1, 0, 0), ref_u=(0, 1, 0),
        uv_island="jacket_sleeve", region=reg
    )
    mb.add_lofted_tube(
        f"sleeve_{side}",
        sleeve_rings,
        smooth_group=f"sleeve_{side}",
        cap_start=True,
        cap_end=True,
        start_center=(0.150, 1.392, 0.0),
        mirror_x=mirror_x,
    )

    # 2. Rolled Sleeve Cuff (x = 0.422 .. 0.456)
    cuff_x = [0.422, 0.430, 0.442, 0.452, 0.456]
    cuff_r = [0.053, 0.061, 0.062, 0.058, 0.048]
    cuff_samples = []
    for ci, x in enumerate(cuff_x):
        cy, cz = arm_centerline_yz(x)
        r = cuff_r[ci]
        v_loc = lerp(0.75, 0.98, ci / (len(cuff_x) - 1))
        cuff_samples.append(((x, cy, cz), r, r, v_loc))
    cuff_rings = build_oriented_tube_rings(
        cuff_samples, n_arm, axis_dir=(1, 0, 0), ref_u=(0, 1, 0),
        uv_island="jacket_sleeve", region=reg
    )
    mb.add_lofted_tube(
        f"rolled_cuff_{side}",
        cuff_rings,
        smooth_group=f"cuff_{side}",
        cap_start=True,
        cap_end=True,
        mirror_x=mirror_x,
    )

    # 3. Bare Forearm passing directly through LowerArm(0.49, 1.40, -0.01) to Hand(0.75, 1.40, 0.0)
    forearm_x = [0.440, 0.468, 0.490, 0.515, 0.555, 0.605, 0.660, 0.715, 0.750]
    forearm_samples = []
    for x in forearm_x:
        cy, cz = arm_centerline_yz(x)
        t = (x - 0.440) / (0.750 - 0.440)
        if x < 0.490:
            st = (x - 0.440) / 0.050
            ry = lerp(0.047, 0.045, st)
            rz = lerp(0.048, 0.046, st)
        elif x < 0.560:
            st = (x - 0.490) / 0.070
            ry = lerp(0.045, 0.047, st)
            rz = lerp(0.046, 0.051, st)
        else:
            st = clamp((x - 0.560) / (0.750 - 0.560), 0.0, 1.0)
            ry = lerp(0.047, 0.019, smoothstep(0.0, 1.0, st))
            rz = lerp(0.051, 0.031, smoothstep(0.0, 1.0, st))

        def arm_mod(theta, cu, cv, xx=x):
            elbow_b = 1.0 + 0.05 * gauss(xx, 0.490, 0.022) * max(0.0, -math.sin(theta))
            return cu, cv * elbow_b

        forearm_samples.append(((x, cy, cz), ry, rz, lerp(0.05, 0.70, t), arm_mod))

    forearm_rings = build_oriented_tube_rings(
        forearm_samples, n_arm, axis_dir=(1, 0, 0), ref_u=(0, 1, 0),
        uv_island="limb_skin", region=reg
    )
    mb.add_lofted_tube(
        f"forearm_{side}",
        forearm_rings,
        smooth_group=f"forearm_{side}",
        cap_start=True,
        cap_end=True,
        mirror_x=mirror_x,
    )

    # 4. Sculpted Palm (x = 0.742 .. 0.824): palm down/inward slightly, thumb forward +Z
    palm_x = [0.742, 0.752, 0.774, 0.798, 0.818, 0.825]
    palm_samples = []
    for x in palm_x:
        t = (x - 0.742) / (0.825 - 0.742)
        cy = 1.40 - 0.006 * t * t
        cz = 0.002 * math.sin(t * math.pi)
        ry = lerp(0.023, 0.013, smoothstep(0.15, 1.0, t))
        rz = lerp(0.034, 0.042, smoothstep(0.0, 0.82, t)) * (0.88 if t > 0.94 else 1.0)

        def palm_mod(theta, cu, cv):
            flat = 1.0 - 0.14 * math.cos(2.0 * theta)
            return cu * flat, cv * (1.0 + 0.06 * math.cos(2.0 * theta))

        palm_samples.append(((x, cy, cz), ry, rz, lerp(0.70, 0.88, t), palm_mod))

    palm_rings = build_oriented_tube_rings(
        palm_samples, 16, axis_dir=(1, 0, 0), ref_u=(0, 1, 0),
        uv_island="limb_skin", region=reg
    )
    mb.add_lofted_tube(
        f"palm_{side}",
        palm_rings,
        smooth_group=f"hand_{side}",
        cap_start=True,
        cap_end=True,
        end_center=(0.829, 1.394, 0.001),
        mirror_x=mirror_x,
    )

    # 5. Thumb (forward +Z, slightly angled +X and curled slightly down -Y)
    thumb_pts = [
        ((0.760, 1.397, 0.026), 0.013, 0.013, 0.74),
        ((0.785, 1.392, 0.046), 0.0115, 0.0115, 0.80),
        ((0.808, 1.387, 0.063), 0.010, 0.010, 0.86),
        ((0.826, 1.382, 0.075), 0.0085, 0.0085, 0.93),
    ]
    thumb_dir = v_sub(thumb_pts[-1][0], thumb_pts[0][0])
    thumb_rings = build_oriented_tube_rings(
        thumb_pts, 10, axis_dir=thumb_dir, ref_u=(0, 1, 0),
        uv_island="limb_skin", region=reg
    )
    tip_t = v_add(thumb_pts[-1][0], v_mul(v_norm(thumb_dir), 0.007))
    mb.add_lofted_tube(
        f"thumb_{side}",
        thumb_rings,
        smooth_group=f"thumb_{side}",
        cap_start=True,
        cap_end=True,
        end_center=tip_t,
        mirror_x=mirror_x,
    )

    # 6. Four closely grouped relaxed fingers (Index, Middle, Ring, Pinky)
    finger_specs = [
        ("index",  0.030, 0.074, 0.0095),
        ("middle", 0.010, 0.080, 0.0098),
        ("ring",  -0.010, 0.075, 0.0092),
        ("pinky", -0.029, 0.061, 0.0082),
    ]
    for fname, fz, flen, frad in finger_specs:
        base_x = 0.812 if fname != "pinky" else 0.807
        base_y = 1.395
        f_samples = []
        for st in (0.0, 0.35, 0.72, 1.0):
            fx = base_x + flen * st
            fy = base_y - 0.015 * (st ** 1.6)
            r = frad * lerp(1.06, 0.72, st)
            f_samples.append(((fx, fy, fz), r * 0.92, r * 1.02, lerp(0.84, 0.96, st)))
        f_rings = build_oriented_tube_rings(
            f_samples, 10, axis_dir=(1, 0, 0), ref_u=(0, 1, 0),
            uv_island="limb_skin", region=reg
        )
        f_tip = (base_x + flen + 0.005, base_y - 0.017, fz)
        mb.add_lofted_tube(
            f"finger_{fname}_{side}",
            f_rings,
            smooth_group=f"finger_{fname}_{side}",
            cap_start=True,
            cap_end=True,
            end_center=f_tip,
            mirror_x=mirror_x,
        )


def leg_centerline_xz(y):
    """Smooth centerline passing through UpperLeg(0.105,0.90,0), LowerLeg(0.105,0.49,0.01), Foot(0.105,0.09,0.02)."""
    t = clamp((0.90 - y) / (0.90 - 0.09), 0.0, 1.0)
    return (0.105, 0.020 * t)


def build_leg(mb, side="L"):
    """Build cargo trousers leg, thigh cargo pocket, lace-up boot, toe vamp, and lug sole on y=0.0."""
    mirror_x = (side == "R")
    reg = "leg_l" if side == "L" else "leg_r"
    n_leg = 20

    # 1. Cargo Trousers Leg (from y=0.205 boot cuff tuck up to y=0.920 hip socket)
    leg_y = [0.205, 0.222, 0.275, 0.355, 0.440, 0.468, 0.490, 0.515, 0.555, 0.640, 0.735, 0.830, 0.875, 0.900, 0.920]
    leg_rings = []
    for y in leg_y:
        cx, cz = leg_centerline_xz(y)
        t_v = (0.920 - y) / (0.920 - 0.205)
        if y < 0.230:
            # Trouser leg slightly gathered/tucked inside rugged boot collar
            rx = lerp(0.045, 0.055, (y - 0.205) / 0.025)
            rz = lerp(0.048, 0.058, (y - 0.205) / 0.025)
        elif y < 0.455:
            ct = (y - 0.230) / (0.455 - 0.230)
            calf_swell = math.sin(ct * math.pi)
            rx = lerp(0.054, 0.059, ct) + 0.008 * calf_swell
            rz = lerp(0.056, 0.063, ct) + 0.011 * calf_swell
            cz -= 0.006 * calf_swell
        elif y < 0.530:
            rx = 0.060
            rz = 0.064
        else:
            tt = (y - 0.530) / (0.920 - 0.530)
            rx = lerp(0.061, 0.082, smoothstep(0.0, 0.80, tt)) * (0.90 if y > 0.905 else 1.0)
            rz = lerp(0.065, 0.090, smoothstep(0.0, 0.80, tt)) * (0.90 if y > 0.905 else 1.0)

        pts = []
        uvs = []
        for j in range(n_leg):
            theta = -math.pi + (2.0 * math.pi * j) / n_leg
            patella = 1.0 + 0.05 * gauss(y, 0.495, 0.025) * max(0.0, math.cos(theta))
            crease = 1.0 + 0.025 * math.cos(4.0 * theta)
            x = cx + rx * math.sin(theta) * crease
            z = cz + rz * math.cos(theta) * patella * crease
            pts.append((x, y, z))
            uvs.append(map_uv("trousers", j / n_leg, lerp(0.04, 0.94, t_v)))
        uvs.append(map_uv("trousers", 1.0, lerp(0.04, 0.94, t_v)))
        leg_rings.append({"points": pts, "uvs": uvs, "region": reg})

    mb.add_lofted_tube(
        f"trouser_leg_{side}",
        leg_rings,
        smooth_group=f"trouser_leg_{side}",
        cap_start=True,
        cap_end=True,
        end_center=(0.105, 0.925, 0.0),
        mirror_x=mirror_x,
    )

    # 2. Outer Thigh Cargo Pocket + Flap
    mb.add_bevel_box(
        f"cargo_pocket_{side}",
        center=(0.178, 0.675, 0.005),
        half_extents=(0.012, 0.062, 0.046),
        bevel=0.003,
        uv_island="trousers",
        region=reg,
        smooth_group=f"cargo_pocket_{side}",
        mirror_x=mirror_x,
    )
    mb.add_bevel_box(
        f"cargo_flap_{side}",
        center=(0.180, 0.728, 0.005),
        half_extents=(0.014, 0.016, 0.048),
        bevel=0.003,
        uv_island="trousers",
        region=reg,
        smooth_group=f"cargo_flap_{side}",
        mirror_x=mirror_x,
    )

    # 3. Boot Shaft (y = 0.022 .. 0.218, centered near ankle x=0.105, z=0.018)
    n_boot = 20
    shaft_levels = [
        (0.022, 0.050, 0.072, 0.012),
        (0.055, 0.049, 0.068, 0.016),
        (0.090, 0.047, 0.056, 0.020),  # Foot.L ankle height
        (0.135, 0.048, 0.053, 0.018),
        (0.185, 0.050, 0.054, 0.016),
        (0.214, 0.055, 0.058, 0.016),  # Boot collar rim clearly proud of tucked trousers
        (0.220, 0.048, 0.051, 0.016),
    ]
    shaft_rings = []
    for si, (y, rx, rz, cz) in enumerate(shaft_levels):
        v_loc = lerp(0.95, 0.05, si / (len(shaft_levels) - 1))
        pts = []
        uvs = []
        for j in range(n_boot):
            theta = -math.pi + (2.0 * math.pi * j) / n_boot
            heel = 1.0 + 0.10 * gauss(y, 0.05, 0.025) * max(0.0, -math.cos(theta))
            pts.append((0.105 + rx * math.sin(theta), y, cz + rz * math.cos(theta) * heel))
            uvs.append(map_uv("boot_leather", j / n_boot, v_loc))
        uvs.append(map_uv("boot_leather", 1.0, v_loc))
        shaft_rings.append({"points": pts, "uvs": uvs, "region": reg})

    mb.add_lofted_tube(
        f"boot_shaft_{side}",
        shaft_rings,
        smooth_group=f"boot_shaft_{side}",
        cap_start=True,
        cap_end=True,
        mirror_x=mirror_x,
    )

    # 4. Boot Lace-Up Front Tongue & Eyelets Panel (y = 0.078 .. 0.204, front +Z)
    # Build with planar front UV projection so the 5 cross-laces stay centered on the tongue!
    lace_v_start = len(mb.positions)
    mb.add_bevel_box(
        f"boot_laces_{side}",
        center=(0.105, 0.142, 0.068),
        half_extents=(0.020, 0.062, 0.011),
        bevel=0.003,
        uv_island="boot_laces",
        region=reg,
        smooth_group=f"boot_laces_{side}",
        rot_x=-0.10,
        mirror_x=mirror_x,
    )
    for vi in range(lace_v_start, len(mb.positions)):
        px_v, py_v, _ = mb.positions[vi]
        lx_ref = -px_v if mirror_x else px_v
        u_l = clamp((lx_ref - 0.105) / 0.044 + 0.5, 0.04, 0.96)
        v_l = clamp((0.204 - py_v) / 0.124, 0.04, 0.96)
        mb.uvs[vi] = map_uv("boot_laces", u_l, v_l)

    # 5. Boot Toe Box / Vamp (lofted forward along +Z from z=0.015 to z=0.186)
    vamp_z = [0.015, 0.055, 0.100, 0.145, 0.175, 0.186]
    vamp_samples = []
    for vi, z in enumerate(vamp_z):
        t = vi / (len(vamp_z) - 1)
        top_y = lerp(0.088, 0.052, smoothstep(0.0, 0.92, t))
        bot_y = 0.020
        cy = 0.5 * (top_y + bot_y)
        ry = 0.5 * (top_y - bot_y)
        rx = lerp(0.049, 0.047, t * 0.5) * (0.72 if vi == len(vamp_z) - 1 else 1.0)

        def vamp_mod(theta, cu, cv):
            flat_bot = 1.0 - 0.15 * max(0.0, -math.cos(theta))
            sq = 1.0 + 0.06 * math.cos(4.0 * theta)
            return cu * flat_bot * sq, cv * sq

        vamp_samples.append(((0.105, cy, z), ry, rx, lerp(0.10, 0.90, t), vamp_mod))

    vamp_rings = build_oriented_tube_rings(
        vamp_samples, 18, axis_dir=(0, 0, 1), ref_u=(0, 1, 0),
        uv_island="boot_leather", region=reg
    )
    # Remap vamp UVs vertically by vertex Y (so mud at bottom of boot_leather matches sole height!)
    for r in vamp_rings:
        new_uvs = []
        for j, pt in enumerate(r["points"]):
            u_l = (pt[2] - 0.015) / 0.175
            v_l = clamp((0.120 - pt[1]) / 0.105, 0.15, 0.96)
            new_uvs.append(map_uv("boot_leather", clamp(u_l, 0.05, 0.95), v_l))
        new_uvs.append(new_uvs[0])
        r["uvs"] = new_uvs

    mb.add_lofted_tube(
        f"boot_vamp_{side}",
        vamp_rings,
        smooth_group=f"boot_vamp_{side}",
        cap_start=True,
        cap_end=True,
        end_center=(0.105, 0.034, 0.192),
        end_cap_uv=map_uv("boot_leather", 0.95, 0.85),
        mirror_x=mirror_x,
    )

    # 6. Rugged Boot Sole + Distinct Heel strictly touching y = 0.000!
    # Heel block: y = 0.000 .. 0.023, z = -0.058 .. +0.015
    mb.add_bevel_box(
        f"boot_heel_{side}",
        center=(0.105, 0.0115, -0.021),
        half_extents=(0.048, 0.0115, 0.038),
        bevel=0.004,
        uv_island="boot_sole",
        region=reg,
        smooth_group=f"boot_sole_{side}",
        mirror_x=mirror_x,
    )
    # Midsole bridge + forefoot lug sole: y = 0.000 .. 0.022, z = +0.045 .. +0.193
    mb.add_bevel_box(
        f"boot_fore_sole_{side}",
        center=(0.105, 0.011, 0.119),
        half_extents=(0.051, 0.011, 0.075),
        bevel=0.004,
        uv_island="boot_sole",
        region=reg,
        smooth_group=f"boot_sole_{side}",
        mirror_x=mirror_x,
    )
    # Arch bridge slightly recessed above y=0.005 so side silhouette shows distinct heel!
    mb.add_bevel_box(
        f"boot_arch_{side}",
        center=(0.105, 0.014, 0.030),
        half_extents=(0.044, 0.009, 0.022),
        bevel=0.003,
        uv_island="boot_sole",
        region=reg,
        smooth_group=f"boot_sole_{side}",
        mirror_x=mirror_x,
    )


# ---------------------------------------------------------------------------
# Anatomy Builders: Head Mesh (Separate for FPP)
# ---------------------------------------------------------------------------

def build_head_and_hair(mb):
    """Build upper neck, sculpted male head (jaw, brow, nose, sockets), ears, and layered dark hair."""
    # 1. Sculpted Upper Neck + Head (y = 1.475 .. 1.745), 48 warped radial segments x 28 rings
    n_head = 48
    y_vals = [
        1.475, 1.490, 1.508, 1.525, 1.538,  # Upper neck -> submental transition
        1.546, 1.555, 1.565, 1.576, 1.586,  # Chin, lower jaw, mouth
        1.596, 1.605, 1.615, 1.624, 1.633,  # Upper lip, nose tip, cheeks, eyes
        1.642, 1.651, 1.662, 1.675, 1.690,  # Brow ridge, lower forehead
        1.706, 1.720, 1.732, 1.740, 1.745,  # Upper forehead -> crown
    ]

    head_rings = []
    for y in y_vals:
        reg = "neck" if y <= 1.530 else "head"
        pts = []
        uvs = []
        for j in range(n_head):
            s = j / n_head
            theta_lin = -math.pi + 2.0 * math.pi * s
            # Concentrate angular resolution across front face (theta ~ 0)
            theta = theta_lin - 0.40 * math.sin(theta_lin)

            # Base head envelope
            if y < 1.535:
                nt = (y - 1.475) / (1.535 - 1.475)
                rx = lerp(0.050, 0.051, nt)
                rz = lerp(0.052, 0.054, nt)
                cz = lerp(0.000, 0.006, nt)
            else:
                ht = clamp((y - 1.535) / (1.745 - 1.535), 0.0, 1.0)
                rx = (
                    0.061
                    + 0.017 * math.sin(ht * math.pi * 0.92)
                    - 0.004 * (1.0 - smoothstep(0.0, 0.25, ht))
                ) * math.sqrt(max(0.04, 1.0 - max(0.0, (ht - 0.72) / 0.28) ** 2.1))
                rz = (
                    0.072
                    + 0.025 * math.sin(ht * math.pi * 0.88)
                ) * math.sqrt(max(0.04, 1.0 - max(0.0, (ht - 0.72) / 0.28) ** 2.1))
                cz = 0.010 - 0.005 * smoothstep(0.25, 0.95, ht)

            ct = math.cos(theta)
            st = math.sin(theta)
            x = rx * st
            z = cz + rz * ct

            if y >= 1.535:
                # 1. Square male chin & jaw angles + crisp submental tuck
                chin_proj = 0.021 * gauss(y, 1.554, 0.014) * gauss(theta, 0.0, 0.34)
                jaw_angle = 0.010 * gauss(y, 1.564, 0.016) * gauss(abs(theta), 0.95, 0.28)
                submental = -0.012 * gauss(y, 1.538, 0.008) * max(0.0, ct)

                # 2. Zygomatic cheekbones
                cheekbone = 0.006 * gauss(y, 1.616, 0.018) * gauss(abs(theta), 0.68, 0.25)

                # 3. Gentle orbital eye sockets
                eye_socket = -0.006 * gauss(y, 1.636, 0.012) * gauss(abs(theta), 0.34, 0.14)

                # 4. Masculine brow ridge
                brow_ridge = 0.006 * gauss(y, 1.652, 0.010) * gauss(theta, 0.0, 0.45)

                # 5. Sculpted nose bridge, tip, and nostrils
                nose_bridge = 0.015 * smoothstep(1.595, 1.612, y) * (1.0 - smoothstep(1.630, 1.650, y)) * gauss(theta, 0.0, 0.105)
                nose_tip = 0.013 * gauss(y, 1.604, 0.010) * gauss(theta, 0.0, 0.115)
                nostrils = 0.006 * gauss(y, 1.600, 0.007) * gauss(abs(theta), 0.13, 0.065)

                # 6. Lips / mouth protrusion
                upper_lip = 0.007 * gauss(y, 1.584, 0.006) * gauss(theta, 0.0, 0.22)
                lower_lip = 0.006 * gauss(y, 1.572, 0.006) * gauss(theta, 0.0, 0.20)
                lip_part = -0.003 * gauss(y, 1.578, 0.0025) * gauss(theta, 0.0, 0.18)

                dz_face = chin_proj + submental + eye_socket + brow_ridge + nose_bridge + nose_tip + nostrils + upper_lip + lower_lip + lip_part
                dx_face = sign_x(theta) * (jaw_angle + cheekbone)
                x += dx_face
                z += dz_face
            else:
                z += 0.004 * gauss(y, 1.512, 0.010) * gauss(theta, 0.0, 0.20)

            pts.append((x, y, z))
            uvs.append(face_uv_from_y_theta(y, theta))

        uvs.append(face_uv_from_y_theta(y, math.pi))
        head_rings.append({"points": pts, "uvs": uvs, "region": reg})

    mb.add_lofted_tube(
        "head_sculpted",
        head_rings,
        smooth_group="head_skin",
        cap_start=True,
        cap_end=True,
        start_center=(0.0, 1.472, 0.0),
        end_center=(0.0, 1.747, 0.004),
        start_cap_region="neck",
        end_cap_region="head",
    )

    # 2. Left & Right Sculpted Ears (slim vertical oval nestled along side of head)
    ear_samples = [
        ((0.065, 1.617, -0.006), 0.023, 0.011, 0.20),
        ((0.074, 1.617, -0.009), 0.025, 0.013, 0.50),
        ((0.079, 1.616, -0.013), 0.020, 0.010, 0.85),
    ]
    ear_rings = build_oriented_tube_rings(
        ear_samples, 14, axis_dir=(1, 0, -0.35), ref_u=(0, 1, 0),
        uv_island="face_skin", region="head"
    )
    for er in ear_rings:
        er["uvs"] = [map_uv("face_skin", 0.72 + 0.06 * (i / 14.0), 0.50 + 0.05 * math.sin(i * 0.45)) for i in range(15)]
    for ear_side, mir in (("L", False), ("R", True)):
        mb.add_lofted_tube(
            f"ear_{ear_side}",
            ear_rings,
            smooth_group=f"ear_{ear_side}",
            cap_start=True,
            cap_end=True,
            mirror_x=mir,
        )

    # 3. Short Neat Layered Dark Hair with Slight Volume (y = 1.568 .. 1.760)
    n_hair = 48
    hair_y = [1.568, 1.590, 1.615, 1.642, 1.668, 1.688, 1.704, 1.720, 1.738, 1.753, 1.760]
    hair_rings = []
    for y in hair_y:
        t_v = 1.0 - (y - 1.568) / (1.760 - 1.568)
        ht = clamp((y - 1.535) / (1.760 - 1.535), 0.0, 1.0)
        base_rx = (0.068 + 0.018 * math.sin(ht * math.pi * 0.88)) * math.sqrt(max(0.03, 1.0 - max(0.0, (ht - 0.65) / 0.35) ** 2.0))
        base_rz = (0.078 + 0.025 * math.sin(ht * math.pi * 0.86)) * math.sqrt(max(0.03, 1.0 - max(0.0, (ht - 0.65) / 0.35) ** 2.0))
        cz = 0.005 - 0.004 * ht

        pts = []
        uvs = []
        for j in range(n_hair):
            theta = -math.pi + (2.0 * math.pi * j) / n_hair
            ct = math.cos(theta)
            st = math.sin(theta)

            # Smooth natural hairline across forehead + neat sideburns in front of ears
            # Subtle soft natural slight curve across forehead (no jagged step!)
            hairline_y = (
                1.694
                + 0.010 * (1.0 - math.cos(2.0 * theta)) * max(0.0, ct)
                - 0.072 * gauss(abs(theta), 1.44, 0.22)
            )
            in_face_cutout = (1.0 - smoothstep(hairline_y - 0.010, hairline_y + 0.010, y)) * smoothstep(-0.20, 0.18, ct)
            scale_cut = lerp(1.0, 0.50, in_face_cutout)

            layer_wave = 1.0 + 0.025 * math.sin(6.0 * theta + y * 35.0) * smoothstep(1.68, 1.75, y)
            crown_vol = 1.0 + 0.06 * gauss(y, 1.732, 0.020) * (0.65 + 0.35 * max(0.0, ct))

            x = base_rx * st * scale_cut * layer_wave
            z = cz + base_rz * ct * scale_cut * layer_wave * crown_vol
            pts.append((x, y, z))
            uvs.append(map_uv("hair", j / n_hair, clamp(t_v, 0.04, 0.96)))
        uvs.append(map_uv("hair", 1.0, clamp(t_v, 0.04, 0.96)))
        hair_rings.append({"points": pts, "uvs": uvs, "region": "head"})

    mb.add_lofted_tube(
        "male_hair",
        hair_rings,
        smooth_group="hair",
        cap_start=True,
        cap_end=True,
        start_center=(0.0, 1.565, -0.040),
        end_center=(0.0, 1.760, 0.002),
        start_cap_region="head",
        end_cap_region="head",
    )


def sign_x(theta):
    if abs(theta) < 1e-6:
        return 0.0
    return 1.0 if theta > 0.0 else -1.0


# ---------------------------------------------------------------------------
# Procedural 1024x1024 PBR Albedo Texture Painter (Pillow)
# ---------------------------------------------------------------------------

def island_px_rect(island_name, pad=8):
    u0, u1, v0, v1 = UV_ISLANDS[island_name]
    x0 = int(round(u0 * (TEX_SIZE - 1)))
    x1 = int(round(u1 * (TEX_SIZE - 1)))
    y0 = int(round(v0 * (TEX_SIZE - 1)))
    y1 = int(round(v1 * (TEX_SIZE - 1)))
    return (
        max(0, x0 - pad),
        max(0, y0 - pad),
        min(TEX_SIZE - 1, x1 + pad),
        min(TEX_SIZE - 1, y1 + pad),
        x0, y0, x1, y1,
    )


def uv_to_px(u, v):
    return (u * (TEX_SIZE - 1), v * (TEX_SIZE - 1))


def add_weave_noise(img, box, base_rgb, amp_x=6, amp_y=6, grain_amp=8, seed=1):
    """Paint subtle directional cloth weave + weathering noise directly in pixel box."""
    rng = random.Random(seed)
    px = img.load()
    bx0, by0, bx1, by1 = box
    br, bg, bb = base_rgb
    for y in range(by0, by1 + 1):
        wy = math.sin(y * 0.95) * amp_y
        for x in range(bx0, bx1 + 1):
            wx = math.sin(x * 0.95) * amp_x
            n = rng.randint(-grain_amp, grain_amp)
            r = int(clamp(br + wx + wy + n, 0, 255))
            g = int(clamp(bg + wx + wy + n, 0, 255))
            b = int(clamp(bb + wx + wy + n, 0, 255))
            px[x, y] = (r, g, b, 255)


def paint_face_island(img):
    """Paint warm Indonesian male skin, eyes, iris, brows, nose shadow, lips, and stubble."""
    bx0, by0, bx1, by1, x0, y0, x1, y1 = island_px_rect("face_skin", pad=12)
    draw = ImageDraw.Draw(img, "RGBA")

    # Warm Indonesian medium-tan olive-brown skin base
    base_skin = (176, 123, 91)
    add_weave_noise(img, (bx0, by0, bx1, by1), base_skin, amp_x=1, amp_y=1, grain_amp=4, seed=42)

    px = img.load()
    u0, u1, v0, v1 = UV_ISLANDS["face_skin"]
    rng_stubble = random.Random(901)
    for py in range(by0, by1 + 1):
        v_loc = (py / (TEX_SIZE - 1) - v0) / (v1 - v0)
        y_m = HEAD_Y_MAX - v_loc * (HEAD_Y_MAX - HEAD_Y_MIN)
        for px_i in range(bx0, bx1 + 1):
            u_loc = (px_i / (TEX_SIZE - 1) - u0) / (u1 - u0)
            theta = (u_loc - 0.5) * 2.0 * math.pi

            r, g, b, _ = px[px_i, py]
            neck_sh = 1.0 - 0.22 * (1.0 - smoothstep(1.505, 1.552, y_m)) * (0.4 + 0.6 * max(0.0, math.cos(theta)))
            cheek_w = gauss(y_m, 1.608, 0.020) * gauss(abs(theta), 0.55, 0.24)
            socket_sh = 1.0 - 0.12 * gauss(y_m, 1.635, 0.013) * gauss(abs(theta), 0.34, 0.13)
            nose_hi = 18.0 * gauss(y_m, 1.622, 0.020) * gauss(theta, 0.0, 0.045)
            nose_side = -14.0 * gauss(y_m, 1.615, 0.016) * gauss(abs(theta), 0.095, 0.035)
            brow_hi = 10.0 * gauss(y_m, 1.652, 0.012) * gauss(theta, 0.0, 0.32)

            # Soft organic contoured jaw/chin/mustache stubble mask (no hard rectangle!)
            jaw_band = gauss(y_m, 1.555, 0.018) * gauss(theta, 0.0, 0.58)
            mustache_band = gauss(y_m, 1.588, 0.005) * gauss(theta, 0.0, 0.17)
            lip_hole = gauss(y_m, 1.577, 0.007) * gauss(theta, 0.0, 0.20)
            stubble_w = clamp((jaw_band * 0.85 + mustache_band * 0.75) * (1.0 - lip_hole), 0.0, 1.0)
            stubble_grain = rng_stubble.uniform(0.4, 1.0) if stubble_w > 0.12 else 0.0
            stubble_dark = 1.0 - 0.20 * stubble_w * stubble_grain

            nr = clamp((r * neck_sh * socket_sh + cheek_w * 16 + nose_hi + nose_side + brow_hi) * stubble_dark, 0, 255)
            ng = clamp((g * neck_sh * socket_sh + cheek_w * 5 + nose_hi * 0.8 + nose_side * 0.9 + brow_hi * 0.8) * stubble_dark, 0, 255)
            nb = clamp((b * neck_sh * socket_sh + cheek_w * 2 + nose_hi * 0.6 + nose_side * 0.8 + brow_hi * 0.6) * stubble_dark, 0, 255)
            px[px_i, py] = (int(nr), int(ng), int(nb), 255)

    def ft_px(ym, th):
        u, v = face_uv_from_y_theta(ym, th)
        return uv_to_px(u, v)

    # Paint Eyes, Iris, Eyelids, Eyebrows at exact 3D socket angles (theta = +-0.34, y = 1.635)
    for side_s in (-1.0, 1.0):
        eth = side_s * 0.34
        ex, ey = ft_px(1.635, eth)
        ex_in, _ = ft_px(1.635, eth - side_s * 0.13)
        ex_out, _ = ft_px(1.635, eth + side_s * 0.13)
        ew = abs(ex_out - ex_in) * 0.56
        eh = ew * 0.46

        # Soft upper eyelid crease shadow
        draw.arc(
            [ex - ew * 1.15, ey - eh * 1.9, ex + ew * 1.15, ey + eh * 0.8],
            start=198, end=342, fill=(84, 52, 37, 130), width=1
        )
        # Sclera almond
        draw.ellipse([ex - ew, ey - eh, ex + ew, ey + eh], fill=(226, 217, 210, 255))
        draw.pieslice([ex - ew, ey - eh, ex + ew, ey + eh], start=190, end=350, fill=(182, 162, 150, 95))
        # Dark Indonesian brown iris & pupil + crisp catchlight
        ir_r = eh * 0.88
        draw.ellipse([ex - ir_r, ey - ir_r, ex + ir_r, ey + ir_r], fill=(40, 25, 16, 255))
        draw.ellipse([ex - ir_r * 0.72, ey - ir_r * 0.72, ex + ir_r * 0.72, ey + ir_r * 0.72], fill=(58, 37, 24, 255))
        pu_r = ir_r * 0.45
        draw.ellipse([ex - pu_r, ey - pu_r, ex + pu_r, ey + pu_r], fill=(12, 10, 10, 255))
        draw.ellipse([ex - ir_r * 0.44, ey - ir_r * 0.48, ex - ir_r * 0.14, ey - ir_r * 0.18], fill=(248, 244, 238, 220))
        # Natural dark lash line
        draw.arc([ex - ew * 1.02, ey - eh * 1.02, ex + ew * 1.02, ey + eh * 1.02], start=190, end=350, fill=(28, 20, 16, 225), width=2)
        draw.arc([ex - ew * 0.95, ey - eh * 0.95, ex + ew * 0.95, ey + eh * 0.95], start=14, end=166, fill=(92, 58, 42, 110), width=1)

        # Natural softly arched masculine eyebrow (gentle arc, feathered hair strokes)
        bx_in, by_in = ft_px(1.651, eth - side_s * 0.16)
        bx_mid, by_mid = ft_px(1.653, eth + side_s * 0.01)
        bx_out, by_out = ft_px(1.649, eth + side_s * 0.18)
        draw.line([(bx_in, by_in), (bx_mid, by_mid), (bx_out, by_out)], fill=(30, 23, 19, 145), width=4)
        for bi in range(28):
            bt = bi / 27.0
            bpx = lerp(bx_in, bx_out, bt)
            bpy = lerp(by_in, by_mid, bt * 2.0) if bt < 0.5 else lerp(by_mid, by_out, (bt - 0.5) * 2.0)
            draw.line([(bpx, bpy + 2), (bpx + side_s * 2.5, bpy - 2)], fill=(20, 15, 13, 195), width=1)

    # Nostrils under nose tip (y ~ 1.598, theta = +-0.068)
    for side_s in (-1.0, 1.0):
        nx, ny = ft_px(1.598, side_s * 0.068)
        draw.ellipse([nx - 3, ny - 2, nx + 3, ny + 2], fill=(74, 46, 33, 190))
    ntx, nty = ft_px(1.606, 0.0)
    draw.ellipse([ntx - 5, nty - 4, ntx + 5, nty + 4], fill=(204, 152, 118, 75))

    # Natural male lips (y = 1.572 .. 1.584, theta = -0.22 .. +0.22)
    lx0, ly_top = ft_px(1.583, -0.22)
    lx1, ly_bot = ft_px(1.571, +0.22)
    _, ly_mid = ft_px(1.577, 0.0)
    draw.ellipse([lx0, ly_top, lx1, ly_bot], fill=(138, 84, 68, 195))
    draw.line([(lx0 + 2, ly_mid), ((lx0 + lx1) * 0.5, ly_mid + 1), (lx1 - 2, ly_mid)], fill=(78, 42, 34, 190), width=1)
    draw.ellipse([(lx0 + lx1) * 0.5 - 10, ly_mid + 2, (lx0 + lx1) * 0.5 + 10, ly_bot - 1], fill=(166, 108, 88, 85))


def paint_albedo_texture(out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img = Image.new("RGBA", (TEX_SIZE, TEX_SIZE), (36, 36, 36, 255))

    # 1. Face Portrait Island
    paint_face_island(img)

    # 2. Hair Island
    bx0, by0, bx1, by1, *_ = island_px_rect("hair", pad=12)
    add_weave_noise(img, (bx0, by0, bx1, by1), (22, 18, 17), amp_x=2, amp_y=0, grain_amp=4, seed=101)
    draw = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(202)
    for _ in range(900):
        hx = rng.randint(bx0, bx1)
        hy = rng.randint(by0, by1)
        col = rng.choice([(14, 12, 11, 180), (34, 28, 25, 160), (46, 37, 32, 110)])
        draw.line([(hx, hy), (hx + rng.randint(-6, 6), hy + rng.randint(14, 34))], fill=col, width=rng.randint(1, 2))

    # 3. Limb / Neck / Hand Skin Island
    bx0, by0, bx1, by1, x0, y0, x1, y1 = island_px_rect("limb_skin", pad=10)
    add_weave_noise(img, (bx0, by0, bx1, by1), (174, 122, 90), amp_x=1, amp_y=1, grain_amp=4, seed=303)
    palm_y = int(lerp(y0, y1, 0.72))
    draw.rectangle([bx0, palm_y, bx1, by1], fill=(180, 128, 96, 80))
    nail_y = int(lerp(y0, y1, 0.96))
    draw.rectangle([bx0, nail_y, bx1, by1], fill=(192, 148, 120, 95))

    # 4. Field Jacket Body Island
    bx0, by0, bx1, by1, x0, y0, x1, y1 = island_px_rect("jacket_body", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (56, 63, 52), amp_x=3, amp_y=3, grain_amp=6, seed=404)
    cx_j = (x0 + x1) // 2
    draw.rectangle([cx_j - 20, y0, cx_j + 20, y1], fill=(48, 54, 44, 150))
    draw.line([(cx_j - 16, y0), (cx_j - 16, y1)], fill=(34, 38, 32, 200), width=2)
    draw.line([(cx_j + 16, y0), (cx_j + 16, y1)], fill=(34, 38, 32, 200), width=2)
    hem_y = int(lerp(y0, y1, 0.88))
    draw.rectangle([bx0, hem_y, bx1, by1], fill=(44, 49, 41, 75))
    for sy_frac in (0.12, 0.34, 0.56, 0.78):
        sy = int(lerp(y0, y1, sy_frac))
        draw.line([(bx0, sy), (bx1, sy)], fill=(38, 43, 35, 110), width=2)

    # 5. Jacket Sleeves & Rolled Cuffs Island
    bx0, by0, bx1, by1, x0, y0, x1, y1 = island_px_rect("jacket_sleeve", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (54, 61, 50), amp_x=3, amp_y=3, grain_amp=6, seed=505)
    cuff_y0 = int(lerp(y0, y1, 0.74))
    cuff_y1 = int(lerp(y0, y1, 0.86))
    draw.rectangle([bx0, cuff_y0, bx1, by1], fill=(44, 49, 41, 120))
    draw.line([(bx0, cuff_y0), (bx1, cuff_y0)], fill=(26, 29, 24, 200), width=3)
    draw.line([(bx0, cuff_y1), (bx1, cuff_y1)], fill=(70, 77, 65, 150), width=2)

    # 6. Dark Undershirt Island
    bx0, by0, bx1, by1, *_ = island_px_rect("undershirt", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (34, 36, 40), amp_x=4, amp_y=1, grain_amp=4, seed=606)

    # 7. Charcoal-Navy Cargo Trousers Island
    bx0, by0, bx1, by1, x0, y0, x1, y1 = island_px_rect("trousers", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (36, 44, 56), amp_x=3, amp_y=3, grain_amp=5, seed=707)
    # Subtle lower trouser dust gradient (keep distinct charcoal-navy above boots!)
    mud_y = int(lerp(y0, y1, 0.84))
    draw.rectangle([bx0, mud_y, bx1, by1], fill=(38, 40, 44, 90))
    draw.line([(x0 + 20, y0), (x0 + 20, y1)], fill=(24, 30, 38, 170), width=2)
    draw.line([(x1 - 20, y0), (x1 - 20, y1)], fill=(24, 30, 38, 170), width=2)
    knee_y = int(lerp(y0, y1, 0.56))
    for ky in (knee_y - 8, knee_y, knee_y + 8):
        draw.line([(bx0, ky), (bx1, ky)], fill=(26, 32, 42, 120), width=2)

    # 8. Brown Leather Belt Island
    bx0, by0, bx1, by1, x0, y0, x1, y1 = island_px_rect("belt", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (88, 52, 30), amp_x=1, amp_y=2, grain_amp=6, seed=808)
    draw.line([(bx0, y0 + 8), (bx1, y0 + 8)], fill=(58, 34, 18, 220), width=2)
    draw.line([(bx0, y1 - 8), (bx1, y1 - 8)], fill=(58, 34, 18, 220), width=2)

    # 9. Brass Buckle & Jacket Buttons Island
    bx0, by0, bx1, by1, *_ = island_px_rect("buckle", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (186, 146, 72), amp_x=2, amp_y=1, grain_amp=8, seed=909)
    draw.rectangle([bx0 + 14, by0 + 14, bx1 - 14, by1 - 14], outline=(112, 84, 36, 210), width=4)

    # 10. Muddy Brown-Black Leather Boots Island
    bx0, by0, bx1, by1, x0, y0, x1, y1 = island_px_rect("boot_leather", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (42, 31, 25), amp_x=2, amp_y=2, grain_amp=6, seed=1010)
    mud_by = int(lerp(y0, y1, 0.68))
    draw.rectangle([bx0, mud_by, bx1, by1], fill=(54, 42, 32, 120))
    draw.line([(bx0, y0 + 8), (bx1, y0 + 8)], fill=(68, 50, 38, 190), width=3)

    # 11. Boot Laces & Tongue Island
    bx0, by0, bx1, by1, x0, y0, x1, y1 = island_px_rect("boot_laces", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (34, 26, 21), amp_x=1, amp_y=2, grain_amp=5, seed=1111)
    for row in range(6):
        ly = int(lerp(y0 + 12, y1 - 12, row / 5.0))
        draw.line([(x0 + 14, ly - 5), (x1 - 14, ly + 5)], fill=(122, 102, 82, 235), width=3)
        draw.line([(x0 + 14, ly + 5), (x1 - 14, ly - 5)], fill=(104, 86, 68, 220), width=3)
        draw.ellipse([x0 + 10, ly - 3, x0 + 16, ly + 3], fill=(166, 142, 98, 255))
        draw.ellipse([x1 - 16, ly - 3, x1 - 10, ly + 3], fill=(166, 142, 98, 255))

    # 12. Boot Rubber Lug Sole Island
    bx0, by0, bx1, by1, *_ = island_px_rect("boot_sole", pad=8)
    add_weave_noise(img, (bx0, by0, bx1, by1), (24, 21, 20), amp_x=4, amp_y=2, grain_amp=5, seed=1212)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.5))
    img.convert("RGB").save(out_path, "PNG")


# ---------------------------------------------------------------------------
# Entrypoint & Full Character Assembly
# ---------------------------------------------------------------------------

def build_adult_male():
    body = MeshBuilder("body-mesh")
    build_pelvis_and_torso(body)
    build_arm(body, side="L")
    build_arm(body, side="R")
    build_leg(body, side="L")
    build_leg(body, side="R")

    head = MeshBuilder("head-mesh")
    build_head_and_hair(head)

    payload = {
        "character_id": "adult_male",
        "height": 1.76,
        "texture_path": "assets/models/player/adult_male_albedo.png",
        "joints": JOINTS,
        "meshes": {
            "body-mesh": body.to_dict(),
            "head-mesh": head.to_dict(),
        },
    }

    os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)
    with open(OUTPUT_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, separators=(",", ":"))

    paint_albedo_texture(OUTPUT_PNG_PATH)
    return payload


def verify_outputs():
    with open(OUTPUT_JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    assert data["character_id"] == "adult_male"
    assert abs(data["height"] - 1.76) < 1e-6
    assert data["texture_path"] == "assets/models/player/adult_male_albedo.png"
    assert len(data["joints"]) == 19
    for jname in JOINTS:
        assert jname in data["joints"], f"Missing joint {jname}"

    all_y = []
    stats = {}
    for mname in ("body-mesh", "head-mesh"):
        m = data["meshes"][mname]
        pos = m["positions"]
        nrm = m["normals"]
        uvs = m["uvs"]
        idx = m["indices"]
        reg = m["regions"]

        nv = len(pos)
        assert nv > 0
        assert len(nrm) == nv and len(uvs) == nv and len(reg) == nv
        assert len(idx) % 3 == 0 and len(idx) > 0

        for p in pos:
            assert all(math.isfinite(c) for c in p)
            all_y.append(p[1])
        for n in nrm:
            assert all(math.isfinite(c) for c in n)
            nl = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2)
            assert abs(nl - 1.0) < 1e-3, f"Non-unit normal {nl}"
        for u, v in uvs:
            assert 0.005 <= u <= 0.995 and 0.005 <= v <= 0.995, f"UV out of margin: {(u, v)}"
        for r in reg:
            assert r in ALLOWED_REGIONS
        for k in idx:
            assert 0 <= k < nv

        # Verify regional lateral discipline
        if mname == "body-mesh":
            for p, r in zip(pos, reg):
                if r == "arm_l":
                    assert p[0] > 0.14, f"arm_l x too small: {p}"
                elif r == "arm_r":
                    assert p[0] < -0.14, f"arm_r x too large: {p}"
                elif r == "leg_l":
                    assert p[0] > 0.01, f"leg_l x invalid: {p}"
                elif r == "leg_r":
                    assert p[0] < -0.01, f"leg_r x invalid: {p}"

        xs = [p[0] for p in pos]
        ys = [p[1] for p in pos]
        zs = [p[2] for p in pos]
        stats[mname] = {
            "verts": nv,
            "tris": len(idx) // 3,
            "min": [round(min(xs), 4), round(min(ys), 4), round(min(zs), 4)],
            "max": [round(max(xs), 4), round(max(ys), 4), round(max(zs), 4)],
        }

    min_y, max_y = min(all_y), max(all_y)
    assert abs(min_y - 0.0) < 0.002, f"Feet min_y={min_y}"
    assert abs(max_y - 1.76) < 0.005, f"Height max_y={max_y}"

    im = Image.open(OUTPUT_PNG_PATH)
    assert im.size == (1024, 1024)
    assert im.mode in ("RGB", "RGBA")

    print("VERIFICATION PASSED")
    print(f"Total height span: y=[{min_y:.4f}, {max_y:.4f}]")
    print(f"body-mesh: {stats['body-mesh']}")
    print(f"head-mesh: {stats['head-mesh']}")
    print(f"Texture: {OUTPUT_PNG_PATH} ({im.size}, {im.mode})")


if __name__ == "__main__":
    build_adult_male()
    verify_outputs()
