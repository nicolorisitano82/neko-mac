/* NekoWeb */

#import <Cocoa/Cocoa.h>

/* BOOL: may the cat look something up. Off until asked for. */
extern NSString * const NekoWebEnabledKey;

/* What a model may ask for, and the only thing it may ask for. */
@interface NekoWebSource : NSObject
{
	NSString *identifier;        /* "ansa" — the word a model is allowed to say */
	NSString *name;              /* "ANSA" */
	NSString *detail;            /* "ultima ora, in italiano" */
	NSString *address;
}
- (id)initWithIdentifier:(NSString *)anIdentifier
                    name:(NSString *)aName
                  detail:(NSString *)aDetail
                 address:(NSString *)anAddress;
- (NSString *)identifier;
- (NSString *)name;
- (NSString *)detail;
- (NSURL *)url;
@end

/* Headlines, from a list somebody else cannot add to.

   The dangerous version of this feature is the obvious one: let the model name a
   web address and fetch it. Then a sentence on a page — or in a headline, or in
   a document somebody sent — can send the cat anywhere, and text nobody in this
   room wrote decides what gets downloaded. So the model does not name addresses.
   It names one of the entries below, by a word from a fixed list, and anything
   else is refused before a connection is opened.

   What comes back is treated the same way as text read from the screen: quoted
   data, never instructions, and an answer built on it may not perform anything.
   That last rule lives in NekoAsk and has a test of its own.

   The request carries nothing: no question, no account, no cookies, no history —
   an ephemeral session, one GET, eight seconds. What ANSA can see is that
   somebody fetched a public feed. */
@interface NekoWeb : NSObject
{
	NSURLSession *session;
}

+ (NekoWeb *)sharedWeb;
- (BOOL)isEnabled;

/* The closed list, and the only way into it. */
+ (NSArray *)sources;
+ (NekoWebSource *)sourceNamed:(NSString *)identifier;

/* The line of names a model is shown, and the marker it answers with. */
+ (NSString *)namesForInstructions;
+ (BOOL)looksLikeALook:(NSString *)line;
+ (NSString *)wantedIn:(NSString *)line;      /* what came after the marker */

/* Up to eight headlines, each a short line of its own. */
- (void)headlinesFrom:(NekoWebSource *)source
           completion:(void (^)(NSArray *headlines, NSError *error))done;

/* Today and tomorrow, from open-meteo, which needs no key and no account.
   3B Meteo publishes no feed — every address it used to have is a 404 — so the
   cat says where its numbers come from rather than pretending. */
- (void)weatherFor:(NSString *)place
        completion:(void (^)(NSString *summary, NSError *error))done;

/* What goes into the second prompt: the lines, marked as somebody else's
   writing. */
+ (NSString *)blockFrom:(NSString *)what lines:(NSArray *)lines;

/* And what to show when there is no model worth handing it to. */
+ (NSString *)plainList:(NSArray *)lines from:(NekoWebSource *)source;

@end
