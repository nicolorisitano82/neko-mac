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
	
	BOOL wanderEnabled;
	BOOL wandering;
	NSPoint wanderTarget;        /* where it decided to go on its own */
	NSPoint wanderMouse;         /* the pointer when it set off, to notice you moving */
	unsigned restedTicks;        /* how long it has been settled and asleep */
	
	NSArray *shelves;            /* top edges of other apps' windows */
	unsigned shelvesAge;
	
}

/* Reads the current preferences and applies them to the cat. */
- (void)applySettings;

/* Stops chasing and shows one pose, for as long as something more important
   than the pointer is going on. The frames still animate. */
- (void)holdWithState:(NekoState)state;
- (void)releaseHold;
- (BOOL)isHeld;

@end
