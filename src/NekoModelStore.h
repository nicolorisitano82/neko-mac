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
}
- (id)initWithIdentifier:(NSString *)anIdentifier
                    name:(NSString *)aName
                  detail:(NSString *)aDetail
                     url:(NSURL *)aURL
                   bytes:(long long)bytes;
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

+ (NekoModelStore *)sharedStore;

/* What can be downloaded, in ascending size. */
- (NSArray *)catalogue;
- (NekoLocalModel *)modelWithIdentifier:(NSString *)identifier;

/* Where they are kept, created on demand. */
- (NSURL *)modelsDirectory;

/* nil when that one is not on disk. */
- (NSURL *)installedURLForIdentifier:(NSString *)identifier;
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
