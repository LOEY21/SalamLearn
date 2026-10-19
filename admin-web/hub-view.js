// Read-only mirror of the learner's Student Hub (Adventure Map, Backpack,
// Me) for one learner. Every value is recomputed from synced Firestore
// records with the same rules the app uses:
//   unlocks      prjct/lib/logic/learner/unlock_rules.dart
//   XP           prjct/lib/logic/learner/learner_xp_provider.dart
//   streak       ProgressRepository._streak / activeStreak
//   Noor Energy  prjct/lib/logic/learner/noor_energy_provider.dart
//   homework     profile_screen.dart _pendingHomework
// Games never launch from here — taps only open read-only sheets.
import { DESTINATIONS, BADGES } from "./curriculum-map.js";

const IMG = "img/hub/";
const MAP_W = 1080;
const MAP_H = 3060;
const NOOR_MAX = 5;
const NOOR_MS = 24 * 60 * 1000;

const SLUGS = {
  1: "village-of-salaam",
  2: "desert-of-letters",
  3: "garden-of-words",
  4: "river-of-sirah",
  5: "masjid-of-salah",
  6: "mountain-of-iman",
  7: "quran-corner",
};

const GAME_ICONS = {
  pronounce: "greeting_match",
  creationHunt: "creation_hunt",
  trace: "magic_sand_tracer",
  soundDetective: "sound_detective",
  quranEtiquette: "quran_etiquette",
  labelMaker: "label_maker",
  ayahBuilder: "ayah_builder",
  sirahStory: "sirah_story",
  classroomHeroes: "classroom_heroes",
  taharahAdventure: "taharah_adventure",
  fivePillars: "five_pillars",
  goodDeedTree: "good_deed_tree",
};

const LEVEL_LABELS = ["Beginner", "Practice", "Mastery"];

const esc = (s) =>
  String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const mi = (name, style = "") => `<span class="mi" aria-hidden="true"${style ? ` style="${style}"` : ""}>${name}</span>`;

// ---- Rules (ports of the Dart logic) ----

function levelsOf(lessons) {
  const per = Math.ceil(lessons.length / 3);
  return [lessons.slice(0, per), lessons.slice(per, per * 2), lessons.slice(per * 2)].filter((g) => g.length);
}

const lessonById = new Map(DESTINATIONS.flatMap((d) => d.lessons.map((l) => [l.id, { lesson: l, dest: d }])));

function destForModule(moduleId) {
  const game = lessonById.get(moduleId);
  if (game) return game.dest;
  return DESTINATIONS.find((d) => SLUGS[d.id] === moduleId || String(d.id) === String(moduleId)) ?? null;
}

function assignedLessonsFor(moduleId, maxLevel = 3, maxLessons = null) {
  const game = lessonById.get(moduleId);
  if (game) return [game.lesson];
  const dest = destForModule(moduleId);
  if (!dest) return [];
  const levels = levelsOf(dest.lessons);
  const out = [];
  for (let li = 0; li < maxLevel && li < levels.length; li++) {
    const cap = li === maxLevel - 1 ? maxLessons : null;
    out.push(...levels[li].slice(0, cap ?? levels[li].length));
  }
  return out;
}

const dayStart = (t) => {
  const d = new Date(t);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
};

function activeStreak(records) {
  const days = new Set(records.filter((r) => r.completedAt).map((r) => dayStart(r.completedAt)));
  if (!days.size) return 0;
  const last = Math.max(...days);
  const lastD = new Date(last);
  let run = 1;
  while (days.has(new Date(lastD.getFullYear(), lastD.getMonth(), lastD.getDate() - run).getTime())) run++;
  return Math.round((dayStart(Date.now()) - last) / 86400000) <= 1 ? run : 0;
}

// Replays every finished lesson (each first completion spends one lantern;
// replays write no record) through the app's relight clock.
function noorEnergy(records, now = Date.now()) {
  const plays = records
    .filter((r) => r.lessonId && !r.isClassroomMode && r.completedAt)
    .map((r) => new Date(r.completedAt).getTime())
    .sort((a, b) => a - b);
  let current = NOOR_MAX;
  let nextAt = null;
  const settle = (t) => {
    while (nextAt != null && current < NOOR_MAX && t >= nextAt) {
      current++;
      nextAt = current < NOOR_MAX ? nextAt + NOOR_MS : null;
    }
    if (current >= NOOR_MAX) nextAt = null;
  };
  for (const t of plays) {
    settle(t);
    if (current <= 0) continue;
    current--;
    nextAt = nextAt ?? t + NOOR_MS;
  }
  settle(now);
  return { current, nextAt };
}

function isBadgeUnlocked(badge, unlocked) {
  const name = badge.name.toLowerCase().trim();
  const id = badge.id.toLowerCase().trim();
  const short = badge.name.replaceAll(" Badge", "").toLowerCase().trim();
  return unlocked.find((item) => {
    const n = String(item.badgeId ?? "").toLowerCase().trim();
    return n === name || n === id || n === short || n.replaceAll(" ", "_") === id || n.replaceAll(" ", "_") === name.replaceAll(" ", "_");
  });
}

function mascotFace(avatar) {
  const m = /^(boy|girl)_mascot(?:_([234]))?$/.exec(avatar ?? "");
  return m ? `${IMG}mascot_${m[1]}_${m[2] ?? 1}_face.jpg` : null;
}

function computeHub({ learner, progress, badges, enrollments, assignments }) {
  const lid = learner.id;
  const records = progress.filter((r) => r.learnerId === lid);
  const completed = new Set(records.filter((r) => r.lessonId && !r.assignedByTeacher && !r.isClassroomMode).map((r) => r.lessonId));
  const homeworkDone = new Set(records.filter((r) => r.lessonId && r.assignedByTeacher && !r.isClassroomMode).map((r) => r.lessonId));

  const classIds = enrollments.filter((e) => e.learnerId === lid).map((e) => e.classId);
  const mine = classIds.flatMap((cid) => [
    ...assignments.filter((a) => a.classId === cid && a.learnerId == null),
    ...assignments.filter((a) => a.classId === cid && a.learnerId === lid),
  ]);

  const homeworkDoneFor = (a) => {
    const wanted = assignedLessonsFor(a.moduleId, a.maxLevel ?? 3, a.maxLessons ?? null);
    return wanted.length > 0 && wanted.every((l) => homeworkDone.has(l.id));
  };

  const stageFinished = (d) => d.lessons.length > 0 && d.lessons.every((l) => completed.has(l.id));
  const stageUnlocked = (i) =>
    i === 0 ||
    DESTINATIONS[i - 1].lessons.every((l) => completed.has(l.id)) ||
    mine.some((a) => destForModule(a.moduleId)?.id === DESTINATIONS[i].id);
  const currentId = (DESTINATIONS.find((d) => !stageFinished(d)) ?? DESTINATIONS.at(-1)).id;
  const now = Date.now();

  const stages = DESTINATIONS.map((d, i) => {
    const unlocked = stageUnlocked(i);
    return {
      dest: d,
      state: !unlocked ? "locked" : d.id === currentId ? "current" : "available",
      finished: stageFinished(d),
      overdue: mine.some((a) => destForModule(a.moduleId)?.id === d.id && a.dueDate && new Date(a.dueDate) < now && !homeworkDoneFor(a)),
    };
  });

  const assigned = new Map();
  for (const a of mine) assigned.set(a.moduleId, a);
  const pendingHomework = assigned.size === 0
    ? null
    : [...assigned.values()].reduce(
        (n, a) => n + assignedLessonsFor(a.moduleId, a.maxLevel ?? 3, a.maxLessons ?? null).filter((l) => !homeworkDone.has(l.id)).length,
        0
      );

  const awards = badges.filter((b) => b.learnerId === lid);
  const xp = DESTINATIONS.flatMap((d) => d.lessons).filter((l) => completed.has(l.id)).reduce((s, l) => s + l.xp, 0);

  return {
    learner,
    completed,
    stages,
    currentId,
    xp,
    streak: activeStreak(records),
    noor: noorEnergy(records, now),
    pendingHomework,
    badgeState: BADGES.map((b) => ({ badge: b, award: isBadgeUnlocked(b, awards) })),
  };
}

// ---- Shared pieces ----

function avatarHtml(avatar, size) {
  const face = mascotFace(avatar);
  if (face) return `<span class="hub-avatar" style="width:${size}px;height:${size}px"><img src="${face}" alt=""></span>`;
  return `<span class="hub-avatar is-emoji" style="width:${size}px;height:${size}px;font-size:${size * 0.48}px">${esc(avatar || "🧒")}</span>`;
}

const flame = (lit, size) =>
  `<img src="${IMG}badges/streak_flame_${lit ? "on" : "off"}.webp" width="${size}" height="${size}" alt="">`;
const moon = (lit, size, extra = "") =>
  `<img class="hub-moon ${lit ? "is-lit" : ""} ${extra}" src="${IMG}noor_energy_moon.webp" width="${size}" height="${size}" alt="">`;
const woodChip = (label, iconName) =>
  `<span class="hub-woodchip">${iconName ? mi(iconName, "font-size:15px;color:var(--hub-gold-soft)") : ""}<span>${esc(label)}</span></span>`;
const chunky = (face, edge, inner, { radius = 20, pad = "14px", border = "", cls = "", action = "", depth = 5 } = {}) =>
  `<div class="hub-chunky ${cls}" ${action} style="background:${edge};border-radius:${radius}px;padding-bottom:${depth}px">` +
  `<div class="hub-chunky-face" style="background:${face};border-radius:${radius}px;padding:${pad};${border ? `border:2px solid ${border}` : ""}">${inner}</div></div>`;

const padlockSvg = (w) => `
  <svg class="hub-padlock" width="${w}" height="${w * 1.18}" viewBox="0 0 100 118" aria-hidden="true">
    <defs>
      <linearGradient id="hubShackle" x1="0" x2="1"><stop offset="0" stop-color="#F4F7F8"/><stop offset="1" stop-color="#9AA6AC"/></linearGradient>
      <linearGradient id="hubLockBody" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE27A"/><stop offset=".55" stop-color="#F2B233"/><stop offset="1" stop-color="#D98A12"/></linearGradient>
    </defs>
    <path d="M27 51.5 L27 35.4 A23 23 0 0 1 73 35.4 L73 51.5" fill="none" stroke="#4B3A26" stroke-width="20" stroke-linecap="round"/>
    <path d="M27 51.5 L27 35.4 A23 23 0 0 1 73 35.4 L73 51.5" fill="none" stroke="url(#hubShackle)" stroke-width="11" stroke-linecap="round"/>
    <rect x="0" y="49.6" width="100" height="68.4" rx="24" fill="url(#hubLockBody)" stroke="#7A4A0E" stroke-width="7"/>
    <rect x="16" y="56.7" width="68" height="8.3" rx="5" fill="#fff" fill-opacity=".55"/>
    <circle cx="50" cy="80.4" r="10" fill="#5A330A"/>
    <path d="M45 80.4 L55 80.4 L58 104 L42 104 Z" fill="#5A330A"/>
  </svg>`;

// ---- Map tab ----

function mapNodeHtml(s, W, H) {
  const { dest: d, state, finished, overdue } = s;
  const current = state === "current";
  const locked = state === "locked";
  const tileW = current ? 74 : 66;
  const tileH = (tileW * 180) / 320;
  const iconBox = tileW * 0.78;
  const width = tileW + 24;
  const height = tileH / 2 + iconBox + 12;
  const tileTop = height - tileH;
  const iconBottom = tileH / 2 - 2;
  const top = (H * d.mapY) / MAP_H - (height - tileH / 2);
  const left = (W * d.mapX) / MAP_W - width / 2;

  const twinkles = !locked && !finished
    ? [[-0.42, 0.12], [0.4, 0.28], [0.22, -0.02]]
        .map(([dx, dy], i) => `<span class="hub-twinkle mi" style="left:${width / 2 + dx * iconBox - 5}px;top:${dy * iconBox + 8}px;animation-delay:${-i * 1.2}s">auto_awesome</span>`)
        .join("")
    : "";

  const labelCls = locked ? "is-locked" : finished ? "is-finished" : current ? "is-current" : "";
  return `
    <button type="button" class="hub-node ${locked ? "is-locked" : "is-open"}" data-action="stage" data-stage="${d.id}"
      style="top:${top}px;left:${left}px;width:${width}px;height:${height}px"
      aria-label="${esc(d.name)} module${locked ? ", locked" : ""}">
      <img class="hub-node-tile" src="${IMG}checkpoint_tile.webp" alt="" style="top:${tileTop}px;width:${tileW}px;height:${tileH}px">
      <span class="hub-node-shadow" style="top:${tileTop + tileH / 2 - 5}px;width:${iconBox * 0.62}px"></span>
      <img class="hub-node-icon" src="${IMG}checkpoint_${d.id}.webp" alt="" style="bottom:${iconBottom}px;width:${iconBox}px;height:${iconBox}px">
      ${twinkles}
      ${locked ? `<span class="hub-node-lock" style="bottom:${iconBottom + iconBox * 0.12}px">${padlockSvg(iconBox * 0.56)}</span>` : ""}
      ${finished ? `
        <span class="hub-crown" style="top:${height - iconBottom - iconBox - 16}px">
          ${mi("star", "font-size:13px;margin-top:5px")}${mi("star", "font-size:19px;color:#FFE38A")}${mi("star", "font-size:13px;margin-top:5px")}
        </span>
        <span class="hub-medal" style="bottom:${tileH / 2 + iconBox * 0.62}px">${mi("check", "font-size:15px")}</span>` : ""}
      ${overdue && !locked ? `<span class="hub-overdue" style="bottom:${tileH / 2 + iconBox * 0.7}px">!</span>` : ""}
      <span class="hub-node-label-wrap" style="top:${height + 2}px">
        <span class="hub-node-label ${labelCls}">
          ${locked ? mi("lock", "font-size:10px;color:#B9811A") : ""}
          ${finished ? mi("check_circle", "font-size:11px;color:var(--hub-teal)") : ""}
          <span>${esc(d.name)}</span>
        </span>
      </span>
    </button>`;
}

function mapTabHtml(hub, W) {
  const H = (W * MAP_H) / MAP_W;
  const cur = DESTINATIONS.find((d) => d.id === hub.currentId);
  const n = hub.noor;
  return `
    <div class="hub-scroll hub-map-scroll" data-map-height="${H}" data-current-y="${(H * cur.mapY) / MAP_H}">
      <div class="hub-map" style="height:${H}px;background-image:url(${IMG}map_background.webp)">
        ${hub.stages.map((s) => mapNodeHtml(s, W, H)).join("")}
        <div class="hub-mascot" style="top:${(H * cur.mapY) / MAP_H - 64}px;left:${(W * cur.mapX) / MAP_W + 34}px">
          <span class="hub-mascot-shadow"></span>
          <span class="hub-mascot-face">${avatarHtml(hub.learner.avatar, 66)}</span>
          <span class="hub-mascot-bubble">You are here!</span>
        </div>
      </div>
    </div>
    <div class="hub-topbar">
      <span class="hub-pill">${flame(hub.streak > 0, 18)}<b style="color:var(--hub-coral)">${hub.streak}</b></span>
      <span class="hub-pill"><img src="${IMG}xp_star.webp" width="18" height="18" alt=""><b style="color:var(--hub-gold)">${hub.xp}</b></span>
      <button type="button" class="hub-pill" data-action="noor" aria-label="Noor Energy, ${n.current} of ${NOOR_MAX}">
        ${Array.from({ length: NOOR_MAX }, (_, i) => moon(i < n.current, 16)).join("")}
      </button>
    </div>`;
}

function levelsSheetHtml(hub, destId) {
  const d = DESTINATIONS.find((x) => x.id === destId);
  const c = hub.completed;
  const levels = levelsOf(d.lessons);
  const done = d.lessons.filter((l) => c.has(l.id)).length;
  const noEnergy = hub.noor.current <= 0;
  const focusY = Math.min(1, Math.max(-1, 1 - (d.id - 1) / 3));

  const levelHtml = (group, li) => {
    const unlocked = li === 0 || levels[li - 1].every((l) => c.has(l.id));
    const complete = group.every((l) => c.has(l.id));
    const doneCount = group.filter((l) => c.has(l.id)).length;
    const ink = unlocked ? "var(--hub-wood)" : "var(--hub-ink-soft)";
    const status = complete
      ? `<span class="hub-status" style="background:var(--hub-green);color:#fff">${mi("check", "font-size:13px")}Complete!</span>`
      : !unlocked
      ? mi("lock", "font-size:17px;color:var(--hub-ink-soft)")
      : noEnergy
      ? `<span class="hub-status" style="background:var(--hub-night);color:var(--hub-on-scene)">⚡ needs Noor</span>`
      : `<span class="hub-dots">${group.map((_, i) => `<span class="${i < doneCount ? "is-done" : ""}"></span>`).join("")}</span>`;

    const cards = group.map((lesson, idx) => {
      const isDone = c.has(lesson.id);
      const lessonUnlocked = unlocked && (idx === 0 || c.has(group[idx - 1].id));
      const doneShown = lessonUnlocked && isDone;
      const iconName = GAME_ICONS[lesson.type];
      const art = `<span class="hub-lesson-art ${lessonUnlocked ? "" : "is-locked"}">
          ${iconName ? `<img src="${IMG}game_icons/${iconName}.webp" alt="">` : ""}
          ${doneShown ? `<span class="hub-seal">${mi("check", "font-size:15px")}</span>` : ""}
        </span>`;
      const titleColor = doneShown ? "var(--hub-teal-dark)" : lessonUnlocked ? "var(--hub-ink)" : "var(--hub-ink-soft)";
      const pill = doneShown
        ? `<span class="hub-status" style="background:var(--hub-green);color:#fff">✓ Completed</span>`
        : `<span class="hub-status" style="background:${lessonUnlocked ? "var(--hub-gold-tint)" : "var(--hub-parchment-deep)"};color:${lessonUnlocked ? "var(--hub-gold-deep)" : "var(--hub-ink-soft)"}">+${lesson.xp} XP</span>`;
      const marker = lessonUnlocked && noEnergy
        ? moon(false, 34, "is-dim")
        : doneShown
        ? mi("star", "font-size:34px;color:var(--hub-gold);text-shadow:0 2px 0 rgba(138,90,0,.4)")
        : lessonUnlocked
        ? `<span class="hub-play">${mi("play_arrow", "font-size:26px")}</span>`
        : `<span class="hub-lesson-lock">${mi("lock", "font-size:17px")}</span>`;
      const body = `<div class="hub-lesson-row">${art}
          <div class="hub-lesson-text"><span class="hub-lesson-title" style="color:${titleColor}">${esc(lesson.title)}</span>${pill}</div>
          ${marker}</div>`;
      return lessonUnlocked
        ? chunky(doneShown ? "#DCF0E6" : "#fff", doneShown ? "var(--hub-green)" : "var(--hub-edge)", body, { pad: "12px", border: doneShown ? "var(--hub-green)" : "" })
        : `<div class="hub-lesson-locked">${body}</div>`;
    }).join("");

    return `<section class="hub-level">
        <div class="hub-level-head">
          ${Array.from({ length: li + 1 }, () => mi("star", `font-size:18px;color:${unlocked ? "var(--hub-gold)" : "var(--hub-locked-ring)"}`)).join("")}
          <span class="hub-level-title" style="color:${ink}">Level ${li + 1} — ${LEVEL_LABELS[Math.min(li, 2)]}</span>
          ${status}
        </div>
        ${cards}
      </section>`;
  };

  return `
    <div class="hub-overlay is-bottom" data-action="close">
      <div class="hub-levels" data-stop>
        <div class="hub-levels-inner">
          <div class="hub-scene" style="height:150px;background-image:url(${IMG}map_background.webp);background-position:50% ${((focusY + 1) / 2) * 100}%">
            <span class="hub-handle"></span>
            <button type="button" class="hub-close" data-action="close" aria-label="Close">${mi("close", "font-size:19px")}</button>
            <div class="hub-levels-head">
              <span class="hub-levels-badge" style="box-shadow:0 0 16px ${d.color}8C,0 3px 6px rgba(0,0,0,.4)"><img src="${IMG}checkpoint_${d.id}.webp" alt=""></span>
              <div>
                <div class="hub-levels-name">${esc(d.name)}</div>
                <div class="hub-levels-ar" dir="rtl">${esc(d.nameAr)}</div>
                ${woodChip(`${done} / ${d.lessons.length} games`, "star")}
              </div>
            </div>
          </div>
          ${noEnergy ? `<div class="hub-resting">${moon(false, 30, "is-dim")}<span>Noor Energy is resting — come back soon to play again!</span></div>` : ""}
          <div class="hub-levels-body">${levels.map(levelHtml).join("")}</div>
        </div>
      </div>
    </div>`;
}

function lockedDialogHtml(destId) {
  const d = DESTINATIONS.find((x) => x.id === destId);
  return `
    <div class="hub-overlay is-center" data-action="close">
      <div class="hub-dialog" data-stop>
        ${mi("lock_outline", "font-size:44px;color:var(--hub-coral)")}
        <h4>${esc(d.name)} is Locked</h4>
        <p>This module is not currently unlocked. Complete the previous module first, or complete your teacher-assigned homework to unlock new modules!</p>
        <button type="button" class="hub-dialog-ok" data-action="close">OK</button>
      </div>
    </div>`;
}

function noorSheetHtml(hub) {
  const n = hub.noor;
  const mins = n.nextAt ? Math.max(0, Math.floor((n.nextAt - Date.now()) / 60000)) : 0;
  const resetIn = mins >= 60 ? `${Math.floor(mins / 60)}h ${mins % 60}m` : `${mins}m`;
  const rule = (iconName, color, title, body) => `
    <div class="hub-rule"><span class="hub-rule-icon" style="background:${color}21;color:${color}">${mi(iconName, "font-size:24px")}</span>
      <div><div class="hub-rule-title">${title}</div><div class="hub-rule-body">${body}</div></div></div>`;
  return `
    <div class="hub-overlay is-bottom is-padded" data-action="close">
      <div class="hub-info" data-stop>
        <div class="hub-info-top">
          <div class="hub-info-hero">${Array.from({ length: NOOR_MAX }, (_, i) => moon(i < n.current, 44, i < n.current ? "is-glow" : "")).join("")}</div>
          <div class="hub-info-title">Noor Energy</div>
          <div class="hub-chips">
            ${woodChip(`${n.current} of ${NOOR_MAX} lanterns lit`)}
            ${n.current < NOOR_MAX ? woodChip(`Next lantern in ${resetIn}`, "schedule") : ""}
          </div>
        </div>
        <div class="hub-info-rules">
          ${rule("map", "#B8741A", "1 lantern = 1 adventure", "Finishing a new lesson uses 1 lantern. Playing again is free!")}
          ${rule("nightlight_round", "#0F6E56", "They come back", "A used lantern lights up again every 24 minutes.")}
          ${rule("backpack", "#D85A30", "Out of lanterns?", "Visit your Backpack. It never uses a lantern.")}
          ${chunky("var(--hub-teal)", "var(--hub-teal-dark)", `<span class="hub-btn-label">Got it!</span>`, { radius: 18, pad: "13px", action: 'data-action="close"', cls: "is-button" })}
        </div>
      </div>
    </div>`;
}

// ---- Backpack tab ----

function medallionHtml(badge, earned, size) {
  return `<span class="hub-medallion ${earned ? "is-earned" : ""}" style="width:${size}px;height:${size}px;--glow:${badge.color}">
      <img src="${IMG}badges/${badge.id}.webp" alt="${esc(badge.name)}">
      ${earned ? "" : `<span class="hub-medallion-lock" style="width:${size * 0.34}px;height:${size * 0.34}px">${mi("lock", `font-size:${size * 0.19}px`)}</span>`}
    </span>`;
}

function backpackTabHtml(hub, category) {
  const earnedCount = hub.badgeState.filter((b) => b.award).length;
  const total = hub.badgeState.length;
  const shelf = hub.badgeState.filter((b) => b.badge.category === category);
  const shelves = [];
  for (let i = 0; i < shelf.length; i += 3) shelves.push(shelf.slice(i, i + 3));
  const tab = (c, iconName, label) => {
    const active = c === category;
    return chunky(
      active ? "var(--hub-gold)" : "#fff",
      active ? "var(--hub-gold-deep)" : "var(--hub-edge)",
      `<span class="hub-tab-label" style="color:${active ? "var(--hub-wood)" : "var(--hub-ink-soft)"}">${mi(iconName, "font-size:20px")}${label}</span>`,
      { radius: 18, pad: "13px 8px", border: active ? "" : "var(--hub-cream-border)", depth: active ? 4 : 5, action: `data-action="category" data-category="${c}"`, cls: "is-button" }
    );
  };
  return `
    <div class="hub-scroll">
      <div class="hub-scene" style="height:236px;background-image:url(${IMG}header_backpack.webp);background-position:67.5% 50%">
        <div class="hub-bp-head">
          <div class="hub-bp-row">
            <img class="hub-bob" src="${IMG}tab_backpack.webp" width="78" height="78" alt="">
            <div>
              <div class="hub-bp-title">Digital Backpack</div>
              <div class="hub-bp-sub">${earnedCount} of ${total} badges earned</div>
            </div>
          </div>
          <div class="hub-woodbar"><span style="width:${earnedCount === 0 ? 0 : `max(10px, ${(earnedCount / total) * 100}%)`}"></span></div>
        </div>
      </div>
      <div class="hub-bp-tabs">
        ${tab("milestone", "emoji_events", "Milestones")}
        ${tab("streak", "local_fire_department", "Streaks")}
      </div>
      <div class="hub-bp-cabinet">
        <div class="hub-quest"><div class="hub-quest-inner" style="padding:16px 10px 8px">
          ${shelves.map((row) => `
            <div class="hub-shelf">
              ${[0, 1, 2].map((i) => {
                const b = row[i];
                if (!b) return `<span></span>`;
                const earned = !!b.award;
                return `<button type="button" class="hub-shelf-badge" data-action="badge" data-badge="${b.badge.id}">
                  ${medallionHtml(b.badge, earned, 74)}
                  <span class="hub-shelf-name" style="color:${earned ? "var(--hub-ink)" : "var(--hub-ink-soft)"}">${esc(b.badge.name.replaceAll(" Badge", ""))}</span>
                  <span class="hub-shelf-state" style="color:${earned ? "var(--hub-teal)" : "var(--hub-ink-soft)"}">${mi(earned ? "check_circle" : "lock", "font-size:13px")}${earned ? "Earned" : "Locked"}</span>
                </button>`;
              }).join("")}
            </div>
            <div class="hub-plank"><span></span><span></span></div>`).join("")}
        </div></div>
      </div>
    </div>`;
}

function badgeSheetHtml(hub, badgeId) {
  const { badge, award } = hub.badgeState.find((b) => b.badge.id === badgeId);
  const earned = !!award;
  const when = earned && award.earnedAt ? ` on ${new Date(award.earnedAt).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })}` : "";
  return `
    <div class="hub-overlay is-bottom is-padded" data-action="close">
      <div class="hub-quest" data-stop><div class="hub-quest-inner hub-badge-sheet">
        <span class="hub-handle is-dark"></span>
        <div class="hub-badge-hero">${earned ? `<span class="hub-rotglow" style="--c:${badge.color}"></span>` : ""}${medallionHtml(badge, earned, 112)}</div>
        <div class="hub-badge-name">${esc(badge.name)}</div>
        ${woodChip(badge.category === "milestone" ? "Milestone & Completion" : "Streak & Habit")}
        <div class="hub-earn-box"><div class="hub-earn-label">How to earn it</div><div class="hub-earn-text">${esc(badge.requirement)}</div></div>
        <div class="hub-earn-state" style="color:${earned ? "var(--hub-teal)" : "var(--hub-gold-deep)"}">
          ${mi(earned ? "check_circle" : "star", `font-size:22px;color:${earned ? "var(--hub-teal)" : "var(--hub-gold)"}`)}${earned ? `Earned${esc(when)}` : `+${badge.xp} XP Reward`}
        </div>
        ${chunky("var(--hub-teal)", "var(--hub-teal-dark)", `<span class="hub-btn-label">Close</span>`, { radius: 18, pad: "13px", action: 'data-action="close"', cls: "is-button" })}
      </div></div>
    </div>`;
}

// ---- Me tab ----

function meTabHtml(hub, studentId) {
  const l = hub.learner;
  const name = l.name || "friend";
  const s = hub.streak;
  const earnedCount = hub.badgeState.filter((b) => b.award).length;
  const note = s === 0
    ? "Play one game today to start your streak!"
    : s === 1
    ? "You learned today. Come back tomorrow to grow your streak!"
    : `You have learned ${s} days in a row. Keep it going!`;
  const p = hub.pendingHomework;
  const hasWork = p != null && p > 0;
  const hwSub = p == null ? "No homework yet" : hasWork ? `${p} pending game${p === 1 ? "" : "s"} to play` : "All homework completed! 🎉";
  const stat = (iconHtml, value, label, color, action = "") =>
    chunky("#fff", "var(--hub-edge)", `
      ${action ? mi("arrow_forward", `font-size:16px;color:${color}`).replace('class="mi"', 'class="mi hub-stat-arrow"') : ""}
      <span class="hub-stat-icon">${iconHtml}</span>
      <span class="hub-stat-value" style="color:${color}">${value}</span>
      <span class="hub-stat-label">${label}</span>`,
      { pad: "12px 6px 10px", border: "var(--hub-cream-border)", action, cls: action ? "is-button hub-stat" : "hub-stat" });
  const setting = (iconName, color, label, sub, trailing) =>
    chunky("#fff", "var(--hub-edge)", `
      <div class="hub-setting">
        <span class="hub-rule-icon" style="background:${color}21;color:${color}">${mi(iconName, "font-size:24px")}</span>
        <div class="hub-setting-text"><div class="hub-setting-label">${label}</div><div class="hub-setting-sub">${sub}</div></div>
        ${mi(trailing, "font-size:22px;color:var(--hub-ink-soft)")}
      </div>`, { radius: 18, pad: "12px", border: "var(--hub-cream-border)" });

  return `
    <div class="hub-scroll">
      <div class="hub-scene" style="height:320px;background-image:url(${IMG}header_me.webp);background-position:50% 35%">
        <span class="hub-bell">${mi("notifications", "font-size:26px")}</span>
        <div class="hub-me-head">
          <span class="hub-me-ring"><span>${avatarHtml(l.avatar, 96)}</span></span>
          <div class="hub-me-name">${esc(name)}</div>
          <div class="hub-me-id">Student ID: ${esc(studentId)}</div>
          <div class="hub-chips">
            ${l.age != null ? woodChip(`Age ${l.age}`, "cake") : ""}
            ${l.gradeLevel ? woodChip(l.gradeLevel, "school") : ""}
          </div>
        </div>
      </div>
      <div class="hub-me-body">
        <div class="hub-stats">
          ${stat(flame(s > 0, 30), s, "Day Streak", "var(--hub-coral)")}
          ${stat(`<img src="${IMG}xp_star.webp" width="30" height="30" alt="">`, hub.xp, "XP", "var(--hub-gold-deep)")}
          ${stat(`<img src="${IMG}tab_backpack.webp" width="30" height="30" alt="">`, earnedCount, "Badges", "var(--hub-teal)", 'data-action="tab" data-tab="backpack"')}
        </div>
        <div class="hub-note"><div class="hub-note-title">Salam, ${esc(name)}! 👋</div><div class="hub-note-text">${note}</div></div>
        <h5 class="hub-section">My Homework</h5>
        ${chunky(hasWork ? "var(--hub-purple)" : "#fff", hasWork ? "var(--hub-purple-deep)" : "var(--hub-edge)", `
          <div class="hub-setting">
            <span class="hub-hw-icon ${hasWork ? "has-work" : ""}">${mi("menu_book", "font-size:30px")}</span>
            <div class="hub-setting-text">
              <div class="hub-hw-title" style="color:${hasWork ? "#fff" : "var(--hub-ink)"}">Assigned Homework</div>
              <div class="hub-hw-sub" style="color:${hasWork ? "#EDEBFF" : "var(--hub-teal)"}">${hwSub}</div>
            </div>
            ${hasWork ? `<span class="hub-hw-count">${p}</span>` : mi("chevron_right", "font-size:24px;color:var(--hub-ink-soft)")}
          </div>`, { radius: 22, pad: "14px", border: hasWork ? "" : "var(--hub-cream-border)" })}
        <h5 class="hub-section">Settings</h5>
        ${setting("face_retouching_natural", "#EF9F27", "My Mascot", "Change your mascot", "chevron_right")}
        ${setting("switch_account", "#0F6E56", "Switch Account", "Requires parent PIN", "lock")}
      </div>
    </div>`;
}

// ---- Shell ----

function bottomNavHtml(tab, avatar) {
  const idx = { home: 0, backpack: 1, profile: 2 }[tab];
  const gradient = {
    home: ["var(--hub-teal)", "var(--hub-green)", "rgba(15,110,86,.35)"],
    backpack: ["#72C9F8", "#6C63D6", "rgba(114,201,248,.35)"],
    profile: ["var(--hub-gold)", "var(--hub-coral)", "rgba(239,159,39,.35)"],
  }[tab];
  const item = (key, label, iconHtml) => `
    <button type="button" class="hub-nav-item ${tab === key ? "is-active" : ""}" data-action="tab" data-tab="${key}">
      <span class="hub-nav-icon">${iconHtml}</span><span class="hub-nav-label">${label}</span>
    </button>`;
  return `
    <nav class="hub-nav">
      <div class="hub-nav-board">
        <div class="hub-nav-inner">
          <span class="hub-nav-medal" style="left:calc((100% - 16px) * ${idx * 0.34})"><span style="background:linear-gradient(135deg, ${gradient[0]}, ${gradient[1]});box-shadow:0 4px 10px ${gradient[2]}"></span></span>
          ${item("home", "Home", `<img src="${IMG}tab_map.webp" width="42" height="42" alt="">`)}
          ${item("backpack", "Backpack", `<img src="${IMG}tab_backpack.webp" width="42" height="42" alt="">`)}
          ${item("profile", "Me", avatarHtml(avatar, 44))}
        </div>
        <i style="top:8px;left:10px"></i><i style="top:8px;right:10px"></i><i style="bottom:8px;left:10px"></i><i style="bottom:8px;right:10px"></i>
      </div>
    </nav>`;
}

export function renderHubView(phone, data, studentId) {
  const hub = computeHub(data);
  const ui = { tab: "home", category: "milestone", sheet: null };

  const draw = () => {
    const W = phone.clientWidth || 390;
    const screen = ui.tab === "home" ? mapTabHtml(hub, W) : ui.tab === "backpack" ? backpackTabHtml(hub, ui.category) : meTabHtml(hub, studentId);
    const sheet = !ui.sheet
      ? ""
      : ui.sheet.kind === "levels"
      ? levelsSheetHtml(hub, ui.sheet.id)
      : ui.sheet.kind === "locked"
      ? lockedDialogHtml(ui.sheet.id)
      : ui.sheet.kind === "noor"
      ? noorSheetHtml(hub)
      : badgeSheetHtml(hub, ui.sheet.id);
    const prevScroll = phone.querySelector(".hub-scroll")?.scrollTop;
    phone.innerHTML = `<div class="hub-screen">${screen}</div>${bottomNavHtml(ui.tab, hub.learner.avatar)}${sheet}`;
    const scroller = phone.querySelector(".hub-scroll");
    if (ui.keepScroll && prevScroll != null) {
      scroller.scrollTop = prevScroll;
    } else if (ui.tab === "home") {
      scroller.scrollTop = Math.max(0, Number(scroller.dataset.currentY) - 300);
    }
    ui.keepScroll = false;
    ui.width = W;
  };

  // Map pins are laid out in pixels from the frame width, so redraw when a
  // phone rotates or the window is resized.
  window.removeEventListener("resize", phone.hubResize);
  phone.hubResize = () => {
    if (phone.clientWidth && phone.clientWidth !== ui.width) draw();
  };
  window.addEventListener("resize", phone.hubResize);

  phone.onclick = (e) => {
    const el = e.target.closest("[data-action], [data-stop]");
    if (!el || !phone.contains(el)) return;
    if (el.hasAttribute("data-stop")) return;
    const a = el.dataset.action;
    ui.keepScroll = a !== "tab";
    if (a === "tab") {
      if (ui.tab === el.dataset.tab) return;
      ui.tab = el.dataset.tab;
      ui.sheet = null;
    } else if (a === "category") {
      ui.category = el.dataset.category;
    } else if (a === "stage") {
      const id = Number(el.dataset.stage);
      const locked = hub.stages.find((s) => s.dest.id === id).state === "locked";
      ui.sheet = { kind: locked ? "locked" : "levels", id };
    } else if (a === "noor") {
      ui.sheet = { kind: "noor" };
    } else if (a === "badge") {
      ui.sheet = { kind: "badge", id: el.dataset.badge };
    } else if (a === "close") {
      ui.sheet = null;
    }
    draw();
  };

  draw();
}

// Self-check for the ported rules: `node --input-type=module -e "import('./hub-view.js').then(m => m.selfCheck())"`.
export function selfCheck() {
  const t0 = new Date(2026, 0, 10, 9, 0).getTime();
  const rec = (mins, extra = {}) => ({ lessonId: "dest1-s3", completedAt: new Date(t0 + mins * 60000).toISOString(), ...extra });
  const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

  let n = noorEnergy([rec(0), rec(1), rec(2)], t0 + 3 * 60000);
  assert(n.current === 2 && n.nextAt === t0 + 24 * 60000, "3 plays -> 2 left, clock from first");
  n = noorEnergy([rec(0), rec(1), rec(2)], t0 + 49 * 60000);
  assert(n.current === 4, "two lanterns relit after 48m");
  n = noorEnergy([rec(0), rec(0), rec(0), rec(0), rec(0), rec(1)], t0 + 2 * 60000);
  assert(n.current === 0, "spent row stays empty, extra play ignored");
  n = noorEnergy([rec(0, { isClassroomMode: true })], t0 + 60000);
  assert(n.current === 5 && n.nextAt === null, "classroom play costs nothing");

  const today = new Date();
  const day = (k) => ({ completedAt: new Date(today.getFullYear(), today.getMonth(), today.getDate() - k, 12).toISOString() });
  assert(activeStreak([day(0), day(1), day(2)]) === 3, "3-day streak");
  assert(activeStreak([day(1), day(2)]) === 2, "yesterday keeps streak");
  assert(activeStreak([day(2), day(3)]) === 0, "missed day resets");

  assert(levelsOf(DESTINATIONS[0].lessons).map((g) => g.length).join() === "3,3,1", "7 lessons split 3/3/1");
  assert(assignedLessonsFor("village-of-salaam", 2, 1).length === 4, "maxLevel 2 + maxLessons 1");
  assert(isBadgeUnlocked(BADGES.find((b) => b.id === "first_steps"), [{ badgeId: "First Steps Badge" }]), "badge matched by name");
  return "ok";
}
