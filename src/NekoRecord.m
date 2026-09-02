#import "NekoRecord.h"
#import "NekoMemory.h"

#define NekoRecordLocalized(key) NSLocalizedStringFromTable(key, @"Localizable", nil)

/* Two, not three: the bubble holds a sentence or two, and a third quotation is
   somebody's diary being read out at them. */
static const NSUInteger NekoRecordMost = 2;

/* The phrases that ask what was said before. A first person and a past between
   them, both required — "ti ricordi" on its own is in "ti ricordi come si
   scrive?", which is a question about spelling and none of this file's business. */
static NSArray *NekoRecordAsking(void)
{
	static NSArray *asking = nil;
	if(asking != nil)
		return asking;
	asking = [[NSArray alloc] initWithObjects:
		/* Italian */
		@"cosa avevo detto", @"che cosa avevo detto", @"che avevo detto",
		@"avevo detto", @"avevo scritto", @"l'avevo detto", @"te l'avevo detto",
		@"ti avevo detto", @"quando avevo", @"cosa ho detto", @"che ho detto",
		@"ti ricordi cosa", @"ti ricordi quando", @"ti ricordi che cosa",
		@"cosa ti ho detto", @"come avevo",
		/* English */
		@"what did i say", @"did i say", @"had i said", @"what had i said",
		@"when did i say", @"what did i tell you", @"did i tell you",
		@"do you remember what", @"do you remember when",
		/* French */
		@"j'avais dit", @"qu'avais-je dit", @"je t'avais dit",
		@"qu'est-ce que j'avais dit", @"tu te souviens quand",
		@"tu te souviens de ce que",
		/* Spanish */
		@"había dicho", @"habia dicho", @"te había dicho", @"qué había dicho",
		@"que habia dicho", @"te acuerdas de lo que", @"te acuerdas cuándo",
		nil];
	return asking;
}

/* The day, as somebody would say it rather than as a file is named. */
static NSString *NekoRecordDay(NSString *stamp)
{
	NSDateFormatter *stored = [[[NSDateFormatter alloc] init] autorelease];
	[stored setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
	[stored setDateFormat:@"yyyy-MM-dd"];
	NSDate *when = [stored dateFromString:stamp];
	if(when == nil)
		return stamp;

	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *midnight = nil, *thatDay = nil;
	[calendar rangeOfUnit:NSCalendarUnitDay startDate:&midnight interval:NULL
	              forDate:[NSDate date]];
	[calendar rangeOfUnit:NSCalendarUnitDay startDate:&thatDay interval:NULL
	              forDate:when];
	NSInteger back = [[calendar components:NSCalendarUnitDay fromDate:thatDay
	                               toDate:midnight options:0] day];
	if(back == 1)
		return NekoRecordLocalized(@"yesterday");

	NSDateFormatter *said = [[[NSDateFormatter alloc] init] autorelease];
	[said setLocale:[NSLocale localeWithLocaleIdentifier:
		[[[NSBundle mainBundle] preferredLocalizations] firstObject] ?: @"en"]];
	/* The year only when it is not this one: "il 27 agosto" reads better than
	   "il 27 agosto 2026" and says the same thing until January. */
	NSDateComponents *now = [calendar components:NSCalendarUnitYear fromDate:[NSDate date]];
	NSDateComponents *then = [calendar components:NSCalendarUnitYear fromDate:when];
	[said setDateFormat:[now year] == [then year] ? @"d MMMM" : @"d MMMM yyyy"];
	return [said stringFromDate:when];
}

@implementation NekoRecord

+ (BOOL)wantedFor:(NSString *)question
{
	NSString *text = [question lowercaseString];
	NSEnumerator *e = [NekoRecordAsking() objectEnumerator];
	NSString *phrase;
	while((phrase = [e nextObject]) != nil)
		if([text rangeOfString:phrase].location != NSNotFound)
			return YES;
	return NO;
}

+ (NSString *)answerFor:(NSString *)question
{
	NSArray *found = [[NekoMemory sharedMemory] recordAbout:question
	                                                  limit:NekoRecordMost];
	if([found count] == 0)
		return NekoRecordLocalized(@"I have nothing written down about that.");

	NSMutableArray *sentences = [NSMutableArray array];
	NSEnumerator *e = [found objectEnumerator];
	NSDictionary *one;
	while((one = [e nextObject]) != nil) {
		BOOL theirs = [[one objectForKey:@"Kind"] isEqualToString:@"you"];
		[sentences addObject:[NSString stringWithFormat:
			theirs ? NekoRecordLocalized(@"On %@ you said: “%@”")
			       : NekoRecordLocalized(@"On %@ I noted: “%@”"),
			NekoRecordDay([one objectForKey:@"Day"]),
			[one objectForKey:@"Text"]]];
	}
	return [sentences componentsJoinedByString:@" "];
}

@end
