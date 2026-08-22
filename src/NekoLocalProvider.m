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

- (void)dealloc
{
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
	NSString *chosen = [[NSUserDefaults standardUserDefaults]
		stringForKey:NekoAskLocalModelKey];
	if([chosen length] > 0)
		return chosen;
	NSArray *installed = [[NekoModelStore sharedStore] installedIdentifiers];
	if([installed count] > 0)
		return [installed firstObject];
	NekoLocalModel *first = [[[NekoModelStore sharedStore] catalogue] firstObject];
	return [first identifier];
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
	NSError *problem = nil;
	if(![self prepareEngine:&problem]) {
		completion(nil, problem ?: [NSError errorWithDomain:NekoAskErrorDomain
		                                              code:NekoAskErrorNotConfigured
		                                          userInfo:nil]);
		return;
	}

	[engine generateFor:question
	       instructions:instructions
	            partial:partial
	         completion:completion];
}

- (void)cancel
{
	[engine cancel];
}

@end
