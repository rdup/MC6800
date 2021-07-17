DEBUG		= -g -O
CCC		= g++
CC		= gcc
CCFLAGS		= $(DEBUG)

SRCS		= mc6809.cc mc6809ins.cc main.cc
OBJS		= $(SRCS:.cc=.o)
BIN		= usim

$(BIN):		$(OBJS)
	$(CCC) -o $(@) $(CCFLAGS) $(LDFLAGS) $(OBJS) $(LIBS)

.cc.o:
	$(CCC) $(CPPFLAGS) $(CCFLAGS) -c $<

$(OBJS):	machdep.h

machdep:	machdep.o
	$(CC) -o $(@) $(CCFLAGS) $(LDFLAGS) machdep.o

machdep.h:	machdep
	./machdep $(@)

clean:
	$(RM) -f machdep.h machdep.o machdep $(BIN) $(OBJS)
