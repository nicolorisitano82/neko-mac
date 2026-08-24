/* NekoSense */

#import <Cocoa/Cocoa.h>

/* The last gate before the cat opens its mouth.

   Small models fail in ways that are obvious to a reader and easy to spot in
   code: the same word four times over, an answer in the wrong language, one of
   the example lines handed straight back, a paragraph where a sentence was
   asked for. None of that is worth showing, and a cat that says nothing is
   better than a cat that says "Codice, codice, codice, codice."

   Everything here is a rejection, never a repair: a line is shown as written or
   not at all. */
@interface NekoSense : NSObject

/* NO when the line should be thrown away. */
+ (BOOL)isWorthSaying:(NSString *)line;

/* Why it was thrown away, for the preferences and the logs. nil when it passes. */
+ (NSString *)problemWith:(NSString *)line;

@end
