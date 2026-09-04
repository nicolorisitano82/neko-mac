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

	/* The named day is computed rather than written down. It used to say "il 3
	   settembre", which was next week when this was written and yesterday by the
	   time somebody ran it again — the check went red for the calendar rather
	   than for the code. A date three weeks out is always ahead. */
	NSDateFormatter *saidAs = [[[NSDateFormatter alloc] init] autorelease];
	[saidAs setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"it_IT"] autorelease]];
	[saidAs setDateFormat:@"d MMMM"];
	NSString *threeWeeksOn = [saidAs stringFromDate:
		[NSDate dateWithTimeIntervalSinceNow:21.0 * 24.0 * 3600.0]];

	NSArray *asked = [NSArray arrayWithObjects:
		@"metti in calendario la riunione con Marco venerdì alle 9:30",
		[NSString stringWithFormat:
			@"segna un appuntamento dal dentista il %@ a mezzogiorno", threeWeeksOn],
		@"appuntamento domani alle 15",
		@"add to my calendar the standup tomorrow at 9am",
		@"schedule lunch with Ana tomorrow at 1pm",
		@"rendez-vous chez le dentiste demain à 15h",
		@"añade al calendario la reunión mañana a las 10", nil];
	NSUInteger i, understood = 0, total = [asked count];
	NSMutableString *missed = [NSMutableString string];
	for(i = 0; i < total; i++) {
		NSString *said = [asked objectAtIndex:i];
		NSDictionary *got = [NekoAppointment wantedFor:said];
		if(got != nil && [got objectForKey:@"When"] != nil
		   && [[got objectForKey:@"Title"] length] > 0) {
			understood++;
			printf("      %-58s %s — “%s”\n", [said UTF8String], [whenOf(got) UTF8String],
				[[got objectForKey:@"Title"] UTF8String]);
		}
		else
			[missed appendFormat:@"%@; ", said];
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
	/* An hour earlier on the same day — which does not exist between midnight and
	   one, where "an hour ago" is yesterday and any bare time today is still to
	   come. The first version of this wrapped with %24 and failed at 00:30, which
	   is a fault in the test and not in the rule it is testing. */
	NSInteger anHourAgo = [now hour] - 1;
	NSString *past = [NSString stringWithFormat:
		@"appuntamento alle %ld:00", (long)anHourAgo];
	NSDictionary *moved = anHourAgo >= 0 ? [NekoAppointment wantedFor:past] : nil;
	if(anHourAgo < 0) {
		notMeasured(@"it is the midnight hour, when no bare time today has gone by "
			@"yet, so there is nothing here to move to tomorrow");
	} else if(moved == nil || [moved objectForKey:@"When"] == nil) {
		notMeasured([NSString stringWithFormat:
			@"“%@” was not read as a time at this hour", past]);
	} else {
		ok([[moved objectForKey:@"When"] timeIntervalSinceNow] > 0.0,
			@"a time that has gone by today lands in the future, not this morning",
			[NSString stringWithFormat:@"%@ (asked at %02ld:%02ld)", whenOf(moved),
				(long)[now hour], (long)[now minute]]);
		/* Whether it *had* to move it is the detector's business, not the rule's:
		   Italian "alle 11" is ambiguous and NSDataDetector reads it as 23:00,
		   which is already in the future and needs no moving. So the flag is
		   reported rather than demanded — the assertion that matters is the one
		   above, that an appointment never lands in the past. */
		printf("      the detector read it as %s; moved to tomorrow: %s\n",
			[whenOf(moved) UTF8String],
			[[moved objectForKey:@"MovedToTomorrow"] boolValue] ? "yes" : "no");
	}

	/* And the half that ambiguity cannot reach: seven in the morning, named with
	   the day so the detector cannot read it as tonight. It has gone by, and the
	   answer must still be in the future. */
	NSDictionary *thisMorning = [NekoAppointment wantedFor:
		@"appuntamento oggi alle 7:00"];
	if(thisMorning == nil || [thisMorning objectForKey:@"When"] == nil)
		notMeasured(@"“oggi alle 7:00” was not read as a time");
	else if([now hour] < 8)
		notMeasured(@"it is before eight, so seven o'clock has not gone by yet");
	else {
		ok([[thisMorning objectForKey:@"When"] timeIntervalSinceNow] > 0.0,
			@"seven this morning, said later in the day, is not this morning",
			whenOf(thisMorning));
		printf("      moved to tomorrow: %s\n",
			[[thisMorning objectForKey:@"MovedToTomorrow"] boolValue] ? "yes" : "no");
	}

	/* What both of those found, which is worth writing down rather than asserting:
	   NSDataDetector mostly avoids the past by itself. "Alle 11" at midday comes
	   back as 23:00 and "oggi alle 7:00" as tomorrow at 19:00 — it reads a bare
	   hour as the afternoon and rolls the day forward. The rule in
	   NekoAppointment is the backstop for the phrasings where it does not, of
	   which "svegliami alle 7" measured at five in the afternoon was one. So the
	   assertion here is the invariant that holds either way — an appointment never
	   lands in the past — and whether the backstop was needed is printed. */

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
