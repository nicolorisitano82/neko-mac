/* Running away, staying put, and the empty space between two screens.

   Three things arrived together in 2.8, and all three came from reading the
   other 24 forks of the 2018 program this one grew out of:

   1. A fourth behaviour — the pointer as something to get away from. The idea
      and, more usefully, the *two* radii are ferlor-BSG's: with one threshold a
      cat sitting on the boundary steps out, finds itself outside, steps back in,
      and does that for ever. The test that matters is the one that would catch
      that, so it is here.
   2. "Stay here", which is this project's answer to the same fork's drag-the-cat
      — a menu item rather than a mouse, because the cat ignores the mouse on
      purpose.
   3. The bounding box of every screen is not the screens. With two displays of
      different heights it contains a rectangle where there is nothing, and a cat
      that walked into it sat somewhere nobody could see. That one is a bug, and
      it is tested against staged rectangles because this Mac has one display.

   **The pointer is staged too, and that was a defect here rather than a choice.**
   This used to read `[NSEvent mouseLocation]` and place the cat forty points from
   wherever the mouse actually was, clamped two hundred points inside the screen so
   the cat had room to run. With the mouse in a corner the clamp wins: the cat lands
   **224** points away, which is outside the radius that sets fleeing off, so
   nothing moves and the measurement fails having measured nothing. It failed once
   in three runs on this Mac and passed on re-running, which is the worst kind of
   test — one whose result depends on where somebody left the mouse.

   So `+[NSEvent mouseLocation]` answers what this harness says it answers, and one
   check asks the cat where it thinks the pointer is, so that a staging that stopped
   working could not pass quietly. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "MyPanel.h"
#import "NekoController.h"

@interface MyPanel (Testing)
- (void)handleTimer:(NSTimer *)timer;
- (void)setStateTo:(NekoState)state;
- (NSPoint)chaseTarget;
@end

/* The panel runs a timer of its own; a real tick landing between two staged ones
   moves the cat and spoils the measurement. Same treatment as tests/turn.m. */
static void onlyStagedTicks(MyPanel *panel)
{
	Ivar found = class_getInstanceVariable([MyPanel class], "myTimer");
	if(found == NULL)
		return;
	NSTimer *ticking = (NSTimer *)object_getIvar(panel, found);
	[ticking invalidate];
	object_setIvar(panel, found, nil);
}

/* The pointer, as this harness says it is. Everything the cat does about the
   mouse goes through +[NSEvent mouseLocation], so that is the one thing to answer
   — and answering it makes every measurement below the same on any Mac and at any
   time of day. */
static NSPoint stagedPointer;

static NSPoint stagedMouseLocation(id ignored, SEL cmd)
{
	return stagedPointer;
}

static BOOL stagePointerAt(NSPoint where)
{
	stagedPointer = where;
	Method found = class_getClassMethod([NSEvent class], @selector(mouseLocation));
	if(found == NULL)
		return NO;
	method_setImplementation(found, (IMP)stagedMouseLocation);
	return NSEqualPoints([NSEvent mouseLocation], where);
}

static NSValue *rect(float x, float y, float w, float h)
{
	return [NSValue valueWithRect:NSMakeRect(x, y, w, h)];
}

static float distanceFrom(MyPanel *panel, NSPoint point)
{
	NSRect frame = [panel frame];
	return hypotf(NSMidX(frame) - point.x, NSMinY(frame) - point.y);
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- the empty space between two screens ---\n");

	/* A wide short display to the right of a tall one — the arrangement this
	   Mac does not have, and the one the bounding box gets wrong. Their union
	   contains (1000..1800, 400..800), where there is no screen at all. */
	NSArray *screens = [NSArray arrayWithObjects:
		rect(0.0f, 0.0f, 1000.0f, 800.0f),
		rect(1000.0f, 0.0f, 800.0f, 400.0f), nil];
	float side = 32.0f;

	NSPoint onTheTall = NSMakePoint(500.0f, 600.0f);
	ok(NSEqualPoints(NekoOriginOnAScreen(onTheTall, side, screens), onTheTall),
		@"a cat on a screen is left where it is", nil);

	NSPoint onTheShort = NSMakePoint(1400.0f, 100.0f);
	ok(NSEqualPoints(NekoOriginOnAScreen(onTheShort, side, screens), onTheShort),
		@"and so is one on the other screen", nil);

	NSPoint acrossTheSeam = NSMakePoint(990.0f, 100.0f);
	ok(NSEqualPoints(NekoOriginOnAScreen(acrossTheSeam, side, screens), acrossTheSeam),
		@"a cat halfway across the seam is doing the right thing", nil);

	/* The bug: inside the bounding box, outside every screen. */
	NSPoint inTheVoid = NSMakePoint(1400.0f, 600.0f);
	NSPoint rescued = NekoOriginOnAScreen(inTheVoid, side, screens);
	ok(!NSEqualPoints(rescued, inTheVoid),
		@"a cat in the gap the bounding box invents is moved",
		[NSString stringWithFormat:@"%.0f,%.0f → %.0f,%.0f",
			inTheVoid.x, inTheVoid.y, rescued.x, rescued.y]);
	ok(NSPointInRect(NSMakePoint(rescued.x + side / 2.0f, rescued.y + side / 2.0f),
	                 NSMakeRect(1000.0f, 0.0f, 800.0f, 400.0f)),
		@"onto the nearest screen, which is the short one below it",
		[NSString stringWithFormat:@"%.0f,%.0f", rescued.x, rescued.y]);

	NSPoint faraway = NSMakePoint(5000.0f, 5000.0f);
	NSPoint back = NekoOriginOnAScreen(faraway, side, screens);
	ok(back.x <= 1800.0f && back.y <= 800.0f,
		@"and a spot from a display that is not here any more comes back",
		[NSString stringWithFormat:@"%.0f,%.0f", back.x, back.y]);

	ok(NSEqualPoints(NekoOriginOnAScreen(inTheVoid, side, [NSArray array]), inTheVoid),
		@"with no screens at all it does not invent one", nil);

	printf("\n--- running away ---\n");

	NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
	[settings setObject:@"flee" forKey:NekoBehaviourKey];
	MyPanel *panel = [[MyPanel alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, 32.0f, 32.0f)
	                                            styleMask:NSWindowStyleMaskBorderless
	                                              backing:NSBackingStoreBuffered
	                                                defer:NO];
	[[NekoController sharedController] setPanel:panel];
	[panel applySettings];
	onlyStagedTicks(panel);
	spin(0.2);

	NSRect room = [[NSScreen mainScreen] visibleFrame];

	/* The middle of the screen, which is the one place with room to run in every
	   direction — and no clamping afterwards, since the clamping is what used to
	   put the cat outside the radius and measure nothing. */
	NSPoint pointer = NSMakePoint(NSMidX(room), NSMidY(room));
	ok(stagePointerAt(pointer), @"the pointer is where this harness says it is",
		[NSString stringWithFormat:@"%.0f,%.0f", pointer.x, pointer.y]);
	/* Forty points away: well inside the near radius, with the screen's whole
	   half in front of it. */
	NSPoint start = NSMakePoint(pointer.x + 40.0f, pointer.y + 40.0f);
	[panel setFrame:NSMakeRect(start.x, start.y, 32.0f, 32.0f) display:NO];
	[panel setStateTo:NekoStateStop];

	float before = distanceFrom(panel, pointer);
	int tick;
	for(tick = 0; tick < 60; tick++)
		[panel handleTimer:nil];
	float after = distanceFrom(panel, pointer);

	ok(after > before, @"the pointer nearby, and the cat is further away than it was",
		[NSString stringWithFormat:@"%.0f → %.0f points", before, after]);
	/* Past the *outer* radius, not the one that set it off. A cat that stopped
	   on the trigger line would be triggered again by the next tick, which is
	   the whole reason there are two numbers. */
	ok(after >= 48.0f * 4.0f - 32.0f,
		@"out past the radius it settles at, not the one that set it off",
		[NSString stringWithFormat:@"%.0f points, wanted %.0f", after, 48.0f * 4.0f]);

	printf("\n--- and not dithering on the boundary ---\n");

	/* The failure the second radius exists to prevent: parked just outside the
	   near ring, a cat with one threshold walks a step out, is now outside,
	   walks back, and repeats. Nothing should move at all here. */
	NSPoint justOutside = NSMakePoint(pointer.x + 48.0f * 3.6f, pointer.y);
	justOutside.x = MIN(MAX(justOutside.x, NSMinX(room)), NSMaxX(room) - 32.0f);
	[panel setFrame:NSMakeRect(justOutside.x, justOutside.y, 32.0f, 32.0f) display:NO];
	[panel setStateTo:NekoStateStop];

	NSPoint settled = [panel frame].origin;
	float travelled = 0.0f;
	for(tick = 0; tick < 40; tick++) {
		[panel handleTimer:nil];
		NSPoint now = [panel frame].origin;
		travelled += hypotf(now.x - settled.x, now.y - settled.y);
		settled = now;
	}
	ok(travelled < 4.0f, @"outside both radii it stays where it is",
		[NSString stringWithFormat:@"%.1f points over 40 ticks", travelled]);

	printf("\n--- stay here ---\n");

	[settings setObject:@"follow" forKey:NekoBehaviourKey];
	[settings setBool:YES forKey:NekoStayKey];
	[panel applySettings];
	onlyStagedTicks(panel);

	/* Following the cursor, which is the mode that would normally walk it right
	   over — and it does not, because it was asked to stay. */
	NSPoint pinned = NSMakePoint(NSMinX(room) + 120.0f, NSMinY(room) + 120.0f);
	[panel setFrame:NSMakeRect(pinned.x, pinned.y, 32.0f, 32.0f) display:NO];
	[panel setStateTo:NekoStateStop];
	for(tick = 0; tick < 60; tick++)
		[panel handleTimer:nil];
	NSPoint stayed = [panel frame].origin;
	ok(hypotf(stayed.x - pinned.x, stayed.y - pinned.y) < 2.0f,
		@"asked to stay, it stays, whatever the pointer is doing",
		[NSString stringWithFormat:@"moved %.1f points",
			hypotf(stayed.x - pinned.x, stayed.y - pinned.y)]);

	[settings setBool:NO forKey:NekoStayKey];
	[panel applySettings];
	onlyStagedTicks(panel);

	/* Asked here rather than up in the fleeing, where -chaseTarget answers with
	   the place the cat is running *to*. Following, it answers with the pointer
	   itself — so this is the one moment that can say the staging above reaches
	   the code that reads it, rather than only the harness that set it. */
	ok(hypotf([panel chaseTarget].x - pointer.x,
	          [panel chaseTarget].y - pointer.y) < 1.0f,
		@"and following, it is the staged pointer the cat walks towards",
		[NSString stringWithFormat:@"%.0f,%.0f", [panel chaseTarget].x,
			[panel chaseTarget].y]);

	for(tick = 0; tick < 60; tick++)
		[panel handleTimer:nil];
	NSPoint freed = [panel frame].origin;
	ok(hypotf(freed.x - pinned.x, freed.y - pinned.y) > 2.0f,
		@"and let go, it goes back to what it was doing",
		[NSString stringWithFormat:@"moved %.1f points",
			hypotf(freed.x - pinned.x, freed.y - pinned.y)]);

	/* The launch after the one where somebody asked: the spot is in the settings
	   and the cat is somewhere else, and applying the settings takes it up. Once
	   — a cat asked to stay does not spring back to the mark every time some
	   unrelated setting changes. */
	NSPoint mark = NSMakePoint(NSMinX(room) + 300.0f, NSMinY(room) + 200.0f);
	[settings setObject:NSStringFromPoint(mark) forKey:NekoStayPointKey];
	[settings setBool:YES forKey:NekoStayKey];
	[panel setFrame:NSMakeRect(NSMinX(room) + 40.0f, NSMinY(room) + 40.0f,
	                           32.0f, 32.0f) display:NO];
	[panel applySettings];
	onlyStagedTicks(panel);
	NSPoint takenUp = [panel frame].origin;
	ok(hypotf(takenUp.x - mark.x, takenUp.y - mark.y) < 2.0f,
		@"the remembered spot is taken up when the settings are applied",
		[NSString stringWithFormat:@"%.0f,%.0f wanted %.0f,%.0f",
			takenUp.x, takenUp.y, mark.x, mark.y]);

	[panel setFrame:NSMakeRect(NSMinX(room) + 40.0f, NSMinY(room) + 40.0f,
	                           32.0f, 32.0f) display:NO];
	[panel applySettings];
	onlyStagedTicks(panel);
	ok(hypotf([panel frame].origin.x - (NSMinX(room) + 40.0f),
	          [panel frame].origin.y - (NSMinY(room) + 40.0f)) < 2.0f,
		@"and only once, not at every settings change after it",
		[NSString stringWithFormat:@"%.0f,%.0f",
			[panel frame].origin.x, [panel frame].origin.y]);
	[settings removeObjectForKey:NekoStayPointKey];

	printf("\n--- and it beats roaming, which is where it first did not ---\n");

	/* Measured in the real application before it was written down: the app was
	   in roam mode, "Stay here" was ticked, and the cat walked off anyway. Twice.
	   A roamer is always either on a walk or about to start one, so staying has
	   to come before the walk rather than after it. */
	[settings setObject:@"roam" forKey:NekoBehaviourKey];
	[settings setBool:YES forKey:NekoStayKey];
	[panel applySettings];
	onlyStagedTicks(panel);
	[panel setFrame:NSMakeRect(pinned.x, pinned.y, 32.0f, 32.0f) display:NO];
	[panel setStateTo:NekoStateStop];

	/* Long enough for a roamer to have decided on somewhere to be: it waits a
	   few seconds between walks and this is four hundred ticks. */
	for(tick = 0; tick < 400; tick++)
		[panel handleTimer:nil];
	NSPoint roamed = [panel frame].origin;
	ok(hypotf(roamed.x - pinned.x, roamed.y - pinned.y) < 2.0f,
		@"a roaming cat asked to stay does not go anywhere either",
		[NSString stringWithFormat:@"moved %.1f points over 400 ticks",
			hypotf(roamed.x - pinned.x, roamed.y - pinned.y)]);

	/* And one asked in the middle of a walk stops where it is, rather than
	   finishing the walk first — which is what it did. */
	[settings setBool:NO forKey:NekoStayKey];
	[panel applySettings];
	onlyStagedTicks(panel);
	/* Sent somewhere deliberately rather than waited for: a roamer rests a
	   random while between walks, and a test that waits for one is a test that
	   sometimes measures nothing. This is the call the antics make. */
	NSPoint setOff = [panel frame].origin;
	[panel errandTo:NSMakePoint(NSMidX(room), NSMidY(room))
	      thenState:NekoStateStop forTicks:8];
	for(tick = 0; tick < 12; tick++)
		[panel handleTimer:nil];
	NSPoint caught = [panel frame].origin;
	float underway = hypotf(caught.x - setOff.x, caught.y - setOff.y);
	/* Pinned first: "it stopped" means nothing about a cat that never started,
	   and that is exactly how this check would pass for the wrong reason. */
	ok(underway > 4.0f, @"and one sent somewhere is genuinely on its way",
		[NSString stringWithFormat:@"%.1f points in twelve ticks", underway]);
	if(![panel isOnErrand]) {
		notMeasured(@"it arrived before it could be asked to stay");
	} else {
		[settings setBool:YES forKey:NekoStayKey];
		[panel applySettings];
		onlyStagedTicks(panel);
		NSPoint whenAsked = [panel frame].origin;
		for(tick = 0; tick < 40; tick++)
			[panel handleTimer:nil];
		NSPoint stopped = [panel frame].origin;
		ok(hypotf(stopped.x - whenAsked.x, stopped.y - whenAsked.y) < 2.0f,
			@"asked in the middle of that walk, it stops there",
			[NSString stringWithFormat:@"moved %.1f points after being asked",
				hypotf(stopped.x - whenAsked.x, stopped.y - whenAsked.y)]);
	}

	[settings removeObjectForKey:NekoBehaviourKey];
	[settings removeObjectForKey:NekoStayKey];

	int result = NekoTestResult();
	[pool release];
	return result;
}
