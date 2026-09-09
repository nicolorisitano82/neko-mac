/* More than one model to draw with, and the reason that is not just a longer
   list.

   The picture catalogue held one entry, and both places that wanted it said
   -firstObject — so there was nothing to choose and nothing choosing. Adding
   rows to it would have been a few lines. What makes it work is that a turbo
   checkpoint is not SD 1.5 with a different file name: it is distilled to draw
   in four steps with the guidance turned off, and handed SD 1.5's fourteen steps
   at a guidance of seven it comes back as mush.

   So the recipe travels with the model, and this is what checks that it does —
   including the argument the helper is actually launched with, because a recipe
   nothing passes on is a comment. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoModelStore.h"
#import "NekoPainter.h"

int main(void)
{
	[NSApplication sharedApplication];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NekoModelStore *store = [NekoModelStore sharedStore];
	NSArray *pictures = [store pictureCatalogue];

	printf("--- what there is to choose between ---\n");
	NSEnumerator *e = [pictures objectEnumerator];
	NekoLocalModel *model;
	while((model = [e nextObject]) != nil)
		printf("      %-24s %5.1f GB  %2d steps  cfg %.1f  %d px\n",
			[[model name] UTF8String], (double)[model expectedBytes] / 1e9,
			[model drawSteps], [model drawGuidance], [model drawSide]);

	ok([pictures count] > 1, @"there is more than one, which is the point",
		[NSString stringWithFormat:@"%lu", (unsigned long)[pictures count]]);

	printf("\n--- and every one of them brought its own recipe ---\n");
	NSUInteger complete = 0, turbo = 0;
	e = [pictures objectEnumerator];
	while((model = [e nextObject]) != nil) {
		BOOL sane = [model drawSteps] > 0 && [model drawGuidance] > 0.0f
		         && [model drawSide] >= 128;
		if(sane)
			complete++;
		/* A distilled one: few steps, and the guidance off. */
		if([model drawSteps] <= 4 && [model drawGuidance] <= 1.5f)
			turbo++;
		ok(sane, [model name],
			[NSString stringWithFormat:@"%d steps, cfg %.1f, %d px",
				[model drawSteps], [model drawGuidance], [model drawSide]]);
	}
	ok(complete == [pictures count],
		@"none of them left to inherit somebody else's",
		[NSString stringWithFormat:@"%lu of %lu",
			(unsigned long)complete, (unsigned long)[pictures count]]);
	ok(turbo > 0, @"and the distilled ones are distinguishable from the rest",
		[NSString stringWithFormat:@"%lu of them draw in four steps at cfg 1",
			(unsigned long)turbo]);

	printf("\n--- choosing one, and being given that one ---\n");
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NekoPainter *painter = [NekoPainter sharedPainter];
	NSUInteger picked = 0;
	e = [pictures objectEnumerator];
	while((model = [e nextObject]) != nil) {
		[defaults setObject:[model identifier] forKey:NekoDrawModelKey];
		if([[[painter model] identifier] isEqualToString:[model identifier]])
			picked++;
		ok([[[painter model] identifier] isEqualToString:[model identifier]],
			[NSString stringWithFormat:@"asked for %@, drawn with %@",
				[model name], [[painter model] name]], nil);
	}
	ok(picked == [pictures count], @"each of them can actually be chosen",
		[NSString stringWithFormat:@"%lu of %lu",
			(unsigned long)picked, (unsigned long)[pictures count]]);

	/* And nothing chosen at all still draws with something. */
	[defaults removeObjectForKey:NekoDrawModelKey];
	ok([painter model] != nil, @"with nothing chosen it falls back to the first",
		[[painter model] name]);
	[defaults setObject:@"there-is-no-such-model" forKey:NekoDrawModelKey];
	ok([painter model] != nil, @"and a name it does not know does not leave it empty",
		[[painter model] name]);
	[defaults removeObjectForKey:NekoDrawModelKey];

	printf("\n--- and the recipe reaches the helper, which is the only part that draws ---\n");

	/* A recipe nothing passes on is a comment. The guidance is read off the
	   model in -draw:, so this checks the source: the flag exists, and it is not
	   a number written into the file. */
	NSString *source = [NSString stringWithContentsOfFile:@"src/NekoPainter.m"
		encoding:NSUTF8StringEncoding error:NULL];
	if([source length] == 0) {
		notMeasured(@"the source is not beside this harness, so the last two "
		            @"checks were skipped");
	} else {
		ok([source rangeOfString:@"--cfg-scale"].location != NSNotFound,
			@"the helper is told the guidance at all", nil);
		ok([source rangeOfString:@"[chosen drawGuidance]"].location != NSNotFound,
			@"and told the chosen model's, not one written into the file", nil);
		ok([source rangeOfString:@"pictureCatalogue] firstObject]"].location
		   == NSNotFound
		   || [source rangeOfString:@"NekoDrawModelKey"].location != NSNotFound,
			@"and nothing here still takes whichever happened to be first", nil);
	}

	printf("\n--- and the room check reaches this tab too ---\n");

	/* The previous release added a memory and disk check before a download, and
	   put it inside the action for models that answer in words — which left the
	   one for models that draw with no check at all, and the largest of those is
	   four gigabytes. Checked against the source, because the alert is modal and
	   a harness cannot press a button in it. */
	NSString *controller = [NSString stringWithContentsOfFile:@"src/NekoController.m"
		encoding:NSUTF8StringEncoding error:NULL];
	if([controller length] == 0) {
		notMeasured(@"the controller is not beside this harness, so the shared "
		            @"guard was not checked");
	} else {
		NSUInteger asks = 0;
		NSRange from = NSMakeRange(0, [controller length]);
		NSRange found;
		while((found = [controller rangeOfString:@"[self mayDownload:"
		                                 options:0 range:from]).location != NSNotFound) {
			asks++;
			from = NSMakeRange(NSMaxRange(found), [controller length] - NSMaxRange(found));
		}
		ok(asks == 2, @"both downloads ask whether there is room first",
			[NSString stringWithFormat:@"%lu of the 2 tabs", (unsigned long)asks]);
	}

	/* And that the picture models are judged by the same arithmetic, which is
	   what makes that guard mean anything here. */
	NSUInteger judged = 0;
	e = [pictures objectEnumerator];
	while((model = [e nextObject]) != nil)
		if([model memoryNeeded] > [model expectedBytes])
			judged++;
	ok(judged == [pictures count],
		@"and each of them costs more to run than to fetch, as the rule says",
		[NSString stringWithFormat:@"%lu of %lu",
			(unsigned long)judged, (unsigned long)[pictures count]]);

	notMeasured(@"what any of them draws. Four checkpoints times a prompt is a "
	            @"quarter of an hour of GPU and a judgement about pictures, which "
	            @"is a person's to make — this checks that each is asked for the "
	            @"way it wants to be asked, not that the result is any good");

	printf("\n%d checks, %d failed\n\n", NekoTestChecks, NekoTestFailures);
	[pool release];
	return NekoTestFailures > 0 ? 1 : 0;
}
