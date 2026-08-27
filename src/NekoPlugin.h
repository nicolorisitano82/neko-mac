/* NekoPlugin */

#import <Cocoa/Cocoa.h>

/* The interface version this build understands. A plugin declaring a higher one
   is refused rather than half-read: a manifest key nobody has implemented yet is
   a promise the app cannot keep. */
extern const NSInteger NekoPluginInterface;

/* One plugin folder, read but never run.

   A plugin is a folder with a manifest and some files. The manifest is the whole
   of the contract: what it says it extends is what it may be asked, and nothing
   else about it is consulted. A plugin that did not declare Feeds cannot add a
   feed however many feed addresses its files contain.

   Nothing here loads code. The app is sandboxed and holds a microphone, a
   location, folders somebody handed over by name and a diary about their working
   life; code inside this process would inherit all of it, and the entitlement
   that makes such loading possible is the one that would make the sandbox
   decorative. So a plugin is data, or — later, and only if something needs it —
   a separate process. See docs/plugins.md. */
@interface NekoPlugin : NSObject
{
	NSURL *folder;
	NSDictionary *manifest;
	NSString *refusal;           /* why it may not be used, or nil */
}

/* Reads the manifest and checks it. Never nil: a plugin that cannot be used is
   still shown in the list, with the sentence that says why. */
- (id)initWithFolder:(NSURL *)aFolder;

- (NSURL *)folder;
- (NSString *)identifier;
- (NSString *)name;
- (NSString *)version;
- (NSString *)author;
- (NSString *)summary;

/* nil when it is usable; otherwise one sentence, for the panel. */
- (NSString *)refusal;
- (BOOL)isUsable;

/* What it declared, already checked against what it wants. */
- (NSArray *)feeds;              /* NSDictionary each: Identifier, Name, Detail, Address */
- (BOOL)wantsNetwork;

/* Text processing, done by running one of the user's own Shortcuts — never a
   program of the plugin's own. nil when it does not process text. */
- (NSDictionary *)text;
- (NSString *)textShortcut;
- (BOOL)processesTextGoing:(BOOL)inward;   /* YES for what you said, NO for the answer */

/* "2 feeds", "nothing yet" — the line under its name in the panel. */
- (NSString *)describeWhatItAdds;

@end
