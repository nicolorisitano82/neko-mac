#import "NekoAppleProvider.h"

/* Written out here rather than imported: the class is Swift, and this is all of
   it that Objective-C needs to know. A mismatch fails at link time, loudly. */
@interface NekoAppleModel : NSObject
+ (BOOL)isAvailable;
+ (NSString *)unavailableReason;
- (void)ask:(NSString *)question
	instructions:(NSString *)instructions
	  completion:(void (^)(NSString *answer, NSString *error))completion;
- (void)cancel;
@end

@implementation NekoAppleProvider

+ (BOOL)isSupported
{
	Class bridge = NSClassFromString(@"NekoAppleModel");
	return bridge != Nil && [bridge isAvailable];
}

- (id)model
{
	if(model == nil) {
		Class bridge = NSClassFromString(@"NekoAppleModel");
		model = [[bridge alloc] init];
	}
	return model;
}

- (void)dealloc
{
	[model cancel];
	[model release];
	[super dealloc];
}

- (NSString *)name
{
	return NSLocalizedString(@"Apple Intelligence, on this Mac", nil);
}

- (BOOL)isConfigured
{
	return [NekoAppleProvider isSupported];
}

- (NSString *)configurationHint
{
	if([self isConfigured])
		return nil;
	Class bridge = NSClassFromString(@"NekoAppleModel");
	NSString *reason = bridge != Nil ? [bridge unavailableReason] : nil;
	return reason ?: NSLocalizedString(@"Needs macOS 26 or newer", nil);
}

- (void)askQuestion:(NSString *)question
         completion:(void (^)(NSString *answer, NSError *error))completion
{
	if(![self isConfigured]) {
		completion(nil, [NSError errorWithDomain:NekoAskErrorDomain
		                                    code:NekoAskErrorNotConfigured
		                                userInfo:nil]);
		return;
	}

	[[self model] ask:question
	     instructions:NekoAnswerInstructions
	       completion:^(NSString *answer, NSString *failure) {
		if([answer length] > 0) {
			completion(answer, nil);
			return;
		}
		completion(nil, [NSError errorWithDomain:NekoAskErrorDomain
		                                    code:NekoAskErrorNoAnswer
		                                userInfo:failure != nil
			? [NSDictionary dictionaryWithObject:failure forKey:NSLocalizedDescriptionKey]
			: nil]);
	}];
}

- (void)cancel
{
	[model cancel];
}

@end
