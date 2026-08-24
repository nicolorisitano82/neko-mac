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

	/* Instruction-tuned models in GGUF, the format the engine reads, ordered by
	   size. The descriptions are what they actually do: the half-billion one was
	   asked for the capital of Italy and answered "Italie, la capitale d'Italia,
	   è Roma", which is the sort of thing worth warning about rather than
	   dressing up. Sizes are the published ones, used to show progress before
	   the server says how long the file is. */
	cached = [[NSArray alloc] initWithObjects:
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"qwen2.5-0.5b-instruct-q4"
			              name:@"Qwen2.5 0.5B Instruct"
			            detail:NSLocalizedString(@"468 MB — answers in a blink, and gets simple facts wrong", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"]
			             bytes:491544576LL] autorelease],
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"qwen2.5-1.5b-instruct-q4"
			              name:@"Qwen2.5 1.5B Instruct"
			            detail:NSLocalizedString(@"1.0 GB — the smallest one worth believing", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"]
			             bytes:1117320192LL] autorelease],
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"llama-3.2-3b-instruct-q4"
			              name:@"Llama 3.2 3B Instruct"
			            detail:NSLocalizedString(@"1.9 GB — good in several languages, a second or two to answer", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"]
			             bytes:2019377696LL] autorelease],
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"qwen2.5-3b-instruct-q4"
			              name:@"Qwen2.5 3B Instruct"
			            detail:NSLocalizedString(@"2.0 GB — right and brief, and a year older than the two below", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"]
			             bytes:2104521312LL] autorelease],
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"qwen3-1.7b-q8"
			              name:@"Qwen3 1.7B"
			            detail:NSLocalizedString(@"1.7 GB — newer than the 1.5B and better at holding to an instruction", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q8_0.gguf"]
			             bytes:1834426016LL] autorelease],
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"gemma-3-4b-it-q4"
			              name:@"Gemma 3 4B"
			            detail:NSLocalizedString(@"2.3 GB — the best of these outside English", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf"]
			             bytes:2489757856LL] autorelease],
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"qwen3-4b-instruct-q4"
			              name:@"Qwen3 4B Instruct"
			            detail:NSLocalizedString(@"2.3 GB — the most recent, and the one that follows a brief best", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf"]
			             bytes:2497281120LL] autorelease],
		nil];
	return cached;
}

- (NekoLocalModel *)modelWithIdentifier:(NSString *)identifier
{
	NSEnumerator *pictures = [[self pictureCatalogue] objectEnumerator];
	NekoLocalModel *picture;
	while((picture = [pictures nextObject]) != nil)
		if([[picture identifier] isEqualToString:identifier])
			return picture;
	NSEnumerator *e = [[self catalogue] objectEnumerator];
	NekoLocalModel *model;
	while((model = [e nextObject]) != nil)
		if([[model identifier] isEqualToString:identifier])
			return model;
	return nil;
}

#pragma mark What is on disk

/* One picture model, because the choice here is not really a choice: Stable
   Diffusion 1.5 quantised to 8 bits is the smallest thing that draws a
   recognisable Colosseum, and the alternatives are either the same model a
   hundred megabytes lighter or four times the size. */
- (NSArray *)pictureCatalogue
{
	static NSArray *cached = nil;
	if(cached != nil)
		return cached;
	cached = [[NSArray alloc] initWithObjects:
		[[[NekoLocalModel alloc]
			initWithIdentifier:@"sd15-q8"
			              name:@"Stable Diffusion 1.5"
			            detail:NSLocalizedString(@"1.6 GB, 8-bit — draws a 512 pixel picture on this Mac's GPU", nil)
			               url:[NSURL URLWithString:@"https://huggingface.co/second-state/stable-diffusion-v1-5-GGUF/resolve/main/stable-diffusion-v1-5-pruned-emaonly-Q8_0.gguf"]
			             bytes:1717986918LL] autorelease], nil];
	return cached;
}

- (BOOL)isPicture:(NSString *)identifier
{
	NSEnumerator *e = [[self pictureCatalogue] objectEnumerator];
	NekoLocalModel *model;
	while((model = [e nextObject]) != nil)
		if([[model identifier] isEqualToString:identifier])
			return YES;
	return NO;
}

- (NSURL *)picturesDirectory
{
	NSArray *support = NSSearchPathForDirectoriesInDomains(
		NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [[[support firstObject] stringByAppendingPathComponent:@"Neko"]
		stringByAppendingPathComponent:@"Images"];
	[[NSFileManager defaultManager] createDirectoryAtPath:path
	                         withIntermediateDirectories:YES
	                                          attributes:nil
	                                               error:NULL];
	return [NSURL fileURLWithPath:path];
}

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
	NSURL *directory = [self isPicture:identifier] ? [self picturesDirectory]
	                                               : [self modelsDirectory];
	return [directory URLByAppendingPathComponent:
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

/* Everything downloaded that is not the one in use, and what it costs. Models
   are hundreds of megabytes each: trying two and forgetting is easy, and a
   gigabyte quietly parked in Application Support is not obvious from anywhere
   else. */
- (NSArray *)identifiersOtherThan:(NSString *)keep
{
	NSMutableArray *others = [NSMutableArray array];
	NSEnumerator *e = [[self installedIdentifiers] objectEnumerator];
	NSString *identifier;
	while((identifier = [e nextObject]) != nil)
		if(![identifier isEqualToString:keep])
			[others addObject:identifier];
	return others;
}

- (long long)installedBytesOtherThan:(NSString *)keep
{
	long long total = 0;
	NSEnumerator *e = [[self identifiersOtherThan:keep] objectEnumerator];
	NSString *identifier;
	while((identifier = [e nextObject]) != nil)
		total += [self installedBytesForIdentifier:identifier];
	return total;
}

- (long long)totalInstalledBytes
{
	long long total = 0;
	NSEnumerator *e = [[self installedIdentifiers] objectEnumerator];
	NSString *identifier;
	while((identifier = [e nextObject]) != nil)
		total += [self installedBytesForIdentifier:identifier];
	return total;
}

/* Returns how many went. Also sweeps away anything left in the folder that is
   not in the catalogue at all — a half finished download from an older version,
   or a model dropped by hand. */
- (NSUInteger)removeAllExcept:(NSString *)keep
{
	NSUInteger removed = 0;
	NSEnumerator *e = [[self identifiersOtherThan:keep] objectEnumerator];
	NSString *identifier;
	while((identifier = [e nextObject]) != nil)
		if([self removeIdentifier:identifier])
			removed++;

	NSArray *known = [[self catalogue] valueForKey:@"identifier"];
	NSArray *contents = [[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:[[self modelsDirectory] path] error:NULL];
	NSEnumerator *files = [contents objectEnumerator];
	NSString *file;
	while((file = [files nextObject]) != nil) {
		NSString *stem = [file stringByDeletingPathExtension];
		if([known containsObject:stem] || [stem isEqualToString:keep])
			continue;
		NSURL *stray = [[self modelsDirectory] URLByAppendingPathComponent:file];
		if([[NSFileManager defaultManager] removeItemAtURL:stray error:NULL])
			removed++;
	}
	return removed;
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
