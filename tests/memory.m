/* The diary: that it can be read, that it is bounded, that it can be deleted,
   and that it never grows into more than a small model can hold.

   Everything here runs against the real file in Application Support, which is
   why every line it writes is marked and removed again at the end. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoMemory.h"
#import "NekoBrains.h"

static NSString * const NekoTestMark = @"zzq-test";

int main(int argc, const char *argv[])
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL slow = [[NSUserDefaults standardUserDefaults] boolForKey:@"slow"];
	NekoMemory *memory = [NekoMemory sharedMemory];

	printf("\n--- what it writes down ---\n");

	[memory noteNoticed:[NSString stringWithFormat:@"%@ Xcode, forty minutes", NekoTestMark]];
	[memory noteSaid:[NSString stringWithFormat:@"%@ that build has been going a while", NekoTestMark]];
	[memory noteHeard:[NSString stringWithFormat:@"%@ it always does on Fridays", NekoTestMark]];

	NSString *today = [memory contextForPrompt];
	ok([today rangeOfString:NekoTestMark].location != NSNotFound,
		@"three kinds of line, and they come back", nil);
	ok([today length] <= 1000,
		@"the block a model is handed is capped",
		[NSString stringWithFormat:@"%lu characters", (unsigned long)[today length]]);

	NSMutableString *huge = [NSMutableString stringWithString:NekoTestMark];
	while([huge length] < 4000)
		[huge appendString:@" and then something else happened as well"];
	[memory noteNoticed:huge];
	ok([[memory contextForPrompt] length] <= 1000,
		@"and stays capped however long the day was",
		[NSString stringWithFormat:@"%lu characters",
			(unsigned long)[[memory contextForPrompt] length]]);

	NSString *path = [[memory directory] path];
	ok([[NSFileManager defaultManager] fileExistsAtPath:path],
		@"it is a folder somebody can open", path);
	printf("      %lld bytes over %lu day(s)\n",
		[memory bytesOnDisk], (unsigned long)[memory dayCount]);

	printf("\n--- and what it forgets ---\n");

	long long before = [memory bytesOnDisk];
	BOOL removed = [memory forgetLinesContaining:NekoTestMark];
	ok(removed, @"a line can be taken out by what is in it", nil);
	ok([[memory contextForPrompt] rangeOfString:NekoTestMark].location == NSNotFound,
		@"and leaves no trace behind it",
		[NSString stringWithFormat:@"%lld bytes → %lld", before, [memory bytesOnDisk]]);

	if(slow) {
		printf("\n--- the reflection ---\n");
		notMeasured(@"the reflection runs once a day and needs yesterday's file; "
		            "it is measured in docs/truelife-roadmap.md rather than here");
	}

	int result = NekoTestResult();
	[pool release];
	return result;
}
