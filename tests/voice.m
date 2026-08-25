/* How it sounds: the mood that moves through the day, the greeting that knows
   when it last saw somebody, and the two habits that make an answer read like a
   helpdesk rather than a cat.

   The slow half asks a real model the same questions at nine in the morning and
   at one in the morning, and counts how much of the wording is the same. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoVoice.h"
#import "NekoSense.h"
#import "NekoAppleProvider.h"
#import "NekoAnswerProvider.h"

static NSDate *at(NSInteger year, NSInteger month, NSInteger day, NSInteger hour)
{
	NSDateComponents *parts = [[[NSDateComponents alloc] init] autorelease];
	[parts setYear:year];
	[parts setMonth:month];
	[parts setDay:day];
	[parts setHour:hour];
	return [[NSCalendar currentCalendar] dateFromComponents:parts];
}

static double sameWords(NSString *one, NSString *two)
{
	NSCharacterSet *breaks = [[NSCharacterSet letterCharacterSet] invertedSet];
	NSMutableSet *first = [NSMutableSet set], *second = [NSMutableSet set];
	NSEnumerator *e = [[[one lowercaseString] componentsSeparatedByCharactersInSet:breaks]
		objectEnumerator];
	NSString *word;
	while((word = [e nextObject]) != nil)
		if([word length] > 3)
			[first addObject:word];
	e = [[[two lowercaseString] componentsSeparatedByCharactersInSet:breaks] objectEnumerator];
	while((word = [e nextObject]) != nil)
		if([word length] > 3)
			[second addObject:word];
	if([first count] == 0 || [second count] == 0)
		return 0.0;
	NSMutableSet *shared = [[second mutableCopy] autorelease];
	[shared intersectSet:first];
	return (double)[shared count] / (double)MIN([first count], [second count]);
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL slow = [[NSUserDefaults standardUserDefaults] boolForKey:@"slow"];

	printf("\n--- the mood moves through the day ---\n");

	NSMutableSet *moods = [NSMutableSet set];
	NSInteger hour;
	for(hour = 0; hour < 24; hour += 3) {
		NSString *mood = [NekoVoice moodAt:at(2026, 8, 26, hour)];   /* a Wednesday */
		[moods addObject:mood];
		printf("      %02ld:00  %.68s…\n", (long)hour, [mood UTF8String]);
	}
	ok([moods count] >= 6, @"a different mood through the day",
		[NSString stringWithFormat:@"%lu of 8 readings differ", (unsigned long)[moods count]]);
	ok([[NekoVoice moodAt:at(2026, 8, 26, 10)]
			isEqualToString:[NekoVoice moodAt:at(2026, 8, 26, 10)]],
		@"and it holds still between two questions", nil);
	ok(![[NekoVoice moodAt:at(2026, 8, 24, 10)]
			isEqualToString:[NekoVoice moodAt:at(2026, 8, 28, 10)]],
		@"Monday morning is not Friday morning", nil);
	ok([[NekoVoice moodAt:at(2026, 8, 29, 15)] rangeOfString:@"weekend"].location
		!= NSNotFound, @"and Saturday knows it is Saturday", nil);

	printf("\n--- turning up ---\n");

	NSDate *tuesdayMorning = at(2026, 8, 25, 9);
	ok([[NekoVoice openingFor:tuesdayMorning lastSeen:nil] length] > 0,
		@"the first time ever, it says something",
		[NekoVoice openingFor:tuesdayMorning lastSeen:nil]);
	ok([NekoVoice openingFor:tuesdayMorning lastSeen:at(2026, 8, 25, 8)] == nil,
		@"twice in one morning, it does not", nil);
	NSString *nextDay = [NekoVoice openingFor:tuesdayMorning lastSeen:at(2026, 8, 24, 18)];
	ok([nextDay length] > 0, @"a new day, it does", nextDay);
	NSString *aWeek = [NekoVoice openingFor:tuesdayMorning lastSeen:at(2026, 8, 10, 9)];
	ok([aWeek length] > 0, @"and a week away is a different sentence", aWeek);
	NSString *lateNight = [NekoVoice openingFor:at(2026, 8, 25, 1) lastSeen:at(2026, 8, 23, 14)];
	printf("      at one in the morning: %s\n", [lateNight UTF8String]);
	ok([lateNight length] > 0, @"one in the morning, too", nil);

	printf("\n--- the assistant, taken out ---\n");

	NSArray *flattered = [NSArray arrayWithObjects:
		@"Ottima domanda! Il file è nella cartella Documenti.",
		@"Great question. The file is in your Documents folder.",
		@"Certo! Xcode è aperto da quaranta minuti.", nil];
	NSEnumerator *e = [flattered objectEnumerator];
	NSString *line;
	while((line = [e nextObject]) != nil) {
		NSString *trimmed = [NekoVoice withoutFlattery:line];
		ok(![trimmed isEqualToString:line] && [trimmed length] > 0,
			@"the compliment comes off the front", trimmed);
	}

	NSString *twice = @"Il build è lento perché il progetto è grande. "
	                  @"Il progetto è grande, quindi il build è lento.";
	ok([NekoVoice saysItTwice:twice], @"a second sentence that says the first again", nil);
	ok([[NekoVoice withoutFlattery:twice] length] < [twice length],
		@"and it comes off the end", [NekoVoice withoutFlattery:twice]);

	NSString *ordinary = @"Il file è in Documenti. L'ho visto aperto stamattina.";
	ok([[NekoVoice withoutFlattery:ordinary] isEqualToString:ordinary],
		@"an ordinary answer is left exactly as it was", nil);
	ok(![NekoVoice saysItTwice:ordinary],
		@"and a sentence that continues is not a repetition", nil);

	ok([NekoVoice isNothingButFlattery:@"Ottima domanda!"],
		@"a compliment with nothing behind it is nothing", nil);
	ok(![NekoVoice isNothingButFlattery:@"Ottima domanda! Il file è in Documenti."],
		@"but a compliment with an answer behind it is an answer", nil);
	ok([[NekoSense problemWith:@"Ottima domanda!"]
			isEqualToString:@"a compliment with nothing behind it"],
		@"and it is refused as a remark", [NekoSense problemWith:@"Ottima domanda!"]);

	if(slow) {
		printf("\n--- the same questions, morning and small hours ---\n");
		NekoAppleProvider *apple = [[[NekoAppleProvider alloc] init] autorelease];
		if(![apple isConfigured]) {
			notMeasured(@"Apple Intelligence is not available here");
		} else {
			NSArray *questions = [NSArray arrayWithObjects:
				@"Che ore sono buone per concentrarsi?",
				@"Cosa fai quando mi annoio?",
				@"Mi conviene fare una pausa?",
				@"Perché il gatto insegue il cursore?",
				@"Come si chiama il tuo umore oggi?", nil];
			double sum = 0.0;
			NSUInteger asked = 0, flattery = 0;
			NSUInteger i;
			for(i = 0; i < [questions count]; i++) {
				NSString *question = [questions objectAtIndex:i];
				NSMutableArray *answers = [NSMutableArray array];
				NSUInteger when;
				for(when = 0; when < 2; when++) {
					/* The mood is what the instructions carry, so the two runs
					   differ only in the hour they were written for. */
					NSString *instructions = [NSString stringWithFormat:
						@"You are a small pixel-art cat on somebody's desktop. "
						@"Answer in Italian, one or two short sentences.\n\n"
						@"HOW YOU SOUND. %@\nNever open with a compliment. Never "
						@"end by saying again what you just said.",
						[NekoVoice moodAt:at(2026, 8, 26, when == 0 ? 9 : 1)]];
					__block NSString *said = nil;
					__block BOOL done = NO;
					[apple askQuestion:question instructions:instructions
					        completion:^(NSString *text, NSError *error) {
						said = [text retain];
						done = YES;
					}];
					NSDate *until = [NSDate dateWithTimeIntervalSinceNow:60.0];
					while(!done && [until timeIntervalSinceNow] > 0.0)
						spin(0.05);
					[answers addObject:said ?: @""];
					if([NekoVoice isNothingButFlattery:said ?: @""]
					   || ![[NekoVoice withoutFlattery:said ?: @""] isEqualToString:said ?: @""])
						flattery++;
				}
				double overlap = sameWords([answers objectAtIndex:0], [answers objectAtIndex:1]);
				sum += overlap;
				asked++;
				printf("      %s\n        09:00  %s\n        01:00  %s\n        same words: %.0f%%\n",
					[question UTF8String],
					[[answers objectAtIndex:0] UTF8String],
					[[answers objectAtIndex:1] UTF8String], overlap * 100.0);
			}
			ok(asked > 0 && sum / (double)asked < 0.7,
				@"morning and small hours are not the same answer",
				[NSString stringWithFormat:@"%.0f%% of the words shared on average",
					100.0 * sum / (double)asked]);
			ok(flattery <= asked / 2,
				@"and the compliments are rare",
				[NSString stringWithFormat:@"%lu of %lu answers needed trimming",
					(unsigned long)flattery, (unsigned long)(asked * 2)]);
		}
	}

	int result = NekoTestResult();
	[pool release];
	return result;
}
