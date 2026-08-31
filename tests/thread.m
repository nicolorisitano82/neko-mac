/* How much of a conversation the cat still has in hand.

   It used to be one turn, for three minutes, on the grounds that more history
   costs a small local model more than it buys it. Half of that is still true and
   is why there is a character budget; the other half was an assumption, and this
   Mac's own diary contradicted it — counted from timestamps alone, of fourteen
   runs of questions inside three minutes of each other, **six reached a third
   turn** and two reached a fifth. Carrying one turn meant that by the third
   question the first thing somebody said had gone.

   So three turns, and bounded three ways, because the reason for the old rule did
   not go away: a count, a clock, and a character cap spent newest first. This
   harness is mostly about the bounds. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoAsk.h"

@interface NekoAsk (TestOnly)
- (void)cancelEverything;
@end

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NekoAsk *ask = [NekoAsk sharedAsk];
	[ask cancelEverything];

	printf("\n--- a third question can see the first ---\n");

	[ask rememberQuestion:@"come si chiama il gatto di Schrödinger"
	               answer:@"Non ha nome, ed è il punto."];
	[ask rememberQuestion:@"e quello di Pavlov?"
	               answer:@"Quello era un cane."];
	[ask rememberQuestion:@"e allora chi aveva il gatto?"
	               answer:@"Schrödinger, e non lo aveva davvero."];

	NSString *thread = [ask threadForPrompt];
	ok([thread rangeOfString:@"Schrödinger"].location != NSNotFound,
		@"the first question is still there at the third", nil);
	ok([thread rangeOfString:@"Pavlov"].location != NSNotFound,
		@"and so is the second", nil);

	/* Oldest first, because a model reads a conversation forwards. */
	NSRange first = [thread rangeOfString:@"non ha nome" options:NSCaseInsensitiveSearch];
	NSRange last = [thread rangeOfString:@"non lo aveva davvero"];
	ok(first.location != NSNotFound && last.location != NSNotFound
	   && first.location < last.location,
		@"in the order they were said", nil);

	printf("\n--- and never more than three of them ---\n");

	[ask rememberQuestion:@"e il quarto?" answer:@"Il quarto sposta il primo fuori."];
	NSString *four = [ask threadForPrompt];
	ok([four rangeOfString:@"Schrödinger, e non lo aveva"].location != NSNotFound,
		@"the newest is kept", nil);
	ok([four rangeOfString:@"Non ha nome"].location == NSNotFound,
		@"and the oldest is gone rather than the newest", four);

	printf("\n--- and never more than a few hundred characters ---\n");

	[ask cancelEverything];
	NSMutableString *essay = [NSMutableString string];
	NSUInteger i;
	for(i = 0; i < 40; i++)
		[essay appendString:@"una risposta molto lunga che continua e continua. "];
	NSUInteger j;
	for(j = 0; j < 3; j++)
		[ask rememberQuestion:[NSString stringWithFormat:@"domanda %lu",
			(unsigned long)j] answer:essay];
	NSString *long_ = [ask threadForPrompt];
	ok([long_ length] <= 700,
		@"three long turns are cut down to something a small model has room around",
		[NSString stringWithFormat:@"%lu characters", (unsigned long)[long_ length]]);
	ok([long_ length] > 0, @"and not cut down to nothing", nil);

	printf("\n--- and it still forgets ---\n");

	/* The clock is the same one it always was: a conversation nobody continued is
	   over, and this is what keeps the thread from following somebody into the
	   afternoon. Reached through the ivar because the point is the age of the
	   turns rather than the age of the last one. */
	Ivar found = class_getInstanceVariable([NekoAsk class], "turns");
	NSMutableArray *turns = found != NULL
		? (NSMutableArray *)object_getIvar(ask, found) : nil;
	Ivar lastFound = class_getInstanceVariable([NekoAsk class], "lastTurn");
	if(turns == nil || lastFound == NULL) {
		notMeasured(@"the turns are not kept where this test expects them");
	} else {
		/* Aged by hand: every turn moved four minutes into the past. */
		NSUInteger k;
		for(k = 0; k < [turns count]; k++) {
			NSMutableDictionary *old = [NSMutableDictionary dictionaryWithDictionary:
				[turns objectAtIndex:k]];
			[old setObject:[NSDate dateWithTimeIntervalSinceNow:-240.0] forKey:@"When"];
			[turns replaceObjectAtIndex:k withObject:old];
		}
		object_setIvar(ask, lastFound,
			[[NSDate dateWithTimeIntervalSinceNow:-240.0] retain]);
		ok([[ask threadForPrompt] length] == 0,
			@"four minutes later there is no conversation to continue", nil);
	}

	[ask cancelEverything];
	int result = NekoTestResult();
	[pool release];
	return result;
}
