/* Ask Neko went dead after many hours, from the keystroke *and* from the menu,
   and only a restart brought it back.

   The unified log has the whole story. Every press did reach the code:

       23:10:10.938  (TCC) TCCAccessRequest() IPC
       23:10:10.948  +[SFSpeechAssetManager pathToAssetWithConfig:...]
       23:10:19.872  IsDeviceUsable: Device ID: 840 (Input:No | Output:No): 
       23:10:19.872  E  AudioObjectRemovePropertyListener: no object with given ID 0

   Presses at 23:10:10, :15 and :19 — every four or five seconds, which is
   somebody pressing again because nothing happened. The default audio device had
   changed underneath the app hours earlier, at the display wake logged at
   09:09:59, and what the engine was handed is a device that is **neither input
   nor output**.

   NekoListener guards the sample rate. It does not guard the channel count, and
   -installTapOnBus:bufferSize:format:block: does not return an error for a bad
   format — it raises. The exception leaves -startCapture halfway through, with
   `phase` still on NekoPhaseListening and nothing on screen, which makes the next
   press take the -isBusy branch, cancel, and return. So it alternates for ever:
   one press throws, the next press silently cancels, and the cat never says a
   word. That is the report, exactly.

   Three things measured here: that the format really raises rather than returns,
   that an exception in the listener used to strand the phase, and that the way
   out is the one the code already uses when there is no microphone — a line to
   type in. */

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoAsk.h"
#import "NekoLine.h"
#import "NekoListener.h"

@interface NekoAsk (Testing)
- (void)startCapture;
- (void)typeALine;
- (BOOL)isBusy;
- (void)finish;
@end

/* Speech is allowed and available, so that -beginListening reaches -startCapture
   the way it does on the machine that failed. */
@interface DeafAsk : NekoAsk
{
	unsigned lines;
}
- (unsigned)lines;
@end

@implementation DeafAsk
- (BOOL)speechAlreadyAllowed { return YES; }
- (void)typeALine            { lines++; }
- (unsigned)lines            { return lines; }
@end

/* A listener that fails the way CoreAudio fails: by raising, not by returning
   NO. Swapped in for the real method, which needs a microphone this binary
   cannot be granted. */
static BOOL raiseInstead = NO;
static BOOL raisingStart(id self, SEL _cmd, NSLocale *locale, id block)
{
	if(raiseInstead)
		[NSException raise:NSInternalInconsistencyException
		            format:@"required condition is false: "
		                   @"IsFormatSampleRateAndChannelCountValid(format)"];
	return NO;
}

int main(int argc, const char **argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];

	printf("--- what CoreAudio does with the device the log caught ---\n");

	/* Device 840 reported Input:No. An input node on such a device gives a
	   format with no channels; this is what the app then does with it. */
	AVAudioFormat *broken = [[[AVAudioFormat alloc]
		initStandardFormatWithSampleRate:44100.0 channels:0] autorelease];
	ok(broken == nil || [broken channelCount] == 0,
		@"a no-channel format is what an absent input gives",
		broken == nil ? @"AVAudioFormat itself refuses it"
		              : [NSString stringWithFormat:@"%u channels", [broken channelCount]]);

	BOOL raised = NO;
	AVAudioEngine *engine = [[[AVAudioEngine alloc] init] autorelease];
	@try {
		[[engine inputNode] installTapOnBus:0 bufferSize:1024 format:broken
			block:^(AVAudioPCMBuffer *b, AVAudioTime *w) { }];
	}
	@catch(NSException *e) {
		raised = YES;
	}
	ok(raised, @"and installing a tap with it raises, it does not return",
		raised ? @"NSException, so a BOOL check never sees it" : @"it returned quietly");

	printf("\n--- so an exception from the listener must not strand the phase ---\n");

	Method start = class_getInstanceMethod([NekoListener class],
		@selector(startListeningWithLocale:report:));
	IMP was = method_setImplementation(start, (IMP)raisingStart);
	raiseInstead = YES;

	DeafAsk *ask = [[[DeafAsk alloc] init] autorelease];
	[ask finish];
	ok(![ask isBusy], @"idle before any of this", nil);

	BOOL escaped = NO;
	@try {
		[ask startCapture];
	}
	@catch(NSException *e) {
		escaped = YES;
	}
	ok(!escaped, @"the exception does not escape -startCapture",
		escaped ? @"it escaped, and everything below is the old bug" : nil);
	ok(![ask isBusy], @"and the phase is back to idle, so the next press works",
		[ask isBusy] ? @"still busy — Ask Neko is dead until a restart" : nil);
	ok([ask lines] == 1, @"and the keystroke still did something: a line to type in",
		[NSString stringWithFormat:@"%u opened", [ask lines]]);

	/* The symptom the report described: press, press, press, nothing. Without
	   the guard the phase alternates busy/idle and neither state ever shows
	   anything. */
	unsigned linesBefore = [ask lines];
	int i;
	for(i = 0; i < 4; i++) {
		@try { [ask startCapture]; } @catch(NSException *e) { }
	}
	ok([ask lines] == linesBefore + 4,
		@"four more presses, four more ways in — not two",
		[NSString stringWithFormat:@"%u", [ask lines] - linesBefore]);
	ok(![ask isBusy], @"and still idle at the end of them", nil);

	raiseInstead = NO;
	method_setImplementation(start, was);

	printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
	[pool release];
	return NekoTestFailures > 0 ? 1 : 0;
}
