# This Makefile illustrates how to use the modern-Fortran version of Powell's solvers. We intend to
# try as many compilers as possible.
#
# Coded by Zaikun Zhang (www.zhangzk.net).
#
# Started: July 2020
#
# Last Modified: September 13, 2021
#
# N.B.:
# The .F90 and .f90 files will be compiled in the enumeration order of the .o files. The order
# matters, because the compilation of each .o file depends on the .o files (and the corresponding
# .mod files) preceding it.

.PHONY: test clean

####################################################################################################
# Variables
SOLVER := $(shell basename $(CURDIR))
# Define the Fortran standard to follow. We aim to make the code compatible with F2008 and above.
# Make sure that your compiler supports the selected standard. For example, gfortran does not
# recognize -std=f2018 until gfortran 8.1 released in May 2018.
FS ?= 18  # Set FS if it does not have a value.
FSTD := 20$(FS)
# Default options for all the compilers.
FFLAGS := -O3 -g
# Common directories.
COMMON := ../../common
# Headers.
HEADERS := $(COMMON)/*.h
# Solver source files.
SOLVER_SRC := ../../$(SOLVER)

####################################################################################################
# All the tests
test:
	$(MAKE) dtest
	$(MAKE) ftest
	$(MAKE) gtest
	$(MAKE) itest
	$(MAKE) ntest
	$(MAKE) vtest
	$(MAKE) xtest
	$(MAKE) rtest

####################################################################################################
# Here are the compilers to test.

# AMD AOCC Flang
AFLANG := $(shell find -L /opt/AMD -type f -executable -name flang -print 2> /dev/null | sort | tail -n 1)
dtest: FC := $(AFLANG) -Wall -Wextra -std=f$(FSTD) -Mstandard

# Flang
ftest: FC := flang -Wall -Wextra -std=f$(FSTD) -Mstandard

# GNU gfortran: due to `error stop` and `backtrace`, we must either compile wit no `-std` or
# use `-std=f20xy -fall-intrinsics` with xy >= 18.
gtest: FC := gfortran -Wall -Wextra -Wno-function-elimination -std=f$(FSTD) -fall-intrinsics

# Intel ifort
itest: FC := ifort -warn all -stand f$(FS)

# NAG nagfor
ntest: FC := nagfor -C -f$(FSTD)

# NVIDIA nvfortran (aka, pgfortran)
VFORT := $(shell find -L /opt/nvidia -type f -executable -name nvfortran -print 2> /dev/null | sort | tail -n 1)
vtest: FC := $(VFORT) -C -Wall -Wextra -Mstandard

# ARM Flang
RFORT := $(shell find -L /opt/arm -type f -executable -name armflang -print 2> /dev/null | sort | tail -n 1)
rtest: FC := $(RFORT) -Wall -Wextra -std=f$(FSTD) -Mstandard

# Intel ifx
xtest: FC := ifx -warn all -stand f$(FS)

####################################################################################################
# Compile the binary needed for a compiler-specific test
%test: $(SOLVER)_example.f90 \
	consts.o infos.o debug.o inf.o infnan.o memory.o string.o linalg.o powalg.o univar.o ratio.o \
	redrho.o history.o checkexit.o fprint.o message.o preproc.o pintrf.o evaluate.o shiftbase.o \
	xinbd.o update.o initialize.o rescue.o trustregion.o geometry.o bobyqb.o bobyqa.o
	$(FC) $(FFLAGS) -o $@ $(SOLVER)_example.f90 *.o
	./$@
	@$(MAKE) clean

# Compile the Fortran code providing common modules
%.o: $(COMMON)/%.*90 $(HEADERS)
	$(FC) $(FFLAGS) -c -o $@ $<

# Compile the Fortran code providing solver-specific modules
%.o: $(SOLVER_SRC)/%.f90 $(HEADERS)
	$(FC) $(FFLAGS) -c -o $@ $<

####################################################################################################
# Cleaning up.
clean:
	@rm -f *.o *.mod *.dbg *.cmdx *.cmod *.ilm *.stb
	@rm -f *test
