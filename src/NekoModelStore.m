#import "NekoModelStore.h"
#import "NekoAnswerProvider.h"

@implementation NekoLocalModel

- (id)initWithIdentifier:(NSString *)anIdentifier
                    name:(NSString *)aName
                  detail:(NSString *)aDetail
                     url:(NSURL *)aURL
                   bytes:(long long)bytes
{
	if((self = [super init]) != nil) {
		identifier = [anIdentifier copy];
		name = [aName copy];
		detail = [aDetail copy];
		url = [aURL retain];
		expectedBytes = bytes;
	}
	return self;
}

- (void)dealloc
{
	[identifier release];
	[name release];
	[detail release];
	[url release];
	[super dealloc];
}

- (NSString *)identifier { return identifier; }
- (NSString *)name { return name; }
- (NSString *)detail { return detail; }
- (NSURL *)url { return url; }
- (long long)expectedBytes { return expectedBytes; }

@end


@implementation NekoModelStore

+ (NekoModelStore *)sharedStore
{
	static NekoModelStore *shared = nil;
	if(shared == nil)
		shared = [[NekoModelStore alloc] init];
	return shared;
}

- (id)init
{
	if((self = [super init]) != nil) {
		NSURLSessionConfiguration *configuration =
			[NSURLSessionConfiguration defaultSessionConfiguration];
		/* Hundreds of megabytes over a possibly slow line: no request timeout,
		   but give up if nothing arrives for a minute. */
		[configuration setTimeoutIntervalForRequest:60.0];
		[configuration setTimeoutIntervalForResource:0.0];
		session = [[NSURLSession sessionWithConfiguration:configuration] retain];
	}
	return self;
}

#pragma mark What can be had

- (NSArray *)catalogue
{
	static NSArray *cached = nil;
	if(cached != nil)
		return cached;

	/* Small instruction-tuned models in GGUF, the format a local engine reads.
	   Sizes are the published ones, used to show progress before the server
	   says how long the file is. */
	cached = [[NSArray alloc] initWithObjects:
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"qwen2.5-0.5b-instruct-q4"
			              name:@"Qwen2.5 0.5B Instruct"
			            detail:NSLocalizedString(@"468 MB, 4-bit — quick, and about as clever as a small cat", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"]
			             bytes:491544576LL] autorelease],
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"qwen2.5-1.5b-instruct-q4"
			              name:@"Qwen2.5 1.5B Instruct"
			            detail:NSLocalizedString(@"1.0 GB, 4-bit — slower, and rather better at answering", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"]
			             bytes:1117320192LL] autorelease],
		nil];
	return cached;
}

- (NekoLocalModel *)modelWithIdentifier:(NSString *)identifier
{
	NSEnumerator *e = [[self catalogue] objectEnumerator];
	NekoLocalModel *model;
	while((model = [e nextObject]) != nil)
		if([[model identifier] isEqualToString:identifier])
			return model;
	return nil;
}

#pragma mark What is on disk

- (NSURL *)modelsDirectory
{
	NSArray *support = NSSearchPathForDirectoriesInDomains(
		NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [[[support firstObject] stringByAppendingPathComponent:@"Neko"]
		stringByAppendingPathComponent:@"Models"];
	[[NSFileManager defaultManager] createDirectoryAtPath:path
	                         withIntermediateDirectories:YES
	                                          attributes:nil
	                                               error:NULL];
	return [NSURL fileURLWithPath:path];
}

- (NSURL *)fileURLForIdentifier:(NSString *)identifier
{
	return [[self modelsDirectory] URLByAppendingPathComponent:
		[identifier stringByAppendingPathExtension:@"gguf"]];
}

- (NSURL *)installedURLForIdentifier:(NSString *)identifier
{
	NSURL *file = [self fileURLForIdentifier:identifier];
	return [[NSFileManager defaultManager] fileExistsAtPath:[file path]] ? file : nil;
}

- (long long)installedBytesForIdentifier:(NSString *)identifier
{
	NSDictionary *attributes = [[NSFileManager defaultManager]
		attributesOfItemAtPath:[[self fileURLForIdentifier:identifier] path] error:NULL];
	return [[attributes objectForKey:NSFileSize] longLongValue];
}

- (NSArray *)installedIdentifiers
{
	NSMutableArray *found = [NSMutableArray array];
	NSEnumerator *e = [[self catalogue] objectEnumerator];
	NekoLocalModel *model;
	while((model = [e nextObject]) != nil)
		if([self installedURLForIdentifier:[model identifier]] != nil)
			[found addObject:[model identifier]];
	return found;
}

- (BOOL)removeIdentifier:(NSString *)identifier
{
	NSURL *file = [self installedURLForIdentifier:identifier];
	if(file == nil)
		return YES;
	return [[NSFileManager defaultManager] removeItemAtURL:file error:NULL];
}

#pragma mark Fetching one

- (BOOL)isDownloading
{
	return task != nil;
}

- (double)fraction
{
	return fraction;
}

- (NekoLocalModel *)downloadingModel
{
	return downloading;
}

- (void)downloadModel:(NekoLocalModel *)model
             progress:(void (^)(double))progress
           completion:(void (^)(NSURL *, NSError *))completion
{
	[self cancelDownload];

	downloading = [model retain];
	fraction = 0.0;
	progressBlock = Block_copy(progress);
	completionBlock = Block_copy(completion);

	NSURL *destination = [self fileURLForIdentifier:[model identifier]];
	long long expected = [model expectedBytes];

	task = [[session downloadTaskWithURL:[model url]
	          completionHandler:^(NSURL *temporary, NSURLResponse *response, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self finishedAt:temporary destination:destination
			         response:response error:error];
		});
	}] retain];

	/* The task reports its own progress; polling it keeps this free of a
	   delegate whose only job would be to forward two numbers. */
	[self performSelector:@selector(reportProgress:)
	           withObject:[NSNumber numberWithLongLong:expected]
	           afterDelay:0.25];
	[task resume];
}

- (void)reportProgress:(NSNumber *)expected
{
	if(task == nil)
		return;

	long long written = [task countOfBytesReceived];
	long long total = [task countOfBytesExpectedToReceive];
	if(total <= 0)
		total = [expected longLongValue];      /* before the server says */
	if(total > 0)
		fraction = MIN(1.0, (double)written / (double)total);
	if(progressBlock != NULL)
		progressBlock(fraction);

	[self performSelector:@selector(reportProgress:) withObject:expected afterDelay:0.25];
}

- (void)finishedAt:(NSURL *)temporary
       destination:(NSURL *)destination
          response:(NSURLResponse *)response
             error:(NSError *)error
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	                                        selector:@selector(reportProgress:)
	                                          object:nil];
	void (^completion)(NSURL *, NSError *) = completionBlock;
	completionBlock = NULL;

	[task release];
	task = nil;
	[downloading release];
	downloading = nil;
	if(progressBlock != NULL) {
		Block_release(progressBlock);
		progressBlock = NULL;
	}

	NSError *problem = error;
	if(problem == nil) {
		NSInteger status = [(NSHTTPURLResponse *)response statusCode];
		if(status != 200)
			problem = [NSError errorWithDomain:NekoAskErrorDomain
			                             code:NekoAskErrorTransport
			                         userInfo:[NSDictionary dictionaryWithObject:
				[NSString stringWithFormat:@"HTTP %ld", (long)status]
				                                                        forKey:NSLocalizedDescriptionKey]];
	}

	if(problem == nil) {
		/* Replace rather than merge: a half written model is worse than none. */
		[[NSFileManager defaultManager] removeItemAtURL:destination error:NULL];
		if(![[NSFileManager defaultManager] moveItemAtURL:temporary
		                                           toURL:destination
		                                           error:&problem])
			destination = nil;
	}

	if(completion != NULL) {
		completion(problem == nil ? destination : nil, problem);
		Block_release(completion);
	}
}

- (void)cancelDownload
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	                                        selector:@selector(reportProgress:)
	                                          object:nil];
	[task cancel];
	[task release];
	task = nil;
	[downloading release];
	downloading = nil;
	fraction = 0.0;
	if(progressBlock != NULL) {
		Block_release(progressBlock);
		progressBlock = NULL;
	}
	if(completionBlock != NULL) {
		Block_release(completionBlock);
		completionBlock = NULL;
	}
}

@end
