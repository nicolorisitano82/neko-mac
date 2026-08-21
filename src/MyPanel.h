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

@end
