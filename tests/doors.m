/* The ways in, from the rest of the Mac.

   Until 2.11 this application had one door — its own hotkey — which made it the
   only thing on this Mac that could not be reached the way everything else is.
   The asymmetry is worth stating plainly: Neko runs the user's Shortcuts, and
   nothing in the operating system could run Neko.

   App Intents is the answer Apple would give and it is not buildable here: the
   metadata a Shortcuts action is discovered through comes from
   appintentsmetadataprocessor, which ships inside Xcode and not in the Command
   Line Tools this project builds with. Swift declaring an intent would compile
   and nothing would ever find it. So these are the two doors that need no
   toolchain: a Services entry, and a URL.

   The URL is the one with a rule attached. A URL can be on a web page, and a web
   page is the one place this application has never taken instructions from — so
   what arrives through it is read back and waits for a yes, exactly like a deed. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoDoors.h"
#import "NekoAsk.h"
#import "NekoBubble.h"

@interface NekoAsk (TestOnly)
- (void)cancelEverything;
@end

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- what the bundle tells the system about itself ---\n");

	NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
	NSArray *services = [plist objectForKey:@"NSServices"];
	ok([services count] == 1, @"there is a Services entry",
		[NSString stringWithFormat:@"%lu", (unsigned long)[services count]]);
	ok([[[services firstObject] objectForKey:@"NSMessage"]
	        isEqualToString:@"askAboutSelection"],
		@"pointing at a method that exists",
		[[services firstObject] objectForKey:@"NSMessage"]);
	ok([NekoDoors instancesRespondToSelector:
		@selector(askAboutSelection:userData:error:)],
		@"and the method really is there — a Services entry naming a method "
		@"nobody wrote is a menu item that does nothing", nil);
	ok([[[services firstObject] objectForKey:@"NSSendTypes"] count] > 0,
		@"and it says it takes text", nil);

	NSArray *urls = [plist objectForKey:@"CFBundleURLTypes"];
	ok([[[urls firstObject] objectForKey:@"CFBundleURLSchemes"]
	        containsObject:@"neko"],
		@"and there is a neko:// scheme", nil);

	printf("\n--- what a URL is allowed to say ---\n");

	struct { const char *url; const char *want; } asked[] = {
		{ "neko://ask?q=che%20ore%20sono", "che ore sono" },
		{ "neko://ask?q=come+stai", "come+stai" },
		{ "neko:ask?q=ciao", "ciao" },
		{ "neko://ASK?q=ciao", "ciao" },
	};
	NSUInteger i, right = 0;
	for(i = 0; i < sizeof(asked) / sizeof(asked[0]); i++) {
		NSString *got = [NekoDoors questionInURL:
			[NSURL URLWithString:[NSString stringWithUTF8String:asked[i].url]]];
		if([got isEqualToString:[NSString stringWithUTF8String:asked[i].want]])
			right++;
		else
			printf("      %s → %s\n", asked[i].url, [(got ?: @"nothing") UTF8String]);
	}
	ok(right == 4, @"the question comes out of the address", nil);

	const char *refused[] = {
		"neko://run?q=rm%20-rf",          /* a verb that is not ask */
		"neko://ask",                      /* nothing asked */
		"neko://ask?q=",                   /* likewise */
		"https://example.com/ask?q=ciao",  /* not ours at all */
		"neko://ask?other=ciao",           /* the wrong parameter */
	};
	NSUInteger quiet = 0;
	for(i = 0; i < sizeof(refused) / sizeof(refused[0]); i++)
		if([NekoDoors questionInURL:[NSURL URLWithString:
		        [NSString stringWithUTF8String:refused[i]]]] == nil)
			quiet++;
		else
			printf("      let through: %s\n", refused[i]);
	ok(quiet == 5, @"and anything else gets nothing",
		[NSString stringWithFormat:@"%lu of 5 refused", (unsigned long)quiet]);

	/* A question long enough to be somebody's document is not a question. */
	NSMutableString *huge = [NSMutableString stringWithString:@"neko://ask?q="];
	NSUInteger n;
	for(n = 0; n < 700; n++)
		[huge appendString:@"a"];
	ok([NekoDoors questionInURL:[NSURL URLWithString:huge]] == nil,
		@"nor does a URL carrying a whole document", nil);

	printf("\n--- and it is asked back before it is asked ---\n");

	/* The rule that makes this door safe: a question from outside is a proposal,
	   in the same bubble and with the same yes as a deed. */
	NekoAsk *ask = [NekoAsk sharedAsk];
	Ivar found = class_getInstanceVariable([NekoAsk class], "bubble");
	NekoBubble *bubble = (NekoBubble *)object_getIvar(ask, found);
	[ask cancelEverything];
	[ask proposeQuestion:@"che ore sono"];
	spin(0.5);

	NSMutableString *shown = [NSMutableString string];
	BOOL buttons = NO;
	NSEnumerator *views = [[[bubble contentView] subviews] objectEnumerator];
	NSView *view;
	while((view = [views nextObject]) != nil) {
		if([view isKindOfClass:[NSButton class]] && ![view isHidden])
			buttons = YES;
		if([view isKindOfClass:[NSTextField class]])
			[shown appendFormat:@"%@ ", [(NSTextField *)view stringValue]];
	}
	ok([shown rangeOfString:@"che ore sono"].location != NSNotFound,
		@"the question is shown before anything is asked", shown);
	ok(buttons, @"with a yes and a no on it", nil);

	[bubble performSelector:@selector(dismissByClick)];
	spin(0.8);
	NSMutableString *after = [NSMutableString string];
	NSEnumerator *later = [[[bubble contentView] subviews] objectEnumerator];
	while((view = [later nextObject]) != nil)
		if([view isKindOfClass:[NSTextField class]])
			[after appendFormat:@"%@ ", [(NSTextField *)view stringValue]];
	/* Not "it is not busy": saying "all right, I will not" is itself a moment of
	   being busy, and the first version of this check failed for that reason.
	   What matters is that it declined rather than went and asked. */
	ok([after rangeOfString:NSLocalizedString(@"All right, I will not.", nil)].location
	       != NSNotFound,
		@"and dismissing it declines instead of asking", after);
	[ask cancelEverything];

	int result = NekoTestResult();
	[pool release];
	return result;
}
