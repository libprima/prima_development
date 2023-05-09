module message_mod
!--------------------------------------------------------------------------------------------------!
! This module provides some subroutines that print messages to terminal/files.
!
! N.B.:
! 1. In case parallelism is desirable (especially during initialization), the subroutines may
! have to be modified or disabled due to the IO operations.
! 2. IPRINT indicates the level of verbosity, which increases with the absolute value of IPRINT.
! IPRINT = +/-3 can be expensive due to high IO operations.
!
! Coded by Zaikun ZHANG (www.zhangzk.net) based on Powell's code and papers.
!
! Started: July 2020
!
! Last Modified: Monday, May 08, 2023 PM08:15:50
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: retmsg, rhomsg, fmsg, cpenmsg

character(len=3), parameter :: spaces = '   '

contains


subroutine retmsg(solver, info, iprint, nf, f, x, cstrv, constr)
!--------------------------------------------------------------------------------------------------!
! This subroutine prints messages at return.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : RP, IK, ZERO, OUTUNIT, STDOUT, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert
use, non_intrinsic :: fprint_mod, only : fprint
use, non_intrinsic :: infos_mod, only : FTARGET_ACHIEVED, MAXFUN_REACHED, MAXTR_REACHED, &
    & SMALL_TR_RADIUS, TRSUBP_FAILED, NAN_INF_X, NAN_INF_F, NAN_INF_MODEL, DAMAGING_ROUNDING, &
    & NO_SPACE_BETWEEN_BOUNDS, ZERO_LINEAR_CONSTRAINT
use, non_intrinsic :: string_mod, only : strip, num2str
implicit none

! Compulsory inputs
character(len=*), intent(in) :: solver
integer(IK), intent(in) :: info
integer(IK), intent(in) :: iprint
integer(IK), intent(in) :: nf
real(RP), intent(in) :: f
real(RP), intent(in) :: x(:)

! Optional inputs
real(RP), intent(in), optional :: cstrv
real(RP), intent(in), optional :: constr(:)

! Local variables
character(len=*), parameter :: newline = new_line('')
character(len=*), parameter :: srname = 'RETMSG'
character(len=:), allocatable :: constr_message
character(len=:), allocatable :: cstrv_message
character(len=:), allocatable :: f_message
character(len=:), allocatable :: fname
character(len=:), allocatable :: message
character(len=:), allocatable :: nf_message
character(len=:), allocatable :: reason
character(len=:), allocatable :: ret_message
character(len=:), allocatable :: x_message
integer :: funit ! File storage unit for the writing. Should be an integer of default kind.
integer(IK), parameter :: valid_exit_flags(11) = [FTARGET_ACHIEVED, MAXFUN_REACHED, MAXTR_REACHED, &
    & SMALL_TR_RADIUS, TRSUBP_FAILED, NAN_INF_F, NAN_INF_X, NAN_INF_MODEL, DAMAGING_ROUNDING, &
    & NO_SPACE_BETWEEN_BOUNDS, ZERO_LINEAR_CONSTRAINT]
logical :: is_constrained
real(RP) :: cstrv_loc

! Preconditions
if (DEBUGGING) then
    call assert(any(info == valid_exit_flags), 'The exit flag is valid', srname)
end if

!====================!
! Calculation starts !
!====================!

if (abs(iprint) < 1) then  ! No printing
    return
elseif (iprint > 0) then  ! Print the message to the standard out.
    funit = STDOUT
    fname = ''
else  ! Print the message to a file named FNAME with the writing unit being OUTUNIT.
    funit = OUTUNIT
    fname = strip(solver)//'_output.txt'
end if

! Decide whether the problem is truly constrained.
if (present(constr)) then
    is_constrained = (size(constr) > 0)
else
    is_constrained = present(cstrv)
end if

! Decide the constraint violation.
if (present(cstrv)) then
    cstrv_loc = cstrv
elseif (present(constr)) then
    cstrv_loc = maxval([ZERO, -constr])  ! N.B.: We assume that the constraint is CONSTR >= 0.
else
    cstrv_loc = ZERO
end if

! Decide the return message.
select case (info)
case (FTARGET_ACHIEVED)
    reason = 'the target function value is achieved.'
case (MAXFUN_REACHED)
    reason = 'the objective function has been evaluated MAXFUN times.'
case (MAXTR_REACHED)
    reason = 'the maximal number of trust region iterations has been reached.'
case (SMALL_TR_RADIUS)
    reason = 'the trust region radius reaches its lower bound.'
case (TRSUBP_FAILED)
    reason = 'a trust region step has failed to reduce the quadratic model.'
case (NAN_INF_X)
    reason = 'NaN or Inf occurs in x.'
case (NAN_INF_F)
    reason = 'the objective function returns NaN/+Inf.'
case (NAN_INF_MODEL)
    reason = 'NaN or Inf occurs in the models.'
case (DAMAGING_ROUNDING)
    reason = 'rounding errors are becoming damaging.'
case (NO_SPACE_BETWEEN_BOUNDS)
    reason = 'there is no space between the lower and upper bounds of variable.'
case (ZERO_LINEAR_CONSTRAINT)
    reason = 'one of the linear constraints has a zero gradient'
case default
    reason = 'UNKNOWN EXIT FLAG'
end select
ret_message = newline//'Return from '//solver//' because '//strip(reason)

nf_message = newline//'At the return from '//solver//spaces//'Number of function evaluations = '//num2str(nf)

f_message = newline//'Least function value = '//num2str(f)

if (size(x) <= 2) then
    x_message = newline//'The corresponding X is: '//num2str(x)  ! Printed in one line
else
    x_message = newline//'The corresponding X is:'//newline//num2str(x)
end if

if (is_constrained) then
    cstrv_message = newline//'Constraint violation = '//num2str(cstrv_loc)
else
    cstrv_message = ''
end if

if (is_constrained .and. present(constr)) then
    if (size(constr) <= 2) then
        constr_message = newline//'The constraint value is: '//num2str(constr)  ! Printed in one line
    else
        constr_message = newline//'The constraint value is:'//newline//num2str(constr)
    end if
else
    constr_message = ''
end if

! Print the message.
if (abs(iprint) >= 2) then
    message = newline//ret_message//nf_message//f_message//cstrv_message//x_message//constr_message//newline
else
    message = ret_message//nf_message//f_message//cstrv_message//x_message//constr_message//newline
end if
call fprint(message, funit, fname, 'append')

!====================!
!  Calculation ends  !
!====================!
end subroutine retmsg


subroutine rhomsg(solver, iprint, nf, f, rho, x, cstrv, constr, cpen)
!--------------------------------------------------------------------------------------------------!
! This subroutine prints messages when RHO is updated.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : RP, IK, ZERO, OUTUNIT, STDOUT
use, non_intrinsic :: fprint_mod, only : fprint
use, non_intrinsic :: string_mod, only : strip, num2str
implicit none

! Compulsory inputs
character(len=*), intent(in) :: solver
integer(IK), intent(in) :: iprint
integer(IK), intent(in) :: nf
real(RP), intent(in) :: f
real(RP), intent(in) :: rho
real(RP), intent(in) :: x(:)

! Optional inputs
real(RP), intent(in), optional :: cstrv
real(RP), intent(in), optional :: constr(:)
real(RP), intent(in), optional :: cpen

! Local variables
character(len=*), parameter :: newline = new_line('')
character(len=:), allocatable :: constr_message
character(len=:), allocatable :: cstrv_message
character(len=:), allocatable :: f_message
character(len=:), allocatable :: fname
character(len=:), allocatable :: message
character(len=:), allocatable :: rp_message
character(len=:), allocatable :: x_message
integer :: funit ! Logical unit for the writing. Should be an integer of default kind.
logical :: is_constrained
real(RP) :: cstrv_loc

!====================!
! Calculation starts !
!====================!

if (abs(iprint) < 2) then  ! No printing
    return
elseif (iprint > 0) then  ! Print the message to the standard out.
    funit = STDOUT
    fname = ''
else  ! Print the message to a file named FNAME with the writing unit being OUTUNIT.
    funit = OUTUNIT
    fname = strip(solver)//'_output.txt'
end if

! Decide whether the problem is truly constrained.
if (present(constr)) then
    is_constrained = (size(constr) > 0)
else
    is_constrained = present(cstrv)
end if

! Decide the constraint violation.
if (present(cstrv)) then
    cstrv_loc = cstrv
elseif (present(constr)) then
    cstrv_loc = maxval([ZERO, -constr])  ! N.B.: We assume that the constraint is CONSTR >= 0.
else
    cstrv_loc = ZERO
end if

if (present(cpen)) then
    rp_message = newline//'New RHO = '//num2str(rho)//spaces//'CPEN = '//num2str(cpen)// &
        & spaces//'Number of function evaluations = '//num2str(nf)
else
    rp_message = newline//'New RHO = '//num2str(rho)//spaces//'Number of function evaluations = '//num2str(nf)
end if

f_message = newline//'Least function value = '//num2str(f)

if (size(x) <= 2) then
    x_message = newline//'The corresponding X is: '//num2str(x)  ! Printed in one line
else
    x_message = newline//'The corresponding X is:'//newline//num2str(x)
end if

if (is_constrained) then
    cstrv_message = newline//'Constraint violation = '//num2str(cstrv_loc)
else
    cstrv_message = ''
end if

if (is_constrained .and. present(constr)) then
    if (size(constr) <= 2) then
        constr_message = newline//'The constraint value is: '//num2str(constr)  ! Printed in one line
    else
        constr_message = newline//'The constraint value is:'//newline//num2str(constr)
    end if
else
    constr_message = ''
end if

! Print the message.
if (abs(iprint) >= 3) then
    message = newline//rp_message//f_message//cstrv_message//x_message//constr_message
else
    message = rp_message//f_message//cstrv_message//x_message//constr_message
end if

call fprint(message, funit, fname, 'append')

!====================!
!  Calculation ends  !
!====================!
end subroutine rhomsg


subroutine cpenmsg(solver, iprint, cpen)
!--------------------------------------------------------------------------------------------------!
! This subroutine prints a message when CPEN is updated.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : RP, IK, OUTUNIT, STDOUT
use, non_intrinsic :: fprint_mod, only : fprint
use, non_intrinsic :: string_mod, only : strip, num2str
implicit none

! Compulsory inputs
character(len=*), intent(in) :: solver
integer(IK), intent(in) :: iprint

! Optional inputs
real(RP), intent(in), optional :: cpen

! Local variables
character(len=*), parameter :: newline = new_line('')
character(len=:), allocatable :: fname
character(len=:), allocatable :: message
integer :: funit ! Logical unit for the writing. Should be an integer of default kind.

!====================!
! Calculation starts !
!====================!

if (abs(iprint) < 2) then  ! No printing
    return
elseif (iprint > 0) then  ! Print the message to the standard out.
    funit = STDOUT
    fname = ''
else  ! Print the message to a file named FNAME with the writing unit being OUTUNIT.
    funit = OUTUNIT
    fname = strip(solver)//'_output.txt'
end if

! Print the message.
if (abs(iprint) >= 3) then
    message = newline//'Set CPEN to '//num2str(cpen)
else
    message = newline//newline//'Set CPEN to '//num2str(cpen)
end if
call fprint(message, funit, fname, 'append')

!====================!
!  Calculation ends  !
!====================!
end subroutine cpenmsg


subroutine fmsg(solver, iprint, nf, f, x, cstrv, constr)
!--------------------------------------------------------------------------------------------------!
! This subroutine prints messages at each iteration.
!--------------------------------------------------------------------------------------------------!
use, non_intrinsic :: consts_mod, only : RP, IK, ZERO, OUTUNIT, STDOUT
use, non_intrinsic :: fprint_mod, only : fprint
use, non_intrinsic :: string_mod, only : strip, num2str
implicit none

! Compulsory inputs
character(len=*), intent(in) :: solver
integer(IK), intent(in) :: iprint
integer(IK), intent(in) :: nf
real(RP), intent(in) :: f
real(RP), intent(in) :: x(:)

! Optional inputs
real(RP), intent(in), optional :: cstrv
real(RP), intent(in), optional :: constr(:)

! Local variables
character(len=*), parameter :: newline = new_line('')
character(len=:), allocatable :: constr_message
character(len=:), allocatable :: f_message
character(len=:), allocatable :: fname
character(len=:), allocatable :: message
character(len=:), allocatable :: x_message
integer :: funit ! Logical unit for the writing. Should be an integer of default kind.
logical :: is_constrained
real(RP) :: cstrv_loc

!====================!
! Calculation starts !
!====================!

if (abs(iprint) < 3) then  ! No printing
    return
elseif (iprint > 0) then  ! Print the message to the standard out.
    funit = STDOUT
    fname = ''
else  ! Print the message to a file named FNAME with the writing unit being OUTUNIT.
    funit = OUTUNIT
    fname = strip(solver)//'_output.txt'
end if

! Decide whether the problem is truly constrained.
if (present(constr)) then
    is_constrained = (size(constr) > 0)
else
    is_constrained = present(cstrv)
end if

! Decide the constraint violation.
if (present(cstrv)) then
    cstrv_loc = cstrv
elseif (present(constr)) then
    cstrv_loc = maxval([ZERO, -constr])  ! N.B.: We assume that the constraint is CONSTR >= 0.
else
    cstrv_loc = ZERO
end if

if (is_constrained) then
    f_message = newline//'Function number '//num2str(nf)//spaces//'Function value = '//num2str(f)// &
        & spaces//'Constraint violation = '//num2str(cstrv_loc)
else
    f_message = newline//'Function number '//num2str(nf)//spaces//'Function value = '//num2str(f)
end if

if (size(x) <= 2) then
    x_message = newline//'The corresponding X is: '//num2str(x)  ! Printed in one line
else
    x_message = newline//'The corresponding X is:'//newline//num2str(x)
end if

if (is_constrained .and. present(constr)) then
    if (size(constr) <= 2) then
        constr_message = newline//'The constraint value is: '//num2str(constr)  ! Printed in one line
    else
        constr_message = newline//'The constraint value is:'//newline//num2str(constr)
    end if
else
    constr_message = ''
end if

! Print the message.
message = f_message//x_message//constr_message
call fprint(message, funit, fname, 'append')

!====================!
!  Calculation ends  !
!====================!
end subroutine fmsg


end module message_mod
