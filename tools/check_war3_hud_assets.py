"""检查经典 HUD 的纹理尺寸、导入设置和禁止使用的现代背景资源。"""

from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1] / "game/ui/war3"


def inspect() -> list[str]:
    """只检查此 HUD 的资源，不将主训练界面的旧实现伪报为已迁移。"""
    errors = []
    for path in sorted((ROOT / "assets").glob("*.png")):
        content = path.read_bytes()
        if content[:8] != b"\x89PNG\r\n\x1a\n":
            errors.append(f"不是 PNG：{path.name}")
            continue
        width, height = struct.unpack(">II", content[16:24])
        if any(value <= 0 or value & (value - 1) for value in [width, height]):
            errors.append(f"非二次幂贴图：{path.name} {width}×{height}")
        settings = path.with_suffix(".png.import").read_text(encoding="utf-8")
        if "mipmaps/generate=false" not in settings or "compress/mode=0" not in settings:
            errors.append(f"导入配置不符：{path.name}")
    for path in (ROOT / "scenes").glob("*.tscn"):
        source = path.read_text(encoding="utf-8")
        for forbidden in ['type="Theme"', 'type="StyleBox', 'type="ShaderMaterial"',
                          'type="HBoxContainer"', 'type="VBoxContainer"', 'type="GridContainer"']:
            if forbidden in source:
                errors.append(f"禁止的布局或材质：{path.name} {forbidden}")
    font = (ROOT / "assets/font.tres").read_text(encoding="utf-8")
    if "antialiasing = 0" not in font:
        errors.append("字体未关闭抗锯齿")
    return errors


def main() -> int:
    errors = inspect()
    for error in errors:
        print(error)
    if not errors:
        print("经典 HUD PNG 尺寸、无损导入、mipmap 与场景资源检查通过；不代表原版素材已验收。")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
