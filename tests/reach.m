/* How far the chain of recognisers actually reaches over real questions.

   docs/router-plan.md, step one. Before anything is compared against an engine,
   the denominator: of the questions somebody actually asked this Mac, how many
   does the application already answer in code, and which ones fall through?

   It costs nothing and touches nothing, because the design already has the seam
   this needs. Every recogniser in `askAfterPlugins:` is split in two — a pure
   `+wantedFor:` or `+matchFor:` that says whether it claims the question, and a
   separate `+act:` / `+make:` / `+fetch:` that does the thing. So the twelve can
   be asked in order without a timer starting, an event being written or Spotify
   being spoken to.

   The corpus is the diary on this Mac: real questions, asked for real reasons,
   which is the whole point. A corpus written for the purpose would prove
   nothing — that is the shape of passing for the wrong reason this project keeps
   catching itself in. Nothing is written and nothing leaves the machine. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoWeb.h"
#import "NekoFact.h"
#import "NekoSums.h"
#import "NekoClock.h"
#import "NekoRecord.h"
#import "NekoSelf.h"
#import "NekoGlance.h"
#import "NekoTimer.h"
#import "NekoAppointment.h"
#import "NekoPluginRoutes.h"
#import "NekoPluginVerbs.h"
#import "NekoUnseen.h"
#import "NekoAsk.h"
#import "NekoPlugins.h"
#import "NekoMemory.h"

/* The diary writes every line through this. Not in the header because nothing
   outside NekoMemory has needed it until now — and what this harness needs is
   exactly it, rather than a reimplementation that would drift. */
@interface NekoMemory (Testing)
- (NSString *)squeeze:(NSString *)text;
@end

/* The chain, in the order askAfterPlugins: runs it, recognition only.

   The two guards that are settings rather than recognisers are applied the way
   the chain applies them, so this reports what *this* Mac would do rather than
   what a differently configured one might. Where a guard is off, the rung is
   reported as unreachable rather than as standing aside — those are different
   facts and running them together would flatter the chain. */
static NSString *whoClaims(NSString *question, NSMutableSet *unreachable)
{
	if([[NekoWeb sharedWeb] isEnabled]) {
		if([[NekoWeb wantedFor:question] length] > 0)
			return @"NekoWeb";
	} else
		[unreachable addObject:@"NekoWeb"];

	if([NekoFact wantedFor:question] != nil)          return @"NekoFact";
	if([NekoSums wantedFor:question] != nil)          return @"NekoSums";
	if([NekoClock wantedFor:question] != nil)         return @"NekoClock";
	if([NekoRecord wantedFor:question])               return @"NekoRecord";
	if([NekoSelf wantedFor:question] != nil)          return @"NekoSelf";
	if([NekoGlance wantedFor:question] > 0.0)         return @"NekoGlance";
	if([NekoTimer wantedFor:question] > 0.0)          return @"NekoTimer";
	if([NekoAppointment wantedFor:question] != nil)   return @"NekoAppointment";

	if([[NekoWeb sharedWeb] isEnabled] && [NekoPluginRoutes anythingListens]) {
		if([NekoPluginRoutes matchFor:question] != nil)
			return @"NekoPluginRoutes";
	} else
		[unreachable addObject:@"NekoPluginRoutes"];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"NekoActionsEnabled"]
	   && [NekoPluginVerbs anythingListens]) {
		if([NekoPluginVerbs matchFor:question] != nil)
			return @"NekoPluginVerbs";
	} else
		[unreachable addObject:@"NekoPluginVerbs"];

	if([NekoUnseen wantedFor:question] != nil)        return @"NekoUnseen";
	return nil;                                        /* through to the engine */
}

/* Every question in the diary, oldest first. The format is
   HH:MM \t who \t what, and "you" is somebody speaking. */
static NSArray *questionsAsked(NSString *directory)
{
	NSMutableArray *asked = [NSMutableArray array];
	NSArray *files = [[[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:directory error:NULL]
		sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator *e = [files objectEnumerator];
	NSString *name;
	while((name = [e nextObject]) != nil) {
		if(![name hasSuffix:@".txt"] || [name length] < 14)
			continue;              /* durable.txt, synonyms.txt, facts.txt */
		NSString *whole = [NSString stringWithContentsOfFile:
			[directory stringByAppendingPathComponent:name]
			encoding:NSUTF8StringEncoding error:NULL];
		NSEnumerator *lines = [[whole componentsSeparatedByString:@"\n"] objectEnumerator];
		NSString *line;
		while((line = [lines nextObject]) != nil) {
			NSArray *parts = [line componentsSeparatedByString:@"\t"];
			if([parts count] < 3)
				continue;
			if(![[[parts objectAtIndex:1] lowercaseString] isEqualToString:@"you"])
				continue;
			NSString *said = [[parts subarrayWithRange:
				NSMakeRange(2, [parts count] - 2)] componentsJoinedByString:@"\t"];
			said = [said stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if([said length] > 0)
				[asked addObject:said];
		}
	}
	return asked;
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	/* What this harness needs, said by the harness rather than by run.sh, so that
	   turning the web on here does not turn it on for every other measurement.
	   The argument domain rather than -registerDefaults:, which is the lowest
	   layer of all and loses to anything already saved — and merged into what is
	   there rather than replacing it, because that is where the diary's own path
	   arrives. Volatile either way: nothing somebody chose is touched. */
	NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithDictionary:
		[settings volatileDomainForName:NSArgumentDomain]];
	[arguments setObject:[NSNumber numberWithBool:YES] forKey:@"NekoWebEnabled"];
	[arguments setObject:[NSNumber numberWithBool:YES] forKey:@"NekoActionsEnabled"];

	/* And the plugins, when a copy of them was handed over. Two rungs of the
	   chain are nothing but plugins — a route somebody added, a verb aimed at a
	   player — so a run without them measures a different application. Every
	   plugin found is switched on: which ones somebody chose is their business,
	   and the question here is what the chain *can* reach. */
	NSString *folder = [settings stringForKey:@"NekoPluginsFrom"];
	if([folder length] > 0) {
		[arguments setObject:folder forKey:NekoPluginsDirectoryKey];
		NSMutableArray *ids = [NSMutableArray array];
		NSEnumerator *f = [[[NSFileManager defaultManager]
			contentsOfDirectoryAtPath:folder error:NULL] objectEnumerator];
		NSString *name;
		while((name = [f nextObject]) != nil) {
			if(![name hasSuffix:@".nekoplugin"])
				continue;
			NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:
				[[folder stringByAppendingPathComponent:name]
					stringByAppendingPathComponent:@"plugin.plist"]];
			NSString *identifier = [plist objectForKey:@"Identifier"];
			if([identifier length] > 0)
				[ids addObject:identifier];
		}
		[arguments setObject:ids forKey:@"NekoPluginsEnabled"];
	}
	[settings setVolatileDomain:arguments forName:NSArgumentDomain];

	NSString *directory = [[NSUserDefaults standardUserDefaults]
		stringForKey:@"NekoMemoryDirectory"];
	NSArray *asked = directory != nil ? questionsAsked(directory) : nil;

	if([asked count] == 0) {
		notMeasured(@"no diary to read on this Mac — this harness measures a real "
		            @"corpus or it measures nothing, and a corpus written for the "
		            @"purpose would prove nothing at all");
		printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
		[pool release];
		return 0;
	}

	printf("--- how far the chain reaches, over %lu real questions ---\n\n",
		(unsigned long)[asked count]);

	NSMutableDictionary *tally = [NSMutableDictionary dictionary];
	NSMutableSet *unreachable = [NSMutableSet set];
	NSMutableArray *throughToTheEngine = [NSMutableArray array];
	NSEnumerator *e = [asked objectEnumerator];
	NSString *question;
	while((question = [e nextObject]) != nil) {
		NSString *who = whoClaims(question, unreachable);
		NSString *key = who ?: @"(the engine)";
		[tally setObject:[NSNumber numberWithUnsignedInteger:
			[[tally objectForKey:key] unsignedIntegerValue] + 1] forKey:key];
		if(who == nil)
			[throughToTheEngine addObject:question];
	}

	NSArray *order = [[tally allKeys] sortedArrayUsingComparator:
		^NSComparisonResult(id a, id b) {
			return [[tally objectForKey:b] compare:[tally objectForKey:a]];
		}];
	NSEnumerator *k = [order objectEnumerator];
	NSString *who;
	while((who = [k nextObject]) != nil)
		printf("      %-20s %lu\n", [who UTF8String],
			(unsigned long)[[tally objectForKey:who] unsignedIntegerValue]);

	NSUInteger caught = [asked count] - [throughToTheEngine count];
	printf("\n");
	ok(YES, @"answered in code, before any engine",
		[NSString stringWithFormat:@"%lu of %lu (%.0f%%)", (unsigned long)caught,
			(unsigned long)[asked count],
			100.0 * (double)caught / (double)[asked count]]);
	ok(YES, @"through to the engine",
		[NSString stringWithFormat:@"%lu", (unsigned long)[throughToTheEngine count]]);
	ok(YES, @"plugins loaded, so the two rungs that are plugins can run",
		[NSString stringWithFormat:@"%lu",
			(unsigned long)[[[NekoPlugins sharedPlugins] enabled] count]]);
	if([unreachable count] > 0)
		ok(YES, @"rungs a setting made unreachable on this Mac",
			[[[unreachable allObjects] sortedArrayUsingSelector:@selector(compare:)]
				componentsJoinedByString:@", "]);

	printf("\n--- and the ones that went through, which is the list ---\n");
	NSEnumerator *t = [throughToTheEngine objectEnumerator];
	while((question = [t nextObject]) != nil)
		printf("      %s\n", [question UTF8String]);

	/* Reading that list, nearly every line is a question the chain has a rung
	   for — "tempo fa", "giorno oggi", "ore", "sei", "quotazione oggi borsa
	   Apple". So the obvious suspicion is that the chain would have caught them
	   as they were spoken, and the diary is what broke them.

	   Guessing at what somebody originally said would prove nothing. This does
	   not guess: it takes the phrasings the recognisers are *documented* to
	   catch, checks the chain catches them, then puts each one through
	   -[NekoMemory squeeze:] — the very method the diary writes with — and asks
	   the same chain again. Whatever stops being recognised is measured damage,
	   not a hypothesis. */
	printf("\n--- and the same questions, before and after the diary writes them ---\n");

	/* Eight phrasings, every one of them verified to be caught by the chain as
	   spoken — that is what the first check below pins, and it is what makes the
	   second one mean anything. Two phrasings that seemed obvious were dropped
	   from this list because the chain does *not* catch them, and they are
	   recorded as gaps further down rather than hidden by being left out. */
	NSArray *asSpoken = [NSArray arrayWithObjects:
		@"che giorno è oggi?",
		@"che ore sono?",
		@"dove sei?",
		@"quanto vale Apple in borsa adesso?",
		@"cosa è successo oggi nel mondo?",
		@"puoi mettere un timer di 10 minuti?",
		@"che tempo fa a Vicenza?",
		@"quanti giorni mancano al 25 dicembre?", nil];

	NekoMemory *diary = [NekoMemory sharedMemory];
	NSUInteger caughtSpoken = 0, caughtSqueezed = 0, lost = 0;
	NSEnumerator *p = [asSpoken objectEnumerator];
	NSString *spoken;
	while((spoken = [p nextObject]) != nil) {
		NSMutableSet *ignored = [NSMutableSet set];
		NSString *before = whoClaims(spoken, ignored);
		NSString *squeezed = [diary squeeze:spoken];
		NSString *after = whoClaims(squeezed, ignored);
		if(before != nil) caughtSpoken++;
		if(after != nil)  caughtSqueezed++;
		if(before != nil && after == nil) lost++;
		printf("      %-38s %-16s\n        → in the diary: %-22s %s\n",
			[spoken UTF8String], [(before ?: @"(the engine)") UTF8String],
			[squeezed UTF8String], [(after ?: @"(the engine)") UTF8String]);
	}

	printf("\n");
	ok(caughtSpoken == [asSpoken count],
		@"as spoken, the chain catches all of them",
		[NSString stringWithFormat:@"%lu of %lu", (unsigned long)caughtSpoken,
			(unsigned long)[asSpoken count]]);
	ok(YES, @"as the diary keeps them, it catches",
		[NSString stringWithFormat:@"%lu of %lu", (unsigned long)caughtSqueezed,
			(unsigned long)[asSpoken count]]);
	ok(YES, @"so the diary alone loses",
		[NSString stringWithFormat:@"%lu of %lu", (unsigned long)lost,
			(unsigned long)[asSpoken count]]);

	/* Two gaps found while choosing the list above, both of them real and
	   neither of them anything to do with the diary. Printed rather than failed:
	   this harness measures reach, and closing these is a separate piece of
	   work with its own checks. */
	printf("\n--- and two gaps, found by trying phrasings that ought to work ---\n");
	NSArray *ought = [NSArray arrayWithObjects:
		@"che tempo fa?",
		@"che tempo fa oggi?",
		@"quanti giorni mancano a Natale?",
		@"che giorno era il 3 marzo 2026?", nil];
	NSEnumerator *g = [ought objectEnumerator];
	NSString *should;
	while((should = [g nextObject]) != nil) {
		NSMutableSet *ignored = [NSMutableSet set];
		NSString *who = whoClaims(should, ignored);
		printf("      %-40s %s\n", [should UTF8String],
			[(who ?: @"(the engine) ←") UTF8String]);
	}
	notMeasured(@"the weather is only recognised when a place is named, and the "
	            @"bare question is the one people ask — the diary has it twice. "
	            @"And the clock does duration arithmetic only: how long until a "
	            @"date, never what day a date was");

	notMeasured(@"whether any of those *should* have been caught is a person's "
	            @"judgement, and that is the point: this produces the list, not "
	            @"the verdict");
	notMeasured(@"and the figure above is a floor, twice over. Any rung listed as "
	            @"unreachable needs plugins this harness does not load, and the "
	            @"lines themselves are what -[NekoMemory squeeze:] left of the "
	            @"questions — the diary is notes, not a transcript, so a "
	            @"recogniser that keys on a word somebody actually said may never "
	            @"see it here");

	printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
	[pool release];
	return 0;
}
