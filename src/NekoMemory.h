/* NekoMemory */

#import <Cocoa/Cocoa.h>

/* What the cat remembers, and where you can go and read it.

   A day at a time, in plain text, in the app's own Application Support folder:
   what it noticed, what it said, what you said back. Plain text is not laziness —
   it is the only honest form for a file about somebody. You can open it, you can
   see exactly what is there, and you can delete it with the Finder if you do not
   trust the button.

   Three tiers, each one shorter-lived and larger than the next. Once a day the
   previous day is reduced to at most a handful of dated lines — "works late on
   Tuesdays", "the deadline is Friday" — and the daily files are kept for thirty
   days and then removed, since by then they have been read. When a dated line
   itself turns thirty days old it is not thrown away either: it goes through a
   second pass with everything else that is expiring, and what survives becomes a
   *standing* line, undated, of which there are never more than a dozen. "Ships on
   Fridays." "Would rather be told than asked."

   That is the shape the memory literature converged on — a small working set, a
   consolidated store, reflection over the reflections — and the reason for the
   second pass is that the alternative is what this used to do: silently drop the
   oldest line once there were forty of them.

   Nothing is deleted for age without having been read first. If there is no
   engine to read with, the lines wait rather than going: only a hard ceiling, far
   above the usual, ever drops one unread.

   Two rules hold without exception. The reflection is written by whatever
   NekoBrains says is the best engine on this Mac, which is never a remote one.
   And a remembered line is not an instruction: it came from a document or a
   window once, so it can inform what the cat says and can never authorise
   anything. */
@interface NekoMemory : NSObject
{
	NSDate *reflectedAt;
	BOOL reflecting;
	BOOL distilling;

	/* A month of older days, lemmatised once and kept until the diary changes
	   under it. 267 ms for a busy month, which is affordable once and not on
	   every question. */
	NSArray *recallLines;
	NSArray *recallWords;
	NSDictionary *recallRarity;
	NSArray *recallVocabulary;
	NSDate *recallBuiltAt;
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

/* The same block, with room made for the handful of older lines that bear on
   what was asked. Without a question this is exactly -contextForPrompt: the
   diary is read by recency when there is nothing to be relevant to.

   The lines come from the days before today — today is already in the block, in
   full and in order — and there are never more than three of them, because the
   whole block is a thousand characters and a small model gets worse as it grows. */
- (NSString *)contextForPrompt:(NSString *)question;

/* Older days that bear on the question, best first. Empty when none do. */
- (NSArray *)linesAbout:(NSString *)question limit:(NSUInteger)limit;

/* The diary's own words of substance, rarest first: the nouns and adjectives
   somebody actually wrote, without the verbs a line is carried by and without
   the three-letter markers the file itself uses. This is what NekoWords offers a
   model to choose among, and it is worked out on demand rather than with the
   rest of the recall, because it is only ever wanted after a question found
   nothing. */
- (NSArray *)vocabularyOfSubstance;

/* Reduces yesterday to a few durable lines, once a day, using the best on-device
   engine. Returns immediately; the work happens on a queue. */
- (void)reflectIfDue;

/* The month-scale pass: dated lines that have aged out, plus the standing ones,
   reduced to what would still be worth knowing in six months. Does nothing when
   nothing has aged out, and — deliberately — nothing at all when there is no
   on-device engine, so that age alone never deletes anything unread. */
- (void)distilIfDue;

- (NSArray *)durableLines;
- (NSArray *)standingLines;

/* Housekeeping, all of it available from the preferences. */
- (NSUInteger)dayCount;
- (long long)bytesOnDisk;
- (void)pruneOldDays;
- (BOOL)forgetLinesContaining:(NSString *)text;
- (void)forgetEverything;

@end
