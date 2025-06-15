/* sound_stripper.c
 * by Richard Cavell
 * June 2025
 * This strips the lower 2 bits off the 8-bit raw audio bytes
 * Version 1.0
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
	FILE *input_fp  = NULL;
	FILE *output_fp = NULL;
	int c = EOF;

	if (argc != 3)
	{
		fprintf(stderr, "%s%s%s", "Usage: ", argv[0],
			" inputfile outputfile\n");
		exit(EXIT_FAILURE);
	}

	input_fp  = fopen(argv[1], "r");

	if (input_fp == NULL)
	{
		fprintf(stderr, "%s%s%s%i%c", "Couldn't open input file ",
					   argv[1],
					   ". Error number: ",
					   errno,
					   '\n');
		exit(EXIT_FAILURE);
	}

	output_fp = fopen(argv[2], "w");

	if (output_fp == NULL)
	{
		fprintf(stderr, "%s%s%s%i%c", "Couldn't open output file ",
					   argv[2],
					   ". Error number: ",
					   errno,
					   '\n');
		exit(EXIT_FAILURE);
	}

	while ((c = fgetc(input_fp)) != EOF)
	{
		c &= 0xfc;	/* the lowest 2 bits = 0 */

		if (fputc(c, output_fp) == EOF)
		{
			fprintf(stderr, "%s%s%s%i%c",
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
		fprintf(stderr, "%s%s%s%i%c", "Couldn't close input file ",
				argv[1], ". Error code: ", errno, '\n');

		exit(EXIT_FAILURE);
	}

	if (fclose(output_fp) == EOF)
	{
		fprintf(stderr, "%s%s%s%i%c", "Couldn't close output file ",
				argv[2], ". Error code: ", errno, '\n');

		exit(EXIT_FAILURE);
	}

	return EXIT_SUCCESS;
}
