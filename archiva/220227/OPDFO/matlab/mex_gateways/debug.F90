#include "fintrf.h"
#include "ppf.h"

module debug_mod
!--------------------------------------------------------------------------------------------------!
! This is a module defining some procedures concerning debugging, errors, and warnings.
!
! Coded by Zaikun ZHANG (www.zhangzk.net).
!
! Started: July 2020.
!
! Last Modified: Saturday, January 22, 2022 PM08:13:22
!--------------------------------------------------------------------------------------------------!
!! N.B.: When interfacing Fortran code with MATLAB, we use this module to replace the one defined in
!! fsrc/common/debug.F90, in order to generate errors or warnings that are native to MATLAB.
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: assert, validate, backtr, warning, errstop, verisize

interface verisize
    module procedure verisize_real_1, verisize_real_2
    module procedure verisize_int_1, verisize_int_2
    module procedure verisize_logical_1, verisize_logical_2
end interface verisize

! Specify the interfaces of mexWarnMsgIdAndTxt and mexErrMsgIdAndTxt.
! We may use those specified in fmxapi_mod. However, that would make debug.F90 depend on fmxapi.F90,
! and make it impossible to use debug_mod in fmxapi.F90.
interface
    subroutine mexErrMsgIdAndTxt(eid, emsg)
    implicit none
    character*(*), intent(in) :: eid, emsg
    end subroutine mexErrMsgIdAndTxt
    subroutine mexWarnMsgIdAndTxt(wid, wmsg)
    implicit none
    character*(*), intent(in) :: wid, wmsg
    end subroutine mexWarnMsgIdAndTxt
end interface


contains


subroutine assert(condition, description, srname)
!--------------------------------------------------------------------------------------------------!
! This subroutine checks whether ASSERTION is true.
! If no, print SRNAME // 'Assertion failed: ' // DESCRIPTION
! and then stop the program by calling ERRSTOP.
! MATLAB analogue: assert(condition, sprintf('%s: Assertion failed: %s', srname, description))
! Python analogue: assert condition, srname + ': Assertion failed: ' + description
! C analogue: assert(condition)  /* An error message will be produced by the compiler */
!--------------------------------------------------------------------------------------------------!
!! N.B.: As in C, we design ASSERT to operate only in the debug mode, i.e., when __DEBUGGING__ == 1;
!! when __DEBUGGING__ == 0, ASSERT does nothing. For the checking that should take effect in both
!! the debug and release modes, use VALIDATE (see below) instead. In the optimized mode of Python
!! (python -O), the Python `assert` will also be ignored. MATLAB does not behave in this way.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : DEBUGGING
implicit none
logical, intent(in) :: condition  ! A condition that is expected to be true
character(len=*), intent(in) :: description  ! Description of the condition in human language
character(len=*), intent(in) :: srname  ! Name of the subroutine that calls this procedure
if (DEBUGGING) then
    if (.not. condition) then
        call errstop(trim(srname), 'Assertion failed: '//trim(description))
    end if
end if
end subroutine assert


subroutine validate(condition, description, srname)
!--------------------------------------------------------------------------------------------------!
! This subroutine checks whether CONDITION is true.
! If no, print SRNAME // 'Validation failed: ' // DESCRIPTION
! and then stop the program by calling ERRSTOP.
! MATLAB analogue: assert(condition, sprintf('%s: Validation failed: %s', srname, description))
! In Python or C, VALIDATE can be implemented following the Fortran implementation below.
!--------------------------------------------------------------------------------------------------!
implicit none
logical, intent(in) :: condition  ! A condition that is expected to be true
character(len=*), intent(in) :: description  ! Description of the condition in human language
character(len=*), intent(in) :: srname  ! Name of the subroutine that calls this procedure
if (.not. condition) then
    call errstop(trim(srname), 'Validation failed: '//trim(description))
end if
end subroutine validate


subroutine errstop(srname, msg)
!--------------------------------------------------------------------------------------------------!
! This subroutine prints 'ERROR: '//TRIM(SRNAME)//': '//TRIM(MSG)//'!', then stop. In the
! debug mode, it also calls BACKTR to print the backtrace.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : MSGLEN, DEBUGGING
implicit none
character(len=*), intent(in) :: srname
character(len=*), intent(in) :: msg

character(len=MSGLEN) :: eid
character(len=MSGLEN) :: emsg

if (DEBUGGING) then
    call backtr()
end if
eid = 'FMXAPI:'//trim(srname)
emsg = trim(srname)//': '//trim(msg)//'!'
call mexErrMsgIdAndTxt(trim(eid), trim(emsg))
end subroutine errstop


subroutine backtr
!--------------------------------------------------------------------------------------------------!
! This subroutine calls a compiler-dependent intrinsic to show a backtrace if we are in the debuge
! mode, i.e., __DEBUGGING__ == 1.
! N.B.:
! 1. The intrinsic is compiler-dependent and does not exist in all compilers. Indeed, it is not
! standard-conforming. Therefore, compilers may warn that a non-standard intrinsic is in use.
! 2. More seriously, if the compiler is instructed to conform to the standards (e.g., gfortran with
! the option -std=f2003) while __DEBUGGING__ is set to 1, then the compilation may FAIL when linking,
! complaining that a subroutine cannot be found (e.g., backtrace for gfortran). In that case, we
! must set __DEBUGGING__ to 0 in ppf.h.
!--------------------------------------------------------------------------------------------------!
#if __DEBUGGING__ == 1

#if defined __GFORTRAN__
implicit none
call backtrace
#elif defined __INTEL_COMPILER
use, non_intrinsic :: ifcore, only : tracebackqq
implicit none
call tracebackqq(user_exit_code=-1)
! According to "Intel Fortran Compiler 19.1 Developer Guide and Reference", item "TRACEBACKQQ":
! By specifying a user exit code of -1, control returns to the calling program. Specifying a user
! exit code with a positive value requests that specified value be returned to the operating system.
! The default value is 0, which causes the application to abort execution.
#endif

#endif
end subroutine backtr


subroutine warning(srname, msg)
!--------------------------------------------------------------------------------------------------!
! This subroutine prints 'Warning: '//TRIM(SRNAME)//': '//TRIM(MSG)//'.'
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : MSGLEN
implicit none
character(len=*), intent(in) :: srname
character(len=*), intent(in) :: msg

character(len=MSGLEN) :: wid
character(len=MSGLEN) :: wmsg

wid = 'FMXAPI:'//trim(srname)
wmsg = trim(srname)//': '//trim(msg)//'.'
call mexWarnMsgIdAndTxt(trim(wid), trim(wmsg))
end subroutine warning


subroutine verisize_real_1(x, n)
!--------------------------------------------------------------------------------------------------!
! VERISIZE_REAL_1 verifies whether SIZE(X) = N.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : RP, IK
implicit none
real(RP), intent(in) :: x(:)
integer(IK), intent(in) :: n

character(len=*), parameter :: srname = 'VERISIZE_REAL_1'

if (int(size(x), IK) /= n) then
    call errstop(srname, 'SIZE(X) /= N')
end if
end subroutine verisize_real_1


subroutine verisize_real_2(x, m, n)
!--------------------------------------------------------------------------------------------------!
! VERISIZE_REAL_2 verifies whether SIZE(X, 1) = M, SIZE(X, 2) = N.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : RP, IK
implicit none
real(RP), intent(in) :: x(:, :)
integer(IK), intent(in) :: m
integer(IK), intent(in) :: n

character(len=*), parameter :: srname = 'VERISIZE_REAL_2'

if (int(size(x, 1), IK) /= m) then
    call errstop(srname, 'SIZE(X, 1) /= M')
end if
if (int(size(x, 2), IK) /= n) then
    call errstop(srname, 'SIZE(X, 2) /= N')
end if
end subroutine verisize_real_2


subroutine verisize_int_1(x, n)
!--------------------------------------------------------------------------------------------------!
! VERISIZE_INT_1 verifies whether SIZE(X) = N.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : IK
implicit none
integer(IK), intent(in) :: x(:)
integer(IK), intent(in) :: n

character(len=*), parameter :: srname = 'VERISIZE_INT_1'

if (int(size(x), IK) /= n) then
    call errstop(srname, 'SIZE(X) /= N')
end if
end subroutine verisize_int_1


subroutine verisize_int_2(x, m, n)
!--------------------------------------------------------------------------------------------------!
! VERISIZE_INT_2 verifies whether SIZE(X, 1) = M, SIZE(X, 2) = N.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : IK
implicit none
integer(IK), intent(in) :: x(:, :)
integer(IK), intent(in) :: m
integer(IK), intent(in) :: n

character(len=*), parameter :: srname = 'VERISIZE_INT_2'

if (int(size(x, 1), IK) /= m) then
    call errstop(srname, 'SIZE(X, 1) /= M')
end if
if (int(size(x, 2), IK) /= n) then
    call errstop(srname, 'SIZE(X, 2) /= N')
end if
end subroutine verisize_int_2


subroutine verisize_logical_1(x, n)
!--------------------------------------------------------------------------------------------------!
! VERISIZE_LOGICAL_1 verifies whether SIZE(X) = N.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : IK
implicit none
logical, intent(in) :: x(:)
integer(IK), intent(in) :: n

character(len=*), parameter :: srname = 'VERISIZE_LOGICAL_1'

if (int(size(x), IK) /= n) then
    call errstop(srname, 'SIZE(X) /= N')
end if
end subroutine verisize_logical_1


subroutine verisize_logical_2(x, m, n)
!--------------------------------------------------------------------------------------------------!
! VERISIZE_LOGICAL_2 verifies whether SIZE(X, 1) = M, SIZE(X, 2) = N.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : IK
implicit none
logical, intent(in) :: x(:, :)
integer(IK), intent(in) :: m
integer(IK), intent(in) :: n

character(len=*), parameter :: srname = 'VERISIZE_LOGICAL_2'

if (int(size(x, 1), IK) /= m) then
    call errstop(srname, 'SIZE(X, 1) /= M')
end if
if (int(size(x, 2), IK) /= n) then
    call errstop(srname, 'SIZE(X, 2) /= N')
end if
end subroutine verisize_logical_2


end module debug_mod
