/* NekoAntics */

#import <Cocoa/Cocoa.h>

/* The curious half of roaming.

   Wandering from place to place is what the cat does; this is what makes it
   look interested in you. Every so often it drops what it was doing, comes over
   to the pointer and asks what you are writing, or pounces on the cursor, or
   goes to claw the edge of the screen.

   What it goes on comes from NekoDesktop: counters the system hands out with no
   permission at all — keys and mouse moves since boot, seconds since the last
   one — plus, if that switch is on, the text being worked on.

   What it says comes from whichever engine Ask Neko is set to, asked while the
   cat is still walking over, with written-in lines as the fallback for when
   there is no engine or it does not answer in time. */
@interface NekoAntics : NSObject
{
	NSTimer *heartbeat;
	NSTimer *arrival;            /* watches for the cat reaching the pointer */
	NSDate *lastAntic;
	NSTimeInterval cooldown;     /* seconds until it is allowed to be curious */
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
