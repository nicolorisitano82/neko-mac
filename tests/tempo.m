/* How long a finished answer waits before it is shown.

   Delays scaled to the weight of a reply raise perceived humanness and social
   presence in chat, and a typing indicator is what makes the wait tolerable —
   this app has had the indicator since the beginning, in the shape of a walking
   paw. It cuts the other way for anything factual: asked the time, fast is the
   answer. So this measures the arithmetic and the exemptions, which is all a
   harness can do. Whether it feels quicker or more considered is two builds and a
   person, and that is said out loud at the end rather than pretended. */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "support.h"
#import "NekoAsk.h"
#import "NekoBubble.h"
#import "MyPanel.h"
#import "NekoController.h"

@interface NekoAsk (Testing)
- (void)cancelEverything;
- (void)finish;
- (void)answer:(NSString *)text;
- (void)ask:(NSString *)question;
@end

@interface TestAsk : NekoAsk
@end
@implementation TestAsk
- (BOOL)speechAlreadyAllowed { return NO; }   /* no beat in the way of the timing */
@end

static NSString *ofLength(NSUInteger length)
{
	NSMutableString *text = [NSMutableString string];
	while([text length] < length)
		[text appendString:@"una risposta abbastanza breve "];
	return [text substringToIndex:length];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:YES forKey:NekoAskTempoKey];

	TestAsk *ask = [[TestAsk alloc] init];
	Ivar found = class_getInstanceVariable([NekoAsk class], "bubble");
	NekoBubble *bubble = (NekoBubble *)object_getIvar(ask, found);
	Ivar asked = class_getInstanceVariable([NekoAsk class], "askingAbout");

	printf("\n--- the arithmetic ---\n");

	object_setIvar(ask, asked, [@"perché il build è lento?" copy]);
	NSTimeInterval brief = [ask tempoFor:ofLength(20)];
	NSTimeInterval middling = [ask tempoFor:ofLength(60)];
	NSTimeInterval full = [ask tempoFor:ofLength(150)];
	NSTimeInterval long_ = [ask tempoFor:ofLength(400)];
	printf("      20 characters %.2f s, 60 %.2f s, 150 %.2f s, 400 %.2f s\n",
		brief, middling, full, long_);
	ok(brief > 0.0 && middling > brief && full > middling,
		@"a longer answer waits a little longer", nil);
	ok(full <= 0.9, @"and nothing waits as long as a second",
		[NSString stringWithFormat:@"%.2f s", full]);
	ok(long_ == 0.0, @"a long answer waits not at all: it streamed in", nil);

	printf("\n--- and the exemptions ---\n");

	object_setIvar(ask, asked, [@"che ore sono?" copy]);
	ok([ask tempoFor:ofLength(40)] == 0.0,
		@"asked the time, fast is the answer", nil);
	object_setIvar(ask, asked, [@"quanto è acceso il Mac?" copy]);
	ok([ask tempoFor:ofLength(40)] == 0.0, @"the uptime too", nil);

	object_setIvar(ask, asked, [@"perché il build è lento?" copy]);
	[defaults setBool:NO forKey:NekoAskTempoKey];
	ok([ask tempoFor:ofLength(40)] == 0.0, @"and none of it with the switch off", nil);
	[defaults setBool:YES forKey:NekoAskTempoKey];

	printf("\n--- what it looks like from outside ---\n");

	MyPanel *panel = [[MyPanel alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, 32.0f, 32.0f)
	                                           styleMask:NSWindowStyleMaskBorderless
	                                             backing:NSBackingStoreBuffered
	                                               defer:NO];
	[[NekoController sharedController] setPanel:panel];
	object_setIvar(ask, asked, [@"perché il build è lento?" copy]);
	NSString *reply = @"Il build è lento perché il progetto è grande.";
	NSTimeInterval expected = [ask tempoFor:reply];
	NSDate *finished = [NSDate date];
	[ask answer:reply];
	spin(0.05);
	BOOL heldBack = ![bubble isShowing]
		|| [[(NSTextField *)[[[bubble contentView] subviews] firstObject] stringValue]
			rangeOfString:@"progetto"].location == NSNotFound;
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:3.0];
	while([until timeIntervalSinceNow] > 0.0) {
		spin(0.02);
		NSString *shown = [(NSTextField *)[[[bubble contentView] subviews] firstObject] stringValue];
		if([shown rangeOfString:@"progetto"].location != NSNotFound)
			break;
	}
	NSTimeInterval waited = -[finished timeIntervalSinceNow];
	printf("      expected %.2f s, the words appeared after %.2f s\n", expected, waited);
	ok(heldBack, @"the answer is not on screen the instant it is ready", nil);
	ok(waited > expected * 0.6 && waited < expected + 0.6,
		@"and arrives about a beat later",
		[NSString stringWithFormat:@"%.2f s against %.2f s", waited, expected]);

	[ask cancelEverything];
	spin(0.2);

	printf("\n--- what a harness cannot say ---\n");
	notMeasured(@"whether this feels quicker or more considered. Two builds, "
	            "twenty questions, one person, blind — and the finding it comes "
	            "from is about chat, where waiting is normal, so a desktop pet "
	            "may well be the case where it is wrong.");

	[defaults removeObjectForKey:NekoAskTempoKey];
	int result = NekoTestResult();
	[pool release];
	return result;
}
