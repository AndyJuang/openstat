#!/usr/bin/env python3
"""產生 OpenStat 各尺寸 PNG icon"""
import subprocess, math, os

SIZES = [16, 32, 64, 128, 256, 512, 1024]
OUT   = os.path.join(os.path.dirname(__file__), "AppIcon.iconset")

def svg(size):
    r  = size / 2
    cx = r
    # 外圓半徑
    ro = r * 0.88
    ri = r * 0.60
    stroke = max(1, size * 0.055)
    bar_w  = size * 0.11
    bar_gap= size * 0.055
    bar_r  = bar_w / 2

    # 三根柱狀：左、中、右
    bars_x = [cx - bar_w - bar_gap, cx, cx + bar_w + bar_gap]
    bars_h = [0.55, 0.80, 0.40]   # 相對高度
    bottom = size * 0.70

    bars_svg = ""
    for bx, bh in zip(bars_x, bars_h):
        bh_px = size * 0.45 * bh
        by    = bottom - bh_px
        bars_svg += (
            f'<rect x="{bx - bar_w/2:.1f}" y="{by:.1f}" '
            f'width="{bar_w:.1f}" height="{bh_px:.1f}" '
            f'rx="{bar_r:.1f}" fill="white" opacity="0.92"/>\n'
        )

    # 刻度弧（背景圓弧，270°）
    def arc_path(rad, start_deg, end_deg):
        s = math.radians(start_deg)
        e = math.radians(end_deg)
        sx = cx + rad * math.cos(s)
        sy = r  + rad * math.sin(s)
        ex = cx + rad * math.cos(e)
        ey = r  + rad * math.sin(e)
        large = 1 if (end_deg - start_deg) > 180 else 0
        return f"M {sx:.2f} {sy:.2f} A {rad:.2f} {rad:.2f} 0 {large} 1 {ex:.2f} {ey:.2f}"

    arc_bg  = arc_path(ro, 135, 405)   # 270° background arc
    arc_fg  = arc_path(ro, 135, 310)   # ~65% filled arc

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%"   stop-color="#1a1a2e"/>
      <stop offset="100%" stop-color="#16213e"/>
    </linearGradient>
    <linearGradient id="arc" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%"   stop-color="#00d2ff"/>
      <stop offset="100%" stop-color="#7b2ff7"/>
    </linearGradient>
  </defs>
  <!-- 背景 -->
  <rect width="{size}" height="{size}" rx="{size*0.22:.1f}" fill="url(#bg)"/>
  <!-- 背景弧 -->
  <path d="{arc_bg}" fill="none" stroke="white" stroke-opacity="0.15" stroke-width="{stroke:.1f}" stroke-linecap="round"/>
  <!-- 前景弧（漸層） -->
  <path d="{arc_fg}" fill="none" stroke="url(#arc)" stroke-width="{stroke:.1f}" stroke-linecap="round"/>
  <!-- 柱狀圖 -->
  {bars_svg}
</svg>"""

def make_icons():
    os.makedirs(OUT, exist_ok=True)
    for s in SIZES:
        svg_path = f"/tmp/openstat_icon_{s}.svg"
        png_path = os.path.join(OUT, f"icon_{s}x{s}.png")
        png_2x   = os.path.join(OUT, f"icon_{s//2}x{s//2}@2x.png") if s >= 32 else None

        with open(svg_path, "w") as f:
            f.write(svg(s))

        subprocess.run(["rsvg-convert", "-w", str(s), "-h", str(s), svg_path, "-o", png_path], check=True)

        if png_2x and s >= 32:
            import shutil
            shutil.copy(png_path, png_2x)

    subprocess.run(["iconutil", "-c", "icns",
                    OUT, "-o",
                    os.path.join(os.path.dirname(OUT), "AppIcon.icns")], check=True)
    print("✓ AppIcon.icns 已產生")

if __name__ == "__main__":
    make_icons()
