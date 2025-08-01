/* sound_stripper.c
 * by Richard Cavell
 * June 2025 - July 2025
 * This sets the lower 2 bits of the 8-bit raw audio bytes to zero
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void
print_help(const char *argv0)
{
	(void) printf("%s",
		"Sound Stripper v1.0\n"
		"by Richard Cavell\n"
		"https://github.com/richardcavell/sound_stripper\n");

	(void) printf("%s%s%s",
	        "Usage: ",
		 argv0,
		" inputfile outputfile\n");
}

int
main(int argc, char *argv[])
{
	FILE *input_fp  = NULL;
	FILE *output_fp = NULL;
	int c = EOF;

	if ((argc > 1) &&
               (strcmp(argv[1], "--help") == 0    ||
            	strcmp(argv[1], "-help") == 0     ||
            	strcmp(argv[1], "-h") == 0        ||
            	strcmp(argv[1], "-?") == 0        ||
            	strcmp(argv[1], "--info") == 0    ||
            	strcmp(argv[1], "-i") == 0        ||
            	strcmp(argv[1], "--usage") == 0   ||
            	strcmp(argv[1], "--version") == 0 ||
		strcmp(argv[1], "-v") == 0        ||
		strcmp(argv[1], "-V") == 0))
	{
		print_help(argv[0]);
		exit(EXIT_SUCCESS);
	}

	if (argc != 3)
	{
		print_help(argv[0]);
		exit(EXIT_FAILURE);
	}

	input_fp  = fopen(argv[1], "r");

	if (input_fp == NULL)
	{
		(void) fprintf(stderr, "%s%s%s%i%c",
				 "Couldn't open input file ",
				  argv[1],
				 ". Error number: ",
				  errno,
				  '\n');
		exit(EXIT_FAILURE);
	}

	output_fp = fopen(argv[2], "w");

	if (output_fp == NULL)
	{
		(void) fprintf(stderr, "%s%s%s%i%c",
				"Couldn't open output file ",
				 argv[2],
				". Error number: ",
				 errno,
				'\n');
		exit(EXIT_FAILURE);
	}

	while ((c = fgetc(input_fp)) != EOF)
	{
		c &= 0xfc;	/* the lowest 2 bits = 0 */

		c >>= 2;	/* appear in the lowest 6 bits */

		if (fputc(c, output_fp) == EOF)
		{
			(void) fprintf(stderr, "%s%s%s%i%c",
                                        "Couldn't write to output file ",
					argv[2],
					". Error code: ",
					errno,
					'\n');
			exit(EXIT_FAILURE);
		}
	}

	if (fclose(input_fp) == EOF)
	{
		(void) fprintf(stderr, "%s%s%s%i%c",
					"Couldn't close input file ",
					argv[1],
					". Error code: ",
					 errno,
					'\n');

		exit(EXIT_FAILURE);
	}

	if (fclose(output_fp) == EOF)
	{
		(void) fprintf(stderr,
			       "%s%s%s%i%c",
			       "Couldn't close output file ",
				argv[2],
			       ". Error code: ",
				errno,
			       '\n');

		exit(EXIT_FAILURE);
	}

	return EXIT_SUCCESS;
}
