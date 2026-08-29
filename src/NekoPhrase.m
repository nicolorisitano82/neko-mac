#import "NekoPhrase.h"

@implementation NekoPhrase

/* A phrase matches when it is there as whole words: "metti" in "metti Taylor
   Swift" and not in "mettiamo". The argument is whatever follows it — cut from
   what was actually said, not from the lowercased copy the matching is done on,
   so that "metti Taylor Swift" searches for Taylor Swift and not taylor swift. */
+ (BOOL)phrase:(NSString *)phrase in:(NSString *)said
          said:(NSString *)original argument:(NSString **)argument
{
	NSRange found = [said rangeOfString:phrase];
	if(found.location == NSNotFound)
		return NO;

	NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
	if(found.location > 0
	   && [letters characterIsMember:[said characterAtIndex:found.location - 1]])
		return NO;
	NSUInteger after = NSMaxRange(found);
	if(after < [said length]
	   && [letters characterIsMember:[said characterAtIndex:after]])
		return NO;

	if(argument != NULL) {
		/* Lowercasing can change a string's length in some languages; where it
		   has, the words that were said cannot be cut at this index, and the
		   lowercased ones are better than the wrong ones. */
		NSString *from = [original length] == [said length] ? original : said;
		*argument = [[from substringFromIndex:after] stringByTrimmingCharactersInSet:
			[NSCharacterSet characterSetWithCharactersInString:@" \t\n\r?!.,;:“”\"'"]];
	}
	return YES;
}

@end
