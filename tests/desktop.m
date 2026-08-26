/* The seams: what counts as a good moment to say something, and for how long it
   stays one.

   Interruptions cost about ten minutes of task switching and another ten or
   fifteen before the original work resumes, and the cost depends on where they
   land (Iqbal & Bailey, CHI 2007/2008). These are the four seams that can be
   seen without reading anything: a program left after a stretch, a return from a
   real break, a burst of typing that stopped, a pause with work either side.

   Staged rather than performed: the front application, how long it has been
   there and how fast somebody is typing are handed to the real rule, and what
   comes back out is the measurement. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoDesktop.h"

@interface NekoDesktop (Testing)
- (void)noticeBreakpoint;
@end

@interface StagedDesktop : NekoDesktop
{
	NSString *staged;
	NSTimeInterval idle;
}
- (void)inFront:(NSString *)app since:(NSTimeInterval)seconds;
- (void)setIdle:(NSTimeInterval)seconds;
- (void)wasIdle:(NSTimeInterval)seconds;
- (void)typing:(uint32_t)nowPerMinute after:(uint32_t)beforePerMinute;
- (void)forget;
@end

@implementation StagedDesktop

- (NSString *)frontApp { return staged; }
- (NSTimeInterval)idleSeconds { return idle; }

/* Somebody has been in `app` for `seconds`, and has just left it for another. */
- (void)inFront:(NSString *)app since:(NSTimeInterval)seconds
{
	[previousApp release];
	previousApp = [app copy];
	[previousAppSince release];
	previousAppSince = [[NSDate dateWithTimeIntervalSinceNow:-seconds] retain];
}

- (void)setIdle:(NSTimeInterval)seconds { idle = seconds; }
- (void)wasIdle:(NSTimeInterval)seconds { previousIdle = seconds; }

- (void)typing:(uint32_t)nowPerMinute after:(uint32_t)beforePerMinute
{
	keysPerMinute = nowPerMinute;
	previousKeys = beforePerMinute;
}

/* No seam at all, as if nothing had happened yet. */
- (void)forget
{
	[breakpointAt release];
	breakpointAt = nil;
	breakpoint = NekoBreakpointNone;
	[staged release];
	staged = nil;
	idle = 0.0;
	keysPerMinute = 0;
	movesPerMinute = 0;
	previousKeys = 0;
	previousIdle = 0.0;
	[previousApp release];
	previousApp = nil;
}

- (void)stageFront:(NSString *)app
{
	[staged release];
	staged = [app copy];
}

@end

@interface StagedDesktop (More)
- (void)stageFront:(NSString *)app;
@end

static NSString *nameOf(NekoBreakpoint seam)
{
	switch(seam) {
		case NekoBreakpointCoarse: return @"coarse";
		case NekoBreakpointMedium: return @"medium";
		case NekoBreakpointFine:   return @"a small gap";
		default:                   return @"nothing";
	}
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	StagedDesktop *desktop = [[StagedDesktop alloc] init];

	printf("\n--- four seams, one at a time ---\n");

	[desktop forget];
	[desktop stageFront:@"Finder"];
	[desktop inFront:@"Pages" since:600.0];
	[desktop setIdle:1.0];
	[desktop noticeBreakpoint];
	ok([desktop breakpointNow] == NekoBreakpointCoarse,
		@"ten minutes in Pages, then a switch", nameOf([desktop breakpointNow]));

	[desktop forget];
	[desktop stageFront:@"Mail"];
	[desktop inFront:@"Finder" since:20.0];
	[desktop setIdle:1.0];
	[desktop noticeBreakpoint];
	ok([desktop breakpointNow] == NekoBreakpointMedium,
		@"twenty seconds in the Finder, then a switch", nameOf([desktop breakpointNow]));

	[desktop forget];
	[desktop stageFront:@"Xcode"];
	[desktop inFront:@"Xcode" since:60.0];
	[desktop wasIdle:420.0];
	[desktop setIdle:1.0];
	[desktop noticeBreakpoint];
	ok([desktop breakpointNow] == NekoBreakpointCoarse,
		@"back after seven minutes away", nameOf([desktop breakpointNow]));

	[desktop forget];
	[desktop stageFront:@"Xcode"];
	[desktop inFront:@"Xcode" since:60.0];
	[desktop typing:5 after:60];
	[desktop setIdle:1.0];
	[desktop noticeBreakpoint];
	ok([desktop breakpointNow] == NekoBreakpointMedium,
		@"a burst of typing that stopped", nameOf([desktop breakpointNow]));

	[desktop forget];
	[desktop stageFront:@"Xcode"];
	[desktop inFront:@"Xcode" since:60.0];
	[desktop typing:0 after:20];
	[desktop setIdle:6.0];
	[desktop noticeBreakpoint];
	ok([desktop breakpointNow] == NekoBreakpointFine,
		@"a pause with work either side of it", nameOf([desktop breakpointNow]));

	[desktop forget];
	[desktop stageFront:@"Xcode"];
	[desktop inFront:@"Xcode" since:60.0];
	[desktop typing:199 after:180];
	[desktop setIdle:0.0];
	[desktop noticeBreakpoint];
	ok([desktop breakpointNow] == NekoBreakpointNone,
		@"still typing, 199 keys a minute", nameOf([desktop breakpointNow]));

	printf("\n--- and a seam does not last ---\n");

	[desktop forget];
	[desktop stageFront:@"Finder"];
	[desktop inFront:@"Pages" since:600.0];
	[desktop setIdle:1.0];
	[desktop noticeBreakpoint];
	spin(3.0);
	ok([desktop breakpointNow] == NekoBreakpointCoarse,
		@"three seconds later it is still there",
		[NSString stringWithFormat:@"%.0f s old", [desktop secondsSinceBreakpoint]]);
	spin(10.0);
	ok([desktop breakpointNow] == NekoBreakpointNone,
		@"thirteen seconds later it is gone",
		[NSString stringWithFormat:@"%.0f s old", [desktop secondsSinceBreakpoint]]);

	printf("\n--- what cannot be staged ---\n");
	notMeasured(@"Focus and Do Not Disturb: macOS keeps that in "
	            "~/Library/DoNotDisturb, which is unreadable even outside the "
	            "sandbox, and there is no public API. A window filling the screen "
	            "is the proxy, and it does not catch a call in a window.");

	int result = NekoTestResult();
	[desktop release];
	[pool release];
	return result;
}
