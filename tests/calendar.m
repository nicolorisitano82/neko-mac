/* Something for the calendar.

   The route with no permission, which docs/utilities.md ranked first and nobody
   built: an .ics written in this application's own container and handed to
   whatever opens those. Calendar shows the whole event with its own Add button,
   so the last word belongs to somebody looking at it in the application it goes
   into. One click more than EventKit, and the click is in the right place.

   Two things were measured before a line of it was written. A sandboxed
   application can write the file in its container, and CalendarFileHandler.app is
   what would open it. And NSDataDetector parses the date out of an ordinary
   sentence in all four languages, handing back the range of the words it used —
   which is how the rest of the sentence becomes the title.

   What this harness is mostly about is the third measurement: "svegliami alle 7",
   said in the afternoon, comes back from the detector as **seven this morning**.
   That is the likeliest way this feature says something wrong, and there is a
   rule for it. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoAppointment.h"

static NSString *whenOf(NSDictionary *a)
{
	NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
	[f setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
	[f setDateFormat:@"yyyy-MM-dd HH:mm"];
	return [f stringFromDate:[a objectForKey:@"When"]];
}

int main(void)
{
	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	printf("\n--- what it takes for a calendar ---\n");

	const char *asked[] = {
		"metti in calendario la riunione con Marco venerdì alle 9:30",
		"segna un appuntamento dal dentista il 3 settembre a mezzogiorno",
		"appuntamento domani alle 15",
		"add to my calendar the standup tomorrow at 9am",
		"schedule lunch with Ana tomorrow at 1pm",
		"rendez-vous chez le dentiste demain à 15h",
		"añade al calendario la reunión mañana a las 10",
	};
	NSUInteger i, understood = 0, total = sizeof(asked) / sizeof(asked[0]);
	NSMutableString *missed = [NSMutableString string];
	for(i = 0; i < total; i++) {
		NSString *said = [NSString stringWithUTF8String:asked[i]];
		NSDictionary *got = [NekoAppointment wantedFor:said];
		if(got != nil && [got objectForKey:@"When"] != nil
		   && [[got objectForKey:@"Title"] length] > 0) {
			understood++;
			printf("      %-58s %s — “%s”\n", asked[i], [whenOf(got) UTF8String],
				[[got objectForKey:@"Title"] UTF8String]);
		}
		else
			[missed appendFormat:@"%s; ", asked[i]];
	}
	ok(understood == total, [NSString stringWithFormat:
		@"all %lu are understood, with a day and a title",
		(unsigned long)total], missed);

	/* And the title is what somebody would have written down, with the asking
	   taken out of it — the whole phrase, not the tail of it. */
	NSDictionary *spanish = [NekoAppointment wantedFor:
		@"añade al calendario la reunión mañana a las 10"];
	ok([[spanish objectForKey:@"Title"] isEqualToString:@"reunión"],
		@"and the phrase that asked is gone from the title, all of it",
		[spanish objectForKey:@"Title"]);

	printf("\n--- and what it refuses to put anywhere ---\n");

	/* The failure that matters is not a missed appointment; it is one nobody
	   asked for. Three of these carry a perfectly good date. */
	const char *notAsked[] = {
		"la riunione è durata due ore",
		"ci siamo visti venerdì alle 9:30",
		"domani alle 15 ho detto a Marco che sarei stato libero",
		"che ore sono?",
		"metti un timer di 10 minuti",
		"ricordati che il venerdì stacco prima",
		"notizie su Bologna",
		"quanto fa sette per otto",
		"metti in calendario",              /* asked, but said no day */
	};
	NSUInteger quiet = 0, ordinary = sizeof(notAsked) / sizeof(notAsked[0]);
	NSMutableString *misfired = [NSMutableString string];
	for(i = 0; i < ordinary; i++) {
		NSDictionary *got = [NekoAppointment wantedFor:
			[NSString stringWithUTF8String:notAsked[i]]];
		if(got == nil)
			quiet++;
		else
			[misfired appendFormat:@"%s → %@; ", notAsked[i], whenOf(got)];
	}
	ok(quiet == ordinary, [NSString stringWithFormat:
		@"none of %lu ordinary sentences becomes an appointment",
		(unsigned long)ordinary], misfired);

	printf("\n--- the rule that keeps it honest ---\n");

	/* A bare time that has gone by today means tomorrow. Built from the clock so
	   the harness says the same thing at nine in the morning and at midnight. */
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *now = [calendar components:
		NSCalendarUnitHour | NSCalendarUnitMinute fromDate:[NSDate date]];
	NSInteger anHourAgo = ([now hour] + 23) % 24;
	NSString *past = [NSString stringWithFormat:
		@"appuntamento alle %ld:00", (long)anHourAgo];
	NSDictionary *moved = [NekoAppointment wantedFor:past];
	if(moved == nil || [moved objectForKey:@"When"] == nil) {
		notMeasured([NSString stringWithFormat:
			@"“%@” was not read as a time at this hour", past]);
	} else {
		ok([[moved objectForKey:@"When"] timeIntervalSinceNow] > 0.0,
			@"a time that has gone by today lands in the future, not this morning",
			[NSString stringWithFormat:@"%@ (asked at %02ld:%02ld)", whenOf(moved),
				(long)[now hour], (long)[now minute]]);
		ok([[moved objectForKey:@"MovedToTomorrow"] boolValue],
			@"and it says that is what it did", nil);
	}

	printf("\n--- and the file it writes ---\n");

	NSDictionary *one = [NekoAppointment wantedFor:
		@"metti in calendario la riunione con Marco domani alle 15"];
	NSString *ics = [NekoAppointment calendarFileFor:one];
	ok([ics hasPrefix:@"BEGIN:VCALENDAR"] && [ics hasSuffix:@"END:VCALENDAR\r\n"],
		@"is a calendar file", [[ics componentsSeparatedByString:@"\r\n"] firstObject]);
	ok([ics rangeOfString:@"DTSTART:"].location != NSNotFound
	   && [ics rangeOfString:@"DTEND:"].location != NSNotFound,
		@"with a beginning and an end", nil);
	ok([ics rangeOfString:@"SUMMARY:riunione con Marco"].location != NSNotFound,
		@"and the title it worked out from the rest of the sentence",
		[one objectForKey:@"Title"]);
	ok([[ics componentsSeparatedByString:@"\r\n"] count] > 8,
		@"with its lines ended the way that format wants", nil);

	/* A title carrying the characters that would end a line or a field in an
	   .ics is a title that could invent a second event. */
	NSDictionary *nasty = [NekoAppointment wantedFor:
		@"appuntamento domani alle 15 con Marco\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nSUMMARY:altro"];
	NSString *dirty = [NekoAppointment calendarFileFor:nasty];
	NSUInteger events = 0;
	NSEnumerator *lines = [[dirty componentsSeparatedByString:@"\r\n"] objectEnumerator];
	NSString *line;
	while((line = [lines nextObject]) != nil)
		if([line isEqualToString:@"BEGIN:VEVENT"])
			events++;
	ok(events == 1, @"and a title full of calendar syntax still makes one event",
		[NSString stringWithFormat:@"%lu events", (unsigned long)events]);

	printf("\n--- what this cannot settle ---\n");
	notMeasured(@"that Calendar shows what somebody meant. The file is handed over "
		@"and the Add button is theirs; whether the event is the right one is a "
		@"person's judgement, which is exactly why it is read back first");

	int result = NekoTestResult();
	[pool release];
	return result;
}
