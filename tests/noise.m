/* Timing that drifts rather than scattering.

   Three numbers decide whether the generator is doing what the literature asks
   for: the slope of its power spectrum (flat means white, −1 means pink), how
   much a value tells you about the next one, and whether the spread survived the
   change — a stream that is beautifully pink and always says 0.5 is a metronome
   again.

   The spectrum is computed here rather than trusted: a periodogram at log-spaced
   frequencies and a least-squares line through it. */

#import <Cocoa/Cocoa.h>
#import "support.h"
#import "NekoNoise.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "MyPanel.h"
#import <math.h>

#define SAMPLES 4096

static double slopeOf(double *values, int count)
{
	/* Mean removed, or the zero frequency dominates everything. */
	double mean = 0.0;
	int i;
	for(i = 0; i < count; i++)
		mean += values[i];
	mean /= (double)count;

	/* Power at log-spaced frequencies, by direct summation. */
	double logF[40], logP[40];
	int bins = 0, b;
	for(b = 0; b < 40; b++) {
		int k = (int)round(pow(2.0, 1.0 + (double)b * 0.25));   /* 2 … ~1000 */
		if(k < 2 || k > count / 4)
			continue;
		double re = 0.0, im = 0.0;
		for(i = 0; i < count; i++) {
			double angle = 2.0 * M_PI * (double)k * (double)i / (double)count;
			re += (values[i] - mean) * cos(angle);
			im += (values[i] - mean) * sin(angle);
		}
		double power = (re * re + im * im) / (double)count;
		if(power <= 0.0)
			continue;
		logF[bins] = log((double)k);
		logP[bins] = log(power);
		bins++;
	}

	/* Least squares. */
	double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
	for(i = 0; i < bins; i++) {
		sx += logF[i]; sy += logP[i];
		sxx += logF[i] * logF[i]; sxy += logF[i] * logP[i];
	}
	double n = (double)bins;
	return (n * sxy - sx * sy) / (n * sxx - sx * sx);
}

static double spreadOf(double *values, int count)
{
	double mean = 0.0, sum = 0.0;
	int i;
	for(i = 0; i < count; i++)
		mean += values[i];
	mean /= (double)count;
	for(i = 0; i < count; i++)
		sum += (values[i] - mean) * (values[i] - mean);
	return sqrt(sum / (double)count);
}

static double memoryOf(double *values, int count)
{
	double mean = 0.0, top = 0.0, bottom = 0.0;
	int i;
	for(i = 0; i < count; i++)
		mean += values[i];
	mean /= (double)count;
	for(i = 0; i < count - 1; i++)
		top += (values[i] - mean) * (values[i + 1] - mean);
	for(i = 0; i < count; i++)
		bottom += (values[i] - mean) * (values[i] - mean);
	return bottom > 0.0 ? top / bottom : 0.0;
}

int main(void)
{
	[NSApplication sharedApplication];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	static double pink[SAMPLES], flat[SAMPLES];
	NekoNoise *noise = [[[NekoNoise alloc] initWithSeed:20260826UL] autorelease];
	int i;
	for(i = 0; i < SAMPLES; i++) {
		pink[i] = [noise next];
		flat[i] = (double)arc4random_uniform(1000000) / 1000000.0;
	}

	printf("\n--- the shape of the two streams ---\n");
	double pinkSlope = slopeOf(pink, SAMPLES), flatSlope = slopeOf(flat, SAMPLES);
	printf("      slope   pink %.2f   flat %.2f      (0 is white, -1 is pink)\n",
		pinkSlope, flatSlope);
	printf("      spread  pink %.3f  flat %.3f     (0.289 is a flat draw)\n",
		spreadOf(pink, SAMPLES), spreadOf(flat, SAMPLES));
	printf("      memory  pink %.2f   flat %.2f      (one value about the next)\n",
		memoryOf(pink, SAMPLES), memoryOf(flat, SAMPLES));

	ok(pinkSlope < -0.6 && pinkSlope > -1.4,
		@"the spectrum is pink, not white",
		[NSString stringWithFormat:@"%.2f", pinkSlope]);
	ok(flatSlope > -0.25 && flatSlope < 0.25,
		@"and the draw it replaces was white, as expected",
		[NSString stringWithFormat:@"%.2f", flatSlope]);
	ok(memoryOf(pink, SAMPLES) > 0.5,
		@"a pause tells you something about the next one",
		[NSString stringWithFormat:@"%.2f", memoryOf(pink, SAMPLES)]);
	ok(fabs(memoryOf(flat, SAMPLES)) < 0.1,
		@"where a flat draw told you nothing",
		[NSString stringWithFormat:@"%.2f", memoryOf(flat, SAMPLES)]);
	ok(spreadOf(pink, SAMPLES) > 0.26 * 0.9,
		@"and the variety survived the change",
		[NSString stringWithFormat:@"%.3f against a flat draw's %.3f",
			spreadOf(pink, SAMPLES), spreadOf(flat, SAMPLES)]);

	printf("\n--- bounds, so nothing waits for ever ---\n");
	double low = 1.0, high = 0.0;
	for(i = 0; i < SAMPLES; i++) {
		if(pink[i] < low) low = pink[i];
		if(pink[i] > high) high = pink[i];
	}
	ok(low >= 0.0 && high < 1.0, @"every value is inside its range",
		[NSString stringWithFormat:@"%.3f … %.3f", low, high]);

	double scaleLow = 9.0, scaleHigh = 0.0, scaleMean = 0.0;
	for(i = 0; i < 4096; i++) {
		double s = [noise nextScale];
		scaleMean += s;
		if(s < scaleLow) scaleLow = s;
		if(s > scaleHigh) scaleHigh = s;
	}
	scaleMean /= 4096.0;
	ok(scaleLow >= 0.6 && scaleHigh <= 1.4 && fabs(scaleMean - 1.0) < 0.05,
		@"a duration is scaled between 0.6 and 1.4, averaging one",
		[NSString stringWithFormat:@"%.2f … %.2f, mean %.3f",
			scaleLow, scaleHigh, scaleMean]);

	printf("\n--- and the same afternoon twice ---\n");
	NekoNoise *one = [[[NekoNoise alloc] initWithSeed:7UL] autorelease];
	NekoNoise *two = [[[NekoNoise alloc] initWithSeed:7UL] autorelease];
	BOOL same = YES;
	for(i = 0; i < 500; i++)
		if([one next] != [two next])
			same = NO;
	ok(same, @"the same seed replays it, which is what makes this testable", nil);

	printf("\n--- and what the cat does with it ---\n");

	/* The idle chain used to hold each pose for a fixed count — four, ten, four,
	   six. Read the dwell it draws now, straight out of the panel. */
	MyPanel *panel = [[MyPanel alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, 32.0f, 32.0f)
	                                           styleMask:NSWindowStyleMaskBorderless
	                                             backing:NSBackingStoreBuffered
	                                               defer:NO];
	Ivar found = class_getInstanceVariable([MyPanel class], "idleDwell");
	ok(found != NULL, @"the dwell is where the test expects it", nil);

	struct { NekoState state; const char *name; unsigned base; } chain[] = {
		{ NekoStateStop,  "sitting",  4 },
		{ NekoStateJare,  "playing",  10 },
		{ NekoStateKaki,  "scratching", 4 },
		{ NekoStateAkubi, "yawning",  6 },
		{ NekoStateLTogi, "at a wall", 10 },
	};
	int c;
	for(c = 0; c < 5; c++) {
		unsigned seen[64];
		memset(seen, 0, sizeof(seen));
		unsigned low = 9999, high = 0, distinct = 0;
		double mean = 0.0;
		int round;
		for(round = 0; round < 400; round++) {
			/* setStateTo: ignores a repeat, so alternate with something else. */
			((void (*)(id, SEL, NekoState))objc_msgSend)(panel, @selector(setStateTo:),
				NekoStateAwake);
			((void (*)(id, SEL, NekoState))objc_msgSend)(panel, @selector(setStateTo:),
				chain[c].state);
			unsigned dwell = *(unsigned *)((char *)panel + ivar_getOffset(found));
			mean += (double)dwell;
			if(dwell < low) low = dwell;
			if(dwell > high) high = dwell;
			if(dwell < 64 && seen[dwell] == 0) { seen[dwell] = 1; distinct++; }
		}
		mean /= 400.0;
		printf("      %-11s base %2u   %u…%u ticks, mean %.2f, %u different\n",
			chain[c].name, chain[c].base, low, high, mean, distinct);
		ok(low >= 1 && high <= (unsigned)((double)chain[c].base * 1.4 + 0.5)
		   && fabs(mean - (double)chain[c].base) < 0.6 && distinct >= 3,
			[NSString stringWithFormat:@"%s varies around its old fixed count",
				chain[c].name], nil);
	}
	[panel release];

	int result = NekoTestResult();
	[pool release];
	return result;
}
