/* NekoLocalProvider */

#import <Cocoa/Cocoa.h>
#import "NekoAnswerProvider.h"

/* What a local engine has to be able to do. Implement this, hand it to the
   provider, and the feature is complete: everything else — the catalogue, the
   download, the file on disk, the settings — is already here.

   The intended implementation is llama.cpp built as a static library and linked
   into the app, reading the GGUF the store downloaded. That keeps the app
   self-sufficient at runtime: no daemon to install, no Python, no other
   application to keep running. */
@protocol NekoLocalEngine <NSObject>
- (BOOL)loadModelAtURL:(NSURL *)file error:(NSError **)error;
- (BOOL)isLoaded;
- (void)generateFor:(NSString *)prompt
        instructions:(NSString *)instructions
             partial:(void (^)(NSString *sofar))partial
          completion:(void (^)(NSString *answer, NSError *error))completion;
- (void)cancel;
@end


/* A model running on this Mac, downloaded through the preferences.

   Distinct from the Apple Intelligence provider, which is also local but is the
   system's model on the system's terms: this one is a file you chose, on a Mac
   that may be too old for Apple Intelligence or have it switched off. */
@interface NekoLocalProvider : NSObject <NekoAnswerProvider>
{
	id<NekoLocalEngine> engine;
	dispatch_queue_t loader;        /* the model file is opened off the main thread */
}

/* The identifier of the model that will actually answer: whatever was chosen if
   it is on the disk, otherwise something that is. */
- (NSString *)modelIdentifier;

/* What the menu says, installed or not. */
- (NSString *)chosenModelIdentifier;

/* nil until an engine is compiled into the app. The provider reports itself
   unconfigured while this is the case, and says so in the preferences rather
   than failing at the moment someone asks a question. */
+ (id<NekoLocalEngine>)makeEngine;

@end
