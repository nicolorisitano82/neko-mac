/* Does reading the screen make the remarks any better?

   Nobody has ever asked. docs/one-look-roadmap.md is the argument for asking
   before reshaping the permission, and this is the experiment it names.

   The whole present value of screen reading is here and nowhere else: `nearbyText`
   has one caller, that caller is `NekoDesktop summary`, and the summary has two
   consumers — the remarks the advisor makes unasked and the curious questions the
   antics ask. So the question is narrow and answerable: given the same desktop and
   the same character, is the one sentence a model produces **different, and
   better,** when the text somebody is typing is in front of it?

   What this harness can decide is whether the remark **uses** what was read. What
   it cannot decide is whether that made it better, so it prints all of them and
   says so: a person reads the output once and settles it. That is the honest
   division of labour and it is the same one tests/persona.m draws.

   It asks a model twenty times, so it runs its full length only with --slow.
   Without it, four contexts, which is enough to know the machinery works. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoBrains.h"
#import "NekoAnswerProvider.h"
#import "NekoSense.h"

/* The same helper tests/persona.m uses: ask, and wait for the answer on the run
   loop rather than by sleeping, because the engine answers on the main thread. */
static NSString *askEngine(id provider, NSString *question, NSString *instructions)
{
	__block NSString *said = nil;
	__block BOOL done = NO;
	[provider askQuestion:question instructions:instructions
	          completion:^(NSString *text, NSError *error) {
		said = [text retain];
		done = YES;
	}];
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:90.0];
	while(!done && [until timeIntervalSinceNow] > 0.0)
		spin(0.05);
	return [said autorelease];
}

/* The summary is built here in the shape NekoDesktop builds it, rather than by
   staging a desktop: what is under test is what a model does with those lines,
   and a real desktop would give the same lines with less control. */
static NSString *contextWith(NSString *app, int minutes, int programs,
                             int keys, int idle, NSString *text)
{
	NSMutableString *lines = [NSMutableString string];
	[lines appendString:@"Here is what I seem to be doing right now.\n"];
	[lines appendFormat:@"The program in front of me: %@\n", app];
	[lines appendFormat:@"Minutes I have been in it: %d\n", minutes];
	[lines appendFormat:@"Different programs I have used in the last 15 minutes: %d\n",
		programs];
	[lines appendFormat:@"Keys a minute: %d, mouse moves a minute: %d\n", keys, keys / 2];
	[lines appendFormat:@"Seconds since my last key or click: %d\n", idle];
	[lines appendString:@"Local time: 15:40\n"];
	if(text != nil)
		[lines appendFormat:@"The text I am working on ends like this: %@\n", text];
	[lines appendFormat:@"\nThe one thing that stands out: %d minutes in %@\n",
		minutes, app];
	return lines;
}

/* Did the remark use what it read? Answered by the words: a word of four letters
   or more from the text, that is not in the rest of the context, turning up in
   the remark. Crude, and stated as crude — the printing is what settles it. */
static BOOL usedTheText(NSString *remark, NSString *text, NSString *without)
{
	if([remark length] == 0 || [text length] == 0)
		return NO;
	NSCharacterSet *breaks = [NSCharacterSet characterSetWithCharactersInString:
		@" \t\n\r,.;:!?\"'()[]{}<>/\\-_=+*"];
	NSEnumerator *e = [[text componentsSeparatedByCharactersInSet:breaks]
		objectEnumerator];
	NSString *word;
	while((word = [e nextObject]) != nil) {
		if([word length] < 4)
			continue;
		NSString *low = [word lowercaseString];
		if([[without lowercaseString] rangeOfString:low].location != NSNotFound)
			continue;              /* it was already in the rest of the context */
		if([[remark lowercaseString] rangeOfString:low].location != NSNotFound)
			return YES;
	}
	return NO;
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	BOOL slow = [[NSUserDefaults standardUserDefaults] boolForKey:@"slow"];

	id<NekoAnswerProvider> engine = [NekoBrains bestOnDeviceProvider];
	if(engine == nil || ![engine isConfigured]) {
		notMeasured(@"there is no engine on this Mac that stays on it, so the "
			@"remarks cannot be asked for at all");
		int early = NekoTestResult();
		[pool release];
		return early;
	}

	struct { const char *app; int minutes; int programs; int keys; int idle;
	         const char *text; } staged[] = {
		{ "Xcode", 47, 2, 90, 1,
		  "static NSTimeInterval NekoTimerPatience = 8.0; /* eight, not twenty */" },
		{ "Mail", 6, 7, 40, 3,
		  "Buongiorno, le confermo la riunione di venerdì alle 9:30 in sede." },
		{ "Safari", 22, 3, 5, 40,
		  "Come coltivare i pomodori in vaso sul balcone: la guida completa" },
		{ "Terminal", 12, 1, 120, 0,
		  "fatal: refusing to merge unrelated histories" },
		{ "Pages", 95, 1, 70, 2,
		  "Capitolo quarto. Le cause della sconfitta non furono militari ma logistiche." },
		{ "Numbers", 31, 4, 55, 5,
		  "Totale trimestre: 48.200 euro, contro 61.000 dell'anno scorso." },
		{ "Messages", 3, 9, 30, 2,
		  "ok allora ci vediamo lì alle otto, porto io il vino" },
		{ "Music", 140, 1, 2, 300, "Lucio Battisti — Il mio canto libero" },
		{ "Calendar", 4, 5, 20, 8,
		  "Dentista, martedì 14:00 — portare la vecchia radiografia" },
		{ "Preview", 18, 2, 8, 25,
		  "Contratto di locazione, articolo 7: il conduttore si impegna a…" },
	};
	NSUInteger many = sizeof(staged) / sizeof(staged[0]);
	if(!slow)
		many = 2;

	printf("\n--- the same desktop, asked twice ---\n");
	printf("    (%lu context%s; run with --slow for all %lu)\n\n",
		(unsigned long)many, many == 1 ? "" : "s",
		(unsigned long)(sizeof(staged) / sizeof(staged[0])));

	NSString *instructions = NekoSuggestionInstructionsFor(
		@"a small pixel-art cat, dry and brief");

	/* A third arm, and the reason this harness exists in the shape it does.
	   The first run of it scored 0 of 10 — not one remark used what was read —
	   and the conclusion nearly drawn from that was "delete the capability".
	   Then the instructions were read.

	   NekoSuggestionInstructionsFor tells the model to talk about the one thing
	   it was told stands out, which is computed from minutes and switching, and
	   then says in so many words: "do not pretend to see inside their files".
	   So the experiment was measuring what the prompt had already decided, and
	   0 of 10 said nothing at all about whether the text is worth reading.

	   So the sentence is conditional now — forbidden when there is nothing to see,
	   permitted when the text is actually in front of it — and this arm asks with
	   the instructions the application now ships when it has read something. The
	   first arm keeps the other half of that condition, which is what a desktop
	   with reading switched off still gets.

	   The finding stands on its own whatever the numbers say: the switch in the
	   preferences was offering a capability the prompt forbade. */
	NSString *permitted = NekoSuggestionInstructionsSeeing(
		@"a small pixel-art cat, dry and brief", YES);
	BOOL replaced = ![permitted isEqualToString:instructions];

	NSUInteger asked = 0, used = 0, differed = 0, sayable = 0, usedWhenAllowed = 0;
	NSUInteger i;
	for(i = 0; i < many; i++) {
		NSString *text = [NSString stringWithUTF8String:staged[i].text];
		NSString *without = contextWith(
			[NSString stringWithUTF8String:staged[i].app], staged[i].minutes,
			staged[i].programs, staged[i].keys, staged[i].idle, nil);
		NSString *with = contextWith(
			[NSString stringWithUTF8String:staged[i].app], staged[i].minutes,
			staged[i].programs, staged[i].keys, staged[i].idle, text);

		NSString *blind = askEngine(engine, without, instructions);
		NSString *seeing = askEngine(engine, with, instructions);
		asked++;

		BOOL sameSentence = [blind length] > 0 && [seeing length] > 0
			&& [blind isEqualToString:seeing];
		if(!sameSentence) differed++;
		if(usedTheText(seeing, text, without)) used++;
		if([NekoSense isWorthSaying:seeing]) sayable++;

		NSString *allowed = replaced
			? askEngine(engine, with, permitted) : nil;
		if(usedTheText(allowed, text, without))
			usedWhenAllowed++;

		printf("  %s, %d min\n", staged[i].app, staged[i].minutes);
		printf("      read:    %.70s\n", staged[i].text);
		printf("      blind:   %s\n", [(blind ?: @"(nothing)") UTF8String]);
		printf("      seeing:  %s%s\n", [(seeing ?: @"(nothing)") UTF8String],
			usedTheText(seeing, text, without) ? "   ← used it" : "");
		printf("      allowed: %s%s\n", [(allowed ?: @"(not run)") UTF8String],
			usedTheText(allowed, text, without) ? "   ← used it" : "");
	}

	printf("\n--- what that adds up to ---\n");
	ok(asked > 0, @"the engine answered at all",
		[NSString stringWithFormat:@"%lu pair(s)", (unsigned long)asked]);
	ok(sayable == asked,
		@"and every remark it made with the text was worth saying at all",
		[NSString stringWithFormat:@"%lu of %lu", (unsigned long)sayable,
			(unsigned long)asked]);

	printf("      used the text, as the prompt stands:  %lu of %lu\n",
		(unsigned long)used, (unsigned long)asked);
	printf("      used it when the prompt allows it:    %lu of %lu\n",
		(unsigned long)usedWhenAllowed, (unsigned long)asked);
	printf("      differed at all:                     %lu of %lu\n",
		(unsigned long)differed, (unsigned long)asked);

	ok(replaced,
		@"the two instructions really do differ — with nothing to see it is "
		@"forbidden from pretending, and with the text in front of it it is not",
		nil);

	/* Deliberately not an assertion. The number this experiment exists to produce
	   is a judgement about whether the remarks are better, and a harness cannot
	   make it — so it produces the number and refuses to pretend. */
	notMeasured([NSString stringWithFormat:
		@"whether the remarks are BETTER for it. As the prompt stands it used the "
		@"text %lu of %lu times, which measures the prompt and not the capability; "
		@"with the forbidding sentence replaced, %lu of %lu. Read the pairs above "
		@"once and settle it — a harness can count words and cannot tell you "
		@"whether a sentence was worth hearing",
		(unsigned long)used, (unsigned long)asked,
		(unsigned long)usedWhenAllowed, (unsigned long)asked]);

	int result = NekoTestResult();
	[pool release];
	return result;
}
