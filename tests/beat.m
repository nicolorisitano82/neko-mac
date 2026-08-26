/* Step 4: the moment after the cat speaks, the barge-in, the typed line, and the
   turn a follow-up points back at. Built inside the bundle so the localized
   strings resolve; no microphone is involved, which is the whole difficulty. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoAsk.h"
#import "NekoBubble.h"
#import "NekoLine.h"
#import "NekoMemory.h"
#import "NekoAnswerProvider.h"
#import "NekoAppleProvider.h"

@interface NekoAsk (Testing)
- (void)cancelEverything;
- (void)finish;
- (BOOL)isSpeakingAloud;
- (void)stopVoice;
- (void)speak:(NSString *)text;
- (void)wantAReply;
@end


/* The two seams: speech already allowed, and a listener that does not exist. */
@interface TestAsk : NekoAsk
{
	unsigned starts;
}
- (unsigned)starts;
- (NekoLine *)openLine;
- (void)beginListening;      /* the real one wants a microphone */
@end

@implementation TestAsk

- (BOOL)speechAlreadyAllowed
{
	return YES;
}

- (BOOL)startListeningForReplyWithPatience:(NSTimeInterval)seconds
{
	starts++;
	return YES;
}

- (unsigned)starts
{
	return starts;
}

/* What the keystroke does, without the microphone: NekoPhaseListening is 1. */
- (void)beginListening
{
	phase = 1;
}

- (NekoLine *)openLine
{
	return typedLine;
}

@end

static NekoBubble *bubbleOf(TestAsk *ask)
{
	/* Declared in the header, so a subclass — and a test — can see it. */
	Ivar found = class_getInstanceVariable([NekoAsk class], "bubble");
	return (NekoBubble *)object_getIvar(ask, found);
}

int main(int argc, const char *argv[])
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	/* Settings come in as arguments, which NSUserDefaults reads before anything
	   saved: the test says what it needs without changing what the user chose.
	   Run it with: -NekoAskEnabled 1 -NekoAskFollowUp 1 -NekoAskProvider openai */
	BOOL slow = [defaults boolForKey:@"slow"];
	printf("ask enabled %d, follow-up %d, provider %s\n",
		[defaults boolForKey:NekoAskEnabledKey],
		[defaults boolForKey:NekoAskFollowUpKey],
		[[defaults stringForKey:NekoAskProviderKey] UTF8String]);

	TestAsk *ask = [[TestAsk alloc] init];
	NekoBubble *bubble = bubbleOf(ask);

	printf("\n--- the moment after it speaks ---\n");

	[ask sayUnprompted:@"You have had Xcode open a while."];
	spin(0.2);
	ok([ask isWaitingForReply], @"a remark leaves the microphone open", nil);
	ok([[bubble hint] length] > 0, @"the bubble says so",
		[NSString stringWithFormat:@"“%@”", [bubble hint]]);
	ok([bubble secondsLeft] >= 6.0,
		@"the sign outlives the microphone",
		[NSString stringWithFormat:@"%.1f s left, beat is 6 s", [bubble secondsLeft]]);
	ok([ask starts] == 1, @"the listener was started once",
		[NSString stringWithFormat:@"%u", [ask starts]]);

	/* Silence. */
	[ask replyHeard:nil final:YES error:[NSError errorWithDomain:@"test" code:1 userInfo:nil]];
	ok(![ask isWaitingForReply], @"silence closes the microphone", nil);
	ok([bubble hint] == nil, @"and takes the sign down", nil);
	ok([bubble isShowing], @"the words stay up as they were", nil);

	[ask cancelEverything];
	spin(0.1);

	/* A long answer must not be cut short to fit the beat. */
	NSMutableString *wall = [NSMutableString string];
	while([wall length] < 400)
		[wall appendString:@"a long answer that takes a while to read. "];
	[ask sayUnprompted:wall];
	spin(0.2);
	NSTimeInterval reading = [NekoBubble readingTimeFor:wall];
	ok([bubble secondsLeft] > 15.0,
		@"a long answer keeps its reading time",
		[NSString stringWithFormat:@"%.1f s left, reading time %.1f s",
			[bubble secondsLeft], reading]);

	[ask cancelEverything];
	spin(0.1);

	printf("\n--- barge-in ---\n");

	[ask sayUnprompted:@"Xcode has been open a while."];
	spin(0.2);
	NSTimeInterval before = [bubble secondsLeft];
	[ask replyHeard:@"why do you" final:NO error:nil];
	spin(0.1);
	ok([bubble secondsLeft] == 0.0,
		@"first words stop the bubble counting down",
		[NSString stringWithFormat:@"%.1f s before, %.1f s after",
			before, [bubble secondsLeft]]);
	ok([ask isWaitingForReply], @"and it is still the same turn", nil);
	ok([[bubble hint] length] > 0, @"the sign is still up while you speak", nil);

	/* Finishing the sentence turns the remark into a conversation. The proof
	   that it reached the question is in the diary, which is where a question
	   goes before anything else happens to it. */
	/* No filler words in it: the diary is written short now, and a phrase this
	   test looks for again afterwards must survive being written the way a note
	   is written. */
	NSString *phrase = @"zzqmark barge test";
	[ask replyHeard:phrase final:YES error:nil];
	spin(0.4);
	/* A question is written down before anything is done with it, so the diary
	   is the evidence that the sentence became one. Only with an engine that is
	   configured — an unconfigured one refuses before it gets that far. */
	BOOL configured = [[ask provider] isConfigured];
	NSString *today = [[NekoMemory sharedMemory] contextForPrompt];
	if(configured)
		ok([today rangeOfString:phrase].location != NSNotFound,
			@"a finished sentence becomes the next question", nil);
	else
		notMeasured(@"the engine is not configured, so the question stopped there");
	[[NekoMemory sharedMemory] forgetLinesContaining:@"zzqmark"];
	ok([[[NekoMemory sharedMemory] contextForPrompt] rangeOfString:phrase].location == NSNotFound,
		@"and the test's own line is removed again", nil);

	/* The one rule that has to hold at every moment: an open microphone and no
	   sign saying so must never happen together. */
	NSDate *watch = [NSDate date];
	BOOL broken = NO;
	while(-[watch timeIntervalSinceNow] < 12.0) {
		spin(0.1);
		if([ask isWaitingForReply] && ![bubble isShowing])
			broken = YES;
	}
	ok(!broken, @"never listening without the sign, watched for 12 s", nil);

	[ask cancelEverything];
	spin(0.1);

	printf("\n--- the turn just before ---\n");

	[ask rememberQuestion:@"Who wrote The Hobbit?" answer:@"Tolkien did."];
	NSString *thread = [ask threadForPrompt];
	ok([thread rangeOfString:@"They asked: Who wrote The Hobbit?"].location != NSNotFound
	   && [thread rangeOfString:@"You answered: Tolkien did."].location != NSNotFound,
		@"a question and its answer", [NSString stringWithFormat:@"“%@”",
			[thread stringByReplacingOccurrencesOfString:@"\n" withString:@" / "]]);
	ok([[ask instructionsForAsking] rangeOfString:@"A MOMENT AGO"].location != NSNotFound,
		@"and it is in what the model is told", nil);

	[ask rememberQuestion:nil answer:@"Xcode has been open a while."];
	ok([[ask threadForPrompt] hasPrefix:@"You said, without being asked:"],
		@"a remark nobody asked for is a turn too", nil);

	[ask rememberQuestion:nil answer:nil];
	ok([[ask threadForPrompt] length] == 0, @"and it can be emptied", nil);

	NSMutableString *huge = [NSMutableString string];
	while([huge length] < 900)
		[huge appendString:@"words and more words "];
	[ask rememberQuestion:huge answer:huge];
	ok([[ask threadForPrompt] length] <= 640,
		@"a long turn is trimmed, not passed on whole",
		[NSString stringWithFormat:@"%lu chars from %lu",
			(unsigned long)[[ask threadForPrompt] length], (unsigned long)(2 * [huge length])]);

	printf("\n--- barge-in, on the voice ---\n");

	BOOL spokeBefore = [defaults boolForKey:NekoAskSpeakKey];
	[defaults setBool:YES forKey:NekoAskSpeakKey];
	[ask speak:@"This is a long sentence that will be interrupted in the middle of it, on purpose, to see how quickly it stops."];
	NSDate *waited = [NSDate date];
	while(![ask isSpeakingAloud] && -[waited timeIntervalSinceNow] < 3.0)
		spin(0.02);
	if([ask isSpeakingAloud]) {
		spin(0.5);
		NSDate *cut = [NSDate date];
		[ask stopVoice];
		while([ask isSpeakingAloud] && -[cut timeIntervalSinceNow] < 2.0)
			spin(0.005);
		NSTimeInterval took = -[cut timeIntervalSinceNow];
		ok(!([ask isSpeakingAloud]) && took < 0.3,
			@"the voice stops mid-sentence",
			[NSString stringWithFormat:@"%.0f ms", took * 1000.0]);
	} else {
		notMeasured(@"the voice never started on this machine");
	}
	[defaults setBool:spokeBefore forKey:NekoAskSpeakKey];

	printf("\n--- the typed line ---\n");

	NekoLine *line = [[NekoLine alloc] init];
	__block NSString *typed = nil;
	__block BOOL called = NO;
	[line askNearRect:NSMakeRect(400.0f, 400.0f, 32.0f, 32.0f)
	      placeholder:@"Ask me something…"
	         finished:^(NSString *text) { typed = [text copy]; called = YES; }];
	spin(0.3);
	ok([line isShowing], @"the line opens", nil);
	/* Key status is not something a harness binary can have: LaunchServices only
	   activates a bundle's main executable, so it is measured in the small app
	   next to this one. What can be measured here is that the panel allows it
	   and that the field is where the typing would go. */
	ok([line canBecomeKeyWindow], @"the panel allows the keyboard", nil);
	ok([[line firstResponder] isKindOfClass:[NSTextView class]],
		@"and the field is first responder",
		[NSString stringWithFormat:@"%@", [[line firstResponder] class]]);

	NSTextField *field = nil;
	NSEnumerator *e = [[[line contentView] subviews] objectEnumerator];
	NSView *view;
	while((view = [e nextObject]) != nil)
		if([view isKindOfClass:[NSTextField class]])
			field = (NSTextField *)view;
	ok(field != nil, @"there is one field in it", nil);
	[field setStringValue:@"  how do I centre a div  "];
	[line performSelector:@selector(sendIt:) withObject:nil];
	spin(0.2);
	ok(called && [typed isEqualToString:@"how do I centre a div"],
		@"Return sends what was typed, trimmed",
		[NSString stringWithFormat:@"“%@”", typed]);
	ok(![line isShowing], @"and closes the line", nil);

	typed = nil; called = NO;
	[line askNearRect:NSMakeRect(400.0f, 400.0f, 32.0f, 32.0f)
	      placeholder:@"Ask me something…"
	         finished:^(NSString *text) { typed = [text copy]; called = YES; }];
	spin(0.2);
	[line close];
	spin(0.2);
	ok(called && typed == nil, @"Escape sends nothing at all", nil);

	typed = nil; called = NO;
	[line askNearRect:NSMakeRect(400.0f, 400.0f, 32.0f, 32.0f)
	      placeholder:@"Ask me something…"
	         finished:^(NSString *text) { typed = [text copy]; called = YES; }];
	spin(0.2);
	[line performSelector:@selector(sendIt:) withObject:nil];
	spin(0.2);
	ok(called && typed == nil, @"an empty line is nothing too", nil);

	printf("\n--- held, rather than tapped ---\n");

	[ask cancelEverything];
	spin(0.1);
	[ask toggle:nil];            /* the key goes down */
	spin(0.2);
	ok([ask openLine] == nil || ![[ask openLine] isShowing],
		@"a fifth of a second in, still the microphone", nil);
	spin(0.5);
	ok([[ask openLine] isShowing],
		@"held past half a second, a line to type in", nil);
	[[ask openLine] close];
	spin(0.1);

	[ask cancelEverything];
	spin(0.1);
	[ask toggle:nil];
	spin(0.2);
	[ask hotKeyLetGo:nil];       /* let go before the half second */
	spin(0.6);
	ok([ask openLine] == nil || ![[ask openLine] isShowing],
		@"let go in time and no line appears", nil);
	[ask cancelEverything];
	spin(0.1);

	printf("\n--- a follow-up, with the engine that answers ---\n");

	NekoAppleProvider *apple = [[NekoAppleProvider alloc] init];
	if(![apple isConfigured]) {
		notMeasured(@"Apple Intelligence is not available here");
	} else {
		NSString *follow = @"And when?";
		int round;
		for(round = 0; round < 2; round++) {
			if(round == 0)
				[ask rememberQuestion:@"Who wrote The Hobbit?" answer:@"Tolkien did."];
			else
				[ask rememberQuestion:nil answer:nil];
			__block NSString *answer = nil;
			__block BOOL done = NO;
			[apple askQuestion:follow
			      instructions:[ask instructionsForAsking]
			        completion:^(NSString *text, NSError *error) {
				answer = [text copy];
				done = YES;
			}];
			NSDate *until = [NSDate dateWithTimeIntervalSinceNow:60.0];
			while(!done && [until timeIntervalSinceNow] > 0.0)
				spin(0.05);
			printf("%s: %s\n", round == 0 ? "with the turn   " : "without the turn",
				[(answer ?: @"(nothing)") UTF8String]);
			if(round == 0) {
				/* A model that did not answer at all measures nothing about
				   whether the previous turn reached it — and under a machine
				   busy compiling ten harnesses, it sometimes does not. */
				if(answer == nil) {
					notMeasured(@"the engine did not answer in a minute");
				} else {
					/* What is under test is whether the previous turn reached the
					   model — not whether the model is right about it. Asked "And
					   when?" with the turn, Apple's model has answered "Tolkien
					   ha scritto Lo Hobbit nel 1937" and also "Il Signore degli
					   Anelli è stato scritto nel 1954": the wrong book, and still
					   an answer about a book by the author it was just told
					   about. Without the turn it reads out the clock, which is
					   the negative control below. So: a year, and not the time. */
					NSString *lowered = [answer lowercaseString];
					BOOL aboutABook = [answer rangeOfString:@"19"].location != NSNotFound
						|| [lowered rangeOfString:@"hobbit"].location != NSNotFound
						|| [lowered rangeOfString:@"tolkien"].location != NSNotFound
						|| [lowered rangeOfString:@"anelli"].location != NSNotFound;
					BOOL aboutTheClock = [lowered rangeOfString:@"ore sono"].location != NSNotFound
						|| [lowered rangeOfString:@"orario"].location != NSNotFound
						|| [lowered rangeOfString:@"l'ora"].location != NSNotFound;
					ok(aboutABook && !aboutTheClock,
						@"“And when?” lands on the previous turn", answer);
				}
			}
		}
	}

	if(slow) {
		printf("\n--- three minutes later ---\n");
		[ask rememberQuestion:@"Who wrote The Hobbit?" answer:@"Tolkien did."];
		ok([[ask threadForPrompt] length] > 0, @"the turn is there to begin with", nil);
		spin(181.0);
		ok([[ask threadForPrompt] length] == 0,
			@"and gone three minutes later, not carried into a new conversation", nil);
	}

	[pool release];
	return NekoTestResult();
}
