#import "NekoSense.h"
#import "NekoAction.h"
#import "NekoVoice.h"
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

/* A word macOS has never heard of, in the language the app runs in.

   Small models conjugate Italian by inventing the participle: "hai togliuto il
   file" for "hai tolto". The system dictionary catches exactly that, and — tried
   on a page of real output — leaves alone the things that would be false alarms:
   Xcode, Safari, TextEdit, Neko, colloquialisms, dates and numbers all pass. The
   grammar checker was tried too and is not worth having: it accepts "il gatto
   sono andato al mare" without complaint.

   Nonsense that is spelled correctly still gets through. This catches the
   invented word, not the invented thought. */
+ (NSString *)unknownWordIn:(NSString *)line
{
	NSString *language = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
	if([language length] == 0)
		return nil;
	NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];
	if(![[checker availableLanguages] containsObject:language])
		return nil;                /* no dictionary, no opinion */

	NSUInteger at = 0;
	while(at < [line length]) {
		NSRange found = [checker checkSpellingOfString:line
		                                   startingAt:at
		                                     language:language
		                                         wrap:NO
		                       inSpellDocumentWithTag:0
		                                    wordCount:NULL];
		if(found.location == NSNotFound || NSMaxRange(found) > [line length])
			return nil;
		NSString *word = [line substringWithRange:found];
		at = NSMaxRange(found);

		/* Anything with a digit or an inner capital is a name, a version or a
		   file, and the dictionary is not the authority on those. */
		if([word rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location
		   != NSNotFound)
			continue;
		if([word length] > 1
		   && [[word substringFromIndex:1] rangeOfCharacterFromSet:
			[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound)
			continue;
		return word;
	}
	return nil;
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
	/* A remark is generated from what is on somebody's screen, and a line that
	   asks for a deed is the shape an injected instruction would take. Nothing
	   downstream would perform it — only an answer to a question you asked can
	   reach an action, and that one is read back and waits for a yes — but it
	   has no business being shown either, and this is where it is thrown away. */
	if([NekoAction looksLikeAnAction:trimmed])
		return @"a deed, in something nobody asked for";
	NSArray *words = [self wordsIn:trimmed];
	if([words count] > NekoSenseMaxWords)
		return @"a paragraph, not a sentence";
	if([self repeatsItself:words])
		return @"the same word over and over";
	if([self isAnExample:trimmed])
		return @"one of the examples, handed back";
	if([self isInTheWrongLanguage:trimmed])
		return @"the wrong language";
	if([NekoVoice isNothingButFlattery:trimmed])
		return @"a compliment with nothing behind it";
	if([NekoVoice saysItTwice:trimmed])
		return @"the same thing twice";
	NSString *invented = [self unknownWordIn:trimmed];
	if(invented != nil)
		return [NSString stringWithFormat:@"a word that does not exist: %@", invented];
	return nil;
}

+ (BOOL)isWorthSaying:(NSString *)line
{
	return [self problemWith:line] == nil;
}

@end
