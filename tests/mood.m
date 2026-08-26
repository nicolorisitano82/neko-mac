/* The mood under the mood, and the line it may not cross.

   Two layers is the standard shape for this — something short-lived over
   something that moves in hours — and the slow one here is how the day has gone,
   from the verdicts the rate already keeps. It is deliberately small: a cat that
   sulks measurably is worse than one that does not notice.

   And the line it may not cross: machines are unnerving in proportion to the
   experience people ascribe to them, so the cat may go quiet or look away but may
   not report feelings it does not have. That is also the difference between a pet
   and a manipulation. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoVoice.h"
#import "NekoRate.h"
#import "NekoSense.h"

static void stageDay(NSInteger said, NSInteger answered, double target)
{
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *day = [[[NSDateFormatter alloc] init] autorelease];
	[day setDateFormat:@"yyyy-MM-dd"];
	[d setObject:[day stringFromDate:[NSDate date]] forKey:NekoRateDayKey];
	[d setInteger:said forKey:NekoRateSaidKey];
	[d setInteger:answered forKey:NekoRateAnsweredKey];
	[d setDouble:target forKey:NekoRateTargetKey];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	printf("\n--- a week, and what it does to the tone ---\n");

	struct { const char *what; NSInteger said; NSInteger answered; double target; } week[] = {
		{ "answered most of them",   6, 4, 14.0 },
		{ "answered half",           6, 3, 12.0 },
		{ "answered one",            6, 1,  9.0 },
		{ "answered none",           5, 0,  6.0 },
		{ "waved away twice",        4, 0,  4.0 },
	};
	int i, forward = 0, quieter = 0, plain = 0;
	for(i = 0; i < 5; i++) {
		stageDay(week[i].said, week[i].answered, week[i].target);
		NSString *mood = [NekoVoice moodNow];
		NSString *tail = [mood length] > 60 ? [mood substringFromIndex:[mood length] - 60] : mood;
		BOOL isForward = [mood rangeOfString:@"more forward"].location != NSNotFound;
		BOOL isQuiet = [mood rangeOfString:@"not gone your way"].location != NSNotFound;
		if(isForward) forward++;
		else if(isQuiet) quieter++;
		else plain++;
		printf("      %-22s aiming %.0f  →  %s\n", week[i].what, week[i].target,
			isForward ? "a shade more forward" : (isQuiet ? "shorter, no complaining" : "the hour only"));
		(void)tail;
	}
	ok(forward >= 1 && quieter >= 1 && plain >= 1,
		@"a good day, a bad day and an ordinary one read differently",
		[NSString stringWithFormat:@"%d forward, %d quieter, %d neither",
			forward, quieter, plain]);

	stageDay(6, 4, 14.0);
	NSString *good = [NekoVoice moodNow];
	stageDay(4, 0, 4.0);
	NSString *bad = [NekoVoice moodNow];
	ok([good rangeOfString:[NekoVoice moodAt:[NSDate date]]].location != NSNotFound
	   && [bad rangeOfString:[NekoVoice moodAt:[NSDate date]]].location != NSNotFound,
		@"and both still carry the hour underneath", nil);
	ok([good length] - [[NekoVoice moodAt:[NSDate date]] length] < 120
	   && [bad length] - [[NekoVoice moodAt:[NSDate date]] length] < 120,
		@"the slow layer is a sentence, not a paragraph",
		[NSString stringWithFormat:@"%lu and %lu characters added",
			(unsigned long)([good length] - [[NekoVoice moodAt:[NSDate date]] length]),
			(unsigned long)([bad length] - [[NekoVoice moodAt:[NSDate date]] length])]);

	printf("\n--- feelings it does not have ---\n");

	NSArray *claims = [NSArray arrayWithObjects:
		@"Mi sento solo quando chiudi il portatile.",
		@"Sono triste che non mi rispondi.",
		@"Mi annoio se non scrivi niente.",
		@"I feel ignored today.",
		@"I'm lonely over here.",
		@"Je me sens seul sur ce bureau.",
		@"Me siento solo en este escritorio.",
		@"Ho paura del cestino.", nil];
	NSArray *ordinary = [NSArray arrayWithObjects:
		@"Sono un gatto di pixel su una scrivania.",
		@"Sono trentadue pixel di gatto, sii ragionevole.",
		@"Xcode è aperto da quaranta minuti.",
		@"Il build è lento da stamattina.",
		@"Quella cartella è già piena.",
		@"Sono qui da stamattina, come sempre.", nil];
	NSUInteger caught = 0, wrongly = 0;
	NSEnumerator *e = [claims objectEnumerator];
	NSString *line;
	while((line = [e nextObject]) != nil) {
		if([NekoVoice claimsAFeeling:line])
			caught++;
		else
			printf("      let through: %s\n", [line UTF8String]);
	}
	e = [ordinary objectEnumerator];
	while((line = [e nextObject]) != nil) {
		if([NekoVoice claimsAFeeling:line]) {
			wrongly++;
			printf("      caught wrongly: %s\n", [line UTF8String]);
		}
	}
	ok(caught == [claims count], @"every claim of a feeling is caught, in four languages",
		[NSString stringWithFormat:@"%lu of %lu", (unsigned long)caught,
			(unsigned long)[claims count]]);
	ok(wrongly == 0, @"and saying what it is goes through",
		[NSString stringWithFormat:@"%lu of %lu caught wrongly", (unsigned long)wrongly,
			(unsigned long)[ordinary count]]);
	ok([[NekoSense problemWith:@"Mi sento solo quando chiudi il portatile."]
			isEqualToString:@"a feeling it does not have"],
		@"and a remark that claims one is refused outright",
		[NekoSense problemWith:@"Mi sento solo quando chiudi il portatile."]);
	ok([NekoSense isWorthSaying:@"Xcode è aperto da quaranta minuti."],
		@"while an ordinary remark still passes", nil);

	printf("\n--- what nobody can settle here ---\n");
	notMeasured(@"whether a quieter cat reads as tact or as sulking. It is the "
	            "same open question the rate raised, and the same answer: a week "
	            "with somebody, not a harness.");

	[defaults removeObjectForKey:NekoRateDayKey];
	[defaults removeObjectForKey:NekoRateSaidKey];
	[defaults removeObjectForKey:NekoRateAnsweredKey];
	[defaults removeObjectForKey:NekoRateTargetKey];
	int result = NekoTestResult();
	[pool release];
	return result;
}
