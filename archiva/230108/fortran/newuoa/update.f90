module update_mod
!--------------------------------------------------------------------------------------------------!
! This module provides subroutines concerning the update of [BMAT, ZMAT, IDZ] (represents H in the
! NEWUOA paper), [XPT, FVAL, KOPT, XOPT, FOPT], and [GQ, HQ, PQ] (the quadratic model) when
! XPT(:, KNEW) becomes XNEW = XOPT + D.
!
! Coded by Zaikun ZHANG (www.zhangzk.net) based on Powell's code and the NEWUOA paper.
!
! Dedicated to late Professor M. J. D. Powell FRS (1936--2015).
!
! Started: July 2020
!
! Last Modified: Monday, November 28, 2022 PM09:45:06
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: updatexf, updateq, tryqalt


contains


subroutine updatexf(knew, ximproved, f, xnew, kopt, fval, xpt, fopt, xopt)
!--------------------------------------------------------------------------------------------------!
! This subroutine updates [XPT, FVAL, KOPT, XOPT, FOPT] so that XPT(:, KNEW) is updated to XNEW.
!--------------------------------------------------------------------------------------------------!
! List of local arrays (including function-output arrays; likely to be stored on the stack): NONE
!--------------------------------------------------------------------------------------------------!

! Generic modules
use, non_intrinsic :: consts_mod, only : RP, IK, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert
use, non_intrinsic :: infnan_mod, only : is_finite, is_nan, is_posinf
use, non_intrinsic :: linalg_mod, only : norm

implicit none

! Inputs
integer(IK), intent(in) :: knew
real(RP), intent(in) :: f
real(RP), intent(in) :: xnew(:)  ! XNEW(N)

! In-outputs
integer(IK), intent(inout) :: kopt
logical, intent(in) :: ximproved
real(RP), intent(inout) :: fval(:)  ! FVAL(NPT)
real(RP), intent(inout) :: xpt(:, :)! XPT(N, NPT)

! Outputs
real(RP), intent(out) :: fopt
real(RP), intent(out) :: xopt(:)    ! XOPT(N)

! Local variables
character(len=*), parameter :: srname = 'UPDATEXF'
integer(IK) :: n
integer(IK) :: npt

! Sizes
n = int(size(xpt, 1), kind(n))
npt = int(size(xpt, 2), kind(npt))

! Preconditions
if (DEBUGGING) then
    call assert(n >= 1 .and. npt >= n + 2, 'N >= 1, NPT >= N + 2', srname)
    call assert(knew >= 0 .and. knew <= npt, '0 <= KNEW <= NPT', srname)
    call assert(kopt >= 1 .and. kopt <= npt, '1 <= KOPT <= NPT', srname)
    call assert(knew >= 1 .or. .not. ximproved, 'KNEW >= 1 unless X is not improved', srname)
    call assert(knew /= kopt .or. ximproved, 'KNEW /= KOPT unless X is improved', srname)
    call assert(size(xnew) == n .and. all(is_finite(xnew)), 'SIZE(XNEW) == N, XNEW is finite', srname)
    call assert(.not. (is_nan(f) .or. is_posinf(f)), 'F is not NaN or +Inf', srname)
    call assert(all(is_finite(xpt)), 'XPT is finite', srname)
    call assert(size(fval) == npt .and. .not. any(is_nan(fval) .or. is_posinf(fval)), &
        & 'SIZE(FVAL) == NPT and FVAL is not NaN or +Inf', srname)
    call assert(.not. any(fval < fval(kopt)), 'FVAL(KOPT) = MINVAL(FVAL)', srname)
    call assert(size(xopt) == n, 'SIZE(XOPT) == N', srname)
    ! N.B.: Do NOT test the value of FOPT or XOPT. Being INTENT(OUT), they are UNDEFINED up to here.
end if

!====================!
! Calculation starts !
!====================!

! Do essentially nothing when KNEW is 0. This can only happen after a trust-region step.
! We must set XOPT and FOPT. Otherwise, they are UNDEFINED because we declare them as INTENT(OUT).
if (knew <= 0) then  ! KNEW < 0 is impossible if the input is correct.
    xopt = xpt(:, kopt)
    fopt = fval(kopt)
    return
end if

xpt(:, knew) = xnew
fval(knew) = f

! KOPT is NOT identical to MINLOC(FVAL). Indeed, if FVAL(KNEW) = FVAL(KOPT) and KNEW < KOPT, then
! MINLOC(FVAL) = KNEW /= KOPT. Do not change KOPT in this case.
if (ximproved) then
    kopt = knew
end if

! Even if FVAL(KNEW) >= FVAL(KOPT) and KOPT remains unchanged, we still need to update XOPT and FOPT,
! because it may happen that KNEW = KOPT, so that XPT(:, KOPT) has been updated to XNEW.
xopt = xpt(:, kopt)
fopt = fval(kopt)

!====================!
!  Calculation ends  !
!====================!

! Postconditions
if (DEBUGGING) then
    call assert(size(xpt, 1) == n .and. size(xpt, 2) == npt .and. all(is_finite(xpt)), &
        & 'SIZE(XPT) == [N, NPT], XPT is finite', srname)
    call assert(kopt >= 1 .and. kopt <= npt, '1 <= KOPT <= NPT', srname)
    call assert(abs(fopt - fval(kopt)) <= 0, 'FOPT == FVAL(KOPT)', srname)
    call assert(size(xopt) == n .and. all(is_finite(xopt)), 'SIZE(XOPT) == N, XOPT is finite', srname)
    call assert(norm(xopt - xpt(:, kopt)) <= 0, 'XOPT == XPT(:, KOPT)', srname)
    call assert(.not. any(fval < fopt), '.NOT. ANY(FVAL < FOPT)', srname)
end if

end subroutine updatexf


subroutine updateq(idz, knew, bmat, moderr, xdrop, zmat, gq, hq, pq)
!--------------------------------------------------------------------------------------------------!
! This subroutine updates [GQ, HQ, PQ] when XPT(:, KNEW) changes from XDROP to XNEW.
! See Section 4 of the NEWUOA paper.
! N.B.: XNEW is encoded in [BMAT, ZMAT, IDZ]. We only need BMAT(:, KNEW) instead of the full matrix.
!--------------------------------------------------------------------------------------------------!
! List of local arrays (including function-output arrays; likely to be stored on the stack): NONE
!--------------------------------------------------------------------------------------------------!

! Generic modules
use, non_intrinsic :: consts_mod, only : RP, IK, ZERO, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert
use, non_intrinsic :: infnan_mod, only : is_finite
use, non_intrinsic :: linalg_mod, only : r1update, issymmetric
use, non_intrinsic :: powalg_mod, only : omega_col

implicit none

! Inputs
integer(IK), intent(in) :: idz
integer(IK), intent(in) :: knew
real(RP), intent(in) :: bmat(:, :) ! BMAT(N, NPT + N)
real(RP), intent(in) :: moderr
real(RP), intent(in) :: xdrop(:)  ! XDROP(N)
real(RP), intent(in) :: zmat(:, :)  ! ZMAT(NPT, NPT - N - 1)

! In-outputs
real(RP), intent(inout) :: gq(:)    ! GQ(N)
real(RP), intent(inout) :: hq(:, :) ! HQ(N, N)
real(RP), intent(inout) :: pq(:)    ! PQ(NPT)

! Local variables
character(len=*), parameter :: srname = 'UPDATEQ'
integer(IK) :: n
integer(IK) :: npt

! Sizes
n = int(size(gq), kind(n))
npt = int(size(pq), kind(npt))

! Preconditions
if (DEBUGGING) then
    call assert(n >= 1 .and. npt >= n + 2, 'N >= 1, NPT >= N + 2', srname)
    call assert(idz >= 1 .and. idz <= size(zmat, 2) + 1, '1 <= IDZ <= SIZE(ZMAT, 2) + 1', srname)
    call assert(knew >= 0 .and. knew <= npt, '0 <= KNEW <= NPT', srname)
    call assert(size(xdrop) == n .and. all(is_finite(xdrop)), 'SIZE(XDROP) == N, XDROP is finite', srname)
    call assert(size(bmat, 1) == n .and. size(bmat, 2) == npt + n, 'SIZE(BMAT)==[N, NPT+N]', srname)
    call assert(issymmetric(bmat(:, npt + 1:npt + n)), 'BMAT(:, NPT+1:NPT+N) is symmetric', srname)
    call assert(size(zmat, 1) == npt .and. size(zmat, 2) == npt - n - 1, &
        & 'SIZE(ZMAT) == [NPT, NPT - N - 1]', srname)
    call assert(size(hq, 1) == n .and. issymmetric(hq), 'HQ is an NxN symmetric matrix', srname)
end if

!====================!
! Calculation starts !
!====================!

! Do nothing when KNEW is 0. This can only happen after a trust-region step.
if (knew <= 0) then  ! KNEW < 0 is impossible if the input is correct.
    return
end if

! The unupdated model corresponding to [GQ, HQ, PQ] interpolates F at all points in XPT except for
! XNEW. The error is MODERR = [F(XNEW)-F(XOPT)] - [Q(XNEW)-Q(XOPT)].

! Absorb PQ(KNEW)*XDROP*XDROP^T into the explicit part of the Hessian.
! Implement R1UPDATE properly so that it ensures that HQ is symmetric.
call r1update(hq, pq(knew), xdrop)
pq(knew) = ZERO

! Update the implicit part of the Hessian.
pq = pq + moderr * omega_col(idz, zmat, knew)

! Update the gradient.
gq = gq + moderr * bmat(:, knew)

!====================!
!  Calculation ends  !
!====================!

! Postconditions
if (DEBUGGING) then
    call assert(size(gq) == n, 'SIZE(GQ) = N', srname)
    call assert(size(hq, 1) == n .and. issymmetric(hq), 'HQ is an NxN symmetric matrix', srname)
    call assert(size(pq) == npt, 'SIZE(PQ) = NPT', srname)
end if

end subroutine updateq


subroutine tryqalt(idz, fval, ratio, bmat, zmat, itest, gq, hq, pq)
!--------------------------------------------------------------------------------------------------!
! This subroutine tests whether to replace Q by the alternative model, namely the model that
! minimizes the F-norm of the Hessian subject to the interpolation conditions. It does the
! replacement if certain criteria are met (i.e., when ITEST = 3). See Section 8 of the NEWUOA paper.
! N.B.: Indeed, we only need BMAT(:, KNEW) instead of the entire matrix.
!--------------------------------------------------------------------------------------------------!
! List of local arrays (including function-output arrays; likely to be stored on the stack):
! REAL(RP) :: GALT(N)
! Size of local arrays: REAL(RP)*(N)
!--------------------------------------------------------------------------------------------------!

! Generic modules
use, non_intrinsic :: consts_mod, only : RP, IK, ZERO, TENTH, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert
use, non_intrinsic :: infnan_mod, only : is_nan, is_posinf
use, non_intrinsic :: linalg_mod, only : inprod, matprod, issymmetric
use, non_intrinsic :: powalg_mod, only : omega_mul

implicit none

! Inputs
integer(IK), intent(in) :: idz
real(RP), intent(in) :: fval(:)     ! FVAL(NPT)
real(RP), intent(in) :: ratio
real(RP), intent(in) :: bmat(:, :)  ! BMAT(N, NPT+N)
real(RP), intent(in) :: zmat(:, :)  ! ZMAT(NPT, NPT-N-1)

! In-output
integer(IK), intent(inout) :: itest
real(RP), intent(inout) :: gq(:)    ! GQ(N)
real(RP), intent(inout) :: hq(:, :) ! HQ(N, N)
real(RP), intent(inout) :: pq(:)    ! PQ(NPT)
! N.B.:
! GQ, HQ, and PQ should be INTENT(INOUT) instead of INTENT(OUT). According to the Fortran 2018
! standard, an INTENT(OUT) dummy argument becomes undefined on invocation of the procedure.
! Therefore, if the procedure does not define such an argument, its value becomes undefined,
! which is the case for HQ and PQ when ITEST < 3 at exit. In addition, the information in GQ is
! needed for definining ITEST, so it must be INTENT(INOUT).

! Local variables
character(len=*), parameter :: srname = 'TRYQALT'
integer(IK) :: n
integer(IK) :: npt
real(RP) :: galt(size(gq))

! Debugging variables
!real(RP) :: intp_tol

! Sizes
n = int(size(gq), kind(n))
npt = int(size(pq), kind(npt))

! Preconditions
if (DEBUGGING) then
    call assert(n >= 1 .and. npt >= n + 2, 'N >= 1, NPT >= N + 2', srname)
    call assert(idz >= 1 .and. idz <= size(zmat, 2) + 1, '1 <= IDZ <= SIZE(ZMAT, 2) + 1', srname)
    ! By the definition of RATIO in ratio.f90, RATIO cannot be NaN unless the actual reduction is
    ! NaN, which should NOT happen due to the moderated extreme barrier.
    call assert(.not. is_nan(ratio), 'RATIO is not NaN', srname)
    call assert(size(fval) == npt .and. .not. any(is_nan(fval) .or. is_posinf(fval)), &
        & 'SIZE(FVAL) == NPT and FVAL is not NaN or +Inf', srname)
    call assert(size(bmat, 1) == n .and. size(bmat, 2) == npt + n, 'SIZE(BMAT)==[N, NPT+N]', srname)
    call assert(issymmetric(bmat(:, npt + 1:npt + n)), 'BMAT(:, NPT+1:NPT+N) is symmetric', srname)
    call assert(size(zmat, 1) == npt .and. size(zmat, 2) == npt - n - 1, &
        & 'SIZE(ZMAT) == [NPT, NPT - N - 1]', srname)
    call assert(size(gq) == n, 'SIZE(GQ) = N', srname)
    call assert(size(hq, 1) == n .and. issymmetric(hq), 'HQ is an NxN symmetric matrix', srname)
    call assert(size(pq) == npt, 'SIZE(PQ) = NPT', srname)
    ! [GQ, HQ, PQ] cannot pass the following test if FVAL contains extremely large values.
    !intp_tol = max(1.0E-8_RP, min(1.0E-1_RP, 1.0E10_RP * real(size(pq), RP) * EPS))
    !call wassert(errquad(fval, xpt, gq, pq, hq) <= intp_tol, 'Q interpolates FVAL at XPT', srname)
end if

!====================!
! Calculation starts !
!====================!

! In the NEWUOA paper, Powell replaces Q with Q_alt when RATIO <= 0.01 and ||G_alt|| <= 0.1||GQ||
! hold for 3 consecutive times (eq(8.4)). But Powell's code compares ABS(RATIO) instead of RATIO
! with 0.01. Here we use RATIO, which is more efficient as observed in Zaikun ZHANG's PhD thesis
! (Section 3.3.2). Update (20221121): RATIO > 0.1 seems to work better.
!if (abs(ratio) > 1.0E-2_RP) then
!if (ratio > 1.0E-2_RP) then
!if (.false.) then
if (ratio > TENTH) then
    itest = 0
else
    galt = matprod(bmat(:, 1:npt), fval)
    if (inprod(gq, gq) < 1.0E2_RP * inprod(galt, galt)) then
        itest = 0
    else
        itest = itest + 1_IK
    end if
end if

! Replace Q with Q_alt when ITEST >= 3.
if (itest >= 3) then
    gq = galt
    hq = ZERO
    pq = omega_mul(idz, zmat, fval)
    itest = 0
end if

!====================!
!  Calculation ends  !
!====================!

! Postconditions
if (DEBUGGING) then
    call assert(size(gq) == n, 'SIZE(GQ) = N', srname)
    call assert(size(hq, 1) == n .and. issymmetric(hq), 'HQ is an NxN symmetric matrix', srname)
    call assert(size(pq) == npt, 'SIZE(PQ) = NPT', srname)
    ! [GQ, HQ, PQ] cannot pass the following test if FVAL contains extremely large values.
    !call wassert(errquad(fval, xpt, gq, pq, hq) <= intp_tol, 'QALT interpolates FVAL at XPT', srname)
end if

end subroutine tryqalt


end module update_mod
