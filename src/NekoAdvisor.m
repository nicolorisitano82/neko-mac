#import "NekoAdvisor.h"
#import "NekoAsk.h"
#import "NekoController.h"
#import "NekoCharacter.h"
#import "NekoAnswerProvider.h"
#import "NekoDesktop.h"
#import "NekoSense.h"
#import "NekoBrains.h"

NSString * const NekoSuggestLastKey = @"NekoSuggestLast";

#define NekoAdvisorLocalized(text) NSLocalizedString(text, nil)

/* How often the cat looks up from what it is doing. Cheap: two lookups and a
   couple of comparisons, nothing that touches the disk or the network. */
static const NSTimeInterval NekoAdvisorHeartbeat = 20.0;

/* Long enough in one application to call it an activity worth commenting on. */
static const NSTimeInterval NekoAdvisorSettled = 25.0;

/* Nobody there, or someone in the middle of a word. */
static const NSTimeInterval NekoAdvisorAway = 150.0;
static const NSTimeInterval NekoAdvisorTyping = 3.0;

@implementation NekoAdvisor

+ (NekoAdvisor *)sharedAdvisor
{
	static NekoAdvisor *shared = nil;
	if(shared == nil)
		shared = [[NekoAdvisor alloc] init];
	return shared;
}

- (id)init
{
	self = [super init];
	if(self != nil) {
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(settingsChanged:)
			       name:NekoSettingsDidChangeNotification
			     object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[heartbeat invalidate];
	[lastSpoke release];
	[lastSubject release];
	[super dealloc];
}

- (BOOL)isThinking
{
	return waiting;
}

- (void)settingsChanged:(NSNotification *)note
{
	[self applySettings];
}

- (void)applySettings
{
	BOOL wanted = [[NekoController sharedController] suggestsUnasked];
	if(wanted == (heartbeat != nil))
		return;
	if(!wanted) {
		[heartbeat invalidate];
		heartbeat = nil;
		return;
	}
	/* Not retained: the timer is invalidated before it could outlive us, and
	   this object lives as long as the application does. */
	heartbeat = [NSTimer scheduledTimerWithTimeInterval:NekoAdvisorHeartbeat
	                                            target:self
	                                          selector:@selector(look:)
	                                          userInfo:nil
	                                           repeats:YES];
}

#pragma mark Watching, shallowly

/* All of it lives in NekoDesktop now, which the antics read too: one place that
   knows what is going on, rather than two that each keep half of it. */
- (NSString *)context
{
	return [[NekoDesktop sharedDesktop] summary];
}

/* Small models wrap their one sentence in quotation marks or bold it, both of
   which read as somebody quoting somebody else inside a speech bubble. */
- (NSString *)cleanUp:(NSString *)answer
{
	NSString *line = [answer stringByReplacingOccurrencesOfString:@"**" withString:@""];
	line = [line stringByReplacingOccurrencesOfString:@"*" withString:@""];
	line = [line stringByReplacingOccurrencesOfString:@"#" withString:@""];
	line = [line stringByTrimmingCharactersInSet:
		[NSCharacterSet characterSetWithCharactersInString:
			@" \t\n\r\"'\u201c\u201d\u00ab\u00bb"]];
	/* Only the first sentence, however carried away it got. */
	NSRange stop = [line rangeOfCharacterFromSet:
		[NSCharacterSet characterSetWithCharactersInString:@"\n"]];
	if(stop.location != NSNotFound)
		line = [[line substringToIndex:stop.location]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	return line;
}

#pragma mark Deciding to speak

/* Every reason not to, in the order that costs least to check. A suggestion is
   an interruption, and the whole feature dies if it interrupts badly. */
- (BOOL)shouldSpeakNow
{
	NekoController *controller = [NekoController sharedController];
	if(waiting || ![controller suggestsUnasked] || [controller isPaused])
		return NO;
	if([[NekoAsk sharedAsk] isBusy] || ![[NekoAsk sharedAsk] canSpeakUnprompted])
		return NO;

	NekoDesktop *desktop = [NekoDesktop sharedDesktop];
	NSTimeInterval idle = [desktop idleSeconds];
	if(idle > NekoAdvisorAway || idle < NekoAdvisorTyping)
		return NO;
	if(lastSpoke != nil
	   && -[lastSpoke timeIntervalSinceNow] < [controller suggestionInterval])
		return NO;
	if(![NekoAsk mayInterruptNow])
		return NO;                 /* something else spoke recently */

	NSString *app = [desktop frontApp];
	if([app length] == 0 || [desktop secondsInFront] < NekoAdvisorSettled)
		return NO;

	/* Twice the interval before saying anything else about the same
	   application: the second remark about the same window is where a helpful
	   pet turns into a nag. */
	if([app isEqualToString:lastSubject]
	   && lastSpoke != nil
	   && -[lastSpoke timeIntervalSinceNow] < [controller suggestionInterval] * 2.0)
		return NO;
	return YES;
}

- (void)look:(NSTimer *)timer
{
	[[NekoDesktop sharedDesktop] sample];
	if(![self shouldSpeakNow])
		return;
	[self suggestNow:NULL];
}

#pragma mark Asking

- (void)suggestNow:(void (^)(NSString *line, NSError *error))report
{
	/* Not the engine set for questions: the best one on this Mac. A remark
	   nobody asked for does not go to a remote service, and a remark written by
	   a model too small to hold the instructions is not worth the interruption. */
	id<NekoAnswerProvider> provider = [NekoBrains bestOnDeviceProvider];
	if(provider == nil || ![provider isConfigured]) {
		if(report != NULL)
			report(nil, [NSError errorWithDomain:NekoAskErrorDomain
			                                code:NekoAskErrorNotConfigured
			                            userInfo:nil]);
		return;
	}

	NekoCharacter *character = [[NekoController sharedController] character];
	NSString *instructions = NekoSuggestionInstructionsFor([character persona]);
	NSString *subject = [[[[NekoDesktop sharedDesktop] frontApp] copy] autorelease];
	NSString *context = [self context];
	void (^callerReport)(NSString *, NSError *) =
		report != NULL ? Block_copy(report) : nil;

	waiting = YES;
	[provider askQuestion:context
	        instructions:instructions
	          completion:^(NSString *answer, NSError *error) {
		waiting = NO;
		/* Small models like to hand back their one sentence in quotation marks,
		   which reads as a quotation of somebody else inside the bubble. */
		NSString *line = [self cleanUp:answer];

		/* A model with nothing worth saying is told to answer with a hyphen,
		   which is easier for a small one to obey than "say nothing". */
		/* Every attempt costs the interval, whatever came of it. Nothing to say
		   counts as having looked, and so does a refusal — Apple's model
		   declines the odd question, and retrying it every twenty seconds until
		   the application changes would be a loop, not a pet. */
		[lastSpoke release];
		lastSpoke = [[NSDate date] retain];
		[lastSubject release];
		lastSubject = [subject retain];

		NSString *problem = [NekoSense problemWith:line];
		if(problem != nil && ![problem isEqualToString:@"nothing to say"])
			NSLog(@"Neko: a suggestion was thrown away — %@: %@", problem, line);

		if([NekoSense isWorthSaying:line]) {
			[[NSUserDefaults standardUserDefaults]
				setObject:line forKey:NekoSuggestLastKey];
			[[NekoAsk sharedAsk] sayUnprompted:line];
		}

		if(callerReport != nil) {
			callerReport([NekoSense isWorthSaying:line] ? line : nil, error);
			Block_release(callerReport);
		}
	}];
}

@end
