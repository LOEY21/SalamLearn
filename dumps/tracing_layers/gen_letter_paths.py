# Builds lib/data/letter_trace_data.dart: for each isolated Arabic letter and
# numeral 1-10,
# ScheherazadeNew Bold's own outline (the tracing mask) and the stroke centre-lines the
# learner follows, taken from the glyph's skeleton so path and shape agree.
# Each stroke is routed along the skeleton through the waypoints below, which
# fix stroke order and direction (right to left, the way the letter is
# written); dots are found from the glyph and added last, right to left.
# Run from prjct/:  python ../dumps/tracing_layers/gen_letter_paths.py <debug dir>
import os, sys
import numpy as np
import networkx as nx
from PIL import Image, ImageDraw
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from letter_glyphs import LETTERS, Glyph, contours, advance

S = sys.argv[1] if len(sys.argv) > 1 else '.'

# Waypoints per stroke, in the letter body's box (dots excluded): u 0 (left)
# .. 1 (right), v 0 (top) .. 1 (bottom). Authored against ScheherazadeNew
# Bold's naskh shapes; see the review sheet this script writes.
BA = [[(0.92, 0.03), (0.93, 0.45), (0.75, 0.75), (0.5, 0.85), (0.15, 0.75),
       (0.06, 0.5), (0.12, 0.25)]]
# One stroke: head left to right, back along it, then down round the bowl.
HA = [[(0.05, 0.18), (0.5, 0.1), (0.92, 0.05), (0.5, 0.1), (0.05, 0.18),
       (0.08, 0.45), (0.05, 0.62), (0.2, 0.85), (0.5, 0.92), (0.97, 0.85)]]
KHA = [[(0.05, 0.15), (0.5, 0.08), (0.95, 0.03), (0.5, 0.08), (0.05, 0.15),
        (0.08, 0.45), (0.05, 0.62), (0.2, 0.85), (0.5, 0.92), (0.97, 0.85)]]
DAL = [[(0.42, 0.02), (0.5, 0.2), (0.8, 0.4), (0.93, 0.62), (0.7, 0.82),
        (0.25, 0.86), (0.05, 0.96)]]
RA = [[(0.83, 0.02), (0.83, 0.22), (0.97, 0.5), (0.75, 0.8), (0.45, 0.92),
       (0.04, 0.85)]]
SIN = [[(0.94, 0.0), (0.95, 0.25), (0.88, 0.38), (0.8, 0.36), (0.78, 0.14),
        (0.79, 0.36), (0.65, 0.42), (0.56, 0.24), (0.57, 0.48), (0.55, 0.72),
        (0.3, 0.9), (0.04, 0.75), (0.15, 0.45)]]
SHIN = [[(0.94, 0.05), (0.95, 0.3), (0.88, 0.4), (0.8, 0.38), (0.78, 0.16),
         (0.79, 0.38), (0.65, 0.42), (0.56, 0.27), (0.57, 0.5), (0.55, 0.72),
         (0.3, 0.9), (0.04, 0.75), (0.1, 0.48)]]
SAD = [[(0.62, 0.45), (0.72, 0.2), (0.9, 0.1), (0.97, 0.22), (0.9, 0.4),
        (0.75, 0.45), (0.6, 0.46), (0.5, 0.32), (0.52, 0.5), (0.5, 0.72),
        (0.25, 0.9), (0.03, 0.7), (0.1, 0.45)]]
TAH = [[(0.47, 0.7), (0.6, 0.6), (0.85, 0.55), (0.97, 0.65), (0.8, 0.85),
        (0.45, 0.88), (0.25, 0.9), (0.03, 0.82)],
       [(0.43, 0.02), (0.45, 0.4), (0.46, 0.7)]]
# One stroke, no lift: head's upper curve down to the joint, out along the
# lower horn and back, then on down round the bowl.
AIN = [[(0.52, 0.08), (0.2, 0.08), (0.12, 0.2), (0.25, 0.3), (0.45, 0.28),
        (0.72, 0.16), (0.45, 0.28), (0.3, 0.32), (0.12, 0.55), (0.08, 0.7),
        (0.3, 0.9), (0.6, 0.93), (0.98, 0.87)]]
HINTS = {
    'ا': [[(0.5, 0.0), (0.4, 0.5), (0.6, 0.97)]],
    'ب': BA, 'ت': BA, 'ث': BA,
    'ج': HA, 'ح': HA, 'خ': KHA,
    'د': DAL, 'ذ': DAL,
    'ر': RA,
    'ز': [[(0.82, 0.03), (0.82, 0.2), (0.97, 0.45), (0.75, 0.8), (0.45, 0.92),
           (0.04, 0.85)]],
    'س': SIN, 'ش': SHIN,
    'ص': SAD, 'ض': SAD,
    'ط': TAH, 'ظ': TAH,
    'ع': AIN, 'غ': AIN,
    # Loops of ف ق و ه run clockwise.
    'ف': [[(0.85, 0.42), (0.72, 0.38), (0.72, 0.2), (0.82, 0.1), (0.9, 0.25),
           (0.9, 0.38), (0.97, 0.5), (0.85, 0.72), (0.5, 0.88),
           (0.1, 0.8), (0.03, 0.6), (0.1, 0.45)]],
    'ق': [[(0.8, 0.45), (0.62, 0.4), (0.62, 0.2), (0.78, 0.1), (0.87, 0.3),
           (0.88, 0.42), (0.95, 0.5), (0.9, 0.75), (0.45, 0.9),
           (0.05, 0.72), (0.15, 0.28)]],
    'ك': [[(0.82, 0.02), (0.87, 0.3), (0.97, 0.68), (0.88, 0.88), (0.5, 0.9),
           (0.12, 0.9), (0.1, 0.72)],
          [(0.57, 0.32), (0.45, 0.42), (0.47, 0.55), (0.57, 0.6), (0.5, 0.67),
           (0.25, 0.65)]],
    'ل': [[(0.88, 0.1), (0.9, 0.4), (0.93, 0.75), (0.5, 0.92), (0.08, 0.8),
           (0.2, 0.56)]],
    'م': [[(0.15, 0.2), (0.5, 0.1), (0.72, 0.25), (0.55, 0.3), (0.3, 0.38),
           (0.2, 0.55), (0.25, 0.8), (0.3, 0.98)]],
    'ن': [[(0.8, 0.02), (0.8, 0.2), (0.95, 0.5), (0.85, 0.75), (0.45, 0.88),
           (0.07, 0.7), (0.15, 0.33)]],
    'ه': [[(0.5, 0.1), (0.52, 0.25), (0.75, 0.33), (0.92, 0.5), (0.85, 0.65),
           (0.45, 0.8), (0.12, 0.62), (0.25, 0.35), (0.46, 0.26)]],
    'و': [[(0.72, 0.38), (0.58, 0.33), (0.6, 0.2), (0.75, 0.12), (0.82, 0.17),
           (0.88, 0.3), (0.96, 0.4), (0.93, 0.6),
           (0.6, 0.87), (0.35, 0.93), (0.02, 0.83)]],
    'ي': [[(0.95, 0.04), (0.85, 0.1), (0.62, 0.25), (0.57, 0.45), (0.85, 0.55),
           (0.88, 0.65), (0.6, 0.8), (0.3, 0.85), (0.05, 0.72), (0.15, 0.3)]],
    # Numerals: top strokes run left to right, then the stem down.
    '١': [[(0.3, 0.03), (0.6, 0.5), (0.85, 0.97)]],
    '٢': [[(0.12, 0.03), (0.35, 0.3), (0.7, 0.25), (0.93, 0.03)],
          [(0.35, 0.3), (0.55, 0.6), (0.6, 0.97)]],
    '٣': [[(0.1, 0.03), (0.3, 0.27), (0.55, 0.24), (0.6, 0.03), (0.6, 0.24),
           (0.75, 0.25), (0.97, 0.03)],
          [(0.3, 0.27), (0.4, 0.6), (0.4, 0.97)]],
    '٤': [[(0.97, 0.0), (0.6, 0.15), (0.3, 0.25), (0.25, 0.4), (0.5, 0.5),
           (0.7, 0.48), (0.5, 0.5), (0.25, 0.75), (0.12, 0.86), (0.7, 0.88),
           (0.97, 0.8)]],
    '٥': [[(0.5, 0.18), (0.15, 0.55), (0.45, 0.83), (0.88, 0.55), (0.6, 0.2)]],
    '٦': [[(0.03, 0.03), (0.35, 0.2), (0.6, 0.2), (0.7, 0.45), (0.92, 0.97)]],
    '٧': [[(0.02, 0.02), (0.3, 0.5), (0.5, 0.8), (0.7, 0.5), (0.98, 0.02)]],
    '٨': [[(0.02, 0.98), (0.3, 0.5), (0.47, 0.04), (0.75, 0.7), (0.98, 0.95)]],
    '٩': [[(0.6, 0.44), (0.62, 0.3), (0.35, 0.1), (0.07, 0.3), (0.3, 0.45),
           (0.55, 0.45), (0.75, 0.7), (0.88, 0.97)]],
}
NUMERALS = '١٢٣٤٥٦٧٨٩'

STEP = 0.02  # resample spacing, in letter units


def route(g, hints):
    """Pixel path along the skeleton through the hint waypoints."""
    ys, xs = np.nonzero(g.skel)
    pix = np.stack([xs, ys], 1)
    lab, _ = ndimage.label(g.skel, structure=np.ones((3, 3)))
    targets = [np.array(g.uv_px(u, v)) for u, v in hints]
    first = pix[np.argmin(((pix - targets[0]) ** 2).sum(1))]
    comp = lab[first[1], first[0]]
    keep = lab[ys, xs] == comp
    pix = pix[keep]
    G = nx.Graph()
    idx = {tuple(p): i for i, p in enumerate(pix)}
    for (x, y), i in idx.items():
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                j = idx.get((x + dx, y + dy))
                if j is not None and j > i:
                    G.add_edge(i, j, weight=np.hypot(dx, dy))
    nodes = [int(np.argmin(((pix - t) ** 2).sum(1))) for t in targets]
    path = [nodes[0]]
    for a, b in zip(nodes, nodes[1:]):
        if a != b:
            path += nx.shortest_path(G, a, b, weight='weight')[1:]
    return pix[path].astype(float)


def extend(g, pts, edt):
    """Push each end out along its tangent to near the stroke's tip."""
    out = [pts]
    for end in (0, -1):
        p = pts[end]
        q = pts[min(6, len(pts) - 1)] if end == 0 else pts[max(-7, -len(pts))]
        d = p - q
        n = np.linalg.norm(d)
        if n < 1e-6:
            continue
        d /= n
        r = edt[int(round(p[1])), int(round(p[0]))] * 0.7
        tip = p + d * r
        out.insert(0 if end == 0 else len(out), tip[None] if end else tip[None])
    if len(out) == 3:
        return np.vstack([out[0], pts, out[2]])
    return pts


def resample(pts, step):
    pts = ndimage.uniform_filter1d(pts, 9, axis=0, mode='nearest')
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    n = max(2, int(s[-1] / step) + 1)
    t = np.linspace(0, s[-1], n)
    return np.stack([np.interp(t, s, pts[:, 0]), np.interp(t, s, pts[:, 1])], 1)


def build(ch):
    g = Glyph(ch)
    edt = ndimage.distance_transform_edt(g.body)
    strokes = []
    for hints in HINTS[ch]:
        px = route(g, hints)
        px = extend(g, px, edt)
        pts = np.array([g.norm(x, y) for x, y in px])
        strokes.append(resample(pts, STEP))
    for x, y in sorted(g.dots, key=lambda d: (-d[0], d[1])):
        strokes.append(np.array([g.norm(x, y)]))
    outline = [np.array([((p[0] - g.x0) / g.E, (g.y1 - p[1]) / g.E) for p in poly])
               for poly in contours(ch, steps=6)]
    return g, strokes, outline


def ten():
    """١٠ as one item: ١ then ٠ beside it (numbers run left to right), the
    ٠ a dot to tap. Both are put back in font units, laid out by advance
    width, and normalised together."""
    g1, s1, o1 = results['١']
    to_font = lambda p: (p[0] * g1.E + g1.x0, g1.y1 - p[1] * g1.E)
    o1 = [np.array([to_font(p) for p in c]) for c in o1]
    s1 = [np.array([to_font(p) for p in st]) for st in s1]
    dx = advance('١')
    o0 = [np.array(c) + (dx, 0) for c in contours('٠', steps=6)]
    pts = np.vstack(o1 + o0)
    x0, y1 = pts[:, 0].min(), pts[:, 1].max()
    E = max(np.ptp(pts[:, 0]), np.ptp(pts[:, 1]))
    norm = lambda a: np.stack([(a[:, 0] - x0) / E, (y1 - a[:, 1]) / E], 1)
    dot = np.vstack(o0)
    centre = np.array([[(dot[:, 0].min() + dot[:, 0].max()) / 2,
                        (dot[:, 1].min() + dot[:, 1].max()) / 2]])
    return g1, [norm(st) for st in s1] + [norm(centre)], [norm(c) for c in o1 + o0]


def fmt(a):
    return ', '.join('%.3f' % v for v in np.asarray(a).ravel())


results = {ch: build(ch) for ch in LETTERS + NUMERALS}
results['١٠'] = ten()

lines = [
    '// GENERATED by dumps/tracing_layers/gen_letter_paths.py from',
    '// assets/fonts/ScheherazadeNew-Bold.ttf. Do not edit by hand; change the',
    '// waypoints in that script and re-run it.',
    '',
    '/// One isolated Arabic letter for Magic Sand Tracer, in the letter\'s own',
    '/// unit space (0..1 on its longer side, y down).',
    'class LetterTrace {',
    '  const LetterTrace(this.outline, this.strokes);',
    '',
    '  /// The glyph\'s contours as flat x,y lists; fill with nonzero winding.',
    '  final List<List<double>> outline;',
    '',
    '  /// Strokes in writing order as flat x,y lists: centre-lines first, each',
    '  /// running the way it is written, then dots (a single point each).',
    '  final List<List<double>> strokes;',
    '}',
    '',
    'const letterTraces = <String, LetterTrace>{',
]
for ch in results:
    g, strokes, outline = results[ch]
    lines.append(f"  '{ch}': LetterTrace(")
    lines.append('    [')
    for c in outline:
        lines.append(f'      [{fmt(c)}],')
    lines.append('    ],')
    lines.append('    [')
    for st in strokes:
        lines.append(f'      [{fmt(st)}],')
    lines.append('    ],')
    lines.append('  ),')
lines.append('};')
open('lib/data/letter_trace_data.dart', 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')

# Review sheet: glyph, strokes numbered with start dot + arrow.
C = 300
sheet = Image.new('RGB', (C * 7, C * ((len(results) + 6) // 7)), 'white')
for k, ch in enumerate(results):
    g, strokes, outline = results[ch]
    sc = C - 40
    img = Image.new('RGB', (C, C), 'white')
    d = ImageDraw.Draw(img)
    for c in outline:
        d.polygon([(20 + x * sc, 20 + y * sc) for x, y in c], fill=(225, 215, 190))
    cols = [(220, 30, 30), (30, 90, 220), (0, 150, 0), (200, 0, 200), (230, 130, 0)]
    for si, st in enumerate(strokes):
        q = [(20 + x * sc, 20 + y * sc) for x, y in st.reshape(-1, 2)]
        col = cols[si % len(cols)]
        if len(q) > 1:
            d.line(q, fill=col, width=3)
            a, b = np.array(q[-4]), np.array(q[-1])
            dv = b - a
            dv /= max(np.linalg.norm(dv), 1e-6)
            nv = np.array([-dv[1], dv[0]])
            d.polygon([tuple(b + dv * 6), tuple(b - dv * 6 + nv * 6), tuple(b - dv * 6 - nv * 6)], fill=col)
        d.ellipse([q[0][0] - 6, q[0][1] - 6, q[0][0] + 6, q[0][1] + 6], outline=col, width=2)
        d.text((q[0][0] + 7, q[0][1] - 6), str(si + 1), fill=col)
    d.text((4, 4), str(k), fill='black')
    sheet.paste(img, ((k % 7) * C, (k // 7) * C))
sheet.save(S + '/letters_final.png')
print('written', len(results))
