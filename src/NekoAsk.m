#import "NekoAsk.h"
#import "NekoPainter.h"
#import "NekoAction.h"
#import "NekoHotKey.h"
#import "NekoListener.h"
#import "NekoBubble.h"
#import "NekoShortcutProvider.h"
#import "NekoModelProvider.h"
#import "NekoAppleProvider.h"
#import "NekoOpenAIProvider.h"
#import "NekoLocalProvider.h"
#import "NekoController.h"
#import "MyPanel.h"
#import <AVFoundation/AVFoundation.h>

NSString * const NekoAskEnabledKey        = @"NekoAskEnabled";
NSString * const NekoAskHotKeyCodeKey     = @"NekoAskHotKeyCode";
NSString * const NekoAskHotKeyModifiersKey = @"NekoAskHotKeyModifiers";
NSString * const NekoAskProviderKey       = @"NekoAskProvider";
NSString * const NekoAskShortcutNameKey   = @"NekoAskShortcutName";
NSString * const NekoAskSpeakKey          = @"NekoAskSpeak";
static NSString * const NekoAskExplainedKey = @"NekoAskExplained";

enum { NekoPhaseIdle = 0, NekoPhaseListening, NekoPhaseThinking, NekoPhaseAnswering };

#define NekoAskLocalized(text) NSLocalizedString(text, nil)

@implementation NekoAsk

+ (void)initialize
{
	if(self != [NekoAsk class])
		return;
	[[NSUserDefaults standardUserDefaults] registerDefaults:
		[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:NO], NekoAskEnabledKey,
			[NSNumber numberWithInt:0x2D], NekoAskHotKeyCodeKey,
			[NSNumber numberWithInt:(int)(NSEventModifierFlagControl
			                              | NSEventModifierFlagOption)],
				NekoAskHotKeyModifiersKey,
			@"apple", NekoAskProviderKey,   /* free, private, and already there */
			@"Ask Neko", NekoAskShortcutNameKey,
			[NSNumber numberWithBool:NO], NekoAskSpeakKey, nil]];
}

+ (NekoAsk *)sharedAsk
{
	static NekoAsk *shared = nil;
	if(shared == nil)
		shared = [[NekoAsk alloc] init];
	return shared;
}

- (id)init
{
	if((self = [super init]) != nil) {
		bubble = [[NekoBubble alloc] init];
		[bubble setDismissalTarget:self action:@selector(bubbleDismissed:)];
		[self applySettings];
	}
	return self;
}

#pragma mark Settings

- (BOOL)isEnabled
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:NekoAskEnabledKey];
}

- (BOOL)isBusy
{
	return phase != NekoPhaseIdle;
}

- (void)applySettings
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	if(![self isEnabled]) {
		/* Only when there is something to abandon: finish reaches for the panel
		   through NekoController, and this runs from init, where asking the
		   controller for anything would have it ask for this object right back. */
		if(phase != NekoPhaseIdle)
			[self finish];
		[hotKey release];
		hotKey = nil;
		hotKeyFailed = NO;
		return;
	}

	if(hotKey == nil)
		hotKey = [[NekoHotKey alloc] initWithTarget:self action:@selector(toggle:)];

	unsigned short code = (unsigned short)[defaults integerForKey:NekoAskHotKeyCodeKey];
	NSUInteger flags = (NSUInteger)[defaults integerForKey:NekoAskHotKeyModifiersKey];
	hotKeyFailed = ![hotKey registerKeyCode:code modifiers:flags];
}

- (NSString *)hotKeyDisplayName
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [NekoHotKey displayNameForKeyCode:
		(unsigned short)[defaults integerForKey:NekoAskHotKeyCodeKey]
	                              modifiers:(NSUInteger)[defaults integerForKey:NekoAskHotKeyModifiersKey]];
}

- (BOOL)hotKeyUnavailable
{
	return hotKeyFailed;
}

- (NekoModelProvider *)modelProvider
{
	if(modelProvider == nil)
		modelProvider = [[NekoModelProvider alloc] init];
	return modelProvider;
}

- (NekoAppleProvider *)appleProvider
{
	if(appleProvider == nil)
		appleProvider = [[NekoAppleProvider alloc] init];
	return appleProvider;
}

- (NekoOpenAIProvider *)openaiProvider
{
	if(openaiProvider == nil)
		openaiProvider = [[NekoOpenAIProvider alloc] init];
	return openaiProvider;
}

- (id<NekoAnswerProvider>)provider
{
	NSString *choice = [[NSUserDefaults standardUserDefaults]
		stringForKey:NekoAskProviderKey];
	if([choice isEqualToString:@"model"])
		return [self modelProvider];
	if([choice isEqualToString:@"openai"])
		return [self openaiProvider];
	if([choice isEqualToString:@"local"]) {
		if(localProvider == nil)
			localProvider = [[NekoLocalProvider alloc] init];
		return localProvider;
	}
	if([choice isEqualToString:@"apple"] || [choice length] == 0)
		return [self appleProvider];

	NSString *name = [[NSUserDefaults standardUserDefaults]
		stringForKey:NekoAskShortcutNameKey];
	if(shortcutProvider == nil
	   || ![[shortcutProvider shortcutName] isEqualToString:name]) {
		[shortcutProvider release];
		shortcutProvider = [[NekoShortcutProvider alloc] initWithShortcutName:name];
	}
	return shortcutProvider;
}

#pragma mark The cat

- (MyPanel *)panel
{
	return [[NekoController sharedController] panel];
}

- (void)showBubble:(NSString *)text dismissAfter:(NSTimeInterval)seconds
{
	MyPanel *panel = [self panel];
	NSRect where = panel != nil ? [panel frame]
	                            : NSMakeRect(200.0f, 200.0f, 32.0f, 32.0f);
	[bubble showText:text nearRect:where dismissAfter:seconds];
}

#pragma mark Starting and stopping

- (void)toggle:(id)sender
{
	if(![self isEnabled])
		return;
	if([self isBusy]) {
		[self cancelEverything];
		return;
	}
	[self beginListening];
}

#pragma mark Speaking unasked

- (BOOL)isSpeaking
{
	return [bubble isShowing];
}

- (BOOL)canSpeakUnprompted
{
	return phase == NekoPhaseIdle && ![bubble isShowing];
}

- (void)sayUnprompted:(NSString *)text
{
	if(![self canSpeakUnprompted] || [text length] == 0)
		return;
	NSTimeInterval showing = [NekoBubble readingTimeFor:text];
	phase = NekoPhaseAnswering;
	[[self panel] holdWithState:NekoStateStop];
	[self showBubble:text dismissAfter:showing];
	[self speak:text];
	[self performSelector:@selector(finish) withObject:nil afterDelay:showing];
}

- (void)showDrawing:(NSImage *)picture near:(id)ignored
{
	if(picture == nil)
		return;
	phase = NekoPhaseAnswering;
	[[self panel] holdWithState:NekoStateStop];
	[bubble showText:@"" picture:picture nearRect:[[self panel] frame] dismissAfter:20.0];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	                                         selector:@selector(finish) object:nil];
	[self performSelector:@selector(finish) withObject:nil afterDelay:20.0];
}

- (void)cancelEverything
{
	[self stopThinking];
	[[NekoPainter sharedPainter] cancel];
	[listener cancel];
	[[self provider] cancel];
	[self finish];
	[bubble hide];
}

/* Back to being a cat. */
- (void)finish
{
	phase = NekoPhaseIdle;
	[[self panel] releaseHold];
}

- (void)bubbleDismissed:(id)sender
{
	if(phase == NekoPhaseAnswering)
		[self finish];
	else
		[self cancelEverything];
}

#pragma mark Listening

- (void)beginListening
{
	if(![NekoListener isAvailable]) {
		[self sayInCharacter:NekoAskLocalized(@"My ears do not work on this Mac.")];
		return;
	}

	NSInteger status = [NekoListener authorizationStatus];
	if(status == 1 || status == 2) {           /* denied or restricted */
		[self sayInCharacter:NekoAskLocalized(@"You have not let me listen. Microphone, in System Settings.")];
		return;
	}
	if(status == 0) {                          /* never asked */
		[self explainThenAuthorise];
		return;
	}
	[self startCapture];
}

/* The system prompt on its own is a surprise; this says what is about to
   happen, once. */
- (void)explainThenAuthorise
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if(![defaults boolForKey:NekoAskExplainedKey]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NekoAskLocalized(@"Neko is about to ask for the microphone")];
		[alert setInformativeText:NekoAskLocalized(@"It listens only while you hold the conversation, from the keystroke until you stop talking. Nothing is recorded and nothing is kept.")];
		[alert addButtonWithTitle:NekoAskLocalized(@"Continue")];
		[alert addButtonWithTitle:NekoAskLocalized(@"Not now")];
		[NSApp activateIgnoringOtherApps:YES];
		if([alert runModal] != NSAlertFirstButtonReturn)
			return;
		[defaults setBool:YES forKey:NekoAskExplainedKey];
	}

	[NekoListener requestAuthorization:^(BOOL granted) {
		if(granted)
			[self startCapture];
		else
			[self sayInCharacter:NekoAskLocalized(@"Then I shall keep quiet.")];
	}];
}

- (void)startCapture
{
	if(listener == nil)
		listener = [[NekoListener alloc] init];

	phase = NekoPhaseListening;
	[[self panel] holdWithState:NekoStateAwake];
	[self showBubble:NekoAskLocalized(@"Listening…") dismissAfter:0.0];

	BOOL started = [listener startListeningWithLocale:[NSLocale currentLocale]
		report:^(NSString *text, BOOL final, NSError *error) {
			[self heard:text final:final error:error];
		}];
	if(!started) {
		phase = NekoPhaseIdle;
		[self sayInCharacter:NekoAskLocalized(@"I could not hear anything at all.")];
	}
}

- (void)heard:(NSString *)text final:(BOOL)final error:(NSError *)error
{
	if(phase != NekoPhaseListening)
		return;

	if(error != nil || (final && [text length] == 0)) {
		phase = NekoPhaseIdle;
		[self sayInCharacter:NekoAskLocalized(@"I did not catch that.")];
		return;
	}

	if(!final) {
		[self showBubble:text dismissAfter:0.0];   /* the question as it forms */
		return;
	}

	[self ask:text];
}

#pragma mark Waiting, visibly

/* Something has to happen between the question and the answer. A spinner would
   do; a cat that is visibly busy doing cat things is better, and the wait is
   where the character has the most room. */
- (NSArray *)thinkingLines
{
	return [NSArray arrayWithObjects:
		NekoAskLocalized(@"sniffing the question"),
		NekoAskLocalized(@"scratching my head"),
		NekoAskLocalized(@"consulting the ball of yarn"),
		NekoAskLocalized(@"staring out of the window"),
		NekoAskLocalized(@"chasing the thought"), nil];
}

- (void)startThinkingAbout:(NSString *)question
{
	[thinkingQuestion release];
	thinkingQuestion = [question copy];
	thinkingTick = 0;
	[thinking invalidate];
	thinking = [NSTimer scheduledTimerWithTimeInterval:0.25
	                                           target:self
	                                         selector:@selector(thinkingTick:)
	                                         userInfo:nil
	                                          repeats:YES];
	[self thinkingTick:nil];
}

- (void)thinkingTick:(NSTimer *)timer
{
	if(phase != NekoPhaseThinking) {
		[self stopThinking];
		return;
	}

	NSArray *lines = [self thinkingLines];
	/* A new occupation every couple of seconds, and the tail grows in between. */
	NSString *line = [lines objectAtIndex:(thinkingTick / 8) % [lines count]];
	static const char *paws[] = {"🐾", "🐾 ", "🐾  ", "🐾   "};
	NSString *paw = [NSString stringWithUTF8String:paws[thinkingTick % 4]];
	NSString *dots = [@"..." substringToIndex:1 + (thinkingTick % 3)];

	[self showBubble:[NSString stringWithFormat:@"%@\n\n%@%@%@",
		thinkingQuestion, paw, line, dots] dismissAfter:0.0];
	thinkingTick++;
}

- (void)stopThinking
{
	[thinking invalidate];
	thinking = nil;
	[thinkingQuestion release];
	thinkingQuestion = nil;
}

#pragma mark Answering

- (void)ask:(NSString *)question
{
	id<NekoAnswerProvider> provider = [self provider];
	if(![provider isConfigured]) {
		phase = NekoPhaseIdle;
		[self sayInCharacter:[self cannedReply]];
		return;
	}

	phase = NekoPhaseThinking;
	[[self panel] holdWithState:NekoStateKaki];
	/* The question stays up while it thinks, so you can see what it understood,
	   with the cat visibly busy underneath it. */
	[self startThinkingAbout:question];

	/* Whoever is on screen is who answers. */
	NekoCharacter *character = [[NekoController sharedController] character];
	/* Only offer the model the drawing route when there is something to draw
	   with: told it may draw when it cannot, it answers "IMAGE: a cat" to
	   somebody who asked a question and gets nothing back. */
	NSString *instructions = NekoAnswerInstructionsWith(
		[character persona], [[NekoPainter sharedPainter] isReady],
		[[NSUserDefaults standardUserDefaults] boolForKey:NekoActionsEnabledKey]);

	void (^finished)(NSString *, NSError *) = ^(NSString *answer, NSError *error) {
		if(phase != NekoPhaseThinking && phase != NekoPhaseAnswering)
			return;                            /* cancelled while it thought */
		[self stopThinking];
		if([answer length] > 0)
			[self answer:answer];
		else
			[self failed:error];
	};

	/* Streaming when the provider can: the first words land in about half a
	   second, which reads as quick even though the whole answer takes longer.
	   The bubble is only redrawn ten times a second — the model produces
	   snapshots far faster than that, and resizing a window on every one of
	   them looks like a stutter. */
	if([provider respondsToSelector:@selector(askQuestion:instructions:partial:completion:)]) {
		lastDrawn = nil;
		[provider askQuestion:question
		        instructions:instructions
		             partial:^(NSString *sofar) {
			if(phase != NekoPhaseThinking || [sofar length] == 0)
				return;
			if([self looksLikeADrawing:sofar] || [NekoAction looksLikeAnAction:sofar])
				return;              /* asking for a picture or a deed, not talking */
			[self stopThinking];       /* words are arriving; stop fidgeting */
			if(lastDrawn != nil && [lastDrawn timeIntervalSinceNow] > -0.1)
				return;
			[lastDrawn release];
			lastDrawn = [[NSDate date] retain];
			[[self panel] holdWithState:NekoStateStop];
			[self showBubble:sofar dismissAfter:0.0];
		}
		          completion:finished];
		return;
	}

	[provider askQuestion:question instructions:instructions completion:finished];
}

/* A model that wants a picture answers with the marker and nothing else. */
- (BOOL)looksLikeADrawing:(NSString *)text
{
	NSString *trimmed = [text stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return [[trimmed uppercaseString] hasPrefix:NekoImageMarker];
}

- (NSString *)drawingPromptIn:(NSString *)text
{
	NSString *trimmed = [text stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSRange colon = [trimmed rangeOfString:@":"];
	if(colon.location == NSNotFound)
		return nil;
	NSString *prompt = [[trimmed substringFromIndex:NSMaxRange(colon)]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSRange newline = [prompt rangeOfString:@"\n"];
	if(newline.location != NSNotFound)
		prompt = [prompt substringToIndex:newline.location];
	return [prompt length] > 0 ? prompt : nil;
}

/* Twenty odd seconds pass between asking and the picture, so the cat says it is
   drawing and stays put — an empty bubble for that long reads as broken. */
- (void)draw:(NSString *)prompt
{
	phase = NekoPhaseAnswering;
	[[self panel] holdWithState:NekoStateKaki];
	[self showBubble:NekoAskLocalized(@"Hold on, I will draw it.") dismissAfter:0.0];

	[[NekoPainter sharedPainter] draw:prompt completion:^(NSImage *picture, NSError *error) {
		if(phase != NekoPhaseAnswering)
			return;                   /* dismissed while it drew */
		if(picture == nil) {
			[self failed:error];
			return;
		}
		NSTimeInterval showing = 30.0;
		[[self panel] holdWithState:NekoStateStop];
		[bubble showText:@"" picture:picture
		        nearRect:[[self panel] frame] dismissAfter:showing];
		[NSObject cancelPreviousPerformRequestsWithTarget:self
		                                         selector:@selector(finish) object:nil];
		[self performSelector:@selector(finish) withObject:nil afterDelay:showing];
	}];
}

/* Nothing is done on the strength of a model's sentence alone: the deed is read
   back in the bubble and waits for a yes. A dismissed bubble, or one that timed
   out, is a no. */
- (void)propose:(NekoAction *)action
{
	phase = NekoPhaseAnswering;
	[[self panel] holdWithState:NekoStateAwake];
	[bubble askText:[action summary] nearRect:[[self panel] frame]
	        decided:^(BOOL yes) {
		if(!yes) {
			[self sayInCharacter:NekoAskLocalized(@"All right, I will not.")];
			return;
		}
		NSError *problem = nil;
		if([action perform:&problem])
			[self sayInCharacter:NekoAskLocalized(@"Done.")];
		else
			[self sayInCharacter:[problem localizedDescription]
				?: NekoAskLocalized(@"That did not work.")];
	}];
}

- (void)answer:(NSString *)text
{
	if([NekoAction looksLikeAnAction:text]
	   && [[NSUserDefaults standardUserDefaults] boolForKey:NekoActionsEnabledKey]) {
		NekoAction *action = [NekoAction actionFromLine:text];
		if(action != nil) {
			[self propose:action];
			return;
		}
		/* It asked for something outside the four verbs, or named a program that
		   is not here: better to say so than to say nothing. */
		[self sayInCharacter:NekoAskLocalized(@"I cannot do that one.")];
		return;
	}

	if([self looksLikeADrawing:text] && [[NekoPainter sharedPainter] isReady]) {
		NSString *prompt = [self drawingPromptIn:text];
		if([prompt length] > 0) {
			[self draw:prompt];
			return;
		}
	}
	phase = NekoPhaseAnswering;
	[[self panel] holdWithState:NekoStateStop];
	[self showBubble:text dismissAfter:[NekoBubble readingTimeFor:text]];
	[self speak:text];
	[self performSelector:@selector(finish)
	           withObject:nil
	           afterDelay:[NekoBubble readingTimeFor:text]];
}

- (void)failed:(NSError *)error
{
	NSString *line = NekoAskLocalized(@"I have no answer for that.");
	if([[error domain] isEqualToString:NekoAskErrorDomain]) {
		switch([error code]) {
			case NekoAskErrorTimedOut:
				line = NekoAskLocalized(@"Whatever I asked never answered.");
				break;
			case NekoAskErrorNotConfigured:
				line = [self cannedReply];
				break;
			case NekoAskErrorNoShortcut:
				line = [NSString stringWithFormat:
					NekoAskLocalized(@"I cannot find a Shortcut called “%@”."),
					[[error userInfo] objectForKey:@"name"] ?: @"?"];
				break;
			default:
				break;
		}
	} else if([error localizedDescription] != nil) {
		line = [error localizedDescription];
	}
	phase = NekoPhaseIdle;
	[self sayInCharacter:line];
}

/* Something in character, for when there is nothing to ask. */
- (NSString *)cannedReply
{
	NSArray *lines = [NSArray arrayWithObjects:
		NekoAskLocalized(@"I am a cat. Ask me again once you have set up an answer."),
		NekoAskLocalized(@"No idea. I mostly chase the cursor."),
		NekoAskLocalized(@"Ask the Shortcut. I have not been given one."), nil];
	return [lines objectAtIndex:arc4random_uniform((unsigned)[lines count])];
}

- (void)sayInCharacter:(NSString *)line
{
	[[self panel] holdWithState:NekoStateAkubi];
	phase = NekoPhaseAnswering;
	[self showBubble:line dismissAfter:4.0];
	[self speak:line];
	[self performSelector:@selector(finish) withObject:nil afterDelay:4.0];
}

- (void)speak:(NSString *)text
{
	if(![[NSUserDefaults standardUserDefaults] boolForKey:NekoAskSpeakKey])
		return;
	if(@available(macOS 10.14, *)) {
		AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:text];
		[utterance setPitchMultiplier:1.25f];  /* a cat, not a newsreader */
		static AVSpeechSynthesizer *synthesizer = nil;
		if(synthesizer == nil)
			synthesizer = [[AVSpeechSynthesizer alloc] init];
		[synthesizer speakUtterance:utterance];
	}
}

@end
