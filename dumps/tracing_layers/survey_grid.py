# Gridded sheets (body-bbox 0..10 grid, skeleton, dots) for authoring waypoints.
import sys, os
os.chdir(os.path.join(os.path.dirname(__file__), '../../prjct'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from letter_glyphs import *
S = sys.argv[1]
C = 400
for sheet in range(4):
    img = Image.new('RGB', (C * 4, C * 2), 'white')
    for j in range(8):
        k = sheet * 8 + j
        if k >= len(LETTERS):
            break
        g = Glyph(LETTERS[k], px=C - 40, pad=20)
        cell = np.full((g.H, g.W, 3), 255, np.uint8)
        cell[g.mask] = (225, 215, 190)
        cell[g.skel] = (0, 90, 255)
        im = Image.fromarray(cell)
        d = ImageDraw.Draw(im)
        for t in range(11):
            x, _ = g.uv_px(t / 10, 0)
            _, y = g.uv_px(0, t / 10)
            col = (255, 120, 120) if t % 5 == 0 else (235, 205, 205)
            d.line([(x, g.by0), (x, g.by1)], fill=col)
            d.line([(g.bx0, y), (g.bx1, y)], fill=col)
            d.text((x - 3, max(0, g.by0 - 14)), str(t), fill=(200, 0, 0))
            d.text((max(0, g.bx0 - 16), y - 5), str(t), fill=(200, 0, 0))
        for (x, y) in g.dots:
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(0, 160, 0))
        d.text((g.W - 30, g.H - 14), str(k), fill='black')
        img.paste(im, ((j % 4) * C, (j // 4) * C))
    img.save(f'{S}/grid{sheet}.png')
print('ok')
