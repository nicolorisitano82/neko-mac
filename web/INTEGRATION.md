# Adding Neko to an existing Angular app

A step by step guide for dropping the cursor-chasing pet into an app that
already exists. Roughly ten minutes, no dependencies, no build changes beyond
one assets entry.

For what the code actually does, see [README.md](README.md).

## What you are adding

| | |
|---|---|
| Code | 4 TypeScript files, ~890 lines, no runtime dependencies |
| Assets | 28 PNG sprite sheets, 372 KB in total, one loaded at a time |
| Build impact | one `assets` entry in `angular.json` |
| Angular | 15 or newer (standalone components; on 14 they were a developer preview) |

The engine itself imports nothing from Angular, so if you later move to another
framework only `oneko-pet.component.ts` and `oneko.service.ts` are thrown away.

## 1. Copy the files

```sh
# from the root of this repository, with YOUR_APP pointing at the Angular project
cp -R web/src YOUR_APP/src/app/oneko
cp -R web/assets/oneko YOUR_APP/src/assets/oneko
```

You end up with:

```
src/app/oneko/
    index.ts
    oneko-characters.ts      generated, see step 6
    oneko-engine.ts
    oneko-pet.component.ts
    oneko.service.ts
src/assets/oneko/
    ace.png … vaporwave.png
```

Shipping all 28 characters is optional. Delete the sheets you do not want and
regenerate the registry (step 6) so the type union only offers what exists.

## 2. Make sure the sheets are served

Most Angular apps already copy `src/assets` wholesale, in which case there is
nothing to do. Check `angular.json` for the build target:

```json
"assets": [
  { "glob": "**/*", "input": "src/assets", "output": "assets" }
]
```

Newer workspaces use `"assets": ["src/assets"]`, which is equivalent. If the app
lists assets file by file, add the folder:

```json
"assets": [
  "src/favicon.ico",
  { "glob": "**/*", "input": "src/assets/oneko", "output": "assets/oneko" }
]
```

Then confirm it, because a missing asset shows up as an invisible pet and
nothing else:

```sh
ng serve
curl -I http://localhost:4200/assets/oneko/neko.png   # expect 200
```

## 3. Put the pet on the page

Pick whichever of these matches the app.

### Standalone app shell

```ts
import { Component } from '@angular/core';
import { OnekoPetComponent } from './oneko';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, OnekoPetComponent],
  template: `
    <router-outlet />
    <oneko-pet />
  `,
})
export class AppComponent {}
```

### An app still using NgModules

A standalone component goes straight into a module's `imports`:

```ts
@NgModule({
  declarations: [AppComponent],
  imports: [BrowserModule, OnekoPetComponent],
  bootstrap: [AppComponent],
})
export class AppModule {}
```

```html
<!-- app.component.html -->
<oneko-pet character="tora" [scale]="2" />
```

### No template at all

When a setting elsewhere decides whether the pet exists:

```ts
import { Component, inject, OnInit } from '@angular/core';
import { OnekoService } from './oneko';

@Component({ /* … */ })
export class AppComponent implements OnInit {
  private readonly oneko = inject(OnekoService);

  ngOnInit(): void {
    if (this.settings.petEnabled) {
      this.oneko.spawn({ characterId: 'sakura', scale: 2 });
    }
  }
}
```

`OnekoService` is `providedIn: 'root'` and despawns itself when the root
injector is destroyed.

Put the tag in a component that lives as long as you want the pet. In a page
component it disappears on navigation, which is a fine thing to want, just not
usually the intent.

## 4. Check it is working

Open the app and look for these four things. Each failure has a single cause.

| Check | Where | If it fails |
|---|---|---|
| A `<div id="oneko">` exists at the end of `<body>` | Elements panel | the component never initialised, or reduced motion is on, see the table in step 7 |
| Its `background-image` points at a sheet | Elements panel | wrong `assetsPath` |
| That sheet returned 200 | Network panel | step 2 |
| It walks towards the pointer | the page | see step 7 |

Note that the element is appended to `document.body`, not inside the component.
That is deliberate: a `position: fixed` element inside an ancestor with
`transform` or `filter` is positioned against that ancestor instead of the
viewport, and the pet would drift away from the real cursor.

## 5. The settings from the macOS app

Every preference the desktop version exposes is an input:

```html
<oneko-pet
  [character]="character"
  [speed]="speed"
  [scale]="scale"
  [idleSleep]="idleSleep"
  [paused]="paused"
  assetsPath="assets/oneko"
/>
```

A picker plus a remembered choice, which is what the macOS menu bar item does:

```ts
import { Component, signal, effect } from '@angular/core';
import {
  ONEKO_CHARACTERS,
  ONEKO_DEFAULT_CHARACTER_ID,
  OnekoPetComponent,
  type OnekoCharacterId,
} from './oneko';

const STORAGE_KEY = 'oneko.character';

@Component({
  selector: 'app-pet-settings',
  standalone: true,
  imports: [OnekoPetComponent],
  template: `
    <select (change)="choose($any($event.target).value)">
      @for (character of characters; track character.id) {
        <option [value]="character.id" [selected]="character.id === current()">
          {{ character.name }}
        </option>
      }
    </select>
    <oneko-pet [character]="current()" />
  `,
})
export class PetSettingsComponent {
  readonly characters = ONEKO_CHARACTERS;
  readonly current = signal<OnekoCharacterId>(
    (localStorage.getItem(STORAGE_KEY) as OnekoCharacterId | null) ?? ONEKO_DEFAULT_CHARACTER_ID,
  );

  constructor() {
    effect(() => localStorage.setItem(STORAGE_KEY, this.current()));
  }

  choose(id: OnekoCharacterId): void {
    this.current.set(id);
  }
}
```

Signals need Angular 16, and the `@for` block needs 17. On older versions use a
plain field and `*ngFor`, or `[(ngModel)]` with `FormsModule`.

`ONEKO_CHARACTERS` also carries `author` and `licence` per character, which is
handy if the picker should credit them.

## 6. Regenerating the registry

`oneko-characters.ts` is generated from the macOS app's character folders, so
the two versions cannot drift. After adding, removing or renaming a character:

```sh
python3 tools/char2sheet.py --all Resources/Characters web/assets/oneko \
        --registry web/src/oneko-characters.ts
```

Then copy the file and the sheets over again. Editing the registry by hand works
until the next regeneration overwrites it.

To add a character that only exists as an oneko.js sheet, import it into the
macOS app first with `tools/sheet2char.py` and regenerate — that way one list
feeds both versions.

## 7. When something is off

| Symptom | Cause | Fix |
|---|---|---|
| No `#oneko` element at all | the visitor has *Reduce motion* on, and the engine stays away by design | `[respectReducedMotion]="false"` if the pet is the point of the page |
| Element exists, invisible | sheet 404 | fix the assets entry, then check `assetsPath` |
| Pet lags behind the cursor by a constant offset | an ancestor `transform` — should not happen, the element lives on `body`, but a global CSS rule targeting `body > div` can do it | scope that rule, or set a different `zIndex` |
| Pet hidden behind app chrome | another element with `z-index: 2147483647` | lower `zIndex` and raise it above your chrome only |
| Pet does not move in a background tab | browsers pause `requestAnimationFrame` in hidden tabs | expected, it resumes on focus |
| `matchMedia is not a function` in unit tests | jsdom has no `matchMedia` in either mode | already guarded in the engine; keep the guard if you patch it |
| Change detection runs constantly | the loop was started inside the Angular zone | keep the `runOutsideAngular` wrapper in the component or service |
| Blocked by CSP | the sheet is loaded as a background image | allow the asset origin in `img-src` |
| Deployed under a subpath and the sheet 404s | relative URLs resolve against the document | set `assetsPath` to the full path, e.g. `/app/assets/oneko`, or a CDN URL |

## 8. Tests

Measured, so you can decide how much to mock:

| Environment | `requestAnimationFrame` | `matchMedia` | What the engine does |
|---|---|---|---|
| jsdom, as created by default | missing | missing | does not start: no element, no error |
| jsdom with `pretendToBeVisual` | present | missing | starts and appends the element, never paints |
| a real browser (Karma, Playwright) | present | present | runs for real |

A missing `requestAnimationFrame` is treated as "not a browser", and
`matchMedia` is only called when it exists, so no environment needs a mock or a
polyfill. Under jsdom the pet stays where it started, because nothing is driving
the frames.

`start()` appends to `document.body`, which survives between tests in the same
file. `fixture.destroy()` removes it, and `TestBed` calls that for you when the
component is destroyed.

To keep the pet out of a test entirely, override the service:

```ts
TestBed.configureTestingModule({
  imports: [AppComponent],
  providers: [{ provide: OnekoService, useValue: { spawn: () => {}, despawn: () => {} } }],
});
```

## 9. Server side rendering

Nothing to do. `start()` needs a `document`, a `window` and a
`requestAnimationFrame` before it touches anything, so it is a no-op on the
server — so the pet appears once the browser
takes over. If you prefer to be explicit on Angular 17 or newer, spawn from
`afterNextRender` instead of `ngOnInit`.

## 10. Removing it

Delete `src/app/oneko`, delete `src/assets/oneko`, drop the tag and the
`angular.json` entry. Nothing else in the app is touched — there are no global
styles, no providers to unregister and no polyfills.

## Licences

The engine is a port of [oneko.js](https://github.com/adryd325/oneko.js), MIT,
Copyright 2022 adryd. The sprites do not share one licence: the oneko animals
are public domain, Sakura and Tomoyo derive from Card Captor Sakura artwork, and
the oneko.js skins come from community collections that state none. Each
character's provenance travels with it in the registry. Ship only what you are
comfortable shipping.
