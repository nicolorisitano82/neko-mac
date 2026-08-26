/* What happens to a memory when it turns thirty days old.

   It used to be dropped — silently, once there were forty of them. Now it goes
   through a second pass with everything else that is expiring, and what survives
   becomes a standing line with no date on it: the nightly pass asks what will
   still be true on Monday, this one asks what will still be true in six months.

   The rule the whole change exists for is the one at the end: with no engine to
   read them with, nothing is deleted at all. Age alone never throws anything
   away unread. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoMemory.h"
#import "NekoBrains.h"
#import "NekoAnswerProvider.h"

@interface NekoMemory (Testing)
- (NSURL *)standingFile;
- (NSURL *)durableFile;
- (NSArray *)expiringLines;
@end

static NSString *contentsOf(NSURL *url)
{
	return [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding
	                                  error:NULL] ?: @"";
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NekoMemory *memory = [NekoMemory sharedMemory];

	/* Whatever is really there comes back at the end. */
	NSString *durableBefore = contentsOf([memory durableFile]);
	NSString *standingBefore = contentsOf([memory standingFile]);

	NSDateFormatter *day = [[[NSDateFormatter alloc] init] autorelease];
	[day setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
	[day setDateFormat:@"yyyy-MM-dd"];
	NSString *old = [day stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-45.0 * 86400.0]];
	NSString *recent = [day stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-2.0 * 86400.0]];

	NSMutableString *staged = [NSMutableString string];
	NSArray *aMonthAgo = [NSArray arrayWithObjects:
		@"the release notes are due Friday",
		@"finished the DMG on Thursday and shipped on Friday",
		@"the changelog was left until last again",
		@"release notes due Friday, as usual",
		@"prefers to write the changelog after the build passes",
		@"shipped 2.0 on a Friday afternoon",
		@"asked twice not to be interrupted during a build",
		@"Xcode was open for forty minutes on Tuesday",
		@"switched programs fourteen times that afternoon",
		@"the build was slow all week", nil];
	NSEnumerator *e = [aMonthAgo objectEnumerator];
	NSString *line;
	while((line = [e nextObject]) != nil)
		[staged appendFormat:@"%@\t%@\n", old, line];
	[staged appendFormat:@"%@\t%@\n", recent, @"working on the iPhone study"];
	[staged writeToURL:[memory durableFile] atomically:YES
	          encoding:NSUTF8StringEncoding error:NULL];
	[@"" writeToURL:[memory standingFile] atomically:YES
	       encoding:NSUTF8StringEncoding error:NULL];

	printf("\n--- what has aged out ---\n");

	ok([[memory expiringLines] count] == [aMonthAgo count],
		@"the month-old lines are the ones expiring",
		[NSString stringWithFormat:@"%lu of %lu",
			(unsigned long)[[memory expiringLines] count],
			(unsigned long)[[memory durableLines] count]]);
	ok([[memory durableLines] count] == [aMonthAgo count] + 1,
		@"and the recent one is not", nil);

	printf("\n--- with nothing to read them with ---\n");

	/* The rule: no engine, no deletion. Simulated by asking what the engine is
	   and saying so, since a Mac with one cannot be talked out of having it. */
	id<NekoAnswerProvider> engine = [NekoBrains bestOnDeviceProvider];
	if(engine == nil || ![engine isConfigured]) {
		[memory distilIfDue];
		spin(1.0);
		ok([[memory durableLines] count] == [aMonthAgo count] + 1,
			@"nothing was deleted for age alone", nil);
		notMeasured(@"the distillation itself: there is no on-device engine here");
	} else {
		printf("      engine: %s\n", [NSStringFromClass([(id)engine class]) UTF8String]);

		printf("\n--- and with an engine ---\n");
		NSDate *started = [NSDate date];
		[memory distilIfDue];
		NSDate *until = [NSDate dateWithTimeIntervalSinceNow:120.0];
		while([[memory standingLines] count] == 0 && [until timeIntervalSinceNow] > 0.0)
			spin(0.2);
		NSTimeInterval took = -[started timeIntervalSinceNow];

		NSArray *standing = [memory standingLines];
		printf("      %.1f s, %lu standing line(s) from %lu:\n", took,
			(unsigned long)[standing count], (unsigned long)[aMonthAgo count]);
		NSEnumerator *s = [standing objectEnumerator];
		NSString *one;
		while((one = [s nextObject]) != nil)
			printf("        %s\n", [one UTF8String]);

		ok([standing count] > 0 && [standing count] <= 8,
			@"a month of lines becomes a handful",
			[NSString stringWithFormat:@"%lu", (unsigned long)[standing count]]);

		NSString *all = [[standing componentsJoinedByString:@" | "] lowercaseString];
		ok([all rangeOfString:@"\t"].location == NSNotFound
		   && [all rangeOfString:@"20"].location == NSNotFound,
			@"with no dates left on them", nil);
		ok([all rangeOfString:@"forty minutes"].location == NSNotFound
		   && [all rangeOfString:@"fourteen"].location == NSNotFound,
			@"and the noise of single afternoons gone", nil);
		ok([all rangeOfString:@"friday"].location != NSNotFound
		   || [all rangeOfString:@"changelog"].location != NSNotFound
		   || [all rangeOfString:@"interrupt"].location != NSNotFound,
			@"while what repeated across the month survives", nil);

		ok([[memory expiringLines] count] == 0,
			@"the expired lines are gone, now that they have been read", nil);
		ok([[memory durableLines] count] == 1,
			@"and the recent one is untouched",
			[NSString stringWithFormat:@"%lu left", (unsigned long)[[memory durableLines] count]]);

		printf("\n--- and it leads the block a model is given ---\n");
		NSString *block = [memory contextForPrompt];
		ok([block rangeOfString:@"months rather than days"].location != NSNotFound,
			@"the standing lines come first", nil);
		ok([block length] <= 1000, @"and the whole block still fits the budget",
			[NSString stringWithFormat:@"%lu characters", (unsigned long)[block length]]);

		printf("\n--- and forgetting still means it ---\n");
		NSString *word = [[standing firstObject] length] > 6
			? [[standing firstObject] substringToIndex:6] : @"Friday";
		[memory forgetLinesContaining:word];
		ok([[[memory standingLines] componentsJoinedByString:@" "]
				rangeOfString:word].location == NSNotFound,
			@"a standing line can be forgotten like any other", word);
	}

	[durableBefore writeToURL:[memory durableFile] atomically:YES
	                 encoding:NSUTF8StringEncoding error:NULL];
	if([standingBefore length] > 0)
		[standingBefore writeToURL:[memory standingFile] atomically:YES
		                  encoding:NSUTF8StringEncoding error:NULL];
	else
		[[NSFileManager defaultManager] removeItemAtURL:[memory standingFile] error:NULL];

	int result = NekoTestResult();
	[pool release];
	return result;
}
