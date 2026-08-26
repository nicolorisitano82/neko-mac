#import "NekoPlace.h"
#import <CoreLocation/CoreLocation.h>

NSString * const NekoPlaceTownKey   = @"NekoPlaceTown";
NSString * const NekoPlaceRegionKey = @"NekoPlaceRegion";
NSString * const NekoPlaceAskedKey  = @"NekoPlaceAsked";

@implementation NekoPlace

+ (NekoPlace *)sharedPlace
{
	static NekoPlace *shared = nil;
	if(shared == nil)
		shared = [[NekoPlace alloc] init];
	return shared;
}

- (void)dealloc
{
	[manager release];
	[report release];
	[super dealloc];
}

+ (BOOL)isAvailable
{
	if(NSClassFromString(@"CLLocationManager") == Nil)
		return NO;
	return [CLLocationManager locationServicesEnabled];
}

+ (NSInteger)authorizationStatus
{
	if(NSClassFromString(@"CLLocationManager") == Nil)
		return 1;
	CLAuthorizationStatus status;
	if(@available(macOS 11.0, *))
		status = [[[[CLLocationManager alloc] init] autorelease] authorizationStatus];
	else
		status = [CLLocationManager authorizationStatus];
	switch(status) {
		case kCLAuthorizationStatusNotDetermined: return 0;
		case kCLAuthorizationStatusDenied:        return 1;
		case kCLAuthorizationStatusRestricted:    return 2;
		default:                                  return 3;
	}
}

#pragma mark What is already known

- (NSString *)town
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:NekoPlaceTownKey];
}

- (NSString *)region
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:NekoPlaceRegionKey];
}

/* The time zone, which every Mac has and nobody has to allow. Europe/Rome is
   Italy whether or not anyone ever presses the location button. */
- (NSString *)country
{
	NSString *fromLocale = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
	if([fromLocale length] == 2)
		return [fromLocale uppercaseString];
	NSString *zone = [[NSTimeZone systemTimeZone] name];
	if([zone hasPrefix:@"Europe/Rome"])
		return @"IT";
	return nil;
}

- (BOOL)mayLook
{
	if(![NekoPlace isAvailable])
		return NO;
	NSInteger status = [NekoPlace authorizationStatus];
	return status == 0 || status == 3;
}

- (void)forget
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:NekoPlaceTownKey];
	[defaults removeObjectForKey:NekoPlaceRegionKey];
	[defaults removeObjectForKey:NekoPlaceAskedKey];
}

#pragma mark Finding out

- (BOOL)askedToday
{
	NSDate *last = [[NSUserDefaults standardUserDefaults] objectForKey:NekoPlaceAskedKey];
	if(![last isKindOfClass:[NSDate class]])
		return NO;
	return [[NSCalendar currentCalendar] isDateInToday:last];
}

- (void)finishWith:(NSString *)town region:(NSString *)region
{
	looking = NO;
	void (^done)(NSString *, NSString *) = [report retain];
	[report release];
	report = nil;

	if([town length] > 0 || [region length] > 0) {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if([town length] > 0)
			[defaults setObject:town forKey:NekoPlaceTownKey];
		if([region length] > 0)
			[defaults setObject:region forKey:NekoPlaceRegionKey];
		[defaults setObject:[NSDate date] forKey:NekoPlaceAskedKey];
	}

	if(done != NULL) {
		done([self town], [self region]);
		[done release];
	}
}

- (void)findOut:(void (^)(NSString *town, NSString *region))done
{
	if(!looking && [self askedToday] && [[self town] length] > 0) {
		/* Already known, and a town does not move. */
		if(done != NULL)
			done([self town], [self region]);
		return;
	}
	if(![self mayLook]) {
		if(done != NULL)
			done([self town], [self region]);
		return;
	}

	[report release];
	report = [done copy];
	looking = YES;

	if(manager == nil) {
		CLLocationManager *locations = [[CLLocationManager alloc] init];
		[locations setDelegate:(id)self];
		/* A town, not a street: the coarser accuracy is both enough and less to
		   ask for. */
		if(@available(macOS 11.0, *))
			[locations setDesiredAccuracy:kCLLocationAccuracyReduced];
		else
			[locations setDesiredAccuracy:kCLLocationAccuracyKilometer];
		manager = locations;
	}

	if([NekoPlace authorizationStatus] == 0) {
		if(@available(macOS 11.0, *))
			[(CLLocationManager *)manager requestWhenInUseAuthorization];
	}
	[(CLLocationManager *)manager requestLocation];

	/* macOS answers a location request when it feels like it, and sometimes not
	   at all. Whoever asked gets an answer either way. */
	[self performSelector:@selector(giveUp) withObject:nil afterDelay:15.0];
}

- (void)giveUp
{
	if(looking)
		[self finishWith:nil region:nil];
}

#pragma mark What CoreLocation says

- (void)locationManager:(id)locations didUpdateLocations:(NSArray *)positions
{
	CLLocation *where = [positions lastObject];
	if(where == nil) {
		[self finishWith:nil region:nil];
		return;
	}

	/* Apple's own lookup, on the system, and the coordinates go no further than
	   this method. */
	CLGeocoder *geocoder = [[[CLGeocoder alloc] init] autorelease];
	[geocoder reverseGeocodeLocation:where
	              completionHandler:^(NSArray *marks, NSError *error) {
		CLPlacemark *mark = [marks firstObject];
		dispatch_async(dispatch_get_main_queue(), ^{
			[NSObject cancelPreviousPerformRequestsWithTarget:self
			                                         selector:@selector(giveUp) object:nil];
			[self finishWith:[mark locality] region:[mark administrativeArea]];
		});
	}];
}

- (void)locationManager:(id)locations didFailWithError:(NSError *)error
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	                                         selector:@selector(giveUp) object:nil];
	[self finishWith:nil region:nil];
}

@end
