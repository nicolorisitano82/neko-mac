#import "NekoFolderAccess.h"

/* One default per folder, holding the bookmark. */
static NSString *NekoBookmarkKeyFor(NSString *key)
{
	return [@"NekoFolder-" stringByAppendingString:key];
}

@implementation NekoFolderAccess

+ (NekoFolderAccess *)sharedAccess
{
	static NekoFolderAccess *shared = nil;
	if(shared == nil)
		shared = [[NekoFolderAccess alloc] init];
	return shared;
}

+ (NSArray *)folderKeys
{
	return [NSArray arrayWithObjects:@"desktop", @"documents", @"downloads",
		@"pictures", @"music", @"movies", nil];
}

+ (BOOL)isFolderKey:(NSString *)key
{
	return [[self folderKeys] containsObject:[key lowercaseString]];
}

/* Where the folder is for a person, which is not where it is for the sandbox:
   the container has its own empty Desktop, and that is never what anyone means. */
- (NSURL *)realFolderFor:(NSString *)key
{
	NSDictionary *names = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Desktop", @"desktop", @"Documents", @"documents",
		@"Downloads", @"downloads", @"Pictures", @"pictures",
		@"Music", @"music", @"Movies", @"movies", nil];
	NSString *name = [names objectForKey:[key lowercaseString]];
	if(name == nil)
		return nil;
	/* NSHomeDirectory is the container inside the sandbox, so the real home is
	   taken from the login name instead. */
	NSString *home = [@"/Users" stringByAppendingPathComponent:NSUserName()];
	return [NSURL fileURLWithPath:[home stringByAppendingPathComponent:name]];
}

- (NSString *)displayNameFor:(NSString *)key
{
	NSURL *folder = [self realFolderFor:key];
	NSString *shown = folder != nil
		? [[NSFileManager defaultManager] displayNameAtPath:[folder path]] : nil;
	return [shown length] > 0 ? shown : key;
}

#pragma mark Remembering

- (NSURL *)resolveBookmarkFor:(NSString *)key stale:(BOOL *)stale
{
	NSData *bookmark = [[NSUserDefaults standardUserDefaults]
		dataForKey:NekoBookmarkKeyFor(key)];
	if(bookmark == nil)
		return nil;
	BOOL wasStale = NO;
	NSError *problem = nil;
	NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
	                                       options:NSURLBookmarkResolutionWithSecurityScope
	                                 relativeToURL:nil
	                           bookmarkDataIsStale:&wasStale
	                                         error:&problem];
	if(stale != NULL)
		*stale = wasStale;
	return url;
}

- (BOOL)hasAccessTo:(NSString *)key
{
	return [self resolveBookmarkFor:key stale:NULL] != nil;
}

- (NSArray *)allowedKeys
{
	NSMutableArray *allowed = [NSMutableArray array];
	NSEnumerator *e = [[NekoFolderAccess folderKeys] objectEnumerator];
	NSString *key;
	while((key = [e nextObject]) != nil)
		if([self hasAccessTo:key])
			[allowed addObject:key];
	return allowed;
}

- (void)forget:(NSString *)key
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:NekoBookmarkKeyFor(key)];
}

#pragma mark Asking

- (NSString *)refusalForChoosing:(NSURL *)chosen insteadOf:(NSString *)key
{
	NSURL *folder = [self realFolderFor:key];
	if(chosen == nil || folder == nil)
		return NSLocalizedString(@"Nothing was chosen.", nil);
	if([[[chosen path] lastPathComponent] isEqualToString:[[folder path] lastPathComponent]])
		return nil;
	return [NSString stringWithFormat:
		NSLocalizedString(@"That is “%@”, and I asked for your %@ folder. I can only be given the one I asked for.", nil),
		[[NSFileManager defaultManager] displayNameAtPath:[chosen path]],
		[self displayNameFor:key]];
}

- (BOOL)requestAccessTo:(NSString *)key
{
	return [self requestAccessTo:key saying:NULL];
}

- (BOOL)requestAccessTo:(NSString *)key saying:(NSString **)problem
{
	if(problem != NULL)
		*problem = nil;
	if(![NekoFolderAccess isFolderKey:key])
		return NO;
	if([self hasAccessTo:key])
		return YES;

	NSURL *folder = [self realFolderFor:key];
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setAllowsMultipleSelection:NO];
	[panel setCanCreateDirectories:NO];
	[panel setDirectoryURL:folder];
	[panel setPrompt:NSLocalizedString(@"Allow", nil)];
	[panel setMessage:[NSString stringWithFormat:
		NSLocalizedString(@"Choose your %@ folder so Neko can work in it. It is the only way in: nothing else can grant this.", nil),
		[self displayNameFor:key]]];

	[NSApp activateIgnoringOtherApps:YES];
	if([panel runModal] != NSModalResponseOK)
		return NO;

	NSURL *chosen = [[panel URLs] firstObject];
	/* The panel is where the sandbox hands over a folder, but it hands over
	   whichever one was picked: a Documents bookmark stored under "desktop"
	   would be a lie the rest of the code would believe. Said out loud rather
	   than refused quietly — from where somebody is standing, a folder chosen and
	   then ignored is the application doing nothing. */
	NSString *wrongOne = [self refusalForChoosing:chosen insteadOf:key];
	if(wrongOne != nil) {
		if(problem != NULL)
			*problem = wrongOne;
		return NO;
	}

	NSError *failure = nil;
	NSData *bookmark = [chosen bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
	            includingResourceValuesForKeys:nil
	                             relativeToURL:nil
	                                     error:&failure];
	if(bookmark == nil) {
		if(problem != NULL)
			*problem = [NSString stringWithFormat:
				NSLocalizedString(@"macOS did not hand your %@ folder over: %@", nil),
				[self displayNameFor:key],
				[failure localizedDescription] ?: NSLocalizedString(@"no reason given", nil)];
		return NO;
	}
	[[NSUserDefaults standardUserDefaults] setObject:bookmark
	                                          forKey:NekoBookmarkKeyFor(key)];
	return YES;
}

#pragma mark Using

- (NSURL *)beginUsing:(NSString *)key
{
	BOOL stale = NO;
	NSURL *url = [self resolveBookmarkFor:key stale:&stale];
	if(url == nil)
		return nil;
	if(stale)
		[self forget:key];        /* it will be asked for again, honestly */
	return [url startAccessingSecurityScopedResource] ? url : nil;
}

- (void)doneWith:(NSURL *)url
{
	[url stopAccessingSecurityScopedResource];
}

@end
