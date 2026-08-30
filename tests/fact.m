/* Things about you that the cat was told, and keeps.

   The diary already grows durable lines, but slowly: a reflection over yesterday,
   once a day, written by an engine. Checked in NekoMemory, that means a fact said
   this morning is invisible until tomorrow — and on a Mac with no local engine and
   no Apple Intelligence it is invisible for ever, because the reflection returns
   early when there is nothing to think with.

   So this is the fast half, recognised in code. What it must get right is not the
   remembering, which is a file, but **the line between a sentence that asks for
   this and one that does not**: "ricordati che" is a fact, "ricordami di" is an
   errand, and "non mi ricordo come si chiama" is neither. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoFact.h"
#import "NekoMemory.h"

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[NekoFact forgetEverything];

	printf("\n--- what it hears as something to keep ---\n");

	struct { const char *said; const char *kind; const char *what; } heard[] = {
		{ "ricordati che il venerdì stacco prima", "keep", "il venerdì stacco prima" },
		{ "ricorda che la release esce venerdì", "keep", "la release esce venerdì" },
		{ "tieni presente che lavoro su neko-mac", "keep", "lavoro su neko-mac" },
		{ "remember that I work late on Tuesdays", "keep", "I work late on Tuesdays" },
		{ "remember I hate being interrupted", "keep", "hate being interrupted" },
		{ "souviens-toi que je travaille le samedi", "keep", "je travaille le samedi" },
		{ "recuerda que los viernes salgo antes", "keep", "los viernes salgo antes" },
		{ "mi chiamo Nicolò", "name", "Nicolò" },
		{ "my name is Nicolò", "name", "Nicolò" },
		{ "je m'appelle Nicolò", "name", "Nicolò" },
		{ "dimentica il venerdì", "forget", "il venerdì" },
		{ "forget the release date", "forget", "the release date" },
	};
	NSUInteger i, right = 0, total = sizeof(heard) / sizeof(heard[0]);
	NSMutableString *wrong = [NSMutableString string];
	for(i = 0; i < total; i++) {
		NSDictionary *got = [NekoFact wantedFor:
			[NSString stringWithUTF8String:heard[i].said]];
		NSString *kind = [got objectForKey:@"Kind"];
		NSString *what = [got objectForKey:@"What"];
		if([kind isEqualToString:[NSString stringWithUTF8String:heard[i].kind]]
		   && [what isEqualToString:[NSString stringWithUTF8String:heard[i].what]])
			right++;
		else
			[wrong appendFormat:@"%s → %@/%@; ", heard[i].said, kind ?: @"nothing", what];
	}
	ok(right == total, [NSString stringWithFormat:
		@"all %lu ways of saying it are understood", (unsigned long)total], wrong);

	printf("\n--- and what it leaves alone ---\n");

	/* The half that matters. Three of these contain the word for remembering. */
	const char *notFacts[] = {
		"ricordami di comprare il latte",       /* an errand, not a fact */
		"ricordamelo fra 20 minuti",            /* the timer's */
		"non mi ricordo come si chiama",        /* a complaint */
		"ti ricordi cosa ho detto ieri?",       /* a question */
		"do you remember what I said?",
		"come si chiama il gatto?",
		"che ore sono?",
		"metti un timer di 10 minuti",
		"notizie su Bologna",
		"quanto fa sette per otto",
	};
	NSUInteger quiet = 0, asked = sizeof(notFacts) / sizeof(notFacts[0]);
	NSMutableString *misfired = [NSMutableString string];
	for(i = 0; i < asked; i++) {
		NSDictionary *got = [NekoFact wantedFor:
			[NSString stringWithUTF8String:notFacts[i]]];
		if(got == nil)
			quiet++;
		else
			[misfired appendFormat:@"%s → %@; ", notFacts[i],
				[got objectForKey:@"What"]];
	}
	ok(quiet == asked, [NSString stringWithFormat:
		@"none of %lu ordinary sentences is written down", (unsigned long)asked],
		misfired);

	printf("\n--- keeping it ---\n");

	[NekoFact act:[NekoFact wantedFor:@"ricordati che il venerdì stacco prima"]];
	ok([[NekoFact all] count] == 1, @"one thing said, one thing kept",
		[[NekoFact all] componentsJoinedByString:@" / "]);
	ok([[[NekoFact all] objectAtIndex:0] isEqualToString:@"il venerdì stacco prima"],
		@"in the words it was said in", [[NekoFact all] objectAtIndex:0]);

	[NekoFact act:[NekoFact wantedFor:@"ricordati che il venerdì stacco prima"]];
	ok([[NekoFact all] count] == 1, @"said twice, kept once", nil);

	[NekoFact act:[NekoFact wantedFor:@"mi chiamo Nicolò"]];
	[NekoFact act:[NekoFact wantedFor:@"mi chiamo Nico"]];
	NSUInteger names = 0;
	NSEnumerator *e = [[NekoFact all] objectEnumerator];
	NSString *one;
	while((one = [e nextObject]) != nil)
		if([one rangeOfString:@"Nico"].location != NSNotFound)
			names++;
	ok(names == 1, @"a name replaces a name rather than sitting beside it",
		[[NekoFact all] componentsJoinedByString:@" / "]);

	printf("\n--- letting it go ---\n");

	NSString *said = [NekoFact act:[NekoFact wantedFor:@"dimentica il venerdì"]];
	ok([[NekoFact all] count] == 1,
		@"forgetting takes the one it matches and leaves the rest",
		[[NekoFact all] componentsJoinedByString:@" / "]);
	ok([said length] > 0, @"and says so", said);

	NSString *nothing = [NekoFact act:
		[NekoFact wantedFor:@"dimentica i cavalli islandesi"]];
	ok([nothing length] > 0 && [[NekoFact all] count] == 1,
		@"and asked to forget something it never knew, it says that instead",
		nothing);

	printf("\n--- and it reaches the block a model is given ---\n");

	[NekoFact act:[NekoFact wantedFor:@"ricordati che lavoro su neko-mac"]];
	NSString *block = [[NekoMemory sharedMemory] contextForPrompt];
	ok([block rangeOfString:@"neko-mac"].location != NSNotFound,
		@"what it was told is in front of the model", nil);
	ok([block length] <= 1100, @"and the block is still inside its budget",
		[NSString stringWithFormat:@"%lu characters", (unsigned long)[block length]]);

	printf("\n--- and it is a file somebody can read ---\n");

	NSURL *file = [[[NekoMemory sharedMemory] directory]
		URLByAppendingPathComponent:@"facts.txt"];
	NSString *onDisk = [NSString stringWithContentsOfURL:file
	                                            encoding:NSUTF8StringEncoding error:NULL];
	ok([onDisk rangeOfString:@"neko-mac"].location != NSNotFound,
		@"plain text, beside the diary, in the folder the preferences open",
		[[onDisk componentsSeparatedByString:@"\n"] lastObject]);

	[NekoFact forgetEverything];
	ok([[NekoFact all] count] == 0, @"and all of it can be thrown away at once", nil);

	int result = NekoTestResult();
	[pool release];
	return result;
}
