/* NekoFolderAccess */

#import <Cocoa/Cocoa.h>

/* Which of your folders the cat has been shown, and how it remembers.

   The app is sandboxed, and measured from a signed build it cannot read the
   Desktop or write to Documents: that is the sandbox doing its job. The way in
   that does not involve giving it up is the one macOS provides — you pick the
   folder yourself, once, in a panel, and the app keeps a security-scoped
   bookmark to it. Nothing else opens that door: not a setting, not a model, not
   a sentence somebody typed into a window.

   Six folders can ever be asked for, and no others. */
@interface NekoFolderAccess : NSObject

+ (NekoFolderAccess *)sharedAccess;

/* "desktop", "documents", "downloads", "pictures", "music", "movies". */
+ (NSArray *)folderKeys;
+ (BOOL)isFolderKey:(NSString *)key;

/* The Finder's name for it, for anything the user reads. */
- (NSString *)displayNameFor:(NSString *)key;

/* Whether a bookmark exists and still resolves. */
- (BOOL)hasAccessTo:(NSString *)key;
- (NSArray *)allowedKeys;

/* Opens the standard panel at that folder and keeps a bookmark if the user
   agrees. Returns whether access is now available. Must be called on the main
   thread: it puts up a panel. */
- (BOOL)requestAccessTo:(NSString *)key;

/* The folder, with access started. Balance every non-nil answer with
   -doneWith:, or the sandbox will run out of scoped resources. */
- (NSURL *)beginUsing:(NSString *)key;
- (void)doneWith:(NSURL *)url;

/* Forgets a folder, which is the only way back out. */
- (void)forget:(NSString *)key;

@end
