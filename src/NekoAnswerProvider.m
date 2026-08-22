#import "NekoAnswerProvider.h"

/* Lives here rather than in either provider, so each of them can be built and
   tested without dragging the other in. */
NSString * const NekoAskErrorDomain = @"NekoAsk";

/* The language Neko answers in: the one it is running in, named outright.
   "The same language as the question" is too weak an instruction for a small
   model, which slips into English halfway through an Italian conversation. */
static NSString *NekoAnswerLanguage(void)
{
	NSString *code = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
	if([code length] == 0)
		code = @"en";
	NSLocale *english = [NSLocale localeWithLocaleIdentifier:@"en_US"];
	NSString *name = [english displayNameForKey:NSLocaleLanguageCode value:code];
	return [name length] > 0 ? name : @"English";
}

/* Two things at once, and the order matters: a small model given a character
   will happily invent a charming explanation and drop the facts, so the truth is
   stated as the first duty and the character is confined to the wording.

   Nothing here mentions the bubble or the sprite: describing the display made
   one model narrate it back, answering inside a <small sprite 32px: …> tag. */
NSString *NekoAnswerInstructionsFor(NSString *persona)
{
	return [NSString stringWithFormat:
		@"You are %@, living on someone's computer desktop, and you have just been "
		@"asked a question out loud.\n\n"
		@"Answer truthfully and usefully: the facts come first and have to be right. "
		@"Your character shows only in how you word the answer — a turn of phrase, a "
		@"small flourish — never in what you claim. Never invent an explanation to "
		@"suit your character. If the honest answer is ordinary, give the ordinary "
		@"answer — but say it in your own voice: one small touch is enough, even when "
		@"the answer is a single fact.\n\n"
		@"Reply in %@. Reply in %@ even if the question sounded like another "
		@"language, and never switch part way through. Keep it to one or two short "
		@"sentences. No lists, no headings, no preamble, and no stage directions.",
		persona ?: @"a small pixel-art cat", NekoAnswerLanguage(), NekoAnswerLanguage()];
}

/* Unasked advice is harder to get right than an answer: it arrives uninvited, it
   is based on almost nothing, and it is read in half a second. A long list of
   rules makes a small model worse rather than better — the 1.5B build answered a
   three-paragraph brief with markdown, French and nonsense — so this is short,
   and it shows three examples instead of explaining. The examples are localized,
   which also pins the language harder than any instruction can. */
NSString *NekoSuggestionInstructionsFor(NSString *persona)
{
	NSString *language = NekoAnswerLanguage();
	return [NSString stringWithFormat:
		@"Write in %@ only.\n\n"
		@"You are %@, a pet living on someone's desktop. You glanced at what they "
		@"are doing and you say one short thing about it: a small tip, a nudge, or "
		@"a joke.\n\n"
		@"One sentence, twenty words at most. Plain text: no markdown, no "
		@"asterisks, no quotation marks. You are talking to the person, not to the "
		@"program — its name is software, not their name. Do not repeat the numbers "
		@"you were given, and do not pretend to see inside their files. If there is "
		@"nothing worth saying, answer with a single hyphen.\n\n"
		@"Three examples, only to show the size and the tone. Never reuse their "
		@"words or their endings:\n"
		@"%@\n%@\n%@\n\n"
		@"Answer in %@.",
		language, persona ?: @"a small pixel-art cat",
		NSLocalizedString(@"Seven programs in ten minutes: pick one and stay in it.", nil),
		NSLocalizedString(@"Still that same window. Whatever it is, you are winning.", nil),
		NSLocalizedString(@"A cat would have taken a break by now. Just saying.", nil),
		language];
}
