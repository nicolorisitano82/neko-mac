import { Injectable, NgZone, OnDestroy, inject } from '@angular/core';

import { ONEKO_DEFAULT_CHARACTER_ID, type OnekoCharacterId } from './oneko-characters';
import { OnekoEngine, type OnekoOptions } from './oneko-engine';

/**
 * The same pet, without a tag in a template. Handy when a setting somewhere
 * else in the app decides whether the pet exists.
 *
 * ```ts
 * private readonly oneko = inject(OnekoService);
 * this.oneko.spawn({ characterId: 'sakura', scale: 2 });
 * this.oneko.setCharacter('dog');
 * this.oneko.despawn();
 * ```
 */
@Injectable({ providedIn: 'root' })
export class OnekoService implements OnDestroy {
  private readonly zone = inject(NgZone);
  private engine: OnekoEngine | null = null;

  get running(): boolean {
    return this.engine?.running ?? false;
  }

  spawn(options: Partial<OnekoOptions> = {}): void {
    if (this.engine !== null) {
      this.engine.update(options);
      return;
    }
    this.zone.runOutsideAngular(() => {
      this.engine = new OnekoEngine({ characterId: ONEKO_DEFAULT_CHARACTER_ID, ...options });
      this.engine.start();
    });
  }

  despawn(): void {
    this.engine?.destroy();
    this.engine = null;
  }

  update(options: Partial<OnekoOptions>): void {
    this.engine?.update(options);
  }

  setCharacter(characterId: OnekoCharacterId): void {
    this.engine?.setCharacter(characterId);
  }

  setPaused(paused: boolean): void {
    this.engine?.setPaused(paused);
  }

  ngOnDestroy(): void {
    this.despawn();
  }
}
