#import "NekoController.h"

NSString * const NekoCharacterKey  = @"NekoCharacter";
NSString * const NekoSpeedKey      = @"NekoSpeed";
NSString * const NekoScaleKey      = @"NekoScale";
NSString * const NekoStopRadiusKey = @"NekoStopRadius";
NSString * const NekoIdleSleepKey  = @"NekoIdleSleep";
NSString * const NekoPausedKey     = @"NekoPaused";

NSString * const NekoSettingsDidChangeNotification = @"NekoSettingsDidChange";

/* SMAppService arrived in macOS 13 and registers the app itself as a login
   item, no helper bundle involved. It is reached through the runtime rather
   than linked, so the binary still runs on the older systems this project
   targets, where the class is simply absent. */
@protocol NekoAppService <NSObject>
- (BOOL)registerAndReturnError:(NSError **)error;
- (BOOL)unregisterAndReturnError:(NSError **)error;
- (NSInteger)status;
@end

@protocol NekoAppServiceClass <NSObject>
- (id)mainAppService;
@end

/* SMAppServiceStatus */
enum {
	NekoLoginNotRegistered = 0,
	NekoLoginEnabled = 1,
	NekoLoginRequiresApproval = 2,
	NekoLoginNotFound = 3
};

/* The English text doubles as the lookup key, so a missing translation falls
   back to English on its own and there is no English table to keep in step. */
#define NekoLocalized(text) NSLocalizedString(text, nil)

static const float NekoMinSpeed = 4.0f;
static const float NekoMaxSpeed = 30.0f;

/* How close the cat is allowed to get to the pointer. 0 puts it right under
   the cursor, which is what it did before the setting existed. */
static const float NekoMinStopRadius = 0.0f;
static const float NekoMaxStopRadius = 200.0f;

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
			[NSNumber numberWithFloat:48.0f], NekoStopRadiusKey,
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
	pauseItem = [menu addItemWithTitle:NekoLocalized(@"Pause Neko")
	                           action:@selector(togglePause:)
	                    keyEquivalent:@""];
	[pauseItem setTarget:self];

	[menu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *item = [menu addItemWithTitle:NekoLocalized(@"Character") action:NULL keyEquivalent:@""];
	characterMenu = [[NSMenu alloc] initWithTitle:NekoLocalized(@"Character")];
	[self buildCharacterMenu];
	[item setSubmenu:characterMenu];

	item = [menu addItemWithTitle:NekoLocalized(@"Preferences…")
	                       action:@selector(showPreferences:)
	                keyEquivalent:@","];
	[item setTarget:self];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [menu addItemWithTitle:NekoLocalized(@"About Neko")
	                       action:@selector(showAbout:)
	                keyEquivalent:@""];
	[item setTarget:self];

	item = [menu addItemWithTitle:NekoLocalized(@"Quit Neko")
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
	[pauseItem setTitle:[self isPaused] ? NekoLocalized(@"Resume Neko")
	                                   : NekoLocalized(@"Pause Neko")];
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
		[[characterMenu addItemWithTitle:NekoLocalized(@"No characters found") action:NULL
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

- (float)stopRadius
{
	float radius = [[NSUserDefaults standardUserDefaults] floatForKey:NekoStopRadiusKey];
	if(radius < NekoMinStopRadius)
		return NekoMinStopRadius;
	if(radius > NekoMaxStopRadius)
		return NekoMaxStopRadius;
	return radius;
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

#pragma mark Opening at login

- (id<NekoAppService>)loginService
{
	Class serviceClass = NSClassFromString(@"SMAppService");
	if (serviceClass == Nil)
		return nil;
	return [(id<NekoAppServiceClass>)serviceClass mainAppService];
}

- (BOOL)canOpenAtLogin
{
	return [self loginService] != nil;
}

- (BOOL)opensAtLogin
{
	id<NekoAppService> service = [self loginService];
	if (service == nil)
		return NO;
	NSInteger status = [service status];
	return status == NekoLoginEnabled || status == NekoLoginRequiresApproval;
}

/* Returns whether the system now agrees, so the checkbox can follow it rather
   than the click. */
- (BOOL)setOpensAtLogin:(BOOL)wanted
{
	id<NekoAppService> service = [self loginService];
	if (service == nil)
		return NO;

	NSError *error = nil;
	BOOL ok = wanted ? [service registerAndReturnError:&error]
	                 : [service unregisterAndReturnError:&error];
	if (!ok)
		NSLog(@"Neko: could not %@ as a login item: %@",
		      wanted ? @"register" : @"unregister", error);
	else if (wanted && [service status] == NekoLoginRequiresApproval)
		[self explainLoginApproval];
	return [self opensAtLogin];
}

/* Registering succeeds but stays inert until the user allows it, and nothing
   says so unless we do. */
- (void)explainLoginApproval
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:NekoLocalized(@"Neko needs your approval to open at login")];
	[alert setInformativeText:NekoLocalized(@"Open System Settings, then Login Items, and allow Neko.")];
	[alert addButtonWithTitle:NekoLocalized(@"OK")];
	[NSApp activateIgnoringOtherApps:YES];
	[alert runModal];
}

- (void)takeOpenAtLoginFrom:(id)sender
{
	BOOL wanted = ([sender state] == NSControlStateValueOn);
	BOOL got = [self setOpensAtLogin:wanted];
	[sender setState:got ? NSControlStateValueOn : NSControlStateValueOff];
}

#pragma mark Notifications

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
		initWithContentRect:NSMakeRect(0.0f, 0.0f, 445.0f, 280.0f)
		          styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
		            backing:NSBackingStoreBuffered
		              defer:NO];
	[prefsPanel setTitle:NekoLocalized(@"Neko Preferences")];
	[prefsPanel setReleasedWhenClosed:NO];
	[prefsPanel setHidesOnDeactivate:NO];
	[prefsPanel center];

	NSView *content = [prefsPanel contentView];

	/* Character */
	[content addSubview:[self labelWithString:NekoLocalized(@"Character:")
	                                    frame:NSMakeRect(20.0f, 238.0f, 105.0f, 17.0f)]];

	characterPopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(127.0f, 233.0f, 170.0f, 26.0f) pullsDown:NO];
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
	[content addSubview:[self labelWithString:NekoLocalized(@"Speed:")
	                                    frame:NSMakeRect(20.0f, 198.0f, 105.0f, 17.0f)]];

	speedSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(130.0f, 195.0f, 200.0f, 21.0f)];
	[speedSlider setMinValue:NekoMinSpeed];
	[speedSlider setMaxValue:NekoMaxSpeed];
	[speedSlider setFloatValue:[self speed]];
	[speedSlider setContinuous:YES];
	[speedSlider setTarget:self];
	[speedSlider setAction:@selector(takeSpeedFrom:)];
	[content addSubview:speedSlider];
	[speedSlider release];

	speedField = [self labelWithString:@"" frame:NSMakeRect(340.0f, 198.0f, 90.0f, 17.0f)];
	[content addSubview:speedField];

	/* How close it comes */
	[content addSubview:[self labelWithString:NekoLocalized(@"Stops short by:")
	                                    frame:NSMakeRect(20.0f, 158.0f, 105.0f, 17.0f)]];

	radiusSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(130.0f, 155.0f, 200.0f, 21.0f)];
	[radiusSlider setMinValue:NekoMinStopRadius];
	[radiusSlider setMaxValue:NekoMaxStopRadius];
	[radiusSlider setFloatValue:[self stopRadius]];
	[radiusSlider setContinuous:YES];
	[radiusSlider setTarget:self];
	[radiusSlider setAction:@selector(takeStopRadiusFrom:)];
	[content addSubview:radiusSlider];
	[radiusSlider release];

	radiusField = [self labelWithString:@"" frame:NSMakeRect(340.0f, 158.0f, 90.0f, 17.0f)];
	[content addSubview:radiusField];

	/* Size */
	[content addSubview:[self labelWithString:NekoLocalized(@"Size:")
	                                    frame:NSMakeRect(20.0f, 116.0f, 105.0f, 17.0f)]];

	sizePopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(127.0f, 111.0f, 100.0f, 26.0f) pullsDown:NO];
	[sizePopUp addItemWithTitle:@"1\u00d7"];
	[sizePopUp addItemWithTitle:@"2\u00d7"];
	[sizePopUp selectItemAtIndex:([self scale] >= 2.0f) ? 1 : 0];
	[sizePopUp setTarget:self];
	[sizePopUp setAction:@selector(takeScaleFrom:)];
	[content addSubview:sizePopUp];
	[sizePopUp release];

	/* Idle sleep */
	sleepCheck = [[NSButton alloc] initWithFrame:NSMakeRect(129.0f, 84.0f, 300.0f, 18.0f)];
	[sleepCheck setButtonType:NSButtonTypeSwitch];
	[sleepCheck setTitle:NekoLocalized(@"Fall asleep when idle")];
	[sleepCheck setState:[self idleSleep] ? NSControlStateValueOn : NSControlStateValueOff];
	[sleepCheck setTarget:self];
	[sleepCheck setAction:@selector(takeIdleSleepFrom:)];
	[content addSubview:sleepCheck];
	[sleepCheck release];

	/* Opening at login */
	loginCheck = [[NSButton alloc] initWithFrame:NSMakeRect(129.0f, 60.0f, 300.0f, 18.0f)];
	[loginCheck setButtonType:NSButtonTypeSwitch];
	[loginCheck setTitle:NekoLocalized(@"Open at login")];
	[loginCheck setState:[self opensAtLogin] ? NSControlStateValueOn : NSControlStateValueOff];
	[loginCheck setTarget:self];
	[loginCheck setAction:@selector(takeOpenAtLoginFrom:)];
	if (![self canOpenAtLogin]) {
		[loginCheck setEnabled:NO];
		[loginCheck setToolTip:NekoLocalized(@"Needs macOS 13 or newer")];
	}
	[content addSubview:loginCheck];
	[loginCheck release];

	/* Restore defaults */
	NSButton *reset = [[NSButton alloc] initWithFrame:NSMakeRect(16.0f, 16.0f, 180.0f, 32.0f)];
	[reset setBezelStyle:NSBezelStyleRounded];
	[reset setTitle:NekoLocalized(@"Restore Defaults")];
	[reset setTarget:self];
	[reset setAction:@selector(restoreDefaults:)];
	[content addSubview:reset];
	[reset release];

	[self updateValueFields];
}

- (void)updateValueFields
{
	[speedField setStringValue:
		[NSString stringWithFormat:NekoLocalized(@"%.0f pt/s"), [self speed] * 8.0f]];
	float radius = [self stopRadius];
	[radiusField setStringValue:(radius <= 0.0f)
		? NekoLocalized(@"touches")
		: [NSString stringWithFormat:NekoLocalized(@"%.0f pt"), radius]];
}

- (void)syncPreferencesControls
{
	[characterPopUp selectItemWithTitle:[[self character] name]];
	[speedSlider setFloatValue:[self speed]];
	[radiusSlider setFloatValue:[self stopRadius]];
	[sizePopUp selectItemAtIndex:([self scale] >= 2.0f) ? 1 : 0];
	[sleepCheck setState:[self idleSleep] ? NSControlStateValueOn : NSControlStateValueOff];
	/* The system owns this one, so it is read back rather than remembered. */
	[loginCheck setState:[self opensAtLogin] ? NSControlStateValueOn : NSControlStateValueOff];
	[self updateValueFields];
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
	[self updateValueFields];
	[self settingsChanged];
}

- (void)takeStopRadiusFrom:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setFloat:[sender floatValue] forKey:NekoStopRadiusKey];
	[self updateValueFields];
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
	[defaults removeObjectForKey:NekoStopRadiusKey];
	[defaults removeObjectForKey:NekoIdleSleepKey];
	[defaults removeObjectForKey:NekoPausedKey];
	if(prefsPanel != nil)
		[self syncPreferencesControls];
	[self settingsChanged];
}

@end
