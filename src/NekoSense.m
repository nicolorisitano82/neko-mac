#import "NekoSense.h"
#import "NekoAnswerProvider.h"
#import <NaturalLanguage/NaturalLanguage.h>

/* One sentence, twenty words. Twice that is a model ignoring the brief. */
static const NSUInteger NekoSenseMaxWords = 45;
static const NSUInteger NekoSenseMinLength = 6;

@implementation NekoSense

+ (NSArray *)wordsIn:(NSString *)line
{
	NSMutableCharacterSet *breaks = [[[NSCharacterSet
		whitespaceAndNewlineCharacterSet] mutableCopy] autorelease];
	[breaks formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
	NSMutableArray *words = [NSMutableArray array];
	NSEnumerator *e = [[[line lowercaseString]
		componentsSeparatedByCharactersInSet:breaks] objectEnumerator];
	NSString *word;
	while((word = [e nextObject]) != nil)
		if([word length] > 0)
			[words addObject:word];
	return words;
}

/* "Codice, codice, codice, codice." Three of the same word out of a handful is
   not emphasis, it is a model stuck in a groove. */
+ (BOOL)repeatsItself:(NSArray *)words
{
	NSCountedSet *counted = [NSCountedSet setWithArray:words];
	NSEnumerator *e = [counted objectEnumerator];
	NSString *word;
	while((word = [e nextObject]) != nil) {
		if([word length] < 3)
			continue;                  /* "di", "la", "the" are meant to repeat */
		if([counted countForObject:word] >= 3)
			return YES;
		if([counted countForObject:word] >= 2 && [words count] <= 6)
			return YES;
	}
	return NO;
}

/* The language the interface is in, which is the language the answer was asked
   for twice over. Only judged when there is enough text to judge. */
+ (BOOL)isInTheWrongLanguage:(NSString *)line
{
	if([line length] < 25)
		return NO;
	if(![NLLanguageRecognizer class])
		return NO;
	NSString *wanted = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
	if([wanted length] == 0)
		return NO;
	NLLanguageRecognizer *recognizer = [[[NLLanguageRecognizer alloc] init] autorelease];
	[recognizer processString:line];
	NSString *found = [recognizer dominantLanguage];
	if([found length] == 0)
		return NO;
	NSDictionary *confidence = [recognizer languageHypothesesWithMaximum:3];
	double sure = [[confidence objectForKey:found] doubleValue];
	if(sure < 0.75)
		return NO;                     /* short cat remarks are hard to place */
	return ![[found substringToIndex:2] isEqualToString:
		[wanted substringToIndex:MIN((NSUInteger)2, [wanted length])]];
}

+ (BOOL)isAnExample:(NSString *)line
{
	NSString *plain = [[line lowercaseString] stringByTrimmingCharactersInSet:
		[NSCharacterSet punctuationCharacterSet]];
	NSEnumerator *e = [NekoInstructionExamples() objectEnumerator];
	NSString *example;
	while((example = [e nextObject]) != nil) {
		NSString *other = [[example lowercaseString] stringByTrimmingCharactersInSet:
			[NSCharacterSet punctuationCharacterSet]];
		if([plain isEqualToString:other])
			return YES;
	}
	return NO;
}

+ (NSString *)problemWith:(NSString *)line
{
	NSString *trimmed = [line stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if([trimmed length] < NekoSenseMinLength)
		return @"too short";
	if([trimmed isEqualToString:@"-"])
		return @"nothing to say";
	NSArray *words = [self wordsIn:trimmed];
	if([words count] > NekoSenseMaxWords)
		return @"a paragraph, not a sentence";
	if([self repeatsItself:words])
		return @"the same word over and over";
	if([self isAnExample:trimmed])
		return @"one of the examples, handed back";
	if([self isInTheWrongLanguage:trimmed])
		return @"the wrong language";
	return nil;
}

+ (BOOL)isWorthSaying:(NSString *)line
{
	return [self problemWith:line] == nil;
}

@end
