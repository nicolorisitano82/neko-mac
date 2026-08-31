/* Whether a model needs help with a clock and a sum.

   Both halves of this were assumed before they were measured, and the assumption
   is the sort that deserves checking: the application already hands the model the
   time, the date and the day of the week in NekoFactsNow, so the flat claim "a
   model asked the date will invent one" is *already false here*. What is not
   settled is what it does with those facts — how many days until Friday is
   arithmetic over dates, and 47×23 is arithmetic, and neither is a thing a four
   billion parameter model does reliably.

   So this asks it, with the real facts block, and counts. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoAnswerProvider.h"
#import "NekoLocalProvider.h"
#import "NekoModelStore.h"
#import "NekoSums.h"
#import "NekoClock.h"

static NSString *ask(id provider, NSString *question, NSString *instructions)
{
	__block NSString *said = nil;
	__block BOOL done = NO;
	[provider askQuestion:question instructions:instructions
	          completion:^(NSString *text, NSError *error) {
		said = [text retain];
		done = YES;
	}];
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:120.0];
	while(!done && [until timeIntervalSinceNow] > 0.0)
		spin(0.05);
	return said ?: @"";
}

/* Right if any of the accepted forms is in there. Deliberately generous: the
   question is whether it knows the number, not how it wrote it. */
static BOOL saysOneOf(NSString *answer, NSArray *forms)
{
	NSEnumerator *e = [forms objectEnumerator];
	NSString *form;
	while((form = [e nextObject]) != nil)
		if([answer rangeOfString:form].location != NSNotFound)
			return YES;
	return NO;
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- what it answers, and what the answer is ---\n");

	NSArray *sums = [NSArray arrayWithObjects:
		@"quanto fa 47 per 23?",              @"1081",
		@"quanto fa 1234 più 5678",           @"6912",
		@"quanto fa 7 diviso 2",              @"3,5",
		@"quanto fa il 18% di 240",           @"43,2",
		@"quanto fa il 18 per cento di 240",  @"43,2",
		@"quanto fa sette per otto",          @"56",
		@"12*7",                              @"84",
		@"quanto fa 2 elevato 10",            @"1024",
		@"(3+4)*5",                           @"35",
		@"how much is 15 times 4",            @"60",
		@"cuánto es 100 dividido 4",          @"25",
		@"quanti litri sono 2 galloni",       @"7,5",
		@"quanti chilometri sono 5 miglia",   @"8,04",
		@"20 gradi in fahrenheit",            @"68",
		@"quanti minuti sono 2 ore",          @"120",
		@"quanti gb sono 2048 mb",            @"2",
		nil];
	NSUInteger i;
	for(i = 0; i < [sums count]; i += 2) {
		NSString *question = [sums objectAtIndex:i];
		NSString *wanted = [sums objectAtIndex:i + 1];
		NSString *said = [NekoSums wantedFor:question];
		ok(said != nil && [said rangeOfString:wanted].location != NSNotFound,
			question, said ?: @"(nothing)");
	}

	printf("\n--- and the half that matters: what it stays out of ---\n");

	NSArray *not = [NSArray arrayWithObjects:
		@"quanto fa male questa cosa", @"quanto costa un caffè",
		@"quanti anni hai", @"che ore sono", @"metti un timer di 10 minuti",
		@"quanto manca a venerdì", @"quanti litri di benzina servono",
		@"5 gatti per 3 giorni", @"ricordami tra 20 minuti",
		@"quanto fa freddo oggi", @"quanto fa 5 diviso 0",
		@"quante persone c'erano", @"parliamo di 2 o 3 cose", nil];
	NSEnumerator *quiet = [not objectEnumerator];
	NSString *sentence;
	while((sentence = [quiet nextObject]) != nil) {
		NSString *said = [NekoSums wantedFor:sentence];
		ok(said == nil, sentence, said ?: @"silent");
	}

	if(![[NSUserDefaults standardUserDefaults] boolForKey:@"slow"]) {
		notMeasured(@"the model arm, which says why this module exists, needs --slow");
		return NekoTestResult();
	}

	printf("\n--- what a model does with the same questions ---\n");

	/* Every model on this Mac, not one: a single model's mistake is that model's,
	   and the claim being tested is about what a small model is for. */
	NSMutableArray *models = [NSMutableArray array];
	NekoModelStore *store = [NekoModelStore sharedStore];
	NSEnumerator *known = [[store catalogue] objectEnumerator];
	NekoLocalModel *one;
	while((one = [known nextObject]) != nil)
		if([store installedURLForIdentifier:[one identifier]] != nil)
			[models addObject:[one identifier]];
	if([models count] == 0) {
		notMeasured(@"no local model on this Mac");
		return NekoTestResult();
	}

	NSString *instructions = [NSString stringWithFormat:
		@"You are answering a question. Answer in Italian, in one short sentence.\n%@",
		NekoFactsNow()];
	printf("      the facts it is given:\n");
	NSEnumerator *lines = [[NekoFactsNow() componentsSeparatedByString:@"\n"] objectEnumerator];
	NSString *line;
	while((line = [lines nextObject]) != nil)
		if([line length] > 0)
			printf("        %s\n", [line UTF8String]);

	NSArray *questions = [NSArray arrayWithObjects:
		@"quanti giorni mancano a venerdì?",     @"4|quattro",
		@"che giorno è dopodomani?",             @"2 settembre|mercoledì",
		@"quanto manca al 25 dicembre?",         @"116|115",
		@"quanto fa 47 per 23?",                 @"1081|1.081",
		@"quanto fa 1234 più 5678?",             @"6912|6.912",
		@"quanto fa 7 diviso 2?",                @"3,5|3.5",
		@"quanto fa il 18% di 240?",             @"43,2|43.2",
		@"quanti chilometri sono 5 miglia?",     @"8,0|8.0|8,04|8,05",
		@"quanti gradi fahrenheit sono 20 gradi?", @"68",
		@"quanti litri sono 2 galloni?",         @"7,5|7.5",
		nil];

	NSEnumerator *chosen = [models objectEnumerator];
	NSString *identifier;
	while((identifier = [chosen nextObject]) != nil) {
	NekoLocalProvider *local = [[[NekoLocalProvider alloc] init] autorelease];
	[local setPreferredModel:identifier];
	printf("\n      --- %s ---\n", [identifier UTF8String]);

	int right = 0, asked = 0;
	for(i = 0; i < [questions count]; i += 2) {
		NSString *question = [questions objectAtIndex:i];
		NSArray *forms = [[questions objectAtIndex:i + 1] componentsSeparatedByString:@"|"];
		NSDate *started = [NSDate date];
		NSString *answer = ask(local, question, instructions);
		BOOL good = saysOneOf(answer, forms);
		asked++;
		if(good)
			right++;
		printf("  %s  %-42s %.1fs  %s\n", good ? "  " : "XX",
			[question UTF8String], -[started timeIntervalSinceNow],
			[[answer stringByReplacingOccurrencesOfString:@"\n" withString:@" "] UTF8String]);
	}

	printf("      %d of %d right\n", right, asked);
	}
	notMeasured(@"this arm is the reason the two modules exist; it does not gate the build");

	[pool release];
	return NekoTestResult();
}
