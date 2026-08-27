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
#import "NekoPluginText.h"

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

	printf("\n--- processing text ---\n");

	/* Declared with a direction and one of the user's own Shortcuts, and never
	   with a program of the plugin's own. */
	NSMutableDictionary *withText = good();
	[withText setObject:[NSDictionary dictionaryWithObject:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"both", @"Direction", @"Tidy up", @"Shortcut", nil]
	                                               forKey:@"Text"] forKey:@"Extends"];
	NekoPlugin *speaks = readPlugin(@"text", withText);
	ok([speaks isUsable], @"a text plugin naming a Shortcut is accepted", [speaks refusal]);
	ok([speaks processesTextGoing:YES] && [speaks processesTextGoing:NO],
		@"both directions", [speaks describeWhatItAdds]);

	NSMutableDictionary *oneWay = good();
	[oneWay setObject:[NSDictionary dictionaryWithObject:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"out", @"Direction", @"Tidy up", @"Shortcut", nil]
	                                             forKey:@"Text"] forKey:@"Extends"];
	NekoPlugin *outward = readPlugin(@"out", oneWay);
	ok([outward processesTextGoing:NO] && ![outward processesTextGoing:YES],
		@"or one", [outward describeWhatItAdds]);

	NSMutableDictionary *noShortcut = good();
	[noShortcut setObject:[NSDictionary dictionaryWithObject:
		[NSDictionary dictionaryWithObject:@"both" forKey:@"Direction"]
	                                                 forKey:@"Text"] forKey:@"Extends"];
	ok([[readPlugin(@"noshort", noShortcut) refusal]
			rangeOfString:@"without naming a Shortcut"].location != NSNotFound,
		@"without a Shortcut it is refused, and for that reason",
		[readPlugin(@"noshort", noShortcut) refusal]);

	NSMutableDictionary *ownProgram = good();
	[ownProgram setObject:[NSDictionary dictionaryWithObject:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"both", @"Direction", @"Tidy up", @"Shortcut",
			@"./filter", @"Program", nil]
	                                                 forKey:@"Text"] forKey:@"Extends"];
	ok([[readPlugin(@"program", ownProgram) refusal]
			rangeOfString:@"program of its own"].location != NSNotFound,
		@"and with a program of its own it is refused, and for that reason",
		[readPlugin(@"program", ownProgram) refusal]);

	NSMutableDictionary *sideways = good();
	[sideways setObject:[NSDictionary dictionaryWithObject:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"sideways", @"Direction", @"Tidy up", @"Shortcut", nil]
	                                               forKey:@"Text"] forKey:@"Extends"];
	ok([[readPlugin(@"sideways", sideways) refusal]
			rangeOfString:@"Direction"].location != NSNotFound,
		@"a direction that is not in, out or both is refused, and for that reason",
		[readPlugin(@"sideways", sideways) refusal]);

	printf("\n--- and nothing processes text unless one is switched on ---\n");

	ok(![NekoPluginText anythingProcesses:YES] && ![NekoPluginText anythingProcesses:NO],
		@"with none enabled, both directions cost nothing", nil);

	__block NSString *came = nil;
	__block BOOL back = NO;
	[NekoPluginText pass:@"che ore sono" inward:YES
	          completion:^(NSString *result, NSString *pluginName) {
		came = [result copy];
		back = YES;
	}];
	spin(0.2);
	ok(back && [came isEqualToString:@"che ore sono"],
		@"and the words come back exactly as they went in", came);

	printf("\n--- the one that ships inside the app ---\n");

	/* What the app does at launch, done here so the sources exist at all: the two
	   dozen feeds live in a plugin now rather than in NekoWeb.m. */
	[registry seedFromBundle];
	NekoPlugin *news = [registry pluginWithIdentifier:@"com.nekomac.news"];
	ok(news != nil, @"it is put in place without being asked", [news name]);
	ok([registry isBundled:news], @"and is known to ship with the app", nil);
	ok([registry isEnabled:news],
		@"switched on, because these are the feeds the app has always had", nil);
	ok([[NekoWeb sources] count] >= 24, @"which is where the sources come from",
		[NSString stringWithFormat:@"%lu", (unsigned long)[[NekoWeb sources] count]]);
	ok([[[NekoWeb sourceNamed:@"ansa"] name] isEqualToString:@"ANSA"],
		@"by name", [[NekoWeb sourceNamed:@"ansa"] name]);
	ok([[NekoWeb namesForInstructions] rangeOfString:@"weather"].location != NSNotFound
	   && [[NekoWeb namesForInstructions] componentsSeparatedByString:@","].count <= 10,
		@"and the handful shown to a model is unchanged",
		[NekoWeb namesForInstructions]);

	printf("\n--- switched off, and it stays off ---\n");

	[registry setEnabled:NO for:news];
	ok([[NekoWeb sources] count] == 0, @"no sources at all", nil);
	ok([NekoWeb wantedFor:@"cosa è successo oggi nel mondo?"] == nil,
		@"and a news question is not sent looking for something that is not there",
		[NekoWeb wantedFor:@"cosa è successo oggi nel mondo?"]);

	/* The rule that matters for a plugin the app ships: seeding again — which is
	   what the next launch does — must not switch it back on. */
	[registry seedFromBundle];
	ok(![registry isEnabled:[registry pluginWithIdentifier:@"com.nekomac.news"]],
		@"and the next launch leaves it off", nil);
	[registry setEnabled:YES for:[registry pluginWithIdentifier:@"com.nekomac.news"]];

	printf("\n--- and a plugin cannot shadow one that is already there ---\n");

	ok([[[NekoWeb sourceNamed:@"wired"] name] isEqualToString:@"Wired Italia"],
		@"the built-in word wins, whatever a plugin calls itself",
		[[NekoWeb sourceNamed:@"wired"] name]);

	int result = NekoTestResult();
	[pool release];
	return result;
}
