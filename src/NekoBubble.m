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
- (BOOL)tailAtBottom;
@end

@implementation NekoBubbleView

- (void)setTailAtBottom:(BOOL)atBottom offset:(float)offset
{
	tailAtBottom = atBottom;
	tailOffset = offset;
	[self setNeedsDisplay:YES];
}

- (BOOL)tailAtBottom
{
	return tailAtBottom;
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

	saveButton = [[NSButton alloc] initWithFrame:NSZeroRect];
	[saveButton setBezelStyle:NSBezelStyleRounded];
	[saveButton setControlSize:NSControlSizeSmall];
	[saveButton setFont:[NSFont systemFontOfSize:
		[NSFont systemFontSizeForControlSize:NSControlSizeSmall]]];
	[saveButton setTitle:NSLocalizedString(@"Save", nil)];
	[saveButton setTarget:self];
	[saveButton setAction:@selector(savePicture:)];
	[saveButton setHidden:YES];

	yesButton = [[NSButton alloc] initWithFrame:NSZeroRect];
	[yesButton setBezelStyle:NSBezelStyleRounded];
	[yesButton setControlSize:NSControlSizeSmall];
	[yesButton setTitle:NSLocalizedString(@"Yes", nil)];
	[yesButton setTarget:self];
	[yesButton setAction:@selector(saidYes:)];
	[yesButton setHidden:YES];

	noButton = [[NSButton alloc] initWithFrame:NSZeroRect];
	[noButton setBezelStyle:NSBezelStyleRounded];
	[noButton setControlSize:NSControlSizeSmall];
	[noButton setTitle:NSLocalizedString(@"No", nil)];
	[noButton setTarget:self];
	[noButton setAction:@selector(saidNo:)];
	[noButton setHidden:YES];

	/* Smaller and dimmer than the words on purpose: it is the app talking, not
	   the cat, and it should never be read first. */
	hintLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
	[hintLabel setBezeled:NO];
	[hintLabel setDrawsBackground:NO];
	[hintLabel setEditable:NO];
	[hintLabel setSelectable:NO];
	[hintLabel setFont:[NSFont systemFontOfSize:11.0f]];
	[hintLabel setTextColor:[NSColor secondaryLabelColor]];
	[hintLabel setHidden:YES];
	[[self contentView] addSubview:hintLabel];

	picture = [[NSImageView alloc] initWithFrame:NSZeroRect];
	[picture setImageScaling:NSImageScaleProportionallyUpOrDown];
	[picture setHidden:YES];
	[[self contentView] addSubview:picture];
	[[self contentView] addSubview:saveButton];   /* above the picture */
	[[self contentView] addSubview:yesButton];
	[[self contentView] addSubview:noButton];
	return self;
}

- (void)dealloc
{
	[dismissal invalidate];
	[label release];
	[hintLabel release];
	[hint release];
	[picture release];
	[saveButton release];
	[yesButton release];
	[noButton release];
	[decision release];
	[hover release];
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

- (void)setHint:(NSString *)line
{
	if(hint == line || [hint isEqualToString:line])
		return;
	[hint release];
	hint = [line copy];
	/* Already on screen: grow or shrink for it now rather than at the next
	   thing that gets said — keeping whatever was left of its welcome, since
	   redrawing is not a reason for a bubble to become permanent. */
	if([self isVisible] && lastText != nil) {
		NSTimeInterval left = dismissal != nil
			? [[dismissal fireDate] timeIntervalSinceNow] : 0.0;
		[self showText:lastText picture:[picture image]
		      nearRect:lastCat dismissAfter:(left > 0.0 ? left : 0.0)];
	}
}

- (NSString *)hint
{
	return hint;
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
	if(lastText != text) {
		[lastText release];
		lastText = [(text ?: @"") copy];
	}
	lastCat = catFrame;

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

	/* The hint sits on its own row under the words, measured the same way. */
	float hintWidth = 0.0f, hintHeight = 0.0f;
	[hintLabel setStringValue:(hint ?: @"")];
	[hintLabel setHidden:([hint length] == 0)];
	if([hint length] > 0) {
		NSSize small = [[hintLabel cell] cellSizeForBounds:
			NSMakeRect(0.0f, 0.0f, room, 10000.0f)];
		hintWidth = ceilf(MIN(small.width, room));
		hintHeight = ceilf(small.height) + 4.0f;
	}

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

	float contentWidth = MAX(MAX(textWidth, hintWidth), drawn.width);
	float gap = (image != nil && [text length] > 0) ? NekoBubbleGapUnderPicture : 0.0f;
	float width = contentWidth + 2.0f * NekoBubblePadding;
	float height = textHeight + hintHeight + drawn.height + gap
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
	if(hintHeight > 0.0f)
		[hintLabel setFrame:NSMakeRect(NekoBubblePadding, bottom,
		                               contentWidth, hintHeight - 4.0f)];
	[label setFrame:NSMakeRect(NekoBubblePadding, bottom + hintHeight,
	                           contentWidth, textHeight)];
	[picture setImage:image];
	[picture setHidden:(image == nil)];
	[saveButton setHidden:YES];
	[yesButton setHidden:YES];
	[noButton setHidden:YES];
	[saveButton setTitle:NSLocalizedString(@"Save", nil)];
	[saveButton setEnabled:YES];
	if(image != nil) {
		NSRect where = NSMakeRect(NekoBubblePadding + (contentWidth - drawn.width) / 2.0f,
		                          bottom + hintHeight + textHeight + gap,
		                          drawn.width, drawn.height);
		[picture setFrame:where];
		/* Top right of the drawing, a few points in, out of the way of whatever
		   the picture is of. */
		NSSize wanted = [saveButton intrinsicContentSize];
		[saveButton setFrame:NSMakeRect(NSMaxX(where) - wanted.width - 8.0f,
		                                NSMaxY(where) - wanted.height - 8.0f,
		                                wanted.width, wanted.height)];
	}

	/* The button only exists while the pointer is over the bubble, so a picture
	   is a picture until somebody reaches for it. */
	if(hover != nil) {
		[[self contentView] removeTrackingArea:hover];
		[hover release];
		hover = nil;
	}
	if(image != nil) {
		hover = [[NSTrackingArea alloc]
			initWithRect:[[self contentView] bounds]
			     options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
			       owner:self
			    userInfo:nil];
		[[self contentView] addTrackingArea:hover];
	}

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

/* A question is the text bubble with room for two buttons under the words. The
   arithmetic is the same; only the height grows. */
- (void)askText:(NSString *)text
       nearRect:(NSRect)catFrame
        decided:(void (^)(BOOL yes))block
{
	[decision release];
	decision = [block copy];

	[self setHint:nil];         /* a question with buttons says enough already */
	[self showText:text nearRect:catFrame dismissAfter:0.0];

	NSSize yesSize = [yesButton intrinsicContentSize];
	NSSize noSize = [noButton intrinsicContentSize];
	float row = MAX(yesSize.height, noSize.height);
	NSRect frame = [self frame];
	frame.size.height += row + NekoBubbleGapUnderPicture;
	if(![(NekoBubbleView *)[self contentView] tailAtBottom])
		frame.origin.y -= row + NekoBubbleGapUnderPicture;
	[self setFrame:frame display:NO];

	/* The label was placed against the bottom padding; the buttons take that
	   place and the label moves up by their height. */
	NSRect words = [label frame];
	words.origin.y += row + NekoBubbleGapUnderPicture;
	[label setFrame:words];

	float right = NSWidth(frame) - NekoBubblePadding;
	float bottom = ([(NekoBubbleView *)[self contentView] tailAtBottom]
		? NekoBubbleTail : 0.0f) + NekoBubblePadding;
	[noButton setFrame:NSMakeRect(right - noSize.width, bottom, noSize.width, row)];
	[yesButton setFrame:NSMakeRect(right - noSize.width - yesSize.width - 8.0f,
	                               bottom, yesSize.width, row)];
	[yesButton setHidden:NO];
	[noButton setHidden:NO];
	[self orderFront:nil];
}

- (void)answerWith:(BOOL)yes
{
	void (^block)(BOOL) = [decision retain];
	[decision release];
	decision = nil;
	[yesButton setHidden:YES];
	[noButton setHidden:YES];
	[self hide];
	if(block != nil) {
		block(yes);
		[block release];
	}
}

- (void)saidYes:(id)sender { [self answerWith:YES]; }
- (void)saidNo:(id)sender  { [self answerWith:NO]; }

- (NSScreen *)screenForRect:(NSRect)rect
{
	NSEnumerator *e = [[NSScreen screens] objectEnumerator];
	NSScreen *screen;
	while((screen = [e nextObject]) != nil)
		if(NSIntersectsRect([screen frame], rect))
			return screen;
	return [NSScreen mainScreen];
}

- (void)mouseEntered:(NSEvent *)event
{
	if([picture image] != nil)
		[saveButton setHidden:NO];
}

- (void)mouseExited:(NSEvent *)event
{
	[saveButton setHidden:YES];
}

/* Straight into Downloads, with the date in the name, and the button says so.
   No panel to fill in: the picture was asked for out loud, and being made to
   choose a folder afterwards is a strange price to pay for a joke. */
- (void)savePicture:(id)sender
{
	NSImage *image = [picture image];
	if(image == nil)
		return;

	NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc]
		initWithData:[image TIFFRepresentation]] autorelease];
	NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG
	                                   properties:[NSDictionary dictionary]];
	NSString *folder = [NSSearchPathForDirectoriesInDomains(
		NSDownloadsDirectory, NSUserDomainMask, YES) firstObject];
	if(png == nil || folder == nil) {
		[saveButton setTitle:NSLocalizedString(@"Failed", nil)];
		return;
	}

	NSDateFormatter *stamp = [[[NSDateFormatter alloc] init] autorelease];
	[stamp setDateFormat:@"yyyy-MM-dd HH.mm.ss"];
	NSString *file = [folder stringByAppendingPathComponent:
		[NSString stringWithFormat:NSLocalizedString(@"Neko %@.png", nil),
			[stamp stringFromDate:[NSDate date]]]];

	if([png writeToFile:file atomically:YES]) {
		[saveButton setTitle:NSLocalizedString(@"Saved", nil)];
		[saveButton setEnabled:NO];
		/* The bubble was going to close on its own; give it long enough for the
		   word "Saved" to be read. */
		[dismissal invalidate];
		dismissal = [NSTimer scheduledTimerWithTimeInterval:4.0
		                                            target:self
		                                          selector:@selector(hideByTimer:)
		                                          userInfo:nil
		                                           repeats:NO];
	} else {
		[saveButton setTitle:NSLocalizedString(@"Failed", nil)];
	}
}

- (NSTimeInterval)secondsLeft
{
	if(dismissal == nil)
		return 0.0;              /* no timer: it stays until told */
	NSTimeInterval left = [[dismissal fireDate] timeIntervalSinceNow];
	return left > 0.0 ? left : 0.0;
}

- (void)keepUpFor:(NSTimeInterval)seconds
{
	[dismissal invalidate];
	dismissal = nil;
	if(seconds <= 0.0)
		return;
	dismissal = [NSTimer scheduledTimerWithTimeInterval:seconds
	                                            target:self
	                                          selector:@selector(hideByTimer:)
	                                          userInfo:nil
	                                           repeats:NO];
}

- (void)hideByTimer:(NSTimer *)timer
{
	if(decision != nil) {
		[self answerWith:NO];
		return;
	}
	[self hide];
}

- (void)dismissByClick
{
	if(decision != nil) {
		[self answerWith:NO];   /* clicking the bubble away is not a yes */
		return;
	}
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
