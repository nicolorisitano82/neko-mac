/* Phrases a plugin asked to hear.

   Recognised by the app and never by a model — the news feeds measured why: asked
   to read one, a 4B invented a headline and a 1.5B repeated the question back. So
   what is under test here is the matching, the read-back, and the two doors a
   verb may go through: an address from a closed list of schemes, or one of the
   user's own Shortcuts.

   Nothing here actually opens anything. Performing is tested for what it refuses;
   what it accepts would open Spotify on somebody's Mac, and a test may not do
   that. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoPlugin.h"
#import "NekoPlugins.h"
#import "NekoPluginVerbs.h"
#import "NekoAction.h"
#import "NekoAsk.h"
#import "NekoBubble.h"
#import <objc/runtime.h>

/* Private, and used here the way tests/screen.m uses it: between two staged
   questions, so the second one does not arrive on top of the first. */
@interface NekoAsk (TestOnly)
- (void)cancelEverything;
@end

static NSURL *stage(NSString *name, NSDictionary *manifest)
{
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
		[NSString stringWithFormat:@"neko-verb-%@.nekoplugin", name]];
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:path
	                          withIntermediateDirectories:YES attributes:nil error:NULL];
	[manifest writeToFile:[path stringByAppendingPathComponent:@"plugin.plist"]
	           atomically:YES];
	return [NSURL fileURLWithPath:path];
}

static NSMutableDictionary *manifestWith(NSArray *verbs, NSArray *wants)
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
		@"com.example.verbs", @"Identifier",
		@"Verbs Test", @"Name",
		@"1.0", @"Version",
		[NSNumber numberWithInteger:1], @"Interface",
		wants, @"Wants",
		[NSDictionary dictionaryWithObject:verbs forKey:@"Verbs"], @"Extends", nil];
}

static NSDictionary *aVerb(NSString *ident, NSArray *phrases, NSString *confirm,
                           NSString *url, NSString *shortcut)
{
	NSMutableDictionary *verb = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		ident, @"Identifier", phrases, @"Phrases", nil];
	if(confirm != nil)  [verb setObject:confirm forKey:@"Confirm"];
	if(url != nil)      [verb setObject:url forKey:@"Url"];
	if(shortcut != nil) [verb setObject:shortcut forKey:@"Shortcut"];
	return verb;
}

/* Whatever the bubble is showing, in one string. */
static NSString *shownIn(NekoBubble *bubble)
{
	NSMutableString *shown = [NSMutableString string];
	NSEnumerator *views = [[[bubble contentView] subviews] objectEnumerator];
	NSView *view;
	while((view = [views nextObject]) != nil)
		if([view isKindOfClass:[NSTextField class]])
			[shown appendFormat:@"%@ ", [(NSTextField *)view stringValue]];
	return shown;
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

	printf("\n--- what a verb has to declare ---\n");

	NSArray *open = [NSArray arrayWithObjects:@"open", @"shortcuts", nil];
	NSDictionary *good = aVerb(@"search",
		[NSArray arrayWithObjects:@"metti", @"play", nil],
		@"Cerco “%@” su Spotify?", @"spotify:search:%@", nil);
	NekoPlugin *fine = readPlugin(@"good", manifestWith([NSArray arrayWithObject:good], open));
	ok([fine isUsable], @"a verb with phrases, a read-back and an address", [fine refusal]);
	ok([[fine verbs] count] == 1, @"and it is there", [fine describeWhatItAdds]);

	struct { const char *what; NSDictionary *verb; NSArray *wants; } wrong[] = {
		{ "no phrases",
		  aVerb(@"a", [NSArray array], @"Faccio?", @"spotify:search:%@", nil), open },
		{ "a phrase of two letters",
		  aVerb(@"a", [NSArray arrayWithObject:@"da"], @"Faccio?", @"spotify:search:%@", nil), open },
		{ "no read-back at all",
		  aVerb(@"a", [NSArray arrayWithObject:@"metti"], nil, @"spotify:search:%@", nil), open },
		{ "neither an address nor a Shortcut",
		  aVerb(@"a", [NSArray arrayWithObject:@"metti"], @"Faccio?", nil, nil), open },
		{ "both an address and a Shortcut",
		  aVerb(@"a", [NSArray arrayWithObject:@"metti"], @"Faccio?", @"spotify:search:%@", @"Something"), open },
		{ "a scheme Neko will not open",
		  aVerb(@"a", [NSArray arrayWithObject:@"metti"], @"Faccio?", @"file:///etc/passwd", nil), open },
		{ "the scheme that runs Shortcuts, hidden in an address",
		  aVerb(@"a", [NSArray arrayWithObject:@"metti"], @"Faccio?", @"shortcuts://run-shortcut?name=Wipe", nil), open },
		{ "a marker in the read-back",
		  aVerb(@"a", [NSArray arrayWithObject:@"metti"], @"ACTION: open-app Terminal", @"spotify:search:%@", nil), open },
		{ "an address without asking to open things",
		  aVerb(@"a", [NSArray arrayWithObject:@"metti"], @"Faccio?", @"spotify:search:%@", nil),
		  [NSArray arrayWithObject:@"shortcuts"] },
		{ "a Shortcut without asking to run one",
		  aVerb(@"a", [NSArray arrayWithObject:@"metti"], @"Faccio?", nil, @"Something"),
		  [NSArray arrayWithObject:@"open"] },
	};
	NSUInteger i;
	for(i = 0; i < sizeof(wrong) / sizeof(wrong[0]); i++) {
		NekoPlugin *bad = readPlugin([NSString stringWithFormat:@"bad%lu", (unsigned long)i],
			manifestWith([NSArray arrayWithObject:wrong[i].verb], wrong[i].wants));
		ok(![bad isUsable] && [[bad refusal] length] > 0,
			[NSString stringWithFormat:@"refused: %s", wrong[i].what], [bad refusal]);
	}

	printf("\n--- and what it hears ---\n");

	/* Installed and switched on, so the matcher can see it. */
	NekoPlugins *registry = [NekoPlugins sharedPlugins];
	NSArray *verbs = [NSArray arrayWithObjects:
		aVerb(@"search", [NSArray arrayWithObjects:@"metti", @"play", nil],
			@"Cerco “%@” su Spotify?", @"spotify:search:%@", nil),
		aVerb(@"volumeup", [NSArray arrayWithObjects:@"alza il volume", @"alza", nil],
			@"Alzo il volume?", nil, @"Neko Volume Up"),
		/* No shorter phrase to fall back on, on purpose: with "alza" in the list
		   above, "alza il volume" matched through it and the check below passed
		   while the real plugins did not work at all. */
		aVerb(@"next", [NSArray arrayWithObject:@"prossima canzone"],
			@"Passo alla prossima?", nil, @"Neko Next Track"), nil];
	NSString *problem = [registry installFrom:
		stage(@"live", manifestWith(verbs, open))];
	NekoPlugin *installed = [registry pluginWithIdentifier:@"com.example.verbs"];
	if(installed == nil) {
		notMeasured([NSString stringWithFormat:@"it could not be installed here: %@", problem]);
	} else {
		ok(![NekoPluginVerbs anythingListens],
			@"switched off, nothing is listening", nil);
		[registry setEnabled:YES for:installed];
		ok([NekoPluginVerbs anythingListens], @"switched on, something is", nil);

		NSDictionary *match = [NekoPluginVerbs matchFor:@"metti Taylor Swift"];
		ok([[match objectForKey:@"Identifier"] isEqualToString:@"search"],
			@"“metti Taylor Swift” is the search verb", [match objectForKey:@"Identifier"]);
		ok([[match objectForKey:@"Argument"] isEqualToString:@"Taylor Swift"],
			@"and the rest of the sentence is the argument",
			[match objectForKey:@"Argument"]);
		ok([[match objectForKey:@"Sentence"] isEqualToString:@"Cerco “Taylor Swift” su Spotify?"],
			@"read back with the words in it", [match objectForKey:@"Sentence"]);

		NSDictionary *longer = [NekoPluginVerbs matchFor:@"alza il volume per favore"];
		ok([[longer objectForKey:@"Identifier"] isEqualToString:@"volumeup"],
			@"the longest phrase wins over the shorter one it contains",
			[longer objectForKey:@"Identifier"]);
		ok([[longer objectForKey:@"Sentence"] isEqualToString:@"Alzo il volume?"],
			@"and a read-back without a %@ is used as it is",
			[longer objectForKey:@"Sentence"]);

		/* The whole sentence being the phrase, with no shorter phrase behind it
		   and nothing after it: this is what the two music plugins do all day,
		   and what stopped working. */
		NSDictionary *bare = [NekoPluginVerbs matchFor:@"prossima canzone"];
		ok([[bare objectForKey:@"Identifier"] isEqualToString:@"next"],
			@"a phrase said with nothing after it is still the verb",
			[bare objectForKey:@"Identifier"]);
		ok([[bare objectForKey:@"Sentence"] isEqualToString:@"Passo alla prossima?"],
			@"and its read-back needs no words to be complete",
			[bare objectForKey:@"Sentence"]);

		ok([NekoPluginVerbs matchFor:@"mettiamo che sia lunedì"] == nil,
			@"a phrase inside a longer word does not match", nil);
		ok([NekoPluginVerbs matchFor:@"metti"] == nil,
			@"and a search with nothing to search for does not either", nil);
		ok([NekoPluginVerbs matchFor:@"che ore sono?"] == nil,
			@"an ordinary question is left alone", nil);

		printf("\n--- and what it refuses to do ---\n");

		NSMutableDictionary *tampered = [NSMutableDictionary dictionaryWithDictionary:match];
		[tampered setObject:@"file:///etc/passwd" forKey:@"Url"];
		ok(![NekoPluginVerbs perform:tampered],
			@"an address outside the list is refused at the moment of doing, too", nil);

		[tampered setObject:@"spotify:search:x" forKey:@"Url"];
		[tampered setObject:@"com.example.gone" forKey:@"Plugin"];
		ok(![NekoPluginVerbs perform:tampered],
			@"and so is a verb whose plugin is not there", nil);

		[registry setEnabled:NO for:installed];
		NSMutableDictionary *offNow = [NSMutableDictionary dictionaryWithDictionary:match];
		ok(![NekoPluginVerbs perform:offNow],
			@"a switch turned off between the question and the yes counts", nil);

		printf("\n--- read back in a bubble, and dismissed ---\n");

		/* Live, through the same door a typed question goes through. The verb
		   under test runs a Shortcut nobody has, so a yes could open nothing
		   even if something went wrong here; what is measured is the bubble. */
		[registry setEnabled:YES for:installed];
		NekoAsk *ask = [NekoAsk sharedAsk];
		Ivar found = class_getInstanceVariable([NekoAsk class], "bubble");
		NekoBubble *bubble = (NekoBubble *)object_getIvar(ask, found);
		NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];

		[settings setBool:NO forKey:NekoActionsEnabledKey];
		[ask cancelEverything];
		[ask askAfterPlugins:@"alza il volume"];
		spin(0.4);
		ok(![bubble isVisible]
		   || [shownIn(bubble) rangeOfString:@"Alzo il volume"].location == NSNotFound,
			@"with doing things switched off, no verb is even offered",
			shownIn(bubble));
		[ask cancelEverything];
		spin(0.2);

		[settings setBool:YES forKey:NekoActionsEnabledKey];
		[ask askAfterPlugins:@"alza il volume"];
		spin(0.4);
		NSString *shown = shownIn(bubble);
		ok([shown rangeOfString:@"Alzo il volume"].location != NSNotFound,
			@"switched on, the read-back is what appears", shown);
		BOOL buttons = NO;
		NSEnumerator *views = [[[bubble contentView] subviews] objectEnumerator];
		NSView *view;
		while((view = [views nextObject]) != nil)
			if([view isKindOfClass:[NSButton class]] && ![view isHidden])
				buttons = YES;
		ok(buttons, @"with a yes and a no on it", nil);

		[bubble performSelector:@selector(dismissByClick)];
		spin(1.0);
		NSString *after = shownIn(bubble);
		ok([after rangeOfString:NSLocalizedString(@"All right, I will not.", nil)].location
		       != NSNotFound
		   || [after rangeOfString:NSLocalizedString(@"Done.", nil)].location == NSNotFound,
			@"dismissing it is a no, and nothing was done", after);
		[ask cancelEverything];
		[settings removeObjectForKey:NekoActionsEnabledKey];

		[registry remove:installed];
	}

	printf("\n--- the examples that ship inside the app ---\n");

	/* Read out of the bundle rather than out of the source folder: what matters
	   is that somebody who downloaded the disk image has something to point Add…
	   at, and that it is not switched on behind their back. */
	NSArray *examples = [[NekoPlugins sharedPlugins] examples];
	ok([examples count] >= 2, @"they are in the bundle, where Add… can reach them",
		[NSString stringWithFormat:@"%lu", (unsigned long)[examples count]]);
	NSEnumerator *e = [examples objectEnumerator];
	NSURL *folder;
	int withVerbs = 0;
	while((folder = [e nextObject]) != nil) {
		NSString *path = [folder path];
		NekoPlugin *example = [[[NekoPlugin alloc] initWithFolder:folder] autorelease];
		ok([example isUsable], [NSString stringWithFormat:@"%@ reads",
			[path lastPathComponent]], [example refusal]);
		/* Not "it is not installed" — somebody may well have installed it, and
		   that is theirs to decide. What must be true is that nothing installs it
		   for them: the seeded folder, which is the one seedFromBundle copies and
		   switches on, must not contain it. */
		NSString *seeded = [[[NSBundle mainBundle] resourcePath]
			stringByAppendingPathComponent:@"Plugins"];
		BOOL amongTheSeeded = NO;
		NSEnumerator *inThere = [[[NSFileManager defaultManager]
			contentsOfDirectoryAtPath:seeded error:NULL] objectEnumerator];
		NSString *seededName;
		while((seededName = [inThere nextObject]) != nil)
			if([seededName isEqualToString:[path lastPathComponent]])
				amongTheSeeded = YES;
		ok(!amongTheSeeded, @"and nothing puts it in place for somebody", nil);
		if([[example verbs] count] == 0)
			continue;
		withVerbs++;
		ok([[example verbs] count] == 6, @"with its six phrases",
			[example describeWhatItAdds]);
		/* Every one of them read back, and none of them a marker. */
		NSEnumerator *v = [[example verbs] objectEnumerator];
		NSDictionary *verb;
		BOOL allSafe = YES;
		while((verb = [v nextObject]) != nil) {
			NSString *confirm = [verb objectForKey:@"Confirm"];
			if([confirm length] == 0 || [NekoAction looksLikeAnAction:confirm])
				allSafe = NO;
		}
		ok(allSafe, @"and every one of them says what it is about to do", nil);
	}
	ok(withVerbs == 2, @"and two of them are the music ones",
		[NSString stringWithFormat:@"%d", withVerbs]);

	printf("\n--- every phrase they ship hears itself ---\n");

	/* The check that was missing. A plugin whose phrases do not match is not
	   refused by anything — it simply never answers, which is how "alza il
	   volume" shipped doing nothing. So: install each of them, and say every
	   phrase of every verb exactly as written. A verb whose read-back needs the
	   words is said with a word after it; one that does not is said bare. */
	NSEnumerator *again = [examples objectEnumerator];
	while((folder = [again nextObject]) != nil) {
		NekoPlugin *read = [[[NekoPlugin alloc] initWithFolder:folder] autorelease];
		if([[read verbs] count] == 0)
			continue;
		/* Whatever somebody has installed here stays installed: this puts it
		   back the way it found it, and only removes what it added itself. */
		BOOL wasThere = [registry pluginWithIdentifier:[read identifier]] != nil;
		NSString *why = wasThere ? nil : [registry installFrom:folder];
		NekoPlugin *live = [registry pluginWithIdentifier:[read identifier]];
		if(live == nil) {
			notMeasured([NSString stringWithFormat:@"%@ could not be installed: %@",
				[[folder path] lastPathComponent], why]);
			continue;
		}
		BOOL was = [registry isEnabled:live];
		[registry setEnabled:YES for:live];

		NSUInteger heard = 0, spoken = 0;
		NSMutableArray *deaf = [NSMutableArray array];
		NSEnumerator *v = [[live verbs] objectEnumerator];
		NSDictionary *verb;
		while((verb = [v nextObject]) != nil) {
			BOOL needsWords = [[verb objectForKey:@"Confirm"]
				rangeOfString:@"%@"].location != NSNotFound;
			NSEnumerator *p = [[verb objectForKey:@"Phrases"] objectEnumerator];
			NSString *phrase;
			while((phrase = [p nextObject]) != nil) {
				NSString *said = needsWords
					? [phrase stringByAppendingString:@" qualcosa"] : phrase;
				NSDictionary *hit = [NekoPluginVerbs matchFor:said];
				spoken++;
				if([[hit objectForKey:@"Identifier"]
				        isEqualToString:[verb objectForKey:@"Identifier"]])
					heard++;
				else
					[deaf addObject:[NSString stringWithFormat:@"%@ → %@", said,
						[hit objectForKey:@"Identifier"] ?: @"nothing"]];
			}
		}
		ok(heard == spoken, [NSString stringWithFormat:@"%@ hears all %lu of its phrases",
			[[folder path] lastPathComponent], (unsigned long)spoken],
			[deaf componentsJoinedByString:@", "]);

		if(!was)
			[registry setEnabled:NO for:live];
		if(!wasThere)
			[registry remove:live];
	}

	int result = NekoTestResult();
	[pool release];
	return result;
}
