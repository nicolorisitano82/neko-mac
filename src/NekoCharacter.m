#import "NekoCharacter.h"

/* Manifest key of every state, indexed by NekoState. */
static NSString * const NekoStateKeys[NekoStateCount] = {
	@"stop", @"jare", @"kaki", @"akubi", @"sleep", @"awake",
	@"u_move", @"d_move", @"l_move", @"r_move",
	@"ul_move", @"ur_move", @"dl_move", @"dr_move",
	@"u_togi", @"d_togi", @"l_togi", @"r_togi"
};

/* State to borrow the frames from when a manifest does not describe one.
   Diagonals fall back to the nearest cardinal, everything else eventually
   reaches "stop", which every character must provide. */
static const NekoState NekoStateFallbacks[NekoStateCount] = {
	NekoStateStop,   /* stop, the root of every chain */
	NekoStateStop,   /* jare */
	NekoStateStop,   /* kaki */
	NekoStateStop,   /* akubi */
	NekoStateStop,   /* sleep */
	NekoStateStop,   /* awake */
	NekoStateStop,   /* u_move */
	NekoStateStop,   /* d_move */
	NekoStateStop,   /* l_move */
	NekoStateStop,   /* r_move */
	NekoStateLMove,  /* ul_move */
	NekoStateRMove,  /* ur_move */
	NekoStateLMove,  /* dl_move */
	NekoStateRMove,  /* dr_move */
	NekoStateKaki,   /* u_togi */
	NekoStateKaki,   /* d_togi */
	NekoStateKaki,   /* l_togi */
	NekoStateKaki    /* r_togi */
};

static NSString * const NekoCharacterExtension = @"nekochar";
static NSString * const NekoCharacterDirectory = @"Characters";

@implementation NekoCharacter

#pragma mark Discovery

+ (NSArray *)availableCharacters
{
	static NSArray *cached = nil;
	if(cached != nil)
		return cached;

	NSString *root = [[[NSBundle mainBundle] resourcePath]
		stringByAppendingPathComponent:NekoCharacterDirectory];
	NSArray *entries = [[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:root error:NULL];
	NSMutableArray *characters = [NSMutableArray array];

	NSEnumerator *e = [entries objectEnumerator];
	NSString *entry;
	while((entry = [e nextObject]) != nil) {
		if(![[entry pathExtension] isEqualToString:NekoCharacterExtension])
			continue;
		NekoCharacter *character = [[[NekoCharacter alloc]
			initWithPath:[root stringByAppendingPathComponent:entry]] autorelease];
		if(character != nil)
			[characters addObject:character];
	}

	[characters sortUsingSelector:@selector(compareByName:)];
	cached = [characters copy];
	return cached;
}

+ (NekoCharacter *)characterWithIdentifier:(NSString *)theIdentifier
{
	NSArray *characters = [self availableCharacters];
	NSEnumerator *e = [characters objectEnumerator];
	NekoCharacter *character;
	while((character = [e nextObject]) != nil)
		if([[character identifier] isEqualToString:theIdentifier])
			return character;
	return ([characters count] > 0) ? [characters objectAtIndex:0] : nil;
}

- (NSComparisonResult)compareByName:(NekoCharacter *)other
{
	return [[self name] caseInsensitiveCompare:[other name]];
}

#pragma mark Loading

- (id)initWithPath:(NSString *)path
{
	if((self = [super init]) == nil)
		return nil;

	NSString *manifestPath = [path stringByAppendingPathComponent:@"character.plist"];
	NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:manifestPath];
	if(manifest == nil) {
		NSLog(@"Neko: %@ has no readable character.plist", path);
		[self release];
		return nil;
	}

	identifier = [[manifest objectForKey:@"Identifier"] copy];
	if(identifier == nil)
		identifier = [[[path lastPathComponent] stringByDeletingPathExtension] copy];
	name = [[manifest objectForKey:@"Name"] copy];
	if(name == nil)
		name = [identifier copy];

	float width = [[manifest objectForKey:@"SpriteWidth"] floatValue];
	float height = [[manifest objectForKey:@"SpriteHeight"] floatValue];
	spriteSize = NSMakeSize(width > 0.0f ? width : 32.0f,
	                        height > 0.0f ? height : 32.0f);

	NSDictionary *states = [manifest objectForKey:@"States"];
	int i;
	for(i = 0; i < NekoStateCount; i++) {
		NSDictionary *state = [states objectForKey:NekoStateKeys[i]];
		frames[i] = [[self imagesInDirectory:path
		                          fileNames:[state objectForKey:@"Frames"]] retain];
		unsigned ticks = [[state objectForKey:@"TicksPerFrame"] unsignedIntValue];
		ticksPerFrame[i] = (ticks > 0) ? ticks : 1;
	}

	if([frames[NekoStateStop] count] == 0) {
		NSLog(@"Neko: %@ describes no usable \"stop\" state", path);
		[self release];
		return nil;
	}
	return self;
}

- (NSArray *)imagesInDirectory:(NSString *)path fileNames:(NSArray *)fileNames
{
	NSMutableArray *images = [NSMutableArray array];
	NSEnumerator *e = [fileNames objectEnumerator];
	NSString *fileName;
	while((fileName = [e nextObject]) != nil) {
		NSString *file = [path stringByAppendingPathComponent:fileName];
		NSImage *image = [[NSImage alloc] initWithContentsOfFile:file];
		if(image == nil) {
			NSLog(@"Neko: cannot load frame %@", file);
			continue;
		}
		[images addObject:image];
		[image release];
	}
	return images;
}

- (void)dealloc
{
	int i;
	for(i = 0; i < NekoStateCount; i++)
		[frames[i] release];
	[identifier release];
	[name release];
	[super dealloc];
}

#pragma mark Accessors

- (NSString *)identifier
{
	return identifier;
}

- (NSString *)name
{
	return name;
}

- (NSSize)spriteSize
{
	return spriteSize;
}

/* Walks the fallback chain until a described state turns up. */
- (NekoState)resolvedState:(NekoState)state
{
	int hops;
	for(hops = 0; hops < NekoStateCount; hops++) {
		if(state < 0 || state >= NekoStateCount)
			return NekoStateStop;
		if([frames[state] count] > 0)
			return state;
		state = NekoStateFallbacks[state];
	}
	return NekoStateStop;
}

- (NSArray *)framesForState:(NekoState)state
{
	return frames[[self resolvedState:state]];
}

- (unsigned)ticksPerFrameForState:(NekoState)state
{
	return ticksPerFrame[[self resolvedState:state]];
}

- (NSImage *)menuBarImage
{
	NSImage *image = [[[self framesForState:NekoStateStop] objectAtIndex:0] copy];
	[image setSize:NSMakeSize(18.0f, 18.0f)];
	[image setTemplate:YES];
	return [image autorelease];
}

@end
