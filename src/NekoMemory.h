/* NekoMemory */

#import <Cocoa/Cocoa.h>

/* What the cat remembers, and where you can go and read it.

   A day at a time, in plain text, in the app's own Application Support folder:
   what it noticed, what it said, what you said back. Plain text is not laziness —
   it is the only honest form for a file about somebody. You can open it, you can
   see exactly what is there, and you can delete it with the Finder if you do not
   trust the button.

   Once a day the previous day is reduced to at most a handful of durable lines —
   "works late on Tuesdays", "the deadline is Friday" — and the daily files are
   kept for thirty days and then removed. That is the shape the memory literature
   converged on: a small working set, a consolidated store, and explicit
   forgetting rather than an unbounded diary.

   Two rules hold without exception. The reflection is written by whatever
   NekoBrains says is the best engine on this Mac, which is never a remote one.
   And a remembered line is not an instruction: it came from a document or a
   window once, so it can inform what the cat says and can never authorise
   anything. */
@interface NekoMemory : NSObject
{
	NSDate *reflectedAt;
	BOOL reflecting;
}

+ (NekoMemory *)sharedMemory;

/* Where the files are, created on demand. Shown in the preferences so it can be
   opened in the Finder. */
- (NSURL *)directory;

/* One line each. Anything empty is dropped, anything long is trimmed: this is a
   diary, not a transcript. */
- (void)noteNoticed:(NSString *)observation;
- (void)noteSaid:(NSString *)line;
- (void)noteHeard:(NSString *)line;

/* The block handed to a model: the durable lines, then the tail of today. Capped
   hard, because the small local models degrade as the prompt grows and one of
   them crashed the engine before the decode was batched. Empty string when there
   is nothing worth saying. */
- (NSString *)contextForPrompt;

/* Reduces yesterday to a few durable lines, once a day, using the best on-device
   engine. Returns immediately; the work happens on a queue. */
- (void)reflectIfDue;

- (NSArray *)durableLines;

/* Housekeeping, all of it available from the preferences. */
- (NSUInteger)dayCount;
- (long long)bytesOnDisk;
- (void)pruneOldDays;
- (BOOL)forgetLinesContaining:(NSString *)text;
- (void)forgetEverything;

@end
