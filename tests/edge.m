/* Where the cat's edges are, and that they move.

   The third piece of docs/self.md. `NekoUnseen` is a list of nine things that lie
   outside the self — somebody's bank, their mail, their files, whether their code
   builds — answered in code with one sentence each. Having such a list is not the
   interesting property. The 2026 benchmark that separates *knowing* whether a
   problem needs something outside you from *acting* on that knowledge (KAPRO, 18
   models) is pointing at the interesting one: whether the edge is **known**, which
   for a program means whether it is in the right place and whether it **moves**
   when the world moves.

   Three things follow, and they are what this measures:

     the edge has named parts     nine classes, nine different sentences, not one
                                  generic refusal wearing nine hats
     it moves inwards             a folder handed over in a panel puts files
                                  inside the boundary, and the cat stops saying
                                  it cannot see them
     and it stays put otherwise   nothing anybody can grant brings somebody's
                                  bank or their dreams inside it

   The folder half is the one docs/personality-roadmap.md and tests/unseen.m both
   recorded as unmeasurable: a real grant is a security-scoped bookmark and a
   harness may not put a panel on somebody's screen. It is measured here by
   swapping the method that answers the question, which is what tests/quit.m does
   to +[NSEvent mouseLocation] and what NekoPlace exposes a seam for. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoUnseen.h"
#import "NekoFolderAccess.h"
#import "NekoWeb.h"

/* A folder, as far as anything asking is concerned. */
static BOOL grantedFolders = NO;

static NSArray *stagedAllowedKeys(id self, SEL _cmd)
{
	return grantedFolders ? [NSArray arrayWithObject:@"documents"] : [NSArray array];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- the edge has named parts ---\n");

	/* One question per class. A boundary that answered all nine with the same
	   sentence would be a wall, not an edge somebody can reason about. */
	NSArray *classes = [NSArray arrayWithObjects:
		@"quanto ho sul conto?",                @"accounts",
		@"quanto vale Apple in borsa adesso?",  @"markets",
		@"chi mi ha scritto stamattina?",       @"mail",
		@"cosa c'è scritto nel file che ho aperto ieri?", @"files",
		@"il mio codice compila?",              @"build",
		@"chi è al telefono?",                  @"people",
		@"che cosa ho sognato stanotte?",       @"body",
		@"che tempo fa a Roma?",                @"weather",
		@"cosa ho in calendario domani?",       @"calendar",
		nil];
	NSMutableSet *sentences = [NSMutableSet set];
	NSUInteger i;
	for(i = 0; i < [classes count]; i += 2) {
		NSString *said = [NekoUnseen wantedFor:[classes objectAtIndex:i]];
		ok(said != nil, [classes objectAtIndex:i + 1], said ?: @"(nothing)");
		if(said != nil)
			[sentences addObject:said];
	}
	ok([sentences count] == [classes count] / 2,
		@"nine classes, nine different sentences",
		[NSString stringWithFormat:@"%lu distinct of %lu",
			(unsigned long)[sentences count], (unsigned long)([classes count] / 2)]);

	printf("\n--- and it moves inwards when a folder is handed over ---\n");

	NSString *aboutAFile = @"cosa c'è scritto nel file che ho aperto ieri?";
	NSString *withNone = [NekoUnseen wantedFor:aboutAFile];
	ok(withNone != nil, @"with no folder granted it says it cannot see inside",
		withNone ?: @"(nothing)");

	Method real = class_getInstanceMethod([NekoFolderAccess class],
	                                      @selector(allowedKeys));
	IMP was = real != NULL ? method_getImplementation(real) : NULL;
	if(real == NULL) {
		notMeasured(@"NekoFolderAccess has no -allowedKeys any more, so the "
		            @"boundary this file measures has moved somewhere else");
	} else {
		method_setImplementation(real, (IMP)stagedAllowedKeys);

		grantedFolders = YES;
		NSString *withOne = [NekoUnseen wantedFor:aboutAFile];
		ok(withOne == nil,
			@"with one granted it stops saying so — the file is inside now",
			withOne ?: @"stands aside");

		grantedFolders = NO;
		NSString *takenBack = [NekoUnseen wantedFor:aboutAFile];
		ok(takenBack != nil && [takenBack isEqualToString:withNone],
			@"and taken away again, the edge is back where it was",
			takenBack ?: @"(nothing)");

		printf("\n--- while nothing anybody can grant moves the others ---\n");

		/* A folder is not a bank and not a night's sleep. The edge moves in one
		   place and stays where it is everywhere else, which is the difference
		   between a boundary and a mood. */
		grantedFolders = YES;
		NSArray *stillOutside = [NSArray arrayWithObjects:
			@"quanto ho sul conto?", @"chi mi ha scritto stamattina?",
			@"che cosa ho sognato stanotte?", @"il mio codice compila?",
			@"cosa ho in calendario domani?", nil];
		NSEnumerator *e = [stillOutside objectEnumerator];
		NSString *question;
		while((question = [e nextObject]) != nil)
			ok([NekoUnseen wantedFor:question] != nil, question,
				[NekoUnseen wantedFor:question] ?: @"WENT QUIET");
		grantedFolders = NO;

		if(was != NULL)
			method_setImplementation(real, was);
		ok([[NekoUnseen wantedFor:aboutAFile] isEqualToString:withNone],
			@"and the real answer is restored after the swap", nil);
	}

	printf("\n--- and it moves outwards when something else can answer ---\n");

	/* The other direction, and the one already true: the weather is inside the
	   boundary when looking things up is on and a town is known, because NekoWeb
	   runs nine places earlier in the chain and takes it. Asserted of the matcher
	   rather than of the chain, since the chain's order is checked by position in
	   tests/unseen.m. */
	ok([NekoWeb wantedFor:@"che tempo fa a Roma?"] != nil,
		@"a forecast this application can fetch is not something it cannot see",
		[NekoWeb wantedFor:@"che tempo fa a Roma?"]);
	ok([NekoWeb wantedFor:@"quanto ho sul conto?"] == nil,
		@"and a bank balance is not something it can fetch", nil);

	printf("\n--- and the chain puts everything that might know first ---\n");

	NSString *chain = [NSString stringWithContentsOfFile:@"src/NekoAsk.m"
		encoding:NSUTF8StringEncoding error:NULL];
	NSRange routes = [chain rangeOfString:@"[NekoPluginRoutes matchFor:question]"];
	NSRange edge = [chain rangeOfString:@"[NekoUnseen wantedFor:question]"];
	ok(chain != nil && routes.location != NSNotFound && edge.location != NSNotFound
	   && routes.location < edge.location,
		@"a plugin's route is asked before the edge is", nil);

	notMeasured(@"what this cannot show is whether the nine classes are the right "
	            @"nine. They came from the ten questions tests/refuse.m measured "
	            @"the shipped prompt answering wrongly, which is a better source "
	            @"than taste and is not a survey");

	[pool release];
	return NekoTestResult();
}
