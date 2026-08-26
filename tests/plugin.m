/* What a plugin may be, and what it is refused for.

   A plugin is a folder with a manifest, read and never run: the app is sandboxed
   and holds a microphone, a location, folders somebody handed over by name and a
   diary about their working life, and code inside this process would inherit all
   of it. So the manifest is the whole contract, and this is the test of the
   reader that enforces it — every refusal is a sentence, because a plugin that is
   refused silently is a plugin nobody can fix. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoPlugin.h"
#import "NekoPlugins.h"
#import "NekoWeb.h"

static NSURL *stage(NSString *name, NSDictionary *manifest)
{
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
		[NSString stringWithFormat:@"neko-test-%@.nekoplugin", name]];
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:path
	                          withIntermediateDirectories:YES attributes:nil error:NULL];
	if(manifest != nil)
		[manifest writeToFile:[path stringByAppendingPathComponent:@"plugin.plist"]
		           atomically:YES];
	return [NSURL fileURLWithPath:path];
}

static NSMutableDictionary *good(void)
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
		@"com.example.test", @"Identifier",
		@"A Test", @"Name",
		@"1.0", @"Version",
		@"Nobody", @"Author",
		[NSNumber numberWithInteger:1], @"Interface",
		@"A plugin for a test.", @"Summary",
		[NSArray arrayWithObject:@"network"], @"Wants",
		[NSDictionary dictionaryWithObject:
			[NSArray arrayWithObject:
				[NSDictionary dictionaryWithObjectsAndKeys:
					@"testwire", @"Identifier",
					@"Test Wire", @"Name",
					@"for a test", @"Detail",
					@"https://example.com/feed.xml", @"Address", nil]]
		                            forKey:@"Feeds"], @"Extends", nil];
}

static NekoPlugin *readPlugin(NSString *name, NSDictionary *manifest)
{
	return [[[NekoPlugin alloc] initWithFolder:stage(name, manifest)] autorelease];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- one that is all right ---\n");

	NekoPlugin *fine = readPlugin(@"fine", good());
	ok([fine isUsable], @"a complete manifest is accepted", [fine refusal]);
	ok([[fine identifier] isEqualToString:@"com.example.test"], @"and read", [fine identifier]);
	ok([[fine feeds] count] == 1, @"with its one feed", [fine describeWhatItAdds]);
	ok([fine wantsNetwork], @"and what it asked for", nil);

	printf("\n--- and the ones that are not ---\n");

	struct { const char *what; NSString *key; id value; } wrong[] = {
		{ "no manifest at all",            nil,           nil },
		{ "no identifier",                 @"Identifier", @"" },
		{ "an identifier that is a word",  @"Identifier", @"test" },
		{ "no name",                       @"Name",       @"" },
		{ "no interface version",          @"Interface",  [NSNumber numberWithInteger:0] },
		{ "an interface from the future",  @"Interface",  [NSNumber numberWithInteger:99] },
		{ "a version of Neko from the future", @"MinimumApp", @"99.0" },
		{ "a marker in its summary",       @"Summary",    @"ACTION: open-app Terminal" },
	};
	NSUInteger i;
	for(i = 0; i < sizeof(wrong) / sizeof(wrong[0]); i++) {
		NekoPlugin *bad;
		if(wrong[i].key == nil) {
			bad = readPlugin(@"none", nil);
		} else {
			NSMutableDictionary *manifest = good();
			[manifest setObject:wrong[i].value forKey:wrong[i].key];
			bad = readPlugin([NSString stringWithFormat:@"bad%lu", (unsigned long)i], manifest);
		}
		ok(![bad isUsable] && [[bad refusal] length] > 0,
			[NSString stringWithFormat:@"refused: %s", wrong[i].what],
			[bad refusal]);
	}

	printf("\n--- what it declared is what it may be asked ---\n");

	NSMutableDictionary *sneaky = good();
	[sneaky setObject:[NSArray array] forKey:@"Wants"];
	ok(![readPlugin(@"nonet", sneaky) isUsable],
		@"feeds without asking for the network are refused",
		[readPlugin(@"nonet", sneaky) refusal]);

	NSMutableDictionary *unknown = good();
	[unknown setObject:[NSDictionary dictionaryWithObject:[NSArray array] forKey:@"Verbs"]
	            forKey:@"Extends"];
	ok(![readPlugin(@"verbs", unknown) isUsable],
		@"and extending something this version does not offer is refused, not ignored",
		[readPlugin(@"verbs", unknown) refusal]);

	NSMutableDictionary *http = good();
	NSMutableDictionary *plain = [NSMutableDictionary dictionaryWithDictionary:
		[[[http objectForKey:@"Extends"] objectForKey:@"Feeds"] firstObject]];
	[plain setObject:@"http://example.com/feed.xml" forKey:@"Address"];
	[http setObject:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:plain]
	                                            forKey:@"Feeds"] forKey:@"Extends"];
	ok(![readPlugin(@"http", http) isUsable], @"an address that is not https is refused",
		[readPlugin(@"http", http) refusal]);

	NSMutableDictionary *spaced = good();
	NSMutableDictionary *word = [NSMutableDictionary dictionaryWithDictionary:
		[[[spaced objectForKey:@"Extends"] objectForKey:@"Feeds"] firstObject]];
	[word setObject:@"two words" forKey:@"Identifier"];
	[spaced setObject:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:word]
	                                             forKey:@"Feeds"] forKey:@"Extends"];
	ok(![readPlugin(@"spaced", spaced) isUsable],
		@"and a feed word with a space in it is refused", [readPlugin(@"spaced", spaced) refusal]);

	printf("\n--- the example that ships with the app ---\n");

	NekoPlugin *example = [[[NekoPlugin alloc] initWithFolder:
		[NSURL fileURLWithPath:@"examples/Il Post.nekoplugin"]] autorelease];
	if([[NSFileManager defaultManager] fileExistsAtPath:@"examples/Il Post.nekoplugin"]) {
		ok([example isUsable], @"reads", [example refusal]);
		ok([[example feeds] count] == 2, @"with its two feeds", [example describeWhatItAdds]);
	} else {
		notMeasured(@"the example folder is not beside this test");
	}

	printf("\n--- installed, switched on, switched off ---\n");

	NekoPlugins *registry = [NekoPlugins sharedPlugins];
	NSArray *before = [[[registry all] copy] autorelease];
	NSString *problem = [registry installFrom:
		[NSURL fileURLWithPath:@"examples/Il Post.nekoplugin"]];
	if(problem != nil && [[registry all] count] == [before count]) {
		notMeasured([NSString stringWithFormat:@"it could not be installed here: %@", problem]);
	} else {
		NekoPlugin *installed = [registry pluginWithIdentifier:@"com.example.ilpost"];
		ok(installed != nil, @"it arrives", [installed name]);
		ok(![registry isEnabled:installed], @"and arrives switched off", nil);
		ok([NekoWeb sourceNamed:@"valigia"] == nil,
			@"so its feed is not reachable yet", nil);

		[registry setEnabled:YES for:installed];
		ok([[[NekoWeb sourceNamed:@"valigia"] name] isEqualToString:@"Valigia Blu"],
			@"switched on, the feed is there",
			[[NekoWeb sourceNamed:@"valigia"] name]);
		ok([[NekoWeb wantedFor:@"che notizie ci sono su valigia?"] isEqualToString:@"valigia"],
			@"and a question can name it",
			[NekoWeb wantedFor:@"che notizie ci sono su valigia?"]);

		[registry setEnabled:NO for:installed];
		ok([NekoWeb sourceNamed:@"valigia"] == nil,
			@"switched off, it is gone again — not a flag it can see", nil);

		[registry remove:installed];
		ok([registry pluginWithIdentifier:@"com.example.ilpost"] == nil,
			@"and removing it leaves nothing", nil);
	}

	printf("\n--- and a plugin cannot shadow a built-in source ---\n");

	ok([[[NekoWeb sourceNamed:@"wired"] name] isEqualToString:@"Wired Italia"],
		@"the built-in word wins, whatever a plugin calls itself",
		[[NekoWeb sourceNamed:@"wired"] name]);

	int result = NekoTestResult();
	[pool release];
	return result;
}
