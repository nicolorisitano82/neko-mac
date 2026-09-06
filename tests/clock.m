/* Whether the cat can count days.

   The reason this module exists is measured in tests/sums.m, which asks three
   models the same questions with the facts block they already get; this one
   measures the answer rather than the need. Every expected value here is worked
   out with NSCalendar inside the test, so it says the same thing next Tuesday and
   in March.

   And one of these is a regression rather than a feature. NSDataDetector, handed
   "al 3 marzo", answers **today at noon** and reports that it used the whole
   phrase; handed "3 marzo" it answers the third of March. The first draft of this
   module therefore said "mancano 12 ore" to a question about March, in a full
   sentence, with no sign of a problem. The preposition is stripped now, and the
   check for it is below. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoClock.h"

static NSCalendar *calendar(void) { return [NSCalendar currentCalendar]; }

static NSDate *startOfDay(NSDate *when)
{
	NSDate *start = nil;
	[calendar() rangeOfUnit:NSCalendarUnitDay startDate:&start interval:NULL forDate:when];
	return start;
}

static NSInteger daysFromTodayTo(NSDate *when)
{
	return [[calendar() components:NSCalendarUnitDay
	                      fromDate:startOfDay([NSDate date])
	                        toDate:startOfDay(when)
	                       options:0] day];
}

/* The next time that weekday comes round, not counting today. */
static NSDate *nextWeekday(NSInteger weekday)
{
	NSDateComponents *want = [[[NSDateComponents alloc] init] autorelease];
	[want setWeekday:weekday];
	return [calendar() nextDateAfterDate:[NSDate date] matchingComponents:want
	                             options:NSCalendarMatchNextTime];
}

static NSDate *nextDayAndMonth(NSInteger day, NSInteger month)
{
	NSDateComponents *want = [[[NSDateComponents alloc] init] autorelease];
	[want setDay:day];
	[want setMonth:month];
	[want setHour:12];
	return [calendar() nextDateAfterDate:[NSDate date] matchingComponents:want
	                             options:NSCalendarMatchNextTime];
}

/* What the answer must contain for a target that many days away. */
static NSString *expectedFor(NSInteger days)
{
	if(days == 0)
		return NSLocalizedString(@"That is today.", nil);
	if(days == 1)
		return NSLocalizedString(@"That is tomorrow.", nil);
	return [NSString stringWithFormat:@"%ld", (long)days];
}

static void answers(NSString *question, NSString *wanted)
{
	NSString *said = [NekoClock wantedFor:question];
	ok(said != nil && [said rangeOfString:wanted].location != NSNotFound,
		question, said ?: @"(nothing)");
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSDateFormatter *full = [[[NSDateFormatter alloc] init] autorelease];
	[full setLocale:[NSLocale localeWithLocaleIdentifier:
		[[[NSBundle mainBundle] preferredLocalizations] firstObject]]];
	[full setDateStyle:NSDateFormatterFullStyle];
	[full setTimeStyle:NSDateFormatterNoStyle];

	NSDateFormatter *clock = [[[NSDateFormatter alloc] init] autorelease];
	[clock setLocale:[full locale]];
	[clock setDateStyle:NSDateFormatterNoStyle];
	[clock setTimeStyle:NSDateFormatterShortStyle];

	printf("\n--- the time and the day, which need no arithmetic ---\n");

	answers(@"che ore sono?", [clock stringFromDate:[NSDate date]]);
	answers(@"what time is it", [clock stringFromDate:[NSDate date]]);
	answers(@"che giorno è?", [full stringFromDate:[NSDate date]]);
	answers(@"che giorno è domani?",
		[full stringFromDate:[NSDate dateWithTimeIntervalSinceNow:86400.0]]);
	answers(@"che giorno è dopodomani?",
		[full stringFromDate:[calendar() dateByAddingUnit:NSCalendarUnitDay value:2
		                                           toDate:[NSDate date] options:0]]);
	answers(@"what's the date", [full stringFromDate:[NSDate date]]);

	printf("\n--- and the days between two dates, which is the part they get wrong ---\n");

	NSDate *friday = nextWeekday(6);
	printf("      today is %s; the next Friday is %s, %ld days off\n",
		[[full stringFromDate:[NSDate date]] UTF8String],
		[[full stringFromDate:friday] UTF8String], (long)daysFromTodayTo(friday));
	answers(@"quanti giorni mancano a venerdì?", expectedFor(daysFromTodayTo(friday)));
	answers(@"how long until friday?", expectedFor(daysFromTodayTo(friday)));
	answers(@"cuántos días faltan para el viernes?", expectedFor(daysFromTodayTo(friday)));

	NSDate *christmas = nextDayAndMonth(25, 12);
	answers(@"quanto manca al 25 dicembre?", expectedFor(daysFromTodayTo(christmas)));

	/* The regression the header is about: with the preposition left in, this
	   answered with today. */
	NSDate *third = nextDayAndMonth(3, 3);
	printf("      the next 3 March is %s, %ld days off\n",
		[[full stringFromDate:third] UTF8String], (long)daysFromTodayTo(third));
	answers(@"quanto manca al 3 marzo?", expectedFor(daysFromTodayTo(third)));

	printf("\n--- and the half that matters: what it stays out of ---\n");

	NSArray *not = [NSArray arrayWithObjects:
		@"quanto manca al lancio del prodotto",
		@"quanto manca alla fine",
		@"quanto manca ancora?",
		@"quanti giorni di ferie ho",
		@"che giorno è meglio per uscire",
		@"che giorno è il tuo compleanno",
		@"che ore sono buone per correre",
		@"a che ora è meglio chiamare",
		@"quanto manca a Natale",
		@"metti un timer di dieci minuti",
		@"quanto fa 47 per 23", nil];
	printf("\n--- and what day a date fell on, which is a lookup and not a sum ---\n");

	/* The gap tests/reach.m found, and it was on the website as a thing that
	   worked: "what day was the 3rd of March". It did not — the triggers were
	   there but nothing behind them could read a date, so every one of these
	   reached a model. A model here is the thing NekoClock.h measured at one of
	   nine.

	   Dates with a year on them, so the answer is the same next year and the
	   check does not rot the way tests/calendar.m did. */
	NSArray *dated = [NSArray arrayWithObjects:
		@"che giorno era il 3 marzo 2026?",
		@"che giorno è il 25 dicembre 2027?",
		@"what day was 3 March 2026?",
		@"quel jour est le 3 mars 2026?",
		@"qué día es el 25 de diciembre de 2027?", nil];
	NSEnumerator *d = [dated objectEnumerator];
	NSString *asked;
	NSUInteger answered = 0;
	while((asked = [d nextObject]) != nil) {
		NSString *said = [NekoClock wantedFor:asked];
		if([said length] > 0)
			answered++;
		ok([said length] > 0, asked, said ?: @"reached a model");
	}
	ok(answered == [dated count], @"all of them, in four languages",
		[NSString stringWithFormat:@"%lu of %lu", (unsigned long)answered,
			(unsigned long)[dated count]]);

	/* 3 March 2026 was a Tuesday and 25 December 2027 is a Saturday. Checked
	   against NSCalendar rather than typed from memory, because a weekday
	   somebody remembered wrongly is exactly the confident wrong answer this
	   file exists to stop. */
	NSDateComponents *parts = [[[NSDateComponents alloc] init] autorelease];
	[parts setYear:2026]; [parts setMonth:3]; [parts setDay:3]; [parts setHour:12];
	NSDate *thatDay = [[NSCalendar currentCalendar] dateFromComponents:parts];
	NSDateFormatter *weekday = [[[NSDateFormatter alloc] init] autorelease];
	[weekday setLocale:[NSLocale localeWithLocaleIdentifier:@"it_IT"]];
	[weekday setDateFormat:@"EEEE"];
	NSString *itWas = [weekday stringFromDate:thatDay];
	NSString *said = [NekoClock wantedFor:@"che giorno era il 3 marzo 2026?"];
	ok([said rangeOfString:itWas].location != NSNotFound,
		@"and it names the right weekday, not just a weekday",
		[NSString stringWithFormat:@"%@ — the calendar says %@", said, itWas]);

	/* The tense, because a language that has one needs it used. */
	NSString *ahead = [NekoClock wantedFor:@"che giorno è il 25 dicembre 2027?"];
	ok([ahead rangeOfString:@"sarà"].location != NSNotFound,
		@"a day still to come is spoken of in the future", ahead);
	ok([said rangeOfString:@"era"].location != NSNotFound,
		@"and one that has been, in the past", said);

	printf("\n--- and it still says nothing to the rest ---\n");
	NSEnumerator *quiet = [not objectEnumerator];
	NSString *sentence;
	while((sentence = [quiet nextObject]) != nil) {
		NSString *said = [NekoClock wantedFor:sentence];
		ok(said == nil, sentence, said ?: @"silent");
	}

	notMeasured(@"\"quanto manca a Natale\" is in the silent list rather than the "
	            @"answered one: NSDataDetector does not know the feast days, and a "
	            @"holiday table in four countries is a bigger promise than this is");

	[pool release];
	return NekoTestResult();
}
