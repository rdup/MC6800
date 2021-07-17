//
//	main.cc
//

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include <signal.h>
#include "mc6809.h"

class sys : public mc6809 {
private:

	int			tty;
	struct termios		oattr, nattr;

protected:

virtual Byte			read(Word);
virtual void			write(Word, Byte);

public:

				sys();
				~sys();
} sys;

Byte sys::read(Word addr)
{
	if (addr == 0xc000) {
		return fgetc(stdin);
	} else {
		return mc6809::read(addr);
	}
}

void sys::write(Word addr, Byte x)
{
	if (addr == 0xc000) {
		fputc(x, stdout);
	} else {
		mc6809::write(addr, x);
	}
}

sys::sys()
{
	tty = fileno(stdin);
	tcgetattr(tty, &nattr);
	tcgetattr(tty, &oattr);
	nattr.c_lflag &= ~ICANON;
	nattr.c_lflag &= ~ECHO;
	tcsetattr(tty, 0, &nattr);
}

sys::~sys()
{
	tcsetattr(tty, 0, &oattr);
}

int main(int argc, char *argv[])
{
	if (argc != 2) {
		fprintf(stderr, "usage: usim <hexfile>\n");
		return EXIT_FAILURE;
	}

	sys.load(argv[1]);
	sys.run();

	fprintf(stderr, "read cycles = %ld, write cycles = %ld\n", sys.nr, sys.nw);

	return EXIT_SUCCESS;
}
