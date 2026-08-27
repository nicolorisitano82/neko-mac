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

	NSArray *known = [NSArray arrayWithObjects:@"Feeds", @"Text", nil];
	NSEnumerator *e = [extends keyEnumerator];
	NSString *key;
	while((key = [e nextObject]) != nil)
		if(![known containsObject:key]) {
			[self refuse:[NSString stringWithFormat:
				NekoPluginLocalized(@"It extends “%@”, which this version of Neko does not offer yet."), key]];
			return;
		}

	[self checkFeeds:[extends objectForKey:@"Feeds"]];
	[self checkText:[extends objectForKey:@"Text"]];
}

/* Text processing: the plugin is handed what somebody said, or what the cat is
   about to say, and hands something back.

   It is done by running one of the user's own Shortcuts, which is the whole of
   why it is allowed at all: the Shortcut is theirs, they wrote it or installed
   it, and nothing new runs inside this app. A plugin names a Shortcut; it cannot
   name a program. */
- (void)checkText:(NSDictionary *)text
{
	if(text == nil)
		return;
	if(![text isKindOfClass:[NSDictionary class]]) {
		[self refuse:NekoPluginLocalized(@"Its Text section is not a dictionary.")];
		return;
	}

	NSString *shortcut = [text objectForKey:@"Shortcut"];
	if([shortcut length] == 0) {
		[self refuse:NekoPluginLocalized(@"It processes text without naming a Shortcut to do it with.")];
		return;
	}
	if([text objectForKey:@"Program"] != nil || [text objectForKey:@"Executable"] != nil) {
		[self refuse:NekoPluginLocalized(@"It wants to process text with a program of its own, which this version does not allow — only one of your own Shortcuts.")];
		return;
	}

	NSString *direction = [[text objectForKey:@"Direction"] lowercaseString];
	NSArray *allowed = [NSArray arrayWithObjects:@"in", @"out", @"both", nil];
	if(![allowed containsObject:direction ?: @""]) {
		[self refuse:NekoPluginLocalized(@"Its Text section has to say Direction: in, out or both.")];
		return;
	}
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
	if(![feeds isKindOfClass:[NSArray class]])
		return [NSArray array];

	/* A detail is looked up as a string key before it is used. For the plugin
	   that ships with the app that means its descriptions stay translated —
	   they are the same keys the code used to hold — and for anybody else's
	   plugin the string simply passes through, which is right: the app has no
	   translations for words it has never seen. */
	NSMutableArray *localized = [NSMutableArray array];
	NSEnumerator *e = [feeds objectEnumerator];
	NSDictionary *feed;
	while((feed = [e nextObject]) != nil) {
		NSMutableDictionary *one = [NSMutableDictionary dictionaryWithDictionary:feed];
		NSString *detail = [feed objectForKey:@"Detail"];
		if([detail length] > 0)
			[one setObject:NSLocalizedString(detail, nil) forKey:@"Detail"];
		[localized addObject:one];
	}
	return localized;
}

- (NSDictionary *)text
{
	if(![self isUsable])
		return nil;
	NSDictionary *text = [[manifest objectForKey:@"Extends"] objectForKey:@"Text"];
	return [text isKindOfClass:[NSDictionary class]] ? text : nil;
}

- (NSString *)textShortcut
{
	return [[self text] objectForKey:@"Shortcut"];
}

- (BOOL)processesTextGoing:(BOOL)inward
{
	NSString *direction = [[[self text] objectForKey:@"Direction"] lowercaseString];
	if([direction isEqualToString:@"both"])
		return YES;
	return [direction isEqualToString:(inward ? @"in" : @"out")];
}

- (NSString *)describeWhatItAdds
{
	NSMutableArray *parts = [NSMutableArray array];
	NSUInteger feeds = [[self feeds] count];
	if(feeds == 1)
		[parts addObject:NekoPluginLocalized(@"1 feed")];
	else if(feeds > 1)
		[parts addObject:[NSString stringWithFormat:
			NekoPluginLocalized(@"%lu feeds"), (unsigned long)feeds]];

	if([self text] != nil) {
		NSString *which = [self processesTextGoing:YES]
			? ([self processesTextGoing:NO]
				? NekoPluginLocalized(@"what you say and what it answers")
				: NekoPluginLocalized(@"what you say"))
			: NekoPluginLocalized(@"what it answers");
		[parts addObject:[NSString stringWithFormat:
			NekoPluginLocalized(@"passes %@ through your Shortcut “%@”"),
			which, [self textShortcut]]];
	}

	if([parts count] == 0)
		return NekoPluginLocalized(@"nothing this version of Neko can use yet");
	return [parts componentsJoinedByString:NekoPluginLocalized(@", and ")];
}

@end
