#import "NekoLocalProvider.h"
#import "NekoModelStore.h"

NSString * const NekoAskLocalModelKey = @"NekoAskLocalModel";

@implementation NekoLocalProvider

+ (id<NekoLocalEngine>)makeEngine
{
	/* Looked up by name so that adding the engine is a matter of compiling one
	   more class in, with nothing here to change. */
	Class engineClass = NSClassFromString(@"NekoLlamaEngine");
	return engineClass != Nil ? [[[engineClass alloc] init] autorelease] : nil;
}

- (id)init
{
	self = [super init];
	if(self != nil)
		loader = dispatch_queue_create("neko.local.loader", DISPATCH_QUEUE_SERIAL);
	return self;
}

- (void)dealloc
{
	if(loader != NULL)
		dispatch_release(loader);
	[engine cancel];
	[(id)engine release];
	[super dealloc];
}

- (NSString *)name
{
	return NSLocalizedString(@"A model on this Mac", nil);
}

- (NSString *)modelIdentifier
{
	NSArray *installed = [[NekoModelStore sharedStore] installedIdentifiers];
	NSString *chosen = [[NSUserDefaults standardUserDefaults]
		stringForKey:NekoAskLocalModelKey];

	/* Picking a model in the menu and never downloading it used to leave the
	   provider unconfigured for ever: questions fell back to the canned reply
	   and the roaming cat went silent, with nothing anywhere saying why. A model
	   that is actually on the disk beats the one that was merely chosen. */
	if([chosen length] > 0 && [installed containsObject:chosen])
		return chosen;
	if([installed count] > 0)
		return [installed firstObject];
	if([chosen length] > 0)
		return chosen;                 /* nothing installed: name the intent */
	NekoLocalModel *first = [[[NekoModelStore sharedStore] catalogue] firstObject];
	return [first identifier];
}

/* What was chosen, whether or not it is here — the preferences need to say
   "using X because Y was never downloaded" rather than quietly swapping. */
- (NSString *)chosenModelIdentifier
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:NekoAskLocalModelKey];
}

- (BOOL)isConfigured
{
	if([NekoLocalProvider makeEngine] == nil)
		return NO;
	return [[NekoModelStore sharedStore]
		installedURLForIdentifier:[self modelIdentifier]] != nil;
}

- (NSString *)configurationHint
{
	if([NekoLocalProvider makeEngine] == nil)
		return NSLocalizedString(@"This build has no local engine yet — the model can be downloaded ready for it", nil);
	if([[NekoModelStore sharedStore] installedURLForIdentifier:[self modelIdentifier]] == nil)
		return NSLocalizedString(@"Download a model first", nil);
	return nil;
}

#pragma mark Asking

- (BOOL)prepareEngine:(NSError **)error
{
	if(engine == nil)
		engine = [[NekoLocalProvider makeEngine] retain];
	if(engine == nil)
		return NO;
	if([engine isLoaded])
		return YES;

	NSURL *file = [[NekoModelStore sharedStore]
		installedURLForIdentifier:[self modelIdentifier]];
	if(file == nil)
		return NO;
	return [engine loadModelAtURL:file error:error];
}

- (void)askQuestion:(NSString *)question
       instructions:(NSString *)instructions
         completion:(void (^)(NSString *answer, NSError *error))completion
{
	[self askQuestion:question instructions:instructions partial:NULL completion:completion];
}

- (void)askQuestion:(NSString *)question
       instructions:(NSString *)instructions
            partial:(void (^)(NSString *sofar))partial
         completion:(void (^)(NSString *answer, NSError *error))completion
{
	/* Opening a GGUF means reading a gigabyte or two and compiling the Metal
	   kernels: seconds, the first time. Doing that here on the main thread would
	   freeze the whole app — the cat, the bubble, the spinner that is meant to
	   say something is happening — so the load goes to a queue of its own and
	   the question follows it there. */
	void (^partialCopy)(NSString *) = partial ? Block_copy(partial) : nil;
	void (^completionCopy)(NSString *, NSError *) = Block_copy(completion);

	dispatch_async(loader, ^{
		NSError *problem = nil;
		BOOL ready = [self prepareEngine:&problem];
		NSError *failure = ready ? nil :
			(problem ?: [NSError errorWithDomain:NekoAskErrorDomain
			                                code:NekoAskErrorNotConfigured
			                            userInfo:nil]);
		dispatch_async(dispatch_get_main_queue(), ^{
			if(!ready) {
				completionCopy(nil, failure);
			} else {
				[engine generateFor:question
				       instructions:instructions
				            partial:partialCopy
				         completion:completionCopy];
			}
			if(partialCopy)
				Block_release(partialCopy);
			Block_release(completionCopy);
		});
	});
}

- (void)cancel
{
	[engine cancel];
}

@end
