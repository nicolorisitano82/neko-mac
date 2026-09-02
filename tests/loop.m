/* Whether the cat can end up talking to itself.

   This one exists because it happened. `tools/diary.py` was written to look at a
   real diary after eight days and it found a closed loop:

       91% of the diary was the cat's own remarks, 0% was anything a person said
       65 remarks, 11 of them distinct — one said 22 times
       21 durable lines, in every prompt: 0 traceable to the person or the Mac,
          16 to the cat's own remarks, 5 to nothing in that day at all
       test zqqmark → test barge → test boat → test chiatta, one non-fact
          degrading over four days, restated in durable.txt every one of them

   The mechanism, once seen, is obvious. `noteSaid` writes each remark to the
   diary; the nightly reflection reads the day back; on a day the cat spoke and
   nobody else did, the only material for a "durable fact" is the cat. Then the
   durable lines go into the next prompt, and the next remark is made out of the
   last one.

   Three things stop it, and this measures all three. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoMemory.h"

static NSString * const Mark = @"zzq-loop";

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NekoMemory *memory = [NekoMemory sharedMemory];

	printf("\n--- having said it once is a reason not to say it again ---\n");

	[memory noteSaid:[Mark stringByAppendingString:@" build lento perché progetto grande"]];

	ok([memory alreadySaidToday:
		[Mark stringByAppendingString:@" build lento perché progetto grande"]],
		@"the same remark, word for word", nil);
	ok([memory alreadySaidToday:
		[Mark stringByAppendingString:@" progetto grande, build lento"]],
		@"and the same remark reworded — which is how it filled a week", nil);
	ok(![memory alreadySaidToday:
		[Mark stringByAppendingString:@" sua sorella ha telefonato ieri sera"]],
		@"but not something else entirely", nil);
	ok(![memory alreadySaidToday:@""], @"and not nothing", nil);

	/* What the person said is not what the cat said: a question of theirs must
	   never make the cat's own remark look like a repeat. */
	[memory noteHeard:[Mark stringByAppendingString:@" quanto manca a venerdì"]];
	ok(![memory alreadySaidToday:
		[Mark stringByAppendingString:@" quanto manca a venerdì"]],
		@"and a line of theirs is not a line of its own", nil);

	printf("\n--- and the reflection is not handed the cat's own voice ---\n");

	/* Read from the source. Running the reflection needs an engine and a staged
	   yesterday, and tests/distil.m already does that; what can regress here is
	   a line somebody deletes, and a deleted line is what caused this. */
	NSString *source = [NSString stringWithContentsOfFile:@"src/NekoMemory.m"
		encoding:NSUTF8StringEncoding error:NULL];
	ok(source != nil, @"the source is where the test is run from", nil);

	NSRange reflect = [source rangeOfString:@"- (void)reflectIfDue"];
	NSRange distil = [source rangeOfString:@"- (BOOL)distilIsDue"];
	NSString *body = (reflect.location != NSNotFound && distil.location != NSNotFound
	                  && distil.location > reflect.location)
		? [source substringWithRange:NSMakeRange(reflect.location,
			distil.location - reflect.location)] : @"";
	ok([body rangeOfString:@"isEqualToString:@\"sed\""].location != NSNotFound
	   && [body rangeOfString:@"continue"].location != NSNotFound,
		@"a “sed” line is dropped before the model sees the day", nil);
	ok([body rangeOfString:@"two kinds"].location != NSNotFound,
		@"and the instructions say two kinds of note, not three", nil);
	ok([body rangeOfString:@"saysTheSameAsAnyOf:saidBefore"].location != NSNotFound,
		@"and a durable line that repeats one is not written twice", nil);

	printf("\n--- and the report that found all this still runs ---\n");

	NSString *tool = [NSString stringWithContentsOfFile:@"tools/diary.py"
		encoding:NSUTF8StringEncoding error:NULL];
	ok(tool != nil && [tool rangeOfString:@"traceable"].location != NSNotFound,
		@"tools/diary.py is there and asks where a line came from", nil);

	notMeasured(@"what this cannot measure is whether a remark was worth hearing. "
	            @"It can only say that the same one was not made twice");

	[memory forgetLinesContaining:Mark];
	ok(![memory alreadySaidToday:
		[Mark stringByAppendingString:@" build lento perché progetto grande"]],
		@"and the harness took its own lines back out of the diary", nil);

	[pool release];
	return NekoTestResult();
}
