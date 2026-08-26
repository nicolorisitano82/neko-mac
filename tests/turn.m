/* Turning toward what it is attending to.

   Orientation is the cheapest attention signal a character has, and with these
   sprites it can only be said by moving: the eight directional poses are a
   gallop, and one frozen mid-stride reads as a cat stuck rather than a cat
   looking. (That is not a guess — the frames were opened and looked at, which is
   why this step turns instead of facing.) So the test asks two things: does it
   step in the right direction of eight, and does it take a step rather than a
   journey. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "MyPanel.h"
#import "NekoController.h"

@interface MyPanel (Testing)
- (void)handleTimer:(NSTimer *)timer;
- (void)setStateTo:(NekoState)state;
@end

static NSString *nameOf(NekoState state)
{
	switch(state) {
		case NekoStateUMove:  return @"north";
		case NekoStateURMove: return @"north-east";
		case NekoStateRMove:  return @"east";
		case NekoStateDRMove: return @"south-east";
		case NekoStateDMove:  return @"south";
		case NekoStateDLMove: return @"south-west";
		case NekoStateLMove:  return @"west";
		case NekoStateULMove: return @"north-west";
		case NekoStateAwake:  return @"sitting up";
		case NekoStateStop:   return @"sitting";
		default:              return [NSString stringWithFormat:@"%d", (int)state];
	}
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	/* Roaming, because that is the mode where the cat is not already wherever
	   the pointer is. */
	[[NSUserDefaults standardUserDefaults] setObject:@"roam" forKey:@"NekoBehaviour"];
	MyPanel *panel = [[MyPanel alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, 32.0f, 32.0f)
	                                           styleMask:NSWindowStyleMaskBorderless
	                                             backing:NSBackingStoreBuffered
	                                               defer:NO];
	[[NekoController sharedController] setPanel:panel];
	[panel applySettings];
	spin(0.2);

	printf("\n--- one of eight ---\n");

	struct { float dx; float dy; NekoState want; } angles[] = {
		{   0.0f,  200.0f, NekoStateUMove  },
		{ 200.0f,  200.0f, NekoStateURMove },
		{ 200.0f,    0.0f, NekoStateRMove  },
		{ 200.0f, -200.0f, NekoStateDRMove },
		{   0.0f, -200.0f, NekoStateDMove  },
		{-200.0f, -200.0f, NekoStateDLMove },
		{-200.0f,    0.0f, NekoStateLMove  },
		{-200.0f,  200.0f, NekoStateULMove },
	};
	int i;
	int right = 0;
	for(i = 0; i < 8; i++) {
		[panel setFrame:NSMakeRect(600.0f, 400.0f, 32.0f, 32.0f) display:NO];
		[panel setStateTo:NekoStateStop];
		NSPoint at = NSMakePoint(616.0f + angles[i].dx, 416.0f + angles[i].dy);
		unsigned ticks = [panel turnToward:at];
		/* The chain holds the alert pose for a few ticks before it sets off, so
		   the direction is visible a moment later, not immediately. */
		int t;
		NekoState got = NekoStateAwake;
		for(t = 0; t < 12 && got == NekoStateAwake; t++) {
			[panel handleTimer:nil];
			got = [panel state];
		}
		BOOL matched = (got == angles[i].want);
		if(matched)
			right++;
		printf("      %-11s wanted %-11s got %-11s (%u ticks)\n",
			[[NSString stringWithFormat:@"%.0f,%.0f", angles[i].dx, angles[i].dy] UTF8String],
			[nameOf(angles[i].want) UTF8String], [nameOf(got) UTF8String], ticks);
	}
	ok(right == 8, @"it steps in the right one of eight directions",
		[NSString stringWithFormat:@"%d of 8", right]);

	printf("\n--- a step, not a journey ---\n");

	[panel setFrame:NSMakeRect(600.0f, 400.0f, 32.0f, 32.0f) display:NO];
	[panel setStateTo:NekoStateStop];
	NSPoint far = NSMakePoint(1400.0f, 416.0f);
	unsigned ticks = [panel turnToward:far];
	int step;
	for(step = 0; step < 40; step++)
		[panel handleTimer:nil];
	float travelled = NSMinX([panel frame]) - 600.0f;
	printf("      target was 800 points away, it moved %.0f in 40 ticks\n", travelled);
	ok(travelled > 8.0f && travelled < 90.0f,
		@"it takes a step toward it and stops",
		[NSString stringWithFormat:@"%.0f points", travelled]);
	ok(ticks > 0 && ticks < 12, @"and says how long that will take",
		[NSString stringWithFormat:@"%u ticks", ticks]);

	printf("\n--- and does not fuss when it is already looking that way ---\n");

	[panel setFrame:NSMakeRect(600.0f, 400.0f, 32.0f, 32.0f) display:NO];
	[panel setStateTo:NekoStateStop];
	ok([panel turnToward:NSMakePoint(630.0f, 420.0f)] == 0,
		@"something under its nose needs no turning", nil);
	ok([panel turnToward:NSMakePoint(600.0f + 70.0f, 400.0f)] == 0,
		@"and neither does something inside the stopping radius", nil);
	ok([panel state] == NekoStateStop, @"and it stays as it was", nameOf([panel state]));

	printf("\n--- what was abandoned, and why ---\n");
	notMeasured(@"facing without moving: the eight directional frames are a "
	            "gallop, so a frozen one reads as a cat stuck mid-stride. The "
	            "sprites were opened and looked at before this step was written, "
	            "and the plan changed from a stare to a step.");
	notMeasured(@"looking away while thinking: already true. The thinking pose is "
	            "the cat scratching its own ear with its eyes shut, which is "
	            "aversion by accident — nothing to build.");

	[panel release];
	int result = NekoTestResult();
	[pool release];
	return result;
}
