# SalamLearn — Backpack & Me Header Image Prompts

These replace the map strip currently used as the top banner of the **Backpack** tab (`_BackpackHeader`, 236dp tall) and the **Me** tab (`_ProfileHeader`, 300dp tall). Both banners crop the image to the phone width (`BoxFit.cover`) and put a dark gradient over the bottom half, so the app's text stays readable.

They're matched to the Adventure Map painting (`assets/images/adventure_map/map_background.png`).

**How to use**
- If your tool supports a style reference, attach `map_background.png` with each prompt so the brushwork and palette match.
- Generate in landscape at the size given, then save as:
  - `assets/images/adventure_map/header_backpack.png`
  - `assets/images/adventure_map/header_me.png`
- Keep the subject in the **middle 60% of the width**: phones crop the sides, tablets show more.
- The **bottom 40%** must stay calm and fairly dark. The app draws a title, chips, a progress bar and the avatar there.
- Paste the negative prompt too, if your tool has a field for it.

---

## Negative prompt (use with both)

```
text, letters, words, numbers, Arabic script, calligraphy, watermark, signature, logo, UI elements, frame, border, people, children, characters, mascots, faces, animals in the foreground, prophets or religious figures, idols, crosses, photorealistic, 3D render, harsh black shadows, busy clutter in the bottom area, cropped main subject, blurry, low resolution
```

---

## 1. Backpack tab — "The Explorer's Treasure Camp" — `header_backpack.png`

What sits on top: a bobbing backpack icon at bottom-left, the title "Digital Backpack", "3 of 16 badges earned", and a wooden progress bar along the bottom.

```
A rich painterly storybook fantasy illustration in the exact style of a cozy Islamic kids' adventure-game world map: hand-painted look, saturated warm colours, soft golden-hour light, gentle glow, fine detail, slight top-down three-quarter view. Scene: an explorer's treasure camp at the edge of a desert oasis at sunset — a striped canvas tent with its flap open, glowing brass lanterns hanging from a palm tree, an open wooden treasure chest spilling soft golden light with shiny round gold medals and coloured gem badges inside, a rolled parchment map and a small brass compass on a woven rug, a gentle stream with a little wooden bridge to one side, palm trees and sand dunes behind, a green-domed mosque with a slender minaret far in the distance under a peach-and-gold sky. The treasure chest is the focal point, placed slightly right of centre. The bottom 40% of the image is a calm, darker sandy ground and shadowed rug with no important details, so text can sit on top. No people, no characters, no text. Wide landscape composition, 1920x1080.
```

---

## 2. Me tab — "Under the Crescent Moon" — `header_me.png`

What sits on top: a large round avatar medallion in the centre of the lower half, the child's name under it, and two small wooden chips (age and grade).

```
A rich painterly storybook fantasy illustration in the exact style of a cozy Islamic kids' adventure-game world map: hand-painted look, saturated jewel-tone colours, soft magical glow, fine detail. Scene: the starry summit of the adventure world at night — a deep indigo-to-violet sky full of twinkling stars and a large glowing golden crescent moon at the upper left, soft lilac clouds, snow-capped purple mountains framing both sides, two small waterfalls catching moonlight, and on a far hilltop a tiny glowing open book on a stone pedestal radiating warm golden rays. A soft warm golden halo of light sits in the lower centre of the image, as if lighting a stage for someone to stand in. The bottom 40% is calm, dark night-blue hills and mist with no important details, so a round portrait and name can sit on top. Symmetrical, centred composition. No people, no characters, no text. Landscape composition, 1600x1200.
```

---

## After generating

The banner widget (`MapSceneHeader` in `hub_world.dart`) always uses the map painting at the moment. To use these images it needs an image option: Backpack passes `header_backpack.png`, Me passes `header_me.png`, and anything else keeps the map. That's a small code change.
