/* NekoAsk */

#import <Cocoa/Cocoa.h>
#import "NekoAnswerProvider.h"

@class NekoHotKey, NekoListener, NekoBubble;
@class NekoShortcutProvider, NekoModelProvider, NekoAppleProvider;
@class NekoOpenAIProvider, NekoLocalProvider;

/* NSUserDefaults keys */
extern NSString * const NekoAskEnabledKey;
extern NSString * const NekoAskHotKeyCodeKey;
extern NSString * const NekoAskHotKeyModifiersKey;
extern NSString * const NekoAskProviderKey;      /* apple, openai, model, shortcut */
extern NSString * const NekoAskShortcutNameKey;
extern NSString * const NekoAskSpeakKey;

/* When the cat last said something nobody asked for. Kept in the defaults so a
   restart does not hand it a fresh tongue. */
extern NSString * const NekoLastUnpromptedKey;

/* Ask the cat a question.

   The keystroke starts listening, what you said becomes text, the text goes to
   whichever provider is configured, and the answer appears in a bubble beside
   the cat. While all that happens the cat stops chasing the pointer: being asked
   something is more important than the cursor.

   Nothing is captured until the keystroke, and the microphone closes as soon as
   the sentence ends. */
@interface NekoAsk : NSObject
{
	NekoHotKey *hotKey;
	NekoListener *listener;
	NekoBubble *bubble;
	NekoShortcutProvider *shortcutProvider;
	NekoModelProvider *modelProvider;
	NekoAppleProvider *appleProvider;
	NekoOpenAIProvider *openaiProvider;
	NekoLocalProvider *localProvider;
	int phase;
	NSDate *lastDrawn;           /* throttles the streaming redraw */
	NSTimer *thinking;
	BOOL drawing;                /* the spinner is an hourglass, not a paw */           /* the animation while it waits */
	NSString *thinkingQuestion;
	unsigned thinkingTick;
	BOOL hotKeyFailed;
}

+ (NekoAsk *)sharedAsk;

/* Re-reads the preferences: on or off, the keystroke, which provider. */
- (void)applySettings;

- (BOOL)isEnabled;
- (BOOL)isBusy;

/* The keystroke as the preferences should show it, and whether registering it
   failed because something else already owns it. */
- (NSString *)hotKeyDisplayName;
- (BOOL)hotKeyUnavailable;

- (id<NekoAnswerProvider>)provider;
- (NekoModelProvider *)modelProvider;   /* the preferences hold its key */
- (NekoOpenAIProvider *)openaiProvider;

/* Starts a question, or abandons the one in progress. */
- (void)toggle:(id)sender;

/* For the cat's own remarks, which nobody asked for. NO while it is listening,
   thinking, answering or already saying something: an interruption of an
   interruption is worse than a missed suggestion. */
- (BOOL)canSpeakUnprompted;

/* Seconds since the last unasked remark of any kind, and whether the quiet
   period from the Suggestions tab has passed. Both count suggestions and
   curious questions together: they are all interruptions to whoever is
   working. */
+ (NSTimeInterval)secondsSinceSpokeUnprompted;
+ (BOOL)mayInterruptNow;

/* Whether a bubble is on screen right now. The cat stays where it is while one
   is: reading something that walks away is worse than waiting for it. */
- (BOOL)isSpeaking;

/* Says something in the bubble without any question having been asked, and
   holds the cat still while it does. */
- (void)sayUnprompted:(NSString *)text;

/* Shows a picture beside the cat, for the preferences' own test button. */
- (void)showDrawing:(NSImage *)picture near:(id)panel;

@end
