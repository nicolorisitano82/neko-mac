#import "NekoBubble.h"

static const float NekoBubbleMaxWidth = 420.0f;
static const float NekoBubbleMaxPicture = 320.0f;
static const float NekoBubbleGapUnderPicture = 8.0f;
static const float NekoBubblePadding = 12.0f;
static const float NekoBubbleTail = 9.0f;
static const float NekoBubbleGap = 6.0f;
static const float NekoBubbleRadius = 10.0f;

/* Draws the rounded body and the tail. The tail points down when the bubble sits
   above the cat, which is the usual case, and up when it had to go below. */
@interface NekoBubbleView : NSView
{
	BOOL tailAtBottom;
	float tailOffset;            /* from the centre, to keep it on the cat */
}
- (void)setTailAtBottom:(BOOL)atBottom offset:(float)offset;
@end

@implementation NekoBubbleView

- (void)setTailAtBottom:(BOOL)atBottom offset:(float)offset
{
	tailAtBottom = atBottom;
	tailOffset = offset;
	[self setNeedsDisplay:YES];
}

- (BOOL)isOpaque
{
	return NO;
}

- (void)drawRect:(NSRect)dirty
{
	NSRect body = [self bounds];
	if(tailAtBottom)
		body.origin.y += NekoBubbleTail;
	body.size.height -= NekoBubbleTail;
	body = NSInsetRect(body, 0.5f, 0.5f);

	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:body
	                                                    xRadius:NekoBubbleRadius
	                                                    yRadius:NekoBubbleRadius];

	float centre = NSMidX(body) + tailOffset;
	centre = MIN(MAX(centre, NSMinX(body) + NekoBubbleRadius + NekoBubbleTail),
	             NSMaxX(body) - NekoBubbleRadius - NekoBubbleTail);
	NSBezierPath *tail = [NSBezierPath bezierPath];
	if(tailAtBottom) {
		[tail moveToPoint:NSMakePoint(centre - NekoBubbleTail, NSMinY(body) + 0.5f)];
		[tail lineToPoint:NSMakePoint(centre, NSMinY(body) - NekoBubbleTail)];
		[tail lineToPoint:NSMakePoint(centre + NekoBubbleTail, NSMinY(body) + 0.5f)];
	} else {
		[tail moveToPoint:NSMakePoint(centre - NekoBubbleTail, NSMaxY(body) - 0.5f)];
		[tail lineToPoint:NSMakePoint(centre, NSMaxY(body) + NekoBubbleTail)];
		[tail lineToPoint:NSMakePoint(centre + NekoBubbleTail, NSMaxY(body) - 0.5f)];
	}
	[tail closePath];
	[path appendBezierPath:tail];

	[[NSColor windowBackgroundColor] setFill];
	[path fill];
	/* separatorColor is 10.14, and this project still builds for 10.13. */
	[[[NSColor labelColor] colorWithAlphaComponent:0.20f] setStroke];
	[path setLineWidth:1.0f];
	[path stroke];
}

- (void)mouseDown:(NSEvent *)event
{
	[[self window] performSelector:@selector(dismissByClick)];
}

@end

@implementation NekoBubble

- (id)init
{
	self = [super initWithContentRect:NSMakeRect(0.0f, 0.0f, 200.0f, 60.0f)
	                       styleMask:(NSWindowStyleMaskBorderless
	                                  | NSWindowStyleMaskNonactivatingPanel)
	                         backing:NSBackingStoreBuffered
	                           defer:NO];
	[self setOpaque:NO];
	[self setBackgroundColor:[NSColor clearColor]];
	[self setHasShadow:YES];
	[self setLevel:NSStatusWindowLevel + 1];
	/* Wherever the cat is allowed to be, so is what it says. Without this the
	   answer arrives on the desktop the bubble was created on, while the cat
	   asking to be looked at is on the one you are using. */
	[self setCollectionBehavior:(NSWindowCollectionBehaviorCanJoinAllSpaces
	                             | NSWindowCollectionBehaviorStationary
	                             | NSWindowCollectionBehaviorIgnoresCycle
	                             | NSWindowCollectionBehaviorFullScreenAuxiliary)];
	[self setCanHide:NO];
	[self setHidesOnDeactivate:NO];
	[self setBecomesKeyOnlyIfNeeded:YES];
	[self setContentView:[[[NekoBubbleView alloc] initWithFrame:NSZeroRect] autorelease]];

	label = [[NSTextField alloc] initWithFrame:NSZeroRect];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setLineBreakMode:NSLineBreakByWordWrapping];
	[[label cell] setWraps:YES];
	[[label cell] setUsesSingleLineMode:NO];
	[[self contentView] addSubview:label];

	picture = [[NSImageView alloc] initWithFrame:NSZeroRect];
	[picture setImageScaling:NSImageScaleProportionallyUpOrDown];
	[picture setHidden:YES];
	[[self contentView] addSubview:picture];
	return self;
}

- (void)dealloc
{
	[dismissal invalidate];
	[label release];
	[picture release];
	[super dealloc];
}

- (BOOL)canBecomeKeyWindow
{
	return NO;                   /* never steal the focus */
}

- (void)setDismissalTarget:(id)target action:(SEL)action
{
	owner = target;
	dismissedAction = action;
}

+ (NSTimeInterval)readingTimeFor:(NSString *)text
{
	/* Six seconds, plus a little for every character, capped so a wall of text
	   does not stay up for a minute. */
	return MIN(6.0 + 0.04 * (double)[text length], 30.0);
}

- (void)showText:(NSString *)text
        nearRect:(NSRect)catFrame
    dismissAfter:(NSTimeInterval)seconds
{
	[self showText:text picture:nil nearRect:catFrame dismissAfter:seconds];
}

/* A drawing sits above its caption, in a bubble that is as wide as the picture
   or as wide as the words, whichever needs more. Everything else — where the
   bubble goes, which way the tail points, when it goes away — is the same
   arithmetic as for text alone. */
- (void)showText:(NSString *)text
         picture:(NSImage *)image
        nearRect:(NSRect)catFrame
    dismissAfter:(NSTimeInterval)seconds
{
	NSFont *font = [NSFont systemFontOfSize:0.0];
	[label setFont:font];
	[label setStringValue:(text ?: @"")];

	/* Measured by the cell that will draw it, not by boundingRectWithSize:.
	   A text field keeps insets of its own, so the string wraps sooner inside
	   the field than it does in a bare measurement: a sentence measured as one
	   line needs two, and the second one used to be cut off — which ate the end
	   of every short answer. */
	float room = NekoBubbleMaxWidth - 2.0f * NekoBubblePadding;
	NSSize needed = [[label cell] cellSizeForBounds:
		NSMakeRect(0.0f, 0.0f, room, 10000.0f)];

	float textWidth = ceilf(MIN(needed.width, room));
	float textHeight = [text length] > 0 ? ceilf(needed.height) : 0.0f;

	/* The picture is shown at whatever size fits the bubble's own limit, keeping
	   its proportions: a 512 pixel square becomes a 320 pixel square on screen,
	   which is a picture rather than a poster. */
	NSSize drawn = NSZeroSize;
	if(image != nil) {
		NSSize natural = [image size];
		float side = MIN(NekoBubbleMaxPicture, MAX(natural.width, natural.height));
		float scale = natural.width > 0.0f && natural.height > 0.0f
			? side / MAX(natural.width, natural.height) : 1.0f;
		drawn = NSMakeSize(ceilf(natural.width * scale), ceilf(natural.height * scale));
	}

	float contentWidth = MAX(textWidth, drawn.width);
	float gap = (image != nil && [text length] > 0) ? NekoBubbleGapUnderPicture : 0.0f;
	float width = contentWidth + 2.0f * NekoBubblePadding;
	float height = textHeight + drawn.height + gap
		+ 2.0f * NekoBubblePadding + NekoBubbleTail;

	NSScreen *screen = [self screenForRect:catFrame];
	NSRect visible = [screen visibleFrame];

	/* Above the cat by default, below when there is no room up there. */
	BOOL above = NSMaxY(catFrame) + NekoBubbleGap + height <= NSMaxY(visible);
	float y = above ? NSMaxY(catFrame) + NekoBubbleGap
	                : NSMinY(catFrame) - NekoBubbleGap - height;
	float x = NSMidX(catFrame) - width / 2.0f;
	x = MIN(MAX(x, NSMinX(visible) + 4.0f), NSMaxX(visible) - width - 4.0f);
	y = MIN(MAX(y, NSMinY(visible) + 4.0f), NSMaxY(visible) - height - 4.0f);

	[self setFrame:NSMakeRect(x, y, width, height) display:NO];
	[(NekoBubbleView *)[self contentView] setTailAtBottom:above
	                                               offset:NSMidX(catFrame) - (x + width / 2.0f)];
	float bottom = (above ? NekoBubbleTail : 0.0f) + NekoBubblePadding;
	[label setFrame:NSMakeRect(NekoBubblePadding, bottom, contentWidth, textHeight)];
	[picture setImage:image];
	[picture setHidden:(image == nil)];
	if(image != nil)
		[picture setFrame:NSMakeRect(NekoBubblePadding + (contentWidth - drawn.width) / 2.0f,
		                             bottom + textHeight + gap,
		                             drawn.width, drawn.height)];

	[self orderFront:nil];

	[dismissal invalidate];
	dismissal = nil;
	if(seconds > 0.0)
		dismissal = [NSTimer scheduledTimerWithTimeInterval:seconds
		                                            target:self
		                                          selector:@selector(hideByTimer:)
		                                          userInfo:nil
		                                           repeats:NO];
}

- (NSScreen *)screenForRect:(NSRect)rect
{
	NSEnumerator *e = [[NSScreen screens] objectEnumerator];
	NSScreen *screen;
	while((screen = [e nextObject]) != nil)
		if(NSIntersectsRect([screen frame], rect))
			return screen;
	return [NSScreen mainScreen];
}

- (void)hideByTimer:(NSTimer *)timer
{
	[self hide];
}

- (void)dismissByClick
{
	[self hide];
	if(owner != nil && dismissedAction != NULL)
		[owner performSelector:dismissedAction withObject:self];
}

- (void)hide
{
	[dismissal invalidate];
	dismissal = nil;
	[self orderOut:nil];
}

- (BOOL)isShowing
{
	return [self isVisible];
}

@end
