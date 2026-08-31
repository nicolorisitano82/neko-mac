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
