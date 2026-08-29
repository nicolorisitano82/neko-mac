/* NekoRecall */

#import <Cocoa/Cocoa.h>

/* Finding the lines of a diary that bear on a question.

   The diary is a month of short lines and the prompt has room for about three of
   them, so the whole problem is which three. Until now the answer was "the newest
   three", which is right for a follow-up and wrong for everything else: something
   decided three weeks ago was written down and then never found again.

   **Why this is words and not a model.** The plan said to embed every line with
   `NLEmbedding`, which is on the machine and needs no permission. Measured on a
   staged Italian diary of twenty lines and ten questions, before any of it was
   built:

   | | top-1 | top-3 | a month costs | on disk |
   | --- | --- | --- | --- | --- |
   | NLEmbedding, cosine | 5/10 | 5/10 | 5.5 s | 3.7 MB |
   | bare shared words | 8/10 | — | — | — |
   | lemmas + word class + rarity | 8/10 | 8/10 | 267 ms | nothing |
   | the two fused by rank | 6/10 | 9/10 | 5.5 s | 3.7 MB |

   The embedding lost to counting words, and fusing the two bought **one question
   in ten** on top-3 — which is inside the noise of a ten-question sample — for
   twenty times the time and 3.7 MB of vectors sitting beside a file whose whole
   promise is that it is plain text somebody can read. So: no embedding. If recall
   turns out to be weak in use, that table is where to start arguing with this
   decision, and the fusion is four lines of code.

   Three things do the work, all of them from NLTagger, all of them in the four
   languages this application speaks:

   1. **Lemmas.** "Ascolto" and "ha ascoltato" are the same word asked twice.
   2. **Word class.** A question is about its nouns; the verbs it is asked with —
      usare, fare, avere — are how a language carries a question. Nouns count 1.0,
      adjectives 0.8, verbs and adverbs 0.35, and the rest not at all.
   3. **Rarity.** A word that is in every line of the diary says nothing about
      which line. Plain inverse document frequency, the cheap half of BM25.

   And one rule decides whether a line is about the question at all: **it has to
   share a word of substance** — a noun, a name, a number, an adjective. Measured:
   of eight questions about things not in the diary, six came back with a line, and
   five of those six shared exactly one word, which was `fare`, `essere` or `come`.
   A verb is how a question is carried, not what it is about.

   What it cannot do is synonyms: asked about *"impostazioni"* it does not find
   *"preferenze"*. That is measured, it is in `tests/recall.m` as a known miss
   rather than hidden, and it is the one thing an embedding was better at — fifth
   of twenty, which would still not have reached the prompt. */
@interface NekoRecall : NSObject

/* The words of a line, lemmatised and folded, with the short ones dropped. */
+ (NSArray *)wordsOf:(NSString *)text;

/* The words of a question, each with what its word class is worth. */
+ (NSDictionary *)askedIn:(NSString *)question;

/* How rare each word is across a body of lines. Pass it back to -linesIn:… so a
   month is only measured once. */
+ (NSDictionary *)rarityAcross:(NSArray *)lines;

/* The words of every line, in order, as sets. Lemmatising a month costs a quarter
   of a second; doing it again on every question would cost a quarter of a second
   somebody waits for nothing, so it is done once and handed back in. */
+ (NSArray *)wordSetsFor:(NSArray *)lines;

/* The lines that bear on the question, best first, and never more than `limit`.
   Empty when nothing bears on it: a question about the weather may not drag
   somebody's month into the prompt behind it. */
+ (NSArray *)linesIn:(NSArray *)lines
               about:(NSString *)question
               limit:(NSUInteger)limit
              rarity:(NSDictionary *)rarity;

/* The same, with the lines' words already worked out. */
+ (NSArray *)linesIn:(NSArray *)lines
               words:(NSArray *)sets
               about:(NSString *)question
               limit:(NSUInteger)limit
              rarity:(NSDictionary *)rarity;

/* What a line scored, exposed so a test can say why rather than only whether. */
+ (double)scoreOf:(NSString *)line asked:(NSDictionary *)asked
           rarity:(NSDictionary *)rarity;
+ (double)scoreOfWords:(NSSet *)words asked:(NSDictionary *)asked
                rarity:(NSDictionary *)rarity;

@end
