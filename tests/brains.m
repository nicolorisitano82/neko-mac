/* Which engine speaks when nobody asked, and which engines the diary is allowed
   anywhere near. One rule in code rather than a promise in a document: a remark
   the cat makes on its own never goes to a remote service, and neither does what
   it remembers. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoBrains.h"
#import "NekoAsk.h"
#import "NekoAnswerProvider.h"
#import "NekoModelStore.h"
#import "NekoAppleProvider.h"
#import "NekoLocalProvider.h"
#import "NekoOpenAIProvider.h"
#import "NekoModelProvider.h"
#import "NekoShortcutProvider.h"

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *chosen = [[[defaults stringForKey:NekoAskProviderKey] copy] autorelease];

	printf("\n--- which engines the diary may go to ---\n");

	/* Asked of the engines themselves rather than through the setting: a test
	   run with -NekoAskProvider on the command line cannot change that setting,
	   since NSUserDefaults reads arguments before anything saved. */
	NSArray *engines = [NSArray arrayWithObjects:
		[[[NekoAppleProvider alloc] init] autorelease],
		[[[NekoLocalProvider alloc] init] autorelease],
		[[[NekoOpenAIProvider alloc] init] autorelease],
		[[[NekoModelProvider alloc] init] autorelease],
		[[[NekoShortcutProvider alloc] initWithShortcutName:@"Ask Neko"] autorelease], nil];
	NSArray *remote = [NSArray arrayWithObjects:
		@"NO", @"NO", @"YES", @"YES", @"YES", nil];
	NSUInteger i;
	for(i = 0; i < [engines count]; i++) {
		id<NekoAnswerProvider> engine = [engines objectAtIndex:i];
		BOOL stays = [NekoBrains staysOnThisMac:engine];
		BOOL isRemote = [[remote objectAtIndex:i] isEqualToString:@"YES"];
		printf("      %-24s memory offered: %s\n",
			[NSStringFromClass([(id)engine class]) UTF8String], stays ? "yes" : "no");
		ok(stays == !isRemote,
			[NSString stringWithFormat:@"%@ %@ the diary",
				NSStringFromClass([(id)engine class]),
				isRemote ? @"is refused" : @"is offered"], nil);
	}

	printf("\n--- and what speaks when nobody asked ---\n");

	id<NekoAnswerProvider> speaks = [NekoBrains bestOnDeviceProvider];
	printf("      %s\n", [NSStringFromClass([(id)speaks class]) UTF8String]);
	ok(speaks == nil || [NekoBrains staysOnThisMac:speaks],
		@"nothing remote can ever speak unasked", nil);
	ok([[defaults stringForKey:NekoAskProviderKey] isEqualToString:chosen],
		@"and the question setting is left alone", chosen);

	printf("\n--- and when there is nothing good enough ---\n");

	printf("      %s\n", [[NekoBrains describeChoice] UTF8String]);
	id big = [NekoBrains biggestInstalledModel];
	printf("      biggest model on this Mac: %s, the bar is %.1f GB\n",
		big != nil ? [[big description] UTF8String] : "none",
		[NekoBrains capableModelBytes] / 1.0e9);
	ok([[NekoBrains describeChoice] length] > 0,
		@"it says which engine, in words", nil);
	ok([NekoBrains hasSomethingWorthHearing]
	   == ([NekoBrains bestOnDeviceProvider] != nil),
		@"and agrees with itself about whether there is one", nil);

	int result = NekoTestResult();
	[pool release];
	return result;
}
