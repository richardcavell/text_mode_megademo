/* sin_table_generator.c
 * by Richard Cavell
 * June 2025 - July 2025
 *
 */

#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const double pi = 3.14159265358979323846;
const int COMPLETE_CIRCLE = 256;

static int
round_nearest(double f)
{
	 /* This is C89 */
	return (int) ((f >= 0.0) ? f + 0.5 : f - 0.5);

	/* This is C99 */
/*	return (int) (round(f)); */
}

static void
fprintf_error(void)
{
	(void) fprintf(stderr, "%s%i%c",
			 "Couldn't print to output file. Error number : ",
			  errno,
			 '\n');
	exit(EXIT_FAILURE);
}

static void
print_help(const char *argv0)
{
	(void) printf("%s",
	    "Sine Table Generator v1.0\n"
	    "by Richard Cavell\n"
	    "https://github.com/richardcavell/text_mode_megademo\n");

	(void) printf("%s%s%s",
		      "Usage: ",
		       argv0,
		      " outputfile\n");
}

int
main(int argc, char *argv[])
{
	FILE *fp = NULL;
	int ret = 0;
	int i = 0;

	if (argc != 2)
	{
		print_help(argv[0]);
		exit(EXIT_FAILURE);
	}

	if (strcmp(argv[1], "--version") == 0 ||
	    strcmp(argv[1], "-v")        == 0 ||
	    strcmp(argv[1], "-V")        == 0 ||
	    strcmp(argv[1], "-version")  == 0 ||
	    strcmp(argv[1], "--help")    == 0 ||
	    strcmp(argv[1], "-h")        == 0 ||
	    strcmp(argv[1], "-?")        == 0 ||
	    strcmp(argv[1], "-help")     == 0 ||
	    strcmp(argv[1], "--info")    == 0 ||
	    strcmp(argv[1], "-info")     == 0)
	{
		print_help(argv[0]);
		exit(EXIT_SUCCESS);
	}


	fp = fopen(argv[1], "w");

	if (fp == NULL)
	{
		(void) fprintf(stderr, "%s%s%s%i%c",
				       "Couldn't open output file ",
				        argv[1],
				       ". Error number : ",
				        errno,
				       '\n');
		exit(EXIT_FAILURE);
	}

	ret = fprintf(fp, "%s",
            "* This file was automatically generated"
		" by sin_table_generator.c\n"
	    "* by Richard Cavell\n"
	    "* https://github.com/richardcavell/text-mode-demo\n"
	    "\n");

	if (ret < 0)
		fprintf_error();

	for (i = 0; i < COMPLETE_CIRCLE; ++i)
	{
		double angle = i / (double) COMPLETE_CIRCLE * 2 * pi;
		double f = sin(angle) * COMPLETE_CIRCLE;

		int j = round_nearest(f);

		ret = fprintf(fp, "%s%i%s%3i%s",
				  "\tFDB\t",
				   j,
				  "\t; ",
				   i,
				  "/256ths of a circle\n");

		if (ret < 0)
			fprintf_error();
	}

	ret = fclose(fp);

	if (ret)
	{
		(void) fprintf(stderr, "%s%s%s%i%c",
				       "Couldn't close output file ",
				        argv[1],
					". Error number : ",
				        errno,
				        '\n');
		exit(EXIT_FAILURE);
	}

	return EXIT_SUCCESS;
}
