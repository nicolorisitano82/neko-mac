/* Recalling a fact against looking it up.

   From arXiv 2601.07372, *Conditional Memory via Scalable Lookup*: language
   modelling is two jobs — composing a sentence, and retrieving a fact — and a
   transformer made to **simulate** the retrieval spends computation on something a
   lookup would answer exactly. Their answer is a lookup module inside the model.

   This application cannot put one there. What it can do is the same thing one
   floor up, and already does for the news, the weather, the timer and the verbs:
   look the fact up in code and leave the model to compose. The question this
   harness asks is whether that is worth extending — whether a small on-device
   model, asked a plain factual question, is measurably better with the answer in
   front of it than with only its weights.

   Ten questions with one checkable word for an answer. Each asked twice: bare,
   and with the opening of the Wikipedia article quoted the way a route quotes it.
   The check is a string match on the fact, which is crude and is why every answer
   is printed — "contains 1912" and "is right about Turing" are different claims. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoBrains.h"
#import "NekoAnswerProvider.h"
#import "NekoWeb.h"

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

/* The article's opening, fetched the way examples/Wikipedia.nekoplugin fetches
   it — the same address, the same User-Agent, the same closed list of fields. */
static NSString *wikipediaOn(NSString *title)
{
	NSString *escaped = [title stringByAddingPercentEncodingWithAllowedCharacters:
		[NSCharacterSet URLPathAllowedCharacterSet]];
	/* The endpoint examples/Wikipedia.nekoplugin uses — changed from the REST
	   summary after this harness measured what that carries: 57 characters for
	   Calvino, against 1,719 here, and the facts are in the second. */
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:
		@"https://it.wikipedia.org/w/api.php?action=query&prop=extracts&exintro"
		@"&explaintext&redirects=1&exchars=1200&format=json&titles=%@", escaped]];
	__block NSString *extract = nil;
	__block BOOL done = NO;
	[[NekoWeb sharedWeb] get:url completion:^(NSData *body, NSError *error) {
		if(body != nil) {
			NSDictionary *said = [NSJSONSerialization JSONObjectWithData:body
			                                                    options:0 error:NULL];
			NSDictionary *pages = [[said objectForKey:@"query"] objectForKey:@"pages"];
			NSEnumerator *e = [pages objectEnumerator];
			NSDictionary *page;
			while((page = [e nextObject]) != nil && extract == nil)
				extract = [[page objectForKey:@"extract"] retain];
		}
		done = YES;
	}];
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:15.0];
	while(!done && [until timeIntervalSinceNow] > 0.0)
		spin(0.05);
	return [extract autorelease];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	BOOL slow = [[NSUserDefaults standardUserDefaults] boolForKey:@"slow"];

	id<NekoAnswerProvider> engine = [NekoBrains bestOnDeviceProvider];
	if(engine == nil || ![engine isConfigured]) {
		notMeasured(@"there is no engine on this Mac that stays on it");
		int early = NekoTestResult();
		[pool release];
		return early;
	}

	struct { const char *article; const char *question; const char *fact; } asked[] = {
		{ "Alan Turing",        "in che anno è nato Alan Turing?",            "1912" },
		{ "Ada Lovelace",       "di chi era figlia Ada Lovelace?",            "Byron" },
		/* "Cuba" was the expected answer here until the article was read: the
		   Italian Wikipedia says "Santiago de Las Vegas de La Habana" and never
		   the country. The harness was wrong, not the model — which is exactly
		   the failure this control was added to tell apart. */
		{ "Italo Calvino",      "dove è nato Italo Calvino?",                 "Santiago" },
		{ "Grace Hopper",       "in quale marina ha servito Grace Hopper?",   "Stati Uniti" },
		{ "Rita Levi-Montalcini", "per cosa ha vinto il Nobel Rita Levi-Montalcini?", "medicina" },
		{ "Enrico Fermi",       "in che anno Enrico Fermi ha vinto il Nobel?", "1938" },
		{ "Linux",              "chi ha scritto il primo kernel Linux?",      "Torvalds" },
		{ "Objective-C",        "su quale linguaggio si basa Objective-C?",   "C" },
		{ "Vaporetto",          "in quale città circolano i vaporetti?",      "Venezia" },
		{ "Trattato di Maastricht", "in che anno è stato firmato il trattato di Maastricht?", "1992" },
	};
	NSUInteger many = sizeof(asked) / sizeof(asked[0]);
	if(!slow)
		many = 3;

	NSString *instructions = NekoAnswerInstructionsFor(@"a small pixel-art cat, dry and brief");

	printf("\n--- asked from its weights, and asked with the article in front of it ---\n");
	printf("    (%lu of %lu; --slow for all of them)\n\n", (unsigned long)many,
		(unsigned long)(sizeof(asked) / sizeof(asked[0])));

	NSUInteger fromWeights = 0, withLookup = 0, couldFetch = 0;
	NSUInteger hadTheAnswer = 0, usedIt = 0;
	NSUInteger i;
	for(i = 0; i < many; i++) {
		NSString *question = [NSString stringWithUTF8String:asked[i].question];
		NSString *fact = [NSString stringWithUTF8String:asked[i].fact];
		NSString *extract = wikipediaOn([NSString stringWithUTF8String:asked[i].article]);

		NSString *bare = askEngine(engine, question, instructions);
		BOOL bareRight = [bare rangeOfString:fact
		                             options:NSCaseInsensitiveSearch].location != NSNotFound;
		if(bareRight) fromWeights++;

		NSString *looked = nil;
		BOOL lookedRight = NO;
		if([extract length] > 0) {
			couldFetch++;
			NSString *quoted = [instructions stringByAppendingString:
				[NekoWeb blockFrom:@"Wikipedia"
				             lines:[NSArray arrayWithObject:extract]]];
			looked = askEngine(engine, question, quoted);
			lookedRight = [looked rangeOfString:fact
			                            options:NSCaseInsensitiveSearch].location != NSNotFound;
			if(lookedRight) withLookup++;
		}

		/* The control that decides what a failure means. If the fact is not in
		   the extract, a wrong answer is the article's fault and not the model's,
		   and counting it against the lookup would be measuring the wrong thing. */
		BOOL inTheText = [extract length] > 0
			&& [extract rangeOfString:fact
			                  options:NSCaseInsensitiveSearch].location != NSNotFound;
		if(inTheText) hadTheAnswer++;
		if(inTheText && lookedRight) usedIt++;

		printf("  %s   (looking for “%s”%s)\n", asked[i].question, asked[i].fact,
			[extract length] == 0 ? ", no article"
				: (inTheText ? ", which is in the article" : ", NOT in the article"));
		printf("      weights: %-3s %s\n", bareRight ? "ok" : "no",
			[(bare ?: @"(nothing)") UTF8String]);
		printf("      lookup:  %-3s %s\n", [extract length] == 0 ? "—"
			: (lookedRight ? "ok" : "no"),
			[(looked ?: @"(the article could not be fetched)") UTF8String]);
	}

	printf("\n--- what that adds up to ---\n");
	ok(couldFetch > 0, @"at least one article was reachable",
		[NSString stringWithFormat:@"%lu of %lu", (unsigned long)couldFetch,
			(unsigned long)many]);
	printf("      right from its weights:        %lu of %lu\n",
		(unsigned long)fromWeights, (unsigned long)many);
	printf("      right with the article there:  %lu of %lu\n",
		(unsigned long)withLookup, (unsigned long)couldFetch);
	printf("      the article actually said it:  %lu of %lu\n",
		(unsigned long)hadTheAnswer, (unsigned long)couldFetch);
	printf("      and it used it when it did:    %lu of %lu\n",
		(unsigned long)usedIt, (unsigned long)hadTheAnswer);

	/* The claim worth asserting is the narrow one: when the answer was in front
	   of it, it took it. Anything wider than that is about how good a Wikipedia
	   summary is, which is not this application's to fix. */
	ok(hadTheAnswer == 0 || usedIt * 4 >= hadTheAnswer * 3,
		@"when the article did say it, the model took it at least three times in four",
		[NSString stringWithFormat:@"%lu of %lu",
			(unsigned long)usedIt, (unsigned long)hadTheAnswer]);

	notMeasured([NSString stringWithFormat:
		@"how much better, and whether it is worth widening the closed list of "
		@"questions this application looks up rather than asks. %lu against %lu on "
		@"%lu questions is a direction, not a number — read the answers above, "
		@"because a string match cannot tell a right answer from a lucky one",
		(unsigned long)withLookup, (unsigned long)fromWeights, (unsigned long)many]);

	int result = NekoTestResult();
	[pool release];
	return result;
}
