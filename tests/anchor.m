/* That a durable line can point at the notes it came from.

   docs/self-2.md reads one survey properly — Always-On Agents, 435 coded works —
   and two of its findings meet here.

   The first names the gap: consolidation "flattens provenance, so an agent loses
   the ability to say where a fact came from at precisely the moment it most needs
   that, **when the fact is later challenged or found poisoned**". Which had
   already happened: in 2.12.1 the durable file held twenty-one lines and
   tools/diary.py could trace none of them.

   The second names the fix, and names two lifecycle stages rather than one: "**validation gates before a lesson becomes a durable rule, provenance and recency
   tags** so that superseded facts lose authority rather than lingering". Those
   turn out to be the same change. The nightly reflection is asked to put the
   times of the notes each line came from in front of it, and a line whose times
   are not in that day is refused — so the citation is both the provenance and the
   gate, and it works whether the diary is in Italian and the lesson in English.

   What is measured here: that a fabricated citation is caught, that a real one
   survives, that the times never reach a model, and — the slow arm — that a real
   engine actually complies with the format, because a gate nothing passes is a
   memory that has been switched off. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoMemory.h"
#import "NekoBrains.h"
#import "NekoAnswerProvider.h"

@interface NekoMemory (Testing)
- (NSString *)citationIn:(NSString *)line against:(NSSet *)realTimes;
- (NSString *)lessonIn:(NSString *)line;
@end

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
		notMeasured(@"this harness writes a diary and will not do it in the real "
		            @"one — run it through tests/run.sh");
		return NekoTestResult();
	}

	NSSet *real = [NSSet setWithObjects:@"09:12", @"11:40", @"14:20", nil];

	printf("\n--- a citation is kept only where the day has it ---\n");

	NSArray *cases = [NSArray arrayWithObjects:
		@"09:12 - the release ships on Friday",              @"09:12",
		@"09:12,11:40 - the release ships on Friday",        @"09:12,11:40",
		@"09:12, 11:40 - spaces are fine",                   @"09:12,11:40",
		/* the half that matters: a time the day does not have */
		@"03:00 - a note that never existed",                @"",
		@"09:12,03:00 - one real and one invented",          @"09:12",
		@"no times at all, just a confident sentence",       @"",
		@"09:12 11:40 - no comma and no hyphen either",      @"",
		/* and the same time twice is one citation */
		@"09:12,09:12 - said twice",                         @"09:12",
		nil];
	NSUInteger i;
	for(i = 0; i < [cases count]; i += 2) {
		NSString *got = [memory citationIn:[cases objectAtIndex:i] against:real];
		ok([got isEqualToString:[cases objectAtIndex:i + 1]],
			[cases objectAtIndex:i],
			[NSString stringWithFormat:@"“%@”", got]);
	}

	printf("\n--- and the lesson survives the citation being taken off ---\n");

	ok([[memory lessonIn:@"09:12,11:40 - the release ships on Friday"]
		isEqualToString:@"the release ships on Friday"],
		@"the times come off the front", nil);
	ok([[memory lessonIn:@"- a line with no times"]
		isEqualToString:@"a line with no times"],
		@"and a line that never had any is unharmed", nil);
	/* A hyphen inside the sentence must not be mistaken for the separator, which
	   is why the separator is looked for near the front only. */
	ok([[memory lessonIn:@"a well-known thing - said plainly, at some length, so that the hyphen is far from the front"]
		rangeOfString:@"well-known"].location != NSNotFound,
		@"and a hyphen far into a sentence is not a separator", nil);

	printf("\n--- and a model is never shown the citation ---\n");

	/* The times are for a person and for tools/diary.py. A prompt gets the day
	   and the lesson, because a dated fact is worth more than an undated one and
	   a list of timestamps is worth nothing to a model. */
	NSString *stored = @"2026-08-27\t09:12,11:40\tthe release ships on Friday";
	NSString *shown = [memory durableForPrompt:stored];
	ok([shown isEqualToString:@"2026-08-27\tthe release ships on Friday"],
		@"the day stays and the times go", shown);
	ok([[memory durableForPrompt:@"2026-08-27\tan older line, from before this"]
		isEqualToString:@"2026-08-27\tan older line, from before this"],
		@"and a line written before any of this is left alone", nil);

	if(![[NSUserDefaults standardUserDefaults] boolForKey:@"slow"]) {
		notMeasured(@"whether a real engine complies with the format — the arm "
		            @"that decides whether this gate is a filter or a wall — "
		            @"needs --slow");
		[pool release];
		return NekoTestResult();
	}

	printf("\n--- and whether an engine actually cites ---\n");

	if([NekoBrains bestOnDeviceProvider] == nil) {
		notMeasured(@"no on-device engine here to ask");
		[pool release];
		return NekoTestResult();
	}

	NSDateFormatter *day = [[[NSDateFormatter alloc] init] autorelease];
	[day setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
	[day setDateFormat:@"yyyy-MM-dd"];
	NSURL *yesterday = [[memory directory] URLByAppendingPathComponent:
		[[day stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-86400.0]]
			stringByAppendingPathExtension:@"txt"]];
	NSString *before = [NSString stringWithContentsOfURL:yesterday
		encoding:NSUTF8StringEncoding error:NULL];
	[@"09:41\tyou\tsto preparando il rilascio di Neko 2.1\n"
	 @"11:02\tyou\tle note di rilascio sono per venerdì\n"
	 @"14:20\tyou\tdomani mando il changelog\n"
	 @"15:44\tsaw\tcambiato programma quattordici volte\n"
		writeToURL:yesterday atomically:YES encoding:NSUTF8StringEncoding error:NULL];

	NSURL *durableFile = [[memory directory] URLByAppendingPathComponent:@"durable.txt"];
	NSString *durableBefore = [NSString stringWithContentsOfURL:durableFile
		encoding:NSUTF8StringEncoding error:NULL] ?: @"";
	[@"" writeToURL:durableFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NekoMemoryReflected"];

	[memory reflectIfDue];
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:180.0];
	while([[memory durableLines] count] == 0 && [until timeIntervalSinceNow] > 0.0)
		spin(0.2);

	NSArray *kept = [memory durableLines];
	NSUInteger anchored = 0;
	NSEnumerator *e = [kept objectEnumerator];
	NSString *one;
	while((one = [e nextObject]) != nil) {
		printf("      %s\n", [one UTF8String]);
		if([[one componentsSeparatedByString:@"\t"] count] >= 3)
			anchored++;
	}
	ok([kept count] > 0,
		@"the gate is a filter and not a wall: something got through",
		[NSString stringWithFormat:@"%lu line(s)", (unsigned long)[kept count]]);
	ok([kept count] == 0 || anchored == [kept count],
		@"and everything kept names the notes it came from",
		[NSString stringWithFormat:@"%lu of %lu",
			(unsigned long)anchored, (unsigned long)[kept count]]);

	notMeasured(@"measured on whichever engine is best here, and not on the weak "
	            @"ones. A model that will not cite gets no durable lines at all, "
	            @"which is deliberate — docs/self-2.md quotes the finding that an "
	            @"ungoverned memory can be worse than none — and is a capability "
	            @"loss somebody should be told about rather than left to notice");

	[durableBefore writeToURL:durableFile atomically:YES
	                 encoding:NSUTF8StringEncoding error:NULL];
	if(before != nil)
		[before writeToURL:yesterday atomically:YES
		          encoding:NSUTF8StringEncoding error:NULL];
	else
		[[NSFileManager defaultManager] removeItemAtURL:yesterday error:NULL];

	[pool release];
	return NekoTestResult();
}
