#import "NekoAction.h"
#import "NekoAnswerProvider.h"

NSString * const NekoActionsEnabledKey = @"NekoActionsEnabled";

#define NekoActionLocalized(text) NSLocalizedString(text, nil)

static NSString * const NekoActionMarker = @"ACTION:";

@implementation NekoAction

+ (BOOL)looksLikeAnAction:(NSString *)line
{
	NSString *trimmed = [line stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return [[trimmed uppercaseString] hasPrefix:NekoActionMarker];
}

#pragma mark Finding what was named

/* "photoshop" is not what the bundle is called: it is "Adobe Photoshop 2025".
   Everything installed is looked at once and the closest name that contains
   what was asked for wins, shortest first so "Safari" does not lose to
   "Safari Technology Preview". */
+ (NSURL *)applicationNamed:(NSString *)name
{
	if([name length] == 0)
		return nil;

	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSString *direct = [workspace fullPathForApplication:name];
	if(direct != nil)
		return [NSURL fileURLWithPath:direct];

	NSArray *folders = [NSArray arrayWithObjects:@"/Applications",
		@"/Applications/Utilities", @"/System/Applications",
		@"/System/Applications/Utilities",
		[NSHomeDirectory() stringByAppendingPathComponent:@"Applications"], nil];
	NSFileManager *files = [NSFileManager defaultManager];
	NSString *wanted = [name lowercaseString];
	NSString *best = nil;

	NSEnumerator *e = [folders objectEnumerator];
	NSString *folder;
	while((folder = [e nextObject]) != nil) {
		NSEnumerator *inside = [[files contentsOfDirectoryAtPath:folder error:NULL]
			objectEnumerator];
		NSString *entry;
		while((entry = [inside nextObject]) != nil) {
			if(![[entry pathExtension] isEqualToString:@"app"])
				continue;
			NSString *path = [folder stringByAppendingPathComponent:entry];
			/* Both names: the bundle on disk is Preview.app and the Finder calls
			   it Anteprima, and someone speaking Italian will say the second. */
			NSString *plain = [[entry stringByDeletingPathExtension] lowercaseString];
			NSString *shown = [[[files displayNameAtPath:path]
				stringByDeletingPathExtension] lowercaseString];
			BOOL matches = [plain rangeOfString:wanted].location != NSNotFound
			            || [wanted rangeOfString:plain].location != NSNotFound
			            || ([shown length] > 0
			                && ([shown rangeOfString:wanted].location != NSNotFound
			                    || [wanted rangeOfString:shown].location != NSNotFound));
			if(!matches)
				continue;
			if(best == nil || [entry length] < [[best lastPathComponent] length])
				best = path;
		}
	}
	return best != nil ? [NSURL fileURLWithPath:best] : nil;
}

+ (NSURL *)folderNamed:(NSString *)name
{
	NSDictionary *known = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedInteger:NSDesktopDirectory], @"desktop",
		[NSNumber numberWithUnsignedInteger:NSDocumentDirectory], @"documents",
		[NSNumber numberWithUnsignedInteger:NSDownloadsDirectory], @"downloads",
		[NSNumber numberWithUnsignedInteger:NSMoviesDirectory], @"movies",
		[NSNumber numberWithUnsignedInteger:NSMusicDirectory], @"music",
		[NSNumber numberWithUnsignedInteger:NSPicturesDirectory], @"pictures", nil];
	NSNumber *which = [known objectForKey:[name lowercaseString]];
	if(which == nil)
		return nil;
	/* The real folder, not the sandbox's copy: this is handed to LaunchServices
	   to open in the Finder, which is allowed even where reading is not. */
	NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
		[[name lowercaseString] capitalizedString]];
	NSArray *inside = NSSearchPathForDirectoriesInDomains(
		[which unsignedIntegerValue], NSUserDomainMask, YES);
	if([inside count] > 0)
		path = [inside firstObject];
	return [NSURL fileURLWithPath:path];
}

#pragma mark Reading the line

+ (NekoAction *)actionFromLine:(NSString *)line
{
	if(![self looksLikeAnAction:line])
		return nil;

	NSString *body = [line stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSRange colon = [body rangeOfString:@":"];
	if(colon.location == NSNotFound)
		return nil;
	body = [[body substringFromIndex:NSMaxRange(colon)]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSRange newline = [body rangeOfString:@"\n"];
	if(newline.location != NSNotFound)
		body = [body substringToIndex:newline.location];

	NSRange space = [body rangeOfString:@" "];
	if(space.location == NSNotFound)
		return nil;
	NSString *word = [[body substringToIndex:space.location] lowercaseString];
	NSString *rest = [[body substringFromIndex:NSMaxRange(space)]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if([rest length] == 0)
		return nil;

	NekoAction *action = [[[NekoAction alloc] init] autorelease];
	action->verb = [word retain];

	if([word isEqualToString:@"open-app"]) {
		action->resolved = [[NekoAction applicationNamed:rest] retain];
		action->target = [rest retain];
		return action->resolved != nil ? action : nil;
	}
	if([word isEqualToString:@"open-url"]) {
		NSString *address = rest;
		/* "in Chrome" at the end names the browser. */
		NSRange in = [[rest lowercaseString] rangeOfString:@" in "
		                                          options:NSBackwardsSearch];
		if(in.location != NSNotFound) {
			address = [[rest substringToIndex:in.location]
				stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			NSString *browser = [[rest substringFromIndex:NSMaxRange(in)]
				stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			action->resolved = [[NekoAction applicationNamed:browser] retain];
			action->extra = [browser retain];
			if(action->resolved == nil)
				return nil;
		}
		if([address rangeOfString:@"://"].location == NSNotFound)
			address = [@"https://" stringByAppendingString:address];
		NSURL *url = [NSURL URLWithString:address];
		NSString *scheme = [[url scheme] lowercaseString];
		/* Only the two schemes anyone means when they say "open": no file://,
		   no custom scheme a model has invented. */
		if(url == nil || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]))
			return nil;
		action->target = [[url absoluteString] retain];
		return action;
	}
	if([word isEqualToString:@"open-folder"]) {
		action->resolved = [[NekoAction folderNamed:rest] retain];
		action->target = [rest retain];
		return action->resolved != nil ? action : nil;
	}
	if([word isEqualToString:@"run-shortcut"]) {
		action->target = [rest retain];
		return action;
	}
	return nil;                     /* an unknown verb is refused, not guessed */
}

- (void)dealloc
{
	[verb release];
	[target release];
	[extra release];
	[resolved release];
	[super dealloc];
}

- (NSString *)verb { return verb; }
- (NSString *)target { return target; }

- (NSString *)summary
{
	if([verb isEqualToString:@"open-app"])
		return [NSString stringWithFormat:NekoActionLocalized(@"Open %@?"),
			[[[resolved lastPathComponent] stringByDeletingPathExtension] ?: target
				stringByReplacingOccurrencesOfString:@".app" withString:@""]];
	if([verb isEqualToString:@"open-url"])
		return extra != nil
			? [NSString stringWithFormat:NekoActionLocalized(@"Open %@ in %@?"), target, extra]
			: [NSString stringWithFormat:NekoActionLocalized(@"Open %@?"), target];
	if([verb isEqualToString:@"open-folder"]) {
		/* The Finder's own name for it, so an Italian is asked about "Documenti"
		   rather than about the English word the model happened to write. */
		NSString *shown = [[NSFileManager defaultManager] displayNameAtPath:[resolved path]];
		return [NSString stringWithFormat:NekoActionLocalized(@"Open the %@ folder?"),
			[shown length] > 0 ? shown : target];
	}
	if([verb isEqualToString:@"run-shortcut"])
		return [NSString stringWithFormat:NekoActionLocalized(@"Run your shortcut “%@”?"), target];
	return nil;
}

#pragma mark Doing it

- (BOOL)perform:(NSError **)error
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];

	if([verb isEqualToString:@"open-app"] || [verb isEqualToString:@"open-folder"])
		return [workspace openURL:resolved];

	if([verb isEqualToString:@"open-url"]) {
		NSURL *url = [NSURL URLWithString:target];
		if(resolved == nil)
			return [workspace openURL:url];
		return [workspace openURLs:[NSArray arrayWithObject:url]
		      withApplicationAtURL:resolved
		                   options:NSWorkspaceLaunchDefault
		             configuration:[NSDictionary dictionary]
		                     error:error] != nil;
	}

	if([verb isEqualToString:@"run-shortcut"]) {
		NSTask *task = [[[NSTask alloc] init] autorelease];
		[task setLaunchPath:@"/usr/bin/shortcuts"];
		[task setArguments:[NSArray arrayWithObjects:@"run", target, nil]];
		NS_DURING
			[task launch];
		NS_HANDLER
			if(error != NULL)
				*error = [NSError errorWithDomain:NekoAskErrorDomain
				                             code:NekoAskErrorTransport
				                         userInfo:nil];
			return NO;
		NS_ENDHANDLER
		return YES;
	}
	return NO;
}

@end
