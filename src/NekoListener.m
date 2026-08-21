#import "NekoListener.h"
#import "NekoAnswerProvider.h"
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

/* Long enough to think mid-sentence, short enough that a forgotten hotkey does
   not leave the microphone open. */
static const NSTimeInterval NekoSilenceTimeout = 2.5;
static const NSTimeInterval NekoListeningLimit = 15.0;

@implementation NekoListener

+ (BOOL)isAvailable
{
	return NSClassFromString(@"SFSpeechRecognizer") != Nil;
}

+ (NSInteger)authorizationStatus
{
	if(![self isAvailable])
		return 1;                /* as good as denied */
	if(@available(macOS 10.15, *))
		return (NSInteger)[SFSpeechRecognizer authorizationStatus];
	return 1;
}

+ (void)requestAuthorization:(void (^)(BOOL granted))completion
{
	if(![self isAvailable]) {
		completion(NO);
		return;
	}
	if(@available(macOS 10.15, *)) {
		[SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completion(status == SFSpeechRecognizerAuthorizationStatusAuthorized);
			});
		}];
	} else {
		completion(NO);
	}
}

- (void)dealloc
{
	[self cancel];
	[heard release];
	[super dealloc];
}

- (BOOL)isListening
{
	return engine != nil;
}

- (BOOL)isOnDevice
{
	return onDevice;
}

#pragma mark Listening

- (BOOL)startListeningWithLocale:(NSLocale *)locale
                          report:(void (^)(NSString *text, BOOL final, NSError *error))block
{
	if(![NekoListener isAvailable] || [self isListening])
		return NO;

	if(@available(macOS 10.15, *)) {
		SFSpeechRecognizer *speech = [[SFSpeechRecognizer alloc] initWithLocale:locale];
		if(speech == nil || ![speech isAvailable]) {
			[speech release];
			return NO;
		}
		recognizer = speech;

		SFSpeechAudioBufferRecognitionRequest *audioRequest =
			[[SFSpeechAudioBufferRecognitionRequest alloc] init];
		[audioRequest setShouldReportPartialResults:YES];
		/* Keeping it on the Mac when the language allows: the preferences say
		   which of the two is happening. */
		onDevice = [speech supportsOnDeviceRecognition];
		if(onDevice)
			[audioRequest setRequiresOnDeviceRecognition:YES];
		request = audioRequest;

		report = Block_copy(block);
		[heard release];
		heard = nil;

		AVAudioEngine *audio = [[AVAudioEngine alloc] init];
		engine = audio;
		AVAudioInputNode *input = [audio inputNode];
		AVAudioFormat *format = [input outputFormatForBus:0];
		if([format sampleRate] <= 0.0) {          /* no usable microphone */
			[self cancel];
			return NO;
		}
		[input installTapOnBus:0 bufferSize:1024 format:format
		                block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
			[(SFSpeechAudioBufferRecognitionRequest *)request appendAudioPCMBuffer:buffer];
		}];

		NSError *error = nil;
		[audio prepare];
		if(![audio startAndReturnError:&error]) {
			void (^failed)(NSString *, BOOL, NSError *) = report;
			report = NULL;
			[self cancel];
			if(failed != NULL) {
				failed(nil, YES, error);
				Block_release(failed);
			}
			return NO;
		}

		task = [[speech recognitionTaskWithRequest:audioRequest
		                            resultHandler:^(SFSpeechRecognitionResult *result,
		                                            NSError *taskError) {
			[self handleResult:result error:taskError];
		}] retain];

		[self restartSilenceTimer:NekoListeningLimit];
		return YES;
	}
	return NO;
}

- (void)handleResult:(id)result error:(NSError *)error
{
	if(report == NULL)
		return;

	if(@available(macOS 10.15, *)) {
		SFSpeechRecognitionResult *recognised = result;
		if(recognised != nil) {
			[heard release];
			heard = [[[recognised bestTranscription] formattedString] copy];
			BOOL final = [recognised isFinal];
			report(heard, final, nil);
			if(final) {
				[self cancel];
				return;
			}
			/* Words are still coming: reset the patience. */
			[self restartSilenceTimer:NekoSilenceTimeout];
			return;
		}
	}

	if(error != nil) {
		void (^failed)(NSString *, BOOL, NSError *) = report;
		report = NULL;
		NSString *partial = [[heard copy] autorelease];
		[self cancel];
		if(failed != NULL) {
			/* Something was understood before it broke: that counts. */
			if([partial length] > 0)
				failed(partial, YES, nil);
			else
				failed(nil, YES, error);
			Block_release(failed);
		}
	}
}

- (void)restartSilenceTimer:(NSTimeInterval)seconds
{
	[silence invalidate];
	silence = [NSTimer scheduledTimerWithTimeInterval:seconds
	                                          target:self
	                                        selector:@selector(silenceExpired:)
	                                        userInfo:nil
	                                         repeats:NO];
}

- (void)silenceExpired:(NSTimer *)timer
{
	silence = nil;
	[self stop];
}

- (void)stop
{
	if(![self isListening])
		return;

	if(@available(macOS 10.15, *))
		[(SFSpeechAudioBufferRecognitionRequest *)request endAudio];

	[[(AVAudioEngine *)engine inputNode] removeTapOnBus:0];
	[(AVAudioEngine *)engine stop];

	/* Nothing was understood at all: say so now rather than hanging. */
	if([heard length] == 0 && report != NULL) {
		void (^failed)(NSString *, BOOL, NSError *) = report;
		report = NULL;
		[self cancel];
		failed(nil, YES, [NSError errorWithDomain:NekoAskErrorDomain
		                                     code:NekoAskErrorNoAnswer
		                                 userInfo:nil]);
		Block_release(failed);
	}
}

- (void)cancel
{
	[silence invalidate];
	silence = nil;

	if(engine != nil) {
		[[(AVAudioEngine *)engine inputNode] removeTapOnBus:0];
		[(AVAudioEngine *)engine stop];
		[engine release];
		engine = nil;
	}
	if(task != nil) {
		if(@available(macOS 10.15, *))
			[(SFSpeechRecognitionTask *)task cancel];
		[task release];
		task = nil;
	}
	[request release];
	request = nil;
	[recognizer release];
	recognizer = nil;
	if(report != NULL) {
		Block_release(report);
		report = NULL;
	}
}

@end
