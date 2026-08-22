#import "NekoController.h"
#import "NekoHotKey.h"
#import "NekoModelProvider.h"
#import "NekoAppleProvider.h"
#import "NekoOpenAIProvider.h"
#import "NekoModelProvider.h"

NSString * const NekoCharacterKey  = @"NekoCharacter";
NSString * const NekoSpeedKey      = @"NekoSpeed";
NSString * const NekoScaleKey      = @"NekoScale";
NSString * const NekoStopRadiusKey = @"NekoStopRadius";
NSString * const NekoIdleSleepKey  = @"NekoIdleSleep";
NSString * const NekoWanderKey     = @"NekoWander";
NSString * const NekoBehaviourKey  = @"NekoBehaviour";
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
			[NSNumber numberWithBool:YES], NekoWanderKey,
			@"follow", NekoBehaviourKey,
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

	askItem = [menu addItemWithTitle:NekoLocalized(@"Ask Neko")
	                         action:@selector(askNeko:)
	                  keyEquivalent:@""];
	[askItem setTarget:self];

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

	[self updateAskItem];
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

/* One slot that changes identity: the question when the feature is on, the way
   to turn it on when it is off. A greyed out item that does nothing is noise,
   and a checkmark would hide the five settings behind it. */
- (void)updateAskItem
{
	NekoAsk *ask = [NekoAsk sharedAsk];
	if([ask isEnabled]) {
		[askItem setTitle:[NSString stringWithFormat:@"%@  (%@)",
			NekoLocalized(@"Ask Neko"), [ask hotKeyDisplayName]]];
		[askItem setAction:@selector(askNeko:)];
	} else {
		/* The ellipsis is the promise that a window opens. */
		[askItem setTitle:NekoLocalized(@"Set up Ask Neko…")];
		[askItem setAction:@selector(showAskPreferences:)];
	}
	[askItem setTarget:self];
	[askItem setEnabled:YES];
}

- (void)showAskPreferences:(id)sender
{
	[self showPreferences:sender];
	[prefsTabs selectTabViewItemAtIndex:1];
}

- (void)askNeko:(id)sender
{
	[[NekoAsk sharedAsk] toggle:sender];
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

- (BOOL)wandersWhenIdle
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:NekoWanderKey];
}

/* Two behaviours that cannot be mixed: chasing the pointer means resting
   wherever it stopped, living on windows means being pulled down onto them. */
- (BOOL)livesOnWindowEdges
{
	return [[[NSUserDefaults standardUserDefaults] stringForKey:NekoBehaviourKey]
		isEqualToString:@"windows"];
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

- (void)takeWanderFrom:(id)sender
{
	[[NSUserDefaults standardUserDefaults]
		setBool:([sender state] == NSControlStateValueOn) forKey:NekoWanderKey];
	[self settingsChanged];
}

- (void)takeBehaviourFrom:(id)sender
{
	[[NSUserDefaults standardUserDefaults]
		setObject:([sender indexOfSelectedItem] == 1) ? @"windows" : @"follow"
		   forKey:NekoBehaviourKey];
	[self updateWanderAvailability];
	[self settingsChanged];
}

/* Wandering is what an idle cursor-chaser does. A cat living on the Dock is
   already moving about on its own, so the two cannot both be on. */
- (void)updateWanderAvailability
{
	BOOL follows = ![self livesOnWindowEdges];
	[wanderCheck setEnabled:follows];
	[wanderCheck setToolTip:follows ? nil
		: NekoLocalized(@"Only while following the cursor")];
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
	[self updateAskItem];
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
	[label setAlignment:NSTextAlignmentRight];
	return label;
}

- (void)buildPreferencesPanel
{
	prefsPanel = [[NSPanel alloc]
		initWithContentRect:NSMakeRect(0.0f, 0.0f, 494.0f, 390.0f)
		          styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
		            backing:NSBackingStoreBuffered
		              defer:NO];
	[prefsPanel setTitle:NekoLocalized(@"Neko Preferences")];
	[prefsPanel setReleasedWhenClosed:NO];
	[prefsPanel setHidesOnDeactivate:NO];
	[prefsPanel center];

	/* Two tabs: the cat, and the conversation. One window's worth of controls
	   each, rather than one window with two windows' worth. */
	NSTabView *tabs = [[NSTabView alloc]
		initWithFrame:NSInsetRect([[prefsPanel contentView] bounds], 8.0f, 8.0f)];
	[[prefsPanel contentView] addSubview:tabs];
	prefsTabs = tabs;            /* to open straight onto a tab */

	NSView *content = [[[NSView alloc]
		initWithFrame:NSMakeRect(0.0f, 0.0f, 470.0f, 340.0f)] autorelease];
	NSTabViewItem *petTab = [[[NSTabViewItem alloc] initWithIdentifier:@"pet"] autorelease];
	[petTab setLabel:NekoLocalized(@"Pet")];
	[petTab setView:content];
	[tabs addTabViewItem:petTab];

	NSView *askContent = [[[NSView alloc]
		initWithFrame:NSMakeRect(0.0f, 0.0f, 470.0f, 340.0f)] autorelease];
	NSTabViewItem *askTab = [[[NSTabViewItem alloc] initWithIdentifier:@"ask"] autorelease];
	[askTab setLabel:NekoLocalized(@"Ask Neko")];
	[askTab setView:askContent];
	[tabs addTabViewItem:askTab];
	[tabs release];

	/* Behaviour */
	[content addSubview:[self labelWithString:NekoLocalized(@"Behaviour:")
	                                    frame:NSMakeRect(20.0f, 96.0f, 125.0f, 17.0f)]];

	behaviourPopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(152.0f, 91.0f, 260.0f, 26.0f) pullsDown:NO];
	[behaviourPopUp addItemWithTitle:NekoLocalized(@"Follows the cursor")];
	[behaviourPopUp addItemWithTitle:NekoLocalized(@"Lives on the Dock")];
	[behaviourPopUp selectItemAtIndex:[self livesOnWindowEdges] ? 1 : 0];
	[behaviourPopUp setTarget:self];
	[behaviourPopUp setAction:@selector(takeBehaviourFrom:)];
	[content addSubview:behaviourPopUp];
	[behaviourPopUp release];

	/* Character */
	[content addSubview:[self labelWithString:NekoLocalized(@"Character:")
	                                    frame:NSMakeRect(20.0f, 298.0f, 125.0f, 17.0f)]];

	characterPopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(152.0f, 293.0f, 170.0f, 26.0f) pullsDown:NO];
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
	                                    frame:NSMakeRect(20.0f, 258.0f, 125.0f, 17.0f)]];

	speedSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(152.0f, 255.0f, 200.0f, 21.0f)];
	[speedSlider setMinValue:NekoMinSpeed];
	[speedSlider setMaxValue:NekoMaxSpeed];
	[speedSlider setFloatValue:[self speed]];
	[speedSlider setContinuous:YES];
	[speedSlider setTarget:self];
	[speedSlider setAction:@selector(takeSpeedFrom:)];
	[content addSubview:speedSlider];
	[speedSlider release];

	speedField = [self labelWithString:@"" frame:NSMakeRect(362.0f, 258.0f, 90.0f, 17.0f)];
	[content addSubview:speedField];

	/* How close it comes */
	[content addSubview:[self labelWithString:NekoLocalized(@"Stops short by:")
	                                    frame:NSMakeRect(20.0f, 218.0f, 125.0f, 17.0f)]];

	radiusSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(152.0f, 215.0f, 200.0f, 21.0f)];
	[radiusSlider setMinValue:NekoMinStopRadius];
	[radiusSlider setMaxValue:NekoMaxStopRadius];
	[radiusSlider setFloatValue:[self stopRadius]];
	[radiusSlider setContinuous:YES];
	[radiusSlider setTarget:self];
	[radiusSlider setAction:@selector(takeStopRadiusFrom:)];
	[content addSubview:radiusSlider];
	[radiusSlider release];

	radiusField = [self labelWithString:@"" frame:NSMakeRect(362.0f, 218.0f, 90.0f, 17.0f)];
	[content addSubview:radiusField];

	/* Size */
	[content addSubview:[self labelWithString:NekoLocalized(@"Size:")
	                                    frame:NSMakeRect(20.0f, 176.0f, 125.0f, 17.0f)]];

	sizePopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(152.0f, 171.0f, 100.0f, 26.0f) pullsDown:NO];
	[sizePopUp addItemWithTitle:@"1\u00d7"];
	[sizePopUp addItemWithTitle:@"2\u00d7"];
	[sizePopUp selectItemAtIndex:([self scale] >= 2.0f) ? 1 : 0];
	[sizePopUp setTarget:self];
	[sizePopUp setAction:@selector(takeScaleFrom:)];
	[content addSubview:sizePopUp];
	[sizePopUp release];

	/* Idle sleep */
	sleepCheck = [[NSButton alloc] initWithFrame:NSMakeRect(154.0f, 144.0f, 300.0f, 18.0f)];
	[sleepCheck setButtonType:NSButtonTypeSwitch];
	[sleepCheck setTitle:NekoLocalized(@"Fall asleep when idle")];
	[sleepCheck setState:[self idleSleep] ? NSControlStateValueOn : NSControlStateValueOff];
	[sleepCheck setTarget:self];
	[sleepCheck setAction:@selector(takeIdleSleepFrom:)];
	[content addSubview:sleepCheck];
	[sleepCheck release];

	/* Wandering */
	wanderCheck = [[NSButton alloc] initWithFrame:NSMakeRect(154.0f, 120.0f, 300.0f, 18.0f)];
	[wanderCheck setButtonType:NSButtonTypeSwitch];
	[wanderCheck setTitle:NekoLocalized(@"Wander off when idle")];
	[wanderCheck setState:[self wandersWhenIdle] ? NSControlStateValueOn : NSControlStateValueOff];
	[wanderCheck setTarget:self];
	[wanderCheck setAction:@selector(takeWanderFrom:)];
	[content addSubview:wanderCheck];
	[wanderCheck release];

	/* Opening at login */
	loginCheck = [[NSButton alloc] initWithFrame:NSMakeRect(154.0f, 72.0f, 300.0f, 18.0f)];
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
	NSButton *reset = [[NSButton alloc] initWithFrame:NSMakeRect(16.0f, 20.0f, 180.0f, 32.0f)];
	[reset setBezelStyle:NSBezelStyleRounded];
	[reset setTitle:NekoLocalized(@"Restore Defaults")];
	[reset setTarget:self];
	[reset setAction:@selector(restoreDefaults:)];
	[content addSubview:reset];
	[reset release];

	[self buildAskTab:askContent];
	[self updateWanderAvailability];
	[self updateValueFields];
}

/* The conversation tab. Everything below the switch is disabled until the
   switch is on, so the shape of the feature is visible before turning it on. */
- (void)buildAskTab:(NSView *)content
{
	NekoAsk *ask = [NekoAsk sharedAsk];

	askCheck = [[NSButton alloc] initWithFrame:NSMakeRect(20.0f, 300.0f, 400.0f, 18.0f)];
	[askCheck setButtonType:NSButtonTypeSwitch];
	[askCheck setTitle:NekoLocalized(@"Let me ask Neko questions out loud")];
	[askCheck setState:[ask isEnabled] ? NSControlStateValueOn : NSControlStateValueOff];
	[askCheck setTarget:self];
	[askCheck setAction:@selector(takeAskEnabledFrom:)];
	[content addSubview:askCheck];
	[askCheck release];

	[content addSubview:[self labelWithString:NekoLocalized(@"Keystroke:")
	                                    frame:NSMakeRect(20.0f, 262.0f, 125.0f, 17.0f)]];
	askHotKeyPopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(152.0f, 257.0f, 160.0f, 26.0f) pullsDown:NO];
	NSEnumerator *e = [[self hotKeyChoices] objectEnumerator];
	NSArray *choice;
	while((choice = [e nextObject]) != nil)
		[askHotKeyPopUp addItemWithTitle:[NekoHotKey
			displayNameForKeyCode:[[choice objectAtIndex:0] unsignedShortValue]
			            modifiers:[[choice objectAtIndex:1] unsignedIntegerValue]]];
	[askHotKeyPopUp setTarget:self];
	[askHotKeyPopUp setAction:@selector(takeAskHotKeyFrom:)];
	[content addSubview:askHotKeyPopUp];
	[askHotKeyPopUp release];

	[content addSubview:[self labelWithString:NekoLocalized(@"Answers from:")
	                                    frame:NSMakeRect(20.0f, 222.0f, 125.0f, 17.0f)]];
	askProviderPopUp = [[NSPopUpButton alloc]
		initWithFrame:NSMakeRect(152.0f, 217.0f, 220.0f, 26.0f) pullsDown:NO];
	/* Same order as askProviderKeys. */
	[askProviderPopUp addItemWithTitle:NekoLocalized(@"Apple Intelligence, on this Mac")];
	[askProviderPopUp addItemWithTitle:NekoLocalized(@"ChatGPT")];
	[askProviderPopUp addItemWithTitle:NekoLocalized(@"Claude")];
	[askProviderPopUp addItemWithTitle:NekoLocalized(@"A Shortcut of mine")];
	[askProviderPopUp setTarget:self];
	[askProviderPopUp setAction:@selector(takeAskProviderFrom:)];
	[content addSubview:askProviderPopUp];
	[askProviderPopUp release];

	[content addSubview:[self labelWithString:NekoLocalized(@"Shortcut name:")
	                                    frame:NSMakeRect(20.0f, 182.0f, 125.0f, 17.0f)]];
	askShortcutField = [[NSTextField alloc] initWithFrame:NSMakeRect(152.0f, 179.0f, 220.0f, 22.0f)];
	[askShortcutField setTarget:self];
	[askShortcutField setAction:@selector(takeAskShortcutNameFrom:)];
	[content addSubview:askShortcutField];
	[askShortcutField release];

	[content addSubview:[self labelWithString:NekoLocalized(@"API key:")
	                                    frame:NSMakeRect(20.0f, 142.0f, 125.0f, 17.0f)]];
	askKeyField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(152.0f, 139.0f, 220.0f, 22.0f)];
	[askKeyField setTarget:self];
	[askKeyField setAction:@selector(takeAskKeyFrom:)];
	[content addSubview:askKeyField];
	[askKeyField release];

	askSpeakCheck = [[NSButton alloc] initWithFrame:NSMakeRect(152.0f, 106.0f, 300.0f, 18.0f)];
	[askSpeakCheck setButtonType:NSButtonTypeSwitch];
	[askSpeakCheck setTitle:NekoLocalized(@"Read the answer aloud")];
	[askSpeakCheck setTarget:self];
	[askSpeakCheck setAction:@selector(takeAskSpeakFrom:)];
	[content addSubview:askSpeakCheck];
	[askSpeakCheck release];

	askStatusField = [self labelWithString:@"" frame:NSMakeRect(20.0f, 20.0f, 430.0f, 68.0f)];
	[askStatusField setAlignment:NSTextAlignmentLeft];
	[[askStatusField cell] setWraps:YES];
	[askStatusField setFont:[NSFont systemFontOfSize:11.0f]];
	[askStatusField setTextColor:[NSColor secondaryLabelColor]];
	[content addSubview:askStatusField];

	[self syncAskControls];
}

/* The combinations offered. A recorder field would be nicer; a short list of
   things that do not collide with anything is more useful sooner. */
- (NSArray *)hotKeyChoices
{
	NSUInteger control = NSEventModifierFlagControl;
	NSUInteger option = NSEventModifierFlagOption;
	NSUInteger command = NSEventModifierFlagCommand;
	NSUInteger shift = NSEventModifierFlagShift;
	return [NSArray arrayWithObjects:
		[NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:0x2D],
			[NSNumber numberWithUnsignedInteger:control | option], nil],
		[NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:0x31],
			[NSNumber numberWithUnsignedInteger:control | option], nil],
		[NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:0x2D],
			[NSNumber numberWithUnsignedInteger:command | control], nil],
		[NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:0x2D],
			[NSNumber numberWithUnsignedInteger:option | shift], nil], nil];
}

- (void)syncAskControls
{
	NekoAsk *ask = [NekoAsk sharedAsk];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL on = [ask isEnabled];
	NSString *choice = [defaults stringForKey:NekoAskProviderKey];
	BOOL shortcut = [choice isEqualToString:@"shortcut"];
	id keyed = [self askKeyedProvider];
	NSUInteger providerIndex = [[self askProviderKeys] indexOfObject:choice ?: @"apple"];
	if(providerIndex == NSNotFound)
		providerIndex = 0;

	[askCheck setState:on ? NSControlStateValueOn : NSControlStateValueOff];
	[askHotKeyPopUp setEnabled:on];
	[askProviderPopUp setEnabled:on];
	[askProviderPopUp selectItemAtIndex:providerIndex];
	[askShortcutField setEnabled:on && shortcut];
	[askShortcutField setStringValue:
		[defaults stringForKey:NekoAskShortcutNameKey] ?: @""];
	[askKeyField setEnabled:on && keyed != nil];
	[askKeyField setStringValue:[keyed hasApiKey] ? @"••••••••••••" : @""];
	[askSpeakCheck setEnabled:on];
	[askSpeakCheck setState:[defaults boolForKey:NekoAskSpeakKey]
		? NSControlStateValueOn : NSControlStateValueOff];

	/* Which combination is selected, if it is one of the offered ones. */
	unsigned short code = (unsigned short)[defaults integerForKey:NekoAskHotKeyCodeKey];
	NSUInteger flags = (NSUInteger)[defaults integerForKey:NekoAskHotKeyModifiersKey];
	NSArray *choices = [self hotKeyChoices];
	NSUInteger i;
	for(i = 0; i < [choices count]; i++) {
		NSArray *choice = [choices objectAtIndex:i];
		if([[choice objectAtIndex:0] unsignedShortValue] == code
		   && [[choice objectAtIndex:1] unsignedIntegerValue] == flags) {
			[askHotKeyPopUp selectItemAtIndex:i];
			break;
		}
	}

	[askStatusField setStringValue:[self askStatusLine]];
}

- (NSString *)askStatusLine
{
	NekoAsk *ask = [NekoAsk sharedAsk];
	if(![ask isEnabled])
		return NekoLocalized(@"The microphone is asked for the first time you use this, never before.");
	if([ask hotKeyUnavailable])
		return NekoLocalized(@"Another application already owns that keystroke. Pick a different one.");

	NSString *hint = [[ask provider] configurationHint];
	if(hint != nil)
		return hint;
	return [NSString stringWithFormat:
		NekoLocalized(@"Press %@ and ask. Neko listens until you stop talking."),
		[ask hotKeyDisplayName]];
}

#pragma mark Ask Neko actions

- (void)takeAskEnabledFrom:(id)sender
{
	[[NSUserDefaults standardUserDefaults]
		setBool:([sender state] == NSControlStateValueOn) forKey:NekoAskEnabledKey];
	[[NekoAsk sharedAsk] applySettings];
	[self updateAskItem];
	[self syncAskControls];
}

- (void)takeAskHotKeyFrom:(id)sender
{
	NSArray *choice = [[self hotKeyChoices] objectAtIndex:[sender indexOfSelectedItem]];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setInteger:[[choice objectAtIndex:0] unsignedShortValue]
	              forKey:NekoAskHotKeyCodeKey];
	[defaults setInteger:(NSInteger)[[choice objectAtIndex:1] unsignedIntegerValue]
	              forKey:NekoAskHotKeyModifiersKey];
	[[NekoAsk sharedAsk] applySettings];
	[self updateAskItem];
	[self syncAskControls];
}

/* The order the popup is built in. */
- (NSArray *)askProviderKeys
{
	return [NSArray arrayWithObjects:@"apple", @"openai", @"model", @"shortcut", nil];
}

- (void)takeAskProviderFrom:(id)sender
{
	NSArray *keys = [self askProviderKeys];
	NSInteger index = [sender indexOfSelectedItem];
	[[NSUserDefaults standardUserDefaults]
		setObject:[keys objectAtIndex:(index >= 0 && index < (NSInteger)[keys count]) ? index : 0]
		   forKey:NekoAskProviderKey];
	[self syncAskControls];
}

/* Whichever key-holding provider is selected, or nil for the two that need no
   key. The field below writes to this one. */
- (id)askKeyedProvider
{
	NSString *choice = [[NSUserDefaults standardUserDefaults] stringForKey:NekoAskProviderKey];
	if([choice isEqualToString:@"model"])
		return [[NekoAsk sharedAsk] modelProvider];
	if([choice isEqualToString:@"openai"])
		return [[NekoAsk sharedAsk] openaiProvider];
	return nil;
}

- (void)takeAskShortcutNameFrom:(id)sender
{
	[[NSUserDefaults standardUserDefaults]
		setObject:[sender stringValue] forKey:NekoAskShortcutNameKey];
	[self syncAskControls];
}

- (void)takeAskKeyFrom:(id)sender
{
	NSString *typed = [sender stringValue];
	if([typed hasPrefix:@"•"])
		return;                  /* the placeholder, not a new key */
	/* Each provider keeps its own key, so switching between them loses neither. */
	[[self askKeyedProvider] setApiKey:typed];
	[self syncAskControls];
}

- (void)takeAskSpeakFrom:(id)sender
{
	[[NSUserDefaults standardUserDefaults]
		setBool:([sender state] == NSControlStateValueOn) forKey:NekoAskSpeakKey];
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
	[wanderCheck setState:[self wandersWhenIdle] ? NSControlStateValueOn : NSControlStateValueOff];
	[behaviourPopUp selectItemAtIndex:[self livesOnWindowEdges] ? 1 : 0];
	[self updateWanderAvailability];
	[self syncAskControls];
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
	[defaults removeObjectForKey:NekoWanderKey];
	[defaults removeObjectForKey:NekoBehaviourKey];
	[defaults removeObjectForKey:NekoPausedKey];
	if(prefsPanel != nil)
		[self syncPreferencesControls];
	[self settingsChanged];
}

@end
