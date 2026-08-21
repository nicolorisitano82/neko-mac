/* NekoController */

#import <Cocoa/Cocoa.h>
#import "NekoCharacter.h"

@class MyPanel;

/* NSUserDefaults keys */
extern NSString * const NekoCharacterKey;  /* identifier of the sprite set */
extern NSString * const NekoSpeedKey;      /* points the cat moves per tick */
extern NSString * const NekoScaleKey;      /* 1.0 or 2.0 */
extern NSString * const NekoStopRadiusKey; /* points to keep from the pointer */
extern NSString * const NekoIdleSleepKey;  /* BOOL, cat falls asleep when idle */
extern NSString * const NekoPausedKey;     /* BOOL, cat hidden and frozen */

/* Posted whenever a setting changes. */
extern NSString * const NekoSettingsDidChangeNotification;

@interface NekoController : NSObject
{
	MyPanel *panel;              /* not retained, owned by the nib */
	NSStatusItem *statusItem;
	NSMenuItem *pauseItem;
	NSMenu *characterMenu;
	NSPanel *prefsPanel;
	NSTextField *speedField;
	NSSlider *speedSlider;
	NSTextField *radiusField;
	NSSlider *radiusSlider;
	NSPopUpButton *characterPopUp;
	NSPopUpButton *sizePopUp;
	NSButton *sleepCheck;
	NSButton *loginCheck;
}

+ (NekoController *)sharedController;

- (MyPanel *)panel;
- (void)setPanel:(MyPanel *)thePanel;

- (NekoCharacter *)character;
- (float)speed;
- (float)stopRadius;
- (float)scale;
- (BOOL)idleSleep;
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
