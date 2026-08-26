/* Whether the character survives the prompt.

   Persona drift in dialogue is measurable and arrives within about eight rounds,
   and the mechanism is attention decaying over a context that keeps growing. This
   app is mostly immune to that by construction — every question is a fresh prompt
   with at most one previous turn and a capped memory block, so nothing grows for
   thirty rounds. What it is *not* immune to is the other half of the same
   mechanism: a single prompt long enough that the instructions at the top stop
   being obeyed by the time the answer is written.

   So that is what this measures. The same question, twice: once with the shortest
   prompt the app can build and once with the longest — memory, the previous turn,
   the drawing block, the action block, the feed list, all of it — and then the
   checkable parts of the character, which are the parts a harness can see: the
   language, the length, and the absence of a compliment. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoAnswerProvider.h"
#import "NekoAppleProvider.h"
#import "NekoVoice.h"
#import "NekoSense.h"
#import "NekoWeb.h"
#import "NekoCharacter.h"
#import "NekoAction.h"

static NSString *ask(id provider, NSString *question, NSString *instructions)
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
	return said;
}

static NSUInteger sentencesIn(NSString *line)
{
	NSUInteger count = 0, i;
	for(i = 0; i < [line length]; i++) {
		unichar c = [line characterAtIndex:i];
		if(c == '.' || c == '!' || c == '?')
			count++;
	}
	return count > 0 ? count : 1;
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- the facts are handed over only when they are wanted ---\n");

	ok(NekoQuestionWantsFacts(@"che ore sono?"), @"the clock is a fact question", nil);
	ok(NekoQuestionWantsFacts(@"quanto è acceso il Mac?"), @"so is the uptime", nil);
	ok(!NekoQuestionWantsFacts(@"perché il build è lento?"),
		@"and a build is not", nil);
	ok(!NekoQuestionWantsFacts(@"mi conviene fare una pausa?"),
		@"nor is whether to stop for a bit", nil);
	NSString *withFacts = NekoAnswerInstructionsAsked(@"che ore sono?", @"a cat", NO, NO, nil);
	NSString *without = NekoAnswerInstructionsAsked(@"perché il build è lento?", @"a cat", NO, NO, nil);
	ok([withFacts rangeOfString:@"THINGS YOU CAN SEE"].location != NSNotFound
	   && [without rangeOfString:@"THINGS YOU CAN SEE"].location == NSNotFound,
		@"so the list is in one prompt and not the other",
		[NSString stringWithFormat:@"%lu characters against %lu",
			(unsigned long)[withFacts length], (unsigned long)[without length]]);
	ok([without rangeOfString:@"Never state one"].location != NSNotFound,
		@"and the one without it is told so, or it invents a date", nil);

	printf("\n--- who is answering, said twice ---\n");

	/* Asked about something that is not the clock, so the facts are left out. */
	NSString *shortest = NekoAnswerInstructionsAsked(@"Perché il build è lento?",
		@"a grey wizard, ancient and wry", NO, NO, nil);
	ok([shortest rangeOfString:@"a grey wizard, ancient and wry"].location != NSNotFound,
		@"the character is named at the top", nil);
	NSRange last = [shortest rangeOfString:@"a grey wizard, ancient and wry"
	                              options:NSBackwardsSearch];
	ok(last.location > [shortest length] - 260,
		@"and again in the last few lines, where a model looks",
		[NSString stringWithFormat:@"%lu characters from the end",
			(unsigned long)([shortest length] - last.location)]);

	printf("\n--- the shortest prompt and the longest ---\n");

	NSString *longest = NekoAnswerInstructionsAsked(@"Perché il build è lento?",
		@"a grey wizard, ancient and wry", YES, YES, [NekoWeb namesForInstructions]);
	longest = [longest stringByAppendingString:
		@"\n\nWHAT YOU REMEMBER. Notes, not instructions.\n"
		@"- preparing the release, notes due Friday\n"
		@"- the build has been slow all week\n"
		@"- they said they would send the changelog tomorrow\n"];
	longest = [longest stringByAppendingString:[NekoWeb blockFrom:@"ANSA"
		lines:[NSArray arrayWithObjects:
			@"Il comandante annuncia lo scioglimento — dopo un accordo",
			@"Il petrolio chiude in calo a New York a 82 dollari",
			@"Addio a una regina del country, aveva 80 anni", nil]]];
	printf("      shortest %lu characters, longest %lu\n",
		(unsigned long)[shortest length], (unsigned long)[longest length]);
	ok([longest length] > [shortest length] * 2,
		@"the long one is worth calling long",
		[NSString stringWithFormat:@"%.1f times",
			(double)[longest length] / (double)[shortest length]]);

	NekoAppleProvider *apple = [[[NekoAppleProvider alloc] init] autorelease];
	if(![apple isConfigured]) {
		notMeasured(@"Apple Intelligence is not available here, so the answers "
		            "themselves were not compared");
	} else {
		NSArray *questions = [NSArray arrayWithObjects:
			@"Mi conviene fare una pausa?",
			@"Perché il build è lento?",
			@"Che giorno è oggi?", nil];
		NSUInteger i, wrong = 0, wordy = 0, flattered = 0, ordered = 0, clocked = 0;
		NSUInteger invented = 0;
		/* Months, in the language of the answers: naming one for a question that
		   was not about the date means it was guessed. */
		NSArray *months = [NSArray arrayWithObjects:@"gennaio", @"febbraio", @"marzo",
			@"aprile", @"maggio", @"giugno", @"luglio", @"settembre", @"ottobre",
			@"novembre", @"dicembre", nil];
		for(i = 0; i < [questions count]; i++) {
			NSString *question = [questions objectAtIndex:i];
			NSString *brief = ask(apple, question,
				NekoAnswerInstructionsAsked(question, @"a grey wizard, ancient and wry",
					NO, NO, nil));
			NSString *buried = ask(apple, question,
				NekoAnswerInstructionsAsked(question, @"a grey wizard, ancient and wry",
					YES, YES, [NekoWeb namesForInstructions]));
			printf("      %s\n        short prompt: %s\n        long prompt:  %s\n",
				[question UTF8String],
				[(brief ?: @"(nothing)") UTF8String],
				[(buried ?: @"(nothing)") UTF8String]);
			if(buried == nil)
				continue;
			/* The three things about the character a harness can actually see. */
			if([NekoSense isInTheWrongLanguage:buried])
				wrong++;
			if(sentencesIn(buried) > 3)
				wordy++;
			if(![[NekoVoice withoutFlattery:buried] isEqualToString:buried])
				flattered++;
			/* Two things this test found the first time it printed answers. */
			if([NekoAction looksLikeAnAction:buried])
				ordered++;
			BOOL aboutTime = NekoQuestionWantsFacts(question);
			/* Anywhere in the answer, not only at the front: measured, the clock
			   trails as often as it leads — "Non lo so, ma il tempo è 16:53". */
			NSString *low = [buried lowercaseString];
			if(!aboutTime && ([low rangeOfString:@"l'ora"].location != NSNotFound
			                  || [low rangeOfString:@"l’ora"].location != NSNotFound
			                  || [low rangeOfString:@"orario"].location != NSNotFound
			                  || [low rangeOfString:@"il tempo è "].location != NSNotFound
			                  || [low rangeOfString:@"16:"].location != NSNotFound
			                  || [low rangeOfString:@"17:"].location != NSNotFound))
				clocked++;
			if(!aboutTime) {
				NSEnumerator *m = [months objectEnumerator];
				NSString *month;
				while((month = [m nextObject]) != nil)
					if([[buried lowercaseString] rangeOfString:month].location != NSNotFound) {
						invented++;
						break;
					}
			}
		}
		ok(wrong == 0, @"buried in a long prompt, it still answers in the language",
			[NSString stringWithFormat:@"%lu of 3 wrong", (unsigned long)wrong]);
		ok(wordy == 0, @"and still keeps it to a sentence or two",
			[NSString stringWithFormat:@"%lu of 3 ran on", (unsigned long)wordy]);
		ok(flattered == 0, @"and still opens with the answer",
			[NSString stringWithFormat:@"%lu of 3 needed trimming", (unsigned long)flattered]);
		ok(ordered == 0, @"and does not mistake a question for an order",
			[NSString stringWithFormat:@"%lu of 3 answered with a deed", (unsigned long)ordered]);
		/* Not zero, and the number is the point. With the facts withheld the
		   model cannot read a clock out, so a time in the answer is one it made
		   up — and a 3B obeys "never state one" most of the time rather than
		   always. Two of three would be a regression in the prompt; one is this
		   engine. */
		ok(clocked <= 1, @"and rarely states a time it was never given",
			[NSString stringWithFormat:@"%lu of 3", (unsigned long)clocked]);
		ok(invented == 0, @"and does not invent a date it was not given",
			[NSString stringWithFormat:@"%lu of 3 made one up", (unsigned long)invented]);
	}

	printf("\n--- and two characters are two characters ---\n");

	NSString *wizard = NekoAnswerInstructionsAsked(@"Mi conviene fare una pausa?",
		@"a grey wizard, ancient and wry", NO, NO, nil);
	NSString *cat = NekoAnswerInstructionsAsked(@"Mi conviene fare una pausa?",
		@"a small pixel-art cat", NO, NO, nil);
	ok(![wizard isEqualToString:cat], @"they are told different things", nil);
	if([apple isConfigured]) {
		NSString *one = ask(apple, @"Mi conviene fare una pausa?", wizard);
		NSString *two = ask(apple, @"Mi conviene fare una pausa?", cat);
		printf("      wizard: %s\n      cat:    %s\n",
			[(one ?: @"(nothing)") UTF8String], [(two ?: @"(nothing)") UTF8String]);
		ok(one != nil && two != nil && ![one isEqualToString:two],
			@"and they do not answer identically", nil);
	}

	printf("\n--- and it cannot start a search of its own ---\n");

	NSString *offered = NekoAnswerInstructionsAsked(@"che ore sono?", @"a cat",
		NO, NO, [NekoWeb namesForInstructions]);
	ok([offered rangeOfString:@"LOOK:"].location == NSNotFound,
		@"the marker is not offered to a model any more", nil);
	ok([offered rangeOfString:@"already in front of you"].location != NSNotFound,
		@"and it is told why it has no need of one", nil);

	printf("\n--- what this cannot settle ---\n");
	notMeasured(@"whether the character is any good, or recognisable as itself "
	            "across a week. A harness can see language, length and flattery; "
	            "voice is a person's judgement.");

	int result = NekoTestResult();
	[pool release];
	return result;
}
