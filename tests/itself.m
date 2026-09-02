/* What the cat knows about itself, and how little of it is a model's business.

   The first piece of docs/self.md. That document's finding is that the field's
   "self-awareness" — a 13,000-question benchmark over sixteen models — measures
   whether a model knows it is a language model and whether it is being tested,
   which is the one self a pixel cat exists in order not to have. What it should
   know is where it lives, since when, and how long since you last spoke to it.

   And every one of those is a subtraction over a timestamp or a rectangle, which
   is the point: on the largest temporal benchmark, putting events in order sits
   below 30% across 24 models, and this application measured three of its own at
   one of nine with the date already in the prompt. So nothing here asks an
   engine anything, and this harness needs none. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoSelf.h"
#import "NekoMemory.h"
#import "NekoController.h"
#import "MyPanel.h"

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NekoMemory *memory = [NekoMemory sharedMemory];

	NSString *lives = [[NSSearchPathForDirectoriesInDomains(
		NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject]
		stringByAppendingPathComponent:@"Neko/Memory"];
	if([[[memory directory] path] isEqualToString:lives]) {
		notMeasured(@"this harness stamps dates and will not do it in the real "
		            @"diary — run it through tests/run.sh");
		return NekoTestResult();
	}

	printf("\n--- where it is: nine parts of a screen, by its own middle ---\n");

	/* A panel put in each corner in turn. The point of interest is that this is
	   the cat's own midpoint — not the pointer's, not the front window's. */
	MyPanel *panel = [[MyPanel alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 32.0, 32.0)
	                                            styleMask:NSWindowStyleMaskBorderless
	                                              backing:NSBackingStoreBuffered
	                                                defer:NO];
	[[NekoController sharedController] setPanel:panel];

	NSRect room = [[NSScreen mainScreen] visibleFrame];
	NSArray *corners = [NSArray arrayWithObjects:
		[NSValue valueWithPoint:NSMakePoint(NSMinX(room) + 10.0, NSMinY(room) + 10.0)], @"bottom left",
		[NSValue valueWithPoint:NSMakePoint(NSMidX(room) - 16.0, NSMinY(room) + 10.0)], @"at the bottom",
		[NSValue valueWithPoint:NSMakePoint(NSMaxX(room) - 42.0, NSMinY(room) + 10.0)], @"bottom right",
		[NSValue valueWithPoint:NSMakePoint(NSMinX(room) + 10.0, NSMidY(room) - 16.0)], @"on the left",
		[NSValue valueWithPoint:NSMakePoint(NSMidX(room) - 16.0, NSMidY(room) - 16.0)], @"in the middle",
		[NSValue valueWithPoint:NSMakePoint(NSMaxX(room) - 42.0, NSMidY(room) - 16.0)], @"on the right",
		[NSValue valueWithPoint:NSMakePoint(NSMinX(room) + 10.0, NSMaxY(room) - 42.0)], @"top left",
		[NSValue valueWithPoint:NSMakePoint(NSMidX(room) - 16.0, NSMaxY(room) - 42.0)], @"at the top",
		[NSValue valueWithPoint:NSMakePoint(NSMaxX(room) - 42.0, NSMaxY(room) - 42.0)], @"top right",
		nil];
	NSUInteger i;
	for(i = 0; i < [corners count]; i += 2) {
		NSPoint where = [[corners objectAtIndex:i] pointValue];
		NSString *wanted = NSLocalizedString([corners objectAtIndex:i + 1], nil);
		[panel setFrame:NSMakeRect(where.x, where.y, 32.0, 32.0) display:NO];
		NSString *said = [NekoSelf whereItIs];
		ok(said != nil && [said rangeOfString:wanted].location != NSNotFound,
			[NSString stringWithFormat:@"%.0f,%.0f", where.x, where.y],
			said ?: @"(nothing)");
	}

	printf("\n--- and it is the cat's position, not the pointer's ---\n");

	/* Two different places, two different answers, with nothing else changed:
	   that is what makes it a fact about the cat. */
	[panel setFrame:NSMakeRect(NSMinX(room) + 10.0, NSMinY(room) + 10.0, 32.0, 32.0)
	        display:NO];
	NSString *low = [NekoSelf whereItIs];
	[panel setFrame:NSMakeRect(NSMaxX(room) - 42.0, NSMaxY(room) - 42.0, 32.0, 32.0)
	        display:NO];
	NSString *high = [NekoSelf whereItIs];
	ok(low != nil && high != nil && ![low isEqualToString:high],
		@"moving the cat changes the answer",
		[NSString stringWithFormat:@"“%@” then “%@”", low, high]);

	printf("\n--- how long it has been here ---\n");

	NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
	id metBefore = [[[settings objectForKey:@"NekoMemoryMetOn"] copy] autorelease];
	id heardBefore = [[[settings objectForKey:@"NekoMemoryLastHeard"] copy] autorelease];

	[settings setObject:[NSDate date] forKey:@"NekoMemoryMetOn"];
	ok([NekoSelf daysHere] == 0, @"met today is nought days",
		[NSString stringWithFormat:@"%ld", (long)[NekoSelf daysHere]]);
	ok([[NekoSelf wantedFor:@"da quanto sei qui?"] length] > 0,
		@"and it still has something to say about it",
		[NekoSelf wantedFor:@"da quanto sei qui?"]);

	[settings setObject:[NSDate dateWithTimeIntervalSinceNow:-43.0 * 86400.0]
	             forKey:@"NekoMemoryMetOn"];
	ok([NekoSelf daysHere] == 43, @"forty-three days ago is forty-three days",
		[NSString stringWithFormat:@"%ld", (long)[NekoSelf daysHere]]);
	NSString *since = [NekoSelf wantedFor:@"da quanto ci conosciamo?"];
	printf("      %s\n", [(since ?: @"(nothing)") UTF8String]);
	/* The nil guard is not decoration. The first draft of this check was
	   `[since rangeOfString:@"43"].location != NSNotFound`, the recogniser did
	   not hold that phrasing, `since` was nil — and the check **passed**, because
	   -rangeOfString: on nil answers {0,0} and zero is not NSNotFound. This
	   project has been caught by that exact arithmetic once before, in the verb
	   matcher, and it is written down in NekoPluginVerbs for the same reason. */
	ok(since != nil && [since rangeOfString:@"43"].location != NSNotFound,
		@"and it says so, with the day it began", since ?: @"(nothing)");

	/* The stamp is the point: an installation whose old day files have been
	   pruned still knows, where counting files would say thirty. */
	ok([NekoSelf daysHere] > (NSInteger)[memory dayCount],
		@"more days than there are day files, which is why it is a stamp",
		[NSString stringWithFormat:@"%ld days, %lu files",
			(long)[NekoSelf daysHere], (unsigned long)[memory dayCount]]);

	printf("\n--- how long since you said anything ---\n");

	[settings removeObjectForKey:@"NekoMemoryLastHeard"];
	ok([NekoSelf howLongSinceHeard] == nil,
		@"nothing heard is nothing to subtract", nil);
	ok([[NekoSelf wantedFor:@"da quanto non ci parliamo?"] length] > 0,
		@"and the question still gets an answer",
		[NekoSelf wantedFor:@"da quanto non ci parliamo?"]);

	[memory noteHeard:@"zzq-self una domanda qualunque"];
	ok([[NekoMemory sharedMemory] lastHeard] != nil,
		@"asking something stamps the moment", nil);
	NSString *justNow = [NekoSelf wantedFor:@"da quanto non ci parliamo?"];
	printf("      %s\n", [justNow UTF8String]);
	ok([justNow length] > 0, @"which reads as just now", justNow);

	[settings setObject:[NSDate dateWithTimeIntervalSinceNow:-3.0 * 86400.0]
	             forKey:@"NekoMemoryLastHeard"];
	NSString *awhile = [NekoSelf wantedFor:@"da quanto non ci parliamo?"];
	printf("      %s\n", [awhile UTF8String]);
	ok(awhile != nil && justNow != nil && ![awhile isEqualToString:justNow]
	   && [awhile rangeOfString:@"3"].location != NSNotFound,
		@"and three days later reads as three days, not seventy-two hours",
		awhile ?: @"(nothing)");

	printf("\n--- and the half that is the work: what it is not asked ---\n");

	NSArray *not = [NSArray arrayWithObjects:
		/* the same words, about the person or the machine */
		@"dove sono le mie cartelle?", @"dove ho salvato il file?",
		@"dove sono i modelli?", @"da quanto è acceso il mac?",
		@"da quanto sono in Xcode?", @"quanto manca a venerdì?",
		@"che ore sono?", @"dove si trova Roma?",
		/* and things that are about it but are somebody else's business */
		@"cosa avevo detto del contratto?", @"quanto vale Apple in borsa?",
		@"chi sei?", @"come stai?",
		nil];
	NSEnumerator *e = [not objectEnumerator];
	NSString *sentence;
	while((sentence = [e nextObject]) != nil)
		ok([NekoSelf wantedFor:sentence] == nil, sentence,
			[NekoSelf wantedFor:sentence] ?: @"left alone");

	printf("\n--- and none of this is in the prompt ---\n");

	/* Deliberate, and measured elsewhere: the block is already a thousand
	   characters, and Völkel's second factor for conversational agents has
	   *egocentric* among its top descriptors. A cat handed its own biography
	   before every answer is a cat that talks about itself. */
	NSString *provider = [NSString stringWithContentsOfFile:@"src/NekoAnswerProvider.m"
		encoding:NSUTF8StringEncoding error:NULL];
	ok(provider != nil && [provider rangeOfString:@"NekoSelf"].location == NSNotFound,
		@"the facts block does not carry it", nil);
	NSString *chain = [NSString stringWithContentsOfFile:@"src/NekoAsk.m"
		encoding:NSUTF8StringEncoding error:NULL];
	ok(chain != nil && [chain rangeOfString:@"[NekoSelf wantedFor:question]"].location
	   != NSNotFound,
		@"and it is answered in code, before any engine", nil);

	notMeasured(@"what this cannot check is whether being told any of it is worth "
	            @"hearing. It can say the numbers are right and that no model was "
	            @"asked for them");

	if(metBefore != nil)
		[settings setObject:metBefore forKey:@"NekoMemoryMetOn"];
	else
		[settings removeObjectForKey:@"NekoMemoryMetOn"];
	if(heardBefore != nil)
		[settings setObject:heardBefore forKey:@"NekoMemoryLastHeard"];
	else
		[settings removeObjectForKey:@"NekoMemoryLastHeard"];

	[pool release];
	return NekoTestResult();
}
