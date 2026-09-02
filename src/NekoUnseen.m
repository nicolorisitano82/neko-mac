#import "NekoUnseen.h"
#import "NekoFolderAccess.h"

#define NekoUnseenLocalized(key) NSLocalizedStringFromTable(key, @"Localizable", nil)

/* Each class of question, the phrases that ask it, and the one sentence that
   answers it. The phrases came from the questions stage 3 measured rather than
   from imagination, which is why there are seven groups and not twenty.

   Whole phrases, not single words: "conto" is in "tienine conto" and "il conto
   del ristorante", and neither is a question about somebody's bank. */
static NSArray *NekoUnseenClasses(void)
{
	static NSArray *classes = nil;
	if(classes != nil)
		return classes;

	classes = [[NSArray alloc] initWithObjects:
		/* Their own money. */
		[NSArray arrayWithObjects:@"accounts",
			@"I cannot see your accounts.",
			@"quanto ho sul conto", @"quanto c'è sul conto", @"il mio saldo",
			@"il saldo del conto", @"quanto ho speso", @"quanto mi resta sul conto",
			@"il mio stipendio", @"la mia bolletta", @"la mia carta di credito",
			@"quanti soldi ho", @"my bank balance", @"how much money do i have",
			@"how much have i spent", @"mon solde", @"mi saldo",
			@"cuánto dinero tengo", nil],

		/* The markets, which are not on this Mac either. */
		[NSArray arrayWithObjects:@"markets",
			@"I cannot see the markets.",
			@"quanto vale in borsa", @"vale in borsa", @"quotazione di",
			@"quanto vale apple", @"il prezzo delle azioni", @"quanto è salito il titolo",
			@"quanto vale il bitcoin", @"il cambio euro dollaro",
			@"stock price", @"share price", @"how much is apple worth",
			@"cours de l'action", @"precio de las acciones", nil],

		/* Mail, messages, calls. */
		[NSArray arrayWithObjects:@"mail",
			@"I cannot see your mail.",
			@"chi mi ha scritto", @"chi mi ha cercato", @"messaggi non letti",
			@"mail non lette", @"email non lette", @"quante mail ho",
			@"la mia posta", @"le mie notifiche", @"chiamate perse",
			@"chi mi ha chiamato", @"ho ricevuto messaggi",
			@"who wrote to me", @"unread messages", @"unread mail", @"my inbox",
			@"missed calls", @"ma boîte", @"mes messages non lus",
			@"mi correo", @"mensajes sin leer", nil],

		/* What is inside a file — unless a folder was handed over. */
		[NSArray arrayWithObjects:@"files",
			@"I cannot see inside your files.",
			@"cosa c'è nel file", @"cosa c'è scritto nel file",
			@"cosa c'è nel documento", @"cosa contiene il file",
			@"dove ho salvato", @"quanto pesa il file", @"cosa ho scritto nel file",
			@"what's in the file", @"what is in the file", @"where did i save",
			@"qu'y a-t-il dans le fichier", @"qué hay en el archivo", nil],

		/* Whether the work works. */
		[NSArray arrayWithObjects:@"build",
			@"I cannot see whether it builds.",
			@"il mio codice compila", @"il codice compila", @"la build è finita",
			@"la build è passata", @"il test passa", @"i test passano",
			@"ci sono errori di compilazione", @"la compilazione è finita",
			@"does my code compile", @"did the build pass", @"do the tests pass",
			@"est-ce que ça compile", @"compila mi código", nil],

		/* Other people. */
		[NSArray arrayWithObjects:@"people",
			@"I cannot see who is there.",
			@"chi è al telefono", @"chi ha suonato", @"chi c'è alla porta",
			@"come si chiama il mio collega", @"come si chiama mia",
			@"chi è quella persona", @"chi c'è in riunione",
			@"who is on the phone", @"who is at the door",
			@"what's my colleague called", @"qui est au téléphone",
			@"quién está al teléfono", nil],

		/* The weather, which is the world rather than the Mac — and which the
		   news path takes first when somebody has a feed for it. */
		[NSArray arrayWithObjects:@"weather",
			@"I cannot see the weather.",
			@"che tempo fa a", @"che tempo farà", @"che tempo fa fuori",
			@"piove a", @"pioverà", @"che temperatura c'è a", @"quanti gradi ci sono a",
			@"what's the weather", @"what is the weather", @"will it rain",
			@"quel temps fait-il", @"qué tiempo hace", nil],

		/* And what is in a calendar this application can write to and not read. */
		[NSArray arrayWithObjects:@"calendar",
			@"I cannot see your calendar.",
			@"cosa ho in calendario", @"che impegni ho", @"ho appuntamenti",
			@"che appuntamenti ho", @"cosa ho domani in calendario",
			@"quando ho la riunione", @"a che ora ho l'appuntamento",
			@"what's on my calendar", @"what do i have tomorrow",
			@"mon agenda", @"mi agenda", nil],

		/* And the person's own body and night. */
		[NSArray arrayWithObjects:@"body",
			@"I cannot know that about you.",
			@"cosa ho sognato", @"quanto ho dormito", @"come ho dormito",
			@"quanti passi ho fatto", @"quanto ho camminato", @"il mio battito",
			@"quanto peso", @"la mia pressione",
			@"what did i dream", @"how did i sleep", @"how many steps",
			@"qu'ai-je rêvé", @"qué soñé", @"cuánto dormí", nil],
		nil];
	return classes;
}

@implementation NekoUnseen

+ (NSString *)wantedFor:(NSString *)question
{
	NSString *text = [question lowercaseString];
	NSEnumerator *groups = [NekoUnseenClasses() objectEnumerator];
	NSArray *group;
	while((group = [groups nextObject]) != nil) {
		NSString *kind = [group objectAtIndex:0];

		/* A folder somebody handed over in a panel is a folder this application
		   can read. It does not get to say it cannot see inside files while it
		   has a bookmark to one. */
		if([kind isEqualToString:@"files"]
		   && [[[NekoFolderAccess sharedAccess] allowedKeys] count] > 0)
			continue;

		NSUInteger i;
		for(i = 2; i < [group count]; i++)
			if([text rangeOfString:[group objectAtIndex:i]].location != NSNotFound)
				return NekoUnseenLocalized([group objectAtIndex:1]);
	}
	return nil;
}

@end
