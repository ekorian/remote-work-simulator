"""Helpers for writing Godot .tres resources from Python tables."""
import json, os, re, shutil

true, false = True, False
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


class Color:
    def __init__(self, hexs):
        h = hexs.lstrip("#")
        self.rgb = tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def variant(v, indent=0):
    """Python value -> Godot text-resource Variant."""
    pad = "  " * (indent + 1)
    if isinstance(v, Color):
        return "Color(%.4g, %.4g, %.4g, 1)" % v.rgb
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        s = repr(v)
        return s if ("." in s or "e" in s) else s + ".0"
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (list, tuple)):
        if not v:
            return "[]"
        flat = "[" + ", ".join(variant(x, indent) for x in v) + "]"
        if len(flat) <= 100 and "\n" not in flat:
            return flat
        return "[\n" + ",\n".join(pad + variant(x, indent + 1) for x in v) + "\n" + "  " * indent + "]"
    if isinstance(v, dict):
        if not v:
            return "{}"
        flat = "{" + ", ".join("%s: %s" % (json.dumps(str(k)), variant(x, indent)) for k, x in v.items()) + "}"
        if len(flat) <= 100 and "\n" not in flat:
            return flat
        return "{\n" + ",\n".join("%s%s: %s" % (pad, json.dumps(str(k)), variant(x, indent + 1)) for k, x in v.items()) + "\n" + "  " * indent + "}"
    raise TypeError(type(v))


def write(folder, script, cls, rid, fields):
    path = os.path.join(ROOT, "resources", folder)
    os.makedirs(path, exist_ok=True)
    lines = [
        '[gd_resource type="Resource" script_class="%s" load_steps=2 format=3]' % cls, "",
        '[ext_resource type="Script" path="res://scripts/data/%s.gd" id="1"]' % script, "",
        "[resource]", 'script = ExtResource("1")', "id = %s" % variant(rid),
    ]
    for k, v in fields.items():
        if v is None:
            continue
        lines.append("%s = %s" % (k, variant(v)))
    with open(os.path.join(path, rid + ".tres"), "w") as f:
        f.write("\n".join(lines) + "\n")


def clean(folder):
    path = os.path.join(ROOT, "resources", folder)
    if os.path.isdir(path):
        for f in os.listdir(path):
            if f.endswith(".tres"):
                os.remove(os.path.join(path, f))


def extract(src, name):
    """Pull `const NAME := <literal>` out of a GDScript file and eval it."""
    m = re.search(r"^const %s := " % re.escape(name), src, re.M)
    if not m:
        raise KeyError(name)
    i = m.end()
    opener = src[i]
    closer = {"{": "}", "[": "]"}[opener]
    depth, j, in_str = 0, i, False
    while j < len(src):
        ch = src[j]
        if in_str:
            if ch == "\\":
                j += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "#":
            while src[j] != "\n":
                j += 1
        elif ch in "{[":
            depth += 1
        elif ch in "}]":
            depth -= 1
            if depth == 0:
                break
        j += 1
    return eval(src[i:j + 1], {"true": True, "false": False, "Color": Color})


def rename(v, pairs):
    """Recursively replace substrings in every string (keys and values)."""
    if isinstance(v, str):
        for a, b in pairs:
            v = v.replace(a, b)
        return v
    if isinstance(v, list):
        return [rename(x, pairs) for x in v]
    if isinstance(v, dict):
        return {rename(k, pairs): rename(x, pairs) for k, x in v.items()}
    return v
