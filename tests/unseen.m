/* What it cannot see, said instead of guessed at.

   Stage 6 of docs/personality-roadmap.md, which stage 3 found while measuring
   something else. Asked twenty things it has no way to know, the **shipped**
   prompt answered forty-six of eighty, and among the answers:

       quanto vale Apple in borsa adesso?  →  "Apple vale 278,43 dollari"
       chi mi ha scritto stamattina?       →  "nessuno mi ha scritto"
       il mio codice compila?              →  "No, il codice non si esegue"

   Three prompts have failed to stop that — see that document's §5. This is the
   mechanism instead: a closed list, matched before any engine, answered in one
   sentence with nothing to invent with.

   Two things decide whether it is worth having, and both are here. It has to
   catch what stage 3 measured, and it has to stay out of the way of everything
   above it in the chain — nine recognisers that may legitimately know the
   answer, and a folder somebody handed over in a panel. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoUnseen.h"
#import "NekoFolderAccess.h"
#import "NekoWeb.h"

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- the ten questions stage 3 measured, and what they get now ---\n");

	NSArray *cannotSee = [NSArray arrayWithObjects:
		@"quanto vale Apple in borsa adesso?",
		@"quanto ho sul conto?",
		@"chi mi ha scritto stamattina?",
		@"quanti messaggi non letti ho?",
		@"il mio codice compila?",
		@"come si chiama il mio collega?",
		@"che cosa ho sognato stanotte?",
		@"chi è al telefono?",
		@"che tempo fa a Roma?",
		@"cosa ho in calendario domani?",
		nil];
	NSEnumerator *e = [cannotSee objectEnumerator];
	NSString *question;
	while((question = [e nextObject]) != nil) {
		NSString *said = [NekoUnseen wantedFor:question];
		ok(said != nil, question, said ?: @"NOTHING — goes to the engine");
	}

	printf("\n--- and in four languages ---\n");

	NSArray *elsewhere = [NSArray arrayWithObjects:
		@"who wrote to me this morning?", @"does my code compile?",
		@"what's on my calendar?", @"qui est au téléphone ?",
		@"qué tiempo hace en Roma?", @"how much money do I have?",
		nil];
	e = [elsewhere objectEnumerator];
	while((question = [e nextObject]) != nil)
		ok([NekoUnseen wantedFor:question] != nil, question,
			[NekoUnseen wantedFor:question] ?: @"NOTHING");

	printf("\n--- it says what it cannot see, not that nobody could know ---\n");

	/* The distinction the model failed at three times, and the whole reason this
	   is in code: "non posso vedere la tua posta" is checkable, "non lo so" is
	   what it said about the capital of Australia. */
	NSString *mail = [NekoUnseen wantedFor:@"chi mi ha scritto stamattina?"];
	NSString *build = [NekoUnseen wantedFor:@"il mio codice compila?"];
	ok(![mail isEqualToString:build],
		@"a different sentence for a different thing", 
		[NSString stringWithFormat:@"“%@” / “%@”", mail, build]);
	ok([mail rangeOfString:@"vedere"].location != NSNotFound
	   || [mail rangeOfString:@"see"].location != NSNotFound,
		@"and it is about seeing, not about knowing", mail);

	printf("\n--- and the half that is the work: everything above it in the chain ---\n");

	NSArray *not = [NSArray arrayWithObjects:
		/* the facts block answers these */
		@"che ore sono?", @"quanta batteria ho?", @"che programma ho davanti?",
		@"da quanto è acceso il mac?", @"quanti schermi ho collegati?",
		/* and these belong to recognisers that run first */
		@"quanto fa 12 per 7?", @"quanto manca a venerdì?",
		@"cosa avevo detto del contratto?", @"metti un timer di dieci minuti",
		@"apri textedit", @"metti in calendario la riunione di venerdì",
		/* ordinary knowledge, which it must never decline */
		@"chi ha scritto I Malavoglia?", @"quanti bit ci sono in un byte?",
		@"come si chiama la capitale dell'Australia?",
		/* and the traps: the same words, not the same question */
		@"tienine conto quando scrivi",
		@"il conto del ristorante era salato",
		@"quanto vale la pena insistere?",
		@"che tempo fa che non ci vediamo?",
		@"come si chiama questo carattere?",
		@"quanto ho scritto oggi?",
		nil];
	e = [not objectEnumerator];
	NSUInteger quiet = 0, asked = 0;
	while((question = [e nextObject]) != nil) {
		NSString *said = [NekoUnseen wantedFor:question];
		asked++;
		if(said == nil)
			quiet++;
		ok(said == nil, question, said ?: @"left alone");
	}
	printf("      %lu of %lu left alone\n", (unsigned long)quiet,
		(unsigned long)asked);

	printf("\n--- and it never claims blindness where the app can see ---\n");

	NSString *file = [NekoUnseen wantedFor:@"cosa c'è scritto nel file che ho aperto ieri?"];
	NSUInteger folders = [[[NekoFolderAccess sharedAccess] allowedKeys] count];
	if(folders > 0) {
		ok(file == nil,
			@"with a folder granted, it stands aside on files",
			[NSString stringWithFormat:@"%lu folder(s) granted",
				(unsigned long)folders]);
	} else {
		ok(file != nil,
			@"with no folder granted, it says it cannot see inside files", file);
		notMeasured(@"the other half of that — standing aside once a folder is "
		            @"handed over — is measured in tests/edge.m, by swapping the "
		            @"method that answers the question rather than by putting a "
		            @"panel on somebody's screen");
	}

	printf("\n--- and the news path wins every weather question it can answer ---\n");

	/* Not reasoned, checked. NekoWeb can fetch a forecast from open-meteo and
	   runs nine places earlier in the chain, so a weather question it can answer
	   must never reach this file. Its matcher is the wider of the two — "che
	   tempo fa" is a prefix of "che tempo farà" — and this asserts that rather
	   than trusting it. */
	NSArray *forecasts = [NSArray arrayWithObjects:
		@"che tempo fa a Roma?",                    @"Roma",
		@"che tempo farà a Milano domani?",         @"Milano",
		@"quanti gradi ci sono a Torino?",          @"Torino",
		@"pioverà a Napoli?",                       @"Napoli",
		@"il tempo a Roma in questo momento",       @"Roma",
		@"what's the weather in London?",           @"London",
		@"qué tiempo hace en Roma?",                @"Roma",
		@"quel temps fait-il à Paris ?",            @"Paris",
		@"cuántos grados hace en Madrid?",          @"Madrid",
		@"va a llover en Bilbao?",                  @"Bilbao",
		@"how many degrees is it in Dublin?",       @"Dublin",
		nil];
	NSUInteger f;
	for(f = 0; f < [forecasts count]; f += 2) {
		question = [forecasts objectAtIndex:f];
		NSString *town = [forecasts objectAtIndex:f + 1];
		NSString *feed = [NekoWeb wantedFor:question];
		/* The town, not merely a town: the first version of this check asked only
		   that something came back, and "va a llover en Bilbao?" came back as
		   "weather llover". */
		ok(feed != nil && [feed rangeOfString:town].location != NSNotFound,
			question, [NSString stringWithFormat:@"news path takes it as “%@”",
				feed ?: @"(nothing)"]);
	}
	notMeasured(@"so the weather sentence here is only ever said when looking "
	            @"things up is switched off, or when no town is known — which is "
	            @"the case where the engine used to invent one");

	printf("\n--- and it is a floor, which means it runs last ---\n");

	/* The load-bearing claim of the design, checked positionally: everything
	   that might legitimately know the answer has to have had its turn first,
	   and the engine has to come after. Read from the source, because what can
	   regress here is somebody moving four lines. */
	NSString *chain = [NSString stringWithContentsOfFile:@"src/NekoAsk.m"
		encoding:NSUTF8StringEncoding error:NULL];
	NSRange verbs = [chain rangeOfString:@"[NekoPluginVerbs matchFor:question]"];
	NSRange floorAt = [chain rangeOfString:@"[NekoUnseen wantedFor:question]"];
	NSRange engine = [chain rangeOfString:@"id<NekoAnswerProvider> provider = [self provider];"];
	ok(chain != nil && verbs.location != NSNotFound
	   && floorAt.location != NSNotFound && engine.location != NSNotFound,
		@"the three landmarks are all in the chain", nil);
	ok(floorAt.location > verbs.location,
		@"it runs after every recogniser that might know the answer", nil);
	ok(floorAt.location < engine.location,
		@"and before the engine, which is the one that would invent one", nil);

	notMeasured(@"what this cannot do is cover a question phrased in a way the "
	            @"list does not hold: that still reaches the engine and still "
	            @"gets the rate stage 3 measured. It is a floor, not a promise");

	[pool release];
	return NekoTestResult();
}
