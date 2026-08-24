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

/* instructions describe who is answering; a provider that cannot set a system
   prompt of its own is expected to work them into the question. */
- (void)askQuestion:(NSString *)question
       instructions:(NSString *)instructions
         completion:(void (^)(NSString *answer, NSError *error))completion;

- (void)cancel;

@optional

/* Answers as it goes: `partial` receives the whole answer so far, `completion`
   closes it. A provider that can do this is preferred, because words on screen
   in half a second read as quick even when the whole answer takes two. */
- (void)askQuestion:(NSString *)question
       instructions:(NSString *)instructions
            partial:(void (^)(NSString *sofar))partial
         completion:(void (^)(NSString *answer, NSError *error))completion;

@end

/* The voice the character answers in, built around who it is. Shared by every
   provider so they cannot drift apart. */
extern NSString *NekoAnswerInstructionsFor(NSString *persona);

/* The same, plus the one extra rule that lets an answer be a picture: reply with
   "IMAGE: something to draw" and the app draws it instead. */
extern NSString *NekoAnswerInstructionsDrawing(NSString *persona, BOOL mayDraw);

/* And with the four things it is allowed to actually do. */
extern NSString *NekoAnswerInstructionsWith(NSString *persona, BOOL mayDraw, BOOL mayAct);

/* The handful of things the cat can truthfully know at this moment — the time,
   the date, the battery, how long the Mac has been awake — as plain lines for a
   model to read. */
extern NSString *NekoFactsNow(void);

/* The example lines the instructions carry, which a model will sometimes hand
   straight back and which are therefore worth recognising. */
extern NSArray *NekoInstructionExamples(void);

/* The marker a model uses to ask for a drawing. */
extern NSString * const NekoImageMarker;

/* The voice for something nobody asked for: a remark about what you appear to
   be doing, offered by a cat that only knows which application is in front.
   Shorter, humbler and allowed to say nothing at all. */
extern NSString *NekoSuggestionInstructionsFor(NSString *persona);

/* The voice for coming over and being nosy: a question about what you are doing,
   shorter than a suggestion and with no advice in it at all. */
extern NSString *NekoCuriosityInstructionsFor(NSString *persona);

/* Errors every provider raises. */
extern NSString * const NekoAskErrorDomain;
enum {
	NekoAskErrorNotConfigured = 1,
	NekoAskErrorTimedOut,
	NekoAskErrorNoAnswer,
	NekoAskErrorTransport,
	NekoAskErrorNoShortcut       /* the named Shortcut does not exist */
};
