"""复用原始边框图集拼装固定尺寸面板与按钮；不绘制替代美术。"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "game/art/classic"


def padded(image, name):
    width = 1 << (image.width - 1).bit_length()
    height = 1 << (image.height - 1).bit_length()
    canvas = Image.new("RGBA", (width, height))
    canvas.paste(image, (0, 0))
    canvas.save(ROOT / name)


def panel(width, height, name):
    background = Image.open(ROOT / "ui/widgets/tooltips/human/human-tooltip-background.png").convert("RGBA")
    border = Image.open(ROOT / "ui/widgets/tooltips/human/human-tooltip-border.png").convert("RGBA")
    result = Image.new("RGBA", (width, height))
    for y in range(0, height, background.height):
        for x in range(0, width, background.width):
            result.paste(background, (x, y))
    edge = 10
    pieces = [border.crop((i*16, 0, (i+1)*16, 16)).resize((edge,edge), Image.Resampling.NEAREST) for i in range(8)]
    for i, point in enumerate([(0,0),(width-edge,0),(0,height-edge),(width-edge,height-edge)]):
        result.alpha_composite(pieces[i+4], point)
    result.alpha_composite(pieces[0].resize((edge,height-2*edge), Image.Resampling.NEAREST), (0,edge))
    result.alpha_composite(pieces[1].resize((edge,height-2*edge), Image.Resampling.NEAREST), (width-edge,edge))
    result.alpha_composite(pieces[2].transpose(Image.Transpose.ROTATE_270).resize((width-2*edge,edge), Image.Resampling.NEAREST), (edge,0))
    result.alpha_composite(pieces[3].transpose(Image.Transpose.ROTATE_270).resize((width-2*edge,edge), Image.Resampling.NEAREST), (edge,height-edge))
    padded(result, name)


def main():
    for width,height,name in [(320,160,"tooltip.png"),(340,268,"multiboard.png"),(640,440,"shop.png")]:
        panel(width,height,name)
    Image.new("RGBA",(2,2),(0,0,0,255)).save(ROOT/"black.png")
    print("已组合原版提示框、计分板及训练商店背景")


if __name__ == "__main__":
    main()
