/* The image the cat is drawing has to belong to somebody.

   Reported against 2.6: *"quando ho selezionato un plugin oppure ho cliccato
   sulla checkbox del plugin, l'app si è chiusa."* Two crash reports, both
   EXC_BAD_ACCESS inside -[MyView drawRect:] + 104, which is the one line in that
   method that sends a message: it draws an NSImage it holds without owning.

   The chain: switching a plugin on posts NekoPluginsDidChangeNotification, the
   controller forgets the character list because a plugin may ship characters, the
   panel then sees a different character object for the same identifier, releases
   the old one and its frames — and the view is still pointing at a frame from
   that array when the next redraw arrives.

   So this measures the ownership rather than the symptom: after the list is
   forgotten and the settings reapplied, the image the view is about to draw must
   still be alive and must be one of the frames the panel currently holds. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "MyPanel.h"
#import "MyView.h"
#import "NekoController.h"

@interface NekoController (Testing)
- (void)buildCharacterMenu;
@end
#import "NekoCharacter.h"
#import "NekoPlugins.h"
#import "NekoPlugin.h"

@interface MyPanel (Testing)
- (void)handleTimer:(NSTimer *)timer;
- (void)setStateTo:(NekoState)state;
@end

/* The panel runs a timer of its own at eight frames a second, and a real tick
   arriving between two staged lines changes what this measures — found the honest
   way: this harness passed alone and failed inside the full suite, where
   everything is slower and more ticks land. */
static void onlyStagedTicks(MyPanel *panel)
{
	Ivar found = class_getInstanceVariable([MyPanel class], "myTimer");
	if(found == NULL)
		return;
	NSTimer *ticking = (NSTimer *)object_getIvar(panel, found);
	[ticking invalidate];
	object_setIvar(panel, found, nil);
}

static id ivarOf(id object, Class where, const char *name)
{
	Ivar found = class_getInstanceVariable(where, name);
	return found != NULL ? object_getIvar(object, found) : nil;
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	MyPanel *panel = [[MyPanel alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, 32.0f, 32.0f)
	                                           styleMask:NSWindowStyleMaskBorderless
	                                             backing:NSBackingStoreBuffered
	                                               defer:NO];
	[[NekoController sharedController] setPanel:panel];
	[panel applySettings];
	spin(0.2);

	/* In the app the view comes out of MainMenu.nib. Loading that nib here would
	   start the whole application, so one is made and wired into the same ivar —
	   which is the ivar drawRect: is reached through either way. */
	MyView *view = (MyView *)ivarOf(panel, [MyPanel class], "view");
	if(view == nil) {
		Ivar slot = class_getInstanceVariable([MyPanel class], "view");
		if(slot == NULL) {
			notMeasured(@"the panel has no view ivar by that name any more");
			int early = NekoTestResult();
			[pool release];
			return early;
		}
		view = [[[MyView alloc] initWithFrame:[[panel contentView] bounds]] autorelease];
		[[panel contentView] addSubview:view];
		object_setIvar(panel, slot, view);
		[panel applySettings];
		spin(0.1);
	}

	onlyStagedTicks(panel);

	printf("\n--- the view owns what it draws ---\n");

	/* The defect itself, measured directly rather than through its symptom: an
	   image nobody else is holding, handed over and then let go of. Without the
	   retain the second check reads freed memory, which is exactly what drawRect:
	   was doing on somebody's Mac. */
	NSImage *fresh = [[NSImage alloc] initWithSize:NSMakeSize(8.0f, 8.0f)];
	NSUInteger held = [fresh retainCount];
	[view setImageTo:fresh];
	ok([fresh retainCount] == held + 1,
		@"handing it an image is handing it over",
		[NSString stringWithFormat:@"%lu → %lu", (unsigned long)held,
			(unsigned long)[fresh retainCount]]);
	[fresh release];
	ok([[view image] size].width == 8.0f,
		@"and it is still there after the caller lets go",
		[NSString stringWithFormat:@"%.0f", [[view image] size].width]);
	[view display];

	printf("\n--- a frame arrives before anything is forgotten ---\n");

	[panel setStateTo:NekoStateStop];
	NSImage *drawn = [view image];
	ok(drawn != nil, @"a change of pose hands the view its first frame at once", nil);

	NSArray *frames = (NSArray *)ivarOf(panel, [MyPanel class], "stateFrames");
	ok([frames containsObject:drawn],
		@"and it is one of the frames the panel is holding",
		[NSString stringWithFormat:@"%lu frames", (unsigned long)[frames count]]);

	printf("\n--- and it survives the character list being forgotten ---\n");

	/* Exactly what switching a plugin on does, in the order it does it. The
	   character identifier does not change; the object behind it does. */
	NekoCharacter *before = (NekoCharacter *)ivarOf(panel, [MyPanel class], "character");
	[NekoCharacter forgetTheList];
	[[NekoController sharedController] buildCharacterMenu];
	[panel applySettings];
	onlyStagedTicks(panel);
	NekoCharacter *after = (NekoCharacter *)ivarOf(panel, [MyPanel class], "character");
	ok(before != after,
		@"forgetting the list really does hand the panel a different object",
		[NSString stringWithFormat:@"%p → %p", before, after]);

	/* The moment of the crash: a redraw between the swap and the next tick. */
	NSImage *nowDrawing = [view image];
	ok(nowDrawing != nil, @"the view still has an image after the swap", nil);
	ok([nowDrawing isKindOfClass:[NSImage class]],
		@"and it is still an image rather than freed memory wearing its address",
		[nowDrawing className]);
	ok([nowDrawing size].width > 0.0f,
		@"which can still answer a question about itself",
		[NSString stringWithFormat:@"%.0f×%.0f",
			[nowDrawing size].width, [nowDrawing size].height]);

	NSArray *nowFrames = (NSArray *)ivarOf(panel, [MyPanel class], "stateFrames");
	ok([nowFrames containsObject:nowDrawing],
		@"and it is one of the frames the panel holds now, not one it let go of",
		[NSString stringWithFormat:@"%lu frames", (unsigned long)[nowFrames count]]);
	ok(nowDrawing != drawn,
		@"which is a different image from the one before the swap",
		[NSString stringWithFormat:@"%p → %p", drawn, nowDrawing]);

	/* And the redraw itself, which is what actually crashed. */
	[view display];
	spin(0.1);
	ok(YES, @"drawing after the swap does not take the app with it", nil);

	printf("\n--- the same thing, through the switch somebody clicks ---\n");

	NekoPlugins *registry = [NekoPlugins sharedPlugins];
	NekoPlugin *news = [registry pluginWithIdentifier:@"com.nekomac.news"];
	if(news == nil) {
		notMeasured(@"the plugin that ships inside the app is not installed here");
	} else {
		BOOL was = [registry isEnabled:news];
		int survived = 0;
		int round;
		for(round = 0; round < 4; round++) {
			[registry setEnabled:(round % 2 == 0) ? !was : was for:news];
			spin(0.05);
			[view display];
			[panel handleTimer:nil];
			if([[view image] isKindOfClass:[NSImage class]]
			   && [[view image] size].width > 0.0f)
				survived++;
		}
		[registry setEnabled:was for:news];
		ok(survived == 4, @"switched on and off four times, still drawing",
			[NSString stringWithFormat:@"%d of 4", survived]);
	}

	int result = NekoTestResult();
	[pool release];
	return result;
}
