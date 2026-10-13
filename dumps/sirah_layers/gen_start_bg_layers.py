# Builds the live-background layers for the Sirah start screen from start_bg.png.
from PIL import Image, ImageDraw
import numpy as np, cv2, sys, random
S = sys.argv[1]
D = 'assets/images/sirah_story/'
src = np.asarray(Image.open(D + 'start_bg.png').convert('RGB')).astype(np.float32)
H, W, _ = src.shape
r, g, b = src[..., 0], src[..., 1], src[..., 2]
luma = 0.3 * r + 0.59 * g + 0.11 * b

# ---- foliage components (same segmentation as the survey pass)
green = (g >= r * 0.82) & (g > b + 25) & (g < 235)
excl = np.zeros((H, W), bool)
excl[360:770, 1340:1560] = 1
excl[300:770, 345:610] = 1
green &= ~excl
m = cv2.morphologyEx(green.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
n, lab, st, cen = cv2.connectedComponentsWithStats(m)

# id: (root, amp px, freq Hz, trunk (top, bottom, width) or None)
P = {
    2: ((122, 165), 10, 0.30, None),
    3: ((1845, 175), 9, 0.27, None),
    35: ((322, 348), 5, 0.42, ((325, 300), (322, 348), 10)),
    63: ((182, 372), 2, 0.50, None),
    65: ((1738, 392), 3, 0.50, None),
    74: ((700, 505), 6, 0.37, ((714, 380), (700, 505), 13)),
    77: ((1622, 445), 5, 0.40, ((1607, 362), (1622, 445), 11)),
    84: ((1285, 455), 5, 0.39, ((1282, 392), (1285, 455), 11)),
    121: ((1113, 565), 6, 0.35, ((1120, 440), (1113, 565), 13)),
    176: ((988, 560), 4, 0.45, ((985, 505), (988, 560), 9)),
    # foreground plants sway from their base
    157: ((232, 614), 4, 0.60, None),
    294: ((40, 830), 4, 0.55, None),
    301: ((200, 780), 3, 0.70, None),
    298: ((264, 690), 2, 0.75, None),
    269: ((304, 622), 2, 0.75, None),
    300: ((1593, 745), 3, 0.65, None),
    267: ((1840, 676), 3, 0.60, None),
    234: ((868, 566), 1.5, 0.80, None),
}
for i in (132, 173, 181, 123, 147, 158, 197, 198, 216, 247, 224, 241, 244, 33, 39):
    x, y, w, h, _ = st[i]
    P[i] = ((x + w / 2, y + h + h * 0.8), 2.2, 0.62, None)

rng = random.Random(7)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
label = np.zeros((H, W), np.float32)
best = np.full((H, W), 1e9, np.float32)
offx = np.zeros((H, W), np.float32)
offy = np.zeros((H, W), np.float32)
bend = np.zeros((H, W), np.float32)
freq = np.zeros((H, W), np.float32)
phase = np.zeros((H, W), np.float32)
dark = (luma < 125) & (r > b + 15)
for i, (root, amp, f, trunk) in P.items():
    comp = (lab == i).astype(np.uint8)
    comp = cv2.morphologyEx(comp, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    near = cv2.dilate(comp, np.ones((31, 31), np.uint8)) > 0
    lb = comp > 0
    if i in (2, 3):
        lb |= near & dark & (yy < root[1])
    if trunk:
        (tx0, ty0), (tx1, ty1), tw = trunk
        band = np.zeros((H, W), np.uint8)
        cv2.line(band, (int(tx0), int(ty0)), (int(tx1), int(ty1)), 1, int(tw))
        lb |= band > 0
    lb &= ~excl
    region = cv2.dilate(lb.astype(np.uint8), np.ones((57, 57), np.uint8)) > 0
    dist = cv2.distanceTransform((~lb).astype(np.uint8), cv2.DIST_L2, 3)
    take = region & (dist < best)
    best[take] = dist[take]
    cx, cy = cen[i]
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

# ---- clouds that drift (fully in open sky); the two tucked behind the
# mountains and the awning stay painted in.
blue = (b > 200) & (b - r > 60)
cl = (b > 200) & (r > 150) & (b - r < 70)
cl[260:] = 0
cm = cv2.morphologyEx(cl.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
cn, clab, cst, _ = cv2.connectedComponentsWithStats(cm)
moving = []
for i in range(1, cn):
    x, y, w, h, ar = cst[i]
    if ar > 3000:
        moving.append((x, y, w, h, i))
print('clouds', moving)

clean = src.copy()
cmask = np.zeros((H, W), np.uint8)
for (x, y, w, h, i) in moving:
    cmask |= cv2.dilate((clab == i).astype(np.uint8), np.ones((11, 11), np.uint8))
def skyfill(img, known, sigma):
    k = known.astype(np.float32)
    num = cv2.GaussianBlur(img * k[..., None], (0, 0), sigma)
    den = cv2.GaussianBlur(k, (0, 0), sigma)[..., None]
    return num / np.maximum(den, 1e-4), den[..., 0]

skypix = (b > 200) & (b - r > 60) & (cmask == 0)
fill = np.zeros_like(src); got = np.zeros((H, W), np.float32)
for sg in (6, 14, 30, 70):
    f, d = skyfill(src, skypix, sg)
    use = (d > 0.08) & (got == 0)
    fill[use] = f[use]; got[use] = 1
clean[cmask > 0] = fill[cmask > 0]

# Cloud layer (straight alpha): sky + a * cloud = pixel.
clouds = np.zeros((H, W, 4), np.float32)
Sr = clean[..., 0]
a = np.clip((r - Sr) / np.maximum(215 - Sr, 20), 0, 1) * (cmask > 0)
a = np.where(a > 0.02, a, 0)
col = (src - clean * (1 - a[..., None])) / np.maximum(a[..., None], 1e-3)
clouds[..., :3] = np.clip(col, 0, 255)
clouds[..., 3] = a * 255
CH = 270
Image.fromarray(clouds[:CH].astype(np.uint8), 'RGBA').save(D + 'start_bg_clouds.png', optimize=True)

# Sky mask from the cloud-free plate, minus foliage.
cr, cg, cb = clean[..., 0], clean[..., 1], clean[..., 2]
sky = ((cb > 190) & (cb - cr > 45)).astype(np.float32)
sky = cv2.morphologyEx(sky, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
sky[500:] = 0
sky = np.minimum(sky, 1 - (label > 0.5))
sky = cv2.GaussianBlur(sky, (3, 3), 0.8)

# Foliage painted out of the plate so it can move over it.
# The hanging lantern by the boy, cut out so it can swing on its chain.
LAMP = [(138, 288), (145, 288), (148, 300), (149, 320), (149, 340), (153, 346),
        (158, 351), (163, 356), (162, 362), (159, 364), (159, 396), (158, 400),
        (157, 405), (152, 410), (146, 413), (136, 413), (130, 410), (125, 405),
        (124, 400), (124, 364), (121, 361), (121, 356), (126, 351), (131, 346),
        (135, 340), (135, 320), (136, 300)]
LX, LY, LW, LH = 112, 284, 56, 136
lm = Image.new('L', (W * 4, H * 4), 0)
ImageDraw.Draw(lm).polygon([(x * 4, y * 4) for x, y in LAMP], fill=255)
lamp = np.asarray(lm.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
# Inside the outline keep the iron (dark) and the glass panes; the wall and
# fronds showing round the chain and the roof's edges fall away.
iron = np.clip((150 - luma) / 35, 0, 1)
iron = cv2.morphologyEx(iron, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
iron[364:399, 127:157] = 1
lamp = cv2.GaussianBlur(lamp * iron, (3, 3), 0.6)
lampimg = np.zeros((LH, LW, 4), np.uint8)
lampimg[..., :3] = src[LY:LY + LH, LX:LX + LW].astype(np.uint8)
lampimg[..., 3] = (lamp[LY:LY + LH, LX:LX + LW] * 255).astype(np.uint8)
Image.fromarray(lampimg, 'RGBA').save(D + 'start_bg_lamp.png', optimize=True)
Image.fromarray(lampimg, 'RGBA').resize((LW * 4, LH * 4), Image.NEAREST).save(S + '/lampcut.png')

hole = cv2.dilate(((label > 0.02) | (lamp > 0.02)).astype(np.uint8), np.ones((5, 5), np.uint8))
telea = cv2.inpaint(np.clip(clean, 0, 255).astype(np.uint8), hole, 7, cv2.INPAINT_TELEA).astype(np.float32)
skyk = ((cb > 190) & (cb - cr > 45)) & (hole == 0)
fill = np.zeros_like(clean); got = np.zeros((H, W), np.float32)
for sg in (6, 14, 30, 70):
    f, d = skyfill(clean, skyk, sg)
    use = (d > 0.08) & (got == 0)
    fill[use] = f[use]; got[use] = 1
_, frac = skyfill(np.zeros_like(clean), skyk, 10)
_, vis = skyfill(np.zeros_like(clean), hole == 0, 10)
sp = np.clip(frac / np.maximum(vis, 1e-4), 0, 1)
sp = np.clip((sp - 0.25) / 0.5, 0, 1)[..., None] * got[..., None]
filled = telea * (1 - sp) + fill * sp
clean8 = np.where(hole[..., None] > 0, filled, clean)
clean8 = np.clip(clean8, 0, 255).astype(np.uint8)
Image.fromarray(clean8).save(D + 'start_bg_clean.png', optimize=True)

palms = np.zeros((H, W, 4), np.uint8)
palms[..., :3] = src.astype(np.uint8)
palms[..., 3] = (label * 255).astype(np.uint8)
palms[label < 0.004] = 0
Image.fromarray(palms, 'RGBA').save(D + 'start_bg_palms.png', optimize=True)

field = np.zeros((H, W, 3), np.uint8)
field[..., 0] = np.clip((offx / 512 + 0.5) * 255 + 0.5, 0, 255)
field[..., 1] = np.clip((offy / 512 + 0.5) * 255 + 0.5, 0, 255)
field[..., 2] = np.clip(bend * 255 + 0.5, 0, 255)
Image.fromarray(field).save(D + 'start_bg_field.png', optimize=True)

aux = np.zeros((H, W, 3), np.uint8)
aux[..., 0] = np.clip(freq * 255, 0, 255)
aux[..., 1] = np.clip(sky * 255, 0, 255)
aux[..., 2] = np.clip(phase * 255, 0, 255)
Image.fromarray(aux).save(D + 'start_bg_aux.png', optimize=True)

ov = src.copy()
ov[label > 0.5] = ov[label > 0.5] * 0.3 + np.array([255, 0, 255]) * 0.7
ov[..., 2] = np.maximum(ov[..., 2], sky * 120)
Image.fromarray(ov.astype(np.uint8)).save(S + '/ov.png')
Image.fromarray(clean8).save(S + '/clean.png')
