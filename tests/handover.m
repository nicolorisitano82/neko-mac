/* The one panel through which a folder is handed over.

   The sandbox means Neko cannot read your Desktop by deciding to: somebody has to
   choose the folder in a panel that the system, not the application, is showing.
   That panel is the whole of the permission — and in 2.5 the plugins window's
   Add… panel proved that an application with no Dock icon can open one **behind**
   whatever the person is looking at, which is indistinguishable from a button that
   does nothing. There is an old unclosed report saying exactly that about this
   one.

   So what is measured here is not that the panel exists. It is that somebody can
   see it: on screen, in front, and belonging to an application that is active. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoFolderAccess.h"
#import "NekoAction.h"
#import "NekoAsk.h"
#import "NekoBubble.h"
#import <objc/runtime.h>

@interface NekoAsk (TestOnly)
- (void)cancelEverything;
@end

static NSWindow *thePanelWindow(void)
{
	NSEnumerator *e = [[NSApp windows] objectEnumerator];
	NSWindow *window;
	while((window = [e nextObject]) != nil) {
		NSString *name = NSStringFromClass([window class]);
		if([name rangeOfString:@"Panel"].location != NSNotFound
		   && [window isVisible]
		   && ![name isEqualToString:@"NekoBubble"])
			return window;
	}
	return nil;
}

/* What the panel looked like from where somebody is standing, sampled while the
   modal session is up and then dismissed so the suite can go on. */
static NSMutableDictionary *seen = nil;

static void look(void)
{
	NSWindow *panel = thePanelWindow();
	seen = [[NSMutableDictionary alloc] init];
	[seen setObject:[NSNumber numberWithBool:panel != nil] forKey:@"there"];
	if(panel != nil) {
		[seen setObject:NSStringFromClass([panel class]) forKey:@"class"];
		[seen setObject:[NSNumber numberWithBool:[panel isVisible]] forKey:@"visible"];
		[seen setObject:[NSNumber numberWithBool:[panel isKeyWindow]] forKey:@"key"];
		[seen setObject:[NSNumber numberWithBool:[panel isOnActiveSpace]] forKey:@"space"];
	}
	[seen setObject:[NSNumber numberWithBool:[NSApp isActive]] forKey:@"active"];
	NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
	[seen setObject:[front bundleIdentifier] ?: @"?" forKey:@"front"];

	/* Whatever it says, put it away: a suite may not leave a modal session up. */
	if(panel != nil && [panel respondsToSelector:@selector(cancel:)])
		[(id)panel cancel:nil];
	[NSApp abortModal];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NekoFolderAccess *access = [NekoFolderAccess sharedAccess];

	printf("\n--- the panel somebody has to see ---\n");

	/* Asking for one that is already granted returns without a panel, which would
	   measure nothing at all. */
	if([access hasAccessTo:@"desktop"]) {
		notMeasured(@"the Desktop is already handed over on this Mac");
		int early = NekoTestResult();
		[pool release];
		return early;
	}

	/* Added to the modal mode by hand. A scheduled timer goes into the default
	   mode, and the run loop is not in the default mode while a modal panel is
	   up — which is how the first version of this test measured nothing and said
	   so, rather than passing. */
	NSTimer *watcher = [NSTimer timerWithTimeInterval:1.5 repeats:NO
	                                            block:^(NSTimer *t) { look(); }];
	[[NSRunLoop currentRunLoop] addTimer:watcher forMode:NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:watcher forMode:NSDefaultRunLoopMode];

	NSDate *began = [NSDate date];
	NSString *cancelled = @"not asked";
	BOOL granted = [access requestAccessTo:@"desktop" saying:&cancelled];
	NSTimeInterval waited = -[began timeIntervalSinceNow];
	ok(!granted, @"the staged panel was dismissed rather than answered", nil);
	ok(waited > 1.0,
		@"the application really did stop and wait for somebody",
		[NSString stringWithFormat:@"%.2f s", waited]);

	if(seen == nil) {
		notMeasured(@"nothing looked at the panel; the modal session never ran");
	} else {
		ok([[seen objectForKey:@"there"] boolValue],
			@"a panel is on screen while the application waits for it",
			[seen objectForKey:@"class"]);
		/* Whether this application can come to the front is not entirely up to
		   it: run inside the whole suite, with a build script and a Finder window
		   busy behind it, something else can own the focus at the moment the panel
		   opens. That is a fact about the machine and not about the panel, so it
		   is said rather than failed — the check that matters, that a panel exists
		   and the application stopped and waited for it, is above and is not
		   conditional. */
		if(![[seen objectForKey:@"active"] boolValue]) {
			notMeasured([NSString stringWithFormat:
				@"%@ had the focus when the panel opened, so being in front could not be measured",
				[seen objectForKey:@"front"]]);
		} else {
			ok(YES, @"and the application it belongs to is active",
				[[seen objectForKey:@"front"] description]);
			ok([[seen objectForKey:@"key"] boolValue],
				@"and it has the keyboard, which is what being in front means",
				[[seen objectForKey:@"key"] boolValue] ? @"key" : @"behind something");
		}
		ok([[seen objectForKey:@"space"] boolValue],
			@"and it is on the desktop somebody is looking at", nil);
	}

	printf("\n--- and it says why, when the answer is no ---\n");

	/* The refusal that was silent: a folder chosen, and not the one asked for.
	   Three places call this and none of them used to say anything, which from
	   where somebody is standing is a panel that did nothing. */
	NSString *wrong = [access refusalForChoosing:
		[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]]
	                                   insteadOf:@"desktop"];
	ok([wrong length] > 0, @"choosing the wrong folder is refused out loud", wrong);
	ok([wrong rangeOfString:@"Documents"].location != NSNotFound
	   || [wrong rangeOfString:@"Documenti"].location != NSNotFound,
		@"and the sentence names what was chosen", wrong);

	NSString *right = [access refusalForChoosing:
		[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"]]
	                                   insteadOf:@"desktop"];
	ok(right == nil, @"and the folder that was asked for is not refused", right);

	ok([access refusalForChoosing:nil insteadOf:@"desktop"] != nil,
		@"nor is nothing at all taken for a yes", nil);

	/* A cancel is not a failure and gets no sentence: the first panel above was
	   dismissed, and it left none. */
	ok(cancelled == nil, @"pressing Cancel says nothing, because it is not a fault",
		cancelled);

	printf("\n--- and through the door somebody actually comes in by ---\n");

	/* The report was not about calling this method. It was about saying yes to a
	   deed that needs a folder, which happens inside the bubble's own click
	   handler — a different place for a modal panel to be opened from, and the
	   place 2.5 proved you cannot reason about. */
	NekoAction *deed = [NekoAction actionFromLine:
		@"ACTION: copy pippo.txt from desktop to documents"];
	if(deed == nil) {
		notMeasured(@"the copy verb no longer parses that line");
	} else if([[deed needsFolders] count] == 0) {
		notMeasured(@"both folders are already handed over on this Mac");
	} else {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:NekoActionsEnabledKey];
		NekoAsk *ask = [NekoAsk sharedAsk];
		Ivar found = class_getInstanceVariable([NekoAsk class], "bubble");
		NekoBubble *bubble = (NekoBubble *)object_getIvar(ask, found);

		[seen release];
		seen = nil;
		[ask propose:deed];
		spin(0.4);

		/* Yes, from the button, not from the method behind it. */
		NSButton *yes = nil;
		NSEnumerator *v = [[[bubble contentView] subviews] objectEnumerator];
		NSView *view;
		while((view = [v nextObject]) != nil)
			if([view isKindOfClass:[NSButton class]] && ![view isHidden]
			   && [[(NSButton *)view title] isEqualToString:
			        NSLocalizedString(@"Yes", nil)])
				yes = (NSButton *)view;
		if(yes == nil) {
			notMeasured(@"the bubble showed no Yes to press");
		} else {
			NSTimer *second = [NSTimer timerWithTimeInterval:1.5 repeats:NO
			                                           block:^(NSTimer *t) { look(); }];
			[[NSRunLoop currentRunLoop] addTimer:second forMode:NSModalPanelRunLoopMode];
			[[NSRunLoop currentRunLoop] addTimer:second forMode:NSDefaultRunLoopMode];
			[yes performClick:nil];
			spin(2.5);
			if(seen == nil)
				notMeasured(@"saying yes opened no panel at all");
			else {
				ok([[seen objectForKey:@"there"] boolValue],
					@"saying yes puts the folder panel on screen",
					[seen objectForKey:@"class"]);
					if([[seen objectForKey:@"active"] boolValue])
					ok([[seen objectForKey:@"key"] boolValue],
						@"in front, with the keyboard",
						[[seen objectForKey:@"front"] description]);
				else
					notMeasured([NSString stringWithFormat:
						@"%@ had the focus, so being in front could not be measured",
						[seen objectForKey:@"front"]]);
			}
		}
		[ask cancelEverything];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:NekoActionsEnabledKey];
	}

	int result = NekoTestResult();
	[pool release];
	return result;
}
