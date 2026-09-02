/* A remark that says nothing is not a remark.

   Stage 1 of docs/personality-roadmap.md, and the only stage with local evidence
   rather than a paper behind it. `tools/diary.py`, run on eight days of real
   diary, found 65 remarks carrying 11 distinct thoughts, and the content was
   these two families:

       L'orario attuale 10:44, mercoledì 26 agosto 2026, Xcode aperto recente
       build lento perché progetto grande

   The first reads the clock back, which the suggestion prompt already forbids in
   so many words and which happened 22 times anyway. The second names nothing
   that was on the screen. Völkel et al.'s tenth factor for conversational agents
   — *Artificial*, from 349 adjectives rated by 744 people — has **vague**,
   **superficial** and **monotonous** among its top twenty descriptors, so the
   vocabulary here is somebody else's instrument and not our own taste.

   Three checks, and the negative table is the work: a gate that silences the cat
   is worse than a cat that says something thin. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoSense.h"

/* A realistic desktop summary, in the shape NekoDesktop builds — English labels,
   the window title and the diary in the person's own language. */
static NSString *seeing(void)
{
	NSDateFormatter *clock = [[[NSDateFormatter alloc] init] autorelease];
	[clock setDateFormat:@"HH:mm"];
	return [NSString stringWithFormat:
		@"2026-08-27\tla release 2.6 esce venerdì\n"
		@"2026-08-28\tpreferisce staccare tardi\n"
		@"Here is what I seem to be doing right now.\n"
		@"The program in front of me: Xcode\n"
		@"Its window is titled: NekoSense.m — neko-mac\n"
		@"Minutes I have been in it: 42\n"
		@"Different programs I have used in the last 15 minutes: 3\n"
		@"Keys a minute: 61, mouse moves a minute: 14\n"
		@"Seconds since my last key or click: 4\n"
		@"Local time: %@\n"
		@"\nThe one thing that stands out: forty-two minutes in Xcode\n",
		[clock stringFromDate:[NSDate date]]];
}

/* The clock, as the cat would read it out — built here so the test says the same
   thing at any hour. */
static NSString *nowAsWritten(void)
{
	NSDateFormatter *clock = [[[NSDateFormatter alloc] init] autorelease];
	[clock setLocale:[NSLocale localeWithLocaleIdentifier:
		[[[NSBundle mainBundle] preferredLocalizations] firstObject] ?: @"en"]];
	[clock setDateFormat:@"HH:mm"];
	NSString *hhmm = [clock stringFromDate:[NSDate date]];
	[clock setDateFormat:@"EEEE d MMMM yyyy"];
	return [NSString stringWithFormat:@"L'orario attuale %@, %@, Xcode aperto recente",
		hhmm, [clock stringFromDate:[NSDate date]]];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *seen = seeing();

	printf("\n--- the two families that filled a real diary ---\n");

	NSArray *thin = [NSArray arrayWithObjects:
		nowAsWritten(),                                   @"the clock, read back",
		@"build lento perché progetto grande",            @"an explanation of nothing it saw",
		@"Il build è lento perché i server sono sovraccarichi.", @"an explanation of nothing it saw",
		@"La compilazione è lenta perché il progetto è enorme.", @"an explanation of nothing it saw",
		nil];
	NSUInteger i;
	for(i = 0; i < [thin count]; i += 2) {
		NSString *line = [thin objectAtIndex:i];
		NSString *problem = [NekoSense problemWith:line seeing:seen];
		ok(problem != nil, [line length] > 46 ? [line substringToIndex:46] : line,
			problem ?: @"LET THROUGH");
		if(problem != nil && ![problem isEqualToString:[thin objectAtIndex:i + 1]])
			printf("        (thrown away as “%s”, expected “%s” — either is a "
			       "rejection)\n", [problem UTF8String],
			       [[thin objectAtIndex:i + 1] UTF8String]);
	}

	printf("\n--- a reproach, which nobody would keep on their desktop ---\n");

	NSArray *reproaches = [NSArray arrayWithObjects:
		@"Dovresti aver chiuso Xcode un'ora fa.",
		@"Avresti dovuto fare una pausa dopo quarantadue minuti.",
		@"You should have committed that before lunch.",
		@"Te l'avevo detto che la release slittava.",
		nil];
	NSEnumerator *e = [reproaches objectEnumerator];
	NSString *line;
	while((line = [e nextObject]) != nil)
		ok([NekoSense problemWith:line seeing:seen] != nil, line,
			[NekoSense problemWith:line seeing:seen] ?: @"LET THROUGH");

	printf("\n--- and the half that is the work: what must still be said ---\n");

	NSArray *good = [NSArray arrayWithObjects:
		@"Quarantadue minuti su Xcode, e la release esce venerdì.",
		@"Xcode da un pezzo: ti conviene una pausa.",
		@"Tre programmi in un quarto d'ora, sei irrequieto.",
		@"Il titolo dice NekoSense.m — sei ancora dentro quel file.",
		@"Venerdì esce la 2.6 e tu sei ancora qui a limare.",
		@"Nessun tasto da quattro secondi. Stai pensando?",
		@"Quarantadue minuti nello stesso file: o va bene, o non va per niente.",
		@"Stacchi tardi anche stasera, a giudicare da Xcode.",
		@"NekoSense.m di nuovo. Quel file ti sta antipatico.",
		@"La 2.6 esce venerdì e sei in Xcode: tutto torna.",
		@"Quattordici movimenti del mouse al minuto — praticamente immobile.",
		@"Tre programmi in un quarto d'ora e poi di nuovo Xcode.",
		nil];
	NSUInteger passed = 0, kept = 0;
	e = [good objectEnumerator];
	while((line = [e nextObject]) != nil) {
		NSString *problem = [NekoSense problemWith:line seeing:seen];
		kept++;
		if(problem == nil)
			passed++;
		ok(problem == nil, [line length] > 52 ? [line substringToIndex:52] : line,
			problem ?: @"said");
	}
	printf("      %lu of %lu ordinary remarks still said\n",
		(unsigned long)passed, (unsigned long)kept);

	printf("\n--- and the borderline ones, printed rather than asserted ---\n");

	/* Remarks the check cannot be right about either way. Printed with its
	   verdict so that somebody reading this can disagree with the design rather
	   than with a passing test. */
	NSArray *edges = [NSArray arrayWithObjects:
		@"Sessantuno tasti al minuto: vai così.",
		@"Alle 18:30 hai la riunione, non fare tardi.",
		@"Una pausa ti conviene.",
		@"Buongiorno.",
		@"Sei concentrato.",
		@"test chiatta ancora attivo",
		@"Il progetto è grande e la compilazione ne soffre.",
		nil];
	e = [edges objectEnumerator];
	while((line = [e nextObject]) != nil) {
		NSString *problem = [NekoSense problemWith:line seeing:seen];
		printf("      %-52s %s\n", [line UTF8String],
			problem != nil ? [[NSString stringWithFormat:@"thrown away — %@",
				problem] UTF8String] : "said");
	}

	printf("\n--- and nothing changes when there is nothing to judge against ---\n");

	/* "build" is not in the Italian dictionary, so the check that has been here
	   all along refuses that line for a different reason. A sentence made only of
	   words the dictionary knows is what tests this one. */
	ok([NekoSense isWorthSaying:@"La compilazione è lenta perché il progetto è enorme."],
		@"with no context, the explanation check does not fire",
		[NekoSense problemWith:@"La compilazione è lenta perché il progetto è enorme."]);
	ok([NekoSense isWorthSaying:@"Xcode è aperto da quaranta minuti."],
		@"and the remark tests/mood.m keeps still passes", nil);
	ok(![NekoSense isWorthSaying:nowAsWritten()],
		@"while the clock is refused with or without context", nil);

	notMeasured(@"what this cannot judge is whether a remark was worth hearing. "
	            @"It can say that the same one was not made twice, that it did "
	            @"not read the clock out, and that it named something real");

	[pool release];
	return NekoTestResult();
}
