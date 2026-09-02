/* Telling you a new version exists, without installing anything.

   The application goes out as an unsigned disk image, which decides the shape:
   a signed application can replace its own bundle, an unsigned one that tried
   would leave you a copy Gatekeeper refuses to open. So it asks, downloads if
   you say so, asks again, opens the image and quits — and the drag into
   Applications is yours.

   What is measurable here is the logic: which version is newer, which asset out
   of a release is the one to fetch, when the daily check is allowed to ask, and
   what the menu says. The two alerts and the progress bar are not, and the last
   step — whether another process can open a file inside this one's container —
   is measured as far as it can be and then named. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoUpdate.h"

static NSData *json(NSString *text)
{
	return [text dataUsingEncoding:NSUTF8StringEncoding];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- which version is newer, by the numbers between the dots ---\n");

	/* NSNumericSearch on the whole string reads "2.9" against "2.9.1" wrongly,
	   because a missing part is not a zero to a string comparison. */
	NSArray *pairs = [NSArray arrayWithObjects:
		@"2.13", @"2.9",    @"YES",
		@"2.13", @"2.12.1", @"YES",
		@"v2.13", @"2.13",  @"NO",
		@"2.13", @"2.13",   @"NO",
		@"2.12.1", @"2.13", @"NO",
		@"2.9.1", @"2.9",   @"YES",
		@"2.9", @"2.9.1",   @"NO",
		@"3.0", @"2.99",    @"YES",
		@"2.10", @"2.9",    @"YES",
		@"v2.14", @"v2.13", @"YES",
		@"", @"2.13",       @"NO",
		@"nonsense", @"2.13", @"NO",
		nil];
	NSUInteger i;
	for(i = 0; i < [pairs count]; i += 3) {
		NSString *candidate = [pairs objectAtIndex:i];
		NSString *current = [pairs objectAtIndex:i + 1];
		BOOL want = [[pairs objectAtIndex:i + 2] isEqualToString:@"YES"];
		BOOL got = [NekoUpdate version:candidate isNewerThan:current];
		ok(got == want, [NSString stringWithFormat:@"“%@” after “%@”",
			candidate, current], got ? @"newer" : @"not newer");
	}

	ok([[NekoUpdate runningVersion] length] > 0,
		@"and it knows which version it is", [NekoUpdate runningVersion]);

	printf("\n--- which asset out of a release ---\n");

	NSString *running = [NekoUpdate runningVersion];
	NSString *newer = [NSString stringWithFormat:@"v99.0"];

	NSDictionary *found = [NekoUpdate releaseFrom:json([NSString stringWithFormat:
		@"{\"tag_name\":\"%@\",\"html_url\":\"https://example.invalid/r\","
		@"\"assets\":["
		@"{\"name\":\"Source code.tar.gz\",\"browser_download_url\":\"https://example.invalid/t\",\"size\":10},"
		@"{\"name\":\"Neko-99.0.dmg\",\"browser_download_url\":\"https://example.invalid/d\",\"size\":30000000}"
		@"]}", newer])];
	ok(found != nil, @"a release with a disk image in it is a release", nil);
	ok([[found objectForKey:@"Version"] isEqualToString:@"99.0"],
		@"the v is off the version", [found objectForKey:@"Version"]);
	ok([[[found objectForKey:@"Download"] absoluteString] hasSuffix:@"/d"],
		@"and the image is taken, not the source archive",
		[[found objectForKey:@"Download"] absoluteString]);
	ok([[found objectForKey:@"Bytes"] longLongValue] == 30000000,
		@"with the size the server gave", nil);
	ok([[found objectForKey:@"Notes"] length] > 0,
		@"and the page to read about it", nil);

	printf("\n--- and every answer that is not one ---\n");

	ok([NekoUpdate releaseFrom:json([NSString stringWithFormat:
		@"{\"tag_name\":\"%@\",\"assets\":[{\"name\":\"Neko.dmg\","
		@"\"browser_download_url\":\"https://example.invalid/d\",\"size\":1}]}",
		running])] == nil,
		@"this version is not a newer version", running);
	ok([NekoUpdate releaseFrom:json([NSString stringWithFormat:
		@"{\"tag_name\":\"%@\",\"assets\":[{\"name\":\"Source code.zip\","
		@"\"browser_download_url\":\"https://example.invalid/z\",\"size\":1}]}",
		newer])] == nil,
		@"a release with nothing to install is nothing to offer", nil);
	ok([NekoUpdate releaseFrom:json([NSString stringWithFormat:
		@"{\"tag_name\":\"%@\",\"assets\":[]}", newer])] == nil,
		@"and neither is a release with no assets at all", nil);
	ok([NekoUpdate releaseFrom:json(@"{\"message\":\"Not Found\"}")] == nil,
		@"GitHub saying no is not a release", nil);
	ok([NekoUpdate releaseFrom:json(@"not json at all")] == nil,
		@"and neither is rubbish", nil);
	ok([NekoUpdate releaseFrom:nil] == nil, @"and neither is nothing", nil);

	printf("\n--- the menu says nothing until there is something ---\n");

	NekoUpdate *update = [NekoUpdate sharedUpdate];
	ok([update menuTitle] == nil,
		@"no row in the menu with no version waiting",
		[update menuTitle] ?: @"absent");
	ok([update availableVersion] == nil, @"and nothing on offer", nil);
	ok(![update isDownloading] && ![update isChecking],
		@"and it is not doing anything by itself", nil);

	printf("\n--- and the switch is what stops it asking ---\n");

	/* Saved and put back: whether somebody wants this switched on is their
	   business, and a harness that answers the question by changing the answer
	   is the pattern tests/brains.m already refuses. */
	NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
	NSString *stampKey = @"NekoUpdateLastChecked";
	BOOL wanted = [settings boolForKey:NekoUpdateCheckKey];
	id stampBefore = [[[settings objectForKey:stampKey] copy] autorelease];

	ok([settings boolForKey:NekoUpdateCheckKey],
		@"looking for versions is on unless turned off — see NekoUpdate.h", nil);

	/* -checkQuietly must not reach the network with the switch off. Measured
	   through the stamp it would leave behind: it writes the date it last asked,
	   so an unchanged stamp is a check that did not happen. */
	NSString *stamp = stampKey;
	[settings removeObjectForKey:stamp];
	[settings setBool:NO forKey:NekoUpdateCheckKey];
	[update checkQuietly];
	spin(0.4);
	ok([settings objectForKey:stamp] == nil,
		@"with it off, nothing is asked", nil);

	[settings setBool:YES forKey:NekoUpdateCheckKey];
	[settings setObject:[NSDate date] forKey:stamp];
	[update checkQuietly];
	spin(0.4);
	ok(![update isChecking],
		@"and asked twice in a day, the second one does not go", nil);

	[settings setBool:wanted forKey:NekoUpdateCheckKey];
	if(stampBefore != nil)
		[settings setObject:stampBefore forKey:stampKey];
	else
		[settings removeObjectForKey:stampKey];
	ok([settings boolForKey:NekoUpdateCheckKey] == wanted,
		@"and the setting is put back the way it was",
		wanted ? @"on" : @"off");

	printf("\n--- the one step that needs a person ---\n");

	/* The download lands inside the application's container, and the disk image
	   is opened by DiskImageMounter, which is a different process. Whether
	   LaunchServices hands that process access to a file inside this one's
	   container is the only part of this feature a harness cannot settle: this
	   harness is not sandboxed, so its own -openURL: proves nothing about the
	   application's.
	   What *can* be settled is the necessary half — that the file is readable
	   from outside the container by a process running as this user at all. If
	   that failed, the container would be the wrong place and no permission
	   would help. */
	NSURL *support = [[[NSFileManager defaultManager]
		URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask]
		firstObject];
	NSURL *updates = [[support URLByAppendingPathComponent:@"Neko"]
		URLByAppendingPathComponent:@"Updates"];
	[[NSFileManager defaultManager] createDirectoryAtURL:updates
	                         withIntermediateDirectories:YES
	                                          attributes:nil error:NULL];
	NSURL *pretend = [updates URLByAppendingPathComponent:@"zzq-not-an-image.dmg"];
	ok([@"not really a disk image" writeToURL:pretend atomically:YES
	                                encoding:NSUTF8StringEncoding error:NULL],
		@"a file can be put where the download would go", [updates path]);
	ok([[NSFileManager defaultManager] isReadableFileAtPath:[pretend path]],
		@"and read back from outside by this user", nil);
	[[NSFileManager defaultManager] removeItemAtURL:pretend error:NULL];
	/* And the folder too, if this harness is what made it: leaving an empty
	   Updates directory in somebody's Application Support is litter. */
	if([[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[updates path]
	                                                        error:NULL] count] == 0)
		[[NSFileManager defaultManager] removeItemAtURL:updates error:NULL];

	notMeasured(@"the sufficient half is a person's: install a build, wait for it "
	            @"to offer a version, and see whether the image mounts. If it "
	            @"does not, -askAboutOpening: reveals the file in the Finder and "
	            @"says so, and the answer would be the Downloads entitlement");

	notMeasured(@"and neither alert nor progress bar is measured here: both are "
	            @"modal and a harness pressing its own buttons proves nothing "
	            @"about the sentences on them");

	[pool release];
	return NekoTestResult();
}
