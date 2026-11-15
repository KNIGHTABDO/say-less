#!/usr/bin/env python3
"""WCAG contrast of the palette's text/background pairs (values mirror SayLess/UI/Theme.swift)."""
def lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def lum(rgb): r, g, b = map(lin, rgb); return 0.2126 * r + 0.7152 * g + 0.0722 * b
def over(fg, a, bg): return tuple(f * a + b * (1 - a) for f, b in zip(fg, bg))
def ratio(fg, bg):
    hi, lo = sorted((lum(fg), lum(bg)), reverse=True); return (hi + 0.05) / (lo + 0.05)

ink = (0.17, 0.15, 0.14); cream = (0.95, 0.92, 0.86)
table = {"light": (0.91, 0.87, 0.80), "dark": (0.115, 0.105, 0.098)}
shade = {"light": (0.78, 0.72, 0.63), "dark": (0.07, 0.065, 0.06)}
paper = {"light": (0.985, 0.965, 0.925), "dark": (0.93, 0.89, 0.81)}
pairs = []
for m in ("light", "dark"):
    t = table[m]; edge = over(shade[m], 0.55 if m == "light" else 0.7, t)
    on, soft = (ink, 0.78) if m == "light" else (cream, 0.74)
    for bgname, bg in (("table", t), ("table edge", edge)):
        pairs += [(f"{m} onTable on {bgname}", on, bg), (f"{m} onTableSoft on {bgname}", over(on, soft, bg), bg)]
    pairs += [(f"{m} ink on paper", ink, paper[m]), (f"{m} fadedInk on paper", over(ink, 0.72, paper[m]), paper[m])]
bad = 0
for name, fg, bg in pairs:
    r = ratio(fg, bg); ok = r >= 4.5; bad += not ok
    print(f"{'OK ' if ok else 'LOW'} {r:5.2f}  {name}")
raise SystemExit(1 if bad else 0)
