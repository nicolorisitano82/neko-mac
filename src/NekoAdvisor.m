#import "NekoAdvisor.h"
#import "NekoAsk.h"
#import "NekoController.h"
#import "NekoCharacter.h"
#import "NekoAnswerProvider.h"

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
		switches = [[NSMutableArray alloc] init];
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(settingsChanged:)
			       name:NekoSettingsDidChangeNotification
			     object:nil];
		[[[NSWorkspace sharedWorkspace] notificationCenter]
			addObserver:self
			   selector:@selector(applicationChanged:)
			       name:NSWorkspaceDidActivateApplicationNotification
			     object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	[heartbeat invalidate];
	[frontApp release];
	[frontSince release];
	[lastSpoke release];
	[lastSubject release];
	[switches release];
	[super dealloc];
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

- (void)applicationChanged:(NSNotification *)note
{
	NSRunningApplication *app = [[note userInfo]
		objectForKey:NSWorkspaceApplicationKey];
	NSString *name = [app localizedName];
	if([name length] == 0 || [name isEqualToString:frontApp])
		return;

	[frontApp release];
	frontApp = [name retain];
	[frontSince release];
	frontSince = [[NSDate date] retain];

	[switches addObject:frontSince];
	while([switches count] > 40)
		[switches removeObjectAtIndex:0];
}

/* Filled in lazily as well as by the notification, so the first suggestion after
   launch knows where it is without waiting for you to switch applications. */
- (NSString *)currentApp
{
	NSString *name = [[[NSWorkspace sharedWorkspace] frontmostApplication]
		localizedName];
	if([name length] == 0)
		return frontApp;
	if(![name isEqualToString:frontApp]) {
		[frontApp release];
		frontApp = [name retain];
		[frontSince release];
		frontSince = [[NSDate date] retain];
	}
	return frontApp;
}

- (NSTimeInterval)secondsInFront
{
	return frontSince != nil ? -[frontSince timeIntervalSinceNow] : 0.0;
}

- (NSUInteger)switchesInTheLastQuarterHour
{
	NSUInteger count = 0;
	NSEnumerator *e = [switches objectEnumerator];
	NSDate *when;
	while((when = [e nextObject]) != nil)
		if(-[when timeIntervalSinceNow] < 900.0)
			count++;
	return count;
}

- (NSTimeInterval)idleSeconds
{
	return CGEventSourceSecondsSinceLastEventType(
		kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType);
}

/* Only when this Mac has already given Neko screen recording for some other
   reason. The permission is never requested here: a pet asking to record your
   screen so it can be chatty would be an outrageous trade. */
- (NSString *)frontWindowTitleIfAllowed
{
	if(!CGPreflightScreenCaptureAccess())
		return nil;

	NSString *wanted = [self currentApp];
	CFArrayRef windows = CGWindowListCopyWindowInfo(
		kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
		kCGNullWindowID);
	NSString *title = nil;
	NSEnumerator *e = [(NSArray *)windows objectEnumerator];
	NSDictionary *window;
	while((window = [e nextObject]) != nil) {
		NSString *owner = [window objectForKey:(NSString *)kCGWindowOwnerName];
		NSString *name = [window objectForKey:(NSString *)kCGWindowName];
		if([owner isEqualToString:wanted] && [name length] > 0) {
			title = [[name copy] autorelease];
			break;
		}
	}
	if(windows != NULL)
		CFRelease(windows);
	return title;
}

- (NSString *)context
{
	NSString *app = [self currentApp];
	NSString *title = [self frontWindowTitleIfAllowed];
	NSDateFormatter *clock = [[[NSDateFormatter alloc] init] autorelease];
	[clock setDateFormat:@"HH:mm"];

	NSMutableString *lines = [NSMutableString string];
	[lines appendString:@"Here is what I seem to be doing right now.\n"];
	[lines appendFormat:@"The program in front of me: %@\n", app ?: @"unknown"];
	if(title != nil)
		[lines appendFormat:@"Its window is titled: %@\n", title];
	[lines appendFormat:@"Minutes I have been in it: %.0f\n",
		[self secondsInFront] / 60.0];
	[lines appendFormat:@"Times I switched program in the last 15 minutes: %lu\n",
		(unsigned long)[self switchesInTheLastQuarterHour]];
	[lines appendFormat:@"Seconds since my last key or click: %.0f\n",
		[self idleSeconds]];
	[lines appendFormat:@"Local time: %@\n", [clock stringFromDate:[NSDate date]]];

	NSString *before = [[NSUserDefaults standardUserDefaults]
		stringForKey:NekoSuggestLastKey];
	if([before length] > 0)
		[lines appendFormat:@"What you told me last time, do not repeat it: %@\n", before];
	/* Ending on the instruction rather than on data: a small model answers the
	   last thing it read, and left to end on a list of numbers it describes the
	   numbers back. */
	[lines appendString:@"\nSay your one line to me now."];
	return lines;
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

	NSTimeInterval idle = [self idleSeconds];
	if(idle > NekoAdvisorAway || idle < NekoAdvisorTyping)
		return NO;
	if(lastSpoke != nil
	   && -[lastSpoke timeIntervalSinceNow] < [controller suggestionInterval])
		return NO;

	NSString *app = [self currentApp];
	if([app length] == 0 || [self secondsInFront] < NekoAdvisorSettled)
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
	if(![self shouldSpeakNow])
		return;
	[self suggestNow:NULL];
}

#pragma mark Asking

- (void)suggestNow:(void (^)(NSString *line, NSError *error))report
{
	id<NekoAnswerProvider> provider = [[NekoAsk sharedAsk] provider];
	if(![provider isConfigured]) {
		if(report != NULL)
			report(nil, [NSError errorWithDomain:NekoAskErrorDomain
			                                code:NekoAskErrorNotConfigured
			                            userInfo:nil]);
		return;
	}

	NekoCharacter *character = [[NekoController sharedController] character];
	NSString *instructions = NekoSuggestionInstructionsFor([character persona]);
	NSString *subject = [[[self currentApp] copy] autorelease];
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

		if([line length] > 0 && ![line isEqualToString:@"-"]) {
			[[NSUserDefaults standardUserDefaults]
				setObject:line forKey:NekoSuggestLastKey];
			[[NekoAsk sharedAsk] sayUnprompted:line];
		}

		if(callerReport != nil) {
			callerReport([line length] > 0 ? line : nil, error);
			Block_release(callerReport);
		}
	}];
}

@end
