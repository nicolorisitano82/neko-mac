/* NekoController */

#import <Cocoa/Cocoa.h>
#import "NekoCharacter.h"
#import "NekoAsk.h"

@class MyPanel;

/* NSUserDefaults keys */
extern NSString * const NekoCharacterKey;  /* identifier of the sprite set */
extern NSString * const NekoSpeedKey;      /* points the cat moves per tick */
extern NSString * const NekoScaleKey;      /* 1.0 or 2.0 */
extern NSString * const NekoStopRadiusKey; /* points to keep from the pointer */
extern NSString * const NekoIdleSleepKey;  /* BOOL, cat falls asleep when idle */
extern NSString * const NekoWanderKey;     /* BOOL, cat strolls off on its own */
extern NSString * const NekoBehaviourKey; /* "follow", "windows" or "roam" */
extern NSString * const NekoSuggestKey;    /* BOOL, unasked suggestions while roaming */
extern NSString * const NekoSuggestEveryKey; /* minutes between suggestions */
extern NSString * const NekoPausedKey;     /* BOOL, cat hidden and frozen */

/* Posted whenever a setting changes. */
extern NSString * const NekoSettingsDidChangeNotification;

@interface NekoController : NSObject
{
	MyPanel *panel;              /* not retained, owned by the nib */
	NSStatusItem *statusItem;
	NSMenuItem *pauseItem;
	NSMenuItem *askItem;
	NSTabView *prefsTabs;
	NSMenu *characterMenu;
	NSPanel *prefsPanel;
	NSTextField *speedField;
	NSSlider *speedSlider;
	NSTextField *radiusField;
	NSSlider *radiusSlider;
	NSPopUpButton *characterPopUp;
	NSPopUpButton *sizePopUp;
	NSButton *sleepCheck;
	NSButton *wanderCheck;
	NSPopUpButton *behaviourPopUp;
	NSButton *askCheck;
	NSPopUpButton *askHotKeyPopUp;
	NSPopUpButton *askProviderPopUp;
	NSTextField *askShortcutField;
	NSSecureTextField *askKeyField;
	NSButton *askSpeakCheck;
	NSButton *actionsCheck;
	NSButton *wakeCheck;
	NSButton *foldersButton;
	NSButton *forgetFoldersButton;
	NSTextField *askStatusField;
	NSPopUpButton *localModelPopUp;
	NSTextField *localDetailField;
	NSButton *localActionButton;
	NSProgressIndicator *localProgress;
	NSTextField *localStatusField;
	NSButton *localCleanButton;
	NSButton *loginCheck;
	NSView *permissionsContent;
	NSTextField *permissionsSummary;
	NSButton *suggestCheck;
	NSButton *readTextCheck;
	NSButton *drawCheck;
	NSButton *drawActionButton;
	NSProgressIndicator *drawProgress;
	NSPopUpButton *drawStepsPopUp;
	NSPopUpButton *drawSizePopUp;
	NSButton *drawNowButton;
	NSTextField *drawStatusField;
	NSPopUpButton *suggestEveryPopUp;
	NSTextField *suggestStatusField;
	NSTextField *memoryField;
	NSButton *suggestNowButton;
}

+ (NekoController *)sharedController;

- (MyPanel *)panel;
- (void)setPanel:(MyPanel *)thePanel;

- (NekoCharacter *)character;
- (float)speed;
- (float)stopRadius;
- (float)scale;
- (BOOL)idleSleep;
- (BOOL)wandersWhenIdle;
- (BOOL)livesOnWindowEdges;

/* The third behaviour: the cat goes where it likes and the pointer means
   nothing to it. Suggestions live here and nowhere else. */
- (BOOL)roamsOnItsOwn;

/* YES only while roaming and switched on: the flag alone is not enough. */
- (BOOL)suggestsUnasked;

/* Minutes between one suggestion and the next. */
- (NSTimeInterval)suggestionInterval;

- (BOOL)isPaused;

/* Whether the system has been told to open Neko at login. Always NO before
   macOS 13, which has no SMAppService. */
- (BOOL)opensAtLogin;
- (BOOL)canOpenAtLogin;

- (void)showPreferences:(id)sender;
- (void)togglePause:(id)sender;
- (void)showAbout:(id)sender;
- (void)quit:(id)sender;

@end
