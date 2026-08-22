#import "NekoAntics.h"
#import "NekoAsk.h"
#import "NekoController.h"
#import "MyPanel.h"

#define NekoAnticsLocalized(text) NSLocalizedString(text, nil)

/* How often it considers being curious, and how long it waits between antics.
   Often enough to feel alive, rare enough not to be a colleague who taps you on
   the shoulder every minute. */
static const NSTimeInterval NekoAnticsHeartbeat = 5.0;
static const NSTimeInterval NekoAnticsMinWait = 45.0;
static const NSTimeInterval NekoAnticsWaitSpread = 75.0;

/* Nobody there. */
static const NSTimeInterval NekoAnticsAway = 150.0;

@implementation NekoAntics

+ (NekoAntics *)sharedAntics
{
	static NekoAntics *shared = nil;
	if(shared == nil)
		shared = [[NekoAntics alloc] init];
	return shared;
}

- (id)init
{
	self = [super init];
	if(self != nil) {
		cooldown = NekoAnticsMinWait;
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
	[arrival invalidate];
	[lastAntic release];
	[sampledAt release];
	[pendingLine release];
	[super dealloc];
}

- (void)settingsChanged:(NSNotification *)note
{
	[self applySettings];
}

- (void)applySettings
{
	BOOL wanted = [[NekoController sharedController] roamsOnItsOwn];
	if(wanted == (heartbeat != nil))
		return;
	if(!wanted) {
		[heartbeat invalidate];
		heartbeat = nil;
		[arrival invalidate];
		arrival = nil;
		return;
	}
	heartbeat = [NSTimer scheduledTimerWithTimeInterval:NekoAnticsHeartbeat
	                                            target:self
	                                          selector:@selector(consider:)
	                                          userInfo:nil
	                                           repeats:YES];
}

#pragma mark What the machine will admit to

/* Counters, not events: no tap on the input stream, no accessibility
   permission, nothing that could see a keystroke. */
- (uint32_t)counterFor:(CGEventType)type
{
	return (uint32_t)CGEventSourceCounterForEventType(
		kCGEventSourceStateCombinedSessionState, type);
}

- (void)sample
{
	uint32_t keys = [self counterFor:kCGEventKeyDown];
	uint32_t moves = [self counterFor:kCGEventMouseMoved];
	NSTimeInterval since = sampledAt != nil ? -[sampledAt timeIntervalSinceNow] : 0.0;

	if(since > 1.0) {
		double minutes = since / 60.0;
		keysPerMinute = (uint32_t)((keys - keysBefore) / minutes);
		movesPerMinute = (uint32_t)((moves - movesBefore) / minutes);
	}
	keysBefore = keys;
	movesBefore = moves;
	[sampledAt release];
	sampledAt = [[NSDate date] retain];
}

- (NSTimeInterval)idleSeconds
{
	return CGEventSourceSecondsSinceLastEventType(
		kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType);
}

#pragma mark Deciding

- (BOOL)mayBeCuriousNow
{
	NekoController *controller = [NekoController sharedController];
	MyPanel *panel = [controller panel];
	if(panel == nil || ![panel isRoaming] || [controller isPaused])
		return NO;
	if([panel isOnErrand] || [panel isHeld])
		return NO;
	if(![[NekoAsk sharedAsk] canSpeakUnprompted])
		return NO;
	if([self idleSeconds] > NekoAnticsAway)
		return NO;
	return lastAntic == nil || -[lastAntic timeIntervalSinceNow] > cooldown;
}

- (void)consider:(NSTimer *)timer
{
	[self sample];
	if(![self mayBeCuriousNow])
		return;
	[self anticNow];
}

#pragma mark The antics themselves

- (NSString *)questionAboutTyping
{
	NSArray *lines = [NSArray arrayWithObjects:
		NekoAnticsLocalized(@"What are you writing?"),
		NekoAnticsLocalized(@"Is it about me?"),
		NekoAnticsLocalized(@"That is a lot of words. Any of them mine?"),
		NekoAnticsLocalized(@"May I watch you type?"),
		NekoAnticsLocalized(@"Need a hand? I only have paws."), nil];
	return [lines objectAtIndex:arc4random_uniform((unsigned)[lines count])];
}

- (NSString *)lineAboutThePointer
{
	NSArray *lines = [NSArray arrayWithObjects:
		NekoAnticsLocalized(@"Got it. It was getting away."),
		NekoAnticsLocalized(@"This arrow keeps moving. Suspicious."),
		NekoAnticsLocalized(@"Caught your cursor. You may have it back."), nil];
	return [lines objectAtIndex:arc4random_uniform((unsigned)[lines count])];
}

/* Where the cat should stand to be nosy: beside the pointer, which is where the
   caret usually is and, more to the point, where you are looking. */
- (NSPoint)pointerSpot
{
	return [NSEvent mouseLocation];
}

- (void)beginAntic:(NSString *)line
        goingTo:(NSPoint)spot
             pose:(NekoState)pose
        forTicks:(unsigned)ticks
{
	MyPanel *panel = [[NekoController sharedController] panel];
	[lastAntic release];
	lastAntic = [[NSDate date] retain];
	cooldown = NekoAnticsMinWait + (NSTimeInterval)arc4random_uniform(
		(unsigned)NekoAnticsWaitSpread);

	[pendingLine release];
	pendingLine = [line copy];
	[panel errandTo:spot thenState:pose forTicks:ticks];

	/* The line waits for the cat: saying "what are you writing?" from the other
	   side of the screen is a different, worse joke. */
	[arrival invalidate];
	arrival = nil;
	if(pendingLine != nil)
		arrival = [NSTimer scheduledTimerWithTimeInterval:0.5
		                                          target:self
		                                        selector:@selector(sayItThere:)
		                                        userInfo:nil
		                                         repeats:YES];
}

- (void)sayItThere:(NSTimer *)timer
{
	MyPanel *panel = [[NekoController sharedController] panel];
	if(panel == nil || ![panel isRoaming]) {
		[arrival invalidate];
		arrival = nil;
		return;
	}
	if([panel isOnErrand])
		return;                          /* still on its way */

	[arrival invalidate];
	arrival = nil;
	if([pendingLine length] > 0)
		[[NekoAsk sharedAsk] sayUnprompted:pendingLine];
	[pendingLine release];
	pendingLine = nil;
}

/* Which antic suits the moment. Typing hard is the interesting one — that is
   somebody at work, and a cat that came over to read it is the joke. */
- (NSString *)anticNow
{
	[self sample];
	MyPanel *panel = [[NekoController sharedController] panel];
	if(panel == nil || ![panel isRoaming])
		return NekoAnticsLocalized(@"Only while roaming.");

	NSTimeInterval idle = [self idleSeconds];

	if(keysPerMinute > 40) {
		/* Reading over your shoulder: it comes over, sits, and asks. */
		[self beginAntic:[self questionAboutTyping]
		         goingTo:[self pointerSpot]
		            pose:NekoStateKaki
		        forTicks:40];
		return NekoAnticsLocalized(@"It came over to ask what you are writing.");
	}
	if(movesPerMinute > 120) {
		[self beginAntic:(arc4random_uniform(2) == 0) ? [self lineAboutThePointer] : nil
		         goingTo:[self pointerSpot]
		            pose:NekoStateKaki
		        forTicks:16];
		return NekoAnticsLocalized(@"It pounced on the cursor.");
	}
	if(idle > 20.0) {
		/* Nobody typing, nobody clicking: it goes and claws the edge of the
		   screen, which the wall behaviour turns into scratching on arrival. */
		NSRect bounds = [[panel screen] visibleFrame];
		NSRect frame = [panel frame];
		BOOL left = NSMidX(frame) < NSMidX(bounds);
		[self beginAntic:nil
		         goingTo:NSMakePoint(left ? NSMinX(bounds) : NSMaxX(bounds),
		                             NSMinY(frame))
		            pose:NekoStateCount
		        forTicks:0];
		return NekoAnticsLocalized(@"It went to claw the edge of the screen.");
	}

	/* Something is happening, just not much: a look in your direction. */
	[self beginAntic:nil
	         goingTo:[self pointerSpot]
	            pose:NekoStateJare
	        forTicks:24];
	return NekoAnticsLocalized(@"It wandered over to see what you were up to.");
}

@end
