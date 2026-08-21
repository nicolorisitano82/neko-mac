# Neko on the web

A TypeScript port of [oneko.js](https://github.com/adryd325/oneko.js) that wears
every character the macOS app ships, packaged for Angular.

```
web/
  src/oneko-characters.ts     generated registry of the 28 characters
  src/oneko-engine.ts         the animation, no framework involved
  src/oneko-pet.component.ts  standalone Angular component
  src/oneko.service.ts        the same pet, driven from code
  src/index.ts                barrel
  assets/oneko/<id>.png       one 256x128 sprite sheet per character
```

Dropping this into an app that already exists is written up separately, with the
build changes, the recipes and the failure modes: [INTEGRATION.md](INTEGRATION.md).

## Installing it in an Angular app

1. Copy `web/src` into the project, say `src/app/oneko`.
2. Copy `web/assets/oneko` into the app's assets folder.
3. Make sure the assets are served. In `angular.json`:

```json
"assets": [
  { "glob": "**/*", "input": "src/assets", "output": "assets" }
]
```

4. Drop the component into a component that lives as long as you want the pet,
   usually the app shell:

```ts
import { Component } from '@angular/core';
import { OnekoPetComponent } from './oneko';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [OnekoPetComponent],
  template: `
    <router-outlet />
    <oneko-pet character="tora" [scale]="2" [speed]="18" />
  `,
})
export class AppComponent {}
```

The component renders nothing. The sprite is a `position: fixed` element the
engine appends to `document.body`, because a transformed or filtered ancestor
would otherwise become its containing block and the pet would drift away from
the real cursor.

### Inputs

| Input | Default | |
|---|---|---|
| `character` | `'neko'` | identifier from `ONEKO_CHARACTER_IDS` |
| `speed` | `13` | points per animation step, clamped to 4..30 |
| `stopRadius` | `48` | points to keep between the pet and the pointer, 0..200 |
| `scale` | `1` | `1` for native 32px sprites, `2` to double them |
| `idleSleep` | `true` | let the pet fall asleep when idle |
| `paused` | `false` | hide it and stop the loop |
| `assetsPath` | `'assets/oneko'` | where the sheets are served from |
| `respectReducedMotion` | `true` | stay away under `prefers-reduced-motion` |

### A picker

`ONEKO_CHARACTERS` carries the name and the provenance of each sheet, so a
selector is a one-liner:

```ts
readonly characters = ONEKO_CHARACTERS;
current: OnekoCharacterId = ONEKO_DEFAULT_CHARACTER_ID;
```

```html
<select [(ngModel)]="current">
  <option *ngFor="let c of characters" [value]="c.id">{{ c.name }}</option>
</select>
<oneko-pet [character]="current" />
```

### Without a template

```ts
private readonly oneko = inject(OnekoService);

ngOnInit(): void {
  this.oneko.spawn({ characterId: 'sakura', scale: 2 });
}
```

## Notes

* **Change detection.** The loop runs inside `NgZone.runOutsideAngular`, so 60
  animation frames a second do not trigger 60 change detection passes.
* **Server side rendering.** The engine touches the DOM only in `start()`, and
  only once a `document`, a `window` and a `requestAnimationFrame` all exist, so
  importing it on the server, or in a DOM-less test, is harmless.
* **No bundler?** The imports are extensionless, which is what the Angular
  compiler and every bundler expect. Loading the compiled files straight into a
  browser as ES modules needs `.js` added to the import specifiers.
* **Sheet format.** 256x128 PNG, an 8x4 grid of 32x32 cells, the oneko.js
  layout, so any skin written for oneko.js drops in unchanged.

## Regenerating the sheets and the registry

The sheets and `oneko-characters.ts` are built from the macOS app's character
folders, so the two versions cannot drift:

```sh
python3 tools/char2sheet.py --all Resources/Characters web/assets/oneko \
        --registry web/src/oneko-characters.ts
```

Packing `Neko.nekochar` reproduces oneko.js' own `oneko.gif` pixel for pixel,
and packing the imported skins reproduces the sheets they were sliced from, which
is what keeps the cell layout honest. `--verify SHEET` runs that comparison.

## Licence

The engine is a port of oneko.js, MIT, Copyright 2022 adryd. The sprites keep
the provenance recorded in each character's `character.plist` and in the
registry: the oneko animals are public domain, Sakura and Tomoyo derive from
Card Captor Sakura artwork, and the oneko.js skins come from community
collections that state no licence. Check that before shipping them.
