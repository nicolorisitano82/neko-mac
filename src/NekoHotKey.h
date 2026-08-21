/* NekoHotKey */

#import <Cocoa/Cocoa.h>

/* A system-wide keystroke.

   Carbon's RegisterEventHotKey is used rather than an event monitor on purpose:
   registering a hotkey needs no permission and works inside the App Sandbox,
   while monitoring keystrokes would ask the user for Accessibility. It also
   means a combination already taken by another application fails loudly instead
   of silently doing nothing. */
@interface NekoHotKey : NSObject
{
	id target;                   /* not retained */
	SEL action;
	void *reference;             /* EventHotKeyRef */
	unsigned identifier;
	unsigned short keyCode;
	NSUInteger modifiers;        /* NSEventModifierFlags */
}

- (id)initWithTarget:(id)aTarget action:(SEL)anAction;

/* NO when the combination is already taken, or is missing a modifier. */
- (BOOL)registerKeyCode:(unsigned short)code modifiers:(NSUInteger)flags;
- (void)unregister;
- (BOOL)isRegistered;

- (unsigned short)keyCode;
- (NSUInteger)modifiers;

/* "⌃⌥N", for the preferences. */
- (NSString *)displayName;
+ (NSString *)displayNameForKeyCode:(unsigned short)code modifiers:(NSUInteger)flags;

/* Control-Option-N. */
+ (unsigned short)defaultKeyCode;
+ (NSUInteger)defaultModifiers;

@end
