#import "MyPanel.h"
#import "NekoController.h"
#import "NekoAsk.h"
#import "NekoAdvisor.h"

@implementation MyPanel
- (void)setStateTo:(NekoState)theState
{
	if(stateFrames != nil && nekoState == theState)
		return;
	//printf("state %d\n", theState);
	tickCount = 0;
	stateCount = 0;
	nekoState = theState;
	[stateFrames release];
	stateFrames = [[character framesForState:theState] retain];
	stateTicksPerFrame = [character ticksPerFrameForState:theState];
	[view setNeedsDisplay:YES];
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)styleMask backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
	self = [super initWithContentRect:contentRect styleMask:NSWindowStyleMaskBorderless backing:bufferingType defer:deferCreation];
	[self setBecomesKeyOnlyIfNeeded:YES];
	[self setLevel:NSStatusWindowLevel];
	/* Belonging to a Space is a property of the window, not of where it is on
	   screen, and a window that says nothing belongs to the one it was born in:
	   a three finger swipe left the cat stranded on the previous desktop. The
	   same four flags the Dock and the menu bar extras use — present everywhere,
	   not dragged along by the switching animation, out of the way of window
	   cycling, and allowed to share a full screen app's Space.

	   Two displays were never the same problem: screens are geometry, and the
	   cat crossing a display border stays in the Space it was already in. */
	[self setCollectionBehavior:(NSWindowCollectionBehaviorCanJoinAllSpaces
	                             | NSWindowCollectionBehaviorStationary
	                             | NSWindowCollectionBehaviorIgnoresCycle
	                             | NSWindowCollectionBehaviorFullScreenAuxiliary)];
	[self setOpaque:NO];
	[self setCanHide:NO];
	[self setIgnoresMouseEvents:YES];
	[self setMovableByWindowBackground:NO];
	[self setFrame:NSMakeRect(0.0f, 0.0f, 32.0f, 32.0f) display:NO];
	[self center];
	[self setBackgroundColor:[NSColor clearColor]];
	
	speed = 13.0f;
	scale = 1.0f;
	stopRadius = 48.0f;
	idleSleep = YES;
	
	[self startTimer];
	return self;
}

- (void)awakeFromNib
{
	NekoController *controller = [NekoController sharedController];
	[controller setPanel:self];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                        selector:@selector(settingsDidChange:)
	                                            name:NekoSettingsDidChangeNotification
	                                          object:nil];
	[self applySettings];
}

- (void)startTimer
{
	if(myTimer != nil)
		return;
	myTimer = [NSTimer scheduledTimerWithTimeInterval:0.125f target:self selector:@selector(handleTimer:) userInfo:nil repeats:YES];
}

- (void)stopTimer
{
	[myTimer invalidate];
	myTimer = nil;
}

- (void)settingsDidChange:(NSNotification*)notification
{
	[self applySettings];
}

/* Resizes the window around its own centre so swapping character or size does
   not make the cat drift across the screen. */
- (void)setSpriteSide:(float)side
{
	NSRect frame = [self frame];
	if(frame.size.width == side && frame.size.height == side)
		return;
	frame.origin.x += floor((frame.size.width - side) / 2.0f);
	frame.origin.y += floor((frame.size.height - side) / 2.0f);
	frame.size = NSMakeSize(side, side);
	[self setFrame:frame display:YES];
}

- (void)applySettings
{
	NekoController *controller = [NekoController sharedController];
	speed = [controller speed];
	scale = [controller scale];
	stopRadius = [controller stopRadius];
	idleSleep = [controller idleSleep];
	windowsMode = [controller livesOnWindowEdges];
	roamMode = [controller roamsOnItsOwn];
	wanderEnabled = [controller wandersWhenIdle];
	if(!wanderEnabled && !windowsMode && !roamMode)
		wandering = NO;
	if(!roamMode) {
		roamTicks = 0;
		errandPhase = 0;
	}
	shelvesAge = 0;
	
	NekoCharacter *newCharacter = [controller character];
	if(newCharacter != character) {
		[character release];
		character = [newCharacter retain];
		[stateFrames release];
		stateFrames = nil;             /* forces setStateTo: to reload */
		[self setStateTo:NekoStateStop];
	}
	
	/* Sprites are square in every character shipped so far; the larger side
	   drives the window so a non-square one is letterboxed instead of cropped. */
	/* A missing character would otherwise size the window to nothing. */
	NSSize sprite = (character != nil) ? [character spriteSize] : NSMakeSize(32.0f, 32.0f);
	float side = MAX(MAX(sprite.width, sprite.height), 8.0f) * scale;
	[self setSpriteSide:side];
	[view setFrame:[[self contentView] bounds]];
	[view setNeedsDisplay:YES];
	
	if([controller isPaused]) {
		[self stopTimer];
		[self orderOut:nil];
	} else {
		if(![self isVisible])
			[self orderFront:nil];
		[self startTimer];
	}
}

/* The eight walking states, which several decisions turn on. */
- (BOOL)isWalking
{
	return nekoState == NekoStateUMove || nekoState == NekoStateDMove
	    || nekoState == NekoStateLMove || nekoState == NekoStateRMove
	    || nekoState == NekoStateULMove || nekoState == NekoStateURMove
	    || nekoState == NekoStateDLMove || nekoState == NekoStateDRMove;
}

#pragma mark Being held

- (void)holdWithState:(NekoState)state
{
	held = YES;
	[self setStateTo:state];
	[self startTimer];           /* the frames keep moving even while it waits */
}

- (void)releaseHold
{
	held = NO;
	restedTicks = 0;
}

- (BOOL)isHeld
{
	return held;
}

/* Roaming, in ticks of an eighth of a second: a couple of seconds' pause
   between errands, and five minutes of that before the cat has earned a nap. */
static const unsigned NekoRoamMinRest = 8;       /* one second */
static const unsigned NekoRoamRestSpread = 24;   /* up to four */
static const unsigned NekoRoamBeforeNap = 2400;  /* five minutes */
static const unsigned NekoRoamNap = 240;         /* half a minute asleep */

#pragma mark Wandering

/* Somewhere else on the desk, a few sprites away, pointing away from wherever
   the pointer is: a cat that has been left alone drifts off, it does not circle
   the cursor it just gave up on. */
- (void)startWanderingAwayFromPointer
{
	NSRect bounds = [self nekoBounds];
	NSRect frame = [self frame];
	NSPoint mouse = [NSEvent mouseLocation];

	double away = atan2(NSMinY(frame) - mouse.y, NSMidX(frame) - mouse.x);
	if(isnan(away))
		away = (double)arc4random_uniform(360) * M_PI / 180.0;
	/* within a third of a turn either side of straight away */
	away += ((double)arc4random_uniform(120) - 60.0) * M_PI / 180.0;
	float reach = 150.0f + (float)arc4random_uniform(200);

	wanderTarget = NSMakePoint(NSMidX(frame) + reach * cos(away),
	                           NSMinY(frame) + reach * sin(away));
	wanderTarget.x = MIN(MAX(wanderTarget.x, NSMinX(bounds) + frame.size.width),
	                     NSMaxX(bounds) - frame.size.width);
	wanderTarget.y = MIN(MAX(wanderTarget.y, NSMinY(bounds)),
	                     NSMaxY(bounds) - frame.size.height);
	wanderMouse = mouse;
	wandering = YES;
}

/* In the other behaviour the cat picks one of your window tops, or the desk,
   and goes to sit on it. The pointer has no say. */
- (void)startWanderingOntoShelf
{
	NSRect bounds = [self nekoBounds];
	NSRect frame = [self frame];
	NSMutableArray *surfaces = [NSMutableArray arrayWithArray:shelves];
	if([surfaces count] == 0)
		[surfaces addObject:[NSValue valueWithRect:NSMakeRect(
			NSMinX(bounds), NSMinY(bounds), bounds.size.width, 1.0f)]];  /* the desk */

	NSRect surface = [[surfaces objectAtIndex:arc4random_uniform([surfaces count])] rectValue];
	float room = surface.size.width - frame.size.width;
	float x = NSMinX(surface) + (room > 0.0f ? (float)arc4random_uniform((unsigned)room) : 0.0f);

	wanderTarget = NSMakePoint(x + frame.size.width / 2.0f, surface.origin.y);
	wanderMouse = [NSEvent mouseLocation];
	wandering = YES;
}

/* Roaming: anywhere on the desk at all. The pointer is not a destination and
   not a repellent — this cat is going about its own business, and where you
   happen to be pointing is none of it. */
- (void)startWanderingAnywhere
{
	NSRect bounds = [self nekoBounds];
	NSRect frame = [self frame];
	float roomX = MAX(bounds.size.width - frame.size.width, 1.0f);
	float roomY = MAX(bounds.size.height - frame.size.height, 1.0f);
	NSPoint here = NSMakePoint(NSMidX(frame), NSMinY(frame));

	/* A worthwhile walk rather than a shuffle: somewhere at least a third of
	   the desk away, given a few tries to find one. Uniform points came out
	   next door often enough that the cat looked like it could not decide. */
	float wanted = MIN(bounds.size.width, bounds.size.height) / 3.0f;
	NSPoint spot = here;
	unsigned try;
	for(try = 0; try < 8; try++) {
		spot = NSMakePoint(NSMinX(bounds) + frame.size.width / 2.0f
		                   + (float)arc4random_uniform((unsigned)roomX),
		                   NSMinY(bounds) + (float)arc4random_uniform((unsigned)roomY));
		if(hypotf(spot.x - here.x, spot.y - here.y) >= wanted)
			break;
	}

	wanderTarget = spot;
	wanderMouse = [NSEvent mouseLocation];
	wandering = YES;
}

- (void)stopWandering
{
	wandering = NO;
}

/* Chasing the pointer: it drifts off only after having properly settled and
   slept, about half a minute of being left alone. Living on windows: it moves
   between them whenever it has sat still long enough. */
/* A bubble on screen pins the cat: whatever it was going to do, being read
   comes first. In-place animations carry on — it can sit, wash, yawn — but the
   walking states, the wandering and the errands all wait, and if the bubble
   comes back the cat stops again. */
- (BOOL)isSpeaking
{
	NekoAsk *ask = [NekoAsk sharedAsk];
	/* Three states, one rule: a bubble on screen, a question being handled —
	   listening, thinking, drawing — or a suggestion being written. All of them
	   are the cat's attention being elsewhere, and a cat whose attention is
	   elsewhere does not cross the desk. */
	return [ask isSpeaking] || [ask isBusy] || [[NekoAdvisor sharedAdvisor] isThinking];
}

- (BOOL)shouldWanderNow
{
	if(wandering || [self isSpeaking])
		return NO;
	if(roamMode) {
		if(errandPhase != 0)
			return NO;                 /* it is already going somewhere */
		if(nekoState == NekoStateSleep)
			return restedTicks > NekoRoamNap;   /* nap over, back on its feet */
		if(roamTicks > NekoRoamBeforeNap)
			return NO;                 /* let the idle chain put it to sleep */
		return restedTicks > roamRest;
	}
	if(windowsMode)
		return restedTicks > 80;      /* ten seconds on a window top */
	return wanderEnabled && restedTicks > 240;   /* thirty seconds asleep */
}

- (void)beginWandering
{
	if(roamMode) {
		/* A different pause each time, so it does not tick round like a
		   metronome. */
		roamRest = NekoRoamMinRest + arc4random_uniform(NekoRoamRestSpread);
		if(nekoState == NekoStateSleep)
			roamTicks = 0;             /* the nap paid for the next five minutes */
		[self startWanderingAnywhere];
	}
	else if(windowsMode)
		[self startWanderingOntoShelf];
	else
		[self startWanderingAwayFromPointer];
	restedTicks = 0;
}

/* Sleeping is for cats that have earned it. A roamer that dozed off three
   seconds into its first pause — which is what the idle chain does — looked
   broken rather than sleepy. */
- (BOOL)mayFallAsleep
{
	if(!idleSleep)
		return NO;
	return !roamMode || roamTicks > NekoRoamBeforeNap;
}

#pragma mark Errands

- (void)errandTo:(NSPoint)point thenState:(NekoState)state forTicks:(unsigned)ticks
{
	if(!roamMode || held || [self isSpeaking])
		return;
	wanderTarget = point;
	wanderMouse = [NSEvent mouseLocation];
	wandering = YES;
	errandPhase = 1;
	errandState = state;
	errandHold = ticks;
	errandTicks = 0;
	restedTicks = 0;
	if(![self isWalking])
		[self setStateTo:NekoStateAwake];
	[self startTimer];
}

- (BOOL)isOnErrand
{
	return errandPhase != 0;
}

- (BOOL)isRoaming
{
	return roamMode;
}

/* What the cat is walking towards: the pointer, or wherever it decided to go. */
- (NSPoint)chaseTarget
{
	if(wandering)
		return wanderTarget;
	if(windowsMode || roamMode)
		return NSMakePoint(NSMidX([self frame]), NSMinY([self frame]));  /* stay put */
	return [NSEvent mouseLocation];
}

#pragma mark Walls and window edges

/* Every screen together, so the cat can follow the pointer onto another
   display instead of treating its own screen border as a wall. */
- (NSRect)nekoBounds
{
	NSRect bounds = NSZeroRect;
	NSEnumerator *e = [[NSScreen screens] objectEnumerator];
	NSScreen *screen;
	while((screen = [e nextObject]) != nil)
		bounds = NSIsEmptyRect(bounds) ? [screen visibleFrame]
		                               : NSUnionRect(bounds, [screen visibleFrame]);
	return NSIsEmptyRect(bounds) ? [[NSScreen mainScreen] visibleFrame] : bounds;
}

/* Where the Dock is, as a surface to stand on, or an empty rect when it is
   hidden. Its own Quartz window covers the whole screen and says nothing, so the
   room it reserves is read from the screen instead: visibleFrame stops where the
   Dock starts. Only a Dock along the bottom is handled; on the sides the cat
   falls back to windows. */
- (NSRect)dockSurface
{
	NSScreen *screen = [self screen] ? [self screen] : [NSScreen mainScreen];
	NSRect frame = [screen frame];
	NSRect visible = [screen visibleFrame];
	float reserved = NSMinY(visible) - NSMinY(frame);
	if(reserved < 20.0f)
		return NSZeroRect;           /* hidden, or on a side */

	/* The Dock sits in the middle of the edge, so the cat is kept over the part
	   that is actually there rather than the empty desk beside it. */
	float inset = frame.size.width * 0.15f;
	return NSMakeRect(NSMinX(frame) + inset, NSMinY(visible),
	                  frame.size.width - 2.0f * inset, 1.0f);
}

/* The surfaces the cat may stand on: the Dock when it is out, otherwise the top
   edge of any window that is not filling the screen, otherwise the desk itself.
   Refreshed every few ticks, since windows do not move eight times a second. */
- (void)refreshShelves
{
	if(shelves != nil && shelvesAge > 0) {
		shelvesAge--;
		return;
	}
	shelvesAge = 4;

	NSMutableArray *found = [NSMutableArray array];
	NSRect dock = [self dockSurface];
	if(!NSIsEmptyRect(dock)) {
		[shelves release];
		shelves = [[NSArray arrayWithObject:[NSValue valueWithRect:dock]] retain];
		return;
	}

	CFArrayRef list = CGWindowListCopyWindowInfo(
		kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
		kCGNullWindowID);
	if(list == NULL)
		return;

	/* Quartz measures from the top of the main display downwards. */
	NSRect screenFrame = [[[NSScreen screens] objectAtIndex:0] frame];
	float flip = NSMaxY(screenFrame);
	double screenArea = screenFrame.size.width * screenFrame.size.height;
	int mine = [[NSProcessInfo processInfo] processIdentifier];
	NSEnumerator *e = [(NSArray *)list objectEnumerator];
	NSDictionary *window;
	while((window = [e nextObject]) != nil) {
		if([[window objectForKey:(id)kCGWindowLayer] integerValue] != 0)
			continue;
		if([[window objectForKey:(id)kCGWindowOwnerPID] intValue] == mine)
			continue;
		NSNumber *alpha = [window objectForKey:(id)kCGWindowAlpha];
		if(alpha != nil && [alpha floatValue] < 0.5f)
			continue;
		CGRect bounds = CGRectZero;
		if(!CGRectMakeWithDictionaryRepresentation(
			(CFDictionaryRef)[window objectForKey:(id)kCGWindowBounds], &bounds))
			continue;
		if(bounds.size.width < 120.0f || bounds.size.height < 60.0f)
			continue;
		/* A window filling the screen leaves nowhere to be seen standing. */
		if(bounds.size.width * bounds.size.height > 0.85 * screenArea)
			continue;
		[found addObject:[NSValue valueWithRect:NSMakeRect(
			bounds.origin.x, flip - bounds.origin.y, bounds.size.width, 1.0f)]];
	}
	CFRelease(list);

	[shelves release];
	shelves = [found copy];
}

/* The highest surface the cat can stand on at this horizontal position, never
   above where its feet already are: it lands on things, it is not lifted. */
- (float)floorUnderCentre:(float)centre feet:(float)feet
{
	float floor = NSMinY([self nekoBounds]);
	if(!windowsMode)
		return floor;

	NSEnumerator *e = [shelves objectEnumerator];
	NSValue *value;
	while((value = [e nextObject]) != nil) {
		NSRect shelf = [value rectValue];
		if(centre < NSMinX(shelf) || centre > NSMaxX(shelf))
			continue;
		float top = shelf.origin.y;
		if(top > feet + 1.0f || top <= floor)
			continue;
		floor = top;
	}
	return floor;
}

/* Keeps the whole sprite on a screen, and standing on whatever is under it. */
- (void)settleX:(float *)x Y:(float *)y from:(float)previousY
{
	NSRect bounds = [self nekoBounds];
	float side = [self frame].size.width;
	*x = MIN(MAX(*x, NSMinX(bounds)), NSMaxX(bounds) - side);
	*y = MIN(MAX(*y, NSMinY(bounds)), NSMaxY(bounds) - side);
	*y = MAX(*y, [self floorUnderCentre:*x + side / 2.0f feet:previousY]);
}

/* The scratching state for whatever the cat is pressed against while still
   trying to get past it, or NekoStateCount when it is not blocked. */
- (NekoState)blockedWallState
{
	NSRect bounds = [self nekoBounds];
	NSRect frame = [self frame];
	float edge = 1.0f;

	if(moveDx < 0.0f && NSMinX(frame) <= NSMinX(bounds) + edge)
		return NekoStateLTogi;
	if(moveDx > 0.0f && NSMaxX(frame) >= NSMaxX(bounds) - edge)
		return NekoStateRTogi;
	if(moveDy > 0.0f && NSMaxY(frame) >= NSMaxY(bounds) - edge)
		return NekoStateUTogi;
	if(moveDy < 0.0f) {
		float floor = [self floorUnderCentre:NSMidX(frame) feet:NSMinY(frame)];
		if(NSMinY(frame) <= floor + edge)
			return NekoStateDTogi;   /* the desk, or the window it is standing on */
	}
	return NekoStateCount;
}

- (void)calcDxDyForX:(float)x Y:(float)y
{
	float		MouseX, MouseY;
	float		DeltaX, DeltaY;
	float		Length;
	
	NSPoint p = [self chaseTarget];
	MouseX = p.x;
	MouseY = p.y;
	
	DeltaX = floor(MouseX - x - [self frame].size.width / 2.0f);
	DeltaY = floor(MouseY - y);
	
	Length = hypotf(DeltaX, DeltaY);
	
	/* The cat keeps stopRadius points between itself and the pointer. Capping
	   the step by whatever distance is left over that ring makes it settle on
	   the ring instead of stepping across it and jittering back. */
	/* The deltas are whole points, so the distance left over the ring can sit
	   just above zero for ever and the cat would creep towards the pointer a
	   fraction of a point per tick, walking animation and all. Anything under
	   a point counts as arrived. */
	float travel = Length - stopRadius;
	if (travel <= 1.0f) {
		moveDx = moveDy = 0.0f;
	} else {
		float step = (travel < speed) ? travel : speed;
		moveDx = (step * DeltaX) / Length;
		moveDy = (step * DeltaY) / Length;
	}
}

- (BOOL)isNekoMoveStart
{
	float threshold = speed / 2.0f;
	return moveDx > threshold || moveDx < -threshold || moveDy > threshold || moveDy < -threshold;
}

- (void)advanceClock
{
	if (++tickCount >= 255) {
		tickCount = 0;
    }
	
    if (tickCount % 2 == 0) {
		if (stateCount < 255) {
			stateCount++;
		}
    }
}

- (void)NekoDirection
{
    NekoState	NewState;
    double		LargeX, LargeY;
    double		Length;
    double		SinTheta;
	
    if (moveDx == 0.0f && moveDy == 0.0f) {
		NewState = NekoStateStop;
    } else {
		LargeX = (double)moveDx;
		LargeY = (double)moveDy;
		Length = sqrt(LargeX * LargeX + LargeY * LargeY);
		SinTheta = LargeY / Length;
		//printf("SinTheta = %f\n", SinTheta);
		
		if (moveDx > 0) {
			if (SinTheta > 0.9239) {
				NewState = NekoStateUMove;
			} else if (SinTheta > 0.3827) {
				NewState = NekoStateURMove;
			} else if (SinTheta > -0.3827) {
				NewState = NekoStateRMove;
			} else if (SinTheta > -0.9239) {
				NewState = NekoStateDRMove;
			} else {
				NewState = NekoStateDMove;
			}
		} else {
			if (SinTheta > 0.9239) {
				NewState = NekoStateUMove;
			} else if (SinTheta > 0.3827) {
				NewState = NekoStateULMove;
			} else if (SinTheta > -0.3827) {
				NewState = NekoStateLMove;
			} else if (SinTheta > -0.9239) {
				NewState = NekoStateDLMove;
			} else {
				NewState = NekoStateDMove;
			}
		}
    }
	
    [self setStateTo:NewState];
}

- (void)handleTimer:(NSTimer*)timer
{
	float x = [self frame].origin.x;
	float y = [self frame].origin.y;
	float previousY = y;
	
	if(stateFrames == nil)
		return;                        /* not wired up to a character yet */
	
	if(windowsMode)
		[self refreshShelves];
	
	if([self isWalking])
		restedTicks = 0;
	else if(restedTicks < 60000)
		restedTicks++;

	if(roamMode && roamTicks < 60000)
		roamTicks++;

	/* An errand has two halves — getting there and doing the thing — and a
	   clock on each, so a target that turns out to be unreachable cannot leave
	   the cat walking into a wall for ever. */
	if(errandPhase == 2) {
		if(++errandTicks > errandHold) {
			errandPhase = 0;
			[self releaseHold];
		}
	} else if(errandPhase == 1) {
		errandTicks++;
		if(!wandering || errandTicks > 480) {
			BOOL arrived = !wandering;
			errandPhase = 0;
			errandTicks = 0;
			[self stopWandering];
			if(arrived && errandState != NekoStateCount && errandHold > 0) {
				errandPhase = 2;
				[self holdWithState:errandState];
			}
		}
	}
	
	/* Whatever it had in mind, you moving the pointer wins — except when it is
	   roaming, where the pointer was never the point. */
	if(wandering && !roamMode) {
		NSPoint mouse = [NSEvent mouseLocation];
		if(hypotf(mouse.x - wanderMouse.x, mouse.y - wanderMouse.y) > 24.0f)
			[self stopWandering];
	}
	
	[self calcDxDyForX:x Y:y];
	BOOL isNekoMoveStart = [self isNekoMoveStart];
	NekoState wall = [self blockedWallState];
	
	unsigned frame = (tickCount / stateTicksPerFrame) % [stateFrames count];
	[view setImageTo:(NSImage*)[stateFrames objectAtIndex:frame]];
	
	[self advanceClock];
	
	if(held)
		goto breakout;           /* being asked a question outranks the pointer */

	if([self isSpeaking]) {
		/* Anything that moves it across the desk is dropped; the idle chain is
		   left alone so it still blinks and washes while you read. */
		[self stopWandering];
		errandPhase = 0;
		moveDx = moveDy = 0.0f;
		if([self isWalking])
			[self setStateTo:NekoStateStop];
		if(nekoState == NekoStateAwake)
			[self setStateTo:NekoStateStop];
		goto breakout;
	}
	
    if(nekoState == NekoStateStop) {
		if (wall != NekoStateCount && isNekoMoveStart) {
			[self setStateTo:wall];    /* pressed against something, claw at it */
			goto breakout;
		}
		if (isNekoMoveStart) {
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if ([self shouldWanderNow]) {
			[self beginWandering];
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if (stateCount < 4) {
			goto breakout;
		}
		[self setStateTo:NekoStateJare];
	} else if(nekoState == NekoStateJare) {
		if (isNekoMoveStart) {
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if ([self shouldWanderNow]) {
			[self beginWandering];
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if (stateCount < 10) {
			goto breakout;
		}
		[self setStateTo:NekoStateKaki];
	} else if(nekoState == NekoStateKaki) {
		if (isNekoMoveStart) {
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if (stateCount < 4) {
			goto breakout;
		}
		[self setStateTo:NekoStateAkubi];
	} else if(nekoState == NekoStateAkubi) {
		if (isNekoMoveStart) {
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if (stateCount < 6) {
			goto breakout;
		}
		[self setStateTo:([self mayFallAsleep] ? NekoStateSleep : NekoStateStop)];
	} else if(nekoState == NekoStateSleep) {
		if (isNekoMoveStart) {
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if ([self shouldWanderNow]) {
			[self beginWandering];
			[self setStateTo:NekoStateAwake];
		}
	} else if(nekoState == NekoStateAwake) {
		if (stateCount < 3) {
			goto breakout;
		}
		[self NekoDirection];	/* work out which way the cat moves */
	} else if(nekoState == NekoStateUMove || nekoState == NekoStateDMove || nekoState == NekoStateLMove || nekoState == NekoStateRMove || nekoState == NekoStateULMove || nekoState == NekoStateURMove || nekoState == NekoStateDLMove || nekoState == NekoStateDRMove) {
		x += moveDx;
		y += moveDy;
		[self settleX:&x Y:&y from:previousY];
		if (wall != NekoStateCount) {
			/* It cannot get any closer, so it scratches instead of walking on
			   the spot for ever. */
			[self setStateTo:wall];
		} else {
			[self NekoDirection];
			if (wandering && nekoState == NekoStateStop)
				[self stopWandering];   /* arrived where it wanted to go */
		}
	} else if(nekoState == NekoStateUTogi || nekoState == NekoStateDTogi || nekoState == NekoStateLTogi || nekoState == NekoStateRTogi) {
		if (wall == NekoStateCount && isNekoMoveStart) {
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if (stateCount < 10) {
			goto breakout;
		}
		[self setStateTo:NekoStateKaki];
	} else {
		/* Internal Error */
		[self setStateTo:NekoStateStop];
	}

	breakout:
	/* Only the window dweller is pulled downwards: a cat chasing the pointer
	   rests wherever it stopped, and dragging it to the floor there sent it
	   into a loop of arriving, falling and setting off again. */
	if (windowsMode && !held && ![self isWalking]) {
		float floor = [self floorUnderCentre:x + [self frame].size.width / 2.0f
		                               feet:previousY];
		if (y > floor)
			y = MAX(floor, y - speed);
	}
	[view displayIfNeeded];
	[self setFrameOrigin:NSMakePoint(x, y)];
}

@end
