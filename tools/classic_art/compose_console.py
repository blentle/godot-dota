"""按原始 ConsoleUI.fdf 坐标和 UV 拼接经典皮肤，固定 1024×768 基准。"""
import json
from pathlib import Path
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "game/art/classic"
SCALE = 1280


def compose(race="human"):
    source = ROOT / "references/downloads/war3-original/ui/framedef/ui/consoleui.fdf"
    text = source.read_text()
    canvas = Image.new("RGBA", (1024, 1024))
    regions = []
    for block in re.findall(r"Texture\s*\{(.*?)\}", text, re.S):
        name = re.search(r'File "ConsoleTexture(\d+)"', block).group(1)
        width = float(re.search(r"Width ([\d.]+)", block).group(1))
        height = float(re.search(r"Height ([\d.]+)", block).group(1))
        coords = re.search(r"TexCoord ([^;\n]+)", block).group(1)
        u0, u1, v0, v1 = [float(x.strip().rstrip(",")) for x in coords.split(",") if x.strip()]
        anchor = re.search(r"Anchor (\w+),\s*([-\d.]+),\s*([-\d.]+)", block)
        side, ax, ay = anchor.group(1), float(anchor.group(2)), float(anchor.group(3))
        image = Image.open(ART / f"ui/console/{race}/{race}uitile{int(name):02}.png").convert("RGBA")
        rect = (round(u0*image.width), round(v0*image.height), round(u1*image.width), round(v1*image.height))
        size = (round(width*SCALE), round(height*SCALE))
        tile = image.crop(rect).resize(size, Image.Resampling.NEAREST)
        tile.putalpha(tile.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
        x = round(ax*SCALE) if "LEFT" in side else 1024 + round(ax*SCALE) - size[0]
        y = -round(ay*SCALE) if side.startswith("TOP") else 768 - round(ay*SCALE) - size[1]
        canvas.alpha_composite(tile, (x, y))
        regions.append({"texture": name, "source": rect, "destination": [x, y, *size]})
    canvas.save(ART / f"console-{race}.png")
    (ART / f"console-layout-{race}.json").write_text(json.dumps({"basis": [1024, 768], "fdf": str(source.relative_to(ROOT)), "regions": regions}, indent=2)+"\n")
    print("已按原始 FDF 拼接经典 Console：", len(regions), "个区域")


if __name__ == "__main__":
    for race in ["human", "nightelf", "undead"]:
        compose(race)
