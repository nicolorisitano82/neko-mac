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
	if([unreachable count] > 0)
		ok(YES, @"rungs a setting made unreachable on this Mac",
			[[[unreachable allObjects] sortedArrayUsingSelector:@selector(compare:)]
				componentsJoinedByString:@", "]);

	printf("\n--- and the ones that went through, which is the list ---\n");
	NSEnumerator *t = [throughToTheEngine objectEnumerator];
	while((question = [t nextObject]) != nil)
		printf("      %s\n", [question UTF8String]);

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
