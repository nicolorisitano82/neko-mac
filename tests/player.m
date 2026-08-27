/* Talking to Music and to Spotify.

   Two halves, measured in two places, because neither place can do both:

   1. **That a sandboxed app may do this at all** was measured before any of it
      was designed, by a throwaway application bundle signed exactly like Neko —
      app-sandbox plus com.apple.security.temporary-exception.apple-events naming
      com.apple.Music and com.spotify.client. It read Music's volume, set it and
      put it back, counted the library, and read Spotify's state and current
      track, all from inside its container. That is why the entitlement is in
      Neko.entitlements with the measurement written next to it.

   2. **That the commands are the right commands** is measured here. This harness
      is not sandboxed — an auxiliary executable with the sandbox entitlement is
      killed on launch, which is its own small finding — so what it proves is the
      scripts, not the container.

   Nothing here launches a music player. If Music is not already running the
   volume checks say so and stop: a test suite that opens somebody's music every
   time it runs is a test suite people turn off. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoPlayer.h"
#import "NekoPlugin.h"

static BOOL alreadyRunning(NSString *bundle)
{
	return [[NSRunningApplication
		runningApplicationsWithBundleIdentifier:bundle] count] > 0;
}

static NekoPlugin *readPlugin(NSString *name, NSDictionary *manifest)
{
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
		[NSString stringWithFormat:@"neko-player-%@.nekoplugin", name]];
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:path
	                          withIntermediateDirectories:YES attributes:nil error:NULL];
	[manifest writeToFile:[path stringByAppendingPathComponent:@"plugin.plist"]
	           atomically:YES];
	return [[[NekoPlugin alloc] initWithFolder:
		[NSURL fileURLWithPath:path]] autorelease];
}

static NSDictionary *manifestWith(NSDictionary *verb, NSArray *wants)
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		@"com.example.player", @"Identifier", @"Player Test", @"Name",
		@"1.0", @"Version", [NSNumber numberWithInteger:1], @"Interface",
		wants, @"Wants",
		[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:verb]
		                            forKey:@"Verbs"], @"Extends", nil];
}

static NSMutableDictionary *aVerb(void)
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
		@"v", @"Identifier",
		[NSArray arrayWithObject:@"alza il volume"], @"Phrases",
		@"Alzo?", @"Confirm",
		@"music", @"Player", @"volumeup", @"Command", nil];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- two players and eight commands, and nothing else ---\n");

	ok([[NekoPlayer players] count] == 2, @"two players",
		[[NekoPlayer players] componentsJoinedByString:@", "]);
	ok([NekoPlayer knows:@"music"] && [NekoPlayer knows:@"spotify"],
		@"and they are the two that were measured", nil);
	ok(![NekoPlayer knows:@"Terminal"] && ![NekoPlayer knows:@"finder"],
		@"anything else is not a player", nil);
	ok(![NekoPlayer knowsCommand:@"quit"] && ![NekoPlayer knowsCommand:@"delete"]
	   && ![NekoPlayer knowsCommand:@"do script"],
		@"and the commands are a list, not a language", nil);
	ok([NekoPlayer knowsCommand:@"volumeup"] && [NekoPlayer knowsCommand:@"next"],
		@"the ones a plugin needs are in it", nil);

	printf("\n--- what a manifest may say ---\n");

	NSArray *wants = [NSArray arrayWithObject:@"players"];
	ok([readPlugin(@"good", manifestWith(aVerb(), wants)) isUsable],
		@"a player and a command it knows", nil);

	NSMutableDictionary *strange = aVerb();
	[strange setObject:@"Terminal" forKey:@"Player"];
	ok(![readPlugin(@"who", manifestWith(strange, wants)) isUsable],
		@"a player it does not know is refused",
		[readPlugin(@"who", manifestWith(strange, wants)) refusal]);

	strange = aVerb();
	[strange setObject:@"quit" forKey:@"Command"];
	ok(![readPlugin(@"what", manifestWith(strange, wants)) isUsable],
		@"and so is a command outside the list",
		[readPlugin(@"what", manifestWith(strange, wants)) refusal]);

	strange = aVerb();
	[strange removeObjectForKey:@"Command"];
	ok(![readPlugin(@"half", manifestWith(strange, wants)) isUsable],
		@"a player with no command is half a verb",
		[readPlugin(@"half", manifestWith(strange, wants)) refusal]);

	strange = aVerb();
	[strange setObject:@"spotify:search:%@" forKey:@"Url"];
	ok(![readPlugin(@"both", manifestWith(strange, wants)) isUsable],
		@"and a verb with two doors is refused as it always was",
		[readPlugin(@"both", manifestWith(strange, wants)) refusal]);

	ok(![readPlugin(@"unasked", manifestWith(aVerb(), [NSArray array])) isUsable],
		@"commanding a player without asking to is refused",
		[readPlugin(@"unasked", manifestWith(aVerb(), [NSArray array])) refusal]);

	/* The thing a plugin must never be able to do. */
	strange = aVerb();
	[strange setObject:@"tell application \"Finder\" to empty trash" forKey:@"Script"];
	NekoPlugin *scripted = readPlugin(@"script", manifestWith(strange, wants));
	ok(![scripted isUsable],
		@"a verb carrying a script of its own is refused, not ignored",
		[scripted refusal]);

	printf("\n--- and what it actually does ---\n");

	if(![NekoPlayer isInstalled:@"music"]) {
		notMeasured(@"there is no Music on this Mac");
	} else if(!alreadyRunning(@"com.apple.Music")) {
		notMeasured(@"Music is not running, and a test may not open it");
	} else if(![NekoPlayer mayControl:@"music"]) {
		notMeasured(@"macOS has not been asked to allow controlling Music here");
	} else {
		NSAppleScript *read = [[[NSAppleScript alloc] initWithSource:
			@"tell application \"Music\" to return sound volume as text"] autorelease];
		int before = [[[read executeAndReturnError:NULL] stringValue] intValue];
		NSString *problem = nil;
		BOOL did = [NekoPlayer perform:@"volumedown" on:@"music"
		                          with:nil saying:&problem];
		/* Music answers with the old number for about a second after it is set,
		   and a second change inside that second is dropped. Measured: down then
		   up with no pause leaves it down; with a second between them both land.
		   Nobody says "alza il volume" twice inside a second — it takes a
		   sentence, a read-back and a click — so this is the test waiting, not the
		   app needing to. */
		spin(1.2);
		int after = [[[read executeAndReturnError:NULL] stringValue] intValue];
		ok(did, @"turning it down works", problem);
		ok(after == before - 10 || after == 0,
			@"and it moves by ten, or stops at nothing",
			[NSString stringWithFormat:@"%d → %d", before, after]);
		NSString *why = nil;
		BOOL restored = [NekoPlayer perform:@"volumeup" on:@"music"
		                               with:nil saying:&why];
		spin(1.2);
		int back = [[[read executeAndReturnError:NULL] stringValue] intValue];
		ok(restored && back == before, @"and back up again, where it was",
			[NSString stringWithFormat:@"%d, %@", back, why ?: @"no complaint"]);
	}

	printf("\n--- and what it says when it cannot ---\n");

	NSString *why = nil;
	ok(![NekoPlayer perform:@"playnamed" on:@"spotify" with:@"anything" saying:&why],
		@"Spotify cannot be searched from outside", why);
	ok([why length] > 0, @"and it says so in a sentence", why);

	why = nil;
	ok(![NekoPlayer perform:@"quit" on:@"music" with:nil saying:&why],
		@"a command outside the list does nothing at the moment of doing either", nil);

	int result = NekoTestResult();
	[pool release];
	return result;
}
