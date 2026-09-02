/* The three ways this project has quietly told itself a lie.

   Every one of these was a real mistake, made more than once, and none of them
   was caught by anything until somebody happened to look:

   1. A changelog edit that matched nothing. Three commits said they had
      documented themselves and had not, because they searched for a heading that
      had been renamed at release time. So: the version in Info.plist must have a
      section in the changelog.
   2. A cross-link into a document that does not exist, or an anchor that has been
      renamed — the same failure, wearing a different hat.
   3. A user-visible string that exists only in English. The app ships in four
      languages, and a plugin refused in an Italian app used to answer in English.

   None of this needs the app to run. It needs somebody to check. */

#import <Cocoa/Cocoa.h>
#import "support.h"

static NSString *fileAt(NSString *path)
{
	return [NSString stringWithContentsOfFile:path
	                                encoding:NSUTF8StringEncoding error:NULL] ?: @"";
}

static NSArray *markdownIn(NSString *folder)
{
	NSMutableArray *found = [NSMutableArray array];
	NSEnumerator *e = [[[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:folder error:NULL] objectEnumerator];
	NSString *name;
	while((name = [e nextObject]) != nil)
		if([[name pathExtension] isEqualToString:@"md"])
			[found addObject:[folder stringByAppendingPathComponent:name]];
	return found;
}

/* Every localisable string in a source file, whichever macro it went through. */
static NSArray *keysIn(NSString *source)
{
	NSMutableArray *keys = [NSMutableArray array];

	/* **Derived, not listed.** This used to hold twelve macro names written out
	   by hand, and by 2.14 it was missing eight: every module added with its own
	   NekoSomethingLocalized() — the clock, the sums, the diary quotations, the
	   things it cannot see, the words it learns, the updates — had its strings
	   invisible to this check, which is the one check that says whether a
	   sentence will appear in Italian. A list of names is a list somebody has to
	   remember to add to, and nobody did.
	   So: anything ending in Localized(@" counts, plus NSLocalizedString itself. */
	NSMutableArray *macros = [NSMutableArray arrayWithObject:@"NSLocalizedString(@\""];
	NSRange looking = NSMakeRange(0, [source length]);
	while(looking.length > 0) {
		NSRange found = [source rangeOfString:@"Localized(" options:0 range:looking];
		if(found.location == NSNotFound)
			break;
		/* Walk back over the identifier in front of it. */
		NSUInteger start = found.location;
		while(start > 0) {
			unichar c = [source characterAtIndex:start - 1];
			if(!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
			     || (c >= '0' && c <= '9') || c == '_'))
				break;
			start--;
		}
		/* The literal may be on the next line: NekoSomethingLocalized( then a
		   newline then @"…". Both shapes are in this source. */
		NSUInteger at = NSMaxRange(found);
		while(at < [source length]) {
			unichar c = [source characterAtIndex:at];
			if(c == ' ' || c == '\t' || c == '\n' || c == '\r') { at++; continue; }
			break;
		}
		if(at + 1 < [source length] && [source characterAtIndex:at] == '@'
		   && [source characterAtIndex:at + 1] == '"') {
			NSString *macro = [NSString stringWithFormat:@"%@@\"",
				[source substringWithRange:
					NSMakeRange(start, NSMaxRange(found) - start)]];
			if(![macros containsObject:macro])
				[macros addObject:macro];
		}
		looking = NSMakeRange(NSMaxRange(found), [source length] - NSMaxRange(found));
	}

	NSEnumerator *m = [macros objectEnumerator];
	NSString *macro;
	while((macro = [m nextObject]) != nil) {
		NSRange from = NSMakeRange(0, [source length]);
		while(from.length > 0) {
			NSRange hit = [source rangeOfString:macro options:0 range:from];
			if(hit.location == NSNotFound)
				break;
			NSUInteger start = NSMaxRange(hit);
			NSUInteger i = start;
			NSMutableString *key = [NSMutableString string];
			BOOL closed = NO;
			while(i < [source length]) {
				unichar c = [source characterAtIndex:i];
				if(c == '\\' && i + 1 < [source length]) {
					[key appendFormat:@"%C%C", c, [source characterAtIndex:i + 1]];
					i += 2;
					continue;
				}
				if(c == '"') { closed = YES; break; }
				[key appendFormat:@"%C", c];
				i++;
			}
			if(closed && [key length] > 0)
				[keys addObject:key];
			from = NSMakeRange(i, [source length] - i);
		}
	}
	return keys;
}

int main(void)
{
	[NSApplication sharedApplication];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- the changelog knows about this version ---\n");

	NSString *version = [[[NSBundle mainBundle] infoDictionary]
		objectForKey:@"CFBundleShortVersionString"];
	NSString *changelog = fileAt(@"CHANGELOG.md");
	ok([changelog length] > 0, @"there is a changelog to read", nil);
	ok([changelog rangeOfString:[NSString stringWithFormat:@"## %@", version]].location
			!= NSNotFound
	   || [changelog rangeOfString:[NSString stringWithFormat:@"— %@", version]].location
			!= NSNotFound,
		[NSString stringWithFormat:@"and a section for %@ in it", version],
		version);

	printf("\n--- every link between documents goes somewhere ---\n");

	NSMutableArray *documents = [NSMutableArray arrayWithObject:@"README.md"];
	[documents addObjectsFromArray:markdownIn(@"docs")];
	[documents addObjectsFromArray:markdownIn(@"tests")];
	NSUInteger checked = 0, broken = 0;
	NSEnumerator *d = [documents objectEnumerator];
	NSString *path;
	while((path = [d nextObject]) != nil) {
		NSString *body = fileAt(path);
		NSString *folder = [path stringByDeletingLastPathComponent];
		if([folder length] == 0)
			folder = @".";
		NSRange from = NSMakeRange(0, [body length]);
		while(from.length > 0) {
			NSRange open = [body rangeOfString:@"](" options:0 range:from];
			if(open.location == NSNotFound)
				break;
			NSRange rest = NSMakeRange(NSMaxRange(open), [body length] - NSMaxRange(open));
			NSRange close = [body rangeOfString:@")" options:0 range:rest];
			if(close.location == NSNotFound)
				break;
			NSString *target = [body substringWithRange:
				NSMakeRange(rest.location, close.location - rest.location)];
			from = NSMakeRange(NSMaxRange(close), [body length] - NSMaxRange(close));

			if([target hasPrefix:@"http"] || [target hasPrefix:@"#"]
			   || [target hasPrefix:@"mailto"])
				continue;
			NSString *file = [[target componentsSeparatedByString:@"#"] firstObject];
			if([file length] == 0)
				continue;
			checked++;
			if(![[NSFileManager defaultManager] fileExistsAtPath:
					[folder stringByAppendingPathComponent:file]]) {
				printf("  %s → %s\n", [path UTF8String], [file UTF8String]);
				broken++;
			}
		}
	}
	ok(broken == 0, @"no document points at a file that is not there",
		[NSString stringWithFormat:@"%lu links checked", (unsigned long)checked]);

	printf("\n--- and every string the app can say has four languages ---\n");

	NSArray *languages = [NSArray arrayWithObjects:@"it", @"fr", @"es", nil];
	NSMutableDictionary *tables = [NSMutableDictionary dictionary];
	NSEnumerator *l = [languages objectEnumerator];
	NSString *language;
	while((language = [l nextObject]) != nil)
		[tables setObject:fileAt([NSString stringWithFormat:
			@"Resources/%@.lproj/Localizable.strings", language]) forKey:language];

	NSMutableDictionary *missing = [NSMutableDictionary dictionary];
	NSUInteger total = 0;
	NSEnumerator *s = [[[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:@"src" error:NULL] objectEnumerator];
	NSString *name;
	while((name = [s nextObject]) != nil) {
		if(![[name pathExtension] isEqualToString:@"m"])
			continue;
		NSEnumerator *k = [keysIn(fileAt([@"src" stringByAppendingPathComponent:name]))
			objectEnumerator];
		NSString *key;
		while((key = [k nextObject]) != nil) {
			total++;
			NSEnumerator *each = [languages objectEnumerator];
			while((language = [each nextObject]) != nil) {
				NSString *quoted = [NSString stringWithFormat:@"\"%@\" =", key];
				if([[tables objectForKey:language] rangeOfString:quoted].location != NSNotFound)
					continue;
				NSMutableArray *list = [missing objectForKey:language];
				if(list == nil) {
					list = [NSMutableArray array];
					[missing setObject:list forKey:language];
				}
				[list addObject:key];
			}
		}
	}

	l = [languages objectEnumerator];
	while((language = [l nextObject]) != nil) {
		NSArray *lost = [missing objectForKey:language] ?: [NSArray array];
		if([lost count] > 0) {
			NSUInteger show = MIN((NSUInteger)4, [lost count]);
			NSUInteger i;
			for(i = 0; i < show; i++)
				printf("  %s misses: %s\n", [language UTF8String],
					[[lost objectAtIndex:i] UTF8String]);
			if([lost count] > show)
				printf("  …and %lu more in %s\n",
					(unsigned long)([lost count] - show), [language UTF8String]);
		}
		ok([lost count] == 0,
			[NSString stringWithFormat:@"%@ has all of them", language],
			[NSString stringWithFormat:@"%lu missing of %lu",
				(unsigned long)[lost count], (unsigned long)total]);
	}

	int result = NekoTestResult();
	[pool release];
	return result;
}
