#import "NekoTimer.h"
#import "NekoWhen.h"
#import "NekoAsk.h"
#import "NekoMemory.h"

NSString * const NekoTimerDidChangeNotification = @"NekoTimerDidChange";

#define NekoTimerLocalized(key) \
	NSLocalizedStringFromTable(key, @"Localizable", nil)

/* How long it will wait for a decent moment before saying it anyway.

   Eight seconds, not twenty. This is the one thing in the application worth
   interrupting for — the whole point of it was to be told — and a timer that is
   right about the duration and then twenty seconds late about saying so is a
   timer that was wrong. Eight is enough to sit out a burst of typing, which is
   what most bad moments are, and short enough that nobody is misled. */
static const NSTimeInterval NekoTimerPatience = 8.0;
static const NSTimeInterval NekoTimerRetry = 2.0;

/* The words that turn a duration into a request. Without one of these "ho dormito
   otto ore" would set a timer for eight hours. */
static BOOL NekoAsksForATimer(NSString *question)
{
	NSString *text = [question lowercaseString];
	NSArray *triggers = [NSArray arrayWithObjects:
		/* Italian */
		@"timer", @"sveglia", @"svegliami", @"ricordamelo", @"ricordami",
		@"avvisami", @"avvertimi", @"dimmelo", @"conta",
		/* English */
		@"remind me", @"wake me", @"alarm", @"tell me in", @"set a timer",
		/* French */
		@"rappelle", @"réveille", @"minuteur", @"préviens",
		/* Spanish */
		@"recuérdame", @"despiértame", @"avísame", @"temporizador", nil];
	NSEnumerator *e = [triggers objectEnumerator];
	NSString *word;
	while((word = [e nextObject]) != nil)
		if([text rangeOfString:word].location != NSNotFound)
			return YES;

	/* Or the sentence is nothing but the waiting: "fra venti minuti", said on its
	   own, is a request and not a remark. */
	NSArray *openings = [NSArray arrayWithObjects:
		@"fra ", @"tra ", @"in ", @"dans ", @"en ", @"dentro di ", @"dentro de ", nil];
	NSEnumerator *o = [openings objectEnumerator];
	NSString *opening;
	while((opening = [o nextObject]) != nil)
		if([text hasPrefix:opening] && [text length] < 40)
			return YES;
	return NO;
}

@implementation NekoTimer

+ (NekoTimer *)sharedTimer
{
	static NekoTimer *shared = nil;
	if(shared == nil)
		shared = [[NekoTimer alloc] init];
	return shared;
}

+ (NSTimeInterval)wantedFor:(NSString *)question
{
	if(!NekoAsksForATimer(question))
		return 0.0;
	return [NekoWhen secondsIn:question];
}

#pragma mark Running one

- (NSString *)startFor:(NSTimeInterval)seconds
{
	if(seconds <= 0.0)
		return @"";
	[self cancel];

	asked = seconds;
	putOff = 0;
	landsAt = [[NSDate dateWithTimeIntervalSinceNow:seconds] retain];
	ticking = [[NSTimer scheduledTimerWithTimeInterval:seconds
	                                            target:self
	                                          selector:@selector(landed:)
	                                          userInfo:nil
	                                           repeats:NO] retain];
	/* Common modes, so that a menu held open does not hold the timer up too. */
	[[NSRunLoop currentRunLoop] addTimer:ticking forMode:NSRunLoopCommonModes];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:NekoTimerDidChangeNotification object:self];

	/* The sentence somebody is answered with: what it understood, and when it
	   lands. A duration repeated back proves nothing about whether it was heard
	   right; a clock time does. */
	return [NSString stringWithFormat:
		NekoTimerLocalized(@"%@: I will tell you at %@."),
		[NekoWhen describe:seconds], [NekoWhen clockTimeIn:seconds]];
}

- (void)landed:(NSTimer *)which
{
	/* A bad moment is worth waiting through, and not worth waiting through for
	   ever: somebody asked to be told. */
	if(![NekoAsk mayInterruptNow] && putOff * NekoTimerRetry < NekoTimerPatience) {
		putOff++;
		[ticking release];
		ticking = [[NSTimer scheduledTimerWithTimeInterval:NekoTimerRetry
		                                           target:self
		                                         selector:@selector(landed:)
		                                         userInfo:nil
		                                          repeats:NO] retain];
		[[NSRunLoop currentRunLoop] addTimer:ticking forMode:NSRunLoopCommonModes];
		return;
	}

	NSString *said = [NSString stringWithFormat:
		NekoTimerLocalized(@"The %@ are up."), [NekoWhen describe:asked]];
	[self cancel];
	[[NekoMemory sharedMemory] noteNoticed:said];
	[[NekoAsk sharedAsk] sayUnprompted:said];
}

- (BOOL)isRunning
{
	return ticking != nil && landsAt != nil;
}

- (NSTimeInterval)secondsLeft
{
	if(![self isRunning])
		return 0.0;
	NSTimeInterval left = [landsAt timeIntervalSinceNow];
	return left > 0.0 ? left : 0.0;
}

- (NSString *)menuTitle
{
	if(![self isRunning])
		return nil;
	NSTimeInterval left = [self secondsLeft];
	/* Under a minute it counts in seconds, above it in minutes: a menu that says
	   "0 minutes" for the last fifty-nine seconds is a menu that looks broken. */
	NSString *remaining = left < 60.0
		? [NekoWhen describe:(double)((int)left + 1)]
		: [NekoWhen describe:(double)(((int)left / 60) * 60)];
	return [NSString stringWithFormat:NekoTimerLocalized(@"Timer — %@ left"),
		remaining];
}

- (void)cancel
{
	[ticking invalidate];
	[ticking release];
	ticking = nil;
	[landsAt release];
	landsAt = nil;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:NekoTimerDidChangeNotification object:self];
}

@end
