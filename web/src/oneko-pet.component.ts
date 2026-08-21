import {
  Component,
  Input,
  NgZone,
  OnChanges,
  OnDestroy,
  OnInit,
  SimpleChanges,
  inject,
} from '@angular/core';

import { ONEKO_DEFAULT_CHARACTER_ID, type OnekoCharacterId } from './oneko-characters';
import { OnekoEngine, type OnekoOptions } from './oneko-engine';

/**
 * Drops a cursor-chasing pet on the page.
 *
 * ```html
 * <oneko-pet [character]="'tora'" [scale]="2" [speed]="18" />
 * ```
 *
 * The component renders nothing itself: the sprite is a fixed element the
 * engine appends to the body, so no ancestor can turn into its containing
 * block. Put the tag anywhere that stays alive as long as you want the pet,
 * usually the app shell.
 */
@Component({
  selector: 'oneko-pet',
  standalone: true,
  template: '',
  styles: [
    `
      :host {
        display: none;
      }
    `,
  ],
})
export class OnekoPetComponent implements OnInit, OnChanges, OnDestroy {
  /** Identifier of the sprite set, e.g. `neko`, `tora`, `eevee`. */
  @Input() character: OnekoCharacterId = ONEKO_DEFAULT_CHARACTER_ID;

  /** Points covered per animation step, clamped to 4..30. */
  @Input() speed = 13;

  /** 1 for native 32px sprites, 2 to double them. */
  @Input() scale = 1;

  /** Let the pet fall asleep when it has nothing to chase. */
  @Input() idleSleep = true;

  /** Hides the pet and stops the loop. */
  @Input() paused = false;

  /** Folder the sprite sheets are served from, no trailing slash. */
  @Input() assetsPath = 'assets/oneko';

  /** Stay away from visitors who asked for reduced motion. */
  @Input() respectReducedMotion = true;

  private readonly zone = inject(NgZone);
  private engine: OnekoEngine | null = null;

  ngOnInit(): void {
    /* The loop runs every animation frame; keeping it out of the Angular zone
       stops it from triggering change detection 60 times a second. */
    this.zone.runOutsideAngular(() => {
      this.engine = new OnekoEngine({
        characterId: this.character,
        assetsPath: this.assetsPath,
        speed: Number(this.speed),
        scale: Number(this.scale),
        idleSleep: this.idleSleep,
        paused: this.paused,
        respectReducedMotion: this.respectReducedMotion,
      });
      this.engine.start();
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
    const engine = this.engine;
    if (engine === null) {
      return; /* the first change detection pass runs before ngOnInit */
    }
    const update: Partial<OnekoOptions> = {};
    if (changes['character']) {
      update.characterId = this.character;
    }
    if (changes['speed']) {
      update.speed = Number(this.speed);
    }
    if (changes['scale']) {
      update.scale = Number(this.scale);
    }
    if (changes['idleSleep']) {
      update.idleSleep = this.idleSleep;
    }
    if (changes['paused']) {
      update.paused = this.paused;
    }
    if (changes['assetsPath']) {
      update.assetsPath = this.assetsPath;
    }
    if (Object.keys(update).length > 0) {
      this.zone.runOutsideAngular(() => engine.update(update));
    }
  }

  ngOnDestroy(): void {
    this.engine?.destroy();
    this.engine = null;
  }
}
