/* That a reasoning model's notes never reach the bubble.

   Reported from use, and it is the worst thing this application has shown
   anybody. Asked for Apple's share price, with Qwen3.5 4B chosen, the cat
   answered:

       <think> Thinking Process: 1. **Analyze Request:** * **Role:** fox living
       someone's computer desktop (quick, sly, pleased own cleverness). *
       **Task:** Answer que…

   The model's own scratchpad, in the speech bubble, with the persona quoted
   back verbatim. Nothing in the application took it out, and NekoSense does not:
   by design it judges only the remarks the cat makes on its own, never an answer
   to a question.

   The cause is upstream of the code. That catalogue entry was added by checking
   its URL, its bytes and its licence, and never asking what the model **writes**.
   So there are two halves here: the stripping, and a required argument on every
   catalogue entry saying whether the model reasons — and the second half is why
   the same mistake cannot be made silently again.

   The slow arm is the one that would have caught it. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoLocalProvider.h"
#import "NekoModelStore.h"
#import "NekoAnswerProvider.h"

static NSString *ask(id provider, NSString *question, NSString *instructions)
{
	__block NSString *said = nil;
	__block BOOL done = NO;
	[provider askQuestion:question instructions:instructions
	          completion:^(NSString *text, NSError *error) {
		said = [text retain];
		done = YES;
	}];
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:180.0];
	while(!done && [until timeIntervalSinceNow] > 0.0)
		spin(0.05);
	return said ?: @"";
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- the block, taken out ---\n");

	NSArray *cases = [NSArray arrayWithObjects:
		@"<think>notes notes</think>Sono le tre.",              @"Sono le tre.",
		@"<think>notes</think>\n\nSono le tre.",                @"Sono le tre.",
		@"Sono le tre.<think>afterwards</think>",               @"Sono le tre.",
		@"<THINK>shouting</THINK>Sono le tre.",                 @"Sono le tre.",
		@"<thinking>other tag</thinking>Sono le tre.",          @"Sono le tre.",
		@"<reasoning>and another</reasoning>Sono le tre.",      @"Sono le tre.",
		@"Sono le tre.",                                        @"Sono le tre.",
		/* The budget ran out inside the notes: everything after the opening tag
		   is more of the same, so nothing is shown at all. */
		@"<think>it never finished thinking",                   @"",
		@"Sono le tre.<think>and then it wandered off",         @"Sono le tre.",
		@"<think>a</think>Uno.<think>b</think>Due.",            @"Uno.Due.",
		nil];
	NSUInteger i;
	for(i = 0; i < [cases count]; i += 2) {
		NSString *raw = [cases objectAtIndex:i];
		NSString *want = [cases objectAtIndex:i + 1];
		NSString *got = [NekoLocalProvider withoutReasoning:raw];
		ok([got isEqualToString:want],
			[raw stringByReplacingOccurrencesOfString:@"\n" withString:@"⏎"],
			[NSString stringWithFormat:@"“%@”", got]);
	}

	ok([[NekoLocalProvider withoutReasoning:nil] length] == 0,
		@"and nothing at all is still nothing", nil);

	printf("\n--- the catalogue says which ones do it ---\n");

	NekoModelStore *store = [NekoModelStore sharedStore];
	NSUInteger thinkers = 0, total = 0;
	NSEnumerator *e = [[store catalogue] objectEnumerator];
	NekoLocalModel *model;
	while((model = [e nextObject]) != nil) {
		total++;
		if([model thinks])
			thinkers++;
		printf("      %-26s %s\n", [[model identifier] UTF8String],
			[model thinks] ? "reasons first" : "answers straight");
	}
	ok(total > 0 && thinkers > 0 && thinkers < total,
		@"some of them reason and some do not, and each one says",
		[NSString stringWithFormat:@"%lu of %lu",
			(unsigned long)thinkers, (unsigned long)total]);
	ok([[store modelWithIdentifier:@"qwen3.5-4b-q4"] thinks],
		@"including the one this was reported on", nil);
	ok(![[store modelWithIdentifier:@"gemma-3-4b-it-q4"] thinks],
		@"and not the one that does not", nil);

	if(![[NSUserDefaults standardUserDefaults] boolForKey:@"slow"]) {
		notMeasured(@"the arm that would have caught this — every installed model "
		            @"asked a question, and no answer allowed to carry a tag — "
		            @"needs --slow");
		[pool release];
		return NekoTestResult();
	}

	printf("\n--- and no installed model gets a tag past the provider ---\n");

	NSUInteger asked = 0;
	e = [[store catalogue] objectEnumerator];
	while((model = [e nextObject]) != nil) {
		if([store installedURLForIdentifier:[model identifier]] == nil)
			continue;
		NekoLocalProvider *local = [[[NekoLocalProvider alloc] init] autorelease];
		[local setPreferredModel:[model identifier]];
		NSString *answer = ask(local, @"quotazione oggi borsa Apple",
			@"You are a small pixel-art cat. Answer in Italian, in one short "
			@"sentence.");
		asked++;
		NSString *shown = [answer stringByReplacingOccurrencesOfString:@"\n"
		                                                    withString:@" "];
		printf("      %-26s %s\n", [[model identifier] UTF8String],
			[shown length] > 76 ? [[shown substringToIndex:76] UTF8String]
			                    : [shown UTF8String]);
		ok([answer rangeOfString:@"<think" options:NSCaseInsensitiveSearch].location
		   == NSNotFound
		   && [answer rangeOfString:@"</think" options:NSCaseInsensitiveSearch].location
		      == NSNotFound,
			[NSString stringWithFormat:@"%@ shows no scratchpad",
				[model identifier]], nil);
		/* And the stripper must not have eaten the whole answer: a model that
		   reasons still has to say something afterwards. */
		ok([answer length] > 0,
			[NSString stringWithFormat:@"%@ still says something after it",
				[model identifier]],
			[NSString stringWithFormat:@"%lu characters",
				(unsigned long)[answer length]]);
	}
	if(asked == 0)
		notMeasured(@"no local model installed where this harness can see it");

	notMeasured(@"what this cannot cover is the channel syntax some other models "
	            @"use instead of a tag — nothing in this catalogue emits it, and "
	            @"writing against it would be guesswork");

	[pool release];
	return NekoTestResult();
}
