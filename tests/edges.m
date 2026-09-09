/* Two monitors, and the cat going mad along the borders.

   Reported from a desk with a portrait display stacked above a laptop:

       screen 0  visible (0, 0, 1512, 949)      the built-in, menu bar removed
       screen 1  visible (0, 982, 1440, 2560)   an external one, on its side, above

   Those two do not tile a rectangle. -nekoBounds unions them into
   (0, 0, 1512, 3542) so the cat can walk from one display to the other, and that
   union contains two regions where **there is no screen at all**:

       x 1440–1512, y 982–3542   the upper display is 72 points narrower
       y  949–982,  x 0–1512     the menu bar band of the lower one

   Everything that picks somewhere to walk to picks it inside the union, so a
   share of every walk aims at a place the cat cannot legally be. What happens
   next is the reported behaviour: -[NSWindow screen] is **nil** for a window on
   no screen, NekoAntics asks it for -visibleFrame and gets NSZeroRect, and the
   antic that goes to claw the edge of the screen computes its edge from a
   rectangle at the origin.

   This measures the share, so the fix has a number to beat, and pins that a
   target is put on a real screen before anybody walks to it. NekoOriginOnAScreen
   takes its screens as an argument, which is what makes any of this testable
   without two monitors attached. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "MyPanel.h"

static NSArray *twoMonitors(void)
{
	return [NSArray arrayWithObjects:
		[NSValue valueWithRect:NSMakeRect(0.0f, 0.0f, 1512.0f, 949.0f)],
		[NSValue valueWithRect:NSMakeRect(0.0f, 982.0f, 1440.0f, 2560.0f)], nil];
}

static NSRect unionOf(NSArray *frames)
{
	NSRect all = NSZeroRect;
	NSEnumerator *e = [frames objectEnumerator];
	NSValue *each;
	while((each = [e nextObject]) != nil)
		all = NSIsEmptyRect(all) ? [each rectValue] : NSUnionRect(all, [each rectValue]);
	return all;
}

static BOOL onSomeScreen(NSPoint origin, float side, NSArray *frames)
{
	NSRect sprite = NSMakeRect(origin.x, origin.y, side, side);
	NSEnumerator *e = [frames objectEnumerator];
	NSValue *each;
	while((each = [e nextObject]) != nil)
		if(NSIntersectsRect(sprite, [each rectValue]))
			return YES;
	return NO;
}

int main(void)
{
	[NSApplication sharedApplication];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSArray *screens = twoMonitors();
	NSRect all = unionOf(screens);
	const float side = 32.0f;

	printf("--- the desk this was reported from ---\n");
	printf("      screen 0  %s\n", [NSStringFromRect([[screens objectAtIndex:0] rectValue]) UTF8String]);
	printf("      screen 1  %s\n", [NSStringFromRect([[screens objectAtIndex:1] rectValue]) UTF8String]);
	printf("      union     %s\n", [NSStringFromRect(all) UTF8String]);

	double screenArea = 0.0;
	NSEnumerator *e = [screens objectEnumerator];
	NSValue *each;
	while((each = [e nextObject]) != nil)
		screenArea += NSWidth([each rectValue]) * NSHeight([each rectValue]);
	double voidShare = 1.0 - screenArea / (NSWidth(all) * NSHeight(all));
	ok(voidShare > 0.0,
		@"the union invents room that is on no screen",
		[NSString stringWithFormat:@"%.1f%% of it", voidShare * 100.0]);

	printf("\n--- where a walk is aimed, as the union has it ---\n");

	/* The same arithmetic -startWanderingAnywhere does: a point taken uniformly
	   from the union, less the sprite. Ten thousand of them, so the share is a
	   measurement rather than an anecdote. */
	NSUInteger tries = 10000, nowhere = 0, rescuedOff = 0;
	NSUInteger i;
	for(i = 0; i < tries; i++) {
		float roomX = MAX(NSWidth(all) - side, 1.0f);
		float roomY = MAX(NSHeight(all) - side, 1.0f);
		NSPoint wanted = NSMakePoint(
			NSMinX(all) + (float)arc4random_uniform((unsigned)roomX),
			NSMinY(all) + (float)arc4random_uniform((unsigned)roomY));
		if(!onSomeScreen(wanted, side, screens))
			nowhere++;
		/* And the same point put through the rescue that already exists. */
		if(!onSomeScreen(NekoOriginOnAScreen(wanted, side, screens), side, screens))
			rescuedOff++;
	}
	ok(nowhere > 0,
		@"a share of every walk is aimed where no screen is",
		[NSString stringWithFormat:@"%lu of %lu — about one walk in %.0f",
			(unsigned long)nowhere, (unsigned long)tries,
			(double)tries / (double)MAX(nowhere, (NSUInteger)1)]);
	ok(rescuedOff == 0,
		@"and every one of them, put through NekoOriginOnAScreen, lands on a screen",
		[NSString stringWithFormat:@"%lu still off", (unsigned long)rescuedOff]);

	printf("\n--- the two dead regions, named ---\n");

	/* The strip beside the narrower upper display. */
	NSPoint besideTheTall = NSMakePoint(1470.0f, 2000.0f);
	ok(NSPointInRect(besideTheTall, all) && !onSomeScreen(besideTheTall, side, screens),
		@"beside the upper display: inside the union, on no screen",
		[NSString stringWithFormat:@"%.0f,%.0f", besideTheTall.x, besideTheTall.y]);
	NSPoint saved = NekoOriginOnAScreen(besideTheTall, side, screens);
	ok(onSomeScreen(saved, side, screens), @"and it is brought back onto one",
		[NSString stringWithFormat:@"→ %.0f,%.0f", saved.x, saved.y]);

	/* The menu bar band, which is a wall the union does not know about. */
	NSPoint inTheMenuBar = NSMakePoint(700.0f, 960.0f);
	ok(NSPointInRect(inTheMenuBar, all),
		@"the menu bar band is inside the union too", nil);
	ok(onSomeScreen(inTheMenuBar, side, screens),
		@"though a 32 point sprite there still touches a screen, so it is the "
		@"lesser of the two", nil);

	printf("\n--- and the corner the reported behaviour comes from ---\n");

	/* NekoAntics asks [[panel screen] visibleFrame] in three places. A window on
	   no screen answers nil, and nil answers NSZeroRect — so the antic that goes
	   to claw the edge of the screen picks its edge from a rectangle at the
	   origin, on a desk 3542 points tall. */
	NSRect fromNil = NSZeroRect;
	float clawTo = NSMidX(NSMakeRect(1470.0f, 2000.0f, side, side)) < NSMidX(fromNil)
		? NSMinX(fromNil) : NSMaxX(fromNil);
	ok(clawTo == 0.0f,
		@"a nil screen sends the cat clawing to x = 0, from x = 1470",
		[NSString stringWithFormat:@"%.0f", clawTo]);
	/* x = 0 is a legal place to stand at that height — the first draft of this
	   check claimed otherwise and was simply wrong. What is wrong is the
	   distance: the cat is beside the right edge of a 1440-wide display and is
	   sent to the left edge of the desk, in one errand, for no reason it could
	   have. That is the bolt somebody watching would call going mad. */
	ok(fabsf(1470.0f - clawTo) > 1000.0f,
		@"which is a bolt across the whole desk, from one edge to the other",
		[NSString stringWithFormat:@"%.0f points in one errand",
			fabsf(1470.0f - clawTo)]);

	printf("\n--- and that the two repairs are in the code, not just intended ---\n");

	/* Checked against the source, the way tests/screen.m checks the route from a
	   screen to a deed. A run cannot prove that nothing asks a nil screen for
	   its frame — only that nothing did this once. */
	NSString *antics = [NSString stringWithContentsOfFile:@"src/NekoAntics.m"
		encoding:NSUTF8StringEncoding error:NULL];
	NSString *panel = [NSString stringWithContentsOfFile:@"src/MyPanel.m"
		encoding:NSUTF8StringEncoding error:NULL];
	if([antics length] == 0 || [panel length] == 0) {
		notMeasured(@"the sources are not beside this harness, so the two "
		            @"structural checks were skipped");
	} else {
		/* The literal appears once more in each file, inside the comment that
		   explains why it is not used — so the count is what is asserted, not
		   its absence. */
		NSUInteger asks = 0;
		NSRange from = NSMakeRange(0, [antics length]);
		NSRange found;
		while((found = [antics rangeOfString:@"[[panel screen] visibleFrame]"
		                             options:0 range:from]).location != NSNotFound) {
			asks++;
			from = NSMakeRange(NSMaxRange(found), [antics length] - NSMaxRange(found));
		}
		ok(asks == 0,
			@"nothing in the antics asks a window's screen for its frame any more",
			[NSString stringWithFormat:@"%lu places", (unsigned long)asks]);

		NSUInteger rescued = 0;
		from = NSMakeRange(0, [panel length]);
		while((found = [panel rangeOfString:@"somewhereItCanStand:"
		                            options:0 range:from]).location != NSNotFound) {
			rescued++;
			from = NSMakeRange(NSMaxRange(found), [panel length] - NSMaxRange(found));
		}
		/* Three walks pick a target — away from the pointer, onto a shelf, and
		   anywhere at all — plus the method itself and the comment above it. */
		ok(rescued >= 4,
			@"and all three ways of choosing a walk put the target on a screen",
			[NSString stringWithFormat:@"%lu mentions", (unsigned long)rescued]);
	}

	notMeasured(@"what this looks like. The share above is the arithmetic of the "
	            @"target, not a recording of the cat; whether the reported "
	            @"madness is this and only this needs the two monitors it was "
	            @"reported from");

	printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
	[pool release];
	return NekoTestFailures > 0 ? 1 : 0;
}
