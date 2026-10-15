# Shared: ScheherazadeNew Bold's isolated letter outlines (the naskh face the
# game's Trace This card uses), rasterised (nonzero winding, as
# Flutter fills a Path), split into body and dots, and skeletonised. Used by
# the survey sheets and gen_letter_paths.py.
import numpy as np
from PIL import Image, ImageDraw
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.basePen import decomposeQuadraticSegment
from skimage.morphology import skeletonize
from scipy import ndimage

LETTERS = 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'
FONT = 'assets/fonts/ScheherazadeNew-Bold.ttf'
_font = TTFont(FONT)
_gs = _font.getGlyphSet()
_cmap = _font.getBestCmap()


def contours(ch, steps=12):
    """Outline polygons in font units (y up)."""
    pen = DecomposingRecordingPen(_gs)
    _gs[_cmap[ord(ch)]].draw(pen)
    polys, cur = [], []
    for op, args in pen.value:
        if op == 'moveTo':
            cur = [args[0]]
        elif op == 'lineTo':
            cur.append(args[0])
        elif op == 'qCurveTo':
            p0 = cur[-1]
            for c, e in decomposeQuadraticSegment(args):
                for i in range(1, steps + 1):
                    t = i / steps
                    cur.append(((1-t)**2*p0[0]+2*(1-t)*t*c[0]+t*t*e[0],
                                (1-t)**2*p0[1]+2*(1-t)*t*c[1]+t*t*e[1]))
                p0 = e
        elif op == 'curveTo':
            p0 = cur[-1]
            c1, c2, e = args
            for i in range(1, steps + 1):
                t = i / steps
                cur.append(tuple((1-t)**3*p0[k]+3*(1-t)**2*t*c1[k]+3*(1-t)*t*t*c2[k]+t**3*e[k]
                                 for k in range(2)))
        elif op in ('closePath', 'endPath'):
            if cur:
                polys.append(cur)
            cur = []
    return polys


def advance(ch):
    """Advance width in font units."""
    return _font['hmtx'][_cmap[ord(ch)]][0]


def _signed_area(poly):
    a = np.array(poly)
    return 0.5 * np.sum(a[:, 0] * np.roll(a[:, 1], -1) - np.roll(a[:, 0], -1) * a[:, 1])


class Glyph:
    """One letter rasterised into a px x px square (y down)."""

    def __init__(self, ch, px=600, pad=20):
        self.ch = ch
        self.polys = contours(ch)
        pts = np.array([p for poly in self.polys for p in poly])
        self.x0, self.y0 = pts.min(0)
        self.x1, self.y1 = pts.max(0)
        self.E = max(self.x1 - self.x0, self.y1 - self.y0)
        self.sc = (px - 2 * pad) / self.E
        self.pad = pad
        self.W = int((self.x1 - self.x0) * self.sc) + 2 * pad
        self.H = int((self.y1 - self.y0) * self.sc) + 2 * pad
        wind = np.zeros((self.H, self.W), np.int16)
        for poly in self.polys:
            t = Image.new('L', (self.W, self.H), 0)
            ImageDraw.Draw(t).polygon([self.to_px(p) for p in poly], fill=1)
            wind += np.asarray(t).astype(np.int16) * (1 if _signed_area(poly) > 0 else -1)
        self.mask = wind != 0
        lab, n = ndimage.label(self.mask)
        sizes = ndimage.sum(self.mask, lab, range(1, n + 1))
        big = sizes.max()
        self.parts = []  # (mask, is_dot)
        for i in range(1, n + 1):
            m = lab == i
            ys, xs = np.nonzero(m)
            h, w = np.ptp(ys) + 1, np.ptp(xs) + 1
            # A diamond dot, or two side by side: solid, and square or 2:1.
            wh = w / h
            dot = (sizes[i - 1] < 0.5 * big and sizes[i - 1] / (h * w) >= 0.5
                   and (0.8 < wh < 1.15 or 1.5 < wh < 2.1))
            self.parts.append((m, dot))
        body = np.zeros_like(self.mask)
        for m, dot in self.parts:
            if not dot:
                body |= m
        self.body = body
        ys, xs = np.nonzero(body)
        self.bx0, self.bx1, self.by0, self.by1 = xs.min(), xs.max(), ys.min(), ys.max()
        self.skel = skeletonize(body)
        # Diamond dots often touch in pairs; split a wide cluster evenly.
        self.dots = []
        for m, d in self.parts:
            if not d:
                continue
            ys, xs = np.nonzero(m)
            h, w = np.ptp(ys) + 1, np.ptp(xs) + 1
            k = max(1, int(round(w / h))) if w > 1.4 * h else 1
            edges = np.linspace(xs.min(), xs.max() + 1, k + 1)
            for j in range(k):
                sel = (xs >= edges[j]) & (xs < edges[j + 1])
                self.dots.append((xs[sel].mean(), ys[sel].mean()))

    def to_px(self, p):
        return (self.pad + (p[0] - self.x0) * self.sc, self.pad + (self.y1 - p[1]) * self.sc)

    def uv_px(self, u, v):
        """Body-bbox normalised coords (u right, v down) to px."""
        return (self.bx0 + u * (self.bx1 - self.bx0), self.by0 + v * (self.by1 - self.by0))

    def norm(self, x, y):
        """px to the letter's own unit space: 0..1 on its longer side, y down."""
        return ((x - self.pad) / (self.E * self.sc), (y - self.pad) / (self.E * self.sc))
