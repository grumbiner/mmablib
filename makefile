#Robert Grumbine
# 1998

export FC=ifort

all : libombf_4.a libombc_4.a

libombc_4.a :
	sorc/makelibombC.sh

libombf_4.a :
	sorc/makelibombF.sh

distclean : 
	rm libombf_4.a libombc_4.a sorc/*.o

