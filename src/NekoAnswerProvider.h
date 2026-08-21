/* NekoAnswerProvider */

#import <Cocoa/Cocoa.h>

/* Where an answer comes from. Two of these exist — a Shortcut the user owns and
   a model called directly — and the rest of the feature knows neither.

   Every provider obeys the same contract: answer or fail within its own
   timeout, always call back on the main thread, and treat a cancellation as
   neither an answer nor an error. */
@protocol NekoAnswerProvider <NSObject>

/* Shown in the preferences. */
- (NSString *)name;

/* NO sends the caller to the canned reply instead. */
- (BOOL)isConfigured;

/* Why it is not configured, for the preferences to show. nil when it is. */
- (NSString *)configurationHint;

- (void)askQuestion:(NSString *)question
         completion:(void (^)(NSString *answer, NSError *error))completion;

- (void)cancel;

@end

/* The voice the cat answers in, shared by every provider that talks to a model
   so they cannot drift apart. */
extern NSString * const NekoAnswerInstructions;

/* Errors every provider raises. */
extern NSString * const NekoAskErrorDomain;
enum {
	NekoAskErrorNotConfigured = 1,
	NekoAskErrorTimedOut,
	NekoAskErrorNoAnswer,
	NekoAskErrorTransport,
	NekoAskErrorNoShortcut       /* the named Shortcut does not exist */
};
