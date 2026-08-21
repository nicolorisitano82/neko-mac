#import "NekoModelProvider.h"

static NSString * const NekoModelKey = @"NekoAskModel";
static NSString * const NekoKeychainService = @"Neko Ask";
static NSString * const NekoKeychainAccount = @"anthropic-api-key";

static NSString * const NekoDefaultModel = @"claude-opus-5";
static const NSTimeInterval NekoModelTimeout = 12.0;

/* Short answers, in the user's language, in character. The cat is a cat. */
static NSString * const NekoSystemPrompt =
	@"You are Neko, a small pixel-art cat who lives on someone's computer desktop "
	@"and has just been asked a question out loud. Answer in the language you were "
	@"asked in. Be genuinely useful and correct, but keep it to one or two short "
	@"sentences: your answer is displayed in a speech bubble beside a cat 32 pixels "
	@"tall. No lists, no headings, no preamble. A little feline character is welcome, "
	@"never at the cost of the answer.";

@implementation NekoModelProvider

- (void)dealloc
{
	[self cancel];
	[super dealloc];
}

- (NSString *)name
{
	return NSLocalizedString(@"Claude, directly", nil);
}

- (NSString *)model
{
	NSString *model = [[NSUserDefaults standardUserDefaults] stringForKey:NekoModelKey];
	return [model length] > 0 ? model : NekoDefaultModel;
}

- (BOOL)isConfigured
{
	return [self hasApiKey];
}

- (NSString *)configurationHint
{
	return [self isConfigured] ? nil : NSLocalizedString(@"Paste an API key", nil);
}

#pragma mark The key, in the Keychain

- (NSMutableDictionary *)keychainQuery
{
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	[query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
	[query setObject:NekoKeychainService forKey:(id)kSecAttrService];
	[query setObject:NekoKeychainAccount forKey:(id)kSecAttrAccount];
	return query;
}

- (BOOL)setApiKey:(NSString *)key
{
	NSMutableDictionary *query = [self keychainQuery];
	SecItemDelete((CFDictionaryRef)query);
	if([key length] == 0)
		return YES;              /* asked to forget it */

	[query setObject:[key dataUsingEncoding:NSUTF8StringEncoding]
	          forKey:(id)kSecValueData];
	return SecItemAdd((CFDictionaryRef)query, NULL) == errSecSuccess;
}

- (NSString *)apiKey
{
	NSMutableDictionary *query = [self keychainQuery];
	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
	[query setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

	CFTypeRef result = NULL;
	if(SecItemCopyMatching((CFDictionaryRef)query, &result) != errSecSuccess)
		return nil;
	NSData *data = [(NSData *)result autorelease];
	return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

- (BOOL)hasApiKey
{
	return [[self apiKey] length] > 0;
}

#pragma mark Asking

- (void)askQuestion:(NSString *)question
         completion:(void (^)(NSString *answer, NSError *error))completion
{
	[self cancel];

	NSString *key = [self apiKey];
	if([key length] == 0) {
		completion(nil, [NSError errorWithDomain:NekoAskErrorDomain
		                                    code:NekoAskErrorNotConfigured
		                                userInfo:nil]);
		return;
	}

	NSDictionary *body = [NSDictionary dictionaryWithObjectsAndKeys:
		[self model], @"model",
		[NSNumber numberWithInt:400], @"max_tokens",   /* a bubble, not an essay */
		NekoSystemPrompt, @"system",
		[NSDictionary dictionaryWithObjectsAndKeys:@"low", @"effort", nil], @"output_config",
		@"default", @"fallbacks",
		[NSArray arrayWithObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"user", @"role", question, @"content", nil]], @"messages",
		nil];

	NSError *encoding = nil;
	NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:&encoding];
	if(payload == nil) {
		completion(nil, encoding);
		return;
	}

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
		[NSURL URLWithString:@"https://api.anthropic.com/v1/messages"]];
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
	[request setValue:key forHTTPHeaderField:@"x-api-key"];
	[request setValue:@"2023-06-01" forHTTPHeaderField:@"anthropic-version"];
	/* Server-side fallbacks: a refused question is answered by another model
	   rather than coming back empty. */
	[request setValue:@"server-side-fallback-2026-07-01" forHTTPHeaderField:@"anthropic-beta"];
	[request setHTTPBody:payload];
	[request setTimeoutInterval:NekoModelTimeout];

	pending = Block_copy(completion);
	task = [[[NSURLSession sharedSession] dataTaskWithRequest:request
	         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self handleData:data response:response error:error];
		});
	}] retain];
	[task resume];
}

- (void)handleData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error
{
	void (^completion)(NSString *, NSError *) = pending;
	pending = NULL;
	[task release];
	task = nil;
	if(completion == NULL)
		return;                  /* cancelled while in flight */

	if(error != nil) {
		completion(nil, error);
		Block_release(completion);
		return;
	}

	NSInteger status = [(NSHTTPURLResponse *)response statusCode];
	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:(data ?: [NSData data])
	                                                     options:0
	                                                       error:NULL];
	if(status != 200) {
		NSString *detail = [[json objectForKey:@"error"] objectForKey:@"message"];
		completion(nil, [NSError errorWithDomain:NekoAskErrorDomain
		                                    code:NekoAskErrorTransport
		                                userInfo:detail != nil
			? [NSDictionary dictionaryWithObject:detail forKey:NSLocalizedDescriptionKey]
			: nil]);
		Block_release(completion);
		return;
	}

	/* The answer is the text blocks, joined. A refusal arrives as a 200 with no
	   text at all, which is why stop_reason is worth looking at. */
	NSMutableString *answer = [NSMutableString string];
	NSEnumerator *e = [[json objectForKey:@"content"] objectEnumerator];
	NSDictionary *block;
	while((block = [e nextObject]) != nil) {
		if(![[block objectForKey:@"type"] isEqualToString:@"text"])
			continue;
		NSString *text = [block objectForKey:@"text"];
		if([text length] == 0)
			continue;
		if([answer length] > 0)
			[answer appendString:@"\n"];
		[answer appendString:text];
	}

	if([answer length] == 0) {
		/* A refusal comes back as a 200 with no text; either way there is
		   nothing for the cat to say. */
		completion(nil, [NSError errorWithDomain:NekoAskErrorDomain
		                                    code:NekoAskErrorNoAnswer
		                                userInfo:nil]);
	} else {
		completion(answer, nil);
	}
	Block_release(completion);
}

- (void)cancel
{
	[task cancel];
	[task release];
	task = nil;
	if(pending != NULL) {
		Block_release(pending);
		pending = NULL;
	}
}

@end
