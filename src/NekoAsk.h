/* NekoAsk */

#import <Cocoa/Cocoa.h>
#import "NekoAnswerProvider.h"

@class NekoHotKey, NekoListener, NekoBubble;
@class NekoShortcutProvider, NekoModelProvider, NekoAppleProvider;

/* NSUserDefaults keys */
extern NSString * const NekoAskEnabledKey;
extern NSString * const NekoAskHotKeyCodeKey;
extern NSString * const NekoAskHotKeyModifiersKey;
extern NSString * const NekoAskProviderKey;      /* "apple", "shortcut" or "model" */
extern NSString * const NekoAskShortcutNameKey;
extern NSString * const NekoAskSpeakKey;

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
	int phase;
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

/* Starts a question, or abandons the one in progress. */
- (void)toggle:(id)sender;

@end
