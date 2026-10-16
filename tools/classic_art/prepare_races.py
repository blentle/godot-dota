"""按原始种族图集生成菜单状态及白昼指示盘；不添加新的边框或效果。"""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw
from prepare_panels import padded

ART = Path(__file__).resolve().parents[2] / 'game/art/classic'


def main():
    day = Image.open(ART / 'ui/console/human/day-indicator-texture4.png').convert('RGBA')
    sun = Image.new('RGBA', (64, 64))
    sun.paste(day.crop((480, 73, 512, 137)), (0, 0))
    sun.paste(day.crop((0, 73, 32, 137)), (32, 0))
    mask = Image.new('L', sun.size)
    ImageDraw.Draw(mask).ellipse((4, 4, 60, 60), fill=255)
    sun.putalpha(mask)
    for race in ['human', 'nightelf', 'undead']:
        sheet = Image.open(ART / f'ui/widgets/console/{race}/{race}-console-buttonstates2.png').convert('RGBA')
        normal = sheet.crop((0, 0, 85, 22))
        hover = ImageChops.add(normal.convert('RGB'), sheet.crop((0, 96, 85, 118)).convert('RGB')).convert('RGBA')
        hover.putalpha(normal.getchannel('A'))
        for name, image in [('normal', normal), ('hover', hover), ('disabled', sheet.crop((0, 64, 85, 86)))]:
            padded(image, f'button-{race}-{name}.png')
        frame = Image.open(ART / f'ui/console/{race}/{race}uitile-timeindicatorframe.png').convert('RGBA')
        clock = Image.new('RGBA', frame.size)
        clock.alpha_composite(sun, (94, 12))
        clock.alpha_composite(frame)
        clock.save(ART / f'clock-{race}.png')
    print('已生成三种原始种族菜单与白昼盘；昼夜实时变化尚未接入')


if __name__ == '__main__':
    main()
