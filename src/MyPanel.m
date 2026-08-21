#import "MyPanel.h"
#import "NekoController.h"

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

- (void)calcDxDyForX:(float)x Y:(float)y
{
	float		MouseX, MouseY;
	float		DeltaX, DeltaY;
	float		Length;
	
	NSPoint p = [NSEvent mouseLocation];
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
	//printf("paint %d %d\n", time(NULL), tickCount % [stateFrames count]);
	
	if(stateFrames == nil)
		return;                        /* not wired up to a character yet */
	
	[self calcDxDyForX:x Y:y];
	BOOL isNekoMoveStart = [self isNekoMoveStart];
	
	unsigned frame = (tickCount / stateTicksPerFrame) % [stateFrames count];
	[view setImageTo:(NSImage*)[stateFrames objectAtIndex:frame]];
	
	[self advanceClock];
	
    if(nekoState == NekoStateStop) {
		if (isNekoMoveStart) {
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
		if (stateCount < 4) {
			goto breakout;
		}
		/* The *_togi (wall scratching) states need screen edge detection, which
		   this port does not do yet, so they stay unreachable. Characters are
		   still expected to describe them. */
		[self setStateTo:NekoStateJare];
	} else if(nekoState == NekoStateJare) {
		if (isNekoMoveStart) {
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
		[self setStateTo:(idleSleep ? NekoStateSleep : NekoStateStop)];
	} else if(nekoState == NekoStateSleep) {
		if (isNekoMoveStart) {
			[self setStateTo:NekoStateAwake];
			goto breakout;
		}
	} else if(nekoState == NekoStateAwake) {
		if (stateCount < 3) {
			goto breakout;
		}
		[self NekoDirection];	/* work out which way the cat moves */
	} else if(nekoState == NekoStateUMove || nekoState == NekoStateDMove || nekoState == NekoStateLMove || nekoState == NekoStateRMove || nekoState == NekoStateULMove || nekoState == NekoStateURMove || nekoState == NekoStateDLMove || nekoState == NekoStateDRMove) {
		x += moveDx;
		y += moveDy;
		[self NekoDirection];
	} else if(nekoState == NekoStateUTogi || nekoState == NekoStateDTogi || nekoState == NekoStateLTogi || nekoState == NekoStateRTogi) {
		if (isNekoMoveStart) {
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
	[view displayIfNeeded];
	[self setFrameOrigin:NSMakePoint(x, y)];
}
@end
