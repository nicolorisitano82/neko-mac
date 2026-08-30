#import "NekoDoors.h"
#import "NekoAsk.h"


static NekoDoors *shared = nil;

@implementation NekoDoors

+ (void)open
{
	if(shared == nil)
		shared = [[NekoDoors alloc] init];
	[NSApp setServicesProvider:shared];
	/* So the Services menu picks the entry up on the first launch after it was
	   added rather than at some later login. */
	NSUpdateDynamicServices();

	[[NSAppleEventManager sharedAppleEventManager]
		setEventHandler:shared
		    andSelector:@selector(handleURLEvent:withReply:)
		  forEventClass:kInternetEventClass
		     andEventID:kAEGetURL];
}

#pragma mark The Services entry

- (void)askAboutSelection:(NSPasteboard *)board
                 userData:(NSString *)data
                    error:(NSString **)problem
{
	NSString *selected = [board stringForType:NSPasteboardTypeString];
	selected = [selected stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if([selected length] == 0) {
		if(problem != NULL)
			*problem = NSLocalizedString(@"There was no text to ask about.", nil);
		return;
	}

	/* Long selections are somebody's document rather than a question. Trimmed
	   to what a question can be, at a word boundary, and the cat is answering
	   about it rather than reading it out. */
	if([selected length] > 600) {
		NSRange cut = [selected rangeOfString:@" "
		                              options:NSBackwardsSearch
		                                range:NSMakeRange(0, 600)];
		selected = [selected substringToIndex:
			cut.location != NSNotFound ? cut.location : 600];
	}
	[[NekoAsk sharedAsk] ask:selected];
}

#pragma mark The URL

+ (NSString *)questionInURL:(NSURL *)url
{
	if(![[[url scheme] lowercaseString] isEqualToString:@"neko"])
		return nil;
	/* neko://ask?q=… and neko:ask?q=… both reach here, and the host is the verb
	   in one shape and the path in the other. */
	NSString *verb = [[url host] length] > 0 ? [url host] : [url path];
	if([verb length] == 0) {
		NSString *rest = [url resourceSpecifier];
		NSRange mark = [rest rangeOfString:@"?"];
		verb = mark.location != NSNotFound ? [rest substringToIndex:mark.location] : rest;
	}
	verb = [verb stringByTrimmingCharactersInSet:
		[NSCharacterSet characterSetWithCharactersInString:@"/"]];
	if(![[verb lowercaseString] isEqualToString:@"ask"])
		return nil;

	/* NSURLComponents only speaks about the hierarchical shape, neko://ask?q=…,
	   and a script is as likely to write the flat one, neko:ask?q=… — where the
	   whole of it after the colon is the resource specifier and there are no
	   query items at all. Both are answered here. */
	NSString *query = [url query];
	if([query length] == 0) {
		NSString *rest = [url resourceSpecifier];
		NSRange mark = [rest rangeOfString:@"?"];
		if(mark.location != NSNotFound)
			query = [rest substringFromIndex:NSMaxRange(mark)];
	}

	NSEnumerator *e = [[query componentsSeparatedByString:@"&"] objectEnumerator];
	NSString *pair;
	while((pair = [e nextObject]) != nil) {
		NSRange equals = [pair rangeOfString:@"="];
		if(equals.location == NSNotFound)
			continue;
		if(![[[pair substringToIndex:equals.location] lowercaseString]
		        isEqualToString:@"q"])
			continue;
		NSString *value = [[pair substringFromIndex:NSMaxRange(equals)]
			stringByRemovingPercentEncoding];
		NSString *asked = [value stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		return [asked length] > 0 && [asked length] <= 600 ? asked : nil;
	}
	return nil;
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event
             withReply:(NSAppleEventDescriptor *)reply
{
	NSString *text = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSString *question = [NekoDoors questionInURL:[NSURL URLWithString:text ?: @""]];
	if([question length] == 0)
		return;

	/* Read back before it is asked. A URL can come from a web page, and a web
	   page is the one place this application has never taken instructions from —
	   so what arrives from one is a proposal, in the same bubble and with the
	   same yes as everything else that came from outside this room. */
	[[NekoAsk sharedAsk] proposeQuestion:question];
}

@end
