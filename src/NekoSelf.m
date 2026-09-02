#import "NekoSelf.h"
#import "NekoController.h"
#import "MyPanel.h"
#import "NekoMemory.h"
#import "NekoWhen.h"
#import "NekoPlace.h"
#import "NekoAsk.h"

#define NekoSelfLocalized(key) NSLocalizedStringFromTable(key, @"Localizable", nil)

static NSLocale *NekoSelfLocale(void)
{
	NSString *code = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
	return [NSLocale localeWithLocaleIdentifier:code ?: @"en"];
}

/* Whichever of these the sentence contains. */
static BOOL NekoSelfAsks(NSString *text, NSArray *phrases)
{
	NSEnumerator *e = [phrases objectEnumerator];
	NSString *phrase;
	while((phrase = [e nextObject]) != nil)
		if([text rangeOfString:phrase].location != NSNotFound)
			return YES;
	return NO;
}

@implementation NekoSelf

#pragma mark Where it is

/* Nine parts of a screen, by thirds. The cat's own midpoint, not the pointer's
   and not the front window's: this is the one fact in the application that is
   about the cat and nothing else. */
+ (NSString *)whereItIs
{
	MyPanel *panel = [[NekoController sharedController] panel];
	if(panel == nil)
		return nil;

	NSRect frame = [panel frame];
	NSScreen *screen = [panel screen];
	if(screen == nil) {
		/* Between two displays, or on none: NekoDesktop.h has the long version of
		   why that is possible. The main screen is the honest fallback. */
		screen = [NSScreen mainScreen];
		if(screen == nil)
			return nil;
	}
	NSRect room = [screen visibleFrame];
	if(NSIsEmptyRect(room))
		return nil;

	double acrossThird = NSWidth(room) / 3.0;
	double upThird = NSHeight(room) / 3.0;
	int across = (int)floor((NSMidX(frame) - NSMinX(room)) / acrossThird);
	int up = (int)floor((NSMidY(frame) - NSMinY(room)) / upThird);
	across = across < 0 ? 0 : (across > 2 ? 2 : across);
	up = up < 0 ? 0 : (up > 2 ? 2 : up);

	static NSString * const parts[3][3] = {
		{ @"bottom left", @"at the bottom", @"bottom right" },
		{ @"on the left",  @"in the middle", @"on the right" },
		{ @"top left",     @"at the top",    @"top right" },
	};
	NSString *where = NekoSelfLocalized(parts[up][across]);

	/* The region phrase carries its own preposition and the frame carries none:
	   "I am %@ of your screen" reads well for "bottom left" and badly for
	   "at the bottom", and in Italian "in basso del tuo schermo" is simply
	   wrong. A frame with nothing after the placeholder works for all nine in
	   all four languages. */
	NSArray *screens = [NSScreen screens];
	if([screens count] < 2)
		return [NSString stringWithFormat:NekoSelfLocalized(@"I am %@."), where];

	NSUInteger which = [screens indexOfObject:screen];
	return [NSString stringWithFormat:
		NekoSelfLocalized(@"I am %@, on screen %ld."), where,
		(long)(which == NSNotFound ? 1 : which + 1)];
}

#pragma mark Where the Mac is

+ (NSString *)whereTheMacIs
{
	NekoPlace *place = [NekoPlace sharedPlace];

	/* Measured, if somebody asked for it to be. */
	NSString *town = [place town];
	if([town length] > 0)
		return [NSString stringWithFormat:
			NekoSelfLocalized(@"The Mac is in %@."), town];

	/* Deduced, and said as a deduction. The time zone gives a country and
	   nothing finer, so the sentence does not pretend to. */
	NSString *code = [place country];
	if([code length] == 0)
		return nil;
	NSString *named = [NekoSelfLocale() localizedStringForCountryCode:code];
	if([named length] == 0)
		named = code;
	return [NSString stringWithFormat:
		NekoSelfLocalized(@"The Mac is somewhere in %@."), named];
}

#pragma mark How long it has been here

+ (NSInteger)daysHere
{
	NSDate *met = [[NekoMemory sharedMemory] metOn];
	if(met == nil)
		return 0;
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *from = nil, *to = nil;
	[calendar rangeOfUnit:NSCalendarUnitDay startDate:&from interval:NULL forDate:met];
	[calendar rangeOfUnit:NSCalendarUnitDay startDate:&to interval:NULL
	              forDate:[NSDate date]];
	NSInteger days = [[calendar components:NSCalendarUnitDay fromDate:from
	                               toDate:to options:0] day];
	return days < 0 ? 0 : days;
}

+ (NSString *)howLongHere
{
	NSInteger days = [self daysHere];
	if(days <= 0)
		return NekoSelfLocalized(@"Since today.");

	NSDateFormatter *said = [[[NSDateFormatter alloc] init] autorelease];
	[said setLocale:NekoSelfLocale()];
	[said setDateFormat:days < 330 ? @"d MMMM" : @"d MMMM yyyy"];
	/* Two calls rather than positional specifiers: a format string that skips an
	   argument is the kind of thing that works until somebody translates it. */
	NSString *when = [said stringFromDate:[[NekoMemory sharedMemory] metOn]];
	if(days == 1)
		return [NSString stringWithFormat:
			NekoSelfLocalized(@"Since yesterday, %@."), when];
	return [NSString stringWithFormat:
		NekoSelfLocalized(@"%ld days, since %@."), (long)days, when];
}

#pragma mark How long since it was spoken to

+ (NSString *)howLongSinceHeard
{
	NSDate *last = [[NekoMemory sharedMemory] lastHeard];
	if(last == nil)
		return nil;
	NSTimeInterval ago = -[last timeIntervalSinceNow];
	if(ago < 60.0)
		return NekoSelfLocalized(@"A moment ago.");
	return [NSString stringWithFormat:NekoSelfLocalized(@"%@ ago."),
		[NekoWhen describe:ago]];
}

+ (NSString *)howLongSinceSpoke
{
	NSDate *last = [[NSUserDefaults standardUserDefaults]
		objectForKey:NekoLastUnpromptedKey];
	if(![last isKindOfClass:[NSDate class]])
		return nil;
	NSTimeInterval ago = -[last timeIntervalSinceNow];
	if(ago < 60.0)
		return NekoSelfLocalized(@"A moment ago.");
	return [NSString stringWithFormat:NekoSelfLocalized(@"%@ ago."),
		[NekoWhen describe:ago]];
}

#pragma mark

+ (NSString *)wantedFor:(NSString *)question
{
	NSString *text = [question lowercaseString];

	/* Where it is. "Dove sono le mie cartelle" is not this, which is why the
	   phrases carry the pronoun. */
	if(NekoSelfAsks(text, [NSArray arrayWithObjects:
			@"dove sei", @"dove ti trovi", @"tu dove sei", @"in che punto sei",
			@"su quale schermo sei", @"dove stai adesso",
			@"where are you", @"whereabouts are you", @"which screen are you on",
			@"où es-tu", @"ou es-tu", @"où te trouves-tu",
			@"dónde estás", @"donde estas", @"en qué pantalla estás", nil])) {
		/* Both halves, because "where are you" is two questions in one and a cat
		   that answered only the screen would be answering the smaller one. */
		NSString *onScreen = [self whereItIs];
		NSString *inTheWorld = [self whereTheMacIs];
		if(onScreen == nil)
			return inTheWorld;
		if(inTheWorld == nil)
			return onScreen;
		return [NSString stringWithFormat:@"%@ %@", onScreen, inTheWorld];
	}

	/* How long since they said anything. Before the next one, because "da quanto
	   non ci parliamo" and "da quanto sei qui" share their opening. */
	if(NekoSelfAsks(text, [NSArray arrayWithObjects:
			@"da quanto non ci parliamo", @"da quanto non parliamo",
			@"quando ci siamo parlati", @"da quanto non ti parlo",
			@"quando ti ho parlato", @"da quanto non mi parli",
			@"how long since we talked", @"how long since we spoke",
			@"when did we last talk", @"when did i last ask you",
			@"depuis quand ne parlons", @"quand nous sommes-nous parlé",
			@"cuánto hace que no hablamos", @"cuando hablamos", nil])) {
		NSString *ago = [self howLongSinceHeard];
		return ago ?: NekoSelfLocalized(@"This is the first thing you have asked me.");
	}

	/* And when it last said something of its own accord, which is the mirror of
	   the question above: one is about you, this one is about it. */
	if(NekoSelfAsks(text, [NSArray arrayWithObjects:
			@"quando hai parlato", @"quando hai detto qualcosa",
			@"da quanto non parli", @"quando hai parlato l'ultima volta",
			@"l'ultima volta che hai parlato",
			@"when did you last speak", @"when did you last say something",
			@"quand as-tu parlé", @"cuándo hablaste", nil])) {
		NSString *ago = [self howLongSinceSpoke];
		return ago ?: NekoSelfLocalized(@"I have not said anything yet.");
	}

	/* How long it has been here, which is also how long you have known it. */
	if(NekoSelfAsks(text, [NSArray arrayWithObjects:
			@"da quanto sei qui", @"da quanto tempo sei qui",
			@"da quanto ci conosciamo",
			@"da quanti giorni sei qui", @"da quanto stai qui",
			@"da quando ci conosciamo", @"quando ci siamo conosciuti",
			@"da quanto tempo ci conosciamo", @"da quanto vivi qui",
			@"how long have you been here", @"how long have you lived here",
			@"how long have we known each other", @"when did we meet",
			@"depuis quand es-tu là", @"depuis quand es-tu ici",
			@"depuis quand nous connaissons",
			@"cuánto llevas aquí", @"cuanto llevas aqui",
			@"desde cuándo nos conocemos", nil]))
		return [self howLongHere];

	return nil;
}

@end
