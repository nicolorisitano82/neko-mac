/* Reacting to a sentence starting, rather than to it ending.

   Conversational gaps between turns run about a tenth of a second while the
   reply behind them takes six times that to plan: what fills the gap is the
   listener visibly reacting. The cat now puts its ears up on the first words of
   a sentence rather than after the last, in both places it listens — a question,
   and the moment it holds the microphone open after speaking.

   What a harness can measure is the app's own path: from the recogniser
   reporting words to the pose changing. What it cannot measure is the
   recogniser's own latency, because a test binary cannot be granted a
   microphone — that part is said out loud rather than claimed. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoAsk.h"
#import "MyPanel.h"
#import "NekoController.h"
#import "NekoBubble.h"

@interface NekoAsk (Testing)
- (void)cancelEverything;
- (void)finish;
- (void)heard:(NSString *)text final:(BOOL)final error:(NSError *)error;
- (void)startCapture;
@end

/* Speech is already allowed, and the listener is not real: the same two seams
   the beat test uses. */
@interface TestAsk : NekoAsk
@end

@implementation TestAsk
- (BOOL)speechAlreadyAllowed { return YES; }
- (BOOL)startListeningForReplyWithPatience:(NSTimeInterval)seconds { return YES; }
@end

static NSString *nameOf(NekoState state)
{
	switch(state) {
		case NekoStateStop:  return @"sitting";
		case NekoStateAwake: return @"ears up";
		case NekoStateKaki:  return @"thinking";
		case NekoStateSleep: return @"asleep";
		default:             return [NSString stringWithFormat:@"%d", (int)state];
	}
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	/* A real panel, so the pose can be read back. */
	MyPanel *panel = [[MyPanel alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, 32.0f, 32.0f)
	                                           styleMask:NSWindowStyleMaskBorderless
	                                             backing:NSBackingStoreBuffered
	                                               defer:NO];
	[[NekoController sharedController] setPanel:panel];
	TestAsk *ask = [[TestAsk alloc] init];
	Ivar found = class_getInstanceVariable([NekoAsk class], "bubble");
	NekoBubble *bubble = (NekoBubble *)object_getIvar(ask, found);

	printf("\n--- a question ---\n");

	[ask startCapture];
	spin(0.2);
	ok([panel state] == NekoStateStop,
		@"the microphone opens and the cat sits", nameOf([panel state]));

	/* The recogniser reports empty partials before anybody speaks. */
	[ask heard:@"" final:NO error:nil];
	[ask heard:@"   " final:NO error:nil];
	spin(0.1);
	ok([panel state] == NekoStateStop,
		@"an empty partial is the microphone, not a person", nameOf([panel state]));

	NSDate *spoke = [NSDate date];
	[ask heard:@"che ore" final:NO error:nil];
	NSTimeInterval took = -[spoke timeIntervalSinceNow];
	ok([panel state] == NekoStateAwake,
		@"the first words put its ears up", nameOf([panel state]));
	ok(took < 0.200,
		@"and it does so inside the gap a person leaves",
		[NSString stringWithFormat:@"%.1f ms of app, against 200 ms", took * 1000.0]);

	/* Twitching once per partial would be worse than not reacting at all. */
	[ask heard:@"che ore sono" final:NO error:nil];
	[ask heard:@"che ore sono adesso" final:NO error:nil];
	spin(0.1);
	ok([panel state] == NekoStateAwake,
		@"and stays as it is for the rest of the sentence", nameOf([panel state]));

	[ask cancelEverything];
	spin(0.2);

	printf("\n--- and in the moment after it speaks ---\n");

	[[NSUserDefaults standardUserDefaults] setObject:[NSDate distantPast]
	                                          forKey:NekoLastUnpromptedKey];
	[ask sayUnprompted:@"Xcode has been open a while."];
	spin(0.3);
	ok([ask isWaitingForReply], @"the beat is open", nil);
	ok([panel state] == NekoStateStop,
		@"and the cat is sitting with what it said", nameOf([panel state]));

	[ask replyHeard:@"" final:NO error:nil];
	spin(0.1);
	ok([panel state] == NekoStateStop, @"empty partials change nothing here either",
		nameOf([panel state]));

	NSDate *replied = [NSDate date];
	[ask replyHeard:@"perché" final:NO error:nil];
	NSTimeInterval reply = -[replied timeIntervalSinceNow];
	ok([panel state] == NekoStateAwake,
		@"answering it puts its ears up", nameOf([panel state]));
	ok(reply < 0.200, @"inside the same gap",
		[NSString stringWithFormat:@"%.1f ms", reply * 1000.0]);
	ok([[bubble hint] length] > 0, @"and the sign is still up", [bubble hint]);

	[ask cancelEverything];
	spin(0.2);
	[ask finish];

	printf("\n--- what this cannot measure ---\n");
	notMeasured(@"the recogniser's own latency from speech to first partial: a "
	            "test binary cannot be granted a microphone, so the number above "
	            "is the app's share of it and not the whole wait");

	int result = NekoTestResult();
	[pool release];
	return result;
}
