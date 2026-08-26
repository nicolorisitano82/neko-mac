/* NekoSense */

#import <Cocoa/Cocoa.h>

/* The last gate before the cat opens its mouth.

   Small models fail in ways that are obvious to a reader and easy to spot in
   code: the same word four times over, an answer in the wrong language, one of
   the example lines handed straight back, a paragraph where a sentence was
   asked for. None of that is worth showing, and a cat that says nothing is
   better than a cat that says "Codice, codice, codice, codice."

   It judges what the cat says on its own, where saying nothing is a perfectly
   good outcome. An answer to a question asked out loud does not come through
   here: dropping that would leave somebody who asked something staring at a
   cat, which is worse than a clumsy sentence.

   Everything here is a rejection, never a repair: a line is shown as written or
   not at all. */
@interface NekoSense : NSObject

/* NO when the line should be thrown away. */
+ (BOOL)isWorthSaying:(NSString *)line;

/* Why it was thrown away, for the preferences and the logs. nil when it passes. */
+ (NSString *)problemWith:(NSString *)line;

/* The first word in the line that the system dictionary does not know, or nil.
   Names, versions and file names are left alone. */
+ (NSString *)unknownWordIn:(NSString *)line;

/* Whether a line is not in the language the application is running in. Public
   because it is one of the few things about a character that a test can see:
   answering in the wrong language is the first thing to go when a prompt gets
   long. */
+ (BOOL)isInTheWrongLanguage:(NSString *)line;

@end
