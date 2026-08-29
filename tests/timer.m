/* "Metti un timer di dieci minuti."

   Two halves, and the second one matters more. The first is the parsing, which is
   a table: a number, a unit, and the words four languages use for a half and a
   quarter. The second is everything that must **not** become a timer — because a
   missed timer is a nuisance and a timer nobody asked for is the application
   deciding things on somebody's behalf.

   Measured before any of it was written: NSDataDetector, which parses "domani
   alle 15" for nothing in all four languages, parses none of these durations. That
   is why there is a table here at all. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoWhen.h"
#import "NekoTimer.h"

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- how long is that, in four languages ---\n");

	struct { const char *said; double want; } durations[] = {
		{ "metti un timer di 10 minuti",   600 },
		{ "ricordamelo fra 20 minuti",    1200 },
		{ "svegliami tra un'ora",         3600 },
		{ "fra un'ora e mezza",           5400 },
		{ "tra un quarto d'ora",           900 },
		{ "tra mezz'ora",                 1800 },
		{ "timer di 90 secondi",            90 },
		{ "timer di 5 min",                300 },
		{ "tra due ore",                  7200 },
		{ "fra quindici minuti",           900 },
		{ "set a timer for 10 minutes",    600 },
		{ "remind me in 20 minutes",      1200 },
		{ "wake me in half an hour",      1800 },
		{ "remind me in an hour and a half", 5400 },
		{ "in a quarter of an hour",       900 },
		{ "wake me in one hour",          3600 },
		{ "rappelle-moi dans 20 minutes", 1200 },
		{ "réveille-moi dans une demi-heure", 1800 },
		{ "dans un quart d'heure",         900 },
		{ "avísame en media hora",        1800 },
		{ "recuérdame en veinte minutos", 1200 },
		{ "temporizador de 1 h 30",       5400 },
	};
	NSUInteger i, right = 0, total = sizeof(durations) / sizeof(durations[0]);
	NSMutableString *wrong = [NSMutableString string];
	for(i = 0; i < total; i++) {
		double got = [NekoWhen secondsIn:
			[NSString stringWithUTF8String:durations[i].said]];
		if(fabs(got - durations[i].want) < 0.5)
			right++;
		else
			[wrong appendFormat:@"%s → %.0f (wanted %.0f); ",
				durations[i].said, got, durations[i].want];
	}
	ok(right == total, [NSString stringWithFormat:
		@"all %lu phrases parse to the second", (unsigned long)total], wrong);

	printf("\n--- and the ones that are not a timer at all ---\n");

	/* The half that matters. Every one of these has to leave the timer alone,
	   and three of them contain a perfectly good duration. */
	const char *notTimers[] = {
		"quanto fa sette per otto", "che tempo fa a Roma",
		"che ore sono", "come si chiama il gatto",
		"ho dormito otto ore",                    /* a duration, and a remark */
		"la riunione è durata due ore",           /* likewise */
		"un'ora di sonno in più mi servirebbe",   /* likewise */
		"domani alle 15", "mettimi una canzone",
		"metti in pausa", "alza il volume",
		"che notizie ci sono", "chi ha vinto ieri",
		"raccontami una barzelletta",
	};
	NSUInteger quiet = 0, asked = sizeof(notTimers) / sizeof(notTimers[0]);
	NSMutableString *misfired = [NSMutableString string];
	for(i = 0; i < asked; i++) {
		NSString *said = [NSString stringWithUTF8String:notTimers[i]];
		NSTimeInterval wanted = [NekoTimer wantedFor:said];
		if(wanted == 0.0)
			quiet++;
		else
			[misfired appendFormat:@"%s → %.0f s; ", notTimers[i], wanted];
	}
	ok(quiet == asked, [NSString stringWithFormat:
		@"none of %lu ordinary sentences sets one", (unsigned long)asked], misfired);

	ok([NekoTimer wantedFor:@"metti un timer"] == 0.0,
		@"and neither does asking for one without saying how long", nil);
	ok([NekoTimer wantedFor:@"svegliami tra 30 ore"] == 0.0,
		@"nor one longer than a day, which is not a timer", nil);

	printf("\n--- what it says back ---\n");

	NekoTimer *timer = [NekoTimer sharedTimer];
	NSString *said = [timer startFor:600.0];
	ok([said length] > 0, @"it answers with a sentence", said);
	ok([said rangeOfString:[NekoWhen clockTimeIn:600.0]].location != NSNotFound,
		@"and the sentence has the time it will land in it, not just the duration",
		said);
	ok([timer isRunning], @"and it is running", nil);
	ok([[timer menuTitle] length] > 0, @"and says so in the menu",
		[timer menuTitle]);

	NSString *second = [timer startFor:300.0];
	ok([timer secondsLeft] < 302.0 && [timer secondsLeft] > 290.0,
		@"a second one replaces the first rather than joining it",
		[NSString stringWithFormat:@"%.0f s left", [timer secondsLeft]]);
	(void)second;

	[timer cancel];
	ok(![timer isRunning] && [timer menuTitle] == nil,
		@"cancelling stops it and takes it out of the menu", nil);

	printf("\n--- and it actually goes off ---\n");

	/* Two seconds, watched by the run loop rather than by a sleep, because a
	   sleep would stop the very timer under test.

	   The window is thirty seconds and not three, and that is the point: when the
	   moment is a bad one — a full-screen window, a password field, and in a
	   harness simply nobody looking — it waits for a better one and says it anyway
	   after eight. A timer somebody set is the one thing here worth interrupting
	   for. How long it actually took is printed, because "it fired" and "it fired
	   when it said it would" are different claims. */
	NSDate *set = [NSDate date];
	[timer startFor:2.0];
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:30.0];
	while([timer isRunning] && [until timeIntervalSinceNow] > 0.0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
		                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	NSTimeInterval took = -[set timeIntervalSinceNow];
	ok(![timer isRunning], @"it goes off by itself, waiting for a decent moment",
		[NSString stringWithFormat:@"asked for 2 s, went off after %.1f s", took]);
	ok(took < 12.0, @"and never waits longer than its patience",
		[NSString stringWithFormat:@"%.1f s", took]);

	int result = NekoTestResult();
	[pool release];
	return result;
}
