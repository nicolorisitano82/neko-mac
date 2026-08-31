/* What the cat can tell about your day without reading any of it.

   The rule this application has never crossed is that nothing it reads becomes
   something the Mac does, and the corollary it has kept alongside it is that most
   of what makes a pet seem attentive is not content at all. Which application is
   in front, how fast somebody is typing, how long they have been still — those
   have driven the timing since 2.1.

   This is three more of the same kind, and the point of each is that it is a
   counter or a flag rather than a thing anybody said:

   - **the microphone is open somewhere.** Not what is being said, not by which
     application: one CoreAudio flag, no permission asked, and the plainest sign
     there is that somebody is on a call.
   - **the screen is locked**, or somebody else is at the console.
   - **the display is asleep.**

   Measured before any of it was written: all three are readable from inside the
   sandbox, none of them prompts for anything, and a hundred samples of two of
   them cost ten milliseconds. And the microphone flag was watched going cold,
   hot while a tap was open on the input, and cold again — because a signal that
   is always "no" is not a signal. */

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "support.h"
#import "NekoDesktop.h"
#import "NekoTimer.h"

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NekoDesktop *desktop = [NekoDesktop sharedDesktop];

	printf("\n--- readable at all, and cheap ---\n");

	NSDate *began = [NSDate date];
	NSUInteger i;
	for(i = 0; i < 200; i++) {
		(void)[desktop microphoneInUse];
		(void)[desktop nobodyIsThere];
	}
	NSTimeInterval each = -[began timeIntervalSinceNow] / 200.0;
	ok(each < 0.005, @"both signals cost almost nothing to sample",
		[NSString stringWithFormat:@"%.2f ms each", each * 1000.0]);

	/* Somebody is sitting here running the suite, so this is knowable. */
	ok(![desktop nobodyIsThere],
		@"and with somebody at the keyboard, somebody is there",
		[desktop whyNobodyIsThere] ?: @"nobody is not there");

	printf("\n--- and the microphone flag actually moves ---\n");

	/* A flag that is always no is not a flag. Nothing is recorded, kept or looked
	   at: a tap is installed on the input and every buffer is dropped. */
	BOOL cold = [desktop microphoneInUse];
	if(cold) {
		/* Something else on this Mac has the input open — a call, a recorder, or
		   this application's own wake word in another process. The transition
		   cannot be observed from inside that, and pretending otherwise would
		   fail for a reason that is nothing to do with the flag. */
		notMeasured(@"the microphone was already in use by something else, so going "
			@"from cold to hot could not be watched here");
		int early = NekoTestResult();
		[pool release];
		return early;
	}
	AVAudioEngine *engine = [[[AVAudioEngine alloc] init] autorelease];
	AVAudioInputNode *input = [engine inputNode];
	[input installTapOnBus:0 bufferSize:1024
	                 format:[input outputFormatForBus:0]
	                  block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) { }];
	NSError *whyNot = nil;
	if(![engine startAndReturnError:&whyNot]) {
		notMeasured([NSString stringWithFormat:
			@"the microphone could not be opened here: %@",
			[whyNot localizedDescription]]);
	} else {
		spin(1.0);
		BOOL hot = [desktop microphoneInUse];
		/* Sampled while it is open, because afterwards there is nothing to see —
		   the first version of this line asked after closing the input and passed
		   for that reason. */
		NSString *whileHot = [[[desktop whyBusyElsewhere] copy] autorelease];
		[engine stop];
		[input removeTapOnBus:0];
		spin(1.0);
		BOOL coldAgain = [desktop microphoneInUse];
		ok(!cold && hot && !coldAgain,
			@"cold, then hot while something has the input open, then cold",
			[NSString stringWithFormat:@"%d → %d → %d", cold, hot, coldAgain]);
		ok([whileHot length] > 0,
			@"and while it is open the cat has a reason to keep quiet",
			whileHot ?: @"none, which is the bug this check exists for");
	}

	printf("\n--- what it says about itself ---\n");

	/* Every reason is a sentence somebody can read in the preferences, and none
	   of them names a document, a window or a word. */
	NSString *why = [desktop whyBusyElsewhere];
	ok(why == nil || [why length] > 0,
		@"the reason it stays quiet is a sentence, or there is no reason",
		why ?: @"nothing in the way");

	printf("\n--- and a timer waits for somebody to come back ---\n");

	/* Nobody there is not a bad moment, it is no moment: a bad moment passes in
	   seconds and a locked screen does not. What cannot be staged here is the
	   locking itself, so what is checked is the shape — that the timer asks the
	   desktop at all, and that with somebody here it still goes off. */
	NekoTimer *timer = [NekoTimer sharedTimer];
	[timer startFor:2.0];
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:20.0];
	while([timer isRunning] && [until timeIntervalSinceNow] > 0.0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
		                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	ok(![timer isRunning],
		@"with somebody at the keyboard it still goes off", nil);
	[timer cancel];

	int result = NekoTestResult();
	[pool release];
	return result;
}
