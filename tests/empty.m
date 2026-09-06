/* How often the engine answers with nothing, and what it says when it does.

   docs/red.md §1: tests/persona.m failed once because Apple Intelligence returned
   nothing at all on one arm of a pair, then passed three times running. The
   check's helper throws the NSError away and keeps only the text, so "nothing"
   and "an error" are indistinguishable from inside it. This keeps both. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoAppleProvider.h"
#import "NekoAnswerProvider.h"

/* Twelve pairs, twenty-four answers. Enough to see a rate of a few per cent and
   short enough to sit through; the run.sh flags are not numbers, so this is not
   taken from the command line. */
static const NSUInteger rounds = 12;

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	/* Twenty-four answers is several minutes of model time. The suite runs this
	   at two pairs so that the path itself stays exercised; the rate wants the
	   full dozen and says so. */
	NSUInteger many = [[NSUserDefaults standardUserDefaults] boolForKey:@"slow"]
		? rounds : 2;

	NekoAppleProvider *apple = [[[NekoAppleProvider alloc] init] autorelease];
	if(![apple isConfigured]) {
		notMeasured(@"Apple Intelligence is not available on this Mac");
		printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
		return 0;
	}

	NSString *wizard = NekoAnswerInstructionsAsked(@"Mi conviene fare una pausa?",
		@"a grey wizard, ancient and wry", NO, NO, nil);
	NSString *cat = NekoAnswerInstructionsAsked(@"Mi conviene fare una pausa?",
		@"a small pixel-art cat", NO, NO, nil);

	printf("--- the same pair, %lu times ---\n", (unsigned long)many);

	NSUInteger empties = 0, errors = 0, asked = 0, identical = 0;
	NSMutableString *reasons = [NSMutableString string];
	NSUInteger i;
	for(i = 0; i < many; i++) {
		NSString *said[2] = { nil, nil };
		NSUInteger arm;
		for(arm = 0; arm < 2; arm++) {
			__block NSString *text = nil;
			__block NSError *problem = nil;
			__block BOOL done = NO;
			[apple askQuestion:@"Mi conviene fare una pausa?"
			      instructions:(arm == 0 ? wizard : cat)
			        completion:^(NSString *answer, NSError *error) {
				text = [answer retain];
				problem = [error retain];
				done = YES;
			}];
			NSDate *until = [NSDate dateWithTimeIntervalSinceNow:90.0];
			while(!done && [until timeIntervalSinceNow] > 0.0)
				spin(0.05);
			asked++;
			said[arm] = text;
			if([text length] == 0) {
				empties++;
				if(problem != nil) {
					errors++;
					[reasons appendFormat:@"%@ / ", [problem localizedDescription]];
				}
				else
					[reasons appendString:@"(nil answer, nil error) / "];
				printf("      round %lu %-7s EMPTY   %s\n", (unsigned long)i + 1,
					arm == 0 ? "wizard" : "cat",
					problem != nil ? [[problem localizedDescription] UTF8String]
					               : "no error either");
			}
			[problem release];
		}
		if([said[0] length] > 0 && [said[0] isEqualToString:said[1]])
			identical++;
	}

	printf("\n");
	ok(YES, @"answers asked for", [NSString stringWithFormat:@"%lu", (unsigned long)asked]);
	ok(YES, @"came back empty", [NSString stringWithFormat:@"%lu of %lu (%.0f%%)",
		(unsigned long)empties, (unsigned long)asked,
		asked ? 100.0 * (double)empties / (double)asked : 0.0]);
	ok(YES, @"of those, with an NSError to say why",
		[NSString stringWithFormat:@"%lu — %@", (unsigned long)errors,
			[reasons length] ? reasons : @"n/a"]);
	ok(YES, @"and two characters answered identically",
		[NSString stringWithFormat:@"%lu of %lu rounds",
			(unsigned long)identical, (unsigned long)many]);

	notMeasured(many < rounds
		? @"two pairs only — the rate needs --slow, which asks the full dozen"
		: @"a rate, not a pass or a fail: what it is for is deciding whether an "
		  @"empty answer is rare enough to leave alone");

	printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
	[pool release];
	return 0;
}
