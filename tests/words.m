/* Whether the cat can learn that two words are the same word.

   NekoRecall.h has the two dead ends — word vectors have no threshold, the system
   dictionary answers with definitions — and NekoWords.h has the measurement that
   found the third way: the on-device model cannot *generate* the synonym that
   matters but can *recognise* it when the diary's own words are put in front of
   it.

   This measures the machinery around that, which is where the risk actually is:
   that an invented word cannot get in, that a synonym never outranks the word
   somebody actually wrote, and that a question about nothing is still answered
   with nothing. The model arm is the last section and needs --slow. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoWords.h"
#import "NekoRecall.h"
#import "NekoMemory.h"
#import "NekoBrains.h"
#import "NekoAnswerProvider.h"

static NSArray *DIARY(void)
{
	return [NSArray arrayWithObjects:
		@"11:40\tyou\tla release 2.6 esce venerdì",
		@"10:05\tyou\tle preferenze si bloccavano",
		@"09:12\tsaw\tha lavorato tutta la mattina sul pannello dei plugin",
		@"13:30\tsaw\tha ascoltato Battisti mentre programmava",
		@"18:30\tsaw\tha parlato al telefono con sua sorella",
		@"14:30\tsaw\tha installato il plugin di Spotify",
		@"11:15\tyou\tla firma Developer ID costa cento euro l'anno",
		@"16:20\tsed\tho sistemato un crash che chiudeva l'applicazione",
		@"09:40\tsaw\tha aperto un branch per la memoria",
		@"12:00\tsaw\tha cambiato il personaggio del gatto in tigre", nil];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NekoWords *words = [NekoWords sharedWords];
	NSURL *file = [words file];
	NSString *before = [NSString stringWithContentsOfURL:file
		encoding:NSUTF8StringEncoding error:NULL];

	NSArray *diary = DIARY();
	NSDictionary *rarity = [NekoRecall rarityAcross:diary];
	NSArray *sets = [NekoRecall wordSetsFor:diary];

	printf("\n--- the words are lemmas on both sides, which is what makes them meet ---\n");

	NSDictionary *asked = [NekoRecall askedIn:@"che problema avevo con le impostazioni?"];
	printf("      asked:  %s\n", [[[asked allKeys] componentsJoinedByString:@", "] UTF8String]);
	printf("      diary:  %s\n",
		[[[[rarity allKeys] sortedArrayUsingSelector:@selector(compare:)]
			componentsJoinedByString:@", "] UTF8String]);
	ok([rarity objectForKey:@"preferenza"] != nil || [rarity objectForKey:@"preferenze"] != nil,
		@"the diary's word for it is in the vocabulary", nil);

	printf("\n--- without the table, the known miss is still a miss ---\n");

	NSArray *plain = [NekoRecall linesIn:diary words:sets
		about:@"che problema avevo con le impostazioni?" limit:3 rarity:rarity];
	ok([plain count] == 0, @"“impostazioni” finds nothing on its own",
		[NSString stringWithFormat:@"%lu lines", (unsigned long)[plain count]]);

	printf("\n--- with it, it is found ---\n");

	NSString *lemma = [rarity objectForKey:@"preferenza"] != nil
		? @"preferenza" : @"preferenze";
	NSDictionary *table = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObject:lemma], @"impostazione",
		[NSArray arrayWithObject:lemma], @"impostazioni", nil];
	NSArray *widened = [NekoRecall linesIn:diary words:sets
		about:@"che problema avevo con le impostazioni?" limit:3
		rarity:rarity synonyms:table];
	ok([widened count] > 0 &&
	   [[widened objectAtIndex:0] rangeOfString:@"preferenze"].location != NSNotFound,
		@"and now it finds the line about the preferences",
		[widened count] > 0 ? [widened objectAtIndex:0] : @"(nothing)");

	printf("\n--- but never over the word somebody actually wrote ---\n");

	NSDictionary *wider = [NekoRecall askedIn:@"la release e le impostazioni"
	                                widenedBy:table];
	double real = [[wider objectForKey:@"release"] doubleValue];
	double borrowed = [[wider objectForKey:lemma] doubleValue];
	ok(borrowed > 0.0 && borrowed < real,
		@"a borrowed word weighs less than a written one",
		[NSString stringWithFormat:@"%.2f against %.2f", borrowed, real]);

	/* The rule the whole application turns on: a question about nothing brings
	   nothing back, table or no table. */
	NSArray *nothing = [NekoRecall linesIn:diary words:sets
		about:@"quanto fa sette per otto?" limit:3 rarity:rarity synonyms:table];
	ok([nothing count] == 0, @"and a question about nothing is still silent",
		[NSString stringWithFormat:@"%lu lines", (unsigned long)[nothing count]]);

	printf("\n--- an answer can only pick, never invent ---\n");

	NSArray *offered = [NSArray arrayWithObjects:
		@"preferenza", @"release", @"plugin", @"firma", nil];
	NSArray *picked = [words wordsOf:@"preferenza, configurazione, opzioni" among:offered];
	ok([picked count] == 1 && [[picked objectAtIndex:0] isEqualToString:@"preferenza"],
		@"words that were not offered are dropped",
		[picked componentsJoinedByString:@", "]);
	ok([[words wordsOf:@"NONE" among:offered] count] == 0,
		@"and a refusal comes back empty", nil);
	ok([[words wordsOf:@"Certo! Ecco le parole: nessuna di queste." among:offered] count] == 0,
		@"and so does an answer that chats instead", nil);
	ok([[words wordsOf:@"preferenza release plugin firma" among:offered] count] == 3,
		@"and no more than three are ever taken", nil);

	printf("\n--- and which word it would spend a question on ---\n");

	/* The same rule NekoMemory offers a model: words of substance, four letters
	   or more, so that the verbs a line is carried by are not on the list. */
	NSMutableSet *substance = [NSMutableSet set];
	NSEnumerator *lines = [diary objectEnumerator];
	NSString *aLine;
	while((aLine = [lines nextObject]) != nil) {
		NSDictionary *inIt = [NekoRecall askedIn:aLine];
		NSEnumerator *w = [inIt keyEnumerator];
		NSString *aWord;
		while((aWord = [w nextObject]) != nil)
			if([[inIt objectForKey:aWord] doubleValue] >= 0.8 && [aWord length] >= 4)
				[substance addObject:aWord];
	}
	NSArray *vocabulary = [[substance allObjects]
		sortedArrayUsingSelector:@selector(compare:)];
	printf("      offered: %s\n",
		[[vocabulary componentsJoinedByString:@", "] UTF8String]);
	NSString *worth = [words wordWorthAsking:@"che problema avevo con le impostazioni?"
	                                   among:vocabulary];
	ok(worth != nil && [worth rangeOfString:@"impostazion"].location != NSNotFound,
		@"the noun it does not know, not the verb it does", worth ?: @"(none)");
	/* Measured, and the reason the rule is two words and not one: NLTagger reads
	   the "stai" of "come stai?" as a noun weighing a full one. */
	ok([words wordWorthAsking:@"come stai?" among:vocabulary] == nil,
		@"nothing worth asking in a question with no substance in it", nil);
	ok([words wordWorthAsking:@"che problema c'era con la release?" among:vocabulary] == nil,
		@"and nothing when the diary already uses the word", nil);

	printf("\n--- and that the two ends are actually joined ---\n");

	/* Read from the source rather than run, because the running version of this
	   waits twenty seconds for the cat to be idle and then writes to somebody's
	   real diary folder. What can regress here is a line somebody deletes, not a
	   behaviour somebody changes. */
	NSString *memory = [NSString stringWithContentsOfFile:@"src/NekoMemory.m"
		encoding:NSUTF8StringEncoding error:NULL];
	ok(memory != nil && [memory rangeOfString:@"synonyms:[[NekoWords sharedWords] table]"].location != NSNotFound,
		@"recall is widened by what was learned", nil);
	ok(memory != nil && [memory rangeOfString:@"missedOn:question"].location != NSNotFound,
		@"and a question that found nothing is what starts the learning", nil);
	NSString *source = [NSString stringWithContentsOfFile:@"src/NekoWords.m"
		encoding:NSUTF8StringEncoding error:NULL];
	ok(source != nil && [source rangeOfString:@"bestOnDeviceProvider"].location != NSNotFound
	   && [source rangeOfString:@"NekoOpenAI"].location == NSNotFound,
		@"and the diary's words are only ever shown to an engine on this Mac", nil);

	if(![[NSUserDefaults standardUserDefaults] boolForKey:@"slow"]) {
		notMeasured(@"the model arm — whether it recognises the word — needs --slow");
		[pool release];
		return NekoTestResult();
	}

	printf("\n--- and whether the model actually recognises it ---\n");

	if([NekoBrains bestOnDeviceProvider] == nil) {
		notMeasured(@"no on-device engine on this Mac, so nothing can be learned");
		[pool release];
		return NekoTestResult();
	}

	printf("      the engine answering: %s\n",
		[NSStringFromClass([(id)[NekoBrains bestOnDeviceProvider] class]) UTF8String]);

	/* Two prompts, the same question. The words are Italian and the instruction
	   is not, which is the obvious suspect for an answer that comes back full of
	   words that merely turn up in the same sort of sentence. */
	NSArray *trials = [NSArray arrayWithObjects:
		@"impostazione", @"preferenza",
		@"versione",     @"release",
		@"programma",    @"applicazione",
		@"errore",       @"crash",
		@"estensione",   @"plugin",
		@"felino",       @"gatto",
		@"bicicletta",   @"",              /* nothing in this diary means these */
		@"oceano",       @"",
		@"pianoforte",   @"",
		nil];
	NSArray *shapes = [NSArray arrayWithObjects:
		@"english", @"Words: %1$@\n\nWhich of those words, if any, mean the same "
		            @"thing as \"%2$@\"? Answer with nothing but those words, "
		            @"separated by commas, and with NONE if there are none.",
		@"italiano", @"Elenco: %1$@\n\nQuali parole dell'elenco, se ce ne sono, "
		            @"vogliono dire la stessa cosa di «%2$@»? Rispondi soltanto con "
		            @"quelle parole, separate da virgola, e con NESSUNA se non ce "
		            @"n'è nessuna. Non aggiungere parole che non sono nell'elenco.",
		nil];
	id<NekoAnswerProvider> engine = [NekoBrains bestOnDeviceProvider];
	NSString *offering = [vocabulary componentsJoinedByString:@", "];
	NSUInteger i, shape;
	for(shape = 0; shape < [shapes count]; shape += 2) {
		printf("\n      --- %s ---\n",
			[[shapes objectAtIndex:shape] UTF8String]);
		NSUInteger right = 0, tried = 0, noise = 0;
		for(i = 0; i < [trials count]; i += 2) {
			NSString *word = [trials objectAtIndex:i];
			NSString *want = [trials objectAtIndex:i + 1];
			NSString *prompt = [NSString stringWithFormat:
				[shapes objectAtIndex:shape + 1], offering, word];
			NSDate *began = [NSDate date];
			__block NSString *said = nil;
			__block BOOL done = NO;
			[engine askQuestion:prompt
			       instructions:@"You match words to other words."
			         completion:^(NSString *text, NSError *error) {
				said = [text retain];
				done = YES;
			}];
			NSDate *until = [NSDate dateWithTimeIntervalSinceNow:120.0];
			while(!done && [until timeIntervalSinceNow] > 0.0)
				spin(0.05);
			NSArray *got = [words wordsOf:(said ?: @"") among:vocabulary];
			BOOL good = [want length] > 0 ? [got containsObject:want] : ([got count] == 0);
			tried++;
			if(good)
				right++;
			if([want length] > 0)
				noise += [got count] > 0 ? [got count] - ([got containsObject:want] ? 1 : 0) : 0;
			else
				noise += [got count];
			printf("  %s  %-14s %.1fs  %s\n", good ? "  " : "XX", [word UTF8String],
				-[began timeIntervalSinceNow],
				[([got componentsJoinedByString:@", "] ?: @"—") UTF8String]);
		}
		printf("      %lu of %lu right, %lu word(s) of noise\n",
			(unsigned long)right, (unsigned long)tried, (unsigned long)noise);
	}
	notMeasured(@"the model arm is why this module exists; it does not gate the build");

	/* Whatever was there before this ran is what is there after it. */
	if(before != nil)
		[before writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	else
		[[NSFileManager defaultManager] removeItemAtURL:file error:NULL];

	[pool release];
	return NekoTestResult();
}
