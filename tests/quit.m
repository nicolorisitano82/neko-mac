/* That ⌘Q does not take the cat with it.

   Reported from use, and it had two sources rather than one. The obvious one is
   the cat's own menu, whose Quit item carried a ⌘Q. The one that was actually
   firing is invisible: MainMenu.nib has carried a standard application menu
   since 2007 — "Quit NewApplication", ⌘Q, wired to -terminate: — Info.plist
   still names that nib, and although the menu is never drawn (this process runs
   as an accessory with no Dock icon) **its key equivalents work whenever the
   application is active**: while the preferences are open, after the About
   panel, or the moment the panel takes focus to have a question typed into it.

   Nothing tells you the shortcut is there until it has fired, and what goes with
   it is everything the cat was in the middle of — a timer, a stretch of looking,
   a question half typed.

   Read from the live menus rather than from the source, because the whole defect
   was a menu nobody could see. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoController.h"

@interface NekoController (Testing)
- (void)disarmQuitIn:(NSMenu *)menu;
@end

/* The cat's own menu, out of the ivar it lives in. */
static NSMenu *statusMenu(NekoController *controller)
{
	Ivar found = class_getInstanceVariable([NekoController class], "statusItem");
	if(found == NULL)
		return nil;
	NSStatusItem *item = (NSStatusItem *)object_getIvar(controller, found);
	return [item menu];
}

static NSMenuItem *itemWithAction(NSMenu *menu, SEL action)
{
	NSEnumerator *e = [[menu itemArray] objectEnumerator];
	NSMenuItem *item;
	while((item = [e nextObject]) != nil) {
		if([item action] == action)
			return item;
		if([item hasSubmenu]) {
			NSMenuItem *deeper = itemWithAction([item submenu], action);
			if(deeper != nil)
				return deeper;
		}
	}
	return nil;
}

static NSUInteger armedQuitsIn(NSMenu *menu)
{
	NSUInteger armed = 0;
	NSEnumerator *e = [[menu itemArray] objectEnumerator];
	NSMenuItem *item;
	while((item = [e nextObject]) != nil) {
		if(([item action] == @selector(terminate:)
		    || [item action] == @selector(quit:))
		   && [[item keyEquivalent] length] > 0)
			armed++;
		if([item hasSubmenu])
			armed += armedQuitsIn([item submenu]);
	}
	return armed;
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- the cat's own menu ---\n");

	NekoController *controller = [NekoController sharedController];
	NSMenu *cats = statusMenu(controller);
	ok(cats != nil, @"the status item has a menu to look at", nil);

	NSMenuItem *quit = itemWithAction(cats, @selector(quit:));
	ok(quit != nil, @"and a way out is still in it", [quit title]);
	ok(quit != nil && [[quit keyEquivalent] length] == 0,
		@"with no keystroke on it",
		[NSString stringWithFormat:@"key equivalent “%@”",
			[quit keyEquivalent] ?: @""]);
	ok(armedQuitsIn(cats) == 0, @"and nothing else in there quits on a key either",
		[NSString stringWithFormat:@"%lu armed", (unsigned long)armedQuitsIn(cats)]);

	printf("\n--- the invisible one, walked ---\n");

	/* Staged, because a harness is not launched through NSApplicationMain and so
	   has no main menu of its own. Same shape as the nib's: an application menu
	   holding a Quit wired to -terminate: with ⌘Q on it. */
	NSMenu *staged = [[[NSMenu alloc] initWithTitle:@"MainMenu"] autorelease];
	NSMenuItem *appItem = [staged addItemWithTitle:@"Neko" action:NULL keyEquivalent:@""];
	NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:@"Neko"] autorelease];
	[appItem setSubmenu:appMenu];
	NSMenuItem *nibQuit = [appMenu addItemWithTitle:@"Quit NewApplication"
	                                         action:@selector(terminate:)
	                                  keyEquivalent:@"q"];
	[appMenu addItemWithTitle:@"Hide" action:@selector(hide:) keyEquivalent:@"h"];

	ok(armedQuitsIn(staged) == 1, @"the staged menu quits on a key, as the nib does",
		[nibQuit keyEquivalent]);
	[controller disarmQuitIn:staged];
	ok(armedQuitsIn(staged) == 0, @"and the walk takes the keystroke off it",
		[NSString stringWithFormat:@"key equivalent “%@”", [nibQuit keyEquivalent]]);
	ok([[appMenu itemWithTitle:@"Hide"] keyEquivalent] != nil
	   && [[[appMenu itemWithTitle:@"Hide"] keyEquivalent] isEqualToString:@"h"],
		@"while every other shortcut in that menu is left alone", @"⌘H");
	ok([nibQuit action] == @selector(terminate:),
		@"and the item still quits when it is chosen", nil);

	printf("\n--- and the hazard is still in the nib, so this test still has a job ---\n");

	NSString *nib = @"Resources/English.lproj/MainMenu.nib/keyedobjects.nib";
	NSData *compiled = [NSData dataWithContentsOfFile:nib];
	if(compiled == nil) {
		notMeasured(@"the nib is not where this expected it — run from the repository root");
	} else {
		NSString *readable = [[[NSString alloc] initWithData:compiled
			encoding:NSISOLatin1StringEncoding] autorelease];
		BOOL carriesQuit = [readable rangeOfString:@"Quit"].location != NSNotFound;
		ok(carriesQuit,
			@"MainMenu.nib still holds a Quit item — which is why the walk runs",
			carriesQuit ? @"found" : @"gone: this check can be deleted");
	}

	printf("\n--- and the real nib's menu, loaded and looked at ---\n");

	/* Stronger than the staged menu above, and the reason this section exists:
	   the staged one is the right shape by my reckoning, and my reckoning about
	   this nib was wrong once already. So load the actual thing. It instantiates
	   a panel as well, which is noisy in a harness and is what -setPanel: does in
	   every other test here. */
	if([NSApp mainMenu] != nil) {
		notMeasured(@"this harness already has a main menu — skipping the load");
	} else {
		BOOL loaded = [[NSBundle mainBundle] loadNibNamed:@"MainMenu"
		                                            owner:NSApp
		                                  topLevelObjects:NULL];
		NSMenu *real = [NSApp mainMenu];
		if(!loaded || real == nil) {
			notMeasured(@"MainMenu.nib would not load in a harness, so the walk "
			            @"is only checked against the staged menu above");
		} else {
			NSMenuItem *theirs = itemWithAction(real, @selector(terminate:));
			ok(theirs != nil,
				@"the nib's own Quit item is there, as the strings said",
				[theirs title]);
			printf("      before the walk: “%s” has key equivalent “%s”\n",
				[[theirs title] UTF8String],
				[[theirs keyEquivalent] UTF8String]);
			[controller disarmQuitIn:real];
			ok(armedQuitsIn(real) == 0,
				@"and after the walk nothing in the real menu quits on a key",
				[NSString stringWithFormat:@"key equivalent “%@”",
					[theirs keyEquivalent]]);
			ok([theirs action] == @selector(terminate:),
				@"while the item itself still works when chosen", nil);
		}
	}

	printf("\n--- and the second pass, for the order nobody promised ---\n");

	/* This controller is built from -awakeFromNib of a panel that lives in the
	   same nib as the menu, so the menu may not be connected to NSApp yet when
	   the first pass runs. Read from the source: what regresses here is somebody
	   deleting an observer, not a behaviour anybody can see. */
	NSString *source = [NSString stringWithContentsOfFile:@"src/NekoController.m"
		encoding:NSUTF8StringEncoding error:NULL];
	ok(source != nil && [source rangeOfString:
		@"NSApplicationDidFinishLaunchingNotification"].location != NSNotFound,
		@"the walk runs again once the nib has finished loading", nil);

	notMeasured(@"what this cannot press is the key. It checks the menus a "
	            @"keystroke would be matched against, on the reasoning that "
	            @"those two menus are the only places a ⌘Q could come from");

	[pool release];
	return NekoTestResult();
}
