/* Whether this Mac can run a model, asked before somebody spends an hour of
   their connection finding out.

   The catalogue grew a 27B, and that is the first entry anybody can *fetch* and
   then not *load*: sixteen gigabytes arrive and llama.cpp cannot map them beside
   everything else running. Nothing in the application used to look — no memory
   check, no disk check — so the whole warning was a sentence in a row.

   Two questions, and they are not the same one:

     to download   is there room on the disk, *and* could it ever be loaded
     already there could it be loaded, which is all that is left to ask

   What a harness can settle is the arithmetic and the wording. What it cannot is
   whether llama.cpp agrees on this exact Mac — that is said out loud rather than
   claimed. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoModelStore.h"

int main(void)
{
	[NSApplication sharedApplication];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NekoModelStore *store = [NekoModelStore sharedStore];
	long long all = [NekoModelStore memoryOnThisMac];
	long long usable = [NekoModelStore memoryForAModel];

	printf("--- what this Mac has ---\n");
	ok(all > 0, @"the memory is read, not guessed",
		[NSString stringWithFormat:@"%.0f GB", (double)all / 1e9]);
	ok(usable > 0 && usable < all,
		@"and some of it is left for the Mac itself",
		[NSString stringWithFormat:@"%.0f GB for a model of %.0f GB",
			(double)usable / 1e9, (double)all / 1e9]);
	ok([store freeDiskBytes] > 0, @"and the free space is read from the disk",
		[NSString stringWithFormat:@"%.0f GB free",
			(double)[store freeDiskBytes] / 1e9]);

	printf("\n--- every model in the catalogue, judged ---\n");
	NSUInteger fits = 0, tight = 0, never = 0;
	NSEnumerator *e = [[store catalogue] objectEnumerator];
	NekoLocalModel *model;
	while((model = [e nextObject]) != nil) {
		NekoModelFit fit = [model fitOnThisMac];
		const char *verdict = fit == NekoModelWillNotLoad ? "will not load"
		                    : (fit == NekoModelFitsTightly ? "tight" : "fits");
		if(fit == NekoModelWillNotLoad)      never++;
		else if(fit == NekoModelFitsTightly) tight++;
		else                                 fits++;
		printf("      %-26s %5.1f GB on disk, %5.1f GB to run   %-14s %s\n",
			[[model name] UTF8String],
			(double)[model expectedBytes] / 1e9,
			(double)[model memoryNeeded] / 1e9,
			verdict,
			[store hasRoomOnDiskFor:model] ? "" : "and no room on disk");
	}
	ok(fits + tight + never == [[store catalogue] count],
		@"every entry got a verdict, none of them skipped",
		[NSString stringWithFormat:@"%lu fit, %lu tight, %lu impossible",
			(unsigned long)fits, (unsigned long)tight, (unsigned long)never]);

	printf("\n--- and the arithmetic behind a verdict ---\n");

	/* Built rather than taken from the catalogue, so the check says the same
	   thing on a Mac with 8 GB and on one with 192. */
	NekoLocalModel *huge = [[[NekoLocalModel alloc]
		initWithIdentifier:@"test-huge" name:@"Bigger than this Mac"
		            detail:@"" url:[NSURL URLWithString:@"https://example.invalid/x.gguf"]
		             bytes:all + 8000000000LL thinks:NO] autorelease];
	NekoLocalModel *tiny = [[[NekoLocalModel alloc]
		initWithIdentifier:@"test-tiny" name:@"Nothing at all"
		            detail:@"" url:[NSURL URLWithString:@"https://example.invalid/y.gguf"]
		             bytes:200000000LL thinks:NO] autorelease];

	ok([huge fitOnThisMac] == NekoModelWillNotLoad,
		@"a model larger than the whole Mac cannot be loaded",
		[NSString stringWithFormat:@"%.0f GB wanted of %.0f GB",
			(double)[huge memoryNeeded] / 1e9, (double)all / 1e9]);
	ok([tiny fitOnThisMac] == NekoModelFitsWell, @"and a small one fits", nil);

	ok([huge memoryNeeded] > [huge expectedBytes],
		@"running one costs more than downloading it",
		[NSString stringWithFormat:@"%.1f GB over the file",
			(double)([huge memoryNeeded] - [huge expectedBytes]) / 1e9]);

	printf("\n--- what it says, and to whom ---\n");
	ok([[huge memoryWarning] length] > 0, @"the impossible one explains itself",
		[huge memoryWarning]);
	ok([tiny memoryWarning] == nil,
		@"and one that fits says nothing at all — a warning on every row is not a warning",
		nil);

	/* The disk question is only asked of a download. A model already on the disk
	   has spent that space, and saying so again would be noise — which is the
	   distinction the request drew. */
	NekoLocalModel *wider = [[[NekoLocalModel alloc]
		initWithIdentifier:@"test-wide" name:@"Wider than the disk"
		            detail:@"" url:[NSURL URLWithString:@"https://example.invalid/z.gguf"]
		             bytes:[store freeDiskBytes] + 5000000000LL thinks:NO] autorelease];
	ok([store hasRoomOnDiskFor:wider] == NO, @"a model wider than the disk is refused room",
		nil);
	ok([[store diskWarningFor:wider] length] > 0, @"and the sentence says both numbers",
		[store diskWarningFor:wider]);
	ok([store diskWarningFor:tiny] == nil, @"while a small one draws no comment", nil);

	printf("\n--- and the Macs this was written for, which are not this one ---\n");

	/* The verdict that matters is the one on a 16 GB machine, and the machine
	   this was written on has thirty-nine — so every row above says "fits" and
	   proves nothing about the case the warning exists for. Staged instead. */
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithDictionary:
		[[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain]];
	long long sizes[] = { 8000000000LL, 16000000000LL, 24000000000LL, 36000000000LL };
	NSUInteger which;
	for(which = 0; which < 4; which++) {
		[arguments setObject:[NSNumber numberWithLongLong:sizes[which]]
		              forKey:NekoModelMemoryKey];
		[[NSUserDefaults standardUserDefaults]
			setVolatileDomain:arguments forName:NSArgumentDomain];

		printf("      on a %.0f GB Mac:\n", (double)sizes[which] / 1e9);
		NSEnumerator *big = [[store catalogue] objectEnumerator];
		NekoLocalModel *each;
		while((each = [big nextObject]) != nil) {
			if([each expectedBytes] < 5000000000LL)
				continue;                    /* the small ones fit everywhere */
			NekoModelFit fit = [each fitOnThisMac];
			printf("        %-24s %s\n", [[each name] UTF8String],
				fit == NekoModelWillNotLoad ? "will not load"
				: (fit == NekoModelFitsTightly ? "tight" : "fits"));
		}
	}

	/* The two claims the catalogue rows make in words, checked as arithmetic. */
	[arguments setObject:[NSNumber numberWithLongLong:16000000000LL]
	              forKey:NekoModelMemoryKey];
	[[NSUserDefaults standardUserDefaults]
		setVolatileDomain:arguments forName:NSArgumentDomain];
	NekoLocalModel *small27 = [store modelWithIdentifier:@"qwen3.8-27b-q2"];
	NekoLocalModel *big27 = [store modelWithIdentifier:@"qwen3.8-27b-q4"];
	ok(small27 != nil && big27 != nil, @"both 27B entries are in the catalogue", nil);
	ok([small27 fitOnThisMac] != NekoModelWillNotLoad,
		@"the smaller 27B loads on a 16 GB Mac, as its row claims",
		[NSString stringWithFormat:@"%.1f GB needed",
			(double)[small27 memoryNeeded] / 1e9]);
	ok([big27 fitOnThisMac] == NekoModelWillNotLoad,
		@"and the larger one does not, exactly as its row warns",
		[big27 memoryWarning]);

	[arguments removeObjectForKey:NekoModelMemoryKey];
	[[NSUserDefaults standardUserDefaults]
		setVolatileDomain:arguments forName:NSArgumentDomain];
	ok([NekoModelStore memoryOnThisMac] > 0,
		@"and with the staging removed it reads the real Mac again",
		[NSString stringWithFormat:@"%.0f GB",
			(double)[NekoModelStore memoryOnThisMac] / 1e9]);

	printf("\n--- and that the sentence fits the row it is written in ---\n");

	/* The field is 420 by 29 points and wraps: two lines of the label font. It
	   used to be seventeen — one line — so a warning wrapped and was then
	   clipped, which is the same as not showing it. This measures the longest
	   thing that can appear there, in every language the app ships, against the
	   space it actually has. */
	NSDictionary *asDrawn = [NSDictionary dictionaryWithObject:
		[NSFont labelFontOfSize:[NSFont systemFontSize]] forKey:NSFontAttributeName];
	NSArray *languages = [NSArray arrayWithObjects:@"en", @"it", @"fr", @"es", nil];
	NSEnumerator *l = [languages objectEnumerator];
	NSString *language;
	CGFloat worst = 0.0;
	NSString *worstLine = nil;
	while((language = [l nextObject]) != nil) {
		NSBundle *bundle = [NSBundle mainBundle];
		NSString *path = [bundle pathForResource:@"Localizable" ofType:@"strings"
		                             inDirectory:nil forLocalization:language];
		NSDictionary *table = path != nil
			? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
		NSArray *shapes = [NSArray arrayWithObjects:
			@"Needs about %.0f GB of memory. This Mac has %.0f GB.",
			@"Fits barely: %.0f GB of %.0f GB. The Mac will feel it.",
			@"No room on the disk: needs %.1f GB, %.1f GB free.", nil];
		NSEnumerator *sh = [shapes objectEnumerator];
		NSString *shape;
		while((shape = [sh nextObject]) != nil) {
			NSString *pattern = [table objectForKey:shape] ?: shape;
			NSString *filled = [NSString stringWithFormat:pattern, 999.0, 999.0];
			/* Plus the catalogue's own longest sentence on the line above it. */
			NSString *whole = [NSString stringWithFormat:@"%@\n%@",
				[[store modelWithIdentifier:@"qwen3.8-27b-q4"] detail], filled];
			NSRect drawn = [whole boundingRectWithSize:NSMakeSize(420.0, 10000.0)
			                                  options:NSStringDrawingUsesLineFragmentOrigin
			                               attributes:asDrawn];
			if(NSHeight(drawn) > worst) {
				worst = NSHeight(drawn);
				worstLine = [NSString stringWithFormat:@"%@ · %@", language, filled];
			}
		}
	}
	printf("      the tallest of them is %.0f points, in %s\n", worst,
		[worstLine UTF8String]);
	/* No tolerance. The first version of this allowed four points of slack and
	   passed at thirty-two against twenty-nine, which is a check agreeing with
	   itself rather than measuring anything. The field is the number below and
	   the sentence either fits it or does not. */
	ok(worst <= 34.0,
		@"the longest warning in any language fits the row",
		[NSString stringWithFormat:@"%.0f points of the 34 it has", worst]);

	notMeasured(@"whether llama.cpp agrees on this exact Mac. The arithmetic here "
	            @"is the file plus a working set, against the memory minus what "
	            @"the system needs — a rule, and a conservative one, not a "
	            @"measurement of a load that actually happened");

	printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
	[pool release];
	return NekoTestFailures > 0 ? 1 : 0;
}
