#import "NekoController.h"

NSString * const NekoCharacterKey  = @"NekoCharacter";
NSString * const NekoSpeedKey      = @"NekoSpeed";
NSString * const NekoScaleKey      = @"NekoScale";
NSString * const NekoIdleSleepKey  = @"NekoIdleSleep";
NSString * const NekoPausedKey     = @"NekoPaused";

NSString * const NekoSettingsDidChangeNotification = @"NekoSettingsDidChange";

static const float NekoMinSpeed = 4.0f;
static const float NekoMaxSpeed = 30.0f;

@implementation NekoController

+ (void)initialize
{
	if(self != [NekoController class])
		return;
	[[NSUserDefaults standardUserDefaults] registerDefaults:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"neko", NekoCharacterKey,
			[NSNumber numberWithFloat:13.0f], NekoSpeedKey,
			[NSNumber numberWithFloat:1.0f], NekoScaleKey,
			[NSNumber numberWithBool:YES], NekoIdleSleepKey,
			[NSNumber numberWithBool:NO], NekoPausedKey, nil]];
}

+ (NekoController *)sharedController
{
	static NekoController *shared = nil;
	if(shared == nil)
		shared = [[NekoController alloc] init];
	return shared;
}

- (id)init
{
	if((self = [super init]) != nil) {
		[self installStatusItem];
	}
	return self;
}

- (void)dealloc
{
	[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
	[statusItem release];
	[prefsPanel release];
	[super dealloc];
}

#pragma mark Status item (tray)

- (void)installStatusItem
{
	statusItem = [[[NSStatusBar systemStatusBar]
		statusItemWithLength:NSSquareStatusItemLength] retain];

	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Neko"];
	pauseItem = [menu addItemWithTitle:@"Pause Neko"
	                           action:@selector(togglePause:)
	                    keyEquivalent:@""];
	[pauseItem setTarget:self];

	[menu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *item = [menu addItemWithTitle:@"Character" action:NULL keyEquivalent:@""];
	characterMenu = [[NSMenu alloc] initWithTitle:@"Character"];
	[self buildCharacterMenu];
	[item setSubmenu:characterMenu];

	item = [menu addItemWithTitle:@"Preferences…"
	                       action:@selector(showPreferences:)
	                keyEquivalent:@","];
	[item setTarget:self];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [menu addItemWithTitle:@"About Neko"
	                       action:@selector(showAbout:)
	                keyEquivalent:@""];
	[item setTarget:self];

	item = [menu addItemWithTitle:@"Quit Neko"
	                       action:@selector(quit:)
	                keyEquivalent:@"q"];
	[item setTarget:self];

	[statusItem setMenu:menu];
	[menu release];

	[self updateStatusItemImage];
	[self updatePauseItemTitle];
}

- (void)updateStatusItemImage
{
	NSStatusBarButton *button = [statusItem button];
	if(button == nil)
		return;
	NSImage *icon = [[self character] menuBarImage];
	if(icon != nil)
		[button setImage:icon];
	else
		[button setTitle:@"Neko"];  /* the sprites are missing, stay visible */
	[button setToolTip:@"Neko"];
}

- (void)updatePauseItemTitle
{
	[pauseItem setTitle:[self isPaused] ? @"Resume Neko" : @"Pause Neko"];
}

- (void)buildCharacterMenu
{
	[characterMenu removeAllItems];
	NSString *active = [[self character] identifier];
	NSEnumerator *e = [[NekoCharacter availableCharacters] objectEnumerator];
	NekoCharacter *character;
	while((character = [e nextObject]) != nil) {
		NSMenuItem *item = [characterMenu addItemWithTitle:[character name]
		                                           action:@selector(chooseCharacter:)
		                                    keyEquivalent:@""];
		[item setTarget:self];
		[item setRepresentedObject:[character identifier]];
		[item setState:[[character identifier] isEqualToString:active]
			? NSControlStateValueOn : NSControlStateValueOff];
	}
	if([characterMenu numberOfItems] == 0)
		[[characterMenu addItemWithTitle:@"No characters found" action:NULL
		                  keyEquivalent:@""] setEnabled:NO];
}

#pragma mark Panel

- (MyPanel *)panel
{
	return panel;
}

- (void)setPanel:(MyPanel *)thePanel
{
	panel = thePanel;
}

#pragma mark Settings

- (NekoCharacter *)character
{
	return [NekoCharacter characterWithIdentifier:
		[[NSUserDefaults standardUserDefaults] stringForKey:NekoCharacterKey]];
}

- (float)speed
{
	float speed = [[NSUserDefaults standardUserDefaults] floatForKey:NekoSpeedKey];
	if(speed < NekoMinSpeed)
		return NekoMinSpeed;
	if(speed > NekoMaxSpeed)
		return NekoMaxSpeed;
	return speed;
}

- (float)scale
{
	float scale = [[NSUserDefaults standardUserDefaults] floatForKey:NekoScaleKey];
	return (scale >= 2.0f) ? 2.0f : 1.0f;
}

- (BOOL)idleSleep
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:NekoIdleSleepKey];
}

- (BOOL)isPaused
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:NekoPausedKey];
}

- (void)settingsChanged
{
	[[NSUserDefaults standardUserDefaults] synchronize];
	/* Menu and tray icon follow the settings even when something other than the
	   menu changed them. */
	[self buildCharacterMenu];
	[self updateStatusItemImage];
	[self updatePauseItemTitle];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:NekoSettingsDidChangeNotification object:self];
}

#pragma mark Actions

- (void)togglePause:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:![self isPaused] forKey:NekoPausedKey];
	[self settingsChanged];
}

- (void)chooseCharacter:(id)sender
{
	[[NSUserDefaults standardUserDefaults]
		setObject:[sender representedObject] forKey:NekoCharacterKey];
	[self characterDidChange];
}

- (void)characterDidChange
{
	if(prefsPanel != nil)
		[characterPopUp selectItemWithTitle:[[self character] name]];
	[self settingsChanged];
}

- (void)showAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:sender];
}

- (void)quit:(id)sender
{
	[NSApp terminate:sender];
}

#pragma mark Preferences window

- (NSTextField *)labelWithString:(NSString *)string frame:(NSRect)frame
{
	NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
	[label setStringValue:string];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setEditable:NO];
	[label setSelectable:NO];
	return label;
}

- (void)buildPreferencesPanel
{
	prefsPanel = [[NSPanel alloc]
		initWithContentRect:NSMakeRect(0.0f, 0.0f, 380.0f, 240.0f)
		          styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
		            backing:NSBackingStoreBuffered
		              defer:NO];
	[prefsPanel setTitle:@"Neko Preferences"];
	[prefsPanel setReleasedWhenClosed:NO];
	[prefsPanel setHidesOnDeactivate:NO];
	[prefsPanel center];

	NSView *content = [prefsPanel contentView];

	/* Character */
	[content addSubview:[self labelWithString:@"Character:"
	                                    frame:NSMakeRect(20.0f, 188.0f, 70.0f, 17.0f)]];

	characterPopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(95.0f, 183.0f, 160.0f, 26.0f) pullsDown:NO];
	NSEnumerator *e = [[NekoCharacter availableCharacters] objectEnumerator];
	NekoCharacter *character;
	while((character = [e nextObject]) != nil)
		[characterPopUp addItemWithTitle:[character name]];
	[characterPopUp selectItemWithTitle:[[self character] name]];
	[characterPopUp setTarget:self];
	[characterPopUp setAction:@selector(takeCharacterFrom:)];
	[content addSubview:characterPopUp];
	[characterPopUp release];

	/* Speed */
	[content addSubview:[self labelWithString:@"Speed:"
	                                    frame:NSMakeRect(20.0f, 148.0f, 70.0f, 17.0f)]];

	speedSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(95.0f, 145.0f, 200.0f, 21.0f)];
	[speedSlider setMinValue:NekoMinSpeed];
	[speedSlider setMaxValue:NekoMaxSpeed];
	[speedSlider setFloatValue:[self speed]];
	[speedSlider setContinuous:YES];
	[speedSlider setTarget:self];
	[speedSlider setAction:@selector(takeSpeedFrom:)];
	[content addSubview:speedSlider];
	[speedSlider release];

	speedField = [self labelWithString:@"" frame:NSMakeRect(305.0f, 148.0f, 60.0f, 17.0f)];
	[content addSubview:speedField];

	/* Size */
	[content addSubview:[self labelWithString:@"Size:"
	                                    frame:NSMakeRect(20.0f, 106.0f, 70.0f, 17.0f)]];

	sizePopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(92.0f, 101.0f, 100.0f, 26.0f) pullsDown:NO];
	[sizePopUp addItemWithTitle:@"1×"];
	[sizePopUp addItemWithTitle:@"2×"];
	[sizePopUp selectItemAtIndex:([self scale] >= 2.0f) ? 1 : 0];
	[sizePopUp setTarget:self];
	[sizePopUp setAction:@selector(takeScaleFrom:)];
	[content addSubview:sizePopUp];
	[sizePopUp release];

	/* Idle sleep */
	sleepCheck = [[NSButton alloc] initWithFrame:NSMakeRect(94.0f, 66.0f, 260.0f, 18.0f)];
	[sleepCheck setButtonType:NSButtonTypeSwitch];
	[sleepCheck setTitle:@"Fall asleep when idle"];
	[sleepCheck setState:[self idleSleep] ? NSControlStateValueOn : NSControlStateValueOff];
	[sleepCheck setTarget:self];
	[sleepCheck setAction:@selector(takeIdleSleepFrom:)];
	[content addSubview:sleepCheck];
	[sleepCheck release];

	/* Restore defaults */
	NSButton *reset = [[NSButton alloc] initWithFrame:NSMakeRect(16.0f, 16.0f, 150.0f, 32.0f)];
	[reset setBezelStyle:NSBezelStyleRounded];
	[reset setTitle:@"Restore Defaults"];
	[reset setTarget:self];
	[reset setAction:@selector(restoreDefaults:)];
	[content addSubview:reset];
	[reset release];

	[self updateSpeedField];
}

- (void)updateSpeedField
{
	[speedField setStringValue:
		[NSString stringWithFormat:@"%.0f pt/s", [self speed] * 8.0f]];
}

- (void)syncPreferencesControls
{
	[characterPopUp selectItemWithTitle:[[self character] name]];
	[speedSlider setFloatValue:[self speed]];
	[sizePopUp selectItemAtIndex:([self scale] >= 2.0f) ? 1 : 0];
	[sleepCheck setState:[self idleSleep] ? NSControlStateValueOn : NSControlStateValueOff];
	[self updateSpeedField];
}

- (void)showPreferences:(id)sender
{
	if(prefsPanel == nil)
		[self buildPreferencesPanel];
	else
		[self syncPreferencesControls];
	[NSApp activateIgnoringOtherApps:YES];
	[prefsPanel makeKeyAndOrderFront:sender];
}

- (void)takeCharacterFrom:(id)sender
{
	NSArray *characters = [NekoCharacter availableCharacters];
	NSInteger index = [sender indexOfSelectedItem];
	if(index < 0 || index >= (NSInteger)[characters count])
		return;
	[[NSUserDefaults standardUserDefaults]
		setObject:[[characters objectAtIndex:index] identifier]
		   forKey:NekoCharacterKey];
	[self characterDidChange];
}

- (void)takeSpeedFrom:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setFloat:[sender floatValue] forKey:NekoSpeedKey];
	[self updateSpeedField];
	[self settingsChanged];
}

- (void)takeScaleFrom:(id)sender
{
	float scale = ([sender indexOfSelectedItem] == 1) ? 2.0f : 1.0f;
	[[NSUserDefaults standardUserDefaults] setFloat:scale forKey:NekoScaleKey];
	[self settingsChanged];
}

- (void)takeIdleSleepFrom:(id)sender
{
	[[NSUserDefaults standardUserDefaults]
		setBool:([sender state] == NSControlStateValueOn) forKey:NekoIdleSleepKey];
	[self settingsChanged];
}

- (void)restoreDefaults:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:NekoCharacterKey];
	[defaults removeObjectForKey:NekoSpeedKey];
	[defaults removeObjectForKey:NekoScaleKey];
	[defaults removeObjectForKey:NekoIdleSleepKey];
	[defaults removeObjectForKey:NekoPausedKey];
	if(prefsPanel != nil)
		[self syncPreferencesControls];
	[self settingsChanged];
}

@end
