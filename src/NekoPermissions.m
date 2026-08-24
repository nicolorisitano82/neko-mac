#import "NekoPermissions.h"
#import "NekoListener.h"
#import "NekoDesktop.h"
#import "NekoWakeWord.h"
#import "NekoAsk.h"
#import "NekoController.h"
#import "NekoFolderAccess.h"
#import <AVFoundation/AVFoundation.h>

#define NekoPermissionLocalized(text) NSLocalizedString(text, nil)

@implementation NekoPermission

- (id)initWithIdentifier:(NSString *)key
{
	self = [super init];
	if(self != nil)
		identifier = [key copy];
	return self;
}

- (void)dealloc
{
	[identifier release];
	[super dealloc];
}

- (NSString *)identifier { return identifier; }

- (NSString *)name
{
	if([identifier isEqualToString:@"microphone"])
		return NekoPermissionLocalized(@"Microphone");
	if([identifier isEqualToString:@"speech"])
		return NekoPermissionLocalized(@"Speech recognition");
	if([identifier isEqualToString:@"accessibility"])
		return NekoPermissionLocalized(@"Accessibility");
	if([identifier isEqualToString:@"screen"])
		return NekoPermissionLocalized(@"Screen recording");
	if([identifier isEqualToString:@"folders"])
		return NekoPermissionLocalized(@"Your folders");
	return identifier;
}

- (NSString *)explanation
{
	if([identifier isEqualToString:@"microphone"])
		return NekoPermissionLocalized(@"Without it the cat cannot hear a question. Asked the first time you use the keystroke, never before.");
	if([identifier isEqualToString:@"speech"])
		return NekoPermissionLocalized(@"Turns what you said into words. On this Mac it stays on this Mac.");
	if([identifier isEqualToString:@"accessibility"])
		return NekoPermissionLocalized(@"Only for reading the text you are working on, which is a switch of its own on the Suggestions tab. Nothing else uses it.");
	if([identifier isEqualToString:@"screen"])
		return NekoPermissionLocalized(@"Window titles, and nothing else. Neko never asks for this one: it is used if you granted it for some other reason, and simply left out if not.");
	if([identifier isEqualToString:@"folders"])
		return NekoPermissionLocalized(@"Handed over one folder at a time, in a panel, so the cat can copy or move a file. Nothing is read until you do.");
	return @"";
}

#pragma mark What the system says

- (NekoPermissionState)permissionState
{
	if([identifier isEqualToString:@"microphone"]) {
		if(@available(macOS 10.14, *)) {
			switch([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
				case AVAuthorizationStatusAuthorized: return NekoPermissionGranted;
				case AVAuthorizationStatusDenied:
				case AVAuthorizationStatusRestricted: return NekoPermissionDenied;
				default: return NekoPermissionUnknown;
			}
		}
		return NekoPermissionGranted;      /* older systems did not ask */
	}
	if([identifier isEqualToString:@"speech"]) {
		if(![NekoListener isAvailable])
			return NekoPermissionUnavailable;
		switch([NekoListener authorizationStatus]) {
			case 3: return NekoPermissionGranted;
			case 1:
			case 2: return NekoPermissionDenied;
			default: return NekoPermissionUnknown;
		}
	}
	if([identifier isEqualToString:@"accessibility"])
		return [NekoDesktop accessibilityGranted] ? NekoPermissionGranted
		                                          : NekoPermissionUnknown;
	if([identifier isEqualToString:@"screen"])
		return CGPreflightScreenCaptureAccess() ? NekoPermissionGranted
		                                        : NekoPermissionUnknown;
	if([identifier isEqualToString:@"folders"])
		return [[[NekoFolderAccess sharedAccess] allowedKeys] count] > 0
			? NekoPermissionGranted : NekoPermissionUnknown;
	return NekoPermissionUnknown;
}

- (BOOL)isNeeded
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL asking = [[NekoAsk sharedAsk] isEnabled];
	if([identifier isEqualToString:@"microphone"] || [identifier isEqualToString:@"speech"])
		return asking;
	if([identifier isEqualToString:@"accessibility"])
		return [defaults boolForKey:NekoReadTextKey];
	if([identifier isEqualToString:@"folders"])
		return asking && [defaults boolForKey:@"NekoActionsEnabled"];
	return NO;                    /* screen recording is never needed, only used */
}

#pragma mark Asking

- (BOOL)canRequest
{
	NekoPermissionState state = [self permissionState];
	if(state == NekoPermissionGranted || state == NekoPermissionUnavailable)
		return NO;
	/* Once macOS has a no on file for one of these, only System Settings can
	   change it: asking again does nothing at all, silently, which is worse than
	   saying so. */
	if(state == NekoPermissionDenied)
		return NO;
	return YES;
}

- (void)request
{
	if([identifier isEqualToString:@"microphone"]) {
		if(@available(macOS 10.14, *))
			[AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio
			                         completionHandler:^(BOOL granted) { }];
		return;
	}
	if([identifier isEqualToString:@"speech"]) {
		[NekoListener requestAuthorization:^(BOOL granted) { }];
		return;
	}
	if([identifier isEqualToString:@"accessibility"]) {
		[NekoDesktop requestAccessibility];
		return;
	}
	if([identifier isEqualToString:@"screen"]) {
		/* The one permission the app is not supposed to want. Asked for only if
		   somebody presses the button here on purpose. */
		CGRequestScreenCaptureAccess();
		return;
	}
	if([identifier isEqualToString:@"folders"]) {
		[[NekoFolderAccess sharedAccess] requestAccessTo:@"desktop"];
		return;
	}
}

- (void)openSettings
{
	NSString *pane = nil;
	if([identifier isEqualToString:@"microphone"])
		pane = @"Privacy_Microphone";
	else if([identifier isEqualToString:@"speech"])
		pane = @"Privacy_SpeechRecognition";
	else if([identifier isEqualToString:@"accessibility"])
		pane = @"Privacy_Accessibility";
	else if([identifier isEqualToString:@"screen"])
		pane = @"Privacy_ScreenCapture";
	if(pane == nil)
		return;
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:
		[@"x-apple.systempreferences:com.apple.preference.security?" stringByAppendingString:pane]]];
}

@end


@implementation NekoPermissions

+ (NSArray *)all
{
	NSMutableArray *all = [NSMutableArray array];
	NSEnumerator *e = [[NSArray arrayWithObjects:@"microphone", @"speech",
		@"accessibility", @"folders", @"screen", nil] objectEnumerator];
	NSString *key;
	while((key = [e nextObject]) != nil)
		[all addObject:[[[NekoPermission alloc] initWithIdentifier:key] autorelease]];
	return all;
}

+ (NSArray *)missing
{
	NSMutableArray *missing = [NSMutableArray array];
	NSEnumerator *e = [[self all] objectEnumerator];
	NekoPermission *permission;
	while((permission = [e nextObject]) != nil)
		if([permission isNeeded] && [permission permissionState] != NekoPermissionGranted)
			[missing addObject:permission];
	return missing;
}

@end
