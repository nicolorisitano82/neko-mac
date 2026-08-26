#import "NekoPlugin.h"

const NSInteger NekoPluginInterface = 1;

#define NekoPluginLocalized(text) NSLocalizedString(text, nil)

/* A plugin may not smuggle a marker into anything the app shows or hands to a
   model: those three words are how this app's own code says "do something", and
   they belong to the app. */
static NSString * const NekoPluginMarkers[] = { @"ACTION:", @"IMAGE:", @"LOOK:", nil };

@implementation NekoPlugin

- (id)initWithFolder:(NSURL *)aFolder
{
	if((self = [super init]) != nil) {
		folder = [aFolder retain];
		[self read];
	}
	return self;
}

- (void)dealloc
{
	[folder release];
	[manifest release];
	[refusal release];
	[super dealloc];
}

- (NSURL *)folder     { return folder; }
- (NSString *)refusal { return refusal; }
- (BOOL)isUsable      { return refusal == nil; }

- (NSString *)identifier
{
	return [manifest objectForKey:@"Identifier"]
		?: [[folder lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)name
{
	return [manifest objectForKey:@"Name"] ?: [self identifier];
}

- (NSString *)version { return [manifest objectForKey:@"Version"] ?: @"?"; }
- (NSString *)author  { return [manifest objectForKey:@"Author"] ?: @""; }
- (NSString *)summary { return [manifest objectForKey:@"Summary"] ?: @""; }

- (BOOL)wantsNetwork
{
	NSArray *wants = [manifest objectForKey:@"Wants"];
	return [wants isKindOfClass:[NSArray class]]
		&& [wants containsObject:@"network"];
}

#pragma mark Reading it

/* Every refusal is a sentence somebody can act on, not a code. The panel shows
   it under the plugin's name and the plugin stays in the list: a plugin that
   vanished on being refused would be a plugin nobody could fix. */
- (void)refuse:(NSString *)why
{
	if(refusal != nil)
		return;                  /* the first reason is the useful one */
	refusal = [why copy];
}

- (BOOL)carriesAMarker:(NSString *)text
{
	NSUInteger i;
	for(i = 0; NekoPluginMarkers[i] != nil; i++)
		if([[text uppercaseString] rangeOfString:NekoPluginMarkers[i]].location != NSNotFound)
			return YES;
	return NO;
}

- (void)read
{
	NSURL *plist = [folder URLByAppendingPathComponent:@"plugin.plist"];
	NSDictionary *read = [NSDictionary dictionaryWithContentsOfURL:plist];
	if(![read isKindOfClass:[NSDictionary class]]) {
		[self refuse:NekoPluginLocalized(@"There is no readable plugin.plist inside it.")];
		return;
	}
	manifest = [read retain];

	NSString *identifier = [manifest objectForKey:@"Identifier"];
	if([identifier length] == 0 || [identifier rangeOfString:@"."].location == NSNotFound) {
		[self refuse:NekoPluginLocalized(@"Its Identifier is missing or is not of the form com.example.thing.")];
		return;
	}
	if([[manifest objectForKey:@"Name"] length] == 0) {
		[self refuse:NekoPluginLocalized(@"It has no Name to show.")];
		return;
	}

	NSInteger declared = [[manifest objectForKey:@"Interface"] integerValue];
	if(declared <= 0) {
		[self refuse:NekoPluginLocalized(@"It does not say which plugin interface it was written for.")];
		return;
	}
	if(declared > NekoPluginInterface) {
		[self refuse:[NSString stringWithFormat:
			NekoPluginLocalized(@"It was written for a newer version of Neko’s plugin interface (%ld; this one understands %ld)."),
			(long)declared, (long)NekoPluginInterface]];
		return;
	}

	NSString *minimum = [manifest objectForKey:@"MinimumApp"];
	NSString *ours = [[[NSBundle mainBundle] infoDictionary]
		objectForKey:@"CFBundleShortVersionString"] ?: @"0";
	if([minimum length] > 0
	   && [ours compare:minimum options:NSNumericSearch] == NSOrderedAscending) {
		[self refuse:[NSString stringWithFormat:
			NekoPluginLocalized(@"It needs Neko %@ or newer, and this is %@."), minimum, ours]];
		return;
	}

	if([self carriesAMarker:[self summary]]) {
		[self refuse:NekoPluginLocalized(@"Its summary contains one of Neko’s own markers, which a plugin may not write.")];
		return;
	}

	[self readExtensions];
}

/* Only the keys this interface knows about. An unknown one is refused rather
   than ignored: ignoring it would mean the plugin believes it is doing something
   it is not. */
- (void)readExtensions
{
	NSDictionary *extends = [manifest objectForKey:@"Extends"];
	if(extends != nil && ![extends isKindOfClass:[NSDictionary class]]) {
		[self refuse:NekoPluginLocalized(@"Its Extends section is not a dictionary.")];
		return;
	}

	NSArray *known = [NSArray arrayWithObjects:@"Feeds", nil];
	NSEnumerator *e = [extends keyEnumerator];
	NSString *key;
	while((key = [e nextObject]) != nil)
		if(![known containsObject:key]) {
			[self refuse:[NSString stringWithFormat:
				NekoPluginLocalized(@"It extends “%@”, which this version of Neko does not offer yet."), key]];
			return;
		}

	[self checkFeeds:[extends objectForKey:@"Feeds"]];
}

- (void)checkFeeds:(NSArray *)feeds
{
	if(feeds == nil)
		return;
	if(![feeds isKindOfClass:[NSArray class]]) {
		[self refuse:NekoPluginLocalized(@"Its Feeds section is not a list.")];
		return;
	}
	if(![self wantsNetwork]) {
		[self refuse:NekoPluginLocalized(@"It adds feeds without asking for the network, so nothing could be fetched.")];
		return;
	}

	NSEnumerator *e = [feeds objectEnumerator];
	NSDictionary *feed;
	while((feed = [e nextObject]) != nil) {
		if(![feed isKindOfClass:[NSDictionary class]]) {
			[self refuse:NekoPluginLocalized(@"One of its feeds is not a dictionary.")];
			return;
		}
		NSString *word = [feed objectForKey:@"Identifier"];
		NSString *address = [feed objectForKey:@"Address"];
		if([word length] == 0 || [[feed objectForKey:@"Name"] length] == 0) {
			[self refuse:NekoPluginLocalized(@"One of its feeds has no Identifier or no Name.")];
			return;
		}
		/* The word a question is matched against, and one the app already uses
		   would quietly shadow a built-in source. */
		if([word rangeOfCharacterFromSet:
				[[NSCharacterSet alphanumericCharacterSet] invertedSet]].location != NSNotFound) {
			[self refuse:[NSString stringWithFormat:
				NekoPluginLocalized(@"The feed word “%@” has punctuation or spaces in it; it has to be one plain word."), word]];
			return;
		}
		if(![[address lowercaseString] hasPrefix:@"https://"]) {
			[self refuse:[NSString stringWithFormat:
				NekoPluginLocalized(@"The feed “%@” is not an https address."), word]];
			return;
		}
		if([self carriesAMarker:[feed objectForKey:@"Name"]]
		   || [self carriesAMarker:([feed objectForKey:@"Detail"] ?: @"")]) {
			[self refuse:NekoPluginLocalized(@"One of its feeds carries one of Neko’s own markers in its name.")];
			return;
		}
	}
}

- (NSArray *)feeds
{
	if(![self isUsable])
		return [NSArray array];
	NSArray *feeds = [[manifest objectForKey:@"Extends"] objectForKey:@"Feeds"];
	return [feeds isKindOfClass:[NSArray class]] ? feeds : [NSArray array];
}

- (NSString *)describeWhatItAdds
{
	NSUInteger feeds = [[self feeds] count];
	if(feeds == 0)
		return NekoPluginLocalized(@"nothing this version of Neko can use yet");
	if(feeds == 1)
		return NekoPluginLocalized(@"1 feed");
	return [NSString stringWithFormat:NekoPluginLocalized(@"%lu feeds"),
		(unsigned long)feeds];
}

@end
