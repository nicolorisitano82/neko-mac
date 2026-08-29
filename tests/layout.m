/* Every pair of controls in every tab, and every control that runs off the edge
   of its tab. Counts as well as overlaps: a view that was never created is a
   silent no-op, and the count is what catches it. Exits non-zero on any
   complaint, so that a stale binary cannot report success.

   The plugins window is in here too now. It was left out when it was new, which
   was 2.5, and it stopped being new some releases ago — and it is the window
   where the sentence saying what a plugin sends out of this Mac is drawn, which
   is a bad sentence to have quietly clipped. */

#import <Cocoa/Cocoa.h>
#import "NekoController.h"
#import "NekoPluginsPanel.h"
#import "NekoPlugins.h"
#import "NekoPlugin.h"

static int complaints = 0;

static NSString *describe(NSView *view)
{
	NSString *what = NSStringFromClass([view class]);
	if([view respondsToSelector:@selector(title)] && [(id)view title] != nil)
		return [NSString stringWithFormat:@"%@ “%@”", what, [(id)view title]];
	if([view respondsToSelector:@selector(stringValue)]) {
		NSString *value = [(id)view stringValue];
		if([value length] > 0)
			return [NSString stringWithFormat:@"%@ “%@”", what,
				[value length] > 34 ? [[value substringToIndex:34]
					stringByAppendingString:@"…"] : value];
	}
	return what;
}

/* A plugin whose row is as tall as a row gets: a summary of real length, a route
   that adds a sentence naming where what you say goes, and a name long enough to
   crowd the switch. */
static NSURL *stagePlugin(void)
{
	NSDictionary *route = [NSDictionary dictionaryWithObjectsAndKeys:
		@"lookup", @"Identifier",
		[NSArray arrayWithObject:@"quando parte il treno per"], @"Phrases",
		@"Somebody Else's Railway", @"Says",
		@"departures, from the railway's own page", @"Summary",
		@"https://example.invalid/trains?to=%@", @"Url", nil];
	NSDictionary *manifest = [NSDictionary dictionaryWithObjectsAndKeys:
		@"com.example.layout", @"Identifier",
		@"A Plugin With A Rather Long Name", @"Name",
		@"1.0", @"Version",
		@"Somebody With A Long Name Too", @"Author",
		[NSNumber numberWithInteger:1], @"Interface",
		@"This one exists to make the tallest row the window can be asked to draw: "
		@"a summary of the length somebody actually writes when they are being "
		@"honest about where the words go and what is done with them.", @"Summary",
		[NSArray arrayWithObject:@"network"], @"Wants",
		[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:route]
		                            forKey:@"Routes"], @"Extends", nil];

	NSString *path = [NSTemporaryDirectory()
		stringByAppendingPathComponent:@"neko-layout.nekoplugin"];
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:path
	                          withIntermediateDirectories:YES attributes:nil error:NULL];
	if(![manifest writeToFile:[path stringByAppendingPathComponent:@"plugin.plist"]
	               atomically:YES])
		return nil;
	return [NSURL fileURLWithPath:path];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NekoController *controller = [NekoController sharedController];
	[controller showPreferences:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

	NSTabView *tabs = nil;
	NSWindow *window;
	NSEnumerator *w = [[NSApp windows] objectEnumerator];
	while((window = [w nextObject]) != nil) {
		NSEnumerator *s = [[[window contentView] subviews] objectEnumerator];
		NSView *view;
		while((view = [s nextObject]) != nil)
			if([view isKindOfClass:[NSTabView class]])
				tabs = (NSTabView *)view;
	}
	if(tabs == nil) {
		printf("no preferences window was built\n");
		return 1;
	}

	/* Tabs, and then whatever scrolls inside them: putting a list in a scroll
	   view is how the permissions rows stopped overflowing, and a check that
	   stops at the scroll view would call that fixed without looking. */
	NSMutableArray *places = [NSMutableArray array];
	NSMutableArray *names = [NSMutableArray array];
	NSEnumerator *items = [[tabs tabViewItems] objectEnumerator];
	NSTabViewItem *item;
	while((item = [items nextObject]) != nil) {
		[places addObject:[item view]];
		[names addObject:[item label]];
		NSEnumerator *inside = [[[item view] subviews] objectEnumerator];
		NSView *maybe;
		while((maybe = [inside nextObject]) != nil)
			if([maybe isKindOfClass:[NSScrollView class]]
			   && [(NSScrollView *)maybe documentView] != nil) {
				[places addObject:[(NSScrollView *)maybe documentView]];
				[names addObject:[NSString stringWithFormat:@"%@ ↓", [item label]]];
			}
	}

	/* And the plugins window, with a plugin staged inside it whose row is the
	   worst case there is: a long summary, and a route, which adds the sentence
	   about what it sends out of this Mac. */
	NSURL *staged = stagePlugin();
	NekoPlugins *registry = [NekoPlugins sharedPlugins];
	NSString *refused = staged != nil ? [registry installFrom:staged] : @"not staged";
	NekoPlugin *installed = [registry pluginWithIdentifier:@"com.example.layout"];
	if(installed != nil)
		[registry setEnabled:YES for:installed];
	else
		printf("  (the staged plugin could not be installed: %s)\n",
			[(refused ?: @"no reason given") UTF8String]);

	NekoPluginsPanel *panel = [NekoPluginsPanel sharedPanel];
	[panel show:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.6]];
	NSWindow *pluginsWindow = [panel window];
	if(pluginsWindow == nil) {
		printf("no plugins window was built\n");
		complaints++;
	} else {
		[places addObject:[pluginsWindow contentView]];
		[names addObject:@"Plugins"];
		NSEnumerator *inside = [[[pluginsWindow contentView] subviews] objectEnumerator];
		NSView *maybe;
		while((maybe = [inside nextObject]) != nil)
			if([maybe isKindOfClass:[NSScrollView class]]
			   && [(NSScrollView *)maybe documentView] != nil) {
				[places addObject:[(NSScrollView *)maybe documentView]];
				[names addObject:@"Plugins ↓"];
			}
	}

	NSUInteger place;
	for(place = 0; place < [places count]; place++) {
		NSView *container = [places objectAtIndex:place];
		NSArray *views = [container subviews];
		NSRect room = [container bounds];
		int overlaps = 0, outside = 0, clipped = 0;
		NSUInteger i, j;
		for(i = 0; i < [views count]; i++) {
			NSView *a = [views objectAtIndex:i];
			if([a isHidden])
				continue;
			if(!NSContainsRect(NSInsetRect(room, -2.0f, -2.0f), [a frame])) {
				printf("  outside the tab: %s %s\n", [describe(a) UTF8String],
					[NSStringFromRect([a frame]) UTF8String]);
				outside++;
			}
			/* A paragraph taller than the space it was given is a paragraph
			   with its last line cut off. */
			if([a isKindOfClass:[NSTextField class]] && [[(NSTextField *)a cell] wraps]
			   && ![(NSTextField *)a isEditable]) {   /* a field's bezel is not text */
				NSSize needed = [[(NSTextField *)a cell] cellSizeForBounds:
					NSMakeRect(0.0f, 0.0f, NSWidth([a frame]), 10000.0f)];
				if(needed.height > NSHeight([a frame]) + 1.0f) {
					printf("  clipped by %.0f pt: %s\n",
						needed.height - NSHeight([a frame]), [describe(a) UTF8String]);
					/* Counted, not merely printed. It was printed and not counted
					   until the plugins window came under this harness and three
					   clipped paragraphs turned up at once — one of them the
					   sentence saying what a plugin sends off this Mac. A
					   complaint nobody fails on is a comment. */
					clipped++;
				}
			}
			for(j = i + 1; j < [views count]; j++) {
				NSView *b = [views objectAtIndex:j];
				if([b isHidden])
					continue;
				NSRect hit = NSIntersectionRect([a frame], [b frame]);
				if(NSWidth(hit) > 0.5f && NSHeight(hit) > 0.5f) {
					printf("  overlap %.0fx%.0f: %s over %s\n",
						NSWidth(hit), NSHeight(hit),
						[describe(a) UTF8String], [describe(b) UTF8String]);
					overlaps++;
				}
			}
		}
		printf("%-24s %2lu controls, %d overlaps, %d outside, %d clipped\n",
			[[names objectAtIndex:place] UTF8String],
			(unsigned long)[views count], overlaps, outside, clipped);
		complaints += overlaps + outside + clipped;
	}

	if(installed != nil)
		[registry remove:installed];

	printf("\n%d complaints\n", complaints);
	[pool release];
	return complaints == 0 ? 0 : 1;
}
