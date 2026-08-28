# The other forks, and what is worth taking from them

Neko for Mac has one ancestor — [mdonoughe/neko-mac](https://github.com/mdonoughe/neko-mac),
142 stars, last touched **21 April 2018** — and 25 forks. This one is a sibling of
the other 24, not their parent: nobody has forked this repository yet.

Twenty-four were read. Fourteen are untouched copies. Ten have commits of their
own, and this is what is in them.

## 1. The landscape, by size

| fork | last push | ahead | what it is |
| --- | --- | --- | --- |
| **this one** | today | — | 9.1 MB. Plugins, verbs, engines, a diary, four languages |
| oO0oO0oO0o0o00 | 2025-11 | 15 | Swift/SwiftUI rewrite; transparency, several cats |
| andreaponza | 2023-01 | 24 | characters: dog, tomoyo, tora, bsd, buddy |
| naoyasugioka | 2026-05 | 11 | multi-screen, point symmetry, a DMG |
| akshat-khare | 2025-12 | 7 | sprites replaced with a company logo |
| ferlor-BSG | 2026-07 | 1 | **flee mode, placed cat**, geometry extracted + tests |
| sgrankin | 2024-09 | 3 | modern conventions, signing, lower deployment target |
| ggppjj | 2026-02 | 1 | AppDelegate, deprecated API |
| Inokinoki/ineko | 2018-05 | 2 | mirrored cursor ("the cat hates you") |
| vonkow | 2018-11 | 1 | scratching in the direction it was walking |

Everything below the first row is 50–200 KB against this repository's 9 MB, and
that ratio is the honest summary: **the other forks are the 2018 program brought
forward. Most of what they added, this already has** — multi-screen, all Spaces
and full-screen apps, login item, characters, code signing, a disk image.

So the question is not what they built. It is which of their **ideas** are absent
here, and three are.

## 2. Worth taking

### 2.1 The cat fades as it nears the pointer — oO0oO0oO0o0o00

Their `CatAnimator` computes an opacity per frame:

```objc
if (self.settings.transparencyRadius < self.mouseDistance) {
    result.opacity = 1.0;
} else {
    float rate = self.mouseDistance / self.settings.transparencyRadius;
    result.opacity = 1 - centerTransparency + rate * centerTransparency;
}
```

Two settings: a radius, and how transparent it goes at the middle.

**Why it belongs here.** This app already decided the same thing and solved it
differently: 2.2's *"stops an arm's length short, and off the line it walked in
on"* exists because a cat sitting on your caret is in the way. Fading is the same
principle applied to the moment it is unavoidable — walking over what you are
reading on its way somewhere else.

**Cost**: small. `MyView` owns its image since 2.7.1 and already draws with a
`fraction:`; the number would come from the distance `MyPanel` computes every
tick anyway. One setting, defaulting to a gentle fade.

**Care**: `drawRect:` composites with `NSCompositingOperationCopy`. With a
fraction below 1 that writes partly transparent pixels into a transparent window,
which is what the fork relies on — but it should be *measured* at a few opacities
rather than assumed, because Copy and SourceOver differ exactly here.

### 2.2 Flee — ferlor-BSG

A third mode beside following: the cat runs **away** from the pointer.

```objc
const CGFloat NekoFleeEnterRadius = 160.0f;
const CGFloat NekoFleeExitRadius  = 176.0f;
BOOL NekoShouldFlee(CGFloat distance, BOOL wasFleeing);
```

The non-obvious part, and the reason to copy rather than reinvent: **the two radii
are different**. One threshold makes a cat that dithers on the boundary, one step
in and one step out, forever. 160 in, 176 out.

**Why it belongs here.** `NekoBehaviourKey` already has *follow*, *windows* and
*roam*, the sprite machine already walks in eight directions, and `beside.m`
already measures approach distances. Fleeing is a fourth value of a setting that
exists, and it is a genuinely different animal to live with.

**Cost**: small, and it has a natural test — the pointer walks at the cat, and the
distance must never fall below the entry radius for more than a tick or two.

**Their extra**: when cornered, an away-vector constrained to the visible frames,
with a fallback direction so the cat does not push into a wall forever.

### 2.3 Clamp to a screen, not to the bounding box — ferlor-BSG

`nekoBounds` here unions every screen's `visibleFrame` and treats the result as
the room:

```objc
bounds = NSIsEmptyRect(bounds) ? [screen visibleFrame]
                               : NSUnionRect(bounds, [screen visibleFrame]);
```

With two displays of different heights, or an L-shaped arrangement, that union
contains rectangles **where there is no screen at all**. The cat can walk into the
void and sit there.

They keep the frames as a list instead — `NekoClampOriginToVisibleFrames(origin,
size, visibleFrames, fallback)` — and clamp to the nearest real one, measuring the
squared distance from the point to each rectangle.

**Why it belongs here.** It is a bug, not a feature, and it is the one thing in
any of these forks that this repository gets **worse** than a sibling. It needs a
staged test with two fake frames rather than a second monitor.

### 2.4 Two characters that are missing — andreaponza

Of their five, three are already here (`Dog`, `Tomoyo`, `Tora`). **`bsd`** (the
BSD daemon) and **`Buddy`** are not. Sprite sets in the oneko family, and this app
reads `.nekochar` folders — half an hour, no code.

## 3. Not worth taking

| what | why not |
| --- | --- |
| **Several cats at once** (oO0oO0oO0o0o00) — extra panels each following the pointer at an offset | The whole design here is *one* animal with a diary, a mood, a rate of speaking and a voice. Two of them is two of those, or one puppet — and this app already refuses to have a plugin make the cat speak. If ever: mute followers that cannot talk, and that is a different program |
| **Swift/SwiftUI rewrite, ARC, AppDelegate** (oO0oO0oO0o0o00, ggppjj, sgrankin) | This is 20 000 lines of MRR Objective-C with 24 harnesses against it. A rewrite buys nothing a user can see |
| **Xcode project modernisation** | There is no Xcode project here. `build.sh` is 200 lines and signs, seeds plugins and produces an arm64 slice |
| **Mirrored cursor** (Inokinoki, naoyasugioka) | A gimmick — the cat runs to the opposite corner. Flee is the same idea done properly |
| **Direction-aware wall scratching** (vonkow) | Already here: `blockedWallState` picks the togi pose from the wall it reached |
| **Sprites replaced with a logo** (akshat-khare) | This is what `.nekochar` is for. Their fork is what a plugin would be here |
| **Point-symmetry rendering, DMG, signing, login item** | All present, most of them better |

## 4. In order, if any of it happens

1. **The screen clamp** (2.3). A bug, small, and the only place a sibling is ahead.
2. **Fading near the pointer** (2.1). One setting, and it finishes an argument this
   app started in 2.2.
3. **Flee** (2.2). A fourth behaviour, an afternoon, and the hysteresis copied
   rather than rediscovered.
4. **BSD and Buddy** (2.4). Free.

And one that came from the same fork but does not fit as written: **placing the
cat by dragging it**. `MyPanel` sets `setIgnoresMouseEvents:YES` on purpose — the
cat is not a control, and clicking through it is why it can live on top of
everything. The idea underneath is still good: *stay there*. In this app's own
idiom that is a menu item, pinning it where it stands and remembering the spot,
with no mouse handling at all.
