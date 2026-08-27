#import "NekoPlayer.h"

#define NekoPlayerLocalized(text) NSLocalizedString(text, nil)

NSString * const NekoPlayerPlay       = @"play";
NSString * const NekoPlayerPause      = @"pause";
NSString * const NekoPlayerPlayPause  = @"playpause";
NSString * const NekoPlayerNext       = @"next";
NSString * const NekoPlayerPrevious   = @"previous";
NSString * const NekoPlayerVolumeUp   = @"volumeup";
NSString * const NekoPlayerVolumeDown = @"volumedown";
NSString * const NekoPlayerPlayNamed  = @"playnamed";

/* Ten points a step. Measured against the two applications rather than chosen:
   both take a volume of 0 to 100, and a step of ten is four presses from half to
   full, which is what somebody saying "alza il volume" twice expects. */
static const int NekoVolumeStep = 10;

@implementation NekoPlayer

+ (NSArray *)players
{
	return [NSArray arrayWithObjects:@"music", @"spotify", nil];
}

+ (NSArray *)commands
{
	return [NSArray arrayWithObjects:
		NekoPlayerPlay, NekoPlayerPause, NekoPlayerPlayPause,
		NekoPlayerNext, NekoPlayerPrevious,
		NekoPlayerVolumeUp, NekoPlayerVolumeDown, NekoPlayerPlayNamed, nil];
}

+ (BOOL)knows:(NSString *)player
{
	return [[self players] containsObject:[player lowercaseString]];
}

+ (BOOL)knowsCommand:(NSString *)command
{
	return [[self commands] containsObject:[command lowercaseString]];
}

+ (NSString *)bundleIdentifierFor:(NSString *)player
{
	if([[player lowercaseString] isEqualToString:@"music"])
		return @"com.apple.Music";
	if([[player lowercaseString] isEqualToString:@"spotify"])
		return @"com.spotify.client";
	return nil;
}

/* The name AppleScript knows it by, which is not the name on the icon in every
   language and is not the bundle identifier either. */
+ (NSString *)scriptingNameFor:(NSString *)player
{
	return [[player lowercaseString] isEqualToString:@"music"] ? @"Music" : @"Spotify";
}

+ (NSString *)displayNameFor:(NSString *)player
{
	NSString *identifier = [self bundleIdentifierFor:player];
	NSURL *where = identifier != nil
		? [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:identifier]
		: nil;
	if(where == nil)
		return [self scriptingNameFor:player];
	NSString *name = [[NSFileManager defaultManager] displayNameAtPath:[where path]];
	return [name stringByDeletingPathExtension];
}

+ (BOOL)isInstalled:(NSString *)player
{
	NSString *identifier = [self bundleIdentifierFor:player];
	return identifier != nil
		&& [[NSWorkspace sharedWorkspace]
			URLForApplicationWithBundleIdentifier:identifier] != nil;
}

#pragma mark The scripts, which live here and nowhere else

/* One place, so that everything a plugin can cause is on one screen. The only
   thing that ever comes from outside is the argument of playnamed, and it is
   escaped for AppleScript before it goes anywhere near this. */
+ (NSString *)scriptFor:(NSString *)command
                     on:(NSString *)player
                   with:(NSString *)argument
{
	NSString *app = [self scriptingNameFor:player];
	BOOL music = [[player lowercaseString] isEqualToString:@"music"];

	if([command isEqualToString:NekoPlayerPlay])
		return [NSString stringWithFormat:@"tell application \"%@\" to play", app];
	if([command isEqualToString:NekoPlayerPause])
		return [NSString stringWithFormat:@"tell application \"%@\" to pause", app];
	if([command isEqualToString:NekoPlayerPlayPause])
		return [NSString stringWithFormat:@"tell application \"%@\" to playpause", app];
	if([command isEqualToString:NekoPlayerNext])
		return [NSString stringWithFormat:@"tell application \"%@\" to next track", app];
	if([command isEqualToString:NekoPlayerPrevious])
		return [NSString stringWithFormat:@"tell application \"%@\" to previous track", app];
	/* Written out rather than clamped in an expression: AppleScript has no min
	   and no max, which the first draft of this file assumed it did — and the
	   volume verbs answered "Musica would not do it" until a test asked what the
	   volume was before and after. */
	if([command isEqualToString:NekoPlayerVolumeUp])
		return [NSString stringWithFormat:
			@"tell application \"%@\"\n"
			 "  set v to (sound volume) + %d\n"
			 "  if v > 100 then set v to 100\n"
			 "  set sound volume to v\n"
			 "end tell", app, NekoVolumeStep];
	if([command isEqualToString:NekoPlayerVolumeDown])
		return [NSString stringWithFormat:
			@"tell application \"%@\"\n"
			 "  set v to (sound volume) - %d\n"
			 "  if v < 0 then set v to 0\n"
			 "  set sound volume to v\n"
			 "end tell", app, NekoVolumeStep];

	if([command isEqualToString:NekoPlayerPlayNamed]) {
		if(!music)
			return nil;      /* Spotify's dictionary cannot search; see perform: */
		/* Your own library, which is the only thing Music's dictionary can look
		   in: the streaming catalogue is not scriptable, and this does not pretend
		   otherwise. Artist first, then title, so "metti Battisti" finds the
		   artist rather than a song with his name in the title. */
		return [NSString stringWithFormat:
			@"tell application \"Music\"\n"
			 "  set found to (every track of library playlist 1 whose artist contains \"%@\")\n"
			 "  if (count of found) is 0 then\n"
			 "    set found to (every track of library playlist 1 whose name contains \"%@\")\n"
			 "  end if\n"
			 "  if (count of found) is 0 then return \"none\"\n"
			 "  play (item 1 of found)\n"
			 "  return \"playing\"\n"
			 "end tell", argument, argument];
	}
	return nil;
}

/* AppleScript string literals take a backslash and a double quote the way C does,
   and nothing else needs escaping inside one. A newline would end the literal, so
   it goes too. */
+ (NSString *)escaped:(NSString *)text
{
	NSMutableString *safe = [NSMutableString stringWithString:text ?: @""];
	[safe replaceOccurrencesOfString:@"\\" withString:@"\\\\"
	                        options:0 range:NSMakeRange(0, [safe length])];
	[safe replaceOccurrencesOfString:@"\"" withString:@"\\\""
	                        options:0 range:NSMakeRange(0, [safe length])];
	[safe replaceOccurrencesOfString:@"\n" withString:@" "
	                        options:0 range:NSMakeRange(0, [safe length])];
	[safe replaceOccurrencesOfString:@"\r" withString:@" "
	                        options:0 range:NSMakeRange(0, [safe length])];
	return safe;
}

#pragma mark Doing it

+ (BOOL)perform:(NSString *)command
             on:(NSString *)player
           with:(NSString *)argument
         saying:(NSString **)problem
{
	if(![self knows:player] || ![self knowsCommand:command])
		return NO;

	if(![self isInstalled:player]) {
		if(problem != NULL)
			*problem = [NSString stringWithFormat:
				NekoPlayerLocalized(@"%@ is not on this Mac."),
				[self displayNameFor:player]];
		return NO;
	}

	if([command isEqualToString:NekoPlayerPlayNamed]
	   && ![[player lowercaseString] isEqualToString:@"music"]) {
		if(problem != NULL)
			*problem = [NSString stringWithFormat:
				NekoPlayerLocalized(@"%@ does not let anything else search it; only its own window can."),
				[self displayNameFor:player]];
		return NO;
	}

	NSString *source = [self scriptFor:command on:player
	                              with:[self escaped:argument]];
	if(source == nil)
		return NO;

	NSDictionary *trouble = nil;
	NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:source] autorelease];
	NSAppleEventDescriptor *answer = [script executeAndReturnError:&trouble];

	if(answer == nil) {
		NSInteger code = [[trouble objectForKey:NSAppleScriptErrorNumber] integerValue];
		if(problem != NULL) {
			/* -1743 is macOS saying the person has not allowed this, and it is the
			   only failure here they can do something about. */
			*problem = (code == -1743)
				? [NSString stringWithFormat:
					NekoPlayerLocalized(@"macOS will not let me control %@ until you allow it in Privacy & Security, under Automation."),
					[self displayNameFor:player]]
				: [NSString stringWithFormat:
					NekoPlayerLocalized(@"%@ would not do it."),
					[self displayNameFor:player]];
		}
		return NO;
	}

	if([command isEqualToString:NekoPlayerPlayNamed]
	   && [[answer stringValue] isEqualToString:@"none"]) {
		if(problem != NULL)
			*problem = [NSString stringWithFormat:
				NekoPlayerLocalized(@"There is nothing by “%@” in your library."), argument];
		return NO;
	}
	return YES;
}

#pragma mark Being allowed to

/* Asked without asking. The obvious way to find out whether macOS will allow this
   is to try something and see — and that is wrong here, because trying is what
   brings the prompt up: merely opening the Permissions tab would have asked the
   person to allow controlling Music, which is not a thing a window should do by
   being looked at. (It also reached the run loop mid-build and drew the tab's
   footer twice; the layout harness caught that.)

   AEDeterminePermissionToAutomateTarget with askUserIfNeeded NO answers from the
   database instead: allowed, refused, or never asked. */
+ (NekoPlayerConsent)consentFor:(NSString *)player
{
	NSString *identifier = [self bundleIdentifierFor:player];
	if(identifier == nil || ![self isInstalled:player])
		return NekoPlayerConsentImpossible;

	AEAddressDesc target;
	const char *bytes = [identifier UTF8String];
	OSStatus made = AECreateDesc(typeApplicationBundleID, bytes,
		strlen(bytes), &target);
	if(made != noErr)
		return NekoPlayerConsentUnknown;

	OSStatus answer = AEDeterminePermissionToAutomateTarget(&target,
		typeWildCard, typeWildCard, NO);
	AEDisposeDesc(&target);

	switch(answer) {
		case noErr:                                return NekoPlayerConsentGiven;
		case errAEEventNotPermitted:               return NekoPlayerConsentRefused;
		case errAEEventWouldRequireUserConsent:    return NekoPlayerConsentUnknown;
		default:                                   return NekoPlayerConsentUnknown;
	}
}

+ (BOOL)mayControl:(NSString *)player
{
	return [self consentFor:player] == NekoPlayerConsentGiven;
}

+ (void)askToControl:(NSString *)player
{
	/* Here, and only here, the prompt is wanted: somebody pressed a button for
	   it. The smallest harmless question either application answers is what its
	   volume is. */
	if(![self isInstalled:player])
		return;
	NSString *source = [NSString stringWithFormat:
		@"tell application \"%@\" to return sound volume as text",
		[self scriptingNameFor:player]];
	NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:source] autorelease];
	(void)[script executeAndReturnError:NULL];
}

@end
