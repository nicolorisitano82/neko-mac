#import "NekoKeychain.h"

static NSString * const NekoKeychainService = @"Neko Ask";

@implementation NekoKeychain

+ (NSMutableDictionary *)queryForAccount:(NSString *)account
{
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	[query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
	[query setObject:NekoKeychainService forKey:(id)kSecAttrService];
	[query setObject:account forKey:(id)kSecAttrAccount];
	return query;
}

+ (BOOL)setSecret:(NSString *)secret forAccount:(NSString *)account
{
	NSMutableDictionary *query = [self queryForAccount:account];
	SecItemDelete((CFDictionaryRef)query);
	if([secret length] == 0)
		return YES;              /* asked to forget it */

	[query setObject:[secret dataUsingEncoding:NSUTF8StringEncoding]
	          forKey:(id)kSecValueData];
	return SecItemAdd((CFDictionaryRef)query, NULL) == errSecSuccess;
}

+ (NSString *)secretForAccount:(NSString *)account
{
	NSMutableDictionary *query = [self queryForAccount:account];
	[query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
	[query setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

	CFTypeRef result = NULL;
	if(SecItemCopyMatching((CFDictionaryRef)query, &result) != errSecSuccess)
		return nil;
	NSData *data = [(NSData *)result autorelease];
	return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

+ (BOOL)hasSecretForAccount:(NSString *)account
{
	return [[self secretForAccount:account] length] > 0;
}

@end
