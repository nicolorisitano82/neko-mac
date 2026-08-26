/* Every pair of controls in every tab, and every control that runs off the edge
   of its tab. Counts as well as overlaps: a view that was never created is a
   silent no-op, and the count is what catches it. Exits non-zero on any
   complaint, so that a stale binary cannot report success. */

#import <Cocoa/Cocoa.h>
#import "NekoController.h"

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

	NSUInteger place;
	for(place = 0; place < [places count]; place++) {
		NSView *container = [places objectAtIndex:place];
		NSArray *views = [container subviews];
		NSRect room = [container bounds];
		int overlaps = 0, outside = 0;
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
				if(needed.height > NSHeight([a frame]) + 1.0f)
					printf("  clipped by %.0f pt: %s\n",
						needed.height - NSHeight([a frame]), [describe(a) UTF8String]);
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
		printf("%-24s %2lu controls, %d overlaps, %d outside\n",
			[[names objectAtIndex:place] UTF8String],
			(unsigned long)[views count], overlaps, outside);
		complaints += overlaps + outside;
	}

	printf("\n%d complaints\n", complaints);
	[pool release];
	return complaints == 0 ? 0 : 1;
}
