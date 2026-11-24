#!/usr/bin/env python3
"""Rig and animate Adult Male and Adult Female character meshes into Godot-ready GLB files.

Reads:
  - tools/characters/output/adult_male_mesh.json + assets/models/player/adult_male_albedo.png
  - tools/characters/output/adult_female_mesh.json + assets/models/player/adult_female_albedo.png

Writes:
  - assets/models/player/adult_male.glb
  - assets/models/player/adult_female.glb
"""

from __future__ import annotations

import json
import math
import os
import struct
from typing import Dict, List, Optional, Sequence, Tuple

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))

CHARACTERS = [
    {
        "id": "adult_male",
        "mesh_json": os.path.join(SCRIPT_DIR, "output", "adult_male_mesh.json"),
        "albedo_png": os.path.join(PROJECT_ROOT, "assets", "models", "player", "adult_male_albedo.png"),
        "out_glb": os.path.join(PROJECT_ROOT, "assets", "models", "player", "adult_male.glb"),
        "is_female": False,
    },
    {
        "id": "adult_female",
        "mesh_json": os.path.join(SCRIPT_DIR, "output", "adult_female_mesh.json"),
        "albedo_png": os.path.join(PROJECT_ROOT, "assets", "models", "player", "adult_female_albedo.png"),
        "out_glb": os.path.join(PROJECT_ROOT, "assets", "models", "player", "adult_female.glb"),
        "is_female": True,
    },
]

# Exact 19-bone humanoid skeleton hierarchy (indices 0..18)
BONES: List[Tuple[str, Optional[int]]] = [
    ("Hips", None),        # 0
    ("Torso", 0),          # 1
    ("Chest", 1),          # 2
    ("Neck", 2),           # 3
    ("Head", 3),           # 4
    ("Shoulder.L", 2),     # 5
    ("UpperArm.L", 5),     # 6
    ("LowerArm.L", 6),     # 7
    ("Hand.L", 7),         # 8
    ("Shoulder.R", 2),     # 9
    ("UpperArm.R", 9),     # 10
    ("LowerArm.R", 10),    # 11
    ("Hand.R", 11),        # 12
    ("UpperLeg.L", 0),     # 13
    ("LowerLeg.L", 13),    # 14
    ("Foot.L", 14),        # 15
    ("UpperLeg.R", 0),     # 16
    ("LowerLeg.R", 16),    # 17
    ("Foot.R", 17),        # 18
]

BONE_INDEX: Dict[str, int] = {name: idx for idx, (name, _) in enumerate(BONES)}

REGION_ALLOWED_BONES: Dict[str, Tuple[str, ...]] = {
    "head": ("Head", "Neck"),
    "neck": ("Chest", "Neck", "Head"),
    "torso": ("Hips", "Torso", "Chest", "Shoulder.L", "Shoulder.R"),
    "arm_l": ("Chest", "Shoulder.L", "UpperArm.L", "LowerArm.L", "Hand.L"),
    "arm_r": ("Chest", "Shoulder.R", "UpperArm.R", "LowerArm.R", "Hand.R"),
    "leg_l": ("Hips", "UpperLeg.L", "LowerLeg.L", "Foot.L"),
    "leg_r": ("Hips", "UpperLeg.R", "LowerLeg.R", "Foot.R"),
}

LOOPING_ANIMS = {"idle", "walk", "sprint", "fall", "crouch", "abducted"}

ANIMATION_SPECS: Tuple[Tuple[str, float], ...] = (
    ("idle", 2.40),
    ("walk", 0.88),
    ("sprint", 0.56),
    ("jump", 0.45),
    ("fall", 0.60),
    ("crouch", 1.00),
    ("interact-right", 0.45),
    ("pick-up", 0.50),
    ("kentongan_hit", 0.55),
    ("drink", 0.65),
    ("die", 0.70),
    ("abducted", 1.20),
)


# ---------------------------------------------------------------------------
# Math helpers: vectors, quaternions (x, y, z, w), 4x4 column-major matrices
# ---------------------------------------------------------------------------

Vec3 = Tuple[float, float, float]
Quat = Tuple[float, float, float, float]  # (x, y, z, w)


def clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else (hi if v > hi else v)


def smooth_cos(t: float) -> float:
    """Smooth C1 cosine ease from 0 to 1 on [0, 1]."""
    u = clamp(t, 0.0, 1.0)
    return 0.5 - 0.5 * math.cos(math.pi * u)


def smooth_step(x: float, edge0: float, edge1: float) -> float:
    """Smooth cosine ramp from 0 at edge0 to 1 at edge1."""
    if abs(edge1 - edge0) < 1e-8:
        return 1.0 if x >= edge1 else 0.0
    return smooth_cos((x - edge0) / (edge1 - edge0))


def v_sub(a: Sequence[float], b: Sequence[float]) -> Vec3:
    return (float(a[0] - b[0]), float(a[1] - b[1]), float(a[2] - b[2]))


def v_add(a: Sequence[float], b: Sequence[float]) -> Vec3:
    return (float(a[0] + b[0]), float(a[1] + b[1]), float(a[2] + b[2]))


def v_dot(a: Sequence[float], b: Sequence[float]) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def v_len(a: Sequence[float]) -> float:
    return math.sqrt(v_dot(a, a))


def v_norm(a: Sequence[float]) -> Vec3:
    l = v_len(a)
    if l < 1e-12:
        return (0.0, 0.0, 0.0)
    return (a[0] / l, a[1] / l, a[2] / l)


def point_segment_distance(p: Vec3, a: Vec3, b: Vec3) -> Tuple[float, float]:
    """Return (distance, clamped projection t in [0, 1]) from p to segment a->b."""
    ab = v_sub(b, a)
    ab2 = v_dot(ab, ab)
    if ab2 < 1e-12:
        return (v_len(v_sub(p, a)), 0.0)
    t = clamp(v_dot(v_sub(p, a), ab) / ab2, 0.0, 1.0)
    proj = (a[0] + ab[0] * t, a[1] + ab[1] * t, a[2] + ab[2] * t)
    return (v_len(v_sub(p, proj)), t)


def q_norm(q: Sequence[float]) -> Quat:
    l = math.sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3])
    if l < 1e-12:
        return (0.0, 0.0, 0.0, 1.0)
    return (q[0] / l, q[1] / l, q[2] / l, q[3] / l)


def q_conj(q: Sequence[float]) -> Quat:
    return (-q[0], -q[1], -q[2], q[3])


def q_mul(a: Sequence[float], b: Sequence[float]) -> Quat:
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def q_axis_angle(axis: Vec3, deg: float) -> Quat:
    if abs(deg) < 1e-9:
        return (0.0, 0.0, 0.0, 1.0)
    ax, ay, az = v_norm(axis)
    half = math.radians(deg) * 0.5
    s = math.sin(half)
    c = math.cos(half)
    return q_norm((ax * s, ay * s, az * s, c))


def q_rotate_vec(q: Sequence[float], v: Vec3) -> Vec3:
    qx, qy, qz, qw = q
    vx, vy, vz = v
    # t = 2 * cross(q_xyz, v)
    tx = 2.0 * (qy * vz - qz * vy)
    ty = 2.0 * (qz * vx - qx * vz)
    tz = 2.0 * (qx * vy - qy * vx)
    # v' = v + qw * t + cross(q_xyz, t)
    return (
        vx + qw * tx + (qy * tz - qz * ty),
        vy + qw * ty + (qz * tx - qx * tz),
        vz + qw * tz + (qx * ty - qy * tx),
    )


def q_dot(a: Sequence[float], b: Sequence[float]) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]


def q_slerp(a: Quat, b: Quat, t: float) -> Quat:
    u = clamp(t, 0.0, 1.0)
    dot = q_dot(a, b)
    b_adj = b
    if dot < 0.0:
        dot = -dot
        b_adj = (-b[0], -b[1], -b[2], -b[3])
    if dot > 0.9995:
        res = (
            a[0] + u * (b_adj[0] - a[0]),
            a[1] + u * (b_adj[1] - a[1]),
            a[2] + u * (b_adj[2] - a[2]),
            a[3] + u * (b_adj[3] - a[3]),
        )
        return q_norm(res)
    theta_0 = math.acos(clamp(dot, -1.0, 1.0))
    sin_0 = math.sin(theta_0)
    theta = theta_0 * u
    s0 = math.cos(theta) - dot * math.sin(theta) / sin_0
    s1 = math.sin(theta) / sin_0
    return q_norm((
        s0 * a[0] + s1 * b_adj[0],
        s0 * a[1] + s1 * b_adj[1],
        s0 * a[2] + s1 * b_adj[2],
        s0 * a[3] + s1 * b_adj[3],
    ))


def mat4_from_trs(t: Vec3, q: Quat) -> List[List[float]]:
    """Build 4x4 row-major matrix M = T(t) * R(q)."""
    x, y, z, w = q_norm(q)
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    return [
        [1.0 - 2.0 * (yy + zz), 2.0 * (xy - wz), 2.0 * (xz + wy), t[0]],
        [2.0 * (xy + wz), 1.0 - 2.0 * (xx + zz), 2.0 * (yz - wx), t[1]],
        [2.0 * (xz - wy), 2.0 * (yz + wx), 1.0 - 2.0 * (xx + yy), t[2]],
        [0.0, 0.0, 0.0, 1.0],
    ]


def mat4_mul(a: List[List[float]], b: List[List[float]]) -> List[List[float]]:
    out = [[0.0] * 4 for _ in range(4)]
    for i in range(4):
        for j in range(4):
            out[i][j] = (
                a[i][0] * b[0][j]
                + a[i][1] * b[1][j]
                + a[i][2] * b[2][j]
                + a[i][3] * b[3][j]
            )
    return out


def mat4_rigid_inv(m: List[List[float]]) -> List[List[float]]:
    """Exact inverse of rigid 4x4 [R | t; 0 | 1]."""
    rt = [
        [m[0][0], m[1][0], m[2][0]],
        [m[0][1], m[1][1], m[2][1]],
        [m[0][2], m[1][2], m[2][2]],
    ]
    tx, ty, tz = m[0][3], m[1][3], m[2][3]
    inv_t = [
        -(rt[0][0] * tx + rt[0][1] * ty + rt[0][2] * tz),
        -(rt[1][0] * tx + rt[1][1] * ty + rt[1][2] * tz),
        -(rt[2][0] * tx + rt[2][1] * ty + rt[2][2] * tz),
    ]
    return [
        [rt[0][0], rt[0][1], rt[0][2], inv_t[0]],
        [rt[1][0], rt[1][1], rt[1][2], inv_t[1]],
        [rt[2][0], rt[2][1], rt[2][2], inv_t[2]],
        [0.0, 0.0, 0.0, 1.0],
    ]


def mat4_to_col_major(m: List[List[float]]) -> List[float]:
    return [m[r][c] for c in range(4) for r in range(4)]


# ---------------------------------------------------------------------------
# Skeleton Bind Pose & Inverse Bind Matrices
# ---------------------------------------------------------------------------

def get_rest_rotation(bone_name: str) -> Quat:
    if bone_name == "Hand.L":
        return q_axis_angle((0.0, 0.0, 1.0), -90.0)
    if bone_name == "Hand.R":
        return q_axis_angle((0.0, 0.0, 1.0), 90.0)
    return (0.0, 0.0, 0.0, 1.0)


def compute_bind_pose(joints_dict: Dict[str, List[float]]) -> Tuple[
    List[Vec3], List[Quat], List[List[List[float]]], List[List[List[float]]]
]:
    """Compute local translations, local rest rotations, global bind matrices, and IBMs."""
    local_t: List[Vec3] = []
    local_q: List[Quat] = []
    m_global: List[List[List[float]]] = []
    ibms: List[List[List[float]]] = []

    for idx, (bname, parent_idx) in enumerate(BONES):
        pos = tuple(float(v) for v in joints_dict[bname])
        if parent_idx is None:
            t = (pos[0], pos[1], pos[2])
        else:
            p_pos = joints_dict[BONES[parent_idx][0]]
            t = v_sub(pos, p_pos)
        q = get_rest_rotation(bname)
        m_loc = mat4_from_trs(t, q)
        m_g = m_loc if parent_idx is None else mat4_mul(m_global[parent_idx], m_loc)
        local_t.append(t)
        local_q.append(q)
        m_global.append(m_g)
        ibms.append(mat4_rigid_inv(m_g))

    return local_t, local_q, m_global, ibms


# ---------------------------------------------------------------------------
# Zero-Bleed Region-Aware Skin Weight Solver
# ---------------------------------------------------------------------------

def _finalize_weights(raw: Dict[str, float], allowed: Sequence[str]) -> Tuple[Tuple[int, int, int, int], Tuple[float, float, float, float]]:
    """Filter strictly to allowed bones, pick top 4, normalize sum == 1.0."""
    filtered = [(BONE_INDEX[b], max(0.0, float(w))) for b, w in raw.items() if b in allowed and w > 1e-6]
    if not filtered:
        filtered = [(BONE_INDEX[allowed[0]], 1.0)]
    filtered.sort(key=lambda item: item[1], reverse=True)
    top4 = filtered[:4]
    total = sum(w for _, w in top4)
    if total <= 1e-12:
        top4 = [(BONE_INDEX[allowed[0]], 1.0)]
        total = 1.0
    normed = [(j, w / total) for j, w in top4]
    while len(normed) < 4:
        normed.append((0, 0.0))
    # Fix float rounding error on largest weight so sum == 1.0 strictly
    s_other = sum(w for _, w in normed[1:])
    normed[0] = (normed[0][0], max(0.0, 1.0 - s_other))
    j_tuple = (normed[0][0], normed[1][0], normed[2][0], normed[3][0])
    w_tuple = (normed[0][1], normed[1][1], normed[2][1], normed[3][1])
    return j_tuple, w_tuple


def _limb_arm_weights(p: Vec3, joints: Dict[str, Vec3], side: str) -> Dict[str, float]:
    """Smooth capsule-segment weights along Chest -> Shoulder -> UpperArm -> LowerArm -> Hand -> tip."""
    sign = 1.0 if side == "L" else -1.0
    b_chest = "Chest"
    b_sh = f"Shoulder.{side}"
    b_up = f"UpperArm.{side}"
    b_lo = f"LowerArm.{side}"
    b_ha = f"Hand.{side}"

    x_abs = p[0] * sign
    sh_x = joints[b_sh][0] * sign
    up_x = joints[b_up][0] * sign
    lo_x = joints[b_lo][0] * sign
    ha_x = joints[b_ha][0] * sign
    tip_pos = (joints[b_ha][0] + sign * 0.16, joints[b_ha][1], joints[b_ha][2])

    # Evaluate true 3D capsule segment proximity along the 5 segments
    segs = [
        (b_chest, b_sh, joints[b_chest], joints[b_sh], 0.065),
        (b_sh, b_up, joints[b_sh], joints[b_up], 0.055),
        (b_up, b_lo, joints[b_up], joints[b_lo], 0.050),
        (b_lo, b_ha, joints[b_lo], joints[b_ha], 0.042),
        (b_ha, b_ha, joints[b_ha], tip_pos, 0.038),
    ]
    best_dist = 1e9
    for _, _, a, b, _ in segs:
        d, _ = point_segment_distance(p, a, b)
        if d < best_dist:
            best_dist = d

    # Smooth monotonic anatomical arc transitions along lateral X while keeping
    # vertices medial of UpperArm pivot anchored cleanly to Chest/Shoulder.
    w_chest = 0.0
    w_sh = 0.0
    w_up = 0.0
    w_lo = 0.0
    w_ha = 0.0

    # 1) Shoulder root -> UpperArm transition: gentle deltoid ramp so +76 deg drop never folds armpit
    up_blend_lo = up_x - 0.018
    up_blend_hi = up_x + 0.115
    # 2) Elbow transition around LowerArm.x
    lo_blend_lo = lo_x - 0.050
    lo_blend_hi = lo_x + 0.050
    # 3) Wrist transition around Hand.x
    ha_blend_lo = ha_x - 0.032
    ha_blend_hi = ha_x + 0.020

    if x_abs < up_blend_hi:
        t_ch_sh = smooth_step(x_abs, sh_x + 0.01, up_x - 0.035)
        t_sh_up = smooth_step(x_abs, up_blend_lo, up_blend_hi)
        w_up = t_sh_up
        rem = 1.0 - w_up
        w_sh = rem * (0.35 + 0.65 * t_ch_sh)
        w_chest = rem - w_sh
    elif x_abs < lo_blend_lo:
        w_up = 1.0
    elif x_abs < lo_blend_hi:
        t_el = smooth_step(x_abs, lo_blend_lo, lo_blend_hi)
        w_up = 1.0 - t_el
        w_lo = t_el
    elif x_abs < ha_blend_lo:
        w_lo = 1.0
    elif x_abs < ha_blend_hi:
        t_wr = smooth_step(x_abs, ha_blend_lo, ha_blend_hi)
        w_lo = 1.0 - t_wr
        w_ha = t_wr
    else:
        w_ha = 1.0

    # Gentle Gaussian capsule refinement near elbow/wrist joints for 3D cylindrical smoothness
    if best_dist > 0.085 and x_abs < up_x:
        # Deep armpit/chest corner: reinforce Chest slightly
        extra_ch = clamp((best_dist - 0.085) * 2.0, 0.0, 0.25)
        w_chest += extra_ch

    return {b_chest: w_chest, b_sh: w_sh, b_up: w_up, b_lo: w_lo, b_ha: w_ha}


def _limb_leg_weights(p: Vec3, joints: Dict[str, Vec3], side: str) -> Dict[str, float]:
    """Smooth zero-bleed leg weights: Hips -> UpperLeg -> LowerLeg -> Foot."""
    b_up = f"UpperLeg.{side}"
    b_lo = f"LowerLeg.{side}"
    b_ft = f"Foot.{side}"

    y = p[1]
    z = p[2]
    up_y = joints[b_up][1]
    lo_y = joints[b_lo][1]
    ft_y = joints[b_ft][1]
    ft_z = joints[b_ft][2]

    # Hip socket transition: anchor pelvic top above UpperLeg.y, blend smoothly down thigh
    hip_lo = up_y - 0.165
    hip_hi = up_y + 0.010
    # Knee transition around LowerLeg.y
    knee_lo = lo_y - 0.058
    knee_hi = lo_y + 0.058
    # Ankle transition around Foot.y (boot toe-box stays 100% Foot)
    ankle_lo = ft_y - 0.015
    ankle_hi = ft_y + 0.048

    if y >= hip_hi:
        return {"Hips": 1.0}
    if y >= hip_lo:
        t = smooth_step(y, hip_lo, hip_hi)
        return {"Hips": t, b_up: 1.0 - t}
    if y >= knee_hi:
        return {b_up: 1.0}
    if y >= knee_lo:
        t = smooth_step(y, knee_lo, knee_hi)
        return {b_up: t, b_lo: 1.0 - t}
    if y >= ankle_hi:
        return {b_lo: 1.0}
    if y >= ankle_lo:
        # Forefoot/instep protruding forward (+Z) belongs solidly to Foot
        if z > ft_z + 0.045 and y < ft_y + 0.025:
            return {b_ft: 1.0}
        t = smooth_step(y, ankle_lo, ankle_hi)
        return {b_lo: t, b_ft: 1.0 - t}
    return {b_ft: 1.0}


def compute_vertex_skin(
    pos: Sequence[float], region: str, joints_raw: Dict[str, List[float]]
) -> Tuple[Tuple[int, int, int, int], Tuple[float, float, float, float]]:
    """Compute top-4 zero-bleed normalized skin indices & weights for one vertex."""
    joints: Dict[str, Vec3] = {k: (float(v[0]), float(v[1]), float(v[2])) for k, v in joints_raw.items()}
    p: Vec3 = (float(pos[0]), float(pos[1]), float(pos[2]))
    x, y, z = p
    allowed = REGION_ALLOWED_BONES[region]

    if region == "head":
        neck_y = joints["Neck"][1]
        if y >= neck_y + 0.05:
            raw = {"Head": 1.0}
        elif z < -0.055:
            # Hanging hair / ponytail behind neck stays tightly attached to Head
            t_tail = smooth_step(neck_y - y, 0.0, 0.16)
            w_neck = 0.10 * t_tail
            raw = {"Head": 1.0 - w_neck, "Neck": w_neck}
        else:
            t = smooth_step(y, neck_y, neck_y + 0.05)
            raw = {"Head": t, "Neck": 1.0 - t}
        return _finalize_weights(raw, allowed)

    if region == "neck":
        neck_y = joints["Neck"][1]
        if y <= neck_y:
            t_ch = smooth_step(y, neck_y - 0.055, neck_y)
            w_chest = 0.65 * (1.0 - t_ch)
            raw = {"Chest": w_chest, "Neck": 1.0 - w_chest}
        else:
            t_hd = smooth_step(y, neck_y, neck_y + 0.05)
            raw = {"Neck": 1.0 - t_hd, "Head": t_hd}
        return _finalize_weights(raw, allowed)

    if region == "torso":
        hips_y = joints["Hips"][1]
        torso_y = joints["Torso"][1]
        chest_y = joints["Chest"][1]
        sh_y = joints["Shoulder.L"][1]
        up_x = abs(joints["UpperArm.L"][0])

        if y <= hips_y:
            w_hips, w_torso, w_chest = 1.0, 0.0, 0.0
        elif y <= torso_y:
            u = smooth_step(y, hips_y, torso_y)
            w_hips, w_torso, w_chest = 1.0 - u, u, 0.0
        elif y <= chest_y:
            u = smooth_step(y, torso_y, chest_y)
            w_hips, w_torso, w_chest = 0.0, 1.0 - u, u
        else:
            w_hips, w_torso, w_chest = 0.0, 0.0, 1.0

        raw: Dict[str, float] = {"Hips": w_hips, "Torso": w_torso, "Chest": w_chest}

        # Gentle shoulder socket blend ONLY very close to shoulder socket |x| > ~0.12 and y > Chest.y
        if abs(x) > 0.12 and y > chest_y:
            tx = smooth_step(abs(x), 0.12, max(0.16, up_x))
            ty = smooth_step(y, chest_y, max(chest_y + 0.04, sh_y))
            w_sh = 0.25 * tx * ty
            if w_sh > 1e-6:
                scale = 1.0 - w_sh
                raw = {k: v * scale for k, v in raw.items()}
                raw["Shoulder.L" if x >= 0.0 else "Shoulder.R"] = w_sh

        return _finalize_weights(raw, allowed)

    if region == "arm_l":
        return _finalize_weights(_limb_arm_weights(p, joints, "L"), allowed)
    if region == "arm_r":
        return _finalize_weights(_limb_arm_weights(p, joints, "R"), allowed)
    if region == "leg_l":
        return _finalize_weights(_limb_leg_weights(p, joints, "L"), allowed)
    if region == "leg_r":
        return _finalize_weights(_limb_leg_weights(p, joints, "R"), allowed)

    raise ValueError(f"Unknown vertex region tag: {region!r}")


# ---------------------------------------------------------------------------
# Skeletal Animation Pose Math & All 12 Animations
# ---------------------------------------------------------------------------

def world_delta_pose(
    rot_x_deg: float = 0.0,
    rot_drop_deg: float = 0.0,
    rot_y_deg: float = 0.0,
    rot_roll_deg: float = 0.0,
) -> Quat:
    """World-space rotation delta matching glTF Y-up convention:
       yaw(+Y), swing(+X), drop(-Z), optional roll(+Z).
    """
    q = (0.0, 0.0, 0.0, 1.0)
    if abs(rot_y_deg) > 1e-6:
        q = q_mul(q, q_axis_angle((0.0, 1.0, 0.0), rot_y_deg))
    if abs(rot_x_deg) > 1e-6:
        q = q_mul(q, q_axis_angle((1.0, 0.0, 0.0), rot_x_deg))
    if abs(rot_drop_deg) > 1e-6:
        q = q_mul(q, q_axis_angle((0.0, 0.0, -1.0), rot_drop_deg))
    if abs(rot_roll_deg) > 1e-6:
        q = q_mul(q, q_axis_angle((0.0, 0.0, 1.0), rot_roll_deg))
    return q_norm(q)


def _solve_pose_frame(
    joints: Dict[str, List[float]],
    bone_params: Dict[str, Tuple[float, ...]],
) -> Tuple[Vec3, List[Quat]]:
    """Convert intuitive per-bone pose angles into exact local translations & rotations.

    For UpperArm.L/R, (swing_x, drop_deg, yaw_y) specifies the desired world orientation
    relative to Shoulder's global frame (so Shoulder shrug doesn't twist UpperArm).
    For LowerArm.L/R, (elbow_flex_deg, twist_deg, adduction_deg) bends the elbow
    anatomically forward in UpperArm's local hinge plane!
    For Hand.L/R, (wrist_flex_deg, wrist_tilt_deg, wrist_twist_deg) offsets from
    the exact Hand bind-pose rotation R_z(+-90 deg).
    For spine/head/legs/shoulders, rotations compose cleanly along parent->child.
    """
    hips_bind = tuple(float(v) for v in joints["Hips"])
    hip_delta = bone_params.get("Hips_pos", (0.0, 0.0, 0.0))
    hips_t = (hips_bind[0] + hip_delta[0], hips_bind[1] + hip_delta[1], hips_bind[2] + hip_delta[2])

    local_q: List[Quat] = [(0.0, 0.0, 0.0, 1.0)] * len(BONES)
    global_q: List[Quat] = [(0.0, 0.0, 0.0, 1.0)] * len(BONES)

    for idx, (bname, parent_idx) in enumerate(BONES):
        rest_q = get_rest_rotation(bname)
        parent_gq = (0.0, 0.0, 0.0, 1.0) if parent_idx is None else global_q[parent_idx]
        p = bone_params.get(bname)

        if bname in ("UpperArm.L", "UpperArm.R"):
            side = "L" if bname.endswith(".L") else "R"
            default_drop = 76.0 if side == "L" else -76.0
            rx, rd, ry = p if p else (0.0, default_drop, 0.0)
            # World orientation of UpperArm relative to chest/body yaw+pitch, removing Shoulder twist
            chest_gq = global_q[BONE_INDEX["Chest"]]
            desired_gq = q_mul(chest_gq, world_delta_pose(rot_x_deg=rx, rot_drop_deg=rd, rot_y_deg=ry))
            ql = q_norm(q_mul(q_conj(parent_gq), desired_gq))
        elif bname in ("LowerArm.L", "LowerArm.R"):
            # Anatomical elbow hinge: bends forearm forward (+Z in UpperArm frame)
            # UpperArm.L local +X points down-arm -> bend toward +Z is around local -Y.
            # UpperArm.R local -X points down-arm -> bend toward +Z is around local +Y.
            side = "L" if bname.endswith(".L") else "R"
            flex_deg, twist_deg, add_deg = p if p else (0.0, 0.0, 0.0)
            hinge_axis = (0.0, -1.0, 0.0) if side == "L" else (0.0, 1.0, 0.0)
            q_bend = q_axis_angle(hinge_axis, flex_deg)
            q_twist = q_axis_angle((1.0 if side == "L" else -1.0, 0.0, 0.0), twist_deg)
            q_add = q_axis_angle((0.0, 0.0, -1.0 if side == "L" else 1.0), add_deg)
            ql = q_norm(q_mul(q_mul(q_add, q_bend), q_twist))
        elif bname in ("Hand.L", "Hand.R"):
            side = "L" if bname.endswith(".L") else "R"
            flex_deg, tilt_deg, twist_deg = p if p else (0.0, 0.0, 0.0)
            # Hand.L: +Y=fingers, +X=palm, +Z=thumb -> curl palm around -Z
            # Hand.R: +Y=fingers, -X=palm, +Z=thumb -> curl palm around +Z
            curl_axis = (0.0, 0.0, -1.0 if side == "L" else 1.0)
            q_off = q_mul(
                q_axis_angle(curl_axis, flex_deg),
                q_mul(q_axis_angle((1.0, 0.0, 0.0), tilt_deg), q_axis_angle((0.0, 1.0, 0.0), twist_deg)),
            )
            ql = q_norm(q_mul(rest_q, q_off))
        else:
            rx, rd, ry = p if p else (0.0, 0.0, 0.0)
            ql = q_norm(q_mul(rest_q, world_delta_pose(rot_x_deg=rx, rot_drop_deg=rd, rot_y_deg=ry)))

        local_q[idx] = ql
        global_q[idx] = q_norm(q_mul(parent_gq, ql))

    return hips_t, local_q


def _sample_keyframes(
    keyframes: List[Tuple[float, Dict[str, Tuple[float, ...]]]],
    joints: Dict[str, List[float]],
    duration: float,
    fps: int = 30,
) -> Tuple[List[float], List[Vec3], List[List[Quat]]]:
    """Interpolate intuitive control keyframes smoothly onto a uniform ~30fps grid."""
    n_steps = max(4, int(round(duration * fps)))
    times = [duration * i / n_steps for i in range(n_steps + 1)]
    times[0] = 0.0
    times[-1] = duration

    # Solve pose quaternions & hip positions at each control keyframe
    ctrl_t: List[float] = []
    ctrl_hip: List[Vec3] = []
    ctrl_q: List[List[Quat]] = []
    for t_k, params in keyframes:
        ht, qs = _solve_pose_frame(joints, params)
        ctrl_t.append(t_k)
        ctrl_hip.append(ht)
        ctrl_q.append(qs)

    out_hip: List[Vec3] = []
    out_q: List[List[Quat]] = []
    prev_q: Optional[List[Quat]] = None

    for t in times:
        # Locate segment [i, i+1]
        seg = 0
        for i in range(len(ctrl_t) - 1):
            if t >= ctrl_t[i] - 1e-9:
                seg = i
        t0, t1 = ctrl_t[seg], ctrl_t[seg + 1]
        u_lin = 0.0 if abs(t1 - t0) < 1e-9 else clamp((t - t0) / (t1 - t0), 0.0, 1.0)
        u = smooth_cos(u_lin)

        h0, h1 = ctrl_hip[seg], ctrl_hip[seg + 1]
        hip_pos = (
            h0[0] + u * (h1[0] - h0[0]),
            h0[1] + u * (h1[1] - h0[1]),
            h0[2] + u * (h1[2] - h0[2]),
        )
        out_hip.append(hip_pos)

        frame_q: List[Quat] = []
        for j in range(len(BONES)):
            q = q_slerp(ctrl_q[seg][j], ctrl_q[seg + 1][j], u)
            # Enforce hemisphere continuity so dot(q_prev, q_curr) >= 0 (no sign-flip pops)
            if prev_q is not None and q_dot(prev_q[j], q) < 0.0:
                q = (-q[0], -q[1], -q[2], -q[3])
            frame_q.append(q)
        out_q.append(frame_q)
        prev_q = frame_q

    return times, out_hip, out_q


def _build_all_animation_keyframes(
    joints: Dict[str, List[float]], is_female: bool
) -> Dict[str, Tuple[List[float], List[Vec3], List[List[Quat]]]]:
    """Build smooth keyframe curves for all 12 contract animations."""
    hips_y = float(joints["Hips"][1])
    # Exact knee/hip flexion so crouch -0.33m keeps boots resting right on ground y=0
    up_leg_y = float(joints["UpperLeg.L"][1])
    lo_leg_y = float(joints["LowerLeg.L"][1])
    ft_y = float(joints["Foot.L"][1])
    l_thigh = up_leg_y - lo_leg_y
    l_shin = lo_leg_y - ft_y
    # Target leg vertical height = (up_leg_y - ft_y) - 0.33
    crouch_hip_deg = -61.0 if is_female else -60.0
    crouch_knee_deg = 109.0 if is_female else 108.0
    crouch_ankle_deg = -(crouch_hip_deg + crouch_knee_deg)
    # Double-check exact hip drop so foot stays at y=ft_y (floor y=0)
    crouch_drop_m = -0.33

    # Subtle gender-aware posture nuances
    idle_arm_drop = 77.5 if is_female else 75.5
    idle_hip_sway = 1.1 if is_female else 0.7
    walk_hip_roll = 4.6 if is_female else 3.2
    walk_leg_fwd = -28.0 if is_female else -30.0
    walk_leg_back = 23.0 if is_female else 24.0
    walk_arm_swing = 20.0 if is_female else 22.0
    walk_elbow_base = 22.0 if is_female else 18.0

    # 1. idle (2.40s)
    idle_kf = [
        (0.00, {
            "Hips_pos": (0.0, 0.0, 0.0),
            "Hips": (0.5, idle_hip_sway, 0.6),
            "Torso": (0.8, -0.5, -0.4),
            "Chest": (-0.6, 0.0, 0.0),
            "Neck": (0.5, 0.0, 0.0),
            "Head": (0.4, 0.0, -0.6),
            "Shoulder.L": (0.0, 1.5, 0.0),
            "Shoulder.R": (0.0, -1.5, 0.0),
            "UpperArm.L": (4.0, idle_arm_drop, -2.0),
            "LowerArm.L": (18.0, 8.0, 0.0),
            "Hand.L": (6.0, 0.0, 0.0),
            "UpperArm.R": (5.0, -idle_arm_drop, 2.0),
            "LowerArm.R": (18.0, 8.0, 0.0),
            "Hand.R": (6.0, 0.0, 0.0),
            "UpperLeg.L": (-2.0, 0.0, 0.0),
            "LowerLeg.L": (4.0, 0.0, 0.0),
            "Foot.L": (-2.0, 0.0, 0.0),
            "UpperLeg.R": (-3.0, 0.0, 0.0),
            "LowerLeg.R": (5.5, 0.0, 0.0),
            "Foot.R": (-2.0, 0.0, 0.0),
        }),
        (0.60, {
            "Hips_pos": (0.0, 0.003, 0.0),
            "Hips": (0.2, -0.4, -0.3),
            "Torso": (1.6, 0.3, 0.3),
            "Chest": (1.4, 0.0, 0.4),
            "Neck": (-0.4, 0.0, 0.4),
            "Head": (1.4, 0.0, 0.8),
            "Shoulder.L": (-1.2, 2.5, 0.0),
            "Shoulder.R": (-1.2, -2.5, 0.0),
            "UpperArm.L": (2.5, idle_arm_drop - 1.5, 0.0),
            "LowerArm.L": (21.0, 10.0, 0.0),
            "Hand.L": (8.0, 0.0, 0.0),
            "UpperArm.R": (3.0, -(idle_arm_drop - 1.5), 0.0),
            "LowerArm.R": (21.0, 10.0, 0.0),
            "Hand.R": (8.0, 0.0, 0.0),
            "UpperLeg.L": (-2.8, 0.0, 0.0),
            "LowerLeg.L": (5.2, 0.0, 0.0),
            "Foot.L": (-2.4, 0.0, 0.0),
            "UpperLeg.R": (-2.2, 0.0, 0.0),
            "LowerLeg.R": (4.4, 0.0, 0.0),
            "Foot.R": (-2.2, 0.0, 0.0),
        }),
        (1.20, {
            "Hips_pos": (0.0, 0.006, 0.0),
            "Hips": (0.8, -idle_hip_sway, -0.6),
            "Torso": (0.0, 0.6, 0.5),
            "Chest": (2.2, 0.0, -0.4),
            "Neck": (-0.8, 0.0, 0.0),
            "Head": (-0.6, 0.0, -0.4),
            "Shoulder.L": (-1.8, 3.0, 0.0),
            "Shoulder.R": (-1.8, -3.0, 0.0),
            "UpperArm.L": (1.5, idle_arm_drop - 2.2, 1.5),
            "LowerArm.L": (23.0, 10.0, 0.0),
            "Hand.L": (9.0, 0.0, 0.0),
            "UpperArm.R": (2.0, -(idle_arm_drop - 2.2), -1.5),
            "LowerArm.R": (23.0, 10.0, 0.0),
            "Hand.R": (9.0, 0.0, 0.0),
            "UpperLeg.L": (-3.5, 0.0, 0.0),
            "LowerLeg.L": (6.5, 0.0, 0.0),
            "Foot.L": (-3.0, 0.0, 0.0),
            "UpperLeg.R": (-1.5, 0.0, 0.0),
            "LowerLeg.R": (3.5, 0.0, 0.0),
            "Foot.R": (-2.0, 0.0, 0.0),
        }),
        (1.80, {
            "Hips_pos": (0.0, 0.002, 0.0),
            "Hips": (0.4, 0.3, 0.2),
            "Torso": (1.0, -0.2, -0.2),
            "Chest": (0.4, 0.0, 0.2),
            "Neck": (0.0, 0.0, -0.2),
            "Head": (0.8, 0.0, 0.4),
            "Shoulder.L": (-0.6, 2.0, 0.0),
            "Shoulder.R": (-0.6, -2.0, 0.0),
            "UpperArm.L": (3.0, idle_arm_drop - 0.8, -0.5),
            "LowerArm.L": (20.0, 9.0, 0.0),
            "Hand.L": (7.0, 0.0, 0.0),
            "UpperArm.R": (4.0, -(idle_arm_drop - 0.8), 0.5),
            "LowerArm.R": (20.0, 9.0, 0.0),
            "Hand.R": (7.0, 0.0, 0.0),
            "UpperLeg.L": (-2.5, 0.0, 0.0),
            "LowerLeg.L": (5.0, 0.0, 0.0),
            "Foot.L": (-2.5, 0.0, 0.0),
            "UpperLeg.R": (-2.5, 0.0, 0.0),
            "LowerLeg.R": (4.5, 0.0, 0.0),
            "Foot.R": (-2.0, 0.0, 0.0),
        }),
    ]
    idle_kf.append((2.40, idle_kf[0][1]))

    # 2. walk (0.88s)
    walk_kf = [
        (0.00, {
            "Hips_pos": (-0.008, -0.020, 0.0),
            "Hips": (2.5, -walk_hip_roll * 0.6, 3.8),
            "Torso": (3.5, 1.8, -4.5),
            "Chest": (2.5, 0.8, -2.0),
            "Head": (-2.0, 0.0, 1.2),
            "Shoulder.L": (0.0, 1.5, -2.0),
            "Shoulder.R": (0.0, -1.5, 2.0),
            "UpperArm.L": (walk_arm_swing, 75.0, -4.0),
            "LowerArm.L": (walk_elbow_base, 10.0, 0.0),
            "Hand.L": (8.0, 0.0, 0.0),
            "UpperArm.R": (-walk_arm_swing - 2.0, -75.0, -5.0),
            "LowerArm.R": (42.0, 14.0, 0.0),
            "Hand.R": (10.0, 0.0, 0.0),
            "UpperLeg.L": (walk_leg_fwd, 0.0, 0.0),
            "LowerLeg.L": (12.0, 0.0, 0.0),
            "Foot.L": (-10.0, 0.0, 0.0),
            "UpperLeg.R": (walk_leg_back, 0.0, 0.0),
            "LowerLeg.R": (32.0, 0.0, 0.0),
            "Foot.R": (16.0, 0.0, 0.0),
        }),
        (0.22, {
            "Hips_pos": (0.006, 0.014, 0.0),
            "Hips": (1.5, 0.0, 1.2),
            "Torso": (4.5, 0.0, -1.5),
            "Chest": (3.0, 0.0, 0.0),
            "Head": (-2.5, 0.0, 0.0),
            "UpperArm.L": (4.0, 76.5, 0.0),
            "LowerArm.L": (28.0, 12.0, 0.0),
            "Hand.L": (9.0, 0.0, 0.0),
            "UpperArm.R": (-2.0, -76.5, 0.0),
            "LowerArm.R": (30.0, 12.0, 0.0),
            "Hand.R": (9.0, 0.0, 0.0),
            "UpperLeg.L": (-4.0, 0.0, 0.0),
            "LowerLeg.L": (16.0, 0.0, 0.0),
            "Foot.L": (-4.0, 0.0, 0.0),
            "UpperLeg.R": (-12.0, 0.0, 0.0),
            "LowerLeg.R": (50.0, 0.0, 0.0),
            "Foot.R": (6.0, 0.0, 0.0),
        }),
        (0.44, {
            "Hips_pos": (0.008, -0.020, 0.0),
            "Hips": (2.5, walk_hip_roll * 0.6, -3.8),
            "Torso": (3.5, -1.8, 4.5),
            "Chest": (2.5, -0.8, 2.0),
            "Head": (-2.0, 0.0, -1.2),
            "Shoulder.L": (0.0, 1.5, 2.0),
            "Shoulder.R": (0.0, -1.5, -2.0),
            "UpperArm.L": (-walk_arm_swing - 2.0, 75.0, 5.0),
            "LowerArm.L": (42.0, 14.0, 0.0),
            "Hand.L": (10.0, 0.0, 0.0),
            "UpperArm.R": (walk_arm_swing, -75.0, 4.0),
            "LowerArm.R": (walk_elbow_base, 10.0, 0.0),
            "Hand.R": (8.0, 0.0, 0.0),
            "UpperLeg.L": (walk_leg_back, 0.0, 0.0),
            "LowerLeg.L": (32.0, 0.0, 0.0),
            "Foot.L": (16.0, 0.0, 0.0),
            "UpperLeg.R": (walk_leg_fwd, 0.0, 0.0),
            "LowerLeg.R": (12.0, 0.0, 0.0),
            "Foot.R": (-10.0, 0.0, 0.0),
        }),
        (0.66, {
            "Hips_pos": (-0.006, 0.014, 0.0),
            "Hips": (1.5, 0.0, -1.2),
            "Torso": (4.5, 0.0, 1.5),
            "Chest": (3.0, 0.0, 0.0),
            "Head": (-2.5, 0.0, 0.0),
            "UpperArm.L": (-2.0, 76.5, 0.0),
            "LowerArm.L": (30.0, 12.0, 0.0),
            "Hand.L": (9.0, 0.0, 0.0),
            "UpperArm.R": (4.0, -76.5, 0.0),
            "LowerArm.R": (28.0, 12.0, 0.0),
            "Hand.R": (9.0, 0.0, 0.0),
            "UpperLeg.L": (-12.0, 0.0, 0.0),
            "LowerLeg.L": (50.0, 0.0, 0.0),
            "Foot.L": (6.0, 0.0, 0.0),
            "UpperLeg.R": (-4.0, 0.0, 0.0),
            "LowerLeg.R": (16.0, 0.0, 0.0),
            "Foot.R": (-4.0, 0.0, 0.0),
        }),
    ]
    walk_kf.append((0.88, walk_kf[0][1]))

    # 3. sprint (0.56s)
    sprint_kf = [
        (0.00, {
            "Hips_pos": (-0.010, -0.026, 0.0),
            "Hips": (6.0, -3.5, 6.0),
            "Torso": (9.0, 2.5, -7.5),
            "Chest": (6.0, 1.5, -4.0),
            "Neck": (-4.0, 0.0, 0.0),
            "Head": (-6.0, 0.0, 1.5),
            "Shoulder.L": (-2.0, 2.0, -3.0),
            "Shoulder.R": (-2.0, -2.0, 3.0),
            "UpperArm.L": (36.0, 71.0, -8.0),
            "LowerArm.L": (56.0, 18.0, 0.0),
            "Hand.L": (16.0, 0.0, 0.0),
            "UpperArm.R": (-42.0, -69.0, -10.0),
            "LowerArm.R": (82.0, 20.0, 0.0),
            "Hand.R": (18.0, 0.0, 0.0),
            "UpperLeg.L": (-48.0, 0.0, 0.0),
            "LowerLeg.L": (20.0, 0.0, 0.0),
            "Foot.L": (-12.0, 0.0, 0.0),
            "UpperLeg.R": (38.0, 0.0, 0.0),
            "LowerLeg.R": (56.0, 0.0, 0.0),
            "Foot.R": (22.0, 0.0, 0.0),
        }),
        (0.14, {
            "Hips_pos": (0.008, 0.026, 0.0),
            "Hips": (4.0, 0.0, 2.0),
            "Torso": (11.0, 0.0, -2.0),
            "Chest": (8.0, 0.0, 0.0),
            "Neck": (-5.0, 0.0, 0.0),
            "Head": (-7.0, 0.0, 0.0),
            "UpperArm.L": (4.0, 72.0, 0.0),
            "LowerArm.L": (66.0, 18.0, 0.0),
            "Hand.L": (16.0, 0.0, 0.0),
            "UpperArm.R": (-6.0, -72.0, 0.0),
            "LowerArm.R": (68.0, 18.0, 0.0),
            "Hand.R": (16.0, 0.0, 0.0),
            "UpperLeg.L": (-6.0, 0.0, 0.0),
            "LowerLeg.L": (24.0, 0.0, 0.0),
            "Foot.L": (-4.0, 0.0, 0.0),
            "UpperLeg.R": (-18.0, 0.0, 0.0),
            "LowerLeg.R": (78.0, 0.0, 0.0),
            "Foot.R": (10.0, 0.0, 0.0),
        }),
        (0.28, {
            "Hips_pos": (0.010, -0.026, 0.0),
            "Hips": (6.0, 3.5, -6.0),
            "Torso": (9.0, -2.5, 7.5),
            "Chest": (6.0, -1.5, 4.0),
            "Neck": (-4.0, 0.0, 0.0),
            "Head": (-6.0, 0.0, -1.5),
            "Shoulder.L": (-2.0, 2.0, 3.0),
            "Shoulder.R": (-2.0, -2.0, -3.0),
            "UpperArm.L": (-42.0, 69.0, 10.0),
            "LowerArm.L": (82.0, 20.0, 0.0),
            "Hand.L": (18.0, 0.0, 0.0),
            "UpperArm.R": (36.0, -71.0, 8.0),
            "LowerArm.R": (56.0, 18.0, 0.0),
            "Hand.R": (16.0, 0.0, 0.0),
            "UpperLeg.L": (38.0, 0.0, 0.0),
            "LowerLeg.L": (56.0, 0.0, 0.0),
            "Foot.L": (22.0, 0.0, 0.0),
            "UpperLeg.R": (-48.0, 0.0, 0.0),
            "LowerLeg.R": (20.0, 0.0, 0.0),
            "Foot.R": (-12.0, 0.0, 0.0),
        }),
        (0.42, {
            "Hips_pos": (-0.008, 0.026, 0.0),
            "Hips": (4.0, 0.0, -2.0),
            "Torso": (11.0, 0.0, 2.0),
            "Chest": (8.0, 0.0, 0.0),
            "Neck": (-5.0, 0.0, 0.0),
            "Head": (-7.0, 0.0, 0.0),
            "UpperArm.L": (-6.0, 72.0, 0.0),
            "LowerArm.L": (68.0, 18.0, 0.0),
            "Hand.L": (16.0, 0.0, 0.0),
            "UpperArm.R": (4.0, -72.0, 0.0),
            "LowerArm.R": (66.0, 18.0, 0.0),
            "Hand.R": (16.0, 0.0, 0.0),
            "UpperLeg.L": (-18.0, 0.0, 0.0),
            "LowerLeg.L": (78.0, 0.0, 0.0),
            "Foot.L": (10.0, 0.0, 0.0),
            "UpperLeg.R": (-6.0, 0.0, 0.0),
            "LowerLeg.R": (24.0, 0.0, 0.0),
            "Foot.R": (-4.0, 0.0, 0.0),
        }),
    ]
    sprint_kf.append((0.56, sprint_kf[0][1]))

    # 4. jump (0.45s)
    jump_kf = [
        (0.00, {
            "Hips_pos": (0.0, -0.05, 0.0),
            "Torso": (8.0, 0.0, 0.0),
            "Chest": (4.0, 0.0, 0.0),
            "Head": (-4.0, 0.0, 0.0),
            "UpperArm.L": (-12.0, 68.0, 0.0),
            "LowerArm.L": (34.0, 10.0, 0.0),
            "UpperArm.R": (-12.0, -68.0, 0.0),
            "LowerArm.R": (34.0, 10.0, 0.0),
            "UpperLeg.L": (-24.0, 0.0, 0.0),
            "LowerLeg.L": (42.0, 0.0, 0.0),
            "Foot.L": (-14.0, 0.0, 0.0),
            "UpperLeg.R": (-20.0, 0.0, 0.0),
            "LowerLeg.R": (36.0, 0.0, 0.0),
            "Foot.R": (-12.0, 0.0, 0.0),
        }),
        (0.20, {
            "Hips_pos": (0.0, 0.06, 0.0),
            "Torso": (6.0, 0.0, 0.0),
            "Chest": (2.0, 0.0, 0.0),
            "Head": (-4.0, 0.0, 0.0),
            "Shoulder.L": (-5.0, 3.0, 0.0),
            "Shoulder.R": (-5.0, -3.0, 0.0),
            "UpperArm.L": (-28.0, 56.0, 0.0),
            "LowerArm.L": (40.0, 12.0, 0.0),
            "UpperArm.R": (-28.0, -56.0, 0.0),
            "LowerArm.R": (40.0, 12.0, 0.0),
            "UpperLeg.L": (-28.0, 0.0, 0.0),
            "LowerLeg.L": (46.0, 0.0, 0.0),
            "Foot.L": (12.0, 0.0, 0.0),
            "UpperLeg.R": (-10.0, 0.0, 0.0),
            "LowerLeg.R": (26.0, 0.0, 0.0),
            "Foot.R": (16.0, 0.0, 0.0),
        }),
        (0.45, {
            "Hips_pos": (0.0, 0.04, 0.0),
            "Torso": (6.0, 0.0, 0.0),
            "Chest": (2.0, 0.0, 0.0),
            "Head": (-4.0, 0.0, 0.0),
            "Shoulder.L": (-4.0, 2.0, 0.0),
            "Shoulder.R": (-4.0, -2.0, 0.0),
            "UpperArm.L": (-34.0, 52.0, 0.0),
            "LowerArm.L": (42.0, 12.0, 0.0),
            "UpperArm.R": (-34.0, -52.0, 0.0),
            "LowerArm.R": (42.0, 12.0, 0.0),
            "UpperLeg.L": (-32.0, 0.0, 0.0),
            "LowerLeg.L": (52.0, 0.0, 0.0),
            "Foot.L": (14.0, 0.0, 0.0),
            "UpperLeg.R": (-14.0, 0.0, 0.0),
            "LowerLeg.R": (30.0, 0.0, 0.0),
            "Foot.R": (18.0, 0.0, 0.0),
        }),
    ]

    # 5. fall (0.60s)
    fall_kf = [
        (0.00, {
            "Hips_pos": (0.0, 0.0, 0.0),
            "Torso": (6.0, 0.0, 0.0),
            "Chest": (2.0, 0.0, 0.0),
            "Head": (-4.0, 0.0, 0.0),
            "Shoulder.L": (-4.0, 2.0, 0.0),
            "Shoulder.R": (-4.0, -2.0, 0.0),
            "UpperArm.L": (-18.0, 52.0, 0.0),
            "LowerArm.L": (36.0, 10.0, 0.0),
            "UpperArm.R": (-18.0, -52.0, 0.0),
            "LowerArm.R": (36.0, 10.0, 0.0),
            "UpperLeg.L": (-18.0, 0.0, 0.0),
            "LowerLeg.L": (30.0, 0.0, 0.0),
            "Foot.L": (12.0, 0.0, 0.0),
            "UpperLeg.R": (-12.0, 0.0, 0.0),
            "LowerLeg.R": (22.0, 0.0, 0.0),
            "Foot.R": (14.0, 0.0, 0.0),
        }),
        (0.30, {
            "Hips_pos": (0.0, 0.015, 0.0),
            "Torso": (4.0, 0.0, 0.0),
            "Chest": (4.0, 0.0, 0.0),
            "Head": (-5.0, 0.0, 0.0),
            "Shoulder.L": (-6.0, 3.0, 0.0),
            "Shoulder.R": (-6.0, -3.0, 0.0),
            "UpperArm.L": (-26.0, 48.0, -4.0),
            "LowerArm.L": (44.0, 12.0, 0.0),
            "UpperArm.R": (-24.0, -48.0, 4.0),
            "LowerArm.R": (44.0, 12.0, 0.0),
            "UpperLeg.L": (-22.0, 0.0, 0.0),
            "LowerLeg.L": (36.0, 0.0, 0.0),
            "Foot.L": (15.0, 0.0, 0.0),
            "UpperLeg.R": (-16.0, 0.0, 0.0),
            "LowerLeg.R": (28.0, 0.0, 0.0),
            "Foot.R": (16.0, 0.0, 0.0),
        }),
    ]
    fall_kf.append((0.60, fall_kf[0][1]))

    # 6. crouch (1.00s) — exact -0.33m Hips drop with grounded boots
    crouch_kf = [
        (0.00, {
            "Hips_pos": (0.0, crouch_drop_m, 0.0),
            "Hips": (4.0, 0.0, 0.0),
            "Torso": (16.0, 0.0, 0.0),
            "Chest": (8.0, 0.0, 0.0),
            "Neck": (-8.0, 0.0, 0.0),
            "Head": (-14.0, 0.0, 0.0),
            "Shoulder.L": (0.0, 3.0, 0.0),
            "Shoulder.R": (0.0, -3.0, 0.0),
            "UpperArm.L": (-24.0, 73.0, -6.0),
            "LowerArm.L": (46.0, 14.0, 0.0),
            "Hand.L": (10.0, 0.0, 0.0),
            "UpperArm.R": (-24.0, -73.0, 6.0),
            "LowerArm.R": (46.0, 14.0, 0.0),
            "Hand.R": (10.0, 0.0, 0.0),
            "UpperLeg.L": (crouch_hip_deg, 0.0, 0.0),
            "LowerLeg.L": (crouch_knee_deg, 0.0, 0.0),
            "Foot.L": (crouch_ankle_deg - 4.0, 0.0, 0.0),
            "UpperLeg.R": (crouch_hip_deg, 0.0, 0.0),
            "LowerLeg.R": (crouch_knee_deg, 0.0, 0.0),
            "Foot.R": (crouch_ankle_deg - 4.0, 0.0, 0.0),
        }),
        (0.50, {
            "Hips_pos": (0.0, crouch_drop_m - 0.012, 0.0),
            "Hips": (4.5, 0.0, 0.0),
            "Torso": (18.0, 0.0, 0.0),
            "Chest": (9.5, 0.0, 0.0),
            "Neck": (-9.0, 0.0, 0.0),
            "Head": (-15.0, 0.0, 0.0),
            "Shoulder.L": (-1.0, 4.0, 0.0),
            "Shoulder.R": (-1.0, -4.0, 0.0),
            "UpperArm.L": (-26.0, 72.0, -7.0),
            "LowerArm.L": (50.0, 15.0, 0.0),
            "Hand.L": (12.0, 0.0, 0.0),
            "UpperArm.R": (-26.0, -72.0, 7.0),
            "LowerArm.R": (50.0, 15.0, 0.0),
            "Hand.R": (12.0, 0.0, 0.0),
            "UpperLeg.L": (crouch_hip_deg - 2.0, 0.0, 0.0),
            "LowerLeg.L": (crouch_knee_deg + 3.0, 0.0, 0.0),
            "Foot.L": (crouch_ankle_deg - 5.5, 0.0, 0.0),
            "UpperLeg.R": (crouch_hip_deg - 2.0, 0.0, 0.0),
            "LowerLeg.R": (crouch_knee_deg + 3.0, 0.0, 0.0),
            "Foot.R": (crouch_ankle_deg - 5.5, 0.0, 0.0),
        }),
    ]
    crouch_kf.append((1.00, crouch_kf[0][1]))

    # 7. interact-right (0.45s)
    interact_kf = [
        (0.00, idle_kf[0][1]),
        (0.18, {
            "Hips_pos": (0.0, -0.01, 0.0),
            "Hips": (2.0, 0.0, 3.0),
            "Torso": (6.0, 0.0, 6.0),
            "Chest": (4.0, 0.0, 4.0),
            "Head": (-4.0, 0.0, -5.0),
            "Shoulder.R": (-4.0, -4.0, 4.0),
            "UpperArm.L": (6.0, idle_arm_drop, 0.0),
            "LowerArm.L": (20.0, 8.0, 0.0),
            "UpperArm.R": (-62.0, -60.0, 10.0),
            "LowerArm.R": (36.0, 12.0, 0.0),
            "Hand.R": (-12.0, 0.0, 0.0),
            "UpperLeg.L": (-4.0, 0.0, 0.0),
            "LowerLeg.L": (8.0, 0.0, 0.0),
            "Foot.L": (-4.0, 0.0, 0.0),
            "UpperLeg.R": (-4.0, 0.0, 0.0),
            "LowerLeg.R": (8.0, 0.0, 0.0),
            "Foot.R": (-4.0, 0.0, 0.0),
        }),
        (0.45, idle_kf[0][1]),
    ]

    # 8. pick-up (0.50s)
    pickup_kf = [
        (0.00, idle_kf[0][1]),
        (0.22, {
            "Hips_pos": (0.0, -0.10, 0.0),
            "Hips": (8.0, 0.0, 2.0),
            "Torso": (22.0, 0.0, 4.0),
            "Chest": (10.0, 0.0, 3.0),
            "Neck": (-8.0, 0.0, 0.0),
            "Head": (-14.0, 0.0, -4.0),
            "Shoulder.R": (-6.0, -5.0, 6.0),
            "UpperArm.L": (10.0, idle_arm_drop, 0.0),
            "LowerArm.L": (24.0, 8.0, 0.0),
            "UpperArm.R": (-72.0, -64.0, 12.0),
            "LowerArm.R": (26.0, 10.0, 0.0),
            "Hand.R": (14.0, 0.0, 0.0),
            "UpperLeg.L": (-22.0, 0.0, 0.0),
            "LowerLeg.L": (44.0, 0.0, 0.0),
            "Foot.L": (-24.0, 0.0, 0.0),
            "UpperLeg.R": (-24.0, 0.0, 0.0),
            "LowerLeg.R": (46.0, 0.0, 0.0),
            "Foot.R": (-24.0, 0.0, 0.0),
        }),
        (0.50, idle_kf[0][1]),
    ]

    # 9. kentongan_hit (0.55s)
    k_ready_l = {"UpperArm.L": (-76.0, 48.0, -18.0), "LowerArm.L": (52.0, 16.0, 0.0), "Hand.L": (18.0, 0.0, 0.0)}
    kent_kf = [
        (0.00, {
            "Hips_pos": (0.0, 0.0, 0.0),
            "Torso": (2.0, 0.0, 0.0),
            "Chest": (2.0, 0.0, 0.0),
            **k_ready_l,
            "UpperArm.R": (-74.0, -48.0, 18.0),
            "LowerArm.R": (42.0, 14.0, 0.0),
            "Hand.R": (16.0, 0.0, 0.0),
            "UpperLeg.L": (-3.0, 0.0, 0.0),
            "LowerLeg.L": (6.0, 0.0, 0.0),
            "Foot.L": (-3.0, 0.0, 0.0),
            "UpperLeg.R": (-3.0, 0.0, 0.0),
            "LowerLeg.R": (6.0, 0.0, 0.0),
            "Foot.R": (-3.0, 0.0, 0.0),
        }),
        (0.14, {
            "Hips_pos": (0.0, 0.0, 0.0),
            "Torso": (4.0, 0.0, 4.0),
            "Chest": (3.0, 0.0, 4.0),
            **k_ready_l,
            "UpperArm.R": (-88.0, -44.0, 42.0),
            "LowerArm.R": (62.0, 18.0, 0.0),
            "Hand.R": (22.0, 0.0, 0.0),
            "UpperLeg.L": (-4.0, 0.0, 0.0),
            "LowerLeg.L": (8.0, 0.0, 0.0),
            "Foot.L": (-4.0, 0.0, 0.0),
            "UpperLeg.R": (-4.0, 0.0, 0.0),
            "LowerLeg.R": (8.0, 0.0, 0.0),
            "Foot.R": (-4.0, 0.0, 0.0),
        }),
        (0.28, {
            "Hips_pos": (0.0, 0.0, 0.0),
            "Torso": (2.0, 0.0, 1.0),
            "Chest": (2.0, 0.0, 1.0),
            **k_ready_l,
            "UpperArm.R": (-78.0, -48.0, 22.0),
            "LowerArm.R": (46.0, 14.0, 0.0),
            "Hand.R": (16.0, 0.0, 0.0),
            "UpperLeg.L": (-3.0, 0.0, 0.0),
            "LowerLeg.L": (6.0, 0.0, 0.0),
            "Foot.L": (-3.0, 0.0, 0.0),
            "UpperLeg.R": (-3.0, 0.0, 0.0),
            "LowerLeg.R": (6.0, 0.0, 0.0),
            "Foot.R": (-3.0, 0.0, 0.0),
        }),
        (0.42, {
            "Hips_pos": (0.0, 0.0, 0.0),
            "Torso": (4.0, 0.0, 4.0),
            "Chest": (3.0, 0.0, 4.0),
            **k_ready_l,
            "UpperArm.R": (-88.0, -44.0, 42.0),
            "LowerArm.R": (62.0, 18.0, 0.0),
            "Hand.R": (22.0, 0.0, 0.0),
            "UpperLeg.L": (-4.0, 0.0, 0.0),
            "LowerLeg.L": (8.0, 0.0, 0.0),
            "Foot.L": (-4.0, 0.0, 0.0),
            "UpperLeg.R": (-4.0, 0.0, 0.0),
            "LowerLeg.R": (8.0, 0.0, 0.0),
            "Foot.R": (-4.0, 0.0, 0.0),
        }),
        (0.55, {
            "Hips_pos": (0.0, 0.0, 0.0),
            "Torso": (2.0, 0.0, 0.0),
            "Chest": (2.0, 0.0, 0.0),
            **k_ready_l,
            "UpperArm.R": (-74.0, -48.0, 18.0),
            "LowerArm.R": (42.0, 14.0, 0.0),
            "Hand.R": (16.0, 0.0, 0.0),
            "UpperLeg.L": (-3.0, 0.0, 0.0),
            "LowerLeg.L": (6.0, 0.0, 0.0),
            "Foot.L": (-3.0, 0.0, 0.0),
            "UpperLeg.R": (-3.0, 0.0, 0.0),
            "LowerLeg.R": (6.0, 0.0, 0.0),
            "Foot.R": (-3.0, 0.0, 0.0),
        }),
    ]

    # 10. drink (0.65s)
    drink_sip = {
        "Hips_pos": (0.0, 0.0, 0.0),
        "Torso": (-3.0, 0.0, -2.0),
        "Chest": (-3.0, 0.0, 0.0),
        "Neck": (-5.0, 0.0, 0.0),
        "Head": (-10.0, 0.0, 0.0),
        "Shoulder.R": (-4.0, -3.0, 4.0),
        "UpperArm.L": (4.0, idle_arm_drop, -2.0),
        "LowerArm.L": (20.0, 8.0, 0.0),
        "UpperArm.R": (-98.0, -44.0, 34.0),
        "LowerArm.R": (78.0, 22.0, 0.0),
        "Hand.R": (14.0, 0.0, 0.0),
        "UpperLeg.L": (-2.0, 0.0, 0.0),
        "LowerLeg.L": (4.0, 0.0, 0.0),
        "Foot.L": (-2.0, 0.0, 0.0),
        "UpperLeg.R": (-3.0, 0.0, 0.0),
        "LowerLeg.R": (5.5, 0.0, 0.0),
        "Foot.R": (-2.0, 0.0, 0.0),
    }
    drink_kf = [
        (0.00, {
            **idle_kf[0][1],
            "UpperArm.R": (-76.0, -48.0, 18.0),
            "LowerArm.R": (44.0, 14.0, 0.0),
        }),
        (0.24, drink_sip),
        (0.46, drink_sip),
        (0.65, {
            **idle_kf[0][1],
            "UpperArm.R": (-76.0, -48.0, 18.0),
            "LowerArm.R": (44.0, 14.0, 0.0),
        }),
    ]

    # 11. die (0.70s) — smooth fall BACKWARD + Hips translation down so body rests on floor!
    die_floor_y = 0.12 - hips_y
    die_kf = [
        (0.00, idle_kf[0][1]),
        (0.24, {
            "Hips_pos": (0.0, die_floor_y * 0.25, -0.10),
            "Hips": (-34.0, 0.0, 0.0),
            "Torso": (-6.0, 0.0, 0.0),
            "Chest": (4.0, 0.0, 0.0),
            "Neck": (8.0, 0.0, 0.0),
            "Head": (10.0, 0.0, 0.0),
            "UpperArm.L": (-20.0, 62.0, -10.0),
            "LowerArm.L": (26.0, 8.0, 0.0),
            "UpperArm.R": (-20.0, -62.0, 10.0),
            "LowerArm.R": (26.0, 8.0, 0.0),
            "UpperLeg.L": (-16.0, 0.0, 0.0),
            "LowerLeg.L": (28.0, 0.0, 0.0),
            "Foot.L": (10.0, 0.0, 0.0),
            "UpperLeg.R": (-14.0, 0.0, 0.0),
            "LowerLeg.R": (24.0, 0.0, 0.0),
            "Foot.R": (10.0, 0.0, 0.0),
        }),
        (0.52, {
            "Hips_pos": (0.0, die_floor_y, -0.25),
            "Hips": (-85.0, 0.0, 0.0),
            "Torso": (0.0, 0.0, 0.0),
            "Chest": (2.0, 0.0, 0.0),
            "Neck": (6.0, 0.0, 0.0),
            "Head": (8.0, 0.0, 0.0),
            "UpperArm.L": (6.0, 56.0, -14.0),
            "LowerArm.L": (16.0, 6.0, 0.0),
            "UpperArm.R": (6.0, -56.0, 14.0),
            "LowerArm.R": (16.0, 6.0, 0.0),
            "UpperLeg.L": (-12.0, 0.0, 0.0),
            "LowerLeg.L": (22.0, 0.0, 0.0),
            "Foot.L": (14.0, 0.0, 0.0),
            "UpperLeg.R": (-8.0, 0.0, 0.0),
            "LowerLeg.R": (16.0, 0.0, 0.0),
            "Foot.R": (16.0, 0.0, 0.0),
        }),
        (0.70, {
            "Hips_pos": (0.0, die_floor_y, -0.26),
            "Hips": (-86.0, 0.0, 0.0),
            "Torso": (0.0, 0.0, 0.0),
            "Chest": (2.0, 0.0, 0.0),
            "Neck": (6.0, 0.0, 0.0),
            "Head": (8.0, 0.0, 0.0),
            "UpperArm.L": (8.0, 54.0, -14.0),
            "LowerArm.L": (14.0, 6.0, 0.0),
            "UpperArm.R": (8.0, -54.0, 14.0),
            "LowerArm.R": (14.0, 6.0, 0.0),
            "UpperLeg.L": (-10.0, 0.0, 0.0),
            "LowerLeg.L": (18.0, 0.0, 0.0),
            "Foot.L": (16.0, 0.0, 0.0),
            "UpperLeg.R": (-7.0, 0.0, 0.0),
            "LowerLeg.R": (14.0, 0.0, 0.0),
            "Foot.R": (18.0, 0.0, 0.0),
        }),
    ]

    # 12. abducted (1.20s) — helpless dangling kick & arm struggle
    abducted_kf = [
        (0.00, {
            "Hips_pos": (0.0, 0.0, 0.0),
            "Hips": (4.0, 3.0, 0.0),
            "Torso": (8.0, 0.0, -4.0),
            "Chest": (4.0, 0.0, -4.0),
            "Head": (-6.0, 0.0, 8.0),
            "Shoulder.L": (-6.0, 4.0, 0.0),
            "Shoulder.R": (-4.0, -4.0, 0.0),
            "UpperArm.L": (-115.0, 38.0, -12.0),
            "LowerArm.L": (30.0, 10.0, 0.0),
            "Hand.L": (16.0, 0.0, 0.0),
            "UpperArm.R": (-124.0, -34.0, 14.0),
            "LowerArm.R": (36.0, 10.0, 0.0),
            "Hand.R": (16.0, 0.0, 0.0),
            "UpperLeg.L": (14.0, 0.0, 4.0),
            "LowerLeg.L": (22.0, 0.0, 0.0),
            "Foot.L": (18.0, 0.0, 0.0),
            "UpperLeg.R": (-18.0, 0.0, -4.0),
            "LowerLeg.R": (46.0, 0.0, 0.0),
            "Foot.R": (24.0, 0.0, 0.0),
        }),
        (0.30, {
            "Hips_pos": (0.0, 0.012, 0.0),
            "Hips": (6.0, -2.0, 3.0),
            "Torso": (11.0, 0.0, 2.0),
            "Chest": (6.0, 0.0, 2.0),
            "Head": (-10.0, 0.0, -4.0),
            "Shoulder.L": (-8.0, 4.0, 0.0),
            "Shoulder.R": (-8.0, -4.0, 0.0),
            "UpperArm.L": (-130.0, 34.0, -16.0),
            "LowerArm.L": (42.0, 12.0, 0.0),
            "Hand.L": (20.0, 0.0, 0.0),
            "UpperArm.R": (-106.0, -40.0, 10.0),
            "LowerArm.R": (24.0, 8.0, 0.0),
            "Hand.R": (14.0, 0.0, 0.0),
            "UpperLeg.L": (-22.0, 0.0, 6.0),
            "LowerLeg.L": (52.0, 0.0, 0.0),
            "Foot.L": (26.0, 0.0, 0.0),
            "UpperLeg.R": (18.0, 0.0, -6.0),
            "LowerLeg.R": (20.0, 0.0, 0.0),
            "Foot.R": (16.0, 0.0, 0.0),
        }),
        (0.60, {
            "Hips_pos": (0.0, -0.008, 0.0),
            "Hips": (4.0, -3.0, 0.0),
            "Torso": (8.0, 0.0, 4.0),
            "Chest": (4.0, 0.0, 4.0),
            "Head": (-6.0, 0.0, -8.0),
            "Shoulder.L": (-4.0, 4.0, 0.0),
            "Shoulder.R": (-6.0, -4.0, 0.0),
            "UpperArm.L": (-124.0, 34.0, -14.0),
            "LowerArm.L": (36.0, 10.0, 0.0),
            "Hand.L": (16.0, 0.0, 0.0),
            "UpperArm.R": (-115.0, -38.0, 12.0),
            "LowerArm.R": (30.0, 10.0, 0.0),
            "Hand.R": (16.0, 0.0, 0.0),
            "UpperLeg.L": (-16.0, 0.0, 4.0),
            "LowerLeg.L": (42.0, 0.0, 0.0),
            "Foot.L": (22.0, 0.0, 0.0),
            "UpperLeg.R": (16.0, 0.0, -4.0),
            "LowerLeg.R": (24.0, 0.0, 0.0),
            "Foot.R": (18.0, 0.0, 0.0),
        }),
        (0.90, {
            "Hips_pos": (0.0, 0.010, 0.0),
            "Hips": (6.0, 2.0, -3.0),
            "Torso": (11.0, 0.0, -2.0),
            "Chest": (6.0, 0.0, -2.0),
            "Head": (-10.0, 0.0, 4.0),
            "Shoulder.L": (-8.0, 4.0, 0.0),
            "Shoulder.R": (-8.0, -4.0, 0.0),
            "UpperArm.L": (-106.0, 40.0, -10.0),
            "LowerArm.L": (24.0, 8.0, 0.0),
            "Hand.L": (14.0, 0.0, 0.0),
            "UpperArm.R": (-130.0, -34.0, 16.0),
            "LowerArm.R": (42.0, 12.0, 0.0),
            "Hand.R": (20.0, 0.0, 0.0),
            "UpperLeg.L": (20.0, 0.0, 6.0),
            "LowerLeg.L": (18.0, 0.0, 0.0),
            "Foot.L": (16.0, 0.0, 0.0),
            "UpperLeg.R": (-24.0, 0.0, -6.0),
            "LowerLeg.R": (54.0, 0.0, 0.0),
            "Foot.R": (26.0, 0.0, 0.0),
        }),
    ]
    abducted_kf.append((1.20, abducted_kf[0][1]))

    anim_defs: Dict[str, List[Tuple[float, Dict[str, Tuple[float, ...]]]]] = {
        "idle": idle_kf,
        "walk": walk_kf,
        "sprint": sprint_kf,
        "jump": jump_kf,
        "fall": fall_kf,
        "crouch": crouch_kf,
        "interact-right": interact_kf,
        "pick-up": pickup_kf,
        "kentongan_hit": kent_kf,
        "drink": drink_kf,
        "die": die_kf,
        "abducted": abducted_kf,
    }

    baked: Dict[str, Tuple[List[float], List[Vec3], List[List[Quat]]]] = {}
    for anim_name, duration in ANIMATION_SPECS:
        kfs = anim_defs[anim_name]
        # Note: verify exact duration matches contract
        assert abs(kfs[-1][0] - duration) < 1e-6, f"{anim_name} duration mismatch"
        baked[anim_name] = _sample_keyframes(kfs, joints, duration, fps=30)
    return baked


# ---------------------------------------------------------------------------
# Binary glTF 2.0 (.glb) Builder
# ---------------------------------------------------------------------------

class GlbBuilder:
    def __init__(self) -> None:
        self.bin_data = bytearray()
        self.buffer_views: List[dict] = []
        self.accessors: List[dict] = []

    def _align4(self) -> None:
        rem = len(self.bin_data) % 4
        if rem:
            self.bin_data.extend(b"\x00" * (4 - rem))

    def add_buffer_view(self, raw_bytes: bytes, target: Optional[int] = None) -> int:
        self._align4()
        offset = len(self.bin_data)
        self.bin_data.extend(raw_bytes)
        length = len(raw_bytes)
        self._align4()
        bv: dict = {
            "buffer": 0,
            "byteOffset": offset,
            "byteLength": length,
        }
        if target is not None:
            bv["target"] = target
        idx = len(self.buffer_views)
        self.buffer_views.append(bv)
        return idx

    def add_accessor(
        self,
        raw_bytes: bytes,
        component_type: int,
        count: int,
        acc_type: str,
        target: Optional[int] = None,
        min_vals: Optional[List[float]] = None,
        max_vals: Optional[List[float]] = None,
    ) -> int:
        bv_idx = self.add_buffer_view(raw_bytes, target=target)
        acc: dict = {
            "bufferView": bv_idx,
            "byteOffset": 0,
            "componentType": component_type,
            "count": count,
            "type": acc_type,
        }
        if min_vals is not None:
            acc["min"] = min_vals
        if max_vals is not None:
            acc["max"] = max_vals
        idx = len(self.accessors)
        self.accessors.append(acc)
        return idx


def _pack_vec3(items: Sequence[Sequence[float]]) -> Tuple[bytes, List[float], List[float]]:
    buf = bytearray()
    mn = [float("inf"), float("inf"), float("inf")]
    mx = [float("-inf"), float("-inf"), float("-inf")]
    for x, y, z in items:
        fx, fy, fz = float(x), float(y), float(z)
        buf.extend(struct.pack("<3f", fx, fy, fz))
        if fx < mn[0]: mn[0] = fx
        if fy < mn[1]: mn[1] = fy
        if fz < mn[2]: mn[2] = fz
        if fx > mx[0]: mx[0] = fx
        if fy > mx[1]: mx[1] = fy
        if fz > mx[2]: mx[2] = fz
    return bytes(buf), mn, mx


def _pack_vec2(items: Sequence[Sequence[float]]) -> bytes:
    buf = bytearray()
    for u, v in items:
        buf.extend(struct.pack("<2f", float(u), float(v)))
    return bytes(buf)


def _pack_vec4_f32(items: Sequence[Sequence[float]]) -> bytes:
    buf = bytearray()
    for a, b, c, d in items:
        buf.extend(struct.pack("<4f", float(a), float(b), float(c), float(d)))
    return bytes(buf)


def _pack_vec4_u16(items: Sequence[Sequence[int]]) -> bytes:
    buf = bytearray()
    for a, b, c, d in items:
        buf.extend(struct.pack("<4H", int(a), int(b), int(c), int(d)))
    return bytes(buf)


def _pack_scalars_f32(items: Sequence[float]) -> Tuple[bytes, List[float], List[float]]:
    buf = bytearray()
    mn = float("inf")
    mx = float("-inf")
    for val in items:
        f = float(val)
        buf.extend(struct.pack("<f", f))
        if f < mn: mn = f
        if f > mx: mx = f
    return bytes(buf), [mn], [mx]


def _pack_indices_u32(indices: Sequence[int]) -> Tuple[bytes, List[int], List[int]]:
    buf = bytearray()
    mn = int(indices[0])
    mx = int(indices[0])
    for idx in indices:
        iv = int(idx)
        buf.extend(struct.pack("<I", iv))
        if iv < mn: mn = iv
        if iv > mx: mx = iv
    return bytes(buf), [mn], [mx]


def build_character_glb(cfg: dict) -> dict:
    """Rig, skin, animate, and serialize one character to .glb."""
    with open(cfg["mesh_json"], "r", encoding="utf-8") as f:
        mesh_data = json.load(f)
    with open(cfg["albedo_png"], "rb") as f:
        png_bytes = f.read()

    char_id = cfg["id"]
    joints_dict: Dict[str, List[float]] = mesh_data["joints"]
    local_t, local_q, _m_global, ibms = compute_bind_pose(joints_dict)

    builder = GlbBuilder()

    # 1. Embed albedo PNG texture
    png_bv_idx = builder.add_buffer_view(png_bytes)

    # 2. Inverse Bind Matrices (19 x MAT4 column-major float32)
    ibm_buf = bytearray()
    for ibm in ibms:
        ibm_buf.extend(struct.pack("<16f", *mat4_to_col_major(ibm)))
    ibm_acc_idx = builder.add_accessor(bytes(ibm_buf), 5126, len(BONES), "MAT4")

    # 3. Build skinned meshes: body-mesh (0), head-mesh (1)
    ARRAY_BUFFER = 34962
    ELEMENT_ARRAY_BUFFER = 34963
    mesh_defs = []
    for mesh_name in ("body-mesh", "head-mesh"):
        m = mesh_data["meshes"][mesh_name]
        positions = m["positions"]
        normals = m["normals"]
        uvs = m["uvs"]
        indices = m["indices"]
        regions = m["regions"]

        assert len(positions) == len(normals) == len(uvs) == len(regions)

        joints0 = []
        weights0 = []
        for pos, reg in zip(positions, regions):
            j4, w4 = compute_vertex_skin(pos, reg, joints_dict)
            joints0.append(j4)
            weights0.append(w4)

        pos_bytes, pos_min, pos_max = _pack_vec3(positions)
        nrm_bytes, _, _ = _pack_vec3(normals)
        uv_bytes = _pack_vec2(uvs)
        jnt_bytes = _pack_vec4_u16(joints0)
        wgt_bytes = _pack_vec4_f32(weights0)
        idx_bytes, idx_min, idx_max = _pack_indices_u32(indices)

        pos_acc = builder.add_accessor(pos_bytes, 5126, len(positions), "VEC3", ARRAY_BUFFER, pos_min, pos_max)
        nrm_acc = builder.add_accessor(nrm_bytes, 5126, len(normals), "VEC3", ARRAY_BUFFER)
        uv_acc = builder.add_accessor(uv_bytes, 5126, len(uvs), "VEC2", ARRAY_BUFFER)
        jnt_acc = builder.add_accessor(jnt_bytes, 5123, len(joints0), "VEC4", ARRAY_BUFFER)
        wgt_acc = builder.add_accessor(wgt_bytes, 5126, len(weights0), "VEC4", ARRAY_BUFFER)
        idx_acc = builder.add_accessor(idx_bytes, 5125, len(indices), "SCALAR", ELEMENT_ARRAY_BUFFER, idx_min, idx_max)

        mesh_defs.append({
            "name": mesh_name,
            "primitives": [
                {
                    "attributes": {
                        "POSITION": pos_acc,
                        "NORMAL": nrm_acc,
                        "TEXCOORD_0": uv_acc,
                        "JOINTS_0": jnt_acc,
                        "WEIGHTS_0": wgt_acc,
                    },
                    "indices": idx_acc,
                    "material": 0,
                    "mode": 4,
                }
            ],
        })

    # 4. Nodes: 0..18 joints, 19 body-mesh, 20 head-mesh, 21 CharacterRoot
    children_map: Dict[int, List[int]] = {i: [] for i in range(len(BONES))}
    for idx, (_name, p_idx) in enumerate(BONES):
        if p_idx is not None:
            children_map[p_idx].append(idx)

    nodes: List[dict] = []
    for idx, (bname, _p_idx) in enumerate(BONES):
        node: dict = {
            "name": bname,
            "translation": [round(local_t[idx][0], 7), round(local_t[idx][1], 7), round(local_t[idx][2], 7)],
            "rotation": [round(local_q[idx][0], 7), round(local_q[idx][1], 7), round(local_q[idx][2], 7), round(local_q[idx][3], 7)],
        }
        if children_map[idx]:
            node["children"] = children_map[idx]
        nodes.append(node)

    body_node_idx = len(nodes)
    nodes.append({"name": "body-mesh", "mesh": 0, "skin": 0})
    head_node_idx = len(nodes)
    nodes.append({"name": "head-mesh", "mesh": 1, "skin": 0})
    root_node_idx = len(nodes)
    nodes.append({"name": "CharacterRoot", "children": [0, body_node_idx, head_node_idx]})

    # 5. Bake all 12 animations
    baked_anims = _build_all_animation_keyframes(joints_dict, is_female=cfg["is_female"])
    animations_json: List[dict] = []

    for anim_name, _dur in ANIMATION_SPECS:
        times, hip_positions, frame_quats = baked_anims[anim_name]
        # Full time accessor for active tracks; 2-key accessor for static tracks
        t_full_bytes, t_min, t_max = _pack_scalars_f32(times)
        t_full_acc = builder.add_accessor(t_full_bytes, 5126, len(times), "SCALAR", None, t_min, t_max)

        t_const_bytes, tc_min, tc_max = _pack_scalars_f32([0.0, times[-1]])
        t_const_acc = builder.add_accessor(t_const_bytes, 5126, 2, "SCALAR", None, tc_min, tc_max)

        samplers: List[dict] = []
        channels: List[dict] = []

        # Hips translation track
        hip_static = all(
            max(abs(h[k] - hip_positions[0][k]) for k in range(3)) < 1e-6
            for h in hip_positions
        )
        if hip_static:
            hp_bytes, _, _ = _pack_vec3([hip_positions[0], hip_positions[-1]])
            hp_acc = builder.add_accessor(hp_bytes, 5126, 2, "VEC3")
            ht_acc = t_const_acc
        else:
            hp_bytes, _, _ = _pack_vec3(hip_positions)
            hp_acc = builder.add_accessor(hp_bytes, 5126, len(hip_positions), "VEC3")
            ht_acc = t_full_acc
        s_idx = len(samplers)
        samplers.append({"input": ht_acc, "interpolation": "LINEAR", "output": hp_acc})
        channels.append({"sampler": s_idx, "target": {"node": 0, "path": "translation"}})

        # Rotation tracks for all 19 joints
        for j_idx in range(len(BONES)):
            q_track = [frame_quats[k][j_idx] for k in range(len(times))]
            q0 = q_track[0]
            q_static = all(
                max(abs(q[k] - q0[k]) for k in range(4)) < 1e-6
                for q in q_track
            )
            if q_static:
                q_bytes = _pack_vec4_f32([q0, q_track[-1]])
                q_acc = builder.add_accessor(q_bytes, 5126, 2, "VEC4")
                qt_acc = t_const_acc
            else:
                q_bytes = _pack_vec4_f32(q_track)
                q_acc = builder.add_accessor(q_bytes, 5126, len(q_track), "VEC4")
                qt_acc = t_full_acc
            s_idx = len(samplers)
            samplers.append({"input": qt_acc, "interpolation": "LINEAR", "output": q_acc})
            channels.append({"sampler": s_idx, "target": {"node": j_idx, "path": "rotation"}})

        animations_json.append({
            "name": anim_name,
            "samplers": samplers,
            "channels": channels,
        })

    # 6. Assemble complete glTF 2.0 JSON
    builder._align4()
    bin_bytes = bytes(builder.bin_data)

    gltf = {
        "asset": {"version": "2.0", "generator": "LAMPOR Character Rigger & Animator"},
        "scene": 0,
        "scenes": [{"name": "Scene", "nodes": [root_node_idx]}],
        "nodes": nodes,
        "skins": [
            {
                "name": "CharacterSkeleton",
                "joints": list(range(len(BONES))),
                "skeleton": 0,
                "inverseBindMatrices": ibm_acc_idx,
            }
        ],
        "meshes": mesh_defs,
        "materials": [
            {
                "name": f"{char_id}_mat",
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "roughnessFactor": 0.78,
                    "metallicFactor": 0.04,
                },
                "doubleSided": False,
            }
        ],
        "textures": [{"sampler": 0, "source": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9729, "wrapS": 10497, "wrapT": 10497}],
        "images": [{"bufferView": png_bv_idx, "mimeType": "image/png", "name": f"{char_id}_albedo"}],
        "animations": animations_json,
        "buffers": [{"byteLength": len(bin_bytes)}],
        "bufferViews": builder.buffer_views,
        "accessors": builder.accessors,
    }

    json_bytes = json.dumps(gltf, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    json_pad = (4 - (len(json_bytes) % 4)) % 4
    json_chunk = json_bytes + (b" " * json_pad)

    total_length = 12 + 8 + len(json_chunk) + 8 + len(bin_bytes)
    os.makedirs(os.path.dirname(cfg["out_glb"]), exist_ok=True)
    with open(cfg["out_glb"], "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total_length))
        f.write(struct.pack("<II", len(json_chunk), 0x4E4F534A))
        f.write(json_chunk)
        f.write(struct.pack("<II", len(bin_bytes), 0x004E4942))
        f.write(bin_bytes)

    return {
        "id": char_id,
        "out_glb": cfg["out_glb"],
        "file_bytes": total_length,
        "joints": len(BONES),
        "meshes": len(mesh_defs),
        "animations": [(a["name"], ANIMATION_SPECS[i][1]) for i, a in enumerate(animations_json)],
    }


# ---------------------------------------------------------------------------
# Comprehensive GLB Validator & Forward Kinematics Deformation Inspector
# ---------------------------------------------------------------------------

def _read_accessor(gltf: dict, bin_buf: bytes, acc_idx: int) -> list:
    acc = gltf["accessors"][acc_idx]
    bv = gltf["bufferViews"][acc["bufferView"]]
    offset = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"]
    ctype = acc["componentType"]
    atype = acc["type"]

    fmt_map = {5123: "H", 5125: "I", 5126: "f"}
    comp_map = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    n_comp = comp_map[atype]
    fmt = "<" + (fmt_map[ctype] * n_comp)
    stride = struct.calcsize(fmt)
    out = []
    for i in range(count):
        vals = struct.unpack_from(fmt, bin_buf, offset + i * stride)
        out.append(vals[0] if n_comp == 1 else vals)
    return out


def _eval_fk_joints(gltf: dict, bin_buf: bytes, anim_name: str, time_s: float) -> Dict[str, Vec3]:
    """Evaluate exact 3D world joint positions at `time_s` by sampling GLB animation tracks."""
    anim = next(a for a in gltf["animations"] if a["name"] == anim_name)
    node_t = [list(n.get("translation", [0.0, 0.0, 0.0])) for n in gltf["nodes"][:19]]
    node_q = [tuple(n.get("rotation", [0.0, 0.0, 0.0, 1.0])) for n in gltf["nodes"][:19]]

    for ch in anim["channels"]:
        target = ch["target"]
        n_idx = target["node"]
        path = target["path"]
        samp = anim["samplers"][ch["sampler"]]
        times = _read_accessor(gltf, bin_buf, samp["input"])
        vals = _read_accessor(gltf, bin_buf, samp["output"])

        # Find bounding keyframes
        if time_s <= times[0]:
            v = vals[0]
        elif time_s >= times[-1]:
            v = vals[-1]
        else:
            k = 0
            for i in range(len(times) - 1):
                if times[i] <= time_s <= times[i + 1]:
                    k = i
                    break
            u = (time_s - times[k]) / max(1e-9, times[k + 1] - times[k])
            if path == "translation":
                v = tuple(vals[k][c] + u * (vals[k + 1][c] - vals[k][c]) for c in range(3))
            else:
                v = q_slerp(vals[k], vals[k + 1], u)

        if path == "translation":
            node_t[n_idx] = list(v)
        elif path == "rotation":
            node_q[n_idx] = tuple(v)

    world_pos: List[Vec3] = [(0.0, 0.0, 0.0)] * 19
    world_q: List[Quat] = [(0.0, 0.0, 0.0, 1.0)] * 19
    for idx, (_name, p_idx) in enumerate(BONES):
        t = (node_t[idx][0], node_t[idx][1], node_t[idx][2])
        q = node_q[idx]
        if p_idx is None:
            world_pos[idx] = t
            world_q[idx] = q
        else:
            rot_t = q_rotate_vec(world_q[p_idx], t)
            world_pos[idx] = v_add(world_pos[p_idx], rot_t)
            world_q[idx] = q_norm(q_mul(world_q[p_idx], q))

    return {BONES[i][0]: world_pos[i] for i in range(19)}


def validate_glb(glb_path: str, mesh_json_path: str) -> dict:
    """Strictly validate binary GLB spec compliance, skinning, animations, and FK poses."""
    with open(glb_path, "rb") as f:
        data = f.read()
    with open(mesh_json_path, "r", encoding="utf-8") as f:
        src_mesh = json.load(f)

    assert len(data) >= 20 and len(data) % 4 == 0, "GLB size must be 4-byte aligned"
    magic, version, total_len = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, f"Bad GLB magic: {hex(magic)}"
    assert version == 2, f"Bad GLB version: {version}"
    assert total_len == len(data), f"Length mismatch: {total_len} != {len(data)}"

    j_len, j_type = struct.unpack_from("<II", data, 12)
    assert j_type == 0x4E4F534A and j_len % 4 == 0
    json_raw = data[20 : 20 + j_len]
    gltf = json.loads(json_raw.decode("utf-8"))

    b_off = 20 + j_len
    b_len, b_type = struct.unpack_from("<II", data, b_off)
    assert b_type == 0x004E4942 and b_len % 4 == 0
    bin_buf = data[b_off + 8 : b_off + 8 + b_len]
    assert b_off + 8 + b_len == len(data)

    # BufferViews 4-byte aligned
    for i, bv in enumerate(gltf["bufferViews"]):
        assert bv["byteOffset"] % 4 == 0, f"bufferView {i} offset unaligned"

    # Hierarchy & skin checks
    assert len(gltf["skins"]) == 1
    skin = gltf["skins"][0]
    assert len(skin["joints"]) == 19
    for idx, (bname, _p) in enumerate(BONES):
        assert gltf["nodes"][skin["joints"][idx]]["name"] == bname

    root = gltf["nodes"][gltf["scenes"][0]["nodes"][0]]
    assert root["name"] == "CharacterRoot"
    child_names = [gltf["nodes"][c]["name"] for c in root["children"]]
    assert child_names == ["Hips", "body-mesh", "head-mesh"], f"Unexpected root children: {child_names}"

    # Verify embedded PNG header
    img_bv = gltf["bufferViews"][gltf["images"][0]["bufferView"]]
    img_bytes = bin_buf[img_bv["byteOffset"] : img_bv["byteOffset"] + img_bv["byteLength"]]
    assert img_bytes[:8] == b"\x89PNG\r\n\x1a\n", "Embedded image is not valid PNG"

    # Verify IBM inverses and zero NaNs/Infs
    ibms = _read_accessor(gltf, bin_buf, skin["inverseBindMatrices"])
    assert len(ibms) == 19
    assert all(math.isfinite(x) for row in ibms for x in row), "Non-finite value in inverseBindMatrices"
    _, _, m_globals, _ = compute_bind_pose(src_mesh["joints"])
    for j_idx, ibm_col in enumerate(ibms):
        ibm_row = [[ibm_col[c * 4 + r] for c in range(4)] for r in range(4)]
        prod = mat4_mul(m_globals[j_idx], ibm_row)
        for r in range(4):
            for c in range(4):
                err = abs(prod[r][c] - (1.0 if r == c else 0.0))
                assert err < 1e-4, f"IBM inversion failed at joint {j_idx} ({r},{c}): err={err}"

    # Verify meshes, accessors min/max, finite floats, skin weight sums & zero-bleed
    for m_idx, m_name in enumerate(("body-mesh", "head-mesh")):
        mesh_g = gltf["meshes"][m_idx]
        assert mesh_g["name"] == m_name
        attrs = mesh_g["primitives"][0]["attributes"]
        pos_acc = gltf["accessors"][attrs["POSITION"]]
        assert "min" in pos_acc and "max" in pos_acc

        for attr_name in ("POSITION", "NORMAL", "TEXCOORD_0", "WEIGHTS_0"):
            vals = _read_accessor(gltf, bin_buf, attrs[attr_name])
            assert all(math.isfinite(c) for v in vals for c in v), f"Non-finite value in {m_name} {attr_name}"

        jnts = _read_accessor(gltf, bin_buf, attrs["JOINTS_0"])
        wgts = _read_accessor(gltf, bin_buf, attrs["WEIGHTS_0"])
        src_regs = src_mesh["meshes"][m_name]["regions"]
        assert len(jnts) == len(wgts) == len(src_regs)

        for v_i, (j4, w4, reg) in enumerate(zip(jnts, wgts, src_regs)):
            allowed_idxs = {BONE_INDEX[b] for b in REGION_ALLOWED_BONES[reg]}
            w_sum = sum(w4)
            assert abs(w_sum - 1.0) < 1e-4, f"{m_name} v{v_i} weights sum {w_sum}"
            for ji, wi in zip(j4, w4):
                if wi > 1e-6:
                    assert ji in allowed_idxs, f"{m_name} v{v_i} region {reg} bled into bone {BONES[ji][0]}"
                else:
                    assert ji == 0 and wi == 0.0

    # Verify all 12 animations, TIME bounds, unit quaternions, and dot(q_prev, q_curr) >= 0
    anim_names = [a["name"] for a in gltf["animations"]]
    expected_names = [name for name, _ in ANIMATION_SPECS]
    assert anim_names == expected_names, f"Animation mismatch: {anim_names}"

    durations = {}
    for anim, (ename, edur) in zip(gltf["animations"], ANIMATION_SPECS):
        max_t = 0.0
        for samp in anim["samplers"]:
            t_acc = gltf["accessors"][samp["input"]]
            assert "min" in t_acc and "max" in t_acc
            times = _read_accessor(gltf, bin_buf, samp["input"])
            assert all(math.isfinite(tv) for tv in times), f"{ename} non-finite TIME"
            max_t = max(max_t, times[-1])
            out_acc = gltf["accessors"][samp["output"]]
            out_vals = _read_accessor(gltf, bin_buf, samp["output"])
            assert all(math.isfinite(c) for v in out_vals for c in v), f"{ename} non-finite sampler output"
            if out_acc["type"] == "VEC4":
                qs = out_vals
                for k, q in enumerate(qs):
                    nrm = math.sqrt(sum(c * c for c in q))
                    assert abs(nrm - 1.0) < 1e-4, f"{ename} unnormalized quat norm={nrm}"
                    if k > 0:
                        d = q_dot(qs[k - 1], q)
                        assert d >= -1e-6, f"{ename} quaternion sign flip dot={d}"
        assert abs(max_t - edur) < 1e-4, f"{ename} duration {max_t} != {edur}"
        durations[ename] = round(max_t, 3)

    # FK sanity checks on deformed joint positions
    fk_idle = _eval_fk_joints(gltf, bin_buf, "idle", 0.0)
    fk_walk_0 = _eval_fk_joints(gltf, bin_buf, "walk", 0.0)
    fk_walk_half = _eval_fk_joints(gltf, bin_buf, "walk", 0.44)
    fk_crouch = _eval_fk_joints(gltf, bin_buf, "crouch", 0.0)
    fk_die = _eval_fk_joints(gltf, bin_buf, "die", 0.70)

    # Arms must hang down beside hips in idle (Hand.y < Shoulder.y - 0.35)
    assert fk_idle["Hand.L"][1] < fk_idle["Shoulder.L"][1] - 0.35
    assert fk_idle["Hand.R"][1] < fk_idle["Shoulder.R"][1] - 0.35
    # Forearm bent forward in idle: Hand.z > LowerArm.z
    assert fk_idle["Hand.L"][2] > fk_idle["LowerArm.L"][2] + 0.03
    # Walk: left foot forward at t=0, right foot forward at t=0.44
    assert fk_walk_0["Foot.L"][2] > fk_walk_0["Foot.R"][2] + 0.15
    assert fk_walk_half["Foot.R"][2] > fk_walk_half["Foot.L"][2] + 0.15
    # Crouch: Hips dropped ~0.33m, knees bent forward (+Z), feet stay near bind ground height!
    assert abs((fk_crouch["Hips"][1] - src_mesh["joints"]["Hips"][1]) - (-0.33)) < 0.01
    assert fk_crouch["LowerLeg.L"][2] > fk_crouch["Hips"][2] + 0.15
    assert abs(fk_crouch["Foot.L"][1] - src_mesh["joints"]["Foot.L"][1]) < 0.05
    # Die: body fallen backward (-Z) and resting near ground (y <= 0.25)
    assert fk_die["Hips"][1] <= 0.15
    assert fk_die["Head"][1] <= 0.28 and fk_die["Head"][2] < fk_die["Hips"][2] - 0.35

    return {
        "file_bytes": len(data),
        "durations": durations,
        "fk_idle_hand_l": [round(v, 3) for v in fk_idle["Hand.L"]],
        "fk_crouch_hips": [round(v, 3) for v in fk_crouch["Hips"]],
        "fk_crouch_foot_l": [round(v, 3) for v in fk_crouch["Foot.L"]],
        "fk_die_hips": [round(v, 3) for v in fk_die["Hips"]],
        "fk_die_head": [round(v, 3) for v in fk_die["Head"]],
    }


def main() -> None:
    for cfg in CHARACTERS:
        res = build_character_glb(cfg)
        val = validate_glb(cfg["out_glb"], cfg["mesh_json"])
        print(
            f"[{res['id']}] OK -> {res['out_glb']} | "
            f"bytes={res['file_bytes']} | joints={res['joints']} | meshes={res['meshes']} | "
            f"anims={len(res['animations'])}"
        )
        print(f"  durations: {val['durations']}")
        print(
            f"  FK idle Hand.L={val['fk_idle_hand_l']}, "
            f"crouch Hips={val['fk_crouch_hips']} Foot.L={val['fk_crouch_foot_l']}, "
            f"die Hips={val['fk_die_hips']} Head={val['fk_die_head']}"
        )


if __name__ == "__main__":
    main()
