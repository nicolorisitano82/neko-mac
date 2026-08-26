/* NekoPlugins */

#import <Cocoa/Cocoa.h>

@class NekoPlugin;

/* Which ones are switched on. An identifier not in this list is never read,
   never asked and never run: disabling is not a flag a plugin can see, it is the
   app not consulting it. */
extern NSString * const NekoPluginsEnabledKey;

/* Posted when one is added, removed, enabled or disabled. */
extern NSString * const NekoPluginsDidChangeNotification;

/* The folder of plugins, and what may be done with them.

   They live inside the app's container, because the app is sandboxed and that is
   where it can actually read. That has a consequence worth saying out loud: a
   plugin cannot be installed by dragging it into a folder in the Finder the way a
   character can. So installing is a panel — the same NSOpenPanel handover the
   folder access already uses — and this class is what does the copying. */
@interface NekoPlugins : NSObject
{
	NSMutableArray *plugins;
}

+ (NekoPlugins *)sharedPlugins;

- (NSURL *)directory;

/* Everything installed, refused ones included: a plugin that cannot be used is
   still shown, with the sentence saying why. */
- (NSArray *)all;
- (NSArray *)enabled;            /* usable and switched on */
- (NekoPlugin *)pluginWithIdentifier:(NSString *)identifier;

- (void)reload;

- (BOOL)isEnabled:(NekoPlugin *)plugin;
- (void)setEnabled:(BOOL)enabled for:(NekoPlugin *)plugin;

/* Copies a folder in and leaves it switched off: arriving is not the same as
   being on. Returns nil on success, or the sentence that says what was wrong. */
- (NSString *)installFrom:(NSURL *)chosen;

/* The folder, its switch, and anything it was remembered by. */
- (void)remove:(NekoPlugin *)plugin;

/* Every feed every enabled plugin adds, as NekoWeb wants them. */
- (NSArray *)feeds;

@end
