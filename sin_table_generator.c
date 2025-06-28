/* sin_table_generator.c
 * by Richard Cavell
 * June 2025
 *
 */

#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

const double pi = 3.14159265358979323846;

static void
fprintf_error(void)
{
	(void) fprintf(stderr, "%s%i%c",
			 "Couldn't print to output file. Error number : ",
			  errno,
			 '\n');
	exit(EXIT_FAILURE);
}

int
main(int argc, char *argv[])
{
	FILE *fp = NULL;
	int ret = 0;
	int i = 0;

	if (argc != 2)
	{
		(void) fprintf(stderr, "%s%s%s", "Usage: ",
					 argv[0],
					 " outputfile\n");
		exit(EXIT_FAILURE);
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

	for (i = 0; i < 256; ++i)
	{
		double angle = i / 256.0 * 2 * pi;
		double f = sin(angle) * 256;
		int j = 0;

/*		f = round(f);		This is C99 */

		/* Round to nearest */
		if (f >= 0)
			j = (int) (f + 0.5);
		else
			j = (int) -(-f + 0.5);

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
				        argv[1], ". Error number : ",
				        errno,
				        '\n');
		exit(EXIT_FAILURE);
	}

	return EXIT_SUCCESS;
}
