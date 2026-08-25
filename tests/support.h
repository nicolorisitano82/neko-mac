/* Shared by every harness here: the same four lines, so that a test reads as
   what it measured rather than as plumbing. */

#import <Cocoa/Cocoa.h>

static int NekoTestChecks = 0;
static int NekoTestFailures = 0;

/* One measurement. The detail is not decoration: a test that only says "ok"
   proves nothing was measured. */
static void ok(BOOL condition, NSString *what, NSString *detail)
{
	NekoTestChecks++;
	if(!condition)
		NekoTestFailures++;
	printf("%s  %-50s %s\n", condition ? "ok  " : "FAIL",
	       [what UTF8String], [(detail ?: @"") UTF8String]);
}

/* Something could not be measured on this machine. Said out loud rather than
   passed quietly, because a test that skips in silence reads as a test that
   passed. */
static void notMeasured(NSString *why)
{
	printf("---   %s\n", [why UTF8String]);
}

static void spin(NSTimeInterval seconds)
{
	[[NSRunLoop currentRunLoop] runUntilDate:
		[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

/* AppKit's own loop, for anything that needs events to arrive. */
static void spinWithEvents(NSTimeInterval seconds)
{
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
	while([until timeIntervalSinceNow] > 0.0) {
		NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
		                                    untilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]
		                                       inMode:NSDefaultRunLoopMode
		                                      dequeue:YES];
		if(event != nil)
			[NSApp sendEvent:event];
	}
}

static int NekoTestResult(void)
{
	printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
	return NekoTestFailures == 0 ? 0 : 1;
}
