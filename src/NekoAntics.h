/* NekoAntics */

#import <Cocoa/Cocoa.h>

/* The curious half of roaming.

   Wandering from place to place is what the cat does; this is what makes it
   look interested in you. Every so often it drops what it was doing, comes over
   to the pointer and asks what you are writing, or pounces on the cursor, or
   goes to claw the edge of the screen.

   What it goes on is what the system will tell anyone without a permission
   prompt: how many keys and mouse moves have happened since the machine booted,
   and how long since the last one. Nothing about which keys, nothing about
   where, nothing that identifies anything. Typing fast is a number going up. */
@interface NekoAntics : NSObject
{
	NSTimer *heartbeat;
	NSTimer *arrival;            /* watches for the cat reaching the pointer */
	NSDate *lastAntic;
	NSTimeInterval cooldown;     /* seconds until it is allowed to be curious */
	uint32_t keysBefore;
	uint32_t movesBefore;
	NSDate *sampledAt;
	uint32_t keysPerMinute;
	uint32_t movesPerMinute;
	NSString *pendingLine;       /* what it will say once it arrives */
}

+ (NekoAntics *)sharedAntics;

/* Runs in the roaming behaviour and stops in the other two. Safe to call
   whenever the settings change. */
- (void)applySettings;

/* One antic now, whatever the timers think — the preferences use it so the
   thing can be watched once instead of waited for. Returns what it decided to
   do, for the status line. */
- (NSString *)anticNow;

@end
