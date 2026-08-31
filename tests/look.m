/* Reading the screen, granted for a stretch of time rather than for ever.

   The switch this replaces was the one standing grant in an application that asks
   per use everywhere else — a folder in a panel, a deed read back, a verb
   re-checked at the moment of doing. It was not a hole; it was a switch somebody
   set on purpose. But a permission you have to remember to revoke is one careful
   people decline permanently, which left the feature off for exactly the people
   this is built for.

   What matters here is not that it can look. It is that it stops: measured from
   the side that reads, not from the label in the menu, because a countdown that
   says zero while something is still reading is worse than no countdown. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoGlance.h"
#import "NekoDesktop.h"

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NekoGlance *glance = [NekoGlance sharedGlance];
	[glance stop];

	printf("\n--- what asks for a look, and what does not ---\n");

	struct { const char *said; double want; } asked[] = {
		{ "guarda cosa sto facendo", 600 },
		{ "guarda per dieci minuti", 600 },
		{ "guarda quello che scrivo per 5 minuti", 300 },
		{ "dai un'occhiata", 600 },
		{ "look at what I am doing", 600 },
		{ "watch what I do for 5 minutes", 300 },
		{ "regarde ce que je fais", 600 },
		{ "mira lo que estoy haciendo", 600 },
	};
	NSUInteger i, right = 0, total = sizeof(asked) / sizeof(asked[0]);
	NSMutableString *wrong = [NSMutableString string];
	for(i = 0; i < total; i++) {
		double got = [NekoGlance wantedFor:
			[NSString stringWithUTF8String:asked[i].said]];
		if(fabs(got - asked[i].want) < 0.5)
			right++;
		else
			[wrong appendFormat:@"%s → %.0f (wanted %.0f); ", asked[i].said, got,
				asked[i].want];
	}
	ok(right == total, [NSString stringWithFormat:
		@"all %lu ways of asking are understood", (unsigned long)total], wrong);

	/* The half that matters, and the one the timer's table taught: every sentence
	   with the word for looking in it that is not a request to read the screen. */
	const char *notAsked[] = {
		"guarda che ore sono",
		"guarda un po' chi si vede",
		"guarda le notizie",
		"guarda il meteo a Roma",
		"look at the time",
		"che cosa stai guardando?",
		"metti un timer di 10 minuti",
		"ricordati che il venerdì stacco prima",
		"fra dieci minuti",
		"quanto fa sette per otto",
	};
	NSUInteger quiet = 0, ordinary = sizeof(notAsked) / sizeof(notAsked[0]);
	NSMutableString *misfired = [NSMutableString string];
	for(i = 0; i < ordinary; i++) {
		double got = [NekoGlance wantedFor:
			[NSString stringWithUTF8String:notAsked[i]]];
		if(got == 0.0)
			quiet++;
		else
			[misfired appendFormat:@"%s → %.0f s; ", notAsked[i], got];
	}
	ok(quiet == ordinary, [NSString stringWithFormat:
		@"and none of %lu ordinary sentences starts one",
		(unsigned long)ordinary], misfired);

	ok([NekoGlance wantedFor:@"guarda per dieci ore"] <= 3600.0,
		@"nor can anybody ask for a whole day of it",
		[NSString stringWithFormat:@"%.0f s",
			[NekoGlance wantedFor:@"guarda per dieci ore"]]);

	printf("\n--- and it stops, measured where it reads ---\n");

	if(![NekoDesktop accessibilityGranted]) {
		notMeasured(@"Accessibility is not granted here, so a stretch refuses to "
			@"start and there is nothing to time out — which is itself the right "
			@"behaviour and is checked below");
		NSString *said = [glance lookFor:2.0];
		ok([said length] > 0 && ![glance isLooking],
			@"it says it would need the permission, and does not pretend to look",
			said);
	} else {
		NSString *said = [glance lookFor:2.0];
		ok([said length] > 0, @"it says how long it will look for", said);
		ok([glance isLooking], @"and it is looking", nil);
		ok([[NekoDesktop sharedDesktop] readsText],
			@"which is what the desktop asks before reading anything", nil);
		ok([[glance menuTitle] length] > 0, @"and the menu carries it",
			[glance menuTitle]);

		NSDate *until = [NSDate dateWithTimeIntervalSinceNow:8.0];
		while([glance isLooking] && [until timeIntervalSinceNow] > 0.0)
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
			                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];

		/* The check the whole design exists for, and asked of the reader rather
		   than of the label: after the stretch, the desktop must refuse. */
		ok(![glance isLooking], @"two seconds later it has stopped by itself", nil);
		ok(![[NekoDesktop sharedDesktop] readsText],
			@"and the desktop will not read anything any more", nil);
		ok([glance menuTitle] == nil, @"and the menu says nothing", nil);
	}

	printf("\n--- and there is only one way to grant it ---\n");

	/* The switch is retired, not kept beside the stretch: two ways to grant the
	   same thing, one of them permanent, is how somebody grants the permanent one
	   by accident. Read from the source, because the defect would be a line
	   somebody adds back. */
	NSString *desktop = [NSString stringWithContentsOfFile:@"src/NekoDesktop.m"
	                                              encoding:NSUTF8StringEncoding
	                                                 error:NULL];
	ok([desktop length] > 0, @"the source is where the test expects it", nil);
	NSRange reads = [desktop rangeOfString:@"- (BOOL)readsText"];
	NSString *body = reads.location != NSNotFound
		? [desktop substringWithRange:NSMakeRange(reads.location,
			MIN((NSUInteger)400, [desktop length] - reads.location))] : @"";
	ok([body rangeOfString:@"NekoGlance"].location != NSNotFound,
		@"reading is gated on the stretch", nil);
	ok([body rangeOfString:@"NekoReadTextKey"].location == NSNotFound,
		@"and no longer on a switch that stays on", nil);
	/* And the key itself is gone rather than left declared and unread, which is
	   the state somebody would have to work out was dead. */
	ok([desktop rangeOfString:@"NekoReadTextKey"].location == NSNotFound,
		@"and the setting it used does not exist any more at all", nil);

	[glance stop];
	int result = NekoTestResult();
	[pool release];
	return result;
}
