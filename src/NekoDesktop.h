/* NekoDesktop */

#import <Cocoa/Cocoa.h>

/* BOOL: read the text being worked on, which needs the Accessibility
   permission. Off until asked for, and worth nothing without the permission. */
extern NSString * const NekoReadTextKey;

/* What the cat can tell about your day, in one place.

   Two tiers, deliberately separated. The first needs no permission at all and is
   what the suggestions and the antics have always run on: which application is
   in front, how long you have been in it, how often you have been switching, how
   fast you are typing and moving the mouse, how long since you last touched
   anything, the time. Counters and timestamps, never content.

   The second tier is content, and is off until you turn it on: the text in the
   field you are typing in, or under the pointer, read through the Accessibility
   API. Password fields are refused, secure keyboard entry silences it entirely,
   and what comes back is trimmed to a few hundred characters. With a remote
   engine chosen, that text is sent to that service — which is why it is a
   separate switch with its own paragraph rather than a detail of another one. */
@interface NekoDesktop : NSObject
{
	NSString *frontApp;
	NSDate *frontSince;
	NSMutableArray *switches;      /* {when, app} for each application change */
	NSString *lastHighlight;       /* so the same remark is not made twice running */

	uint32_t keysBefore, movesBefore;
	NSDate *sampledAt;
	uint32_t keysPerMinute, movesPerMinute;
}

+ (NekoDesktop *)sharedDesktop;

/* Cheap: two counters and a couple of dates. Call it on whatever timer you
   already have. */
- (void)sample;

- (NSString *)frontApp;
- (NSTimeInterval)secondsInFront;
- (NSUInteger)switchesInTheLastQuarterHour;

/* How many different programs, which is the honest measure of jumping about. */
- (NSUInteger)programsInTheLastQuarterHour;
- (NSTimeInterval)idleSeconds;
- (uint32_t)keysPerMinute;
- (uint32_t)movesPerMinute;

/* Only when screen recording was already granted for some other reason; never
   asked for. */
- (NSString *)windowTitleIfAllowed;

/* The switch and the permission together. */
- (BOOL)readsText;
+ (BOOL)accessibilityGranted;

/* Asks the system for the permission, which shows the standard alert and opens
   the pane. Returns whether it was already granted. */
+ (BOOL)requestAccessibility;

/* The text being worked on, or nil: switch off, permission missing, secure
   input, a password field, or simply nothing there. */
- (NSString *)nearbyText;

/* The single fact worth a remark right now — a long stretch in one program, a
   lot of jumping about, the small hours — in one English sentence. */
- (NSString *)highlight;

/* Everything above as the plain text a model is given. */
- (NSString *)summary;

@end
