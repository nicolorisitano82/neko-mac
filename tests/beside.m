/* Coming over without landing on you.

   People keep their distance from something that attends to them, and the closer
   and more head-on the attention the more they compensate — measured with robots
   and with virtual agents, and the instinct is the same for a cat that sits on
   the caret. So the curious antics now stop an arm's length short and off to one
   side of the line they walked in on, and if the typing that sent the cat over
   has not stopped by the time it arrives, it leaves without saying anything.

   The geometry is testable without a screen, which is what this does. Whether it
   reads as tact or as a cat that never arrives is the week nobody can put in a
   harness. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoAntics.h"
#import "NekoDesktop.h"

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NekoAntics *antics = [NekoAntics sharedAntics];
	NSRect bounds = NSMakeRect(0.0f, 0.0f, 1920.0f, 1080.0f);

	printf("\n--- an arm's length, and off to one side ---\n");

	float nearest = 1.0e9f, furthest = 0.0f, tightest = 180.0f, widest = 0.0f;
	int both = 0, i;
	for(i = 0; i < 500; i++) {
		/* The cat somewhere, the thing it is nosy about somewhere else. */
		NSPoint cat = NSMakePoint(300.0f + (float)(i % 13) * 40.0f,
		                          200.0f + (float)(i % 7) * 60.0f);
		NSPoint what = NSMakePoint(1100.0f, 700.0f);
		NSPoint spot = [antics spotBeside:what from:cat within:bounds];

		float dx = spot.x - what.x, dy = spot.y - what.y;
		float distance = sqrtf(dx * dx + dy * dy);
		nearest = MIN(nearest, distance);
		furthest = MAX(furthest, distance);

		/* The angle at the thing, between the way the cat came from and where it
		   ended up: 0 would be standing in its own path, 180 the far side. */
		float ax = cat.x - what.x, ay = cat.y - what.y;
		float alen = sqrtf(ax * ax + ay * ay);
		float dot = (ax * dx + ay * dy) / (alen * distance);
		float angle = acosf(MAX(-1.0f, MIN(1.0f, dot))) * 180.0f / (float)M_PI;
		tightest = MIN(tightest, angle);
		widest = MAX(widest, angle);
		/* Left and right of the approach both happen. */
		float cross = ax * dy - ay * dx;
		if(cross > 0.0f)
			both |= 1;
		else
			both |= 2;
	}
	printf("      distance from the thing: %.0f to %.0f points\n", nearest, furthest);
	printf("      angle off the approach:  %.0f to %.0f degrees\n", tightest, widest);

	ok(nearest >= 55.0f && furthest <= 95.0f,
		@"it stops an arm's length short, every time",
		[NSString stringWithFormat:@"%.0f–%.0f points", nearest, furthest]);
	ok(tightest >= 35.0f, @"and never in the path it walked in on",
		[NSString stringWithFormat:@"closest %.0f degrees off", tightest]);
	ok(widest <= 75.0f, @"nor round the far side of it",
		[NSString stringWithFormat:@"widest %.0f degrees off", widest]);
	ok(both == 3, @"and it uses both sides", nil);

	printf("\n--- and it stays on the screen ---\n");

	NSPoint corner = NSMakePoint(4.0f, 4.0f);
	NSPoint spot = [antics spotBeside:corner
	                            from:NSMakePoint(900.0f, 600.0f)
	                          within:bounds];
	ok(NSPointInRect(spot, NSInsetRect(bounds, 8.0f, 8.0f)),
		@"a thing in the corner does not send it off the edge",
		[NSString stringWithFormat:@"%.0f, %.0f", spot.x, spot.y]);

	printf("\n--- and thinks better of it if you never stopped ---\n");

	/* shouldWithdrawInstead reads the same counter the antic was started by. */
	printf("      keys a minute right now: %u\n", [[NekoDesktop sharedDesktop] keysPerMinute]);
	ok([antics shouldWithdrawInstead] == ([[NekoDesktop sharedDesktop] keysPerMinute] > 40),
		@"the rule is the typing rate that sent it over", nil);
	notMeasured(@"the withdrawal itself: it needs somebody typing hard for two "
	            "seconds at the moment the cat arrives, which is a person and a "
	            "desk rather than a harness");

	int result = NekoTestResult();
	[pool release];
	return result;
}
