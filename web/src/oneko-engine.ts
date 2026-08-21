/**
 * oneko engine, framework agnostic.
 *
 * A TypeScript port of oneko.js (https://github.com/adryd325/oneko.js,
 * MIT, Copyright 2022 adryd) with the features the macOS Neko app grew:
 * every bundled character, a live character swap, 1x/2x scale, an
 * adjustable speed, a pause switch and an idle-sleep switch.
 *
 * It touches the DOM only from `start()`, so importing it during
 * server side rendering is safe.
 */

import {
  ONEKO_CHARACTERS_BY_ID,
  ONEKO_DEFAULT_CHARACTER_ID,
  type OnekoCharacterId,
} from './oneko-characters';

/** Side of one sprite cell, in CSS pixels. */
export const ONEKO_CELL = 32;

/** The sprite sheet is an 8x4 grid of cells. */
export const ONEKO_SHEET_COLUMNS = 8;
export const ONEKO_SHEET_ROWS = 4;

/** One animation step. oneko.js runs at 10 frames per second. */
const TICK_MS = 100;

/**
 * Cell coordinates of every animation, as multiples of a cell. They are
 * negative because they are used as CSS background offsets.
 */
export const ONEKO_SPRITE_SETS = {
  idle: [[-3, -3]],
  alert: [[-7, -3]],
  scratchSelf: [
    [-5, 0],
    [-6, 0],
    [-7, 0],
  ],
  scratchWallN: [
    [0, 0],
    [0, -1],
  ],
  scratchWallS: [
    [-7, -1],
    [-6, -2],
  ],
  scratchWallE: [
    [-2, -2],
    [-2, -3],
  ],
  scratchWallW: [
    [-4, 0],
    [-4, -1],
  ],
  tired: [[-3, -2]],
  sleeping: [
    [-2, 0],
    [-2, -1],
  ],
  N: [
    [-1, -2],
    [-1, -3],
  ],
  NE: [
    [0, -2],
    [0, -3],
  ],
  E: [
    [-3, 0],
    [-3, -1],
  ],
  SE: [
    [-5, -1],
    [-5, -2],
  ],
  S: [
    [-6, -3],
    [-7, -2],
  ],
  SW: [
    [-5, -3],
    [-6, -1],
  ],
  W: [
    [-4, -2],
    [-4, -3],
  ],
  NW: [
    [-1, 0],
    [-1, -1],
  ],
} as const;

export type OnekoSpriteName = keyof typeof ONEKO_SPRITE_SETS;

/** The idle animations the cat can pick on its own. */
type OnekoIdleAnimation = Extract<
  OnekoSpriteName,
  'sleeping' | 'scratchSelf' | 'scratchWallN' | 'scratchWallS' | 'scratchWallE' | 'scratchWallW'
>;

/** A direction the cat can walk in. */
type OnekoDirection = Extract<OnekoSpriteName, 'N' | 'NE' | 'E' | 'SE' | 'S' | 'SW' | 'W' | 'NW'>;

export interface OnekoOptions {
  /** Which character to wear. Defaults to the classic cat. */
  characterId: OnekoCharacterId;
  /** Folder the sprite sheets are served from, without a trailing slash. */
  assetsPath: string;
  /** Points the cat covers per animation step. The macOS app allows 4 to 30. */
  speed: number;
  /** Points to keep between the pet and the pointer. 0 sits on the cursor. */
  stopRadius: number;
  /** 1 draws the sprites at their native 32px, 2 doubles them. */
  scale: number;
  /** Whether the cat is allowed to fall asleep when it has nothing to chase. */
  idleSleep: boolean;
  /** A paused cat is hidden and stops animating. */
  paused: boolean;
  /** Stay away when the visitor asked for reduced motion. */
  respectReducedMotion: boolean;
  /** Stacking order of the sprite. */
  zIndex: number;
  /** Where the cat waits before the pointer first moves. */
  startPosition: { x: number; y: number };
}

const DEFAULTS: OnekoOptions = {
  characterId: ONEKO_DEFAULT_CHARACTER_ID,
  assetsPath: 'assets/oneko',
  speed: 13,
  stopRadius: 48,
  scale: 1,
  idleSleep: true,
  paused: false,
  respectReducedMotion: true,
  zIndex: 2147483647,
  startPosition: { x: 32, y: 32 },
};

export class OnekoEngine {
  private options: OnekoOptions;

  private element: HTMLDivElement | null = null;
  private frameRequest: number | null = null;
  private readonly onPointerMove = (event: PointerEvent | MouseEvent): void => {
    this.mouseX = event.clientX;
    this.mouseY = event.clientY;
  };

  private nekoX = 0;
  private nekoY = 0;
  private mouseX = 0;
  private mouseY = 0;

  private frameCount = 0;
  private idleTime = 0;
  private idleAnimation: OnekoIdleAnimation | null = null;
  private idleAnimationFrame = 0;
  private lastFrameTimestamp: number | null = null;

  /** Guards against a slow sheet download landing after another swap. */
  private pendingSheet = 0;

  constructor(options: Partial<OnekoOptions> = {}) {
    this.options = { ...DEFAULTS, ...options };
    this.options.speed = clampSpeed(this.options.speed);
    this.options.scale = clampScale(this.options.scale);
    this.options.stopRadius = clampStopRadius(this.options.stopRadius);
    this.nekoX = this.options.startPosition.x;
    this.nekoY = this.options.startPosition.y;
    this.mouseX = this.nekoX;
    this.mouseY = this.nekoY;
  }

  get running(): boolean {
    return this.element !== null;
  }

  /** Adds the sprite to the page and starts the loop. Does nothing twice. */
  start(): void {
    if (this.element !== null || !isBrowser()) {
      return;
    }
    if (this.options.respectReducedMotion && prefersReducedMotion()) {
      return;
    }

    const element = document.createElement('div');
    element.id = 'oneko';
    element.setAttribute('aria-hidden', 'true');
    element.style.position = 'fixed';
    element.style.pointerEvents = 'none';
    element.style.backgroundRepeat = 'no-repeat';
    element.style.imageRendering = 'pixelated';
    element.style.zIndex = String(this.options.zIndex);
    /* Appended to the body rather than to the host component: a transformed
       or filtered ancestor would become the containing block of a fixed
       element and the cat would stop following the real cursor. */
    document.body.appendChild(element);
    this.element = element;

    this.applyScale();
    this.applyCharacter();
    this.applyPaused();
    this.setSprite('idle', 0);
    this.move();

    document.addEventListener('pointermove', this.onPointerMove, { passive: true });
    this.requestFrame();
  }

  /** Removes the sprite and every listener. The instance can be started again. */
  destroy(): void {
    if (this.frameRequest !== null) {
      cancelAnimationFrame(this.frameRequest);
      this.frameRequest = null;
    }
    if (isBrowser()) {
      document.removeEventListener('pointermove', this.onPointerMove);
    }
    this.element?.remove();
    this.element = null;
    this.lastFrameTimestamp = null;
  }

  /** Applies whichever options changed, while running or not. */
  update(options: Partial<OnekoOptions>): void {
    const previous = this.options;
    this.options = { ...previous, ...options };
    this.options.speed = clampSpeed(this.options.speed);
    this.options.scale = clampScale(this.options.scale);
    this.options.stopRadius = clampStopRadius(this.options.stopRadius);

    if (this.options.scale !== previous.scale) {
      this.applyScale();
    }
    if (this.options.characterId !== previous.characterId) {
      this.applyCharacter();
    }
    if (this.options.paused !== previous.paused) {
      this.applyPaused();
    }
    if (!this.options.idleSleep && this.idleAnimation === 'sleeping') {
      this.resetIdleAnimation();
    }
  }

  setCharacter(characterId: OnekoCharacterId): void {
    this.update({ characterId });
  }

  setPaused(paused: boolean): void {
    this.update({ paused });
  }

  /** Absolute URL of the sheet a character is drawn from. */
  sheetUrl(characterId: OnekoCharacterId = this.options.characterId): string {
    const character = ONEKO_CHARACTERS_BY_ID[characterId];
    return `${this.options.assetsPath}/${character.sheet}`;
  }

  private applyScale(): void {
    const { scale } = this.options;
    const element = this.element;
    if (element === null) {
      return;
    }
    element.style.width = `${ONEKO_CELL * scale}px`;
    element.style.height = `${ONEKO_CELL * scale}px`;
    element.style.backgroundSize = `${ONEKO_CELL * ONEKO_SHEET_COLUMNS * scale}px ${
      ONEKO_CELL * ONEKO_SHEET_ROWS * scale
    }px`;
    this.move();
  }

  /**
   * Swaps the sheet only once the new one has decoded, so a character change
   * never flashes an empty square.
   */
  private applyCharacter(): void {
    const element = this.element;
    if (element === null) {
      return;
    }
    const url = this.sheetUrl();
    const token = ++this.pendingSheet;
    const image = new Image();
    image.onload = () => {
      if (token === this.pendingSheet && this.element !== null) {
        this.element.style.backgroundImage = `url('${url}')`;
      }
    };
    image.src = url;
  }

  private applyPaused(): void {
    const element = this.element;
    if (element === null) {
      return;
    }
    element.style.display = this.options.paused ? 'none' : 'block';
    if (this.options.paused) {
      if (this.frameRequest !== null) {
        cancelAnimationFrame(this.frameRequest);
        this.frameRequest = null;
      }
      this.lastFrameTimestamp = null;
    } else if (this.frameRequest === null) {
      this.requestFrame();
    }
  }

  private requestFrame(): void {
    this.frameRequest = requestAnimationFrame((timestamp) => this.onAnimationFrame(timestamp));
  }

  private onAnimationFrame(timestamp: number): void {
    const element = this.element;
    if (element === null || !element.isConnected) {
      this.frameRequest = null;
      return;
    }
    if (this.lastFrameTimestamp === null) {
      this.lastFrameTimestamp = timestamp;
    }
    if (timestamp - this.lastFrameTimestamp > TICK_MS) {
      this.lastFrameTimestamp = timestamp;
      this.tick();
    }
    this.requestFrame();
  }

  private setSprite(name: OnekoSpriteName, frame: number): void {
    const frames = ONEKO_SPRITE_SETS[name];
    const [column, row] = frames[frame % frames.length];
    const step = ONEKO_CELL * this.options.scale;
    if (this.element !== null) {
      this.element.style.backgroundPosition = `${column * step}px ${row * step}px`;
    }
  }

  private resetIdleAnimation(): void {
    this.idleAnimation = null;
    this.idleAnimationFrame = 0;
  }

  private idle(): void {
    this.idleTime += 1;

    if (this.idleTime > 10 && Math.floor(Math.random() * 200) === 0 && this.idleAnimation === null) {
      const available: OnekoIdleAnimation[] = ['scratchSelf'];
      if (this.options.idleSleep) {
        available.push('sleeping');
      }
      if (this.nekoX < ONEKO_CELL) {
        available.push('scratchWallW');
      }
      if (this.nekoY < ONEKO_CELL) {
        available.push('scratchWallN');
      }
      if (this.nekoX > window.innerWidth - ONEKO_CELL) {
        available.push('scratchWallE');
      }
      if (this.nekoY > window.innerHeight - ONEKO_CELL) {
        available.push('scratchWallS');
      }
      this.idleAnimation = available[Math.floor(Math.random() * available.length)];
    }

    switch (this.idleAnimation) {
      case 'sleeping':
        if (this.idleAnimationFrame < 8) {
          this.setSprite('tired', 0);
          break;
        }
        this.setSprite('sleeping', Math.floor(this.idleAnimationFrame / 4));
        if (this.idleAnimationFrame > 192) {
          this.resetIdleAnimation();
        }
        break;
      case 'scratchWallN':
      case 'scratchWallS':
      case 'scratchWallE':
      case 'scratchWallW':
      case 'scratchSelf':
        this.setSprite(this.idleAnimation, this.idleAnimationFrame);
        if (this.idleAnimationFrame > 9) {
          this.resetIdleAnimation();
        }
        break;
      default:
        this.setSprite('idle', 0);
        return;
    }
    this.idleAnimationFrame += 1;
  }

  private tick(): void {
    this.frameCount += 1;
    const { speed, scale, stopRadius } = this.options;
    const diffX = this.nekoX - this.mouseX;
    const diffY = this.nekoY - this.mouseY;
    const distance = Math.sqrt(diffX ** 2 + diffY ** 2);

    /* How far there is to go before the ring the pet keeps around the pointer. */
    const travel = distance - stopRadius;
    if (travel <= 0) {
      this.idle();
      return;
    }

    this.resetIdleAnimation();

    if (this.idleTime > 1) {
      this.setSprite('alert', 0);
      this.idleTime = Math.min(this.idleTime, 7) - 1;
      return;
    }

    let direction = '';
    direction += diffY / distance > 0.5 ? 'N' : '';
    direction += diffY / distance < -0.5 ? 'S' : '';
    direction += diffX / distance > 0.5 ? 'W' : '';
    direction += diffX / distance < -0.5 ? 'E' : '';
    /* One component always exceeds 0.5 once the two are normalised, so this
       is always one of the eight directions. */
    this.setSprite(direction as OnekoDirection, this.frameCount);

    /* Capping the step by the distance left over the ring lands the pet on it
       rather than stepping across and jittering back. */
    const step = Math.min(speed, travel);
    this.nekoX -= (diffX / distance) * step;
    this.nekoY -= (diffY / distance) * step;

    const half = (ONEKO_CELL * scale) / 2;
    this.nekoX = Math.min(Math.max(half, this.nekoX), window.innerWidth - half);
    this.nekoY = Math.min(Math.max(half, this.nekoY), window.innerHeight - half);
    this.move();
  }

  private move(): void {
    const element = this.element;
    if (element === null) {
      return;
    }
    const half = (ONEKO_CELL * this.options.scale) / 2;
    element.style.left = `${this.nekoX - half}px`;
    element.style.top = `${this.nekoY - half}px`;
  }
}

function clampSpeed(speed: number): number {
  return Math.min(Math.max(Number(speed) || DEFAULTS.speed, 4), 30);
}

function clampStopRadius(radius: number): number {
  const value = Number(radius);
  return Math.min(Math.max(Number.isFinite(value) ? value : DEFAULTS.stopRadius, 0), 200);
}

function clampScale(scale: number): number {
  return Number(scale) >= 2 ? 2 : 1;
}

function isBrowser(): boolean {
  /* requestAnimationFrame is part of the test: jsdom only provides it when it
     is created with pretendToBeVisual, and without it there is no loop to run,
     so the engine stays out of the way instead of throwing. */
  return (
    typeof document !== 'undefined' &&
    typeof window !== 'undefined' &&
    typeof requestAnimationFrame === 'function'
  );
}

function prefersReducedMotion(): boolean {
  /* jsdom, which unit tests usually run in, has no matchMedia. */
  if (typeof window.matchMedia !== 'function') {
    return false;
  }
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}
