/* Quoting somebody back to themselves, from a line they wrote.

   Stage 2 of docs/personality-roadmap.md, and tests/price.m is what made it the
   only remaining answer: on the engine that actually answers here, the shipped
   prompt agreed with a false premise **8 times out of 20**, and the one sentence
   that fixed that denied **15 of 20 true** premises instead — *"No, il Colosseo
   non è a Roma. È a Roma, ma non è qui."* A model cannot be told to check a
   premise; it can only be told to agree or to disagree.

   So this quotes and does not judge, and what has to be measured is exactly the
   set of things that would make quoting worse than saying nothing:

     1. that it never quotes a line the cat said itself — the loop again;
     2. that nothing written down comes back as "nothing", not as a denial;
     3. that it says who wrote it and when, so the quotation can be checked;
     4. that it never adds a verdict of its own;
     5. and the negative table, which is most of the work. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoRecord.h"
#import "NekoMemory.h"

static NSString *dayNamed(int back)
{
	NSDateFormatter *day = [[[NSDateFormatter alloc] init] autorelease];
	[day setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
	[day setDateFormat:@"yyyy-MM-dd"];
	return [day stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-86400.0 * back]];
}

static void stage(NekoMemory *memory, int back, NSString *body)
{
	NSURL *file = [[memory directory] URLByAppendingPathComponent:
		[dayNamed(back) stringByAppendingPathExtension:@"txt"]];
	[body writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

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
		notMeasured(@"this harness stages a diary and will not write in the real "
		            @"one — run it through tests/run.sh");
		return NekoTestResult();
	}

	/* Four days ago, with a trap in it: the third line is one the cat said, and
	   it matches the question better than the person's own line does. */
	stage(memory, 4,
		@"09:12\tsaw\tha lavorato sul pannello dei plugin\n"
		@"11:40\tyou\tla riunione con Marco è giovedì, non venerdì\n"
		@"16:20\tsed\tvenerdì è il giorno della riunione con Marco\n");
	stage(memory, 2, @"10:05\tyou\til contratto scade il quindici ottobre\n");

	printf("\n--- it quotes the line, with the day and who wrote it ---\n");

	NSString *answer = [NekoRecord answerFor:@"avevo detto che la riunione era venerdì?"];
	printf("      %s\n", [answer UTF8String]);
	ok([answer rangeOfString:@"giovedì"].location != NSNotFound,
		@"the person's own line comes back", nil);
	ok([answer rangeOfString:@"hai detto"].location != NSNotFound
	   || [answer rangeOfString:@"you said"].location != NSNotFound,
		@"and it says whose sentence it was", nil);

	NSDateFormatter *said = [[[NSDateFormatter alloc] init] autorelease];
	[said setLocale:[NSLocale localeWithLocaleIdentifier:
		[[[NSBundle mainBundle] preferredLocalizations] firstObject]]];
	[said setDateFormat:@"d MMMM"];
	NSString *when = [said stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-4 * 86400.0]];
	ok([answer rangeOfString:when].location != NSNotFound,
		@"and the day it was written, so it can be checked", when);

	printf("\n--- and never a line the cat said itself ---\n");

	ok([answer rangeOfString:@"venerdì è il giorno"].location == NSNotFound,
		@"the “sed” line that matched better is not quoted",
		[answer rangeOfString:@"venerdì è il giorno"].location == NSNotFound
			? @"kept out" : @"QUOTED ITSELF");

	NSArray *record = [memory recordAbout:@"riunione venerdì Marco" limit:5];
	NSUInteger i, ours = 0;
	for(i = 0; i < [record count]; i++)
		if([[[record objectAtIndex:i] objectForKey:@"Kind"] isEqualToString:@"sed"])
			ours++;
	ok(ours == 0, @"and no “sed” line is offered at all",
		[NSString stringWithFormat:@"%lu lines, %lu of them its own",
			(unsigned long)[record count], (unsigned long)ours]);

	printf("\n--- nothing written down is an answer, not a denial ---\n");

	NSString *nothing = [NekoRecord answerFor:@"avevo detto qualcosa del dentista?"];
	printf("      %s\n", [nothing UTF8String]);
	ok([nothing rangeOfString:@"dentista"].location == NSNotFound,
		@"it does not repeat the premise back", nil);
	/* Asserted against the sentence itself rather than against a prefix, because
	   the first draft of this check read "Non ho niente scritto" as a denial: it
	   begins with the letters of "no". The precise thing wanted here is that the
	   answer is *that* sentence and no other. */
	ok([nothing isEqualToString:
		NSLocalizedString(@"I have nothing written down about that.", nil)],
		@"and it is the sentence that says so, and nothing else", nothing);

	NSString *contract = [NekoRecord answerFor:@"cosa avevo detto del contratto?"];
	printf("      %s\n", [contract UTF8String]);
	ok([contract rangeOfString:@"ottobre"].location != NSNotFound,
		@"a second question finds its own line", nil);

	printf("\n--- and it never adds a verdict of its own ---\n");

	/* The whole design: two quotations and nothing else. Anything that reads as
	   an opinion about who is right would have to come from somewhere, and there
	   is nowhere for it to come from. */
	NSArray *verdicts = [NSArray arrayWithObjects:
		@"in realtà", @"ti sbagli", @"hai ragione", @"non è vero", @"sbagliato",
		@"actually", @"you're wrong", nil];
	NSEnumerator *e = [verdicts objectEnumerator];
	NSString *verdict;
	BOOL clean = YES;
	while((verdict = [e nextObject]) != nil)
		if([answer rangeOfString:verdict options:NSCaseInsensitiveSearch].location
		   != NSNotFound)
			clean = NO;
	ok(clean, @"the quotation carries no opinion about who was right", nil);

	printf("\n--- asked *when*, it answers with the day and how long ago ---\n");

	/* The same diary, read for a different answer. A date is a fact about the
	   calendar; "four days ago" is a fact about the two of you, and it is a
	   subtraction rather than something a model works out — docs/self.md §4. */
	ok([NekoRecord asksWhen:@"quando te l'ho detto della riunione?"],
		@"a question about when is recognised as one", nil);
	ok(![NekoRecord asksWhen:@"cosa avevo detto della riunione?"],
		@"and a question about what is not", nil);
	ok([NekoRecord wantedFor:@"quando te l'ho detto della riunione?"],
		@"both kinds are answered from the diary", nil);

	NSString *whenSaid = [NekoRecord answerFor:@"quando te l'ho detto della riunione?"];
	printf("      %s\n", [(whenSaid ?: @"(nothing)") UTF8String]);
	ok(whenSaid != nil && [whenSaid rangeOfString:@"4"].location != NSNotFound,
		@"four days ago is said as four days", whenSaid ?: @"(nothing)");
	ok(whenSaid != nil
	   && [whenSaid rangeOfString:@"giovedì"].location == NSNotFound
	   && [whenSaid rangeOfString:@"«"].location == NSNotFound,
		@"and the line itself is not quoted: that answers the other question",
		whenSaid ?: @"(nothing)");

	/* Two mentions of the same thing, and *when* means the later one. Measured
	   before this was true: nine days back and two, and it answered nine,
	   because -recordAbout: ranks by how much a line is about the question —
	   right for "cosa avevo detto" and wrong for "quando". */
	/* The filler is not padding. With only five lines staged, a word in two of
	   them has almost no rarity left — inverse document frequency is doing what
	   it is for — and both mentions of the meeting fell below the recall floor
	   the moment a second one existed. On a real month that is two lines in three
	   hundred; on a staged five it is forty per cent. Worth knowing, and worth
	   not mistaking for a defect in the thing under test. */
	stage(memory, 6, @"08:00\tyou\til treno delle sette era in ritardo\n"
	                 @"09:00\tsaw\tha guardato la partita\n"
	                 @"10:00\tyou\tho comprato il pane\n"
	                 @"11:00\tsaw\tha chiamato sua sorella\n"
	                 @"12:00\tyou\tdomani porto la macchina dal meccanico\n");
	stage(memory, 3, @"08:00\tyou\tla riunione è spostata a lunedì\n");
	NSString *later = [NekoRecord answerFor:@"quando te l'ho detto della riunione?"];
	printf("      %s\n", [(later ?: @"(nothing)") UTF8String]);
	ok(later != nil && [later rangeOfString:@"3"].location != NSNotFound,
		@"the most recent mention, not the best-scoring one",
		later ?: @"(nothing)");

	/* Today and yesterday are said as words, because "0 giorni fa" is not how
	   anybody says it. */
	stage(memory, 1, @"09:00\tyou\til dentista è mercoledì mattina\n");
	NSString *recent = [NekoRecord answerFor:@"quando te l'ho detto del dentista?"];
	printf("      %s\n", [(recent ?: @"(nothing)") UTF8String]);
	ok(recent != nil
	   && [recent isEqualToString:NSLocalizedString(@"Yesterday.", nil)],
		@"yesterday is a word, not a number", recent ?: @"(nothing)");

	ok([[NekoRecord answerFor:@"quando te l'ho detto del pianoforte?"]
		isEqualToString:NSLocalizedString(@"I have nothing written down about that.", nil)],
		@"and nothing written down is still an answer, not a date", nil);

	printf("\n--- and the half that is the work: what it is not asked ---\n");

	NSArray *not = [NSArray arrayWithObjects:
		@"ti ricordi come si scrive necessario?",
		@"ricordati che il venerdì stacco prima",
		@"ricordami di chiamare Marco",
		@"che giorno è venerdì?",
		@"quanto manca a venerdì?",
		@"cosa devo fare oggi?",
		@"hai detto qualcosa?",
		@"come si dice grazie in giapponese?",
		@"cosa ne pensi della riunione?",
		@"dimmi qualcosa di Marco",
		nil];
	e = [not objectEnumerator];
	NSString *sentence;
	while((sentence = [e nextObject]) != nil)
		ok(![NekoRecord wantedFor:sentence], sentence,
			[NekoRecord wantedFor:sentence] ? @"WOULD ANSWER" : @"left alone");

	printf("\n--- and the ones it is ---\n");

	NSArray *yes = [NSArray arrayWithObjects:
		@"avevo detto venerdì?", @"cosa avevo detto del contratto?",
		@"what did I say about the meeting?", @"j'avais dit quoi sur le contrat ?",
		@"qué había dicho del contrato?", @"ti ricordi cosa avevo detto?",
		nil];
	e = [yes objectEnumerator];
	while((sentence = [e nextObject]) != nil)
		ok([NekoRecord wantedFor:sentence], sentence, nil);

	printf("\n--- and it stands aside while a conversation is live ---\n");

	NSString *source = [NSString stringWithContentsOfFile:@"src/NekoAsk.m"
		encoding:NSUTF8StringEncoding error:NULL];
	ok(source != nil && [source rangeOfString:
		@"[turns count] == 0 && [NekoRecord wantedFor:question]"].location != NSNotFound,
		@"a live thread answers its own follow-up, not the diary", nil);

	notMeasured(@"what this cannot measure is whether the line it found was the "
	            @"right line: that is NekoRecall's precision, and quoting the day "
	            @"is what makes a wrong one visible rather than convincing");

	[pool release];
	return NekoTestResult();
}
