#import "NekoWakeWord.h"
#import "NekoAsk.h"
#import "NekoController.h"
#import "NekoListener.h"
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

NSString * const NekoWakeWordKey = @"NekoWakeWord";

/* Speech ends a recognition task of its own accord after about a minute, so it
   is rebuilt before that rather than after. */
static const NSTimeInterval NekoWakeRenewal = 50.0;

/* One wake a second at most, so a sentence containing the name twice is one
   wake, not two. */
static const NSTimeInterval NekoWakeCooldown = 1.5;

/* What a recogniser makes of a cat called Neko. A dictation engine has never
   heard of the cat and writes down the nearest word it knows, which in Italian
   is usually "neco" or "necco" and in English "nico". */
static NSString * const NekoWakeSpellings[] = {
	@"neko", @"neco", @"necco", @"nekko", @"nico", @"niko", nil
};

@implementation NekoWakeWord

+ (NekoWakeWord *)sharedWakeWord
{
	static NekoWakeWord *shared = nil;
	if(shared == nil)
		shared = [[NekoWakeWord alloc] init];
	return shared;
}

+ (BOOL)isAvailable
{
	if(![NekoListener isAvailable])
		return NO;
	if(@available(macOS 10.15, *)) {
		SFSpeechRecognizer *speech = [[[SFSpeechRecognizer alloc]
			initWithLocale:[NSLocale currentLocale]] autorelease];
		return speech != nil && [speech isAvailable]
			&& [speech supportsOnDeviceRecognition];
	}
	return NO;
}

+ (NSString *)unavailableReason
{
	if(![NekoListener isAvailable])
		return NSLocalizedString(@"This Mac has no speech recognition.", nil);
	if(![self isAvailable])
		return NSLocalizedString(@"This Mac cannot recognise your language without sending the audio to a server, and an always-open microphone is not something to send anywhere.", nil);
	return nil;
}

#pragma mark The name

/* Accents off, case off, punctuation to spaces, so that "Neko!" and "nekò" and
   "neko," are all the same three syllables. */
+ (NSString *)plainly:(NSString *)text
{
	NSString *folded = [text stringByFoldingWithOptions:
		(NSDiacriticInsensitiveSearch | NSCaseInsensitiveSearch)
		                                          locale:[NSLocale currentLocale]];
	NSMutableString *plain = [NSMutableString stringWithString:@" "];
	NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
	NSUInteger i;
	for(i = 0; i < [folded length]; i++) {
		unichar c = [folded characterAtIndex:i];
		[plain appendString:[letters characterIsMember:c]
			? [NSString stringWithCharacters:&c length:1] : @" "];
	}
	[plain appendString:@" "];
	return plain;
}

+ (BOOL)textNamesTheCat:(NSString *)text
{
	if([text length] == 0)
		return NO;
	NSString *plain = [self plainly:text];
	NSUInteger i;
	for(i = 0; NekoWakeSpellings[i] != nil; i++) {
		NSString *word = [NSString stringWithFormat:@" %@ ", NekoWakeSpellings[i]];
		if([plain rangeOfString:word].location != NSNotFound)
			return YES;
	}
	return NO;
}

#pragma mark Running

- (BOOL)isListening
{
	return running;
}

- (BOOL)shouldRun
{
	NekoController *controller = [NekoController sharedController];
	return [[NSUserDefaults standardUserDefaults] boolForKey:NekoWakeWordKey]
		&& [[NekoAsk sharedAsk] isEnabled]
		&& ![controller isPaused]
		&& [NekoWakeWord isAvailable];
}

- (void)applySettings
{
	if([self shouldRun])
		[self start];
	else
		[self stop];
}

- (void)start
{
	if(running)
		return;
	if(@available(macOS 10.15, *)) {
		SFSpeechRecognizer *speech = [[SFSpeechRecognizer alloc]
			initWithLocale:[NSLocale currentLocale]];
		if(speech == nil || ![speech isAvailable] || ![speech supportsOnDeviceRecognition]) {
			[speech release];
			return;
		}
		recognizer = speech;

		AVAudioEngine *audio = [[AVAudioEngine alloc] init];
		engine = audio;
		AVAudioInputNode *input = [audio inputNode];
		AVAudioFormat *format = [input outputFormatForBus:0];
		if([format sampleRate] <= 0.0) {
			[self stop];
			return;
		}
		/* The tap outlives each recognition task: only the request underneath it
		   is swapped, every fifty seconds. */
		[input installTapOnBus:0 bufferSize:2048 format:format
		                block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
			id current = request;
			if(current != nil)
				[(SFSpeechAudioBufferRecognitionRequest *)current appendAudioPCMBuffer:buffer];
		}];

		NSError *problem = nil;
		[audio prepare];
		if(![audio startAndReturnError:&problem]) {
			[self stop];
			return;
		}

		running = YES;
		[self beginTask];
		renewal = [NSTimer scheduledTimerWithTimeInterval:NekoWakeRenewal
		                                          target:self
		                                        selector:@selector(renew:)
		                                        userInfo:nil
		                                         repeats:YES];
	}
}

- (void)beginTask
{
	if(@available(macOS 10.15, *)) {
		SFSpeechAudioBufferRecognitionRequest *audioRequest =
			[[SFSpeechAudioBufferRecognitionRequest alloc] init];
		[audioRequest setShouldReportPartialResults:YES];
		[audioRequest setRequiresOnDeviceRecognition:YES];
		request = audioRequest;

		task = [[(SFSpeechRecognizer *)recognizer
			recognitionTaskWithRequest:audioRequest
			             resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {
			if(result != nil)
				[self heard:[[result bestTranscription] formattedString]];
			if(error != nil && running)
				[self renew:nil];   /* a task that died is rebuilt, not mourned */
		}] retain];
	}
}

- (void)endTask
{
	if(@available(macOS 10.15, *)) {
		[(SFSpeechAudioBufferRecognitionRequest *)request endAudio];
		[(SFSpeechRecognitionTask *)task cancel];
	}
	[(id)request release];
	request = nil;
	[(id)task release];
	task = nil;
}

- (void)renew:(NSTimer *)timer
{
	if(!running)
		return;
	[self endTask];
	[self beginTask];
}

- (void)stop
{
	[renewal invalidate];
	renewal = nil;
	[resume invalidate];
	resume = nil;
	if(@available(macOS 10.15, *)) {
		[(AVAudioEngine *)engine stop];
		[[(AVAudioEngine *)engine inputNode] removeTapOnBus:0];
	}
	[self endTask];
	[(id)engine release];
	engine = nil;
	[(id)recognizer release];
	recognizer = nil;
	running = NO;
}

#pragma mark Hearing it

- (void)heard:(NSString *)text
{
	if(!running || ![NekoWakeWord textNamesTheCat:text])
		return;
	if(lastHeard != nil && -[lastHeard timeIntervalSinceNow] < NekoWakeCooldown)
		return;
	[lastHeard release];
	lastHeard = [[NSDate date] retain];

	NekoAsk *ask = [NekoAsk sharedAsk];
	if([ask isBusy] || [ask isSpeaking])
		return;

	/* The microphone cannot be held by two things at once, and the cat is about
	   to want it: stop, hand over, and pick it up again when the conversation is
	   over. */
	[self stop];
	[ask toggle:nil];
	resume = [NSTimer scheduledTimerWithTimeInterval:1.0
	                                         target:self
	                                       selector:@selector(maybeResume:)
	                                       userInfo:nil
	                                        repeats:YES];
}

- (void)maybeResume:(NSTimer *)timer
{
	NekoAsk *ask = [NekoAsk sharedAsk];
	if([ask isBusy] || [ask isSpeaking])
		return;
	[resume invalidate];
	resume = nil;
	[self applySettings];
}

- (void)dealloc
{
	[self stop];
	[lastHeard release];
	[super dealloc];
}

@end
