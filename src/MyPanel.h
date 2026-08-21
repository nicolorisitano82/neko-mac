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
	
	float speed, scale;
	BOOL idleSleep;
	
}

/* Reads the current preferences and applies them to the cat. */
- (void)applySettings;

@end
