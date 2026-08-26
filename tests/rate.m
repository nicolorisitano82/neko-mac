/* Step 5: how often it speaks. A day at a time, replayed in a second, with the
   clock and the seams staged and the governor itself the real thing. Then the
   wiring: that a remark counts, and that what became of it moves the pace. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoRate.h"
#import "NekoAsk.h"
#import "NekoBubble.h"
#import "NekoDesktop.h"

@interface NekoAsk (Testing)
- (void)cancelEverything;
- (void)finish;
- (void)bubbleDismissed:(id)sender;
@end


/* A clock that does what it is told, and a Mac somebody may or may not be at. */
@interface FakeRate : NekoRate
{
	NSDate *clock;
	NSTimeInterval sinceRemark;
	BOOL present;
	NSTimeInterval floorSeconds;
}
- (void)setClock:(NSDate *)date;
- (void)setSince:(NSTimeInterval)seconds;
- (void)setPresent:(BOOL)yes;
- (void)setFloor:(NSTimeInterval)seconds;
@end

@implementation FakeRate
- (NSDate *)now { return clock; }
- (NSTimeInterval)secondsSinceLastRemark { return sinceRemark; }
- (BOOL)atTheMac { return present; }
- (NSTimeInterval)floorFromPreferences { return floorSeconds; }
- (void)setClock:(NSDate *)date { [clock release]; clock = [date retain]; }
- (void)setSince:(NSTimeInterval)seconds { sinceRemark = seconds; }
- (void)setPresent:(BOOL)yes { present = yes; }
- (void)setFloor:(NSTimeInterval)seconds { floorSeconds = seconds; }
@end

/* Reproducible, so that two runs of the same day are the same day. */
static unsigned long seed = 20260825UL;
static unsigned nextRandom(unsigned bound)
{
	seed = seed * 6364136223846793005UL + 1442695040888963407UL;
	return (unsigned)((seed >> 33) % bound);
}

typedef enum { ReplyAlways, ReplyNever, ReplyHalf, ReplyClicksAway } Reaction;

/* One day at the Mac, a minute at a time. Seams turn up every quarter of an
   hour or so, and how good they are is what the governor has to hold out for. */
static void playDay(FakeRate *rate, NSDate *midnight, NSTimeInterval hoursAtTheMac,
                    Reaction reaction, int *saidOut, int *answeredOut,
                    NSTimeInterval *shortestGap)
{
	int minutes = (int)(hoursAtTheMac * 60.0);
	int said = 0, answered = 0;
	NSTimeInterval since = 4.0 * 3600.0;   /* a fresh morning */
	NSTimeInterval shortest = 1.0e9;
	int minute;
	for(minute = 0; minute < minutes; minute++) {
		[rate setClock:[midnight dateByAddingTimeInterval:9.0 * 3600.0 + minute * 60.0]];
		[rate setPresent:YES];
		[rate setSince:since];

		/* A seam every fifteen minutes: half of them small, a third medium, the
		   rest the end of a long stretch in one program. */
		NekoBreakpoint seam = NekoBreakpointNone;
		if(minute % 15 == 0) {
			unsigned roll = nextRandom(10);
			seam = roll < 5 ? NekoBreakpointFine
			     : (roll < 8 ? NekoBreakpointMedium : NekoBreakpointCoarse);
		}

		if([rate mayInterruptNow] && seam != NekoBreakpointNone
		   && seam >= [rate seamNeeded]) {
			if(since < shortest)
				shortest = since;
			[rate noteSaid];
			said++;
			BOOL replied = (reaction == ReplyAlways)
				|| (reaction == ReplyHalf && (nextRandom(2) == 0));
			if(replied) {
				[rate noteAnswered];
				answered++;
			} else if(reaction == ReplyClicksAway) {
				[rate noteDismissed];
			} else {
				[rate noteIgnored];
			}
			since = 0.0;
		}
		since += 60.0;
	}
	*saidOut = said;
	*answeredOut = answered;
	*shortestGap = shortest;
}

/* The rule this step replaced, kept here to be measured against: an interval
   floor, a seam requirement that relaxed with the silence alone, and no notion
   whatever of how many times it had already spoken today. Same day, same seams,
   same seed. */
static int playOldDay(NSTimeInterval floorSeconds, NSTimeInterval hoursAtTheMac)
{
	int minutes = (int)(hoursAtTheMac * 60.0), said = 0;
	NSTimeInterval since = 4.0 * 3600.0;
	int minute;
	for(minute = 0; minute < minutes; minute++) {
		NekoBreakpoint seam = NekoBreakpointNone;
		if(minute % 15 == 0) {
			unsigned roll = nextRandom(10);
			seam = roll < 5 ? NekoBreakpointFine
			     : (roll < 8 ? NekoBreakpointMedium : NekoBreakpointCoarse);
		}
		NekoBreakpoint needed = since > floorSeconds * 3.0 ? NekoBreakpointFine
			: (since > floorSeconds * 1.5 ? NekoBreakpointMedium : NekoBreakpointCoarse);
		if(since >= floorSeconds && seam != NekoBreakpointNone && seam >= needed) {
			said++;
			since = 0.0;
		}
		since += 60.0;
	}
	return said;
}

static void clearState(void)
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *keys = [NSArray arrayWithObjects:NekoRateTargetKey, NekoRateDayKey,
		NekoRateSaidKey, NekoRateAnsweredKey, NekoRateIgnoredKey,
		NekoRateDismissedKey, NekoRateActiveKey, nil];
	NSEnumerator *e = [keys objectEnumerator];
	NSString *key;
	while((key = [e nextObject]) != nil)
		[defaults removeObjectForKey:key];
}

static NSString *runWeek(Reaction reaction, NSTimeInterval hours,
                         NSTimeInterval floorMinutes, int *lastDaySaid)
{
	clearState();
	seed = 20260825UL;
	FakeRate *rate = [[FakeRate alloc] init];
	[rate setFloor:floorMinutes * 60.0];
	NSMutableString *line = [NSMutableString string];
	NSDate *midnight = [NSDate dateWithTimeIntervalSince1970:1787011200.0];  /* a Monday */
	int day;
	for(day = 0; day < 5; day++) {
		int said = 0, answered = 0;
		NSTimeInterval shortest = 0.0;
		playDay(rate, [midnight dateByAddingTimeInterval:day * 86400.0],
		        hours, reaction, &said, &answered, &shortest);
		[line appendFormat:@"%d/%d ", said, answered];
		if(day == 4 && lastDaySaid != NULL)
			*lastDaySaid = said;
	}
	[line appendFormat:@"→ aiming at %.1f", [rate target]];
	[rate release];
	return line;
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	printf("\n--- the rule this replaced, on the same day ---\n");
	seed = 20260825UL;
	int old10 = playOldDay(600.0, 8.0);
	seed = 20260825UL;
	int old30 = playOldDay(1800.0, 8.0);
	printf("interval of 10 minutes %d remarks in the day\n", old10);
	printf("interval of 30 minutes %d remarks in the day\n", old30);
	ok(old10 > 15, @"the old rule had no idea how many it had said",
		[NSString stringWithFormat:@"%d in one day at ten minutes", old10]);

	printf("\n--- five working days, said/answered each day ---\n");

	int last = 0;
	NSString *week;

	week = runWeek(ReplyAlways, 8.0, 10.0, &last);
	printf("answers every time     %s\n", [week UTF8String]);
	ok(last >= 8 && last <= 15, @"a colleague's rate when it is working",
		[NSString stringWithFormat:@"%d on the fifth day", last]);

	week = runWeek(ReplyHalf, 8.0, 10.0, &last);
	printf("answers half the time  %s\n", [week UTF8String]);
	ok(last >= 8 && last <= 15, @"still in the band when half of them land",
		[NSString stringWithFormat:@"%d on the fifth day", last]);

	week = runWeek(ReplyNever, 8.0, 10.0, &last);
	printf("never answers          %s\n", [week UTF8String]);
	ok(last <= 5, @"quietens down when nothing comes back",
		[NSString stringWithFormat:@"%d on the fifth day", last]);

	week = runWeek(ReplyClicksAway, 8.0, 10.0, &last);
	printf("clicks them away       %s\n", [week UTF8String]);
	ok(last <= 5, @"and faster when they are waved away",
		[NSString stringWithFormat:@"%d on the fifth day", last]);

	printf("\n--- the day is measured in hours at the Mac ---\n");

	int shortDay = 0;
	week = runWeek(ReplyAlways, 3.0, 10.0, &shortDay);
	printf("three hours a day      %s\n", [week UTF8String]);
	ok(shortDay <= 8, @"three hours is not a working day",
		[NSString stringWithFormat:@"%d remarks", shortDay]);

	printf("\n--- the interval in the preferences is the ceiling ---\n");

	clearState();
	seed = 20260825UL;
	FakeRate *strict = [[FakeRate alloc] init];
	[strict setFloor:60.0 * 60.0];       /* at most once an hour */
	int said = 0, answered = 0;
	NSTimeInterval shortest = 0.0;
	playDay(strict, [NSDate dateWithTimeIntervalSince1970:1787011200.0], 8.0,
	        ReplyAlways, &said, &answered, &shortest);
	printf("at most once an hour   %d remarks, closest together %.0f min\n",
		said, shortest / 60.0);
	ok(said <= 8, @"an hour apart cannot make fifteen a day",
		[NSString stringWithFormat:@"%d remarks", said]);
	ok(shortest >= 3600.0, @"and none of them came sooner than that",
		[NSString stringWithFormat:@"%.0f minutes", shortest / 60.0]);
	[strict release];

	printf("\n--- the counts belong to a day ---\n");

	clearState();
	FakeRate *rate = [[FakeRate alloc] init];
	[rate setFloor:600.0];
	[rate setPresent:YES];
	NSDate *monday = [NSDate dateWithTimeIntervalSince1970:1787011200.0];
	[rate setClock:[monday dateByAddingTimeInterval:10.0 * 3600.0]];
	[rate noteSaid]; [rate noteSaid];
	ok([rate saidToday] == 2, @"two today", nil);
	[rate setClock:[monday dateByAddingTimeInterval:34.0 * 3600.0]];   /* tomorrow */
	ok([rate saidToday] == 0, @"none tomorrow", nil);
	ok([rate target] > 0.0, @"but the pace it learned is still there",
		[NSString stringWithFormat:@"%.1f", [rate target]]);
	[rate release];

	printf("\n--- what became of a remark ---\n");

	clearState();
	NekoAsk *ask = [NekoAsk sharedAsk];
	NekoRate *live = [NekoRate sharedRate];
	Ivar found = class_getInstanceVariable([NekoAsk class], "bubble");
	NekoBubble *bubble = (NekoBubble *)object_getIvar(ask, found);
	(void)bubble;

	double before = [live target];
	NSUInteger saidBefore = [live saidToday];
	[ask sayUnprompted:@"Xcode has been open a while."];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	ok([live saidToday] == saidBefore + 1, @"a remark counts against the day",
		[NSString stringWithFormat:@"%lu", (unsigned long)[live saidToday]]);
	ok([live target] == before, @"and nothing is decided about it yet", nil);

	/* Nothing was listening, so there is no verdict: the pace must not move. */
	[ask finish];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	ok([live target] == before,
		@"with nothing listening, no verdict at all",
		[NSString stringWithFormat:@"%.1f", [live target]]);

	[ask cancelEverything];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	before = [live target];
	[ask sayUnprompted:@"Two windows of the same file."];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	[ask bubbleDismissed:nil];
	ok([live target] == before - 2.0 || [live target] == 4.0,
		@"clicked away is worth two",
		[NSString stringWithFormat:@"%.1f from %.1f", [live target], before]);

	clearState();
	(void)defaults;
	[pool release];
	return NekoTestResult();
}
