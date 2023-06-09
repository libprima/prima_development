#include "fintrf.h"

module fmxcl_mod
!--------------------------------------------------------------------------------------------------!
! FMXCL_MOD is a module that provides the following constants
!
! IK_CL
! RP_CL
! MAXMEMORY_CL
!
! and the following procedures:
!
! fmxReadMPtr
! fmxWriteMPtr
!
! They are analogous to the subroutines with the same name in FMXAPI_MOD. The difference is that the
! procedures in FMXAPI_MOD deal with reading/writing of INTEGER(IK) and REAL(RP), while the
! procedures here read/write integers and reals with the "classical" kinds:
!
! classical kind for INTEGER: IK_CL = IK_DFT, e.g., kind(0);
! classical kind for REAL: RP_CL = DP, e.g., kind(0.0D0).
!
! N.B.:
! 0. IK_CL and RP_CL can be changed easily if needed (see below), but we decide not to support
! RP_CL = REAL128.
! 1. These procedures are needed when interfacing the "classical mode" of Powell's Fortran code
! with MEX.
! 2. Why cannot we emerge the fmxReadMPtr and fmxWriteMPtr here with those in FMXAPI_MOD? Because
! we cannot decide at compilation time whether IK = IK_CL and whether RP = RP_CL (we can if we
! include ppf.h, but we do not want to do that). Consequently, it is undecidable whether the
! interfaces of fmxReadMPtr should or not include the subroutines read_rscalar_cl, read_iscalar, etc.
! A solution is to let fmxReadMPtr include all possible combinations of integer kind and real kind
! (write_rscalar_sp, write_rscalar_dp, write_rscalar_qp, write_iscalar_int16_sp,
! write_iscalar_int16_dp, ...), but there are too many combinations! The same applies to fmxWriteMPtr.
! 3. We decide to name the procedures in exactly the same way as in FMXAPI_MOD so that the classical
! and normal modes of the MEX gateways can have almost the same I/O code except for inputs that do
! not appear in the classical mode, although they use fmxReadMPtr/fmxWriteMPtr from different modules.

! Coded by Zaikun ZHANG in July 2020.
!
! Last Modified: Tuesday, January 18, 2022 PM10:19:24
!--------------------------------------------------------------------------------------------------!

use, non_intrinsic :: consts_mod, only : DP, IK_CL => IK_DFT, RP_CL => DP
use, non_intrinsic :: fmxapi_mod, only : mwOne, notComplex
use, non_intrinsic :: fmxapi_mod, only : mxGetM, mxGetN
use, non_intrinsic :: fmxapi_mod, only : mexErrMsgIdAndTxt
use, non_intrinsic :: fmxapi_mod, only : mxCreateDoubleScalar
use, non_intrinsic :: fmxapi_mod, only : mxCreateDoubleMatrix
use, non_intrinsic :: fmxapi_mod, only : mxCopyPtrToReal8
use, non_intrinsic :: fmxapi_mod, only : mxCopyReal8ToPtr
use, non_intrinsic :: fmxapi_mod, only : fmxVerifyClassShape
use, non_intrinsic :: fmxapi_mod, only : fmxGetDble
implicit none
private
public :: IK_CL
public :: RP_CL
public :: MAXMEMORY_CL
public :: fmxReadMPtr
public :: fmxWriteMPtr

real(RP_CL), parameter :: ONE = 1.0_RP_CL
real(DP), parameter :: cvsnTol = 1.0E1_DP * max(epsilon(0.0_DP), real(epsilon(0.0_RP_CL), DP))
integer, parameter :: MAXMEMORY_CL = min(21 * (10**8), int(huge(0_IK_CL)))

interface fmxReadMPtr
    ! fmxReadMPtr reads the numeric data associated with an mwPointer.
    ! It verifies the class and shape of the data before reading, and
    ! converts the data to REAL(RP_CL) if necessary.
    module procedure read_rscalar_cl, read_rvector_cl, read_rmatrix_cl
    module procedure read_iscalar_cl
    module procedure read_lscalar_cl
end interface fmxReadMPtr

interface fmxWriteMPtr
    ! fmxWriteMPtr associates numeric data with an mwPointer. It converts the data to REAL(DP) if
    ! necessary, and allocates space if the data is a vector or matrix. Therefore, it is necessary
    ! to call mxDestroyArray when the usage of the vector/matrix terminates.
    module procedure write_rscalar_cl, write_rvector_cl, write_rmatrix_cl
    module procedure write_iscalar_cl
end interface fmxWriteMPtr


contains


subroutine read_rscalar_cl(px, x)
! READ_RSCALAR_CL reads the double scalar associated with an mwPointer PX and saves the data in X,
! which is a REAL(RP_CL) scalar.
use, non_intrinsic :: consts_mod, only : DP, MSGLEN
implicit none

! Input
mwPointer, intent(in) :: px

! Output
real(RP_CL), intent(out) :: x

! Local variable
real(DP) :: x_dp(1)
character(len=MSGLEN) :: eid, msg

! Check input type and size
call fmxVerifyClassShape(px, 'double', 'scalar')

! Read the input
call mxCopyPtrToReal8(fmxGetDble(px), x_dp, mwOne)

! Convert the input to the type expected by the Fortran code
x = real(x_dp(1), kind(x))
! Check whether the type conversion is proper
if (kind(x) /= kind(x_dp)) then
    if (abs(x - x_dp(1)) > cvsnTol * max(abs(x), ONE)) then
        eid = 'FMXAPI:ConversionError'
        msg = 'READ_RSCALAR_CL: Large error occurs when converting REAL(DP) to REAL(RP_CL) (maybe due to overflow).'
        call mexErrMsgIdAndTxt(trim(eid), trim(msg))
    end if
end if
end subroutine read_rscalar_cl


subroutine read_rvector_cl(px, x)
! READ_RVECTOR_CL reads the double vector associated with an mwPointer PX and saves the data in X,
! which is a REAL(RP_CL) allocatable vector and should have size mxGetM(PX)*mxGetN(PX) at return.
use, non_intrinsic :: consts_mod, only : DP, IK, MSGLEN
use, non_intrinsic :: memory_mod, only : safealloc
implicit none

! Input
mwPointer, intent(in) :: px

! Output
real(RP_CL), allocatable, intent(out) :: x(:)

! Local variables
real(DP), allocatable :: x_dp(:)
integer(IK_CL) :: n
mwSize :: n_mw
character(len=MSGLEN) :: eid, msg

! Check input type and size
call fmxVerifyClassShape(px, 'double', 'vector')

! Get size
n_mw = int(mxGetM(px) * mxGetN(px), kind(n_mw))
n = int(n_mw, kind(n))

! Copy input to X_DP
call safealloc(x_dp, int(n, IK)) ! NOT removable
call mxCopyPtrToReal8(fmxGetDble(px), x_dp, n_mw)

! Convert X_DP to the type expected by the Fortran code
call safealloc(x, int(n, IK)) ! Removable in F2003
x = real(x_dp, kind(x))
! Check whether the type conversion is proper
if (kind(x) /= kind(x_dp)) then
    if (maxval(abs(x - x_dp)) > cvsnTol * max(maxval(abs(x)), ONE)) then
        eid = 'FMXAPI:ConversionError'
        msg = 'READ_RVECTOR_CL: Large error occurs when converting REAL(DP) to REAL(RP_CL) (maybe due to overflow).'
        call mexErrMsgIdAndTxt(trim(eid), trim(msg))
    end if
end if

! Deallocate X_DP. Indeed, automatic deallocation would take place.
deallocate (x_dp)
end subroutine read_rvector_cl


subroutine read_rmatrix_cl(px, x)
! READ_MATRIX_CL reads the double matrix associated with an mwPointer PX and saves the data in X,
! which is a REAL(RP_CL) allocatable matrix and should have size [mxGetM(PX), mxGetN(PX)] at return.
use, non_intrinsic :: consts_mod, only : DP, IK, MSGLEN
use, non_intrinsic :: memory_mod, only : safealloc
implicit none

! Input
mwPointer, intent(in) :: px

! Output
real(RP_CL), allocatable, intent(out) :: x(:, :)

! Local variables
real(DP), allocatable :: x_dp(:, :)
integer(IK_CL) :: m, n
mwSize :: xsize
character(len=MSGLEN) :: eid, msg

! Check input type and size
call fmxVerifyClassShape(px, 'double', 'matrix')

! Get size
m = int(mxGetM(px), kind(m))
n = int(mxGetN(px), kind(n))
xsize = int(m * n, kind(xsize))

! Copy input to X_DP
call safealloc(x_dp, int(m, IK), int(n, IK)) ! NOT removable
call mxCopyPtrToReal8(fmxGetDble(px), x_dp, xsize)

! Convert X_DP to the type expected by the Fortran code
call safealloc(x, int(m, IK), int(n, IK)) ! Removable in F2003
x = real(x_dp, kind(x))
! Check whether the type conversion is proper
if (kind(x) /= kind(x_dp)) then
    if (maxval(abs(x - x_dp)) > cvsnTol * max(maxval(abs(x)), ONE)) then
        eid = 'FMXAPI:ConversionError'
        msg = 'READ_MATRIX_CL: Large error occurs when converting REAL(DP) to REAL(RP_CL) (maybe due to overflow).'
        call mexErrMsgIdAndTxt(trim(eid), trim(msg))
    end if
end if

! Deallocate X_DP. Indeed, automatic deallocation would take place.
deallocate (x_dp)
end subroutine read_rmatrix_cl


subroutine read_iscalar_cl(px, x)
! READ_ISCALAR_CL reads a MEX input X that is a double scalar with an integer value. Such a value
! will be passed to the Fortran code as an integer but passed by MEX as a double.
use, non_intrinsic :: consts_mod, only : DP, MSGLEN
implicit none

! Input
mwPointer, intent(in) :: px

! Output
integer(IK_CL), intent(out) :: x

! Local variable
real(DP) :: x_dp(1)
character(len=MSGLEN) :: eid, msg

! Check input type and size
call fmxVerifyClassShape(px, 'double', 'scalar')

! Read the input
call mxCopyPtrToReal8(fmxGetDble(px), x_dp, mwOne)

! Convert the input to the type expected by the Fortran code
x = int(x_dp(1), kind(x))

! Check whether the type conversion is proper
if (abs(x - x_dp(1)) > epsilon(x_dp) * max(abs(x), 1_IK_CL)) then
    eid = 'FMXAPI:ConversionError'
    msg = 'READ_ISCALAR_CL: Large error occurs when converting REAL(DP) to INTEGER ' &
        & //'(maybe due to overflow, or the input is not an integer).'
    call mexErrMsgIdAndTxt(trim(eid), trim(msg))
end if
end subroutine read_iscalar_cl


subroutine read_lscalar_cl(px, x)
! READ_LSCALAR_CL reads a MEX input X that is a double scalar with a boolean value. Such a value will
! be passed to the Fortran code as a logical. In MEX, data is passed by pointers, but there is no
! functions that can read a boolean value from a pointer. Therefore, in general, it is recommended
! to pass logicals as double variables and then cast them back to logicals before using them in the
! Fortran code.
use, non_intrinsic :: consts_mod, only : DP, MSGLEN
implicit none

! Input
mwPointer, intent(in) :: px

! Output
logical, intent(out) :: x

! Local variables
character(len=MSGLEN) :: eid, msg
integer :: x_int
real(DP) :: x_dp(1)

! Check input type and size
call fmxVerifyClassShape(px, 'double', 'scalar')

! Read the input
call mxCopyPtrToReal8(fmxGetDble(px), x_dp, mwOne)

! Convert the input to the type expected by the Fortran code
x_int = int(x_dp(1))

! Check whether the type conversion is proper
if (abs(x_int - x_dp(1)) > epsilon(x_dp) * max(abs(x_int), 1)) then
    eid = 'FMXAPI:ConversionError'
    msg = 'READ_LSCALAR_CL: Large error occurs when converting REAL(DP) to INTEGER ' &
        & //'(maybe due to overflow, or the input is not an integer).'
    call mexErrMsgIdAndTxt(trim(eid), trim(msg))
end if
if (x_int /= 0 .and. x_int /= 1) then
    eid = 'FMXAPI:InputNotBoolean'
    msg = 'READ_LSCALAR_CL: The input should be boolean, either 0 or 1.'
    call mexErrMsgIdAndTxt(trim(eid), trim(msg))
end if

x = (x_int == 1)

end subroutine read_lscalar_cl


subroutine write_rscalar_cl(x, px)
! WRITE_RSCALAR_CL associates a REAL(RP_CL) scalar X with an mwPointer PX, after which X can be
! passed to MATLAB either as an output of mexFunction or an input of mexCallMATLAB.
use, non_intrinsic :: consts_mod, only : DP, MSGLEN
implicit none

! Input
real(RP_CL), intent(in) :: x

! Output
mwPointer, intent(out) :: px

! Local variable
real(DP) :: x_dp
character(len=MSGLEN) :: eid, msg

! Convert X to REAL(DP), which is expected by mxCopyReal8ToPtr
x_dp = real(x, kind(x_dp))
if (kind(x_dp) /= kind(x)) then
    ! Check whether the type conversion is proper
    if (abs(x - x_dp) > cvsnTol * max(abs(x), ONE)) then
        eid = 'FMXAPI:ConversionError'
        msg = 'WRITE_RSCALAR_CL: Large error occurs when converting REAL(RP_CL) to REAL(DP) (maybe due to overflow).'
        call mexErrMsgIdAndTxt(trim(eid), trim(msg))
    end if
end if

px = mxCreateDoubleScalar(x_dp)

end subroutine write_rscalar_cl


subroutine write_rvector_cl(x, px, rowcol)
! WRITE_RVECTOR_CL associates a REAL(RP_CL) vector X with an mwPointer PX, after which X can be
! passed to MATLAB either as an output of mexFunction or an input of mexCallMATLAB. If
! ROWCOL = 'row', then the vector is passed as a row vector, otherwise, it will be a column vector.
use, non_intrinsic :: consts_mod, only : DP, MSGLEN
use, non_intrinsic :: string_mod, only : lower
implicit none

! Input
real(RP_CL), intent(in) :: x(:)
character(len=*), intent(in), optional :: rowcol

! Output
mwPointer, intent(out) :: px

! Local variable
real(DP) :: x_dp(size(x))
integer(IK_CL) :: n
mwSize :: n_mw
logical :: row
character(len=MSGLEN) :: eid, msg

! Get size of X
n_mw = int(size(x), kind(n_mw))
n = int(n_mw, kind(n))

! Convert X to REAL(DP), which is expected by mxCopyReal8ToPtr
x_dp = real(x, kind(x_dp))
! Check whether the type conversion is proper
if (kind(x) /= kind(x_dp)) then
    if (maxval(abs(x - x_dp)) > cvsnTol * max(maxval(abs(x)), ONE)) then
        eid = 'FMXAPI:ConversionError'
        msg = 'WRITE_RVECTOR_CL: Large error occurs when converting REAL(RP_CL) to REAL(DP) (maybe due to overflow).'
        call mexErrMsgIdAndTxt(trim(eid), trim(msg))
    end if
end if

row = .false.
if (present(rowcol)) then
    row = (lower(rowcol) == 'row')
end if
! Create a MATLAB matrix using the data in X_DP
if (row) then
    px = mxCreateDoubleMatrix(mwOne, n_mw, notComplex)
else
    px = mxCreateDoubleMatrix(n_mw, mwOne, notComplex)
end if
call mxCopyReal8ToPtr(x_dp, fmxGetDble(px), n_mw)

end subroutine write_rvector_cl


subroutine write_rmatrix_cl(x, px)
! WRITE_MATRIX_CL associates a REAL(RP_CL) matrix X with an mwPointer PX, after which X can be
! passed to MATLAB either as an output of mexFunction or an input of mexCallMATLAB.
use, non_intrinsic :: consts_mod, only : DP, MSGLEN
implicit none

! Input
real(RP_CL), intent(in) :: x(:, :)

! Output
mwPointer, intent(out) :: px

! Local variable
real(DP) :: x_dp(size(x, 1), size(x, 2))
integer(IK_CL) :: m, n
mwSize :: m_mw, n_mw
character(len=MSGLEN) :: eid, msg

! Get size of X
m = int(size(x, 1), kind(m))
n = int(size(x, 2), kind(n))
m_mw = int(m, kind(m_mw))
n_mw = int(n, kind(n_mw))

! Convert X to REAL(DP), which is expected by mxCopyReal8ToPtr
x_dp = real(x, kind(x_dp))
! Check whether the type conversion is proper
if (kind(x) /= kind(x_dp)) then
    if (maxval(abs(x - x_dp)) > cvsnTol * max(maxval(abs(x)), ONE)) then
        eid = 'FMXAPI:ConversionError'
        msg = 'WRITE_MATRIX_CL: Large error occurs when converting REAL(RP_CL) to REAL(DP) (maybe due to overflow).'
        call mexErrMsgIdAndTxt(trim(eid), trim(msg))
    end if
end if

! Create a MATLAB matrix using the data in X_DP
px = mxCreateDoubleMatrix(m_mw, n_mw, notComplex)
call mxCopyReal8ToPtr(x_dp, fmxGetDble(px), m_mw * n_mw)

end subroutine write_rmatrix_cl


subroutine write_iscalar_cl(x, px)
! WRITE_RSCALAR_CL associates an INTEGER(IK_CL) scalar X with an mwPointer PX, after which X can be
! passed to MATLAB either as an output of mexFunction or an input of mexCallMATLAB.
use, non_intrinsic :: consts_mod, only : DP, MSGLEN
implicit none

! Input
integer(IK_CL), intent(in) :: x

! Output
mwPointer, intent(out) :: px

! Local variable
real(DP) :: x_dp
character(len=MSGLEN) :: eid, msg

x_dp = real(x, kind(x_dp))

if (abs(x - x_dp) > epsilon(x_dp) * max(abs(x), 1_IK_CL)) then
    eid = 'FMXAPI:ConversionError'
    msg = 'WRITE_ISCALAR_CL: Large error occurs when converting INTEGER(IK_CL) to REAL(DP) (maybe due to overflow).'
    call mexErrMsgIdAndTxt(trim(eid), trim(msg))
end if

px = mxCreateDoubleScalar(x_dp)

end subroutine write_iscalar_cl


end module fmxcl_mod
