/* Whether the typed line really takes the keyboard, and really gives it back.

   This one is a real application bundle rather than a second executable inside
   Neko.app: LaunchServices only activates a bundle's main executable, and
   without activation no window is ever key — which looks exactly like the bug
   this is meant to catch. It writes its result to a file because a bundle
   launched with `open` has nowhere to print. */

#import <Cocoa/Cocoa.h>
#import "NekoLine.h"

static NSMutableString *report = nil;
static int failures = 0;

static void say(NSString *line)
{
	[report appendString:line];
	[report appendString:@"\n"];
}

static void ok(BOOL condition, NSString *what, NSString *detail)
{
	if(!condition)
		failures++;
	say([NSString stringWithFormat:@"%@  %-46@ %@",
		condition ? @"ok  " : @"FAIL", what, detail ?: @""]);
}

/* AppKit's own loop has to be the one running, or activation never arrives. */
static void spin(NSTimeInterval seconds)
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

static void run(void)
{
	NSRunningApplication *before = [[NSWorkspace sharedWorkspace] frontmostApplication];

	NekoLine *line = [[NekoLine alloc] init];
	__block NSString *typed = nil;
	__block BOOL called = NO;
	[line askNearRect:NSMakeRect(600.0f, 500.0f, 32.0f, 32.0f)
	      placeholder:@"Ask me something…"
	         finished:^(NSString *text) { typed = [text copy]; called = YES; }];
	/* Activation can take a moment, and sometimes macOS declines to hand the
	   front to a bundle launched from a script at all — a full-screen window in
	   the way is enough. That is not a failure of the window, and it is not
	   something this test can measure, so it says which of the two happened. */
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:8.0];
	while(![line isKeyWindow] && [until timeIntervalSinceNow] > 0.0)
		spin(0.1);

	if([NSApp isActive])
		ok([line isKeyWindow], @"the line takes the keyboard",
			@"the application was brought to the front");
	else
		say(@"---   macOS did not bring this bundle to the front, so the keyboard "
		    @"was not measured");

	NSTextField *field = nil;
	NSEnumerator *e = [[[line contentView] subviews] objectEnumerator];
	NSView *view;
	while((view = [e nextObject]) != nil)
		if([view isKindOfClass:[NSTextField class]])
			field = (NSTextField *)view;
	[field setStringValue:@"typed with the keyboard it took"];
	[line performSelector:@selector(sendIt:) withObject:nil];
	spin(1.5);

	ok(called && [typed isEqualToString:@"typed with the keyboard it took"],
		@"what was typed comes back", typed);

	NSRunningApplication *after = [[NSWorkspace sharedWorkspace] frontmostApplication];
	ok([[after bundleIdentifier] isEqualToString:[before bundleIdentifier]],
		@"and the keyboard goes back where it came from",
		[NSString stringWithFormat:@"%@ → %@ → %@",
			[before bundleIdentifier], @"com.nekomac.linetest", [after bundleIdentifier]]);

	say([NSString stringWithFormat:@"\n%d failed", failures]);
	[report writeToFile:[@"~/Library/Caches/neko-linetest.txt" stringByExpandingTildeInPath]
	         atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	report = [[NSMutableString alloc] init];
	[NSApp finishLaunching];
	run();
	return failures == 0 ? 0 : 1;
}
