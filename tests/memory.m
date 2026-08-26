/* The diary: that it can be read, that it is bounded, that it can be deleted,
   and that it never grows into more than a small model can hold.

   Everything here runs against the real file in Application Support, which is
   why every line it writes is marked and removed again at the end. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoMemory.h"
#import "NekoBrains.h"

@interface NekoMemory (Testing)
- (NSString *)tidy:(NSString *)text;
@end

static NSString * const NekoTestMark = @"zzq-test";

int main(int argc, const char *argv[])
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL slow = [[NSUserDefaults standardUserDefaults] boolForKey:@"slow"];
	NekoMemory *memory = [NekoMemory sharedMemory];

	printf("\n--- what it writes down ---\n");

	[memory noteNoticed:[NSString stringWithFormat:@"%@ Xcode, forty minutes", NekoTestMark]];
	[memory noteSaid:[NSString stringWithFormat:@"%@ that build has been going a while", NekoTestMark]];
	[memory noteHeard:[NSString stringWithFormat:@"%@ it always does on Fridays", NekoTestMark]];

	NSString *today = [memory contextForPrompt];
	ok([today rangeOfString:NekoTestMark].location != NSNotFound,
		@"three kinds of line, and they come back", nil);
	ok([today length] <= 1000,
		@"the block a model is handed is capped",
		[NSString stringWithFormat:@"%lu characters", (unsigned long)[today length]]);

	NSMutableString *huge = [NSMutableString stringWithString:NekoTestMark];
	while([huge length] < 4000)
		[huge appendString:@" and then something else happened as well"];
	[memory noteNoticed:huge];
	ok([[memory contextForPrompt] length] <= 1000,
		@"and stays capped however long the day was",
		[NSString stringWithFormat:@"%lu characters",
			(unsigned long)[[memory contextForPrompt] length]]);

	NSString *path = [[memory directory] path];
	ok([[NSFileManager defaultManager] fileExistsAtPath:path],
		@"it is a folder somebody can open", path);
	printf("      %lld bytes over %lu day(s)\n",
		[memory bytesOnDisk], (unsigned long)[memory dayCount]);

	printf("\n--- written the way somebody writes in a margin ---\n");

	/* The same notes as sentences and as notes. Both say the same thing; one of
	   them is read back to a model every time it is asked anything. */
	NSArray *sentences = [NSArray arrayWithObjects:
		@"Ho notato che la build di Xcode è di nuovo lenta, per la terza volta oggi.",
		@"Sta lavorando al rilascio di Neko 2.1 e le note di rilascio sono per venerdì.",
		@"Mi ha detto che il test non è passato e che non vuole rifarlo adesso.",
		@"The build has been running for over forty minutes in Xcode again.", nil];
	NSUInteger longWay = 0, shortWay = 0;
	NSEnumerator *s = [sentences objectEnumerator];
	NSString *sentence;
	while((sentence = [s nextObject]) != nil) {
		NSString *note = [memory tidy:sentence];
		longWay += [sentence length];
		shortWay += [note length];
		printf("      %s\n        → %s\n", [sentence UTF8String], [note UTF8String]);
	}
	ok(shortWay < longWay,
		@"a third or so of it is scaffolding",
		[NSString stringWithFormat:@"%lu characters → %lu, %.0f%% less",
			(unsigned long)longWay, (unsigned long)shortWay,
			100.0 * (1.0 - (double)shortWay / (double)longWay)]);

	NSString *negated = [memory tidy:@"Mi ha detto che il test non è passato e che non vuole rifarlo adesso."];
	ok([negated rangeOfString:@"non"].location != NSNotFound,
		@"and the word that inverts a note survives", negated);

	NSString *named = [memory tidy:@"Sta lavorando al rilascio di Neko 2.1 per venerdì alle 14:30."];
	ok([named rangeOfString:@"Neko"].location != NSNotFound
	   && [named rangeOfString:@"2.1"].location != NSNotFound
	   && [named rangeOfString:@"14:30"].location != NSNotFound,
		@"so do names, versions and times", named);

	NSString *allFiller = [memory tidy:@"che di la"];
	ok([allFiller length] > 0, @"a line of nothing but filler is kept as it was",
		allFiller);

	printf("\n--- and the same note twice is one note ---\n");

	[memory forgetLinesContaining:NekoTestMark];
	NSString *repeated = [NSString stringWithFormat:@"%@ Xcode, quaranta minuti", NekoTestMark];
	[memory noteNoticed:repeated];
	[memory noteNoticed:repeated];
	[memory noteNoticed:repeated];
	NSUInteger written = 0;
	NSEnumerator *lines = [[[memory contextForPrompt]
		componentsSeparatedByString:@"\n"] objectEnumerator];
	NSString *one;
	while((one = [lines nextObject]) != nil)
		if([one rangeOfString:NekoTestMark].location != NSNotFound)
			written++;
	ok(written == 1, @"three identical looks, one line",
		[NSString stringWithFormat:@"%lu line(s)", (unsigned long)written]);

	printf("\n--- and what it forgets ---\n");

	long long before = [memory bytesOnDisk];
	BOOL removed = [memory forgetLinesContaining:NekoTestMark];
	ok(removed, @"a line can be taken out by what is in it", nil);
	ok([[memory contextForPrompt] rangeOfString:NekoTestMark].location == NSNotFound,
		@"and leaves no trace behind it",
		[NSString stringWithFormat:@"%lld bytes → %lld", before, [memory bytesOnDisk]]);

	if(slow) {
		printf("\n--- the reflection, on notes written this way ---\n");

		/* A staged yesterday, in the short form the diary now uses. What has to
		   come out is a handful of lines that would still mean something on
		   Monday — not "Xcode open forty minutes", which was true that afternoon
		   and is noise by the end of the week. */
		NSURL *durableFile = [[memory directory]
			URLByAppendingPathComponent:@"durable.txt"];
		NSString *keptBefore = [NSString stringWithContentsOfURL:durableFile
			encoding:NSUTF8StringEncoding error:NULL] ?: @"";
		id reflectedBefore = [[NSUserDefaults standardUserDefaults]
			objectForKey:@"NekoMemoryReflected"];

		NSDateFormatter *day = [[[NSDateFormatter alloc] init] autorelease];
		[day setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
		[day setDateFormat:@"yyyy-MM-dd"];
		NSDate *yesterday = [NSDate dateWithTimeIntervalSinceNow:-86400.0];
		NSURL *staged = [[memory directory] URLByAppendingPathComponent:
			[[day stringFromDate:yesterday] stringByAppendingPathExtension:@"txt"]];
		NSString *before = [NSString stringWithContentsOfURL:staged
			encoding:NSUTF8StringEncoding error:NULL];

		NSString *dayOfNotes =
			@"09:12\tsaw\tXcode, quaranta minuti\n"
			@"09:40\tsed\tbuild lenta, terza volta oggi\n"
			@"09:41\tyou\tsto preparando rilascio Neko 2.1\n"
			@"10:15\tsaw\tXcode, quaranta minuti\n"
			@"11:02\tyou\tnote di rilascio per venerdì\n"
			@"11:30\tsaw\tSafari, dieci minuti\n"
			@"14:03\tsed\tDMG finito\n"
			@"14:20\tyou\tdomani mando il changelog\n"
			@"15:44\tsaw\tcambiato programma quattordici volte\n"
			@"16:10\tsaw\tTerminal, cinque minuti\n";
		[dayOfNotes writeToURL:staged atomically:YES
		              encoding:NSUTF8StringEncoding error:NULL];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NekoMemoryReflected"];
		/* Emptied first, or the lines kept from some earlier day are read as
		   this run's result and the test passes without reflecting anything. */
		[@"" writeToURL:durableFile atomically:YES
		       encoding:NSUTF8StringEncoding error:NULL];

		NSDate *started = [NSDate date];
		[memory reflectIfDue];
		NSDate *until = [NSDate dateWithTimeIntervalSinceNow:120.0];
		while([[memory durableLines] count] == 0 && [until timeIntervalSinceNow] > 0.0)
			spin(0.2);
		NSArray *kept = [memory durableLines];
		printf("      %.1f s\n", -[started timeIntervalSinceNow]);
		NSEnumerator *k = [kept objectEnumerator];
		NSString *one;
		while((one = [k nextObject]) != nil)
			printf("      %s\n", [one UTF8String]);

		ok([kept count] > 0 && [kept count] <= 4,
			@"a day of short notes still reduces to a few lines",
			[NSString stringWithFormat:@"%lu line(s)", (unsigned long)[kept count]]);
		NSString *all = [kept componentsJoinedByString:@" | "];
		ok([all rangeOfString:@"2.1"].location != NSNotFound
		   || [[all lowercaseString] rangeOfString:@"rilascio"].location != NSNotFound
		   || [[all lowercaseString] rangeOfString:@"release"].location != NSNotFound,
			@"and keeps what would still matter on Monday", nil);
		ok([[all lowercaseString] rangeOfString:@"quaranta"].location == NSNotFound
		   && [[all lowercaseString] rangeOfString:@"quattordici"].location == NSNotFound,
			@"and throws away what was true only that afternoon", nil);

		/* Put the diary back exactly as it was found. */
		[keptBefore writeToURL:durableFile atomically:YES
		              encoding:NSUTF8StringEncoding error:NULL];
		if(before != nil)
			[before writeToURL:staged atomically:YES
			          encoding:NSUTF8StringEncoding error:NULL];
		else
			[[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
		if(reflectedBefore != nil)
			[[NSUserDefaults standardUserDefaults] setObject:reflectedBefore
			                                          forKey:@"NekoMemoryReflected"];
	}

	int result = NekoTestResult();
	[pool release];
	return result;
}
