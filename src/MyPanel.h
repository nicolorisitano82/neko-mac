/* MyPanel */

#import <Cocoa/Cocoa.h>
#import "MyView.h"
#import "NekoCharacter.h"

@interface MyPanel : NSPanel
{
	IBOutlet MyView *view;
	
	NekoCharacter *character;
	NekoState nekoState;
	NSArray *stateFrames;         /* frames of nekoState, never empty */
	unsigned stateTicksPerFrame;
	
	unsigned char tickCount, stateCount;
	float moveDx, moveDy;
	NSTimer *myTimer;
	
	float speed, scale, stopRadius;
	BOOL idleSleep;
	BOOL held;                   /* frozen mid-conversation */
	BOOL windowsMode;            /* lives on window tops instead of chasing */
	BOOL roamMode;               /* goes where it likes, the pointer means nothing */
	
	BOOL wanderEnabled;
	BOOL wandering;
	NSPoint wanderTarget;        /* where it decided to go on its own */
	NSPoint wanderMouse;         /* the pointer when it set off, to notice you moving */
	unsigned restedTicks;        /* how long it has been settled and asleep */
	unsigned roamTicks;          /* how long this roaming stretch has lasted */
	unsigned roamRest;           /* ticks to sit still before the next errand */

	int errandPhase;             /* 0 none, 1 on its way, 2 doing the thing */
	NekoState errandState;       /* what it does when it arrives */
	unsigned errandHold;         /* how long it does it for */
	unsigned errandTicks;
	
	NSArray *shelves;            /* top edges of other apps' windows */
	unsigned shelvesAge;
	
}

/* Reads the current preferences and applies them to the cat. */
- (void)applySettings;

/* Stops chasing and shows one pose, for as long as something more important
   than the pointer is going on. The frames still animate. */
/* Somewhere to go, on somebody else's behalf, and something to do when it gets
   there — the curious antics are built out of this. Pass NekoStateCount to
   arrive and carry on as normal. Roaming only: the other two behaviours have
   their own ideas about where the cat belongs. */
- (void)errandTo:(NSPoint)point thenState:(NekoState)state forTicks:(unsigned)ticks;
- (BOOL)isOnErrand;
- (BOOL)isRoaming;

- (void)holdWithState:(NekoState)state;

/* Which pose it is in. Read by the tests, and by anything that needs to know
   whether the cat has visibly reacted yet. */
- (NekoState)state;
- (void)releaseHold;
- (BOOL)isHeld;

@end
