module update_mod
!--------------------------------------------------------------------------------------------------!
! This module contains subroutines concerning the update of the interpolation set.
!
! Coded by Zaikun ZHANG (www.zhangzk.net) based on Powell's code and the BOBYQA paper.
!
! Dedicated to late Professor M. J. D. Powell FRS (1936--2015).
!
! Started: February 2022
!
! Last Modified: Saturday, October 01, 2022 PM03:00:14
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: updateh


contains


subroutine updateh(knew, beta, vlag_in, bmat, zmat, info)
!--------------------------------------------------------------------------------------------------!
! This subroutine updates arrays BMAT and ZMAT in order to replace the interpolation point
! XPT(:, KNEW) by XNEW = XPT(:, KOPT) + D. See Section 4 of the BOBYQA paper. [BMAT, ZMAT] describes
! the matrix H in the BOBYQA paper (eq. 2.7), which is the inverse of the coefficient matrix of the
! KKT system for the least-Frobenius norm interpolation problem: ZMAT holds a factorization of the
! leading NPT*NPT submatrix OMEGA of H, the factorization being OMEGA = ZMAT*ZMAT^T; BMAT holds the
! last N ROWs of H except for the (NPT+1)th column. Note that the (NPT + 1)th row and (NPT + 1)th
! column of H are not stored as they are unnecessary for the calculation.
!--------------------------------------------------------------------------------------------------!

! Generic modules
use, non_intrinsic :: consts_mod, only : RP, IK, ONE, ZERO, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert
use, non_intrinsic :: infnan_mod, only : is_finite
use, non_intrinsic :: infos_mod, only : INFO_DFT, DAMAGING_ROUNDING
use, non_intrinsic :: linalg_mod, only : planerot, matprod, outprod, symmetrize, issymmetric
implicit none

! Inputs
integer(IK), intent(in) :: knew
real(RP), intent(in) :: beta
real(RP), intent(in) :: vlag_in(:)  ! VLAG(NPT + N)

! In-outputs
real(RP), intent(inout) :: bmat(:, :)  ! BMAT(N, NPT + N)
real(RP), intent(inout) :: zmat(:, :)  ! ZMAT(NPT, NPT-N-1)

! Outputs
integer(IK), intent(out), optional :: info

! Local variables
character(len=*), parameter :: srname = 'UPDATEH'
integer(IK) :: j
integer(IK) :: n
integer(IK) :: npt
real(RP) :: alpha
real(RP) :: denom
real(RP) :: grot(2, 2)
real(RP) :: sqrtdn
real(RP) :: tau
real(RP) :: tempa
real(RP) :: tempb
real(RP) :: v1(size(bmat, 1))
real(RP) :: v2(size(bmat, 1))
real(RP) :: vlag(size(vlag_in))
real(RP) :: w(size(vlag))
real(RP) :: ztest

! Sizes.
n = int(size(bmat, 1), kind(n))
npt = int(size(bmat, 2) - size(bmat, 1), kind(npt))

! Preconditions
if (DEBUGGING) then
    call assert(n >= 1, 'N >= 1', srname)
    call assert(npt >= n + 2, 'NPT >= N+2', srname)
    call assert(knew >= 1 .and. knew <= npt, '1 <= KNEW <= NPT', srname)
    call assert(size(bmat, 1) == n .and. size(bmat, 2) == npt + n, 'SIZE(BMAT)==[N, NPT+N]', srname)
    call assert(issymmetric(bmat(:, npt + 1:npt + n)), 'BMAT(:, NPT+1:NPT+N) is symmetric', srname)
    call assert(size(zmat, 1) == npt .and. size(zmat, 2) == npt - n - 1_IK, 'SIZE(ZMAT) == [NPT, NPT-N-1]', srname)
    call assert(size(vlag_in) == npt + n, 'SIZE(VLAG) == NPT + N', srname)

    ! The following is too expensive to check.
    !tol = 1.0E-2_RP
    !call wassert(errh(bmat, zmat, xpt) <= tol .or. RP == kind(0.0), &
    !    & 'H = W^{-1} in (2.7) of the BOBYQA paper', srname)
end if

!====================!
! Calculation starts !
!====================!

if (present(info)) then
    info = INFO_DFT
end if

! We must not do anything if KNEW is 0. This can only happen sometimes after a trust-region step.
if (knew <= 0) then  ! KNEW < 0 is impossible if the input is correct.
    return
end if

! Read VLAG, and calculate parameters for the updating formula (4.9) and (4.14) of the BOBYQA paper.
vlag = vlag_in
tau = vlag(knew)
! In theory, DENOM can also be calculated after ZMAT is rotated below. However, this worsened the
! performance of BOBYQA in a test on 20220413.
denom = sum(zmat(knew, :)**2) * beta + tau**2

! Quite rarely, due to rounding errors, VLAG or BETA may not be finite, and DENOM may not be
! positive. In such cases, [BMAT, ZMAT] would be destroyed by the update, and hence we would rather
! not update them at all. Or should we simply terminate the algorithm?
if (.not. (is_finite(sum(abs(vlag)) + abs(beta)) .and. denom > 0)) then
    if (present(info)) then
        info = DAMAGING_ROUNDING
    end if
    return
end if

! After the following line, VLAG = H*w - e_KNEW in the NEWUOA paper (where t = KNEW).
vlag(knew) = vlag(knew) - ONE

! Apply Givens rotations to put zeros in the KNEW-th row of ZMAT. After this, ZMAT(KNEW, :) contains
! only one nonzero at ZMAT(KNEW, 1). Entries of ZMAT are treated as 0 if the moduli are at most ZTEST.
ztest = 1.0E-20_RP * maxval(abs(zmat))
do j = 2, npt - n - 1_IK
    if (abs(zmat(knew, j)) > ztest) then
        grot = planerot(zmat(knew, [1_IK, j]))
        zmat(:, [1_IK, j]) = matprod(zmat(:, [1_IK, j]), transpose(grot))
    end if
    zmat(knew, j) = ZERO
end do

! Put the first NPT components of the KNEW-th column of H into W(1:NPT).
w(1:npt) = zmat(knew, 1) * zmat(:, 1)
alpha = w(knew)

! Complete the updating of ZMAT. See (4.14) of the BOBYQA paper.
sqrtdn = sqrt(denom)
tempa = tau / sqrtdn
tempb = zmat(knew, 1) / sqrtdn
zmat(:, 1) = tempa * zmat(:, 1) - tempb * vlag(1:npt)

! Finally, update the matrix BMAT. It implements the last N rows of (4.9) in the BOBYQA paper.
w(npt + 1:npt + n) = bmat(:, knew)
v1 = (alpha * vlag(npt + 1:npt + n) - tau * w(npt + 1:npt + n)) / denom
v2 = (-beta * w(npt + 1:npt + n) - tau * vlag(npt + 1:npt + n)) / denom
bmat = bmat + outprod(v1, vlag) + outprod(v2, w) !!call r2update(bmat, ONE, v1, vlag, ONE, v2, w)
! Numerically, the update above does not guarantee BMAT(:, NPT+1 : NPT+N) to be symmetric.
call symmetrize(bmat(:, npt + 1:npt + n))

!====================!
!  Calculation ends  !
!====================!

! Postconditions
if (DEBUGGING) then
    call assert(size(bmat, 1) == n .and. size(bmat, 2) == npt + n, 'SIZE(BMAT)==[N, NPT+N]', srname)
    call assert(issymmetric(bmat(:, npt + 1:npt + n)), 'BMAT(:, NPT+1:NPT+N) is symmetric', srname)
    call assert(size(zmat, 1) == npt .and. size(zmat, 2) == npt - n - 1, 'SIZE(ZMAT) == [NPT, NPT-N-1]', srname)

    !! The following is too expensive to check.
    !if (n * npt <= 50) then
    !    xpt_test = xpt
    !    xpt_test(:, knew) = xpt(:, kopt) + d
    !    call assert(errh(bmat, zmat, xpt_test) <= tol .or. RP == kind(0.0), &
    !        & 'H = W^{-1} in (2.7) of the BOBYQA paper', srname)
    !end if
end if
end subroutine updateh


end module update_mod
