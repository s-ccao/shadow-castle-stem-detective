"""Gait styling for the HD characters: what makes a Tripo clip read on a
50 px chibi figure.

Tripo's preset clips are motion capture retargeted onto the chibi bodies.
The legs stay theirs; they plant the feet and carry the weight well. The
upper body does not survive the short arms and the long coat: the hands hang
at the hips, inside the coat's outline, and the run is a hunched sprint. So
every frame keeps the clip's legs and hips and rebuilds the rest:

  * arms held out from the body so the hands clear the coat, swinging
    against the legs (a beat behind them), elbows bending as they come
    forward; a run pumps them with fists;
  * the chest twists with the arms and the head turns back against it, looks
    where the figure goes and nods with the steps;
  * the hands are drawn 1.3-1.4 times larger, the way chibi art draws them;
  * the run's stride is lengthened, with the body lowered so the stance foot
    still meets the floor, so legs at game speed don't blur;
  * standing breathes, sways and looks around.

The pose maths works on the armature's rest frames and local quaternions, so
a whole frame is styled without a depsgraph update. The figure faces -Y,
with +Z up and +X its left.
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

FORWARD = Vector((0.0, -1.0, 0.0))
UP = Vector((0.0, 0.0, 1.0))
LEFT = Vector((1.0, 0.0, 0.0))
SIDES = (("Left", 1.0), ("Right", -1.0))
FINGERS = ("Index", "Middle", "Ring", "Pinky")
LEGS = ("UpLeg", "Leg", "Foot")
FOOT_BONES = ("Foot", "ToeBase", "Toe_End")

# Per character and gait. Angles in degrees. "clip" is the Tripo preset the
# legs come from; a walk or run is one cycle of `frames`, the idle a loop of
# `seconds`; "air" is how much of a run's time off the floor it keeps. Arms:
# "out" holds them from the body, "swing" is the forward
# reach (back reach is 0.8 of it), "elbow" the bend, "reach" the extra bend
# coming forward, "cross" how far the forearms swing in across the body.
STYLES = {
    "detective": {
        "hand": 1.4,
        "idle": {"clip": "idle", "frames": 36, "seconds": 6.0, "out": 17.0, "swing": 4.0, "elbow": 16.0,
                 "curl": 18.0, "look": 26.0, "breath": 1.4, "sway": 1.6},
        "walk": {"clip": "walk", "frames": 8, "stride": 1.25, "knee": 1.1, "out": 15.0, "swing": 32.0,
                 "elbow": 22.0, "reach": 20.0, "cross": 4.0, "curl": 28.0, "twist": 7.0, "lean": 3.0,
                 "nod": 2.5, "gaze": -4.0},
        "run": {"clip": "run", "frames": 8, "stride": 1.45, "knee": 1.25, "air": 0.5, "out": 26.0, "swing": 52.0,
                "elbow": 84.0, "reach": 14.0, "cross": 0.0, "curl": 75.0, "twist": 11.0, "lean": 14.0,
                "nod": 2.0, "gaze": 2.0},
    },
    "guardian": {
        "hand": 1.3,
        "idle": {"clip": "idle", "frames": 36, "seconds": 6.0, "out": 13.0, "swing": 3.0, "elbow": 12.0,
                 "curl": 45.0, "look": 34.0, "breath": 1.1, "sway": 1.0},
        "walk": {"clip": "walk", "frames": 8, "stride": 1.3, "knee": 1.1, "out": 12.0, "swing": 24.0,
                 "elbow": 16.0, "reach": 14.0, "cross": 3.0, "curl": 55.0, "twist": 5.0, "lean": 4.0,
                 "nod": 1.5, "gaze": -2.0},
        "run": {"clip": "run", "frames": 8, "stride": 1.15, "knee": 1.05, "air": 0.5, "out": 22.0, "swing": 42.0,
                "elbow": 80.0, "reach": 12.0, "cross": 0.0, "curl": 80.0, "twist": 8.0, "lean": 13.0,
                "nod": 1.5, "gaze": 0.0},
    },
}


def bone(name):
    return "mixamorig:" + name


def mean_quaternion(quaternions):
    reference = quaternions[0]
    total = Quaternion((0.0, 0.0, 0.0, 0.0))
    for value in quaternions:
        total += value if value.dot(reference) >= 0.0 else -value
    total.normalize()
    return total


def ease(value):
    value = min(max(value, 0.0), 1.0)
    return value * value * (3.0 - 2.0 * value)


class Rig:
    """The armature's rest frames, and the finger curl directions."""

    def __init__(self, armature):
        self.armature = armature
        self.bones = armature.data.bones
        self.rest = {item.name: item.matrix_local.to_3x3().normalized() for item in self.bones}
        self.parent = {item.name: item.parent.name if item.parent else None for item in self.bones}
        # Which way about its own x axis bends each finger joint toward the
        # palm, which faces down in the rest T-pose.
        self.curl_sign = {}
        for side, _sign in SIDES:
            for finger in FINGERS + ("Thumb",):
                for joint in (1, 2, 3):
                    name = bone("%sHand%s%d" % (side, finger, joint))
                    if name not in self.rest:
                        continue
                    rest = self.rest[name]
                    tip = rest @ Vector((0.0, 1.0, 0.0))
                    bent = rest @ (Quaternion((1.0, 0.0, 0.0), math.radians(30.0)) @ Vector((0.0, 1.0, 0.0)))
                    self.curl_sign[name] = 1.0 if (bent - tip).z < 0.0 else -1.0

    def reset(self):
        """Every channel at rest, so a clip sets exactly what it keys."""
        for item in self.armature.pose.bones:
            item.rotation_mode = "QUATERNION"
            item.location = (0.0, 0.0, 0.0)
            item.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
            item.scale = (1.0, 1.0, 1.0)

    def capture(self):
        return {item.name: [item.location.copy(), item.rotation_quaternion.copy(), item.scale.copy()]
                for item in self.armature.pose.bones}

    def apply(self, channels):
        for item in self.armature.pose.bones:
            location, rotation, scale = channels[item.name]
            item.rotation_mode = "QUATERNION"
            item.location = location
            item.rotation_quaternion = rotation
            item.scale = scale


class Pose:
    """A full set of pose channels, with each bone's orientation in armature
    space worked out from the rest frames."""

    def __init__(self, rig, channels):
        self.rig = rig
        self.channels = {name: [loc.copy(), rot.copy(), scale.copy()] for name, (loc, rot, scale) in channels.items()}
        self.cache = {}

    def rotation(self, name):
        if name not in self.cache:
            self.cache[name] = self.base(name) @ self.channels[name][1].to_matrix()
        return self.cache[name]

    def base(self, name):
        """The bone's orientation if its own channel were at rest."""
        parent = self.rig.parent[name]
        if parent is None:
            return self.rig.rest[name]
        return self.rotation(parent) @ self.rig.rest[parent].transposed() @ self.rig.rest[name]

    def set_rotation(self, name, value):
        self.channels[name][1] = value.normalized()
        self.cache.clear()

    def aim(self, name, direction):
        """Points the bone along `direction` with the least turn from rest."""
        local = self.base(name).transposed() @ direction.normalized()
        self.set_rotation(name, Vector((0.0, 1.0, 0.0)).rotation_difference(local))

    def turn(self, name, matrix):
        """Turns the bone (and all it carries) by `matrix`, in armature space."""
        base = self.base(name)
        self.set_rotation(name, (base.transposed() @ matrix @ base @ self.channels[name][1].to_matrix()).to_quaternion())

    def frame(self, name):
        """Where the body's forward, up and left point, carried by this bone."""
        change = self.rotation(name) @ self.rig.rest[name].transposed()
        return change @ FORWARD, change @ UP, change @ LEFT


def rotation(axis, degrees):
    return Matrix.Rotation(math.radians(degrees), 3, axis.normalized())


def exaggerate(pose, means, stride, knee):
    """Lengthens the stride: each leg joint swings `stride` (the knee `knee`)
    times as far from its average over the cycle, the knee never past
    straight."""
    for side, _sign in SIDES:
        for part, factor in (("UpLeg", stride), ("Leg", knee), ("Foot", 1.0 + (stride - 1.0) * 0.5)):
            name = bone(side + part)
            if factor == 1.0:
                continue
            mean = means[name]
            change = mean.inverted() @ pose.channels[name][1]
            axis, angle = change.to_axis_angle()
            if angle > math.pi:
                angle -= 2.0 * math.pi
            value = mean @ Quaternion(axis, angle * factor)
            if part == "Leg":
                mean_axis, mean_angle = mean.to_axis_angle()
                bend = 2.0 * math.atan2(Vector(value[1:]).dot(mean_axis), value[0])
                if bend * math.copysign(1.0, mean_angle) < math.radians(4.0):
                    value = Quaternion(mean_axis, math.copysign(math.radians(4.0), mean_angle))
            pose.set_rotation(name, value)


def arms(pose, style, swing_left, hand):
    """Both arms from the chest: held out, swung by `swing_left` (the left
    arm's forward swing, -1..1; the right swings against it)."""
    forward, up, left = pose.frame(bone("Spine2"))
    for side, sign in SIDES:
        swing = swing_left * sign
        reach = style["swing"] * (swing if swing > 0.0 else 0.8 * swing)
        out = math.radians(style["out"])
        phi = math.radians(reach)
        outward = left * sign
        upper = (-up * math.cos(out) * math.cos(phi) + outward * math.sin(out)
                 + forward * math.cos(out) * math.sin(phi))
        pose.aim(bone(side + "Arm"), upper)
        bend = math.radians(style["elbow"] + style.get("reach", 0.0) * max(swing, 0.0))
        ahead = (forward - upper.normalized() * forward.dot(upper.normalized())).normalized()
        fore = upper.normalized() * math.cos(bend) + ahead * math.sin(bend)
        fore = (fore - outward * math.sin(math.radians(style.get("cross", 0.0)))).normalized()
        pose.aim(bone(side + "ForeArm"), fore)
        pose.aim(bone(side + "Hand"), fore)
        pose.channels[bone(side + "Hand")][2] = Vector((hand, hand, hand))
        curl = style["curl"]
        for finger in FINGERS + ("Thumb",):
            for joint, share in ((1, 1.0), (2, 1.1), (3, 0.8)):
                name = bone("%sHand%s%d" % (side, finger, joint))
                if name not in pose.channels:
                    continue
                angle = curl * share * (0.55 if finger == "Thumb" else 1.0)
                pose.set_rotation(name, Quaternion((1.0, 0.0, 0.0), math.radians(angle * pose.rig.curl_sign[name])))


def level_head(pose, gaze):
    """Pitches the head so the face looks `gaze` degrees above level."""
    forward, _up, _left = pose.frame(bone("Head"))
    pitch = math.degrees(math.asin(max(-1.0, min(1.0, forward.z))))
    axis = forward.cross(UP)
    if axis.length > 1e-6:
        pose.turn(bone("Head"), rotation(axis, gaze - pitch))


def torso_lean(pose):
    """Degrees the trunk leans forward: hips to neck, against vertical."""
    arm = pose.rig.armature
    neck = arm.pose.bones[bone("Neck")].head
    hips = arm.pose.bones[bone("Hips")].head
    trunk = neck - hips
    return math.degrees(math.atan2(-trunk.y, trunk.z))


def style_cycle(pose, style, phase, swing_left, unlean):
    """A walk or run frame. `phase` 0..1 runs from the right foot's contact;
    `swing_left` is the left arm's swing, -1..1."""
    pose.turn(bone("Spine"), rotation(LEFT, -unlean))
    twist = style["twist"] * swing_left
    pose.turn(bone("Spine2"), rotation(UP, -twist))
    pose.turn(bone("Neck"), rotation(UP, twist * 0.5))
    pose.turn(bone("Head"), rotation(UP, twist * 0.4))
    nod = style["nod"] * math.cos(4.0 * math.pi * phase)
    level_head(pose, style["gaze"] - nod)


def style_idle(pose, style, time):
    """The standing loop at `time` 0..1: breathing twice, swaying once, and a
    look to the figure's left, then right, between rests."""
    breath = 0.5 - 0.5 * math.cos(4.0 * math.pi * time)
    pose.turn(bone("Spine1"), rotation(LEFT, -style["breath"] * breath))
    pose.turn(bone("Spine2"), rotation(LEFT, -style["breath"] * breath))
    for side, sign in SIDES:
        name = bone(side + "Shoulder")
        if name in pose.channels:
            pose.turn(name, rotation(FORWARD, 2.2 * breath * sign))
    pose.turn(bone("Spine"), rotation(FORWARD, style["sway"] * math.sin(2.0 * math.pi * time)))
    look = style["look"] * (ease((time - 0.12) / 0.12) - ease((time - 0.40) / 0.14)
                            - ease((time - 0.54) / 0.12) + ease((time - 0.78) / 0.12))
    tilt = 0.18 * look
    pose.turn(bone("Spine2"), rotation(UP, look * 0.2))
    pose.turn(bone("Neck"), rotation(UP, look * 0.35))
    pose.turn(bone("Head"), rotation(UP, look * 0.45))
    head_forward, _up, _left = pose.frame(bone("Head"))
    pose.turn(bone("Head"), rotation(head_forward, -tilt))
    level_head(pose, -6.0 + 1.5 * breath)
    return breath


def leg_means(rig, character, times):
    samples = {bone(side + part): [] for side, _s in SIDES for part in LEGS}
    for time in times:
        character.set_time(time)
        for name in samples:
            samples[name].append(rig.armature.pose.bones[name].rotation_quaternion.copy())
    return {name: mean_quaternion(values) for name, values in samples.items()}


def foot_mid(rig, side):
    """The middle of the foot, between ankle and ball, in armature space."""
    pose = rig.armature.pose.bones
    return (pose[bone(side + "Foot")].head + pose[bone(side + "ToeBase")].head) / 2.0


def settle(rig, character, times, styled, keep):
    """Sets each of `times` on the floor and measures the gait.

    `styled(time)` sets the clip at `time` and returns the styled channels;
    `character.soles()` gives each shoe's lowest point as posed. The retargeted
    clips float and sink their planted feet by a few centimetres, so the lower
    shoe is put on the floor every time, keeping only `keep` of how far it was
    above its lowest (a run keeps some of its time in the air).

    Returns, per time, how far to raise the body; the ground one cycle covers
    (a planted foot's steady backward slide, over the whole cycle); the
    middle of the feet over the cycle; and the share of time no shoe is
    within 1 cm of the floor."""
    lows, mids = [], []
    for time in times:
        channels = styled(time)
        armature_action = character.armature.animation_data.action
        character.armature.animation_data.action = None
        rig.apply(channels)
        bpy.context.view_layer.update()
        lows.append([low for low, _point in character.soles()])
        mids.append([foot_mid(rig, side) for side, _s in SIDES])
        character.armature.animation_data.action = armature_action
    lows = np.array(lows)
    mids = np.array([[tuple(point) for point in pair] for pair in mids])
    lowest = lows.min(axis=1)
    floor = float(lowest.min())
    lifts = keep * (lowest - floor) - lowest
    # Ground speed: each foot's steadiest backward slide, the stretch of the
    # cycle where it is planted and the body passes over it.
    count = len(times)
    window = max(3, count // 4)
    slides = []
    for side in range(2):
        back = np.array([mids[(index + 1) % count, side, 1] - mids[index, side, 1] for index in range(count)])
        best = None
        for begin in range(count):
            steps = back[[(begin + k) % count for k in range(window)]]
            if (steps > 0.0).all():
                spread = float(steps.std() / steps.mean())
                if best is None or spread < best[0]:
                    best = (spread, float(steps.mean()))
        if best is not None:
            slides.append(best[1])
    travel = float(np.mean(slides)) * count if slides else 0.0
    return lifts, travel, mids.reshape(-1, 3).mean(axis=0), float(np.mean(lowest - floor > 0.01))
