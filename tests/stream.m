/* An answer that arrives a few words at a time.

   The local engines streamed already; the two remote ones did not, which is
   backwards — they are the two that go over a network and so the two where
   somebody waits. Both can send server-sent events, and the two formats differ
   only in where the text sits inside each event.

   None of this is measured by calling either service. An API call costs the
   person running the suite money and would make this harness depend on somebody
   else's uptime, so what is fed in here is bytes: split mid-word, split between
   the two halves of a newline, with keep-alives and comments in between, and
   with an error body instead of a stream. Those are the things that actually go
   wrong when reading one of these. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoStream.h"

static NekoStream *staged(NSString *(^text)(NSDictionary *event),
                          NSMutableArray *seen,
                          NSMutableArray *ended)
{
	NSURLRequest *nowhere = [NSURLRequest requestWithURL:
		[NSURL URLWithString:@"https://example.invalid/"]];
	return [[[NekoStream alloc] initWithRequest:nowhere
	                                    timeout:8.0
	                                       text:text
	                                    partial:^(NSString *sofar) {
		[seen addObject:sofar];
	}
	                                 completion:^(NSString *answer, NSError *error) {
		[ended addObject:answer ?: @""];
	}] autorelease];
}

static NSString *(^openAIText)(NSDictionary *) = ^NSString *(NSDictionary *event) {
	return [[[[event objectForKey:@"choices"] lastObject]
		objectForKey:@"delta"] objectForKey:@"content"];
};

static NSString *(^claudeText)(NSDictionary *) = ^NSString *(NSDictionary *event) {
	NSDictionary *delta = [event objectForKey:@"delta"];
	if(![delta isKindOfClass:[NSDictionary class]])
		return nil;
	return [delta objectForKey:@"text"];
};

static void feed(NekoStream *stream, NSString *text)
{
	[stream consume:[text dataUsingEncoding:NSUTF8StringEncoding]];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- ChatGPT's shape ---\n");

	NSMutableArray *seen = [NSMutableArray array];
	NekoStream *chat = staged(openAIText, seen, [NSMutableArray array]);
	feed(chat, @"data: {\"choices\":[{\"delta\":{\"content\":\"Ciao\"}}]}\n");
	feed(chat, @"data: {\"choices\":[{\"delta\":{\"content\":\", come \"}}]}\n");
	feed(chat, @"data: {\"choices\":[{\"delta\":{\"content\":\"va?\"}}]}\n");
	feed(chat, @"data: [DONE]\n");
	ok([[chat sofar] isEqualToString:@"Ciao, come va?"],
		@"three events become one sentence", [chat sofar]);
	ok([seen count] == 3, @"and each one showed what there was so far",
		[NSString stringWithFormat:@"%lu times", (unsigned long)[seen count]]);
	ok([[seen objectAtIndex:0] isEqualToString:@"Ciao"],
		@"the first of them being the first word", [seen objectAtIndex:0]);

	printf("\n--- Claude's shape ---\n");

	NekoStream *claude = staged(claudeText, [NSMutableArray array], [NSMutableArray array]);
	feed(claude, @"event: message_start\n"
		@"data: {\"type\":\"message_start\",\"message\":{\"id\":\"x\"}}\n\n");
	feed(claude, @"event: content_block_delta\n"
		@"data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Buon\"}}\n\n");
	feed(claude, @"event: content_block_delta\n"
		@"data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"giorno\"}}\n\n");
	feed(claude, @"event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n");
	ok([[claude sofar] isEqualToString:@"Buongiorno"],
		@"the deltas become one word and the envelopes are ignored", [claude sofar]);

	printf("\n--- and bytes arriving where they like ---\n");

	/* The thing that actually goes wrong: a chunk does not end on a line. */
	NekoStream *split = staged(openAIText, [NSMutableArray array], [NSMutableArray array]);
	feed(split, @"data: {\"choices\":[{\"delta\":{\"conte");
	ok([[split sofar] length] == 0, @"half a line says nothing yet", [split sofar]);
	feed(split, @"nt\":\"metà\"}}]}\n");
	ok([[split sofar] isEqualToString:@"metà"],
		@"and the other half completes it", [split sofar]);

	/* And a line split between the two bytes of a multi-byte character, which is
	   where a naive reader turns an accent into a question mark. */
	NekoStream *midChar = staged(openAIText, [NSMutableArray array], [NSMutableArray array]);
	NSData *whole = [@"data: {\"choices\":[{\"delta\":{\"content\":\"perché\"}}]}\n"
		dataUsingEncoding:NSUTF8StringEncoding];
	NSUInteger cut = [whole length] - 6;      /* inside the é */
	[midChar consume:[whole subdataWithRange:NSMakeRange(0, cut)]];
	[midChar consume:[whole subdataWithRange:NSMakeRange(cut, [whole length] - cut)]];
	ok([[midChar sofar] isEqualToString:@"perché"],
		@"a character split across two chunks survives", [midChar sofar]);

	NekoStream *noisy = staged(openAIText, [NSMutableArray array], [NSMutableArray array]);
	feed(noisy, @": keep-alive\n\n");
	feed(noisy, @"\n");
	feed(noisy, @"event: ping\n");
	feed(noisy, @"data: {\"choices\":[{\"delta\":{}}]}\n");
	feed(noisy, @"data: not json at all\n");
	feed(noisy, @"data: {\"choices\":[{\"delta\":{\"content\":\"comunque\"}}]}\n");
	ok([[noisy sofar] isEqualToString:@"comunque"],
		@"keep-alives, empty deltas and rubbish are all stepped over",
		[noisy sofar]);

	printf("\n--- and the answer is the same one either way ---\n");

	/* Two chunkings of the same stream have to end in the same string, which is
	   the whole promise: the network may break it anywhere. */
	NSString *events = @"data: {\"choices\":[{\"delta\":{\"content\":\"Il gatto \"}}]}\n"
		@"data: {\"choices\":[{\"delta\":{\"content\":\"dorme sul \"}}]}\n"
		@"data: {\"choices\":[{\"delta\":{\"content\":\"tetto.\"}}]}\n"
		@"data: [DONE]\n";
	NSData *all = [events dataUsingEncoding:NSUTF8StringEncoding];
	NekoStream *atOnce = staged(openAIText, [NSMutableArray array], [NSMutableArray array]);
	[atOnce consume:all];
	NekoStream *byteByByte = staged(openAIText, [NSMutableArray array], [NSMutableArray array]);
	NSUInteger i;
	for(i = 0; i < [all length]; i++)
		[byteByByte consume:[all subdataWithRange:NSMakeRange(i, 1)]];
	ok([[atOnce sofar] isEqualToString:[byteByByte sofar]]
	   && [[atOnce sofar] isEqualToString:@"Il gatto dorme sul tetto."],
		@"all at once and one byte at a time agree",
		[NSString stringWithFormat:@"“%@” / “%@”", [atOnce sofar], [byteByByte sofar]]);

	int result = NekoTestResult();
	[pool release];
	return result;
}
