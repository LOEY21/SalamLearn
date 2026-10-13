# Builds the live-background layers for Magic Sand Tracer from start_bg.png.
# Same approach as dumps/sirah_layers/gen_start_bg_layers.py: foliage and
# clouds are cut from the painting, the plate behind them is filled, and a
# per-pixel field tells shaders/sand_tracer_bg.frag how each plant sways.
# Run from prjct/:  python ../dumps/tracing_layers/gen_bg_layers.py <debug dir>
from PIL import Image
import numpy as np, cv2, sys, random
S = sys.argv[1]
D = 'assets/images/tracing/'
im = Image.open(D + 'start_bg.png').convert('RGB')
src = np.asarray(im).astype(np.float32)
H, W, _ = src.shape
r, g, b = src[..., 0], src[..., 1], src[..., 2]
luma = 0.3 * r + 0.59 * g + 0.11 * b

# ---- foliage components (hue-based: the paving is yellow, leaves aren't)
hsv = cv2.cvtColor(np.asarray(im), cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
hue, sat = hsv[..., 0] * 360 / 256, hsv[..., 1] / 255
green = (hue > 55) & (hue < 170) & (sat > 0.3)
excl = np.zeros((H, W), bool)
excl[575:634, 140:215] = 1  # the olive dome touching palm 45
excl[650:682, 238:272] = 1  # small domes behind the far palms
excl[694:722, 548:580] = 1
green &= ~excl
m = cv2.morphologyEx(green.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
n, lab, st, cen = cv2.connectedComponentsWithStats(m)

# seed point on the plant, rows it's limited to (a clump split into tiers,
# each rooted at its own base) or None: (root, amp px, freq Hz, trunk
# (top, bottom, width) or None, whether its dark trunk/dates move with it)
P = [
    # the big framing palms sway from their trunks off the edge
    ((100, 60), None, (5, 330), 8, 0.22, None, True),
    ((760, 60), None, (853, 275), 7, 0.25, None, True),
    ((800, 350), None, (870, 350), 4, 0.28, None, False),
    ((40, 480), None, (10, 655), 4, 0.31, ((22, 480), (10, 655), 14), False),
    ((760, 580), None, (800, 725), 3, 0.33, ((795, 590), (800, 725), 12), False),
    ((190, 670), None, (185, 790), 3, 0.35, ((185, 655), (185, 790), 11), False),
    # far palms across the square barely stir
    ((610, 710), None, (612, 790), 1.5, 0.40, ((612, 705), (612, 790), 9), False),
    ((335, 715), None, (335, 765), 1.5, 0.42, ((335, 705), (335, 765), 8), False),
    ((412, 715), None, (412, 775), 1.5, 0.39, ((412, 715), (412, 775), 8), False),
    ((520, 760), None, (520, 790), 1.2, 0.44, ((520, 745), (520, 790), 7), False),
    # bushes and ferns hold still (amp 0): only the palms move
    ((60, 700), (0, 780), (80, 775), 0, 0.50, None, False),
    ((60, 700), (780, 2000), (150, 915), 0, 0.46, None, False),
    ((800, 850), (0, 800), (780, 800), 0, 0.48, None, False),
    ((800, 850), (800, 2000), (760, 990), 0, 0.44, None, False),
    ((375, 780), None, (375, 805), 0, 0.60, None, False),
    ((40, 1000), None, (60, 1045), 0, 0.55, None, False),
    ((830, 1015), None, (835, 1045), 0, 0.58, None, False),
    ((820, 1560), None, (853, 1690), 0, 0.40, None, False),
    ((40, 1580), None, (0, 1690), 0, 0.42, None, False),
    ((700, 1780), None, (700, 1900), 0, 0.36, None, False),
    ((60, 1790), None, (60, 1900), 0, 0.38, None, False),
]


def comp_at(x, y):
    win = lab[max(0, y - 25):y + 26, max(0, x - 25):x + 26]
    ids, counts = np.unique(win[win > 0], return_counts=True)
    big = [k for k, i in enumerate(ids) if st[i][4] > 300]
    assert big, (x, y)
    return int(ids[max(big, key=lambda k: counts[k])])


P = [(comp_at(*seed), rows, *rest) for seed, rows, *rest in P]
for i, rows, *_ in P:
    print(i, rows, tuple(int(v) for v in st[i]))

rng = random.Random(7)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
label = np.zeros((H, W), np.float32)
best = np.full((H, W), 1e9, np.float32)
offx = np.zeros((H, W), np.float32)
offy = np.zeros((H, W), np.float32)
bend = np.zeros((H, W), np.float32)
freq = np.zeros((H, W), np.float32)
phase = np.zeros((H, W), np.float32)
dark = (luma < 150) & (r > b + 15)
# Trunk bark: saturated orange-brown. Shaded wall is paler and duller, so a
# trunk band never carries a sliver of the wall beside it.
bark = (sat > 0.55) & (r > b + 40) & (luma < 185)
# A leaf's own pixels and its dark ink outline; the wall or sky showing
# between leaves stays in the plate.
leafy = green | (luma < 100)
for i, rows, root, amp, f, trunk, trunkdark in P:
    comp = (lab == i) & leafy
    if rows:
        comp[:rows[0]] = False
        comp[rows[1]:] = False
    comp = comp.astype(np.uint8)
    near = cv2.dilate(comp, np.ones((31, 31), np.uint8)) > 0
    lb = comp > 0
    if trunkdark:
        lb |= near & dark & (yy < root[1])
    if trunk:
        (tx0, ty0), (tx1, ty1), tw = trunk
        band = np.zeros((H, W), np.uint8)
        cv2.line(band, (int(tx0), int(ty0)), (int(tx1), int(ty1)), 1, int(tw))
        lb |= (band > 0) & (bark | (luma < 100))
    lb &= ~excl
    # Wide enough that a frond at full swing never leaves its own field.
    region = cv2.dilate(lb.astype(np.uint8), np.ones((61, 61), np.uint8)) > 0
    dist = cv2.distanceTransform((~lb).astype(np.uint8), cv2.DIST_L2, 3)
    take = region & (dist < best)
    best[take] = dist[take]
    cy, cx = [float(v.mean()) for v in np.nonzero(lb)]
    L = max(20.0, float(np.hypot(cx - root[0], cy - root[1])))
    ox = xx - root[0]
    oy = yy - root[1]
    s = np.clip(np.hypot(ox, oy) / L, 0, 1)
    bb = np.clip(s * amp / (0.05 * L), 0, 1)
    offx[take] = ox[take]
    offy[take] = oy[take]
    bend[take] = bb[take]
    freq[take] = f
    phase[take] = rng.random()
    label = np.maximum(label, lb.astype(np.float32))

label = cv2.GaussianBlur(label, (3, 3), 0.7)


def skyfill(img, known, sigma):
    k = known.astype(np.float32)
    num = cv2.GaussianBlur(img * k[..., None], (0, 0), sigma)
    den = cv2.GaussianBlur(k, (0, 0), sigma)[..., None]
    return num / np.maximum(den, 1e-4), den[..., 0]


def fill_sky(img, known):
    fill = np.zeros_like(img)
    got = np.zeros((H, W), np.float32)
    for sg in (6, 14, 30, 70, 150):
        f, d = skyfill(img, known, sg)
        use = (d > 0.08) & (got == 0)
        fill[use] = f[use]
        got[use] = 1
    return fill, got


# ---- clouds. A smooth sky model first, so a cloud's faint edges count as
# cloud (and leave no ghost in the plate) rather than as sky.
CH = 700
yy_ = yy < CH
bluesky = (b > 180) & (b - r > 60)
cloudlike = ((b >= r - 8) & (g <= b + 10) & (r <= g + 12) & (label < 0.02)
             & yy_)


def sky_model(known):
    """Smooth sky: a robust low-order surface through open-sky pixels, so a
    cloud's faint halo can't brighten the fill and leave a ghost."""
    ys, xs = np.nonzero(known[::4, ::4])
    ys, xs = ys * 4, xs * 4
    X, Y = xs / W, ys / CH

    def basis(X, Y):
        return np.stack([X ** i * Y ** j for i in range(5) for j in range(5 - i)], -1)

    A = basis(X, Y)
    keep = np.ones(len(xs), bool)
    for _ in range(4):
        coef = [np.linalg.lstsq(A[keep], src[ys, xs, c][keep], rcond=None)[0]
                for c in range(3)]
        res = src[ys, xs, 0] - A @ coef[0]
        keep = res < 5
    gy, gx = np.mgrid[0:H, 0:W]
    B = basis(gx.ravel() / W, np.minimum(gy.ravel(), CH) / CH)
    return np.stack([(B @ coef[c]).reshape(H, W) for c in range(3)], -1)


# Cloud cores stand well clear of the smooth surface; the sky itself is
# then taken locally from open sky well away from any core, so the haze
# towards the edges isn't read as cloud and halos don't brighten the fill.
core = (r - sky_model(bluesky & yy_)[..., 0] > 25) & cloudlike
seed = bluesky & ~cv2.dilate(core.astype(np.uint8), np.ones((21, 21), np.uint8)).astype(bool)
model, _ = fill_sky(src, seed)
cloudy = (r - model[..., 0] > 8) & cloudlike
cm = cv2.morphologyEx(cloudy.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
# The clouds that drift, one box each; everything cloudy inside a box moves
# as that cloud. Clouds a minaret or wall cuts into stay painted in (they'd
# show a hard edge once they moved); being behind a palm is fine, the cloud
# is filled in under the fronds. The shader fades each box's ends.
BOXES = [
    (425, 12, 165, 50),
    (505, 76, 220, 90),
    (0, 104, 378, 214),
    (466, 236, 164, 56),
    (480, 292, 373, 158),
    (0, 318, 358, 142),
    (403, 446, 192, 64),
    (152, 470, 80, 42),
]
clab = np.zeros((H, W), np.int32)
moving = []
for k, (bx, by, bw, bh) in enumerate(BOXES, 1):
    box = np.zeros((H, W), bool)
    box[by:by + bh, bx:bx + bw] = True
    clab[box & (cm > 0) & (clab == 0)] = k
    moving.append((bx, by, bw, bh, k))

cmask = np.zeros((H, W), np.uint8)
for (x, y, w, h, i) in moving:
    grown = cv2.dilate((clab == i).astype(np.uint8), np.ones((7, 7), np.uint8))
    grown[:y] = 0
    grown[y + h:] = 0
    grown[:, :x] = 0
    grown[:, x + w:] = 0
    cmask |= grown
cmask &= cloudlike.astype(np.uint8)
# Feathered, so where a box cuts through cloud the plate blends rather
# than showing a seam.
wt = cv2.GaussianBlur(cmask.astype(np.float32), (0, 0), 3)
wt = np.maximum(wt, cmask) * (cloudlike | bluesky)  # never into a minaret
wt = wt[..., None]
clean = src * (1 - wt) + model * wt

# Cloud layer (straight alpha): sky + a * cloud = pixel.
Sr = model[..., 0]
a = np.clip((r - Sr) / np.maximum(228 - Sr, 20), 0, 1) * (cmask > 0)
a = np.where(a > 0.02, a, 0)
pre = np.clip(src - model * (1 - a[..., None]), 0, 255)  # premultiplied
# Where a palm or a minaret hid part of a drifting cloud, paint the cloud on under it so
# no hole shows once it drifts out from behind the fronds.
hidden = np.zeros((H, W), np.uint8)
for (x, y, w, h, i) in moving:
    c = (clab == i).astype(np.uint8)
    hull = cv2.morphologyEx(c, cv2.MORPH_CLOSE, np.ones((61, 61), np.uint8))
    hidden |= ((hull > 0) & (c == 0) & ~bluesky).astype(np.uint8)
hidden[CH:] = 0
pre8 = pre.astype(np.uint8)
a8 = (a * 255).astype(np.uint8)
if hidden.any():
    pre8 = cv2.inpaint(pre8, hidden, 5, cv2.INPAINT_TELEA)
    a8 = cv2.inpaint(a8, hidden, 5, cv2.INPAINT_TELEA)
af = np.maximum(a8.astype(np.float32) / 255, 1e-3)[..., None]
col8 = np.clip(pre8 / af, 0, 255).astype(np.uint8)
clouds = np.zeros((CH, W, 4), np.uint8)
clouds[..., :3] = col8[:CH]
clouds[..., 3] = a8[:CH]
Image.fromarray(clouds, 'RGBA').save(D + 'bg_clouds.png', optimize=True)

# ---- foliage painted out of the plate so it can move over it
hole = cv2.dilate((label > 0.02).astype(np.uint8), np.ones((5, 5), np.uint8))
telea = cv2.inpaint(np.clip(clean, 0, 255).astype(np.uint8), hole, 7,
                    cv2.INPAINT_TELEA).astype(np.float32)
cr, cg, cb = clean[..., 0], clean[..., 1], clean[..., 2]
skyk = ((cb > 180) & (cb - cr > 45)) & (hole == 0)
fill, got = fill_sky(clean, skyk)
_, frac = skyfill(np.zeros_like(clean), skyk, 10)
_, vis = skyfill(np.zeros_like(clean), hole == 0, 10)
sp = np.clip(frac / np.maximum(vis, 1e-4), 0, 1)
sp = np.clip((sp - 0.25) / 0.5, 0, 1)[..., None] * got[..., None]
filled = telea * (1 - sp) + fill * sp
clean8 = np.where(hole[..., None] > 0, filled, clean)
clean8 = np.clip(clean8, 0, 255).astype(np.uint8)
Image.fromarray(clean8).save(D + 'bg_clean.png', optimize=True)

# Open sky on the finished plate (palm holes filled with sky count too, so
# clouds pass behind the swaying palms rather than being cut round them).
c8 = clean8.astype(np.float32)
sky = ((c8[..., 2] > 180) & (c8[..., 2] - c8[..., 0] > 45)).astype(np.float32)
sky = cv2.morphologyEx(sky, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
sky[CH:] = 0
sky = cv2.GaussianBlur(sky, (3, 3), 0.8)

palms = np.zeros((H, W, 4), np.uint8)
palms[..., :3] = src.astype(np.uint8)
palms[..., 3] = (label * 255).astype(np.uint8)
palms[label < 0.004] = 0
Image.fromarray(palms, 'RGBA').save(D + 'bg_palms.png', optimize=True)

field = np.zeros((H, W, 3), np.uint8)
field[..., 0] = np.clip((offx / 1024 + 0.5) * 255 + 0.5, 0, 255)
field[..., 1] = np.clip((offy / 1024 + 0.5) * 255 + 0.5, 0, 255)
field[..., 2] = np.clip(bend * 255 + 0.5, 0, 255)
Image.fromarray(field).save(D + 'bg_field.png', optimize=True)

aux = np.zeros((H, W, 3), np.uint8)
aux[..., 0] = np.clip(freq * 255, 0, 255)
aux[..., 1] = np.clip(sky * 255, 0, 255)
aux[..., 2] = np.clip(phase * 255, 0, 255)
Image.fromarray(aux).save(D + 'bg_aux.png', optimize=True)

# Shader lines for the clouds: rect in bg_clouds.png, drift px/s, seed.
# Higher (nearer) clouds are bigger and drift faster than those low on the
# horizon.
for k, (x, y, w, h, i) in enumerate(sorted(moving, key=lambda m: -m[2] * m[3])):
    speed = 2.0 + 5.0 * (1 - (y + h / 2) / CH) + rng.random()
    print('    col = over(col, cloud(p, vec4(%d.0, %d.0, %d.0, %d.0), %.1f, %.1f), sky);'
          % (x, y, w, h, speed, rng.random() * 9))

ov = src.copy()
ov[label > 0.5] = ov[label > 0.5] * 0.3 + np.array([255, 0, 255]) * 0.7
ov[hidden > 0] = [255, 0, 0]
ov[..., 2] = np.maximum(ov[..., 2], sky * 120)
Image.fromarray(ov.astype(np.uint8)).save(S + '/ov.png')
Image.fromarray(clean8).save(S + '/clean.png')
cv = np.zeros((CH, W, 3), np.float32) + [40, 40, 60]
al = clouds[..., 3:4] / 255.0
Image.fromarray((cv * (1 - al) + clouds[..., :3] * al).astype(np.uint8)).save(S + '/clouds.png')
