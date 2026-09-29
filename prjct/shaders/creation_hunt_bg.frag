#version 460 core

#include <flutter/runtime_effect.glsl>

// Allah's Creation Hunt scene: the trees bend in the wind and the waterfall
// runs. uMap is baked from each scene's art (half size):
//   r = sway mix (0 = big slow tree, 1 = small stiff one)
//   g = sway weight, 1.0 = 12 image px at the tips (0 at the roots)
//   b = leaf flutter, or inside uFalls how much of the pixel is water.
// uFalls = the falls in image px: left, lip, right, splash line. All zero
// for a scene without falls. uMist: 1 lets the spray drift over whatever
// sits beside the splash, 0 keeps it on the water (so it never hazes over
// anyone standing in front of the falls).

uniform vec2 uSize;
uniform vec2 uImg;
uniform float uTime;
uniform vec4 uFalls;
uniform float uMist;
uniform sampler2D uBg;
uniform sampler2D uMap;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float t = uTime;

  // BoxFit.cover, centred (matches Image.asset(fit: BoxFit.cover)).
  float s = max(uSize.x / uImg.x, uSize.y / uImg.y);
  vec2 d = uImg * s;
  vec2 uv = (p - (uSize - d) * 0.5) / d;
  vec2 q = uv * uImg;

  vec4 m = texture(uMap, uv);
  vec2 suv = uv;
  float lit = 1.0;

  bool inFalls = uFalls.w > 0.0 &&
      q.x > uFalls.x - 16.0 && q.x < uFalls.z + 16.0 &&
      q.y > uFalls.y - 8.0 && q.y < uFalls.w + 22.0;

  if (!inFalls && (m.g > 0.002 || m.b > 0.002)) {
    // Gusts roll across the scene from the left, so neighbouring trees
    // lean one after another rather than all at once.
    float g0 = t * 0.16 - q.x / 900.0;
    float gust = 0.35 + 0.65 * smoothstep(0.25, 0.8, noise(vec2(g0, 3.7)));
    // Big trees swing slow and wide, small ones quicker; both lean
    // downwind a little more than they come back.
    float ph = q.x / 520.0;
    float slow = sin(t * 0.85 - ph) * 0.75 + sin(t * 1.9 - ph * 1.6 + 1.1) * 0.25;
    float quick = sin(t * 1.7 - ph) * 0.7 + sin(t * 3.1 - ph * 1.3 + 0.4) * 0.3;
    float sway = mix(slow, quick, m.r);
    float lean = gust * (0.35 + sway * 0.65);
    vec2 bendPx = vec2(lean * 12.0, abs(lean) * 1.8) * m.g;

    // Leaf clusters flutter on their own, faster when it gusts.
    vec2 lq = q / 26.0;
    vec2 flut = vec2(
        fbm(lq + vec2(t * 1.3, t * 0.4)) - 0.5,
        fbm(lq * 1.1 + vec2(5.2 - t * 0.5, t * 1.1)) - 0.5);
    vec2 flutPx = flut * (1.2 + 2.4 * gust) * m.b;

    suv = uv - (bendPx + flutPx) / uImg;
    // Leaves catch the light as they turn.
    lit = 1.0 + m.b * (flut.x * 0.16 * gust + lean * 0.03);
  }

  vec3 col = texture(uBg, suv).rgb * lit;

  if (inFalls && m.b > 0.01) {
    float w = m.b;
    float x0 = uFalls.x;
    float top = uFalls.y;
    float x1 = uFalls.z;
    float bot = uFalls.w;
    float fy = clamp((q.y - top) / (bot - top), 0.0, 1.0);
    float sheet = step(q.y, bot) * smoothstep(top - 4.0, top + 2.0, q.y);

    // Water shimmers sideways as it drops.
    float wob = (noise(vec2(q.x / 3.0, q.y / 6.0 - t * 9.0)) - 0.5) * 1.6 * sheet;
    vec3 base = texture(uBg, (q + vec2(wob, 0.0)) / uImg).rgb;

    // Streaks racing down, stretching as the water speeds up.
    float fall = (q.y - top) / (6.0 + 22.0 * fy) - t * 3.2;
    float n1 = noise(vec2(q.x / 2.6, fall));
    float n2 = noise(vec2(q.x / 5.0 + 7.0, fall * 0.6 - t * 0.9));
    float hi = smoothstep(0.58, 0.9, n1) * (0.55 + 0.45 * fy);
    float lo = smoothstep(0.42, 0.12, n2);
    // Slick, glassy water right at the lip.
    float lip = exp(-pow((q.y - top - 3.0) / 4.0, 2.0));
    vec3 water = base * (1.0 - lo * 0.14);
    water = mix(water, vec3(0.94, 0.98, 1.0), hi * 0.6);
    water = mix(water, vec3(0.85, 0.94, 1.0), lip * 0.35 * (0.6 + 0.4 * sin(q.x * 0.5 - t * 5.0)));

    // Churning white water where it lands.
    float cx = (x0 + x1) * 0.5;
    float hw = (x1 - x0) * 0.62;
    float band = exp(-pow((q.y - bot) / 11.0, 2.0)) *
        smoothstep(hw + 10.0, hw - 6.0, abs(q.x - cx));
    float churn = fbm(q / 5.0 + vec2(t * 0.6, -t * 2.6)) +
        0.6 * fbm(q / 3.0 + vec2(-t * 1.1, -t * 3.4) + 9.0);
    float foam = smoothstep(0.62, 1.05, churn) * band;
    water = mix(water, vec3(1.0), foam * 0.9);

    // Pool below: light rings and ripples drifting off downstream.
    float pool = smoothstep(bot + 2.0, bot + 12.0, q.y);
    float rip = sin(length((q - vec2(cx, bot)) * vec2(0.6, 1.5)) * 0.9 - t * 4.0);
    water += vec3(0.07) * smoothstep(0.6, 1.0, rip) * pool *
        exp(-(q.y - bot) / 16.0) * (0.5 + 0.5 * noise(q / 6.0 + t));

    col = mix(col, water, w);
  }

  if (uFalls.w > 0.0) {
    // Spray and mist lifting off the splash, drifting up and thinning out.
    float cx = (uFalls.x + uFalls.z) * 0.5;
    float hw = (uFalls.z - uFalls.x) * 0.5;
    vec2 r = (q - vec2(cx, uFalls.w - 4.0)) / vec2(hw * 1.5 + 8.0, 34.0);
    float zone = exp(-dot(r, r) * 2.2) * smoothstep(uFalls.w + 26.0, uFalls.w + 4.0, q.y) *
        mix(m.b, 1.0, uMist);
    if (zone > 0.01) {
      float mist = fbm(vec2(q.x / 14.0 + sin(t * 0.3) * 0.4, q.y / 10.0 + t * 0.9));
      col = mix(col, vec3(0.97, 0.99, 1.0), smoothstep(0.45, 0.8, mist) * zone * 0.5);
    }
  }

  fragColor = vec4(min(col, vec3(1.0)), 1.0);
}
