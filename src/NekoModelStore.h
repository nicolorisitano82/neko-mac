/* NekoModelStore */

#import <Cocoa/Cocoa.h>

/* One downloadable model. */
@interface NekoLocalModel : NSObject
{
	NSString *identifier;
	NSString *name;
	NSString *detail;
	NSURL *url;
	long long expectedBytes;
	BOOL thinks;
}
/* Whether this model writes its notes before it answers.

   A required argument and not a setter, on purpose: a catalogue entry added
   without deciding this is exactly how Qwen3.5 4B got in. Its URL was checked,
   its bytes were checked, its licence was checked, and nobody asked what it
   **writes** — which is a `<think>` block, and it went in the bubble with the
   persona quoted back inside it. NekoLocalProvider takes it out now; this says
   which ones it will be taking it out of, so the preferences can say so too. */
- (BOOL)thinks;

- (id)initWithIdentifier:(NSString *)anIdentifier
                    name:(NSString *)aName
                  detail:(NSString *)aDetail
                     url:(NSURL *)aURL
                   bytes:(long long)bytes
                  thinks:(BOOL)thinksOutLoud;
- (NSString *)identifier;
- (NSString *)name;
- (NSString *)detail;        /* "468 MB, 4-bit" and so on */
- (NSURL *)url;
- (long long)expectedBytes;
@end


/* Keeps the local models: what can be had, what is on disk, and the download in
   between.

   Nothing here shells out to anything. The files live in the app's own
   Application Support folder, inside the sandbox container, and are fetched
   straight over HTTPS — no package manager, no Python, no daemon to install
   first. */
@interface NekoModelStore : NSObject
{
	NSURLSession *session;
	NSURLSessionDownloadTask *task;
	NekoLocalModel *downloading;
	double fraction;
	void (^progressBlock)(double);
	void (^completionBlock)(NSURL *, NSError *);
}

/* Where the models are, when they are not where they live.

   Not a preference and not in any window, and here for the same reason
   NekoMemoryDirectoryKey is: a harness runs unsandboxed and looks in
   ~/Library/Application Support, while the application looks inside its
   container, so the check that matters most cannot see the file it needs.

   That cost something real. The arm of tests/think.m that asks every installed
   model a question and refuses any answer carrying a reasoning tag — the one
   check that would have caught a `<think>` block reaching a speech bubble —
   found nothing to ask, because the only model on the machine was in the app's
   container. It reported that honestly and it still measured nothing. */
extern NSString * const NekoModelsDirectoryKey;

+ (NekoModelStore *)sharedStore;

/* What can be downloaded, in ascending size. */
- (NSArray *)catalogue;

/* The ones that draw rather than write. Kept apart from the others in every
   sense — their own folder, their own list — so that the housekeeping button on
   the Local model tab cannot sweep away a picture model it does not recognise. */
- (NSArray *)pictureCatalogue;

- (NekoLocalModel *)modelWithIdentifier:(NSString *)identifier;

/* Where they are kept, created on demand. */
- (NSURL *)modelsDirectory;
- (NSURL *)picturesDirectory;

/* nil when that one is not on disk. */
- (NSURL *)installedURLForIdentifier:(NSString *)identifier;

/* A file that is there but far short of its published size: an interrupted
   download, which reads as a broken model rather than a missing one. */
- (BOOL)isIncomplete:(NSString *)identifier;
- (long long)installedBytesForIdentifier:(NSString *)identifier;
- (NSArray *)installedIdentifiers;
- (BOOL)removeIdentifier:(NSString *)identifier;

/* Housekeeping: what is downloaded besides the one in use, what it costs, and
   one call to be rid of it — strays that are not in the catalogue included. */
- (NSArray *)identifiersOtherThan:(NSString *)keep;
- (long long)installedBytesOtherThan:(NSString *)keep;
- (long long)totalInstalledBytes;
- (NSUInteger)removeAllExcept:(NSString *)keep;

/* One download at a time; asking for a second cancels the first. Progress is
   0 to 1, and both blocks arrive on the main thread. */
- (void)downloadModel:(NekoLocalModel *)model
             progress:(void (^)(double fraction))progress
           completion:(void (^)(NSURL *file, NSError *error))completion;
- (void)cancelDownload;
- (BOOL)isDownloading;
- (double)fraction;
- (NekoLocalModel *)downloadingModel;

@end
