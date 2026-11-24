#!/usr/bin/env python3
"""
Adult Female Survivor (Indonesian) 3D Mesh & PBR Albedo Texture Generator for LAMPOR.

Outputs:
  - tools/characters/output/adult_female_mesh.json
  - assets/models/player/adult_female_albedo.png

Coordinate Space & Rig Contract:
  - Godot / glTF standard Y-up, facing +Z, character Left = +X, character Right = -X
  - Feet flat on y = 0.0, total height = 1.65m
  - Arms extended horizontally in T-pose along +X / -X at y = 1.31m
  - Two separate named meshes: "body-mesh" and "head-mesh"
  - Per-vertex "regions" array using: "torso", "arm_l", "arm_r", "leg_l", "leg_r", "neck", "head"
  - Non-overlapping 1024x1024 UV atlas with glTF PNG coordinates (u = x/(W-1), v = y/(H-1), v=0 top)
"""

import json
import math
import os
import random
from typing import Dict, List, Optional, Tuple

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# ---------------------------------------------------------------------------
# Paths & Constants
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
OUTPUT_JSON_PATH = os.path.join(SCRIPT_DIR, "output", "adult_female_mesh.json")
OUTPUT_TEX_PATH = os.path.join(REPO_ROOT, "assets", "models", "player", "adult_female_albedo.png")
TEXTURE_REL_PATH = "assets/models/player/adult_female_albedo.png"

TEX_SIZE = 1024
ALLOWED_REGIONS = {"torso", "arm_l", "arm_r", "leg_l", "leg_r", "neck", "head"}

JOINTS: Dict[str, List[float]] = {
    "Hips": [0.0, 0.88, 0.0],
    "Torso": [0.0, 1.05, 0.0],
    "Chest": [0.0, 1.23, 0.0],
    "Neck": [0.0, 1.39, 0.0],
    "Head": [0.0, 1.50, 0.01],
    "Shoulder.L": [0.07, 1.31, 0.0],
    "UpperArm.L": [0.18, 1.31, 0.0],
    "LowerArm.L": [0.44, 1.31, -0.01],
    "Hand.L": [0.68, 1.31, 0.0],
    "Shoulder.R": [-0.07, 1.31, 0.0],
    "UpperArm.R": [-0.18, 1.31, 0.0],
    "LowerArm.R": [-0.44, 1.31, -0.01],
    "Hand.R": [-0.68, 1.31, 0.0],
    "UpperLeg.L": [0.095, 0.85, 0.0],
    "LowerLeg.L": [0.095, 0.46, 0.01],
    "Foot.L": [0.095, 0.08, 0.02],
    "UpperLeg.R": [-0.095, 0.85, 0.0],
    "LowerLeg.R": [-0.095, 0.46, 0.01],
    "Foot.R": [-0.095, 0.08, 0.02],
}

# ---------------------------------------------------------------------------
# Non-overlapping UV Atlas Regions (u_min, v_min, u_max, v_max)
# Left column: u in [0.02, 0.50] | Right column: u in [0.53, 0.98]
# Minimum gutter >= 0.025 (~25 px), bleed painted +8 px around every island.
# ---------------------------------------------------------------------------
UV_ISLANDS = {
    "face": (0.03, 0.03, 0.48, 0.34),         # Head face + upper neck
    "jacket": (0.03, 0.39, 0.35, 0.70),       # Burgundy jacket body, lapels, collar, pockets
    "sleeve": (0.37, 0.39, 0.49, 0.70),       # Burgundy jacket sleeves & cuffs
    "trousers": (0.03, 0.75, 0.49, 0.97),     # Slate-charcoal fitted trousers
    "hands": (0.54, 0.03, 0.77, 0.21),        # Hands, thumbs, fingers, wrists (skin)
    "ears": (0.80, 0.03, 0.90, 0.12),         # Left & right ears (skin)
    "lower_neck": (0.80, 0.14, 0.97, 0.21),   # Lower neck skin base
    "hair": (0.54, 0.26, 0.88, 0.43),         # Dark hair cap, side locks, ponytail
    "hair_tie": (0.90, 0.26, 0.97, 0.43),     # Hair band tie
    "tunic": (0.54, 0.48, 0.97, 0.64),        # Cream-slate high-neck tunic undershirt
    "belt": (0.54, 0.69, 0.83, 0.74),         # Leather belt strap
    "buckle": (0.86, 0.69, 0.97, 0.74),       # Antique brass belt buckle
    "boot_upper": (0.54, 0.79, 0.83, 0.97),   # Weathered ankle boot upper & laces
    "boot_sole": (0.86, 0.79, 0.97, 0.97),    # Boot vulcanized rubber sole & heel
}


# ---------------------------------------------------------------------------
# Pure Python Vector & Math Utilities
# ---------------------------------------------------------------------------
Vec3 = Tuple[float, float, float]
Vec2 = Tuple[float, float]


def clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else (hi if v > hi else v)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    if abs(edge1 - edge0) < 1e-12:
        return 0.0
    t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def v_add(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_scale(a: Vec3, s: float) -> Vec3:
    return (a[0] * s, a[1] * s, a[2] * s)


def v_dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def v_cross(a: Vec3, b: Vec3) -> Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def v_len(a: Vec3) -> float:
    return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])


def v_norm(a: Vec3) -> Vec3:
    l = v_len(a)
    if l < 1e-12:
        return (0.0, 1.0, 0.0)
    return (a[0] / l, a[1] / l, a[2] / l)


def v_lerp(a: Vec3, b: Vec3, t: float) -> Vec3:
    return (lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t))


def uv_map(island_name: str, lu: float, lv: float) -> Vec2:
    """Map local [0..1]x[0..1] coordinates into an atlas island with inner safety margin."""
    u0, v0, u1, v1 = UV_ISLANDS[island_name]
    pad_u = 0.0025
    pad_v = 0.0025
    u = lerp(u0 + pad_u, u1 - pad_u, clamp(lu, 0.0, 1.0))
    v = lerp(v0 + pad_v, v1 - pad_v, clamp(lv, 0.0, 1.0))
    return (round(u, 6), round(v, 6))


# ---------------------------------------------------------------------------
# MeshBuilder with Area-Weighted Normals & Winding Verification
# ---------------------------------------------------------------------------
class MeshBuilder:
    """Accumulates organic lofted sub-meshes and computes smooth area-weighted normals."""

    def __init__(self, name: str) -> None:
        self.name = name
        self.positions: List[Vec3] = []
        self.uvs: List[Vec2] = []
        self.indices: List[int] = []
        self.regions: List[str] = []
        self.smooth_groups: List[int] = []
        self._normals: List[Vec3] = []

    def add_vertex(self, pos: Vec3, uv: Vec2, region: str, smooth_group: int) -> int:
        assert region in ALLOWED_REGIONS, f"Invalid region {region}"
        idx = len(self.positions)
        self.positions.append((round(pos[0], 6), round(pos[1], 6), round(pos[2], 6)))
        self.uvs.append((round(uv[0], 6), round(uv[1], 6)))
        self.regions.append(region)
        self.smooth_groups.append(smooth_group)
        return idx

    def _add_tri(self, i0: int, i1: int, i2: int) -> None:
        p0, p1, p2 = self.positions[i0], self.positions[i1], self.positions[i2]
        e1 = v_sub(p1, p0)
        e2 = v_sub(p2, p0)
        if v_len(v_cross(e1, e2)) > 1e-11:
            self.indices.extend([i0, i1, i2])

    def _signed_volume(self, tri_list: List[Tuple[int, int, int]]) -> float:
        vol = 0.0
        for i0, i1, i2 in tri_list:
            p0, p1, p2 = self.positions[i0], self.positions[i1], self.positions[i2]
            vol += v_dot(p0, v_cross(p1, p2)) / 6.0
        return vol

    def add_loft(
        self,
        rings: List[List[Vec3]],
        ring_uvs: List[List[Vec2]],
        region: str,
        smooth_group: int,
        cap_start: bool = True,
        cap_end: bool = True,
        ring_regions: Optional[List[str]] = None,
        flip_winding: bool = False,
    ) -> None:
        """
        Loft a sequence of closed rings into a smooth triangle strip mesh.
        Each ring has M+1 vertices (last vertex shares position with first for UV seam).
        Checks signed volume on closed lofts and ensures outward CCW winding.
        """
        num_rings = len(rings)
        if num_rings < 2:
            return
        m = len(rings[0])
        assert all(len(r) == m and len(u) == m for r, u in zip(rings, ring_uvs))

        vert_grid: List[List[int]] = []
        for r_idx in range(num_rings):
            reg = ring_regions[r_idx] if ring_regions is not None else region
            row: List[int] = []
            for j in range(m):
                row.append(self.add_vertex(rings[r_idx][j], ring_uvs[r_idx][j], reg, smooth_group))
            vert_grid.append(row)

        tris: List[Tuple[int, int, int]] = []
        for r_idx in range(num_rings - 1):
            row0 = vert_grid[r_idx]
            row1 = vert_grid[r_idx + 1]
            for j in range(m - 1):
                a, b = row0[j], row0[j + 1]
                c, d = row1[j + 1], row1[j]
                if flip_winding:
                    tris.append((a, c, b))
                    tris.append((a, d, c))
                else:
                    tris.append((a, b, c))
                    tris.append((a, c, d))

        if cap_start:
            c_pos = (
                sum(p[0] for p in rings[0][:-1]) / max(1, m - 1),
                sum(p[1] for p in rings[0][:-1]) / max(1, m - 1),
                sum(p[2] for p in rings[0][:-1]) / max(1, m - 1),
            )
            c_uv = (
                sum(u[0] for u in ring_uvs[0][:-1]) / max(1, m - 1),
                sum(u[1] for u in ring_uvs[0][:-1]) / max(1, m - 1),
            )
            c_reg = ring_regions[0] if ring_regions is not None else region
            c_idx = self.add_vertex(c_pos, c_uv, c_reg, smooth_group)
            row0 = vert_grid[0]
            for j in range(m - 1):
                if flip_winding:
                    tris.append((c_idx, row0[j], row0[j + 1]))
                else:
                    tris.append((c_idx, row0[j + 1], row0[j]))

        if cap_end:
            c_pos = (
                sum(p[0] for p in rings[-1][:-1]) / max(1, m - 1),
                sum(p[1] for p in rings[-1][:-1]) / max(1, m - 1),
                sum(p[2] for p in rings[-1][:-1]) / max(1, m - 1),
            )
            c_uv = (
                sum(u[0] for u in ring_uvs[-1][:-1]) / max(1, m - 1),
                sum(u[1] for u in ring_uvs[-1][:-1]) / max(1, m - 1),
            )
            c_reg = ring_regions[-1] if ring_regions is not None else region
            c_idx = self.add_vertex(c_pos, c_uv, c_reg, smooth_group)
            row1 = vert_grid[-1]
            for j in range(m - 1):
                if flip_winding:
                    tris.append((c_idx, row1[j + 1], row1[j]))
                else:
                    tris.append((c_idx, row1[j], row1[j + 1]))

        if cap_start and cap_end:
            vol = self._signed_volume(tris)
            if vol < 0.0:
                tris = [(i0, i2, i1) for (i0, i1, i2) in tris]

        for i0, i1, i2 in tris:
            self._add_tri(i0, i1, i2)

    def add_tube(
        self,
        centers: List[Vec3],
        rx_list: List[float],
        ry_list: List[float],
        radial_segs: int,
        island: str,
        region: str,
        smooth_group: int,
        cap_start_dome: bool = True,
        cap_end_dome: bool = True,
        up_hint: Vec3 = (0.0, 1.0, 0.0),
        u_span: Tuple[float, float] = (0.0, 1.0),
        v_span: Tuple[float, float] = (0.0, 1.0),
        ring_regions: Optional[List[str]] = None,
        dome_scale: float = 0.7,
    ) -> None:
        """Sweep an elliptical tube along a 3D curve using parallel-transport frames."""
        n = len(centers)
        assert n >= 2
        tangents: List[Vec3] = []
        for i in range(n):
            if i == 0:
                t = v_sub(centers[1], centers[0])
            elif i == n - 1:
                t = v_sub(centers[-1], centers[-2])
            else:
                t = v_sub(centers[i + 1], centers[i - 1])
            tangents.append(v_norm(t))

        # Initial frame
        t0 = tangents[0]
        if abs(v_dot(t0, up_hint)) > 0.94:
            up_hint = (0.0, 0.0, 1.0)
        b0 = v_norm(v_cross(t0, up_hint))
        n0 = v_norm(v_cross(b0, t0))

        frames: List[Tuple[Vec3, Vec3]] = [(n0, b0)]
        prev_t = t0
        prev_n = n0
        for i in range(1, n):
            cur_t = tangents[i]
            axis = v_cross(prev_t, cur_t)
            axis_l = v_len(axis)
            if axis_l > 1e-8:
                axis_n = v_scale(axis, 1.0 / axis_l)
                dot_val = clamp(v_dot(prev_t, cur_t), -1.0, 1.0)
                ang = math.acos(dot_val)
                # Rodrigues rotation of prev_n around axis_n by ang
                c = math.cos(ang)
                s = math.sin(ang)
                cur_n = v_add(
                    v_add(v_scale(prev_n, c), v_scale(v_cross(axis_n, prev_n), s)),
                    v_scale(axis_n, v_dot(axis_n, prev_n) * (1.0 - c)),
                )
            else:
                cur_n = prev_n
            cur_n = v_norm(v_sub(cur_n, v_scale(cur_t, v_dot(cur_n, cur_t))))
            cur_b = v_norm(v_cross(cur_t, cur_n))
            frames.append((cur_n, cur_b))
            prev_t = cur_t
            prev_n = cur_n

        # Build rings + optional smooth dome caps
        rings: List[List[Vec3]] = []
        ring_uvs: List[List[Vec2]] = []
        regs: List[str] = []

        def make_ring(center: Vec3, ax_n: Vec3, ax_b: Vec3, rx: float, ry: float, lv: float) -> Tuple[List[Vec3], List[Vec2]]:
            pts: List[Vec3] = []
            uvs: List[Vec2] = []
            for j in range(radial_segs + 1):
                frac = j / radial_segs
                ang = frac * 2.0 * math.pi
                ca, sa = math.cos(ang), math.sin(ang)
                offset = v_add(v_scale(ax_n, ca * rx), v_scale(ax_b, sa * ry))
                pts.append(v_add(center, offset))
                lu = lerp(u_span[0], u_span[1], frac)
                uvs.append(uv_map(island, lu, lv))
            return pts, uvs

        if cap_start_dome:
            c0 = centers[0]
            t_start = tangents[0]
            n_s, b_s = frames[0]
            r_x0, r_y0 = rx_list[0], ry_list[0]
            dome_d = min(r_x0, r_y0) * dome_scale
            for step, (depth, rad_s) in enumerate([(0.95, 0.25), (0.65, 0.68), (0.25, 0.92)]):
                cp = v_sub(c0, v_scale(t_start, depth * dome_d))
                pts, uvs = make_ring(cp, n_s, b_s, r_x0 * rad_s, r_y0 * rad_s, v_span[0])
                rings.append(pts)
                ring_uvs.append(uvs)
                regs.append(ring_regions[0] if ring_regions else region)

        for i in range(n):
            lv = lerp(v_span[0], v_span[1], i / (n - 1))
            ax_n, ax_b = frames[i]
            pts, uvs = make_ring(centers[i], ax_n, ax_b, rx_list[i], ry_list[i], lv)
            rings.append(pts)
            ring_uvs.append(uvs)
            regs.append(ring_regions[i] if ring_regions else region)

        if cap_end_dome:
            ce = centers[-1]
            t_end = tangents[-1]
            n_e, b_e = frames[-1]
            r_xe, r_ye = rx_list[-1], ry_list[-1]
            dome_d = min(r_xe, r_ye) * dome_scale
            for depth, rad_s in [(0.25, 0.92), (0.65, 0.68), (0.95, 0.25)]:
                cp = v_add(ce, v_scale(t_end, depth * dome_d))
                pts, uvs = make_ring(cp, n_e, b_e, r_xe * rad_s, r_ye * rad_s, v_span[1])
                rings.append(pts)
                ring_uvs.append(uvs)
                regs.append(ring_regions[-1] if ring_regions else region)

        self.add_loft(
            rings,
            ring_uvs,
            region=region,
            smooth_group=smooth_group,
            cap_start=True,
            cap_end=True,
            ring_regions=regs,
        )

    def add_beveled_box(
        self,
        center: Vec3,
        size: Vec3,
        island: str,
        region: str,
        smooth_group: int,
        bevel: float = 0.0025,
        u_span: Tuple[float, float] = (0.1, 0.9),
        v_span: Tuple[float, float] = (0.1, 0.9),
    ) -> None:
        """Create a closed watertight rounded/beveled box oriented with axis-aligned faces."""
        cx, cy, cz = center
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        bv = min(bevel, hx * 0.4, hy * 0.4, hz * 0.4)
        # Loft vertically along Y with 12 points around a beveled rectangle
        y_levels = [
            (cy - hy, 0.65, 0.0),
            (cy - hy + bv, 1.0, 0.15),
            (cy + hy - bv, 1.0, 0.85),
            (cy + hy, 0.65, 1.0),
        ]

        def rect_loop(rx_out: float, rz_out: float, b_r: float) -> List[Tuple[float, float]]:
            # 12 points CCW in XZ plane
            ix = max(1e-4, rx_out - b_r)
            iz = max(1e-4, rz_out - b_r)
            pts = [
                (rx_out, iz),
                (ix, rz_out),
                (-ix, rz_out),
                (-rx_out, iz),
                (-rx_out, -iz),
                (-ix, -rz_out),
                (ix, -rz_out),
                (rx_out, -iz),
            ]
            pts.append(pts[0])
            return pts

        rings: List[List[Vec3]] = []
        ring_uvs: List[List[Vec2]] = []
        for y_val, scale_xy, lv_frac in y_levels:
            rx = hx * scale_xy
            rz = hz * scale_xy
            b_r = bv * scale_xy
            loop = rect_loop(rx, rz, b_r)
            ring: List[Vec3] = []
            ruvs: List[Vec2] = []
            for idx_p, (px, pz) in enumerate(loop):
                ring.append((cx + px, y_val, cz + pz))
                lu = lerp(u_span[0], u_span[1], idx_p / (len(loop) - 1))
                lv = lerp(v_span[0], v_span[1], lv_frac)
                ruvs.append(uv_map(island, lu, lv))
            rings.append(ring)
            ring_uvs.append(ruvs)

        self.add_loft(rings, ring_uvs, region=region, smooth_group=smooth_group, cap_start=True, cap_end=True)

    def compute_normals(self) -> List[Vec3]:
        """Compute smooth area-weighted vertex normals welded by quantized position & smooth group."""
        accum: Dict[Tuple[int, int, int, int], List[float]] = {}
        for idx in range(0, len(self.indices), 3):
            i0, i1, i2 = self.indices[idx], self.indices[idx + 1], self.indices[idx + 2]
            p0, p1, p2 = self.positions[i0], self.positions[i1], self.positions[i2]
            fn = v_cross(v_sub(p1, p0), v_sub(p2, p0))
            if v_len(fn) < 1e-12:
                continue
            for vi in (i0, i1, i2):
                p = self.positions[vi]
                key = (
                    round(p[0] * 10000),
                    round(p[1] * 10000),
                    round(p[2] * 10000),
                    self.smooth_groups[vi],
                )
                if key not in accum:
                    accum[key] = [fn[0], fn[1], fn[2]]
                else:
                    accum[key][0] += fn[0]
                    accum[key][1] += fn[1]
                    accum[key][2] += fn[2]

        normals: List[Vec3] = []
        for vi, p in enumerate(self.positions):
            key = (
                round(p[0] * 10000),
                round(p[1] * 10000),
                round(p[2] * 10000),
                self.smooth_groups[vi],
            )
            acc = accum.get(key, [0.0, 1.0, 0.0])
            n = v_norm((acc[0], acc[1], acc[2]))
            normals.append((round(n[0], 6), round(n[1], 6), round(n[2], 6)))
        self._normals = normals
        return normals

    def export_dict(self) -> Dict:
        normals = self.compute_normals()
        return {
            "positions": [list(p) for p in self.positions],
            "normals": [list(n) for n in normals],
            "uvs": [list(uv) for uv in self.uvs],
            "indices": list(self.indices),
            "regions": list(self.regions),
        }


# ---------------------------------------------------------------------------
# Anatomical Profile Helpers
# ---------------------------------------------------------------------------
def head_projection_angles(radial_segs: int) -> List[float]:
    """
    Generate non-uniform angles starting at theta = -pi (back) -> 0 (front +Z) -> +pi (back).
    Concentrates extra resolution across the front face (-65 deg .. +65 deg).
    """
    angles: List[float] = []
    for j in range(radial_segs):
        t = j / radial_segs  # [0, 1)
        s = (t - 0.5) * 2.0  # [-1, 1)
        # Warp s so density is higher around s = 0 (front face)
        sign = 1.0 if s >= 0 else -1.0
        warped = sign * (0.62 * abs(s) + 0.38 * (abs(s) ** 1.75))
        angles.append(warped * math.pi)
    angles.append(math.pi)  # close seam at +pi
    return angles


def head_surface_point(y: float, theta: float) -> Tuple[float, float, float]:
    """
    Evaluate sculpted Indonesian adult female upper-neck & head at height y and angle theta.
    theta = 0 faces +Z, theta = +pi/2 is +X (character left), theta = +-pi is -Z (back).
    """
    # Vertical sections: (y, rx, rz_front, rz_back, z_center)
    profile = [
        (1.388, 0.042, 0.044, 0.044, 0.000),  # upper neck base (tucked cleanly inside tunic collar)
        (1.412, 0.041, 0.043, 0.044, 0.002),  # slender neck mid
        (1.430, 0.042, 0.047, 0.045, 0.005),  # neck-to-chin transition
        (1.442, 0.048, 0.068, 0.052, 0.009),  # soft chin & lower jaw
        (1.464, 0.058, 0.078, 0.064, 0.011),  # lower cheek & jaw
        (1.486, 0.065, 0.080, 0.076, 0.011),  # upper cheek & mid jaw
        (1.505, 0.069, 0.081, 0.084, 0.010),  # cheekbones & ear level (Head joint ~1.50)
        (1.526, 0.070, 0.080, 0.088, 0.009),  # orbital / eye line
        (1.552, 0.071, 0.081, 0.090, 0.007),  # brow / forehead lower
        (1.580, 0.069, 0.078, 0.088, 0.004),  # upper forehead
        (1.608, 0.061, 0.068, 0.078, 0.000),  # upper cranium
        (1.628, 0.045, 0.049, 0.056, -0.003), # crown taper
        (1.638, 0.022, 0.024, 0.028, -0.005), # crown cap base
    ]

    # Piecewise linear/cosine interpolation across profile
    if y <= profile[0][0]:
        _, rx, rzf, rzb, zc = profile[0]
    elif y >= profile[-1][0]:
        _, rx, rzf, rzb, zc = profile[-1]
    else:
        idx = 0
        for i in range(len(profile) - 1):
            if profile[i][0] <= y <= profile[i + 1][0]:
                idx = i
                break
        y0, rx0, rzf0, rzb0, zc0 = profile[idx]
        y1, rx1, rzf1, rzb1, zc1 = profile[idx + 1]
        t = smoothstep(y0, y1, y)
        rx = lerp(rx0, rx1, t)
        rzf = lerp(rzf0, rzf1, t)
        rzb = lerp(rzb0, rzb1, t)
        zc = lerp(zc0, zc1, t)

    s_th = math.sin(theta)
    c_th = math.cos(theta)
    rz = rzf if c_th >= 0.0 else rzb

    # Base oval shape with soft oval female jaw tapering
    jaw_taper = 1.0 - 0.12 * smoothstep(1.480, 1.434, y) * max(0.0, c_th) * abs(s_th)
    x = rx * jaw_taper * s_th
    z = zc + rz * c_th

    # Analytic facial sculpting on front (+Z)
    if c_th > 0.0:
        # Smooth oval chin projection
        chin_w = math.exp(-((y - 1.440) / 0.015) ** 2) * math.exp(-(theta / 0.42) ** 2)
        z += 0.011 * chin_w

        # Nose bridge & soft rounded nose tip
        nose_y = math.exp(-((y - 1.500) / 0.012) ** 2)
        bridge_y = smoothstep(1.490, 1.502, y) * (1.0 - smoothstep(1.524, 1.544, y))
        nose_profile = (0.016 * nose_y + 0.008 * bridge_y) * math.exp(-(theta / 0.15) ** 2)
        nostril_w = math.exp(-((y - 1.496) / 0.007) ** 2) * (
            math.exp(-((abs(theta) - 0.145) / 0.065) ** 2)
        )
        z += nose_profile + 0.004 * nostril_w

        # Soft upper & lower lip contour
        upper_lip = math.exp(-((y - 1.476) / 0.0045) ** 2) * math.exp(-(theta / 0.27) ** 2)
        lower_lip = math.exp(-((y - 1.468) / 0.0055) ** 2) * math.exp(-(theta / 0.25) ** 2)
        lip_groove = math.exp(-((y - 1.472) / 0.0022) ** 2) * math.exp(-(theta / 0.26) ** 2)
        z += 0.0045 * upper_lip + 0.0048 * lower_lip - 0.0022 * lip_groove

        # Gentle orbital eye hollows
        eye_socket = math.exp(-((y - 1.524) / 0.012) ** 2) * (
            math.exp(-((abs(theta) - 0.40) / 0.15) ** 2)
        )
        z -= 0.0055 * eye_socket

        # Subtle feminine cheekbones
        cheek = math.exp(-((y - 1.502) / 0.016) ** 2) * (
            math.exp(-((abs(theta) - 0.56) / 0.20) ** 2)
        )
        z += 0.0045 * cheek
        x += (0.0035 if s_th >= 0 else -0.0035) * cheek

    return (x, y, z)


def head_uv(y: float, theta: float) -> Vec2:
    """Consistent UV unwrap for head-mesh face & upper neck (u=0.5 centered at +Z front)."""
    lu = 0.5 + (theta / math.pi) * 0.46
    lv = lerp(0.03, 0.97, clamp((1.640 - y) / (1.640 - 1.388), 0.0, 1.0))
    return uv_map("face", lu, lv)


# ---------------------------------------------------------------------------
# Body Sub-Part Builders
# ---------------------------------------------------------------------------
def build_body_mesh() -> MeshBuilder:
    mb = MeshBuilder("body-mesh")
    radial_torso = 28

    # 1. Inner Torso + Trouser Pelvis + Tunic Shirt + Lower Neck Base
    # Duplicated UV seam rings at trouser/tunic (y=0.950) and tunic/neck (y=1.390)
    # (y, rx, rzf, rzb, zc, island, region, smooth_group, bust_amount)
    torso_spec = [
        (0.804, 0.090, 0.054, 0.062, 0.000, "trousers", "torso", 1, 0.0),   # tucked pelvis saddle
        (0.832, 0.150, 0.088, 0.106, 0.000, "trousers", "torso", 1, 0.0),   # lower hip
        (0.880, 0.156, 0.094, 0.112, 0.000, "trousers", "torso", 1, 0.0),   # Hips joint
        (0.922, 0.136, 0.085, 0.096, 0.000, "trousers", "torso", 1, 0.0),   # upper hip
        (0.950, 0.118, 0.080, 0.084, 0.000, "trousers", "torso", 1, 0.0),   # trouser waistband top
    ]
    tunic_spec = [
        (0.950, 0.114, 0.077, 0.081, 0.000, "tunic", "torso", 2, 0.0),      # tunic tucked into waistband
        (1.000, 0.111, 0.075, 0.079, 0.000, "tunic", "torso", 2, 0.0),
        (1.050, 0.110, 0.075, 0.079, 0.000, "tunic", "torso", 2, 0.0),      # Torso tapered waist
        (1.120, 0.122, 0.084, 0.083, 0.000, "tunic", "torso", 2, 0.25),
        (1.185, 0.133, 0.093, 0.087, 0.002, "tunic", "torso", 2, 0.85),     # bust lower slope
        (1.230, 0.139, 0.096, 0.090, 0.003, "tunic", "torso", 2, 1.00),     # Chest joint & bust peak
        (1.275, 0.148, 0.088, 0.086, 0.002, "tunic", "torso", 2, 0.45),     # upper chest
        (1.310, 0.165, 0.077, 0.076, 0.000, "tunic", "torso", 2, 0.0),      # shoulder line (meets arms)
        (1.345, 0.086, 0.060, 0.061, 0.000, "tunic", "torso", 2, 0.0),      # trapezius slope
        (1.362, 0.052, 0.051, 0.052, 0.000, "tunic", "torso", 2, 0.0),      # high-neck collar base
        (1.390, 0.048, 0.048, 0.049, 0.000, "tunic", "torso", 2, 0.0),      # high-neck collar top (Neck joint)
    ]
    neck_spec = [
        (1.372, 0.039, 0.041, 0.041, 0.000, "lower_neck", "neck", 3, 0.0),  # inside collar
        (1.382, 0.039, 0.041, 0.041, 0.000, "lower_neck", "neck", 3, 0.0),  # lower neck base
        (1.388, 0.038, 0.040, 0.040, 0.000, "lower_neck", "neck", 3, 0.0),  # capped inside collar below head-mesh
    ]

    def build_torso_rings(spec_list, v_y0: float, v_y1: float) -> Tuple[List[List[Vec3]], List[List[Vec2]], List[str]]:
        rings: List[List[Vec3]] = []
        ruvs: List[List[Vec2]] = []
        regs: List[str] = []
        for y, rx, rzf, rzb, zc, island, reg, _, bust in spec_list:
            ring: List[Vec3] = []
            uv_row: List[Vec2] = []
            lv = clamp((v_y1 - y) / max(1e-5, (v_y1 - v_y0)), 0.02, 0.98)
            for j in range(radial_torso + 1):
                frac = j / radial_torso
                theta = (frac - 0.5) * 2.0 * math.pi  # -pi back -> 0 front -> +pi back
                s_th, c_th = math.sin(theta), math.cos(theta)
                rz = rzf if c_th >= 0.0 else rzb
                px = rx * s_th
                pz = zc + rz * c_th
                # Feminine bust contour + subtle spine groove
                if bust > 0.0 and c_th > 0.0:
                    bust_lobe = (
                        math.exp(-((abs(theta) - 0.44) / 0.25) ** 2)
                        * 0.021
                        * bust
                    )
                    sternum = math.exp(-(theta / 0.14) ** 2) * 0.006 * bust
                    pz += bust_lobe - sternum
                if c_th < -0.5 and 0.90 < y < 1.32:
                    spine_groove = math.exp(-((abs(theta) - math.pi) / 0.20) ** 2) * 0.0045
                    pz += spine_groove
                ring.append((px, y, pz))
                uv_row.append(uv_map(island, lerp(0.04, 0.96, frac), lv))
            rings.append(ring)
            ruvs.append(uv_row)
            regs.append(reg)
        return rings, ruvs, regs

    r_pelvis, u_pelvis, reg_pelvis = build_torso_rings(torso_spec, 0.80, 0.955)
    mb.add_loft(r_pelvis, u_pelvis, "torso", smooth_group=1, cap_start=True, cap_end=True, ring_regions=reg_pelvis)

    r_tunic, u_tunic, reg_tunic = build_torso_rings(tunic_spec, 0.945, 1.395)
    mb.add_loft(r_tunic, u_tunic, "torso", smooth_group=2, cap_start=True, cap_end=True, ring_regions=reg_tunic)

    r_neck, u_neck, reg_neck = build_torso_rings(neck_spec, 1.388, 1.418)
    mb.add_loft(r_neck, u_neck, "neck", smooth_group=3, cap_start=True, cap_end=True, ring_regions=reg_neck)

    # 2. Slim Leather Belt + Brass Buckle (around waist / high hip y = 0.918..0.952)
    belt_levels = [
        (0.916, 0.143, 0.089, 0.100, 0.95),
        (0.922, 0.142, 0.089, 0.099, 0.70),
        (0.946, 0.125, 0.084, 0.088, 0.30),
        (0.952, 0.121, 0.082, 0.086, 0.05),
    ]
    # Build closed thick strap ring (outer + inner surface)
    belt_rings: List[List[Vec3]] = []
    belt_uvs: List[List[Vec2]] = []
    belt_segs = 28
    for y, rx, rzf, rzb, lv in belt_levels:
        pts_out: List[Vec3] = []
        pts_in: List[Vec3] = []
        uvs_out: List[Vec2] = []
        uvs_in: List[Vec2] = []
        for j in range(belt_segs):
            frac = j / belt_segs
            theta = (frac - 0.5) * 2.0 * math.pi
            s_th, c_th = math.sin(theta), math.cos(theta)
            rz = rzf if c_th >= 0 else rzb
            pts_out.append((rx * s_th, y, rz * c_th))
            pts_in.append(((rx - 0.008) * s_th, y, (rz - 0.008) * c_th))
            uvs_out.append(uv_map("belt", frac, lv))
            uvs_in.append(uv_map("belt", frac, lv))
        belt_rings.append(pts_out + [pts_out[0]])
        belt_uvs.append(uvs_out + [uvs_out[0]])
    # Closed solid belt shell: outer loop up, inner loop down
    solid_belt_rings = list(belt_rings)
    solid_belt_uvs = list(belt_uvs)
    for y, rx, rzf, rzb, lv in reversed(belt_levels):
        pts_in = []
        uvs_in = []
        for j in range(belt_segs):
            frac = j / belt_segs
            theta = (frac - 0.5) * 2.0 * math.pi
            s_th, c_th = math.sin(theta), math.cos(theta)
            rz = (rzf if c_th >= 0 else rzb) - 0.008
            pts_in.append(((rx - 0.008) * s_th, y, rz * c_th))
            uvs_in.append(uv_map("belt", frac, lv))
        solid_belt_rings.append(pts_in + [pts_in[0]])
        solid_belt_uvs.append(uvs_in + [uvs_in[0]])
    # Close seam between inner top and outer bottom
    solid_belt_rings.append(belt_rings[0])
    solid_belt_uvs.append(belt_uvs[0])
    mb.add_loft(solid_belt_rings, solid_belt_uvs, "torso", smooth_group=4, cap_start=False, cap_end=False)

    # Belt buckle centered on +Z front
    mb.add_beveled_box(
        center=(0.0, 0.934, 0.088),
        size=(0.044, 0.038, 0.014),
        island="buckle",
        region="torso",
        smooth_group=5,
        bevel=0.003,
    )

    # 3. Fitted Dark Burgundy Weathered Utility Jacket (Thick Open-Front Manifold Shell + Lapels & Collar)
    # Cross-section is an open C-arc wrapped around back/sides/front with thickness = 9mm,
    # leaving front gap around |theta| < open_angle so tunic + belt buckle stay clearly visible!
    # (y, rx, rzf, rzb, zc, open_deg, lapel_flare, collar_lift)
    jacket_levels = [
        (0.832, 0.165, 0.100, 0.119, 0.000, 26.0, 0.000),  # flared jacket hem over hips
        (0.885, 0.163, 0.101, 0.118, 0.000, 24.0, 0.000),  # hip curve
        (0.950, 0.130, 0.090, 0.094, 0.000, 22.0, 0.000),  # waist cinch
        (1.045, 0.121, 0.084, 0.088, 0.000, 20.0, 0.000),  # fitted waist
        (1.135, 0.132, 0.094, 0.091, 0.001, 19.0, 0.004),  # lower ribcage
        (1.205, 0.144, 0.105, 0.095, 0.002, 23.0, 0.011),  # bust + lapel starts
        (1.245, 0.150, 0.107, 0.098, 0.002, 28.0, 0.016),  # chest + sculpted lapel fold
        (1.290, 0.164, 0.094, 0.092, 0.001, 34.0, 0.018),  # upper chest + lapel peak
        (1.320, 0.175, 0.085, 0.084, 0.000, 38.0, 0.014),  # shoulder yoke (overlaps sleeve caps)
        (1.352, 0.098, 0.068, 0.070, 0.000, 44.0, 0.008),  # shoulder-to-collar slope
        (1.378, 0.062, 0.058, 0.062, 0.000, 52.0, 0.005),  # standing/turned jacket collar!
    ]

    arc_samples = 22
    thick = 0.0085
    jacket_rings: List[List[Vec3]] = []
    jacket_uvs: List[List[Vec2]] = []

    for y, rx, rzf, rzb, zc, open_deg, lapel_flare in jacket_levels:
        open_rad = math.radians(open_deg)
        ring_pts: List[Vec3] = []
        ring_uv: List[Vec2] = []
        lv = clamp((1.385 - y) / (1.385 - 0.825), 0.04, 0.96)

        # Outer arc: from +open_rad (left front opening) -> +pi (back) -> 2pi - open_rad (right front opening)
        outer_angles = [
            lerp(open_rad, 2.0 * math.pi - open_rad, k / (arc_samples - 1))
            for k in range(arc_samples)
        ]
        for k, th in enumerate(outer_angles):
            s_th, c_th = math.sin(th), math.cos(th)
            rz = rzf if c_th >= 0 else rzb
            px = rx * s_th
            pz = zc + rz * c_th
            # Bust contour on outer jacket
            if 1.12 < y < 1.29 and c_th > 0.0:
                bust_amt = math.sin(clamp((y - 1.12) / 0.17, 0.0, 1.0) * math.pi)
                pz += math.exp(-((abs(s_th) - 0.42) / 0.25) ** 2) * 0.015 * bust_amt
            # Lapel outward ridge near front opening
            edge_dist = min(k, arc_samples - 1 - k)
            if edge_dist <= 2 and lapel_flare > 0.0:
                flare_w = (3 - edge_dist) / 3.0
                pz += lapel_flare * flare_w
                px += (0.008 if s_th >= 0 else -0.008) * flare_w
            ring_pts.append((px, y, pz))
            lu = lerp(0.05, 0.95, k / (arc_samples - 1))
            ring_uv.append(uv_map("jacket", lu, lv))

        # Inner arc: return from right front edge -> back -> left front edge (inset by thickness)
        for k_rev in range(arc_samples - 1, -1, -1):
            th = outer_angles[k_rev]
            s_th, c_th = math.sin(th), math.cos(th)
            rz = (rzf if c_th >= 0 else rzb) - thick
            px = (rx - thick) * s_th
            pz = zc + rz * c_th
            if 1.12 < y < 1.29 and c_th > 0.0:
                bust_amt = math.sin(clamp((y - 1.12) / 0.17, 0.0, 1.0) * math.pi)
                pz += math.exp(-((abs(s_th) - 0.42) / 0.25) ** 2) * 0.015 * bust_amt
            ring_pts.append((px, y, pz))
            lu = lerp(0.05, 0.95, k_rev / (arc_samples - 1))
            ring_uv.append(uv_map("jacket", lu, lv))

        # Close loop
        ring_pts.append(ring_pts[0])
        ring_uv.append(ring_uv[0])
        jacket_rings.append(ring_pts)
        jacket_uvs.append(ring_uv)

    mb.add_loft(jacket_rings, jacket_uvs, "torso", smooth_group=6, cap_start=False, cap_end=False)

    # Watertight manifold quad-bridge caps for concave jacket hem (bottom) and collar rim (top)
    n_arc = arc_samples
    for cap_ring, is_top in ((jacket_rings[0], False), (jacket_rings[-1], True)):
        cap_uv = jacket_uvs[0] if not is_top else jacket_uvs[-1]
        sg = 8 if not is_top else 9
        out_idx = [mb.add_vertex(cap_ring[k], cap_uv[k], "torso", sg) for k in range(n_arc)]
        in_idx = [
            mb.add_vertex(cap_ring[2 * n_arc - 1 - k], cap_uv[2 * n_arc - 1 - k], "torso", sg)
            for k in range(n_arc)
        ]
        target_y = 1.0 if is_top else -1.0
        for k in range(n_arc - 1):
            for t_a, t_b, t_c in (
                (out_idx[k], in_idx[k + 1], in_idx[k]),
                (out_idx[k], out_idx[k + 1], in_idx[k + 1]),
            ):
                p0, p1, p2 = mb.positions[t_a], mb.positions[t_b], mb.positions[t_c]
                ny = v_cross(v_sub(p1, p0), v_sub(p2, p0))[1]
                if ny * target_y >= 0.0:
                    mb._add_tri(t_a, t_b, t_c)
                else:
                    mb._add_tri(t_a, t_c, t_b)

    # Sculpted Utility Pockets on Jacket Hip Front (tucked neatly against jacket hem)
    for sx in (1.0, -1.0):
        mb.add_beveled_box(
            center=(sx * 0.102, 0.885, 0.072),
            size=(0.050, 0.056, 0.010),
            island="jacket",
            region="torso",
            smooth_group=7,
            bevel=0.0025,
            u_span=(0.15, 0.35),
            v_span=(0.72, 0.86),
        )

    # 4. Left & Right Arms + Sleeves + Cuffs + Sculpted Hands (T-pose along +-X at y = 1.31)
    for side_sign, region_tag in [(1.0, "arm_l"), (-1.0, "arm_r")]:
        # Sleeve segment: shoulder cap tucked inside jacket (x = +-0.136) through UpperArm (+-0.18),
        # LowerArm (+-0.44, z=-0.01), down to rolled cuff at +-0.638
        # (x_abs, y, z, ry, rz)
        sleeve_pts = [
            (0.136, 1.310, 0.000, 0.045, 0.046),  # tucked cleanly inside jacket shoulder
            (0.180, 1.310, 0.000, 0.049, 0.050),  # UpperArm joint (0.36m shoulder span)
            (0.245, 1.309, -0.003, 0.043, 0.044), # deltoid taper
            (0.340, 1.309, -0.006, 0.039, 0.040), # mid bicep
            (0.440, 1.310, -0.010, 0.036, 0.037), # LowerArm elbow joint
            (0.535, 1.310, -0.006, 0.035, 0.036), # mid forearm
            (0.618, 1.310, -0.002, 0.031, 0.033), # sleeve before cuff
            (0.624, 1.310, -0.002, 0.034, 0.036), # rolled cuff flare
            (0.640, 1.310, -0.001, 0.034, 0.036), # cuff end
        ]
        arm_centers = [(side_sign * x, y, z) for (x, y, z, _, _) in sleeve_pts]
        arm_ry = [ry for (_, _, _, ry, _) in sleeve_pts]
        arm_rz = [rz for (_, _, _, _, rz) in sleeve_pts]
        mb.add_tube(
            centers=arm_centers,
            rx_list=arm_ry,
            ry_list=arm_rz,
            radial_segs=20,
            island="sleeve",
            region=region_tag,
            smooth_group=10 if side_sign > 0 else 11,
            cap_start_dome=True,
            cap_end_dome=True,
            up_hint=(0.0, 1.0, 0.0),
            u_span=(0.05, 0.95),
            v_span=(0.04, 0.96),
        )

        # Skin wrist & palm loft (from x = +-0.630 inside cuff, through Hand joint +-0.68, to knuckles +-0.755)
        # (x_abs, y, z, half_y, half_z, tilt_deg)
        hand_sections = [
            (0.628, 1.310, -0.001, 0.023, 0.027, 4.0),   # tucked inside sleeve cuff
            (0.660, 1.310, 0.000, 0.021, 0.026, 6.0),    # wrist taper
            (0.680, 1.310, 0.000, 0.020, 0.028, 8.0),    # Hand joint (wrist)
            (0.705, 1.309, 0.002, 0.017, 0.033, 10.0),   # heel of palm
            (0.732, 1.307, 0.003, 0.015, 0.036, 11.0),   # mid palm
            (0.756, 1.305, 0.002, 0.013, 0.035, 11.0),   # knuckle bridge
        ]
        hand_rings: List[List[Vec3]] = []
        hand_uvs: List[List[Vec2]] = []
        h_segs = 18
        for x_abs, cy, cz, hy, hz, tilt_deg in hand_sections:
            tilt = math.radians(tilt_deg)
            ct, st = math.cos(tilt), math.sin(tilt)
            ring: List[Vec3] = []
            ruvs: List[Vec2] = []
            lv = clamp((x_abs - 0.628) / (0.758 - 0.628), 0.05, 0.92)
            for j in range(h_segs + 1):
                frac = j / h_segs
                ang = frac * 2.0 * math.pi
                dy_local = hy * math.cos(ang)
                dz_local = hz * math.sin(ang)
                # Slightly flatten palm underside (-Y) and arch dorsal (+Y)
                if dy_local < 0:
                    dy_local *= 0.85
                # Rotate by slight palm-inward tilt around X
                dy_rot = dy_local * ct - dz_local * st
                dz_rot = dy_local * st + dz_local * ct
                ring.append((side_sign * x_abs, cy + dy_rot, cz + dz_rot))
                ruvs.append(uv_map("hands", lerp(0.05, 0.68, frac), lv))
            hand_rings.append(ring)
            hand_uvs.append(ruvs)

        mb.add_loft(
            hand_rings,
            hand_uvs,
            region=region_tag,
            smooth_group=12 if side_sign > 0 else 13,
            cap_start=True,
            cap_end=True,
        )

        # Thumb (pointing forward +Z & slightly downward -Y)
        thumb_centers = [
            (side_sign * 0.698, 1.303, 0.022),
            (side_sign * 0.720, 1.298, 0.042),
            (side_sign * 0.742, 1.292, 0.058),
            (side_sign * 0.760, 1.287, 0.068),
        ]
        mb.add_tube(
            centers=thumb_centers,
            rx_list=[0.011, 0.0095, 0.0082, 0.0068],
            ry_list=[0.010, 0.0090, 0.0078, 0.0065],
            radial_segs=10,
            island="hands",
            region=region_tag,
            smooth_group=14 if side_sign > 0 else 15,
            u_span=(0.72, 0.96),
            v_span=(0.10, 0.45),
        )

        # Four individual sculpted fingers (Index, Middle, Ring, Little) with relaxed curl
        finger_specs = [
            # (z_offset, y_offset, length, radius)
            (0.025, 1.305, 0.064, 0.0078),   # Index
            (0.008, 1.306, 0.071, 0.0080),   # Middle
            (-0.009, 1.305, 0.065, 0.0075),  # Ring
            (-0.024, 1.302, 0.051, 0.0066),  # Little
        ]
        for f_idx, (fz, fy, flen, frad) in enumerate(finger_specs):
            f_centers = [
                (side_sign * 0.750, fy, fz),
                (side_sign * (0.750 + flen * 0.42), fy - 0.003, fz),
                (side_sign * (0.750 + flen * 0.76), fy - 0.010, fz),
                (side_sign * (0.750 + flen * 1.00), fy - 0.019, fz),
            ]
            mb.add_tube(
                centers=f_centers,
                rx_list=[frad, frad * 0.90, frad * 0.80, frad * 0.66],
                ry_list=[frad * 0.95, frad * 0.85, frad * 0.76, frad * 0.62],
                radial_segs=10,
                island="hands",
                region=region_tag,
                smooth_group=16 + f_idx + (0 if side_sign > 0 else 10),
                u_span=(0.72, 0.96),
                v_span=(0.50, 0.95),
            )

    # 5. Left & Right Trousers Legs + Ankle Survival Boots
    for side_sign, region_tag in [(1.0, "leg_l"), (-1.0, "leg_r")]:
        leg_cx = side_sign * 0.095
        # Trouser leg from upper hip dome inside pelvis (y = 0.878) through UpperLeg (0.85),
        # LowerLeg (0.46, z=0.01), calf, down into boot cuff (y = 0.165)
        # (y, x_off, zc, rx_in, rx_out, rzf, rzb)
        trouser_levels = [
            (0.876, side_sign * -0.004, 0.000, 0.042, 0.044, 0.044, 0.046),  # tucked dome inside pelvis
            (0.850, side_sign * 0.000, 0.000, 0.068, 0.074, 0.074, 0.084),   # UpperLeg joint
            (0.760, side_sign * 0.000, 0.003, 0.068, 0.074, 0.074, 0.082),   # upper thigh
            (0.630, side_sign * 0.000, 0.006, 0.060, 0.063, 0.065, 0.069),   # mid thigh
            (0.520, side_sign * 0.000, 0.009, 0.052, 0.053, 0.055, 0.056),   # above knee
            (0.460, side_sign * 0.000, 0.010, 0.048, 0.049, 0.053, 0.051),   # LowerLeg knee joint
            (0.355, side_sign * 0.000, 0.005, 0.050, 0.052, 0.045, 0.058),   # sculpted calf curve
            (0.245, side_sign * 0.000, 0.013, 0.040, 0.041, 0.041, 0.044),   # lower shin
            (0.180, side_sign * 0.000, 0.016, 0.036, 0.037, 0.038, 0.040),   # trouser tucked into boot
        ]
        leg_rings: List[List[Vec3]] = []
        leg_uvs: List[List[Vec2]] = []
        l_segs = 22
        for y, x_off, zc, rx_in, rx_out, rzf, rzb in trouser_levels:
            ring: List[Vec3] = []
            ruvs: List[Vec2] = []
            lv = clamp((0.880 - y) / (0.880 - 0.175), 0.04, 0.96)
            for j in range(l_segs + 1):
                frac = j / l_segs
                theta = (frac - 0.5) * 2.0 * math.pi
                s_th, c_th = math.sin(theta), math.cos(theta)
                # Differentiate inner thigh vs outer thigh radius cleanly
                is_outer = (s_th * side_sign) >= 0.0
                rx = rx_out if is_outer else rx_in
                rz = rzf if c_th >= 0.0 else rzb
                px = leg_cx + x_off + rx * s_th
                # Keep inner thigh strictly clear of midline x = 0
                if side_sign > 0:
                    px = max(0.009, px)
                else:
                    px = min(-0.009, px)
                pz = zc + rz * c_th
                ring.append((px, y, pz))
                ruvs.append(uv_map("trousers", lerp(0.05, 0.95, frac), lv))
            leg_rings.append(ring)
            leg_uvs.append(ruvs)

        mb.add_loft(
            leg_rings,
            leg_uvs,
            region=region_tag,
            smooth_group=30 if side_sign > 0 else 31,
            cap_start=True,
            cap_end=True,
        )

        # Boot Upper Shaft (from padded cuff at y = 0.205 through ankle Foot joint at y = 0.08, z = 0.02 down to vamp y = 0.03)
        # Plus Boot Forefoot & Toe Box swept cleanly onto the rubber sole!
        boot_shaft = [
            (0.205, 0.015, 0.044, 0.048, 0.046),  # padded boot collar lip
            (0.185, 0.016, 0.045, 0.050, 0.048),  # boot cuff
            (0.130, 0.018, 0.042, 0.047, 0.046),  # ankle shaft
            (0.080, 0.020, 0.041, 0.054, 0.048),  # Foot ankle joint (0.095, 0.08, 0.02)
            (0.052, 0.045, 0.042, 0.092, 0.068),  # instep & heel transition
            (0.032, 0.062, 0.043, 0.114, 0.092),  # upper shoe body
            (0.020, 0.068, 0.042, 0.114, 0.104),  # welt base sitting atop sole
        ]
        b_rings: List[List[Vec3]] = []
        b_uvs: List[List[Vec2]] = []
        b_segs = 20
        for y, zc, rx, rzf, rzb in boot_shaft:
            ring = []
            ruvs = []
            lv = clamp((0.205 - y) / (0.205 - 0.020), 0.04, 0.90)
            for j in range(b_segs + 1):
                frac = j / b_segs
                theta = (frac - 0.5) * 2.0 * math.pi
                s_th, c_th = math.sin(theta), math.cos(theta)
                rz = rzf if c_th >= 0 else rzb
                taper = 1.0 - 0.22 * max(0.0, c_th) ** 2 if y < 0.07 else 1.0
                px = leg_cx + rx * taper * s_th
                pz = zc + rz * c_th
                ring.append((px, y, pz))
                ruvs.append(uv_map("boot_upper", lerp(0.05, 0.95, frac), lv))
            b_rings.append(ring)
            b_uvs.append(ruvs)

        mb.add_loft(
            b_rings,
            b_uvs,
            region=region_tag,
            smooth_group=32 if side_sign > 0 else 33,
            cap_start=True,
            cap_end=True,
        )

        # Boot Toe Cap Dome (sculpted rounded front toe box from z = 0.095 to 0.186)
        toe_centers = [
            (leg_cx, 0.041, 0.095),
            (leg_cx, 0.036, 0.130),
            (leg_cx, 0.031, 0.160),
            (leg_cx, 0.025, 0.180),
        ]
        mb.add_tube(
            centers=toe_centers,
            rx_list=[0.023, 0.020, 0.015, 0.008],
            ry_list=[0.040, 0.038, 0.031, 0.017],
            radial_segs=16,
            island="boot_upper",
            region=region_tag,
            smooth_group=34 if side_sign > 0 else 35,
            up_hint=(0.0, 1.0, 0.0),
            u_span=(0.10, 0.90),
            v_span=(0.55, 0.95),
            dome_scale=0.45,
        )

        # Boot Rubber Sole (flat on y = 0.000! Heel block + Mid arch + Forefoot pad)
        mb.add_beveled_box(
            center=(leg_cx, 0.013, -0.004),
            size=(0.078, 0.026, 0.068),
            island="boot_sole",
            region=region_tag,
            smooth_group=36 if side_sign > 0 else 37,
            bevel=0.003,
        )
        mb.add_beveled_box(
            center=(leg_cx, 0.0145, 0.050),
            size=(0.068, 0.019, 0.048),
            island="boot_sole",
            region=region_tag,
            smooth_group=36 if side_sign > 0 else 37,
            bevel=0.003,
        )
        mb.add_beveled_box(
            center=(leg_cx, 0.011, 0.122),
            size=(0.080, 0.022, 0.110),
            island="boot_sole",
            region=region_tag,
            smooth_group=36 if side_sign > 0 else 37,
            bevel=0.004,
        )

    return mb


# ---------------------------------------------------------------------------
# Head, Face, Ears & Hair Builder (head-mesh)
# ---------------------------------------------------------------------------
def build_head_mesh() -> MeshBuilder:
    mb = MeshBuilder("head-mesh")

    # 1. Upper Neck + Sculpted Feminine Head
    head_y_levels = [
        1.388, 1.412, 1.428, 1.440, 1.454, 1.466, 1.478, 1.494,
        1.505, 1.518, 1.528, 1.542, 1.558, 1.576, 1.594, 1.612, 1.628, 1.638,
    ]
    angles = head_projection_angles(32)
    h_rings: List[List[Vec3]] = []
    h_uvs: List[List[Vec2]] = []
    h_regs: List[str] = []

    for y in head_y_levels:
        ring: List[Vec3] = []
        ruvs: List[Vec2] = []
        for theta in angles:
            ring.append(head_surface_point(y, theta))
            ruvs.append(head_uv(y, theta))
        h_rings.append(ring)
        h_uvs.append(ruvs)
        h_regs.append("neck" if y <= 1.429 else "head")

    mb.add_loft(
        h_rings,
        h_uvs,
        region="head",
        smooth_group=50,
        cap_start=True,
        cap_end=True,
        ring_regions=h_regs,
    )

    # 2. Left & Right Sculpted Ears (tucked naturally on head sides)
    for side_sign in (1.0, -1.0):
        ear_centers = [
            (side_sign * 0.068, 1.486, 0.005),
            (side_sign * 0.074, 1.498, 0.003),
            (side_sign * 0.075, 1.512, 0.000),
            (side_sign * 0.071, 1.522, -0.003),
        ]
        mb.add_tube(
            centers=ear_centers,
            rx_list=[0.006, 0.008, 0.008, 0.0055],
            ry_list=[0.008, 0.011, 0.012, 0.008],
            radial_segs=10,
            island="ears",
            region="head",
            smooth_group=51 if side_sign > 0 else 52,
            up_hint=(1.0 if side_sign > 0 else -1.0, 0.0, 0.0),
            u_span=(0.1, 0.9),
            v_span=(0.1, 0.9),
        )

    # 3. Sculpted Dark Hair Cap with Feminine Parting (Crown reaches y = 1.650!)
    # Hair sits cleanly outside the cranium on top, sides, and back while curving above the face!
    # Vertical rings from hair nape/sides up to crown at y = 1.650
    hair_y = [1.432, 1.458, 1.488, 1.518, 1.548, 1.576, 1.602, 1.622, 1.634, 1.643, 1.648, 1.650]
    hair_segs = 40
    hair_rings: List[List[Vec3]] = []
    hair_uvs: List[List[Vec2]] = []

    for hy in hair_y:
        ring = []
        ruvs = []
        lv = clamp((1.650 - hy) / (1.650 - 1.430), 0.04, 0.94)
        for j in range(hair_segs + 1):
            frac = j / hair_segs
            theta = (frac - 0.5) * 2.0 * math.pi  # -pi back -> 0 front -> +pi back
            s_th, c_th = math.sin(theta), math.cos(theta)

            # Smooth feminine off-center parting near theta = +0.16 (~x=+0.012)
            part_dip = 0.009 * math.exp(-((theta - 0.16) / 0.30) ** 2)
            face_weight = max(0.0, c_th)
            hairline_y = 1.434 + 0.132 * (face_weight ** 0.78) + part_dip

            if hy >= 1.622:
                # Smooth spherical crown dome from y=1.622 up to y=1.650 (no cone peak!)
                t_dome = clamp((hy - 1.622) / (1.650 - 1.622), 0.0, 1.0)
                alpha = t_dome * (math.pi * 0.44)  # end ring radius ~cos(0.44*pi) so cap_end sits smoothly at 1.650
                rad_scale = math.cos(alpha)
                base_x, _, base_z = head_surface_point(1.622, theta)
                radial_thick = 0.010 + 0.004 * (1.0 - face_weight)
                rx_dome = base_x * (1.0 + radial_thick / 0.068)
                rz_dome = (base_z - 0.004) * (1.0 + radial_thick / 0.082) + 0.004
                px = rx_dome * rad_scale
                pz = lerp(-0.004, rz_dome, rad_scale)
                py = 1.622 + 0.028 * (math.sin(alpha) / math.sin(math.pi * 0.44))
            elif hy >= hairline_y:
                base_x, _, base_z = head_surface_point(min(hy, 1.637), theta)
                edge_fade = smoothstep(hairline_y, hairline_y + 0.032, hy)
                radial_thick = (0.009 + 0.005 * (1.0 - face_weight)) * edge_fade + 0.002
                px = base_x * (1.0 + radial_thick / 0.068)
                pz = (base_z - 0.004) * (1.0 + radial_thick / 0.082) + 0.004
                py = hy
            else:
                snap_y = hairline_y
                base_x, _, base_z = head_surface_point(min(snap_y, 1.637), theta)
                px, py, pz = base_x * 0.96, snap_y, lerp(0.005, base_z, 0.96)

            ring.append((px, py, pz))
            ruvs.append(uv_map("hair", lerp(0.05, 0.95, frac), lv))
        hair_rings.append(ring)
        hair_uvs.append(ruvs)

    mb.add_loft(hair_rings, hair_uvs, region="head", smooth_group=55, cap_start=True, cap_end=True)

    # 4. Two Layered Face-Framing Side Locks (sweeping past temples/ears toward low ponytail)
    for side_sign in (1.0, -1.0):
        lock_pts = [
            (side_sign * 0.022, 1.578, 0.068),
            (side_sign * 0.056, 1.560, 0.056),
            (side_sign * 0.072, 1.525, 0.030),
            (side_sign * 0.068, 1.482, -0.015),
            (side_sign * 0.044, 1.454, -0.058),
            (side_sign * 0.014, 1.446, -0.086),
        ]
        mb.add_tube(
            centers=lock_pts,
            rx_list=[0.008, 0.013, 0.014, 0.012, 0.010, 0.007],
            ry_list=[0.007, 0.011, 0.011, 0.010, 0.009, 0.007],
            radial_segs=10,
            island="hair",
            region="head",
            smooth_group=56 if side_sign > 0 else 57,
            u_span=(0.1, 0.9),
            v_span=(0.1, 0.9),
        )

    # 5. Hair Tie Band + Layered Low Ponytail Mass (all inside head-mesh, tagged "head")
    # Hair tie collar around nape/occiput at (0.0, 1.446, -0.088)
    tie_pts = [
        (0.0, 1.452, -0.080),
        (0.0, 1.446, -0.090),
        (0.0, 1.440, -0.098),
    ]
    mb.add_tube(
        centers=tie_pts,
        rx_list=[0.022, 0.025, 0.022],
        ry_list=[0.020, 0.023, 0.020],
        radial_segs=14,
        island="hair_tie",
        region="head",
        smooth_group=58,
        up_hint=(0.0, 1.0, 0.0),
    )

    # Main Ponytail Body (sweeps back and gracefully down behind neck/upper back)
    pony_centers = [
        (0.0, 1.445, -0.090),
        (0.0, 1.425, -0.114),
        (0.0, 1.385, -0.128),
        (0.0, 1.335, -0.130),
        (0.0, 1.285, -0.124),
        (0.0, 1.245, -0.116),
    ]
    mb.add_tube(
        centers=pony_centers,
        rx_list=[0.017, 0.022, 0.023, 0.019, 0.014, 0.007],
        ry_list=[0.018, 0.028, 0.033, 0.029, 0.021, 0.009],
        radial_segs=14,
        island="hair",
        region="head",
        smooth_group=59,
        up_hint=(0.0, 0.0, -1.0),
        u_span=(0.1, 0.9),
        v_span=(0.1, 0.95),
    )

    # Twin secondary wavy side tails hugging the main ponytail for organic layered silhouette
    for sx in (1.0, -1.0):
        sub_centers = [
            (sx * 0.010, 1.440, -0.094),
            (sx * 0.020, 1.402, -0.120),
            (sx * 0.018, 1.345, -0.126),
            (sx * 0.010, 1.292, -0.119),
            (sx * 0.004, 1.262, -0.114),
        ]
        mb.add_tube(
            centers=sub_centers,
            rx_list=[0.009, 0.012, 0.012, 0.009, 0.005],
            ry_list=[0.010, 0.014, 0.015, 0.011, 0.005],
            radial_segs=10,
            island="hair",
            region="head",
            smooth_group=60 if sx > 0 else 61,
            up_hint=(0.0, 0.0, -1.0),
            u_span=(0.1, 0.9),
            v_span=(0.15, 0.95),
        )

    return mb


# ---------------------------------------------------------------------------
# Procedural 1024x1024 PBR Albedo Texture Painter (Pillow)
# ---------------------------------------------------------------------------
def _uv_to_px(u: float, v: float) -> Tuple[int, int]:
    return (int(round(u * (TEX_SIZE - 1))), int(round(v * (TEX_SIZE - 1))))


def _island_px_box(island_name: str, bleed_px: int = 8) -> Tuple[int, int, int, int]:
    u0, v0, u1, v1 = UV_ISLANDS[island_name]
    x0, y0 = _uv_to_px(u0, v0)
    x1, y1 = _uv_to_px(u1, v1)
    return (
        max(0, x0 - bleed_px),
        max(0, y0 - bleed_px),
        min(TEX_SIZE - 1, x1 + bleed_px),
        min(TEX_SIZE - 1, y1 + bleed_px),
    )


def _make_tiled_pattern(
    tile_w: int,
    tile_h: int,
    seed: int,
    gen_fn,
) -> Image.Image:
    """Create a small deterministic procedural tile and return it for fast tiling."""
    rng = random.Random(seed)
    tile = Image.new("RGB", (tile_w, tile_h))
    px = tile.load()
    for y in range(tile_h):
        for x in range(tile_w):
            px[x, y] = gen_fn(x, y, rng)
    return tile


def _fill_island_with_tile(img: Image.Image, box: Tuple[int, int, int, int], tile: Image.Image) -> None:
    x0, y0, x1, y1 = box
    tw, th = tile.size
    for yy in range(y0, y1 + 1, th):
        for xx in range(x0, x1 + 1, tw):
            cw = min(tw, x1 + 1 - xx)
            ch = min(th, y1 + 1 - yy)
            crop = tile.crop((0, 0, cw, ch)) if (cw < tw or ch < th) else tile
            img.paste(crop, (xx, yy))


def _paint_face_island(img: Image.Image, box: Tuple[int, int, int, int]) -> None:
    """Paint warm Indonesian adult female face using exact UV coordinates from head_uv()."""
    x0, y0, x1, y1 = box

    # Warm Indonesian complexion base with subtle soft pore warmth
    skin_base = (196, 144, 112)
    skin_tile = _make_tiled_pattern(
        64,
        64,
        101,
        lambda x, y, r: (
            clamp(int(skin_base[0] + r.randint(-3, 3)), 0, 255),
            clamp(int(skin_base[1] + r.randint(-3, 3)), 0, 255),
            clamp(int(skin_base[2] + r.randint(-2, 2)), 0, 255),
        ),
    )
    _fill_island_with_tile(img, box, skin_tile)

    # Soft overlay layer for seamlessly blended facial shading (no hard rectangular edges!)
    overlay = Image.new("RGBA", (TEX_SIZE, TEX_SIZE), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)

    # Smooth chin/under-jaw shadow ellipse
    jaw_x, jaw_y = _uv_to_px(*head_uv(1.428, 0.0))
    od.ellipse([jaw_x - 85, jaw_y - 26, jaw_x + 85, jaw_y + 40], fill=(154, 108, 82, 85))

    # Subtle scalp/hairline shadow near forehead top
    fh_x, fh_y = _uv_to_px(*head_uv(1.576, 0.0))
    od.ellipse([fh_x - 110, y0 - 20, fh_x + 110, fh_y + 10], fill=(142, 98, 74, 75))

    # Warm rosy-terracotta cheek blush & soft orbital shadow
    for th_sign in (-1.0, 1.0):
        chk_x, chk_y = _uv_to_px(*head_uv(1.500, th_sign * 0.52))
        od.ellipse([chk_x - 26, chk_y - 16, chk_x + 26, chk_y + 18], fill=(198, 118, 96, 65))

        eye_x, eye_y = _uv_to_px(*head_uv(1.524, th_sign * 0.40))
        od.ellipse([eye_x - 20, eye_y - 12, eye_x + 20, eye_y + 12], fill=(142, 98, 74, 80))

    # Nose bridge soft highlight & under-tip/nostril shadow
    nb_x, nb_y0 = _uv_to_px(*head_uv(1.528, 0.0))
    _, nb_y1 = _uv_to_px(*head_uv(1.498, 0.0))
    od.ellipse([nb_x - 7, nb_y0 - 4, nb_x + 7, nb_y1 + 4], fill=(216, 168, 136, 95))
    nt_x, nt_y = _uv_to_px(*head_uv(1.493, 0.0))
    od.ellipse([nt_x - 11, nt_y - 4, nt_x + 11, nt_y + 6], fill=(138, 92, 70, 95))

    overlay_blurred = overlay.filter(ImageFilter.GaussianBlur(radius=14))
    img_rgba = Image.alpha_composite(img.convert("RGBA"), overlay_blurred)
    img.paste(img_rgba.convert("RGB"))

    # Crisp facial details layer (eyes, lashes, irises, curved brows, nostrils, lips)
    detail = Image.new("RGBA", (TEX_SIZE, TEX_SIZE), (0, 0, 0, 0))
    dd = ImageDraw.Draw(detail)

    for th_sign in (-1.0, 1.0):
        ex, ey = _uv_to_px(*head_uv(1.524, th_sign * 0.40))
        # Almond sclera
        dd.ellipse([ex - 13, ey - 6, ex + 13, ey + 6], fill=(230, 222, 214, 240))
        # Rich dark-brown iris & crisp pupil
        dd.ellipse([ex - 6, ey - 6, ex + 6, ey + 6], fill=(42, 24, 17, 255))
        dd.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=(14, 10, 10, 255))
        # Specular catchlight
        dd.ellipse([ex - 2, ey - 4, ex + 1, ey - 1], fill=(246, 242, 238, 215))
        # Upper lash line & gentle eyelid crease
        dd.arc([ex - 15, ey - 8, ex + 15, ey + 8], start=190, end=350, fill=(20, 14, 12, 255), width=3)
        dd.arc([ex - 14, ey - 11, ex + 14, ey + 3], start=205, end=335, fill=(108, 70, 52, 135), width=1)
        dd.arc([ex - 12, ey - 5, ex + 12, ey + 6], start=15, end=165, fill=(72, 46, 36, 130), width=1)

        # Smooth, natural feminine arched eyebrow (soft curve, grounded expression)
        brow_pts = [
            _uv_to_px(*head_uv(1.538, th_sign * 0.22)),
            _uv_to_px(*head_uv(1.540, th_sign * 0.31)),
            _uv_to_px(*head_uv(1.541, th_sign * 0.41)),
            _uv_to_px(*head_uv(1.540, th_sign * 0.50)),
            _uv_to_px(*head_uv(1.537, th_sign * 0.57)),
        ]
        dd.line(brow_pts, fill=(32, 22, 18, 210), width=3, joint="curve")

        # Subtle nostrils
        nx, ny = _uv_to_px(*head_uv(1.495, th_sign * 0.095))
        dd.ellipse([nx - 3, ny - 2, nx + 3, ny + 2], fill=(108, 70, 52, 155))

    # Natural feminine lips (muted terracotta-rose)
    lx_l, ly_c = _uv_to_px(*head_uv(1.472, -0.22))
    lx_r, _ = _uv_to_px(*head_uv(1.472, 0.22))
    lx_c, ly_up = _uv_to_px(*head_uv(1.477, 0.0))
    _, ly_lo = _uv_to_px(*head_uv(1.466, 0.0))
    dd.polygon(
        [
            (lx_l, ly_c),
            (int(lerp(lx_l, lx_c, 0.6)), ly_up),
            (lx_c, ly_up + 2),
            (int(lerp(lx_r, lx_c, 0.6)), ly_up),
            (lx_r, ly_c),
            (lx_c, ly_c + 1),
        ],
        fill=(152, 88, 82, 215),
    )
    dd.polygon(
        [
            (lx_l + 2, ly_c),
            (lx_c, ly_c + 1),
            (lx_r - 2, ly_c),
            (int(lerp(lx_r, lx_c, 0.55)), ly_lo),
            (int(lerp(lx_l, lx_c, 0.55)), ly_lo),
        ],
        fill=(170, 104, 96, 215),
    )
    dd.line([(lx_l, ly_c), (lx_c, ly_c + 1), (lx_r, ly_c)], fill=(102, 56, 52, 185), width=2)

    detail_soft = detail.filter(ImageFilter.GaussianBlur(radius=1.0))
    img_rgba = Image.alpha_composite(img.convert("RGBA"), detail_soft)
    img.paste(img_rgba.convert("RGB"))


def generate_albedo_texture(out_path: str) -> None:
    """Paint a rich, crisp 1024x1024 PBR albedo texture matching UV_ISLANDS."""
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    # Neutral dark-warm background between islands so unused pixels never create bright seams
    img = Image.new("RGB", (TEX_SIZE, TEX_SIZE), (36, 30, 28))
    draw = ImageDraw.Draw(img)

    # 1. Face & Upper Neck Skin Island
    _paint_face_island(img, _island_px_box("face"))

    # 2. Hands, Ears, Lower Neck Skin Islands
    skin_tile = _make_tiled_pattern(
        64,
        64,
        202,
        lambda x, y, r: (
            clamp(194 + r.randint(-4, 4), 0, 255),
            clamp(142 + r.randint(-3, 3), 0, 255),
            clamp(110 + r.randint(-3, 3), 0, 255),
        ),
    )
    for skin_island in ("hands", "ears", "lower_neck"):
        box = _island_px_box(skin_island)
        _fill_island_with_tile(img, box, skin_tile)
    # Hand palm/knuckle/nail shading details
    hx0, hy0, hx1, hy1 = _island_px_box("hands", bleed_px=0)
    hw, hh = hx1 - hx0, hy1 - hy0
    # Slightly warmer/darker underside & knuckle lines
    draw.rectangle([hx0 + int(hw * 0.25), hy0, hx0 + int(hw * 0.52), hy1], fill=(182, 130, 100))
    for k_frac in (0.35, 0.55, 0.72):
        ky = hy0 + int(hh * k_frac)
        draw.line([(hx0, ky), (hx1, ky)], fill=(166, 114, 86), width=2)
    # Subtle fingernail tips along finger ends
    draw.rectangle([hx0 + int(hw * 0.72), hy0 + int(hh * 0.85), hx1, hy1], fill=(214, 174, 152))
    # Ear inner concha shadow
    ex0, ey0, ex1, ey1 = _island_px_box("ears", bleed_px=0)
    draw.ellipse([ex0 + 18, ey0 + 18, ex1 - 18, ey1 - 18], fill=(154, 108, 82))

    # 3. Dark Indonesian Hair & Ponytail + Hair Tie
    hair_tile = _make_tiled_pattern(
        64,
        64,
        303,
        lambda x, y, r: (
            clamp(int(26 + 8 * math.sin(x * 0.55) + r.randint(-3, 4)), 0, 255),
            clamp(int(21 + 6 * math.sin(x * 0.55) + r.randint(-2, 3)), 0, 255),
            clamp(int(20 + 5 * math.sin(x * 0.55) + r.randint(-2, 3)), 0, 255),
        ),
    )
    hbox = _island_px_box("hair")
    _fill_island_with_tile(img, hbox, hair_tile)
    # Hair strand sheen streaks
    hx_a, hy_a, hx_b, hy_b = hbox
    rng_h = random.Random(304)
    for _ in range(95):
        sx = rng_h.randint(hx_a, hx_b)
        col = (46, 36, 32) if rng_h.random() > 0.3 else (18, 14, 14)
        draw.line([(sx, hy_a), (sx + rng_h.randint(-4, 4), hy_b)], fill=col, width=2)
    # Hair tie dark maroon-slate cloth band
    tbox = _island_px_box("hair_tie")
    draw.rectangle(tbox, fill=(56, 24, 28))

    # 4. Weathered Dark Burgundy Utility Jacket & Sleeves
    jacket_tile = _make_tiled_pattern(
        64,
        64,
        404,
        lambda x, y, r: (
            clamp(int(88 + (((x + y) % 4 == 0) * 5 - 3) + r.randint(-4, 4)), 0, 255),
            clamp(int(28 + (((x + y) % 4 == 0) * 2 - 2) + r.randint(-2, 2)), 0, 255),
            clamp(int(34 + (((x + y) % 4 == 0) * 2 - 2) + r.randint(-2, 2)), 0, 255),
        ),
    )
    for j_isl in ("jacket", "sleeve"):
        jbox = _island_px_box(j_isl)
        _fill_island_with_tile(img, jbox, jacket_tile)
        jx0, jy0, jx1, jy1 = jbox
        # Subtle vertical princess seams & lapel highlight
        for f in (0.14, 0.36, 0.64, 0.86):
            sx = int(lerp(jx0, jx1, f))
            draw.line([(sx, jy0), (sx, jy1)], fill=(62, 18, 22), width=2)
            draw.line([(sx + 2, jy0), (sx + 2, jy1)], fill=(110, 42, 48), width=1)
        # Weathered hem dirt/grime toward bottom of jacket & cuffs
        hem_y = int(lerp(jy0, jy1, 0.85))
        for yy in range(hem_y, jy1 + 1):
            t = (yy - hem_y) / max(1, jy1 - hem_y)
            dark_r = int(lerp(88, 52, t))
            dark_g = int(lerp(28, 22, t))
            dark_b = int(lerp(34, 24, t))
            draw.line([(jx0, yy), (jx1, yy)], fill=(dark_r, dark_g, dark_b), width=1)

    # 5. Muted Cream/Slate High-Neck Tunic Shirt
    tunic_tile = _make_tiled_pattern(
        64,
        64,
        505,
        lambda x, y, r: (
            clamp(int(174 + (4 if x % 3 == 0 else -3) + r.randint(-3, 3)), 0, 255),
            clamp(int(166 + (4 if x % 3 == 0 else -3) + r.randint(-3, 3)), 0, 255),
            clamp(int(156 + (3 if x % 3 == 0 else -3) + r.randint(-3, 3)), 0, 255),
        ),
    )
    tunic_box = _island_px_box("tunic")
    _fill_island_with_tile(img, tunic_box, tunic_tile)
    tx0, ty0, tx1, ty1 = tunic_box
    # High-neck collar seam shading
    draw.line([(tx0, ty0 + 28), (tx1, ty0 + 28)], fill=(138, 130, 120), width=3)

    # 6. Slim Leather Belt & Brass Buckle
    belt_box = _island_px_box("belt")
    draw.rectangle(belt_box, fill=(64, 41, 29))
    bx0, by0, bx1, by1 = belt_box
    draw.line([(bx0, by0 + 10), (bx1, by0 + 10)], fill=(90, 60, 42), width=2)
    draw.line([(bx0, by1 - 10), (bx1, by1 - 10)], fill=(44, 28, 20), width=2)

    buckle_box = _island_px_box("buckle")
    draw.rectangle(buckle_box, fill=(166, 140, 88))
    kx0, ky0, kx1, ky1 = buckle_box
    draw.rectangle([kx0 + 12, ky0 + 12, kx1 - 12, ky1 - 12], fill=(108, 86, 52))
    draw.rectangle([kx0 + 8, ky0 + 8, kx1 - 8, ky1 - 8], outline=(206, 180, 122), width=3)

    # 7. Fitted Dark Slate-Charcoal Trousers
    trouser_tile = _make_tiled_pattern(
        64,
        64,
        707,
        lambda x, y, r: (
            clamp(int(42 + (((x + y) % 5 == 0) * 4 - 2) + r.randint(-3, 3)), 0, 255),
            clamp(int(46 + (((x + y) % 5 == 0) * 4 - 2) + r.randint(-3, 3)), 0, 255),
            clamp(int(55 + (((x + y) % 5 == 0) * 4 - 2) + r.randint(-3, 3)), 0, 255),
        ),
    )
    tr_box = _island_px_box("trousers")
    _fill_island_with_tile(img, tr_box, trouser_tile)
    rx0, ry0, rx1, ry1 = tr_box
    # Side trouser seam lines & soft localized front-knee fade (no horizontal band!)
    for f in (0.25, 0.75):
        sx = int(lerp(rx0, rx1, f))
        draw.line([(sx, ry0), (sx, ry1)], fill=(28, 31, 38), width=3)
    knee_y = int(lerp(ry0, ry1, 0.54))
    knee_x = (rx0 + rx1) // 2
    knee_ov = Image.new("RGBA", (TEX_SIZE, TEX_SIZE), (0, 0, 0, 0))
    kod = ImageDraw.Draw(knee_ov)
    kod.ellipse([knee_x - 52, knee_y - 24, knee_x + 52, knee_y + 24], fill=(64, 70, 82, 95))
    img.paste(Image.alpha_composite(img.convert("RGBA"), knee_ov.filter(ImageFilter.GaussianBlur(radius=10))).convert("RGB"))
    draw = ImageDraw.Draw(img)
    # Lower cuff dried mud gradient
    cuff_y = int(lerp(ry0, ry1, 0.82))
    for yy in range(cuff_y, ry1 + 1):
        t = (yy - cuff_y) / max(1, ry1 - cuff_y)
        draw.line(
            [(rx0, yy), (rx1, yy)],
            fill=(int(lerp(42, 54, t)), int(lerp(46, 44, t)), int(lerp(55, 38, t))),
            width=1,
        )

    # 8. Weathered Ankle Survival Boots & Rubber Soles
    boot_tile = _make_tiled_pattern(
        64,
        64,
        808,
        lambda x, y, r: (
            clamp(44 + r.randint(-4, 4), 0, 255),
            clamp(32 + r.randint(-3, 3), 0, 255),
            clamp(26 + r.randint(-3, 3), 0, 255),
        ),
    )
    ubox = _island_px_box("boot_upper")
    _fill_island_with_tile(img, ubox, boot_tile)
    ux0, uy0, ux1, uy1 = ubox
    # Lace panel down center + padded ankle rim + weathered mud edge
    ucx = (ux0 + ux1) // 2
    draw.rectangle([ux0, uy0, ux1, uy0 + 22], fill=(58, 42, 34))
    draw.rectangle([ucx - 18, uy0 + 24, ucx + 18, int(lerp(uy0, uy1, 0.65))], fill=(30, 22, 18))
    for ly in range(uy0 + 32, int(lerp(uy0, uy1, 0.62)), 16):
        draw.line([(ucx - 14, ly), (ucx + 14, ly + 8)], fill=(120, 96, 76), width=3)
        draw.line([(ucx + 14, ly), (ucx - 14, ly + 8)], fill=(120, 96, 76), width=3)
    # Muddy lower welt
    mud_y = int(lerp(uy0, uy1, 0.78))
    for yy in range(mud_y, uy1 + 1):
        t = (yy - mud_y) / max(1, uy1 - mud_y)
        draw.line(
            [(ux0, yy), (ux1, yy)],
            fill=(int(lerp(44, 62, t)), int(lerp(32, 48, t)), int(lerp(26, 38, t))),
            width=1,
        )

    sole_box = _island_px_box("boot_sole")
    draw.rectangle(sole_box, fill=(26, 24, 24))
    sx0, sy0, sx1, sy1 = sole_box
    for sy in range(sy0 + 10, sy1, 14):
        draw.line([(sx0, sy), (sx1, sy)], fill=(42, 36, 32), width=3)

    img.save(out_path, format="PNG")


# ---------------------------------------------------------------------------
# Verification & Main Pipeline
# ---------------------------------------------------------------------------
def verify_mesh_and_texture(payload: Dict, tex_path: str) -> None:
    required_joints = set(JOINTS.keys())
    assert set(payload["joints"].keys()) == required_joints, "Joint keys mismatch"
    assert payload["character_id"] == "adult_female"
    assert abs(payload["height"] - 1.65) < 1e-6

    min_y, max_y = 1e9, -1e9
    min_x, max_x = 1e9, -1e9
    min_z, max_z = 1e9, -1e9

    for mesh_name in ("body-mesh", "head-mesh"):
        m = payload["meshes"][mesh_name]
        pos = m["positions"]
        nrm = m["normals"]
        uvs = m["uvs"]
        idx = m["indices"]
        reg = m["regions"]

        n_v = len(pos)
        assert n_v > 0 and len(nrm) == n_v and len(uvs) == n_v and len(reg) == n_v
        assert len(idx) % 3 == 0 and len(idx) > 0

        for p in pos:
            assert len(p) == 3 and all(math.isfinite(c) for c in p)
            min_x, max_x = min(min_x, p[0]), max(max_x, p[0])
            min_y, max_y = min(min_y, p[1]), max(max_y, p[1])
            min_z, max_z = min(min_z, p[2]), max(max_z, p[2])

        for n in nrm:
            assert len(n) == 3 and all(math.isfinite(c) for c in n)
            l = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2)
            assert abs(l - 1.0) < 1e-3, f"Non-unit normal {n}"

        for uv in uvs:
            assert 0.005 <= uv[0] <= 0.995 and 0.005 <= uv[1] <= 0.995, f"UV out of safe range: {uv}"

        for r in reg:
            assert r in ALLOWED_REGIONS, f"Invalid region: {r}"

        for t in range(0, len(idx), 3):
            i0, i1, i2 = idx[t], idx[t + 1], idx[t + 2]
            assert 0 <= i0 < n_v and 0 <= i1 < n_v and 0 <= i2 < n_v
            assert i0 != i1 and i1 != i2 and i0 != i2

    assert -0.001 <= min_y <= 0.005, f"Feet min_y expected ~0.0, got {min_y}"
    assert 1.64 <= max_y <= 1.66, f"Head max_y expected ~1.65, got {max_y}"

    with Image.open(tex_path) as im:
        assert im.size == (1024, 1024), f"Expected 1024x1024, got {im.size}"
        assert im.mode in ("RGB", "RGBA")

    print(
        f"VERIFY OK | bounds X:[{min_x:.3f},{max_x:.3f}] Y:[{min_y:.3f},{max_y:.3f}] Z:[{min_z:.3f},{max_z:.3f}]"
    )


def main() -> None:
    os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)
    os.makedirs(os.path.dirname(OUTPUT_TEX_PATH), exist_ok=True)

    body_mb = build_body_mesh()
    head_mb = build_head_mesh()

    payload = {
        "character_id": "adult_female",
        "height": 1.65,
        "texture_path": TEXTURE_REL_PATH,
        "joints": JOINTS,
        "meshes": {
            "body-mesh": body_mb.export_dict(),
            "head-mesh": head_mb.export_dict(),
        },
    }

    generate_albedo_texture(OUTPUT_TEX_PATH)

    with open(OUTPUT_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f)

    verify_mesh_and_texture(payload, OUTPUT_TEX_PATH)

    for m_name, m_data in payload["meshes"].items():
        v_cnt = len(m_data["positions"])
        t_cnt = len(m_data["indices"]) // 3
        print(f"  {m_name}: {v_cnt} verts, {t_cnt} tris")


if __name__ == "__main__":
    main()
