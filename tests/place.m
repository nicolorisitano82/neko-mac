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
#import "NekoWeb.h"

/* Stands in for CLLocationManager and writes down what it is asked to do. */
@interface Recorder : NSObject
{
	NSMutableArray *told;
}
- (NSArray *)told;
@end

@implementation Recorder
- (id)init { if((self = [super init]) != nil) told = [[NSMutableArray alloc] init]; return self; }
- (void)dealloc { [told release]; [super dealloc]; }
- (NSArray *)told { return told; }
- (void)requestWhenInUseAuthorization { [told addObject:@"permission"]; }
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
- (void)setPermission:(NSInteger)status { staged = status; }
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
