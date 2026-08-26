/* Where this Mac is: the order the two questions have to be asked in.

   Asking macOS for a position before anybody has granted permission is answered
   immediately with a refusal, the request unwinds, and the dialog never appears
   — which is exactly what "clicking Ask does nothing" was. So the sequence is
   the thing under test, and it is tested with a manager that records what it was
   told rather than one that puts a dialog on somebody's screen. A test may not
   ask for a real permission: a refusal can only be undone in System Settings. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoPlace.h"
#import <CoreLocation/CoreLocation.h>
#import "NekoWeb.h"
#import "NekoPermissions.h"

/* Stands in for CLLocationManager and writes down what it is asked to do. */
@interface Recorder : NSObject
{
	NSMutableArray *told;
	CLAuthorizationStatus status;
}
- (NSArray *)told;
- (void)setStatus:(CLAuthorizationStatus)theStatus;
@end

@implementation Recorder
- (id)init { if((self = [super init]) != nil) told = [[NSMutableArray alloc] init]; return self; }
- (void)dealloc { [told release]; [super dealloc]; }
- (NSArray *)told { return told; }
- (void)requestWhenInUseAuthorization { [told addObject:@"permission"]; }
/* The app asks the manager what the system decided, so the stand-in has to have
   an answer: the real one is the reason this test aborted the first time. */
- (CLAuthorizationStatus)authorizationStatus { return status; }
- (void)setStatus:(CLAuthorizationStatus)theStatus { status = theStatus; }
- (void)requestLocation { [told addObject:@"position"]; }
- (void)setDelegate:(id)delegate {}
- (void)setDesiredAccuracy:(double)accuracy {}
@end

@interface StagedPlace : NekoPlace
{
	Recorder *fake;
	NSInteger staged;
}
- (void)setPermission:(NSInteger)status;
- (NSArray *)told;
@end

@implementation StagedPlace
- (id)manager
{
	if(fake == nil)
		fake = [[Recorder alloc] init];
	return fake;
}
- (NSInteger)permission { return staged; }
- (void)setPermission:(NSInteger)status
{
	staged = status;
	/* CoreLocation's own scale, which is not this app's: 1 is restricted there
	   and denied here. */
	CLAuthorizationStatus real = kCLAuthorizationStatusNotDetermined;
	if(status == 3)
		real = kCLAuthorizationStatusAuthorizedAlways;
	else if(status == 1)
		real = kCLAuthorizationStatusDenied;
	else if(status == 2)
		real = kCLAuthorizationStatusRestricted;
	[(Recorder *)[self manager] setStatus:real];
}
- (NSArray *)told { return [(Recorder *)[self manager] told]; }
@end

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	printf("\n--- what this Mac says today ---\n");
	printf("      location services: %s, permission: %ld, town: %s\n",
		[NekoPlace isAvailable] ? "on" : "off",
		(long)[NekoPlace authorizationStatus],
		[([[NekoPlace sharedPlace] town] ?: @"(not looked up)") UTF8String]);
	ok([[[NekoPlace sharedPlace] country] length] == 2,
		@"the country needs no permission at all", [[NekoPlace sharedPlace] country]);

	printf("\n--- nobody has been asked yet ---\n");

	[defaults removeObjectForKey:NekoPlaceTownKey];
	[defaults removeObjectForKey:NekoPlaceRegionKey];
	[defaults removeObjectForKey:NekoPlaceAskedKey];

	StagedPlace *place = [[StagedPlace alloc] init];
	[place setPermission:0];
	__block BOOL answered = NO;
	[place findOut:^(NSString *town, NSString *region) { answered = YES; }];
	spin(0.2);
	ok([[place told] count] == 1 && [[[place told] firstObject] isEqualToString:@"permission"],
		@"it asks for permission and stops there",
		[[place told] componentsJoinedByString:@", "]);
	ok(!answered, @"and does not pretend to have an answer yet", nil);

	printf("\n--- and when the dialog is answered ---\n");

	[place setPermission:3];
	[place performSelector:@selector(locationManagerDidChangeAuthorization:) withObject:nil];
	spin(0.2);
	ok([[place told] count] == 2 && [[[place told] lastObject] isEqualToString:@"position"],
		@"then, and only then, it asks where it is",
		[[place told] componentsJoinedByString:@", "]);

	printf("\n--- and a button asks again ---\n");

	/* The defect this exists for: with a town already known and looked up today,
	   the button returned in six milliseconds having done nothing at all. */
	[defaults setObject:@"Bovalino" forKey:NekoPlaceTownKey];
	[defaults setObject:@"Calabria" forKey:NekoPlaceRegionKey];
	[defaults setObject:[NSDate date] forKey:NekoPlaceAskedKey];
	StagedPlace *pressed = [[StagedPlace alloc] init];
	[pressed setPermission:3];
	__block BOOL answered2 = NO;
	[pressed findOut:^(NSString *town, NSString *region) { answered2 = YES; }];
	spin(0.2);
	ok([[pressed told] count] == 0 && answered2,
		@"the automatic path leaves a town found today alone", nil);
	[pressed lookAgain:^(NSString *town, NSString *region) { }];
	spin(0.2);
	ok([[pressed told] count] == 1
	   && [[[pressed told] firstObject] isEqualToString:@"position"],
		@"and a button asks the system again anyway",
		[[pressed told] componentsJoinedByString:@", "]);

	printf("\n--- and the row says what is true before the status settles ---\n");

	[defaults setObject:@"Bovalino" forKey:NekoPlaceTownKey];
	NSEnumerator *rows = [[NekoPermissions all] objectEnumerator];
	NekoPermission *row;
	while((row = [rows nextObject]) != nil) {
		if(![[row identifier] isEqualToString:@"location"])
			continue;
		ok([row permissionState] == NekoPermissionGranted,
			@"a town in hand outranks a status that has not arrived",
			[NSString stringWithFormat:@"state %ld", (long)[row permissionState]]);
		ok([[row explanation] rangeOfString:@"Bovalino"].location != NSNotFound,
			@"and the row names the place, so pressing it shows something",
			[row explanation]);
	}

	printf("\n--- refused ---\n");

	StagedPlace *refused = [[StagedPlace alloc] init];
	[refused setPermission:1];
	__block BOOL toldSo = NO;
	[refused findOut:^(NSString *town, NSString *region) { toldSo = YES; }];
	spin(0.2);
	ok([[refused told] count] == 0, @"nothing is asked of the system at all",
		[[refused told] componentsJoinedByString:@", "]);
	ok(toldSo, @"and whoever asked is told immediately", nil);

	printf("\n--- already known ---\n");

	[defaults setObject:@"Milano" forKey:NekoPlaceTownKey];
	[defaults setObject:@"Lombardia" forKey:NekoPlaceRegionKey];
	[defaults setObject:[NSDate date] forKey:NekoPlaceAskedKey];
	StagedPlace *again = [[StagedPlace alloc] init];
	[again setPermission:3];
	__block NSString *gotTown = nil;
	[again findOut:^(NSString *town, NSString *region) { gotTown = [town copy]; }];
	spin(0.2);
	ok([[again told] count] == 0 && [gotTown isEqualToString:@"Milano"],
		@"a town looked up today is not looked up again", gotTown);
	ok([[[[NekoWeb localSource] url] absoluteString] rangeOfString:@"lombardia"].location
		!= NSNotFound, @"and it is what picks the local feed",
		[[[NekoWeb localSource] url] absoluteString]);

	printf("\n--- and whatever is on screen is told ---\n");

	__block BOOL heard = NO;
	id watcher = [[NSNotificationCenter defaultCenter]
		addObserverForName:NekoPlaceDidChangeNotification object:nil queue:nil
		        usingBlock:^(NSNotification *note) { heard = YES; }];
	[place performSelector:@selector(locationManagerDidChangeAuthorization:) withObject:nil];
	spin(0.2);
	ok(heard, @"a notification goes out when the answer arrives", nil);
	[[NSNotificationCenter defaultCenter] removeObserver:watcher];

	[defaults removeObjectForKey:NekoPlaceTownKey];
	[defaults removeObjectForKey:NekoPlaceRegionKey];
	[defaults removeObjectForKey:NekoPlaceAskedKey];
	int result = NekoTestResult();
	[pool release];
	return result;
}
