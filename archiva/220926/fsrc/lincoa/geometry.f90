module geometry_mod
!--------------------------------------------------------------------------------------------------!
! This module contains subroutines concerning the geometry-improving of the interpolation set XPT.
!
! Coded by Zaikun ZHANG (www.zhangzk.net) based on Powell's code.
!
! Dedicated to late Professor M. J. D. Powell FRS (1936--2015).
!
! Started: February 2022
!
! Last Modified: Sunday, October 23, 2022 AM09:03:37
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: setdrop_tr, geostep


contains


function setdrop_tr(idz, kopt, freduced, bmat, d, xpt, zmat) result(knew)
!--------------------------------------------------------------------------------------------------!
! This subroutine sets KNEW to the index of the interpolation point to be deleted AFTER A TRUST
! REGION STEP. KNEW will be set in a way ensuring that the geometry of XPT is "optimal" after
! XPT(:, KNEW) is replaced by XNEW = XOPT + D, where D is the trust-region step.
! N.B.:
! It is tempting to take the function value into consideration when defining KNEW, for example,
! set KNEW so that FVAL(KNEW) = MAX(FVAL) as long as F(XNEW) < MAX(FVAL), unless there is a better
! choice. However, this is not a good idea, because the definition of KNEW should benefit the
! quality of the model that interpolates f at XPT. A set of points with low function values is not
! necessarily a good interpolation set. In contrast, a good interpolation set needs to include
! points with relatively high function values; otherwise, the interpolant will unlikely reflect the
! landscape of the function sufficiently.
!--------------------------------------------------------------------------------------------------!

! Generic modules
use, non_intrinsic :: consts_mod, only : RP, IK, ONE, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert
use, non_intrinsic :: infnan_mod, only : is_nan, is_finite
use, non_intrinsic :: linalg_mod, only : issymmetric
use, non_intrinsic :: powalg_mod, only : calden
implicit none

! Inputs
integer(IK), intent(in) :: idz
integer(IK), intent(in) :: kopt
logical, intent(in) :: freduced
real(RP), intent(in) :: bmat(:, :)  ! BMAT(N, NPT + N)
real(RP), intent(in) :: d(:)
real(RP), intent(in) :: xpt(:, :)   ! XPT(N, NPT)
real(RP), intent(in) :: zmat(:, :)  ! ZMAT(NPT, NPT - N - 1)

! Outputs
integer(IK) :: knew

! Local variables
character(len=*), parameter :: srname = 'SETDROP_TR'
integer(IK) :: n
integer(IK) :: npt
real(RP) :: denabs(size(xpt, 2))
real(RP) :: distsq(size(xpt, 2))
real(RP) :: score(size(xpt, 2))
real(RP) :: weight(size(xpt, 2))

! Sizes
n = int(size(xpt, 1), kind(npt))
npt = int(size(xpt, 2), kind(npt))

! Preconditions
if (DEBUGGING) then
    call assert(n >= 1 .and. npt >= n + 2, 'N >= 1, NPT >= N + 2', srname)
    call assert(idz >= 1 .and. idz <= size(zmat, 2) + 1, '1 <= IDZ <= SIZE(ZMAT, 2) + 1', srname)
    call assert(kopt >= 1 .and. kopt <= npt, '1 <= KOPT <= NPT', srname)
    call assert(size(d) == n .and. all(is_finite(d)), 'SIZE(D) == N, D is finite', srname)
    call assert(all(is_finite(xpt)), 'XPT is finite', srname)
    call assert(size(bmat, 1) == n .and. size(bmat, 2) == npt + n, 'SIZE(BMAT)==[N, NPT+N]', srname)
    call assert(issymmetric(bmat(:, npt + 1:npt + n)), 'BMAT(:, NPT+1:NPT+N) is symmetric', srname)
    call assert(size(zmat, 1) == npt .and. size(zmat, 2) == npt - n - 1, &
        & 'SIZE(ZMAT) == [NPT, NPT - N - 1]', srname)
end if

!====================!
! Calculation starts !
!====================!

! Calculate the distance squares between the interpolation points and the "optimal point". When
! identifying the optimal point, as suggested in (7.5) of the LINCOA paper, it is reasonable to
! take into account the new trust-region trial point XPT(:, KOPT) + D, which will become the optimal
! point in the next interpolation if FREDUCED is TRUE. Strangely, considering this new point does
! not always lead to a better performance of LINCOA. Here, we choose not to check FREDUCED, as
! the performance of LINCOA is better in this way.
! HOWEVER, THIS MAY WELL CHANGE IF THE OTHER PARTS OF LINCOA ARE IMPLEMENTED DIFFERENTLY.
!if (freduced) then
!    distsq = sum((xpt - spread(xpt(:, kopt) + d, dim=2, ncopies=npt))**2, dim=1)
!    !!MATLAB: distsq = sum((xpt - (xpt(:, kopt) + d)).^2)  % d should be a column!! Implicit expansion
!else
!    distsq = sum((xpt - spread(xpt(:, kopt), dim=2, ncopies=npt))**2, dim=1)
!    !!MATLAB: distsq = sum((xpt - xpt(:, kopt)).^2)  % Implicit expansion
!end if
distsq = sum((xpt - spread(xpt(:, kopt), dim=2, ncopies=npt))**2, dim=1)

weight = distsq**2
!--------------------------------------------------------------------------------------------------!
! Other possible definitions of WEIGHT.
!weight = (distsq / delta**2)**2   ! Works the same as DISTSQ**2 (as it should be).
!weight = distsq**1.5_RP
!weight = distsq**2.5_RP
!weight = (distsq / delta**2)**3
!weight = max(1.0_RP, distsq / rho**2)**2
!weight = max(1.0_RP, distsq / rho**2)**3
!weight = max(1.0_RP, distsq / delta**2)**2
!weight = max(1.0_RP, distsq / delta**2)**3
!--------------------------------------------------------------------------------------------------!

denabs = abs(calden(kopt, bmat, d, xpt, zmat, idz))
score = weight * denabs

! If the new F is not better than FVAL(KOPT), we set SCORE(KOPT) = -1 to avoid KNEW = KOPT.
! This is not really needed if DISTSQ does not take FREDUCED into account and WEIGHT is defined to
! DISTSQ to some power, in which case SCORE(KOPT) = 0. We keep the code for robustness.
if (.not. freduced) then
    score(kopt) = -ONE
end if

if (any(score > 0)) then
!if (any(score > 1) .or. any(score > 0) .and. freduced) then
    ! SCORE(K) is NaN implies DENABS(K) is NaN, but we want DENABS to be big. So we exclude such K.
    knew = int(maxloc(score, mask=(.not. is_nan(score)), dim=1), IK)
    !!MATLAB: [~, knew] = max(score, [], 'omitnan');
else if (freduced) then
    ! Powell's code does not handle this case, leaving KNEW = 0 and leading to a segfault.
    knew = int(maxloc(distsq, dim=1), IK)
else
    knew = 0_IK
end if

!====================!
!  Calculation ends  !
!====================!

! Postconditions
if (DEBUGGING) then
    call assert(knew >= 0 .and. knew <= npt, '0 <= KNEW <= NPT', srname)
    call assert(knew /= kopt .or. freduced, 'KNEW /= KOPT', srname)
    call assert(knew >= 1 .or. .not. freduced, 'KNEW >= 1 unless FREDUCED = FALSE', srname)
    ! KNEW >= 1 when FREDUCED = TRUE unless NaN occurs in DISTSQ, which should not happen if the
    ! starting point does not contain NaN and the trust-region/geometry steps never contain NaN.
end if
end function setdrop_tr


subroutine geostep(iact, idz, knew, kopt, nact, amat, bmat, delbar, qfac, rescon, xpt, zmat, feasible, s)
!--------------------------------------------------------------------------------------------------!
! This subroutine finds a step S hat intends to improve the geometry of the interpolation set when
! XPT(:, KNEW) is changed to XOPT + S, where XOPT = XPT(:, KOPT).
!
! S is chosen to provide a relatively large value of the modulus of the denominator SIGMA in the
! updating formula (4.11) of the NEWUOA paper (in theory, SIGMA is positive, yet this may not hold
! numerically due to rounding errors; in the code, SIGMA is represented by DEN and its modulus by
! DENABS). This is done by solving
!
!   |LFUNC(XOPT + S)|, subject to |S| <= DELBAR,
!
! because SIGMA >= |LFUNC(XOPT + S)|^2 according to (4.12) of the NEWUOA paper. We do not solve this
! problem exactly, but calculate three approximate solutions as follows and then choose S from them.
! 1. The step that maximizes |LFUNC| within the trust region on the lines through XOPT and other
! interpolation points.
! 2. The gradient step that maximizes |LFUNC| within the trust region.
! 3. A projected gradient step that maximizes |LFUNC| within the trust region, the projection being
! made onto the orthogonal complement of the space spanned by the active gradients.
!
! We select S from these three steps by the following criteria.
! 1. First, set S to either the first or second step, whichever renders a larger value of |SIGMA|.
! 2. Second, override S by the third step if the latter provides a |SIGMA| that is not small
! compared with the above one, while leading to a good feasibility.
!
! N.B.:
! 1. The linear constraints are NOT considered in the calculation of the first two steps.
! 2. For the selection of S, Powell adopted a different set of criteria as follows.
! 2.1. First, set S to either the first or second step, whichever renders a larger value of |LFUNC|.
! 2.2. Second, override S by the third step if the latter provides a |LFUNC| that is not small
! compared with the above one, while being either feasible or with a constraint violation that is at
! least 0.2*DELBAR.
! 2.3. If S is not feasible and its constraint violation is less than 0.2*DELBAR, then it is
! perturbed so that the constraint violation becomes 0.2*DELBAR or more.
! 3. Powell required the positive constraint violation to be at least 0.2*DELBAR in order to keep
! the interpolation points apart. In our criteria specified above, we have removed this requirement
! as we believe that it is implied by the maximization of |LFUNC|. Our criteria works well in tests.
! 4. In terms of flops, our criteria are more expensive than Powell's due to the evaluation of SIGMA.
! In derivative-free optimization, we are willing to save function evaluations at the cost of flops.
! 5. The geometry step of BOBYQA is calculated in a fashion similar to this subroutine: first obtain
! a step by maximizing |LFUNC| along the lines through XOPT and other interpolation points, then
! find the Cauchy step, which maximizes |LFUNC| in the 1D space spanned by the gradient of LFUNC,
! and finally select the geometry step from the aforesaid steps according to the value of |LFUNC| or
! SIGMA. Yet there still exist three major differences between geometry steps of BOBYQA and LINCOA.
! 5.1. The geometry step of BOBYQA is calculated subject to the bound constraints, and the computed
! step is always feasible; the geometry step of LINCOA may violate the linear constraints.
! 5.2. BOBYQA uses an estimated value of SIGMA (see (3.11) of the BOBYQA paper) to select the step
! along the lines through XOPT and other interpolation points; LINCOA uses |LFUNC|. According to
! a test on 20220529, using the estimated SIGMA does not improve the performance of LINCOA.
! 5.3. LINCOA tries a projected gradient step and prefers this step when its quality is reasonable.
! BOBYQA does not compute such a step.
! Additionally, we observe in BOBYQA that it is beneficial for bound constrained problems (but NOT
! unconstrained ones) to take the Cauchy step only in the late stage of the algorithm, e.g., when
! DELBAR <= 1.0E-2. Similar phenomenon is not observed in LINCOA, where it worsens the performance
! of the algorithm to skip the gradient step or the projected gradient step even in the early stage.
!
! AMAT, XPT, NACT, IACT, RESCON, QFAC, KOPT are the same as the terms with these names in subroutine
! LINCOB. KNEW is the index of the interpolation point that is going to be moved. DELBAR is the
! restriction on the length of S, which is never greater than the current trust region radius DELTA.
!--------------------------------------------------------------------------------------------------!

! Generic modules
use, non_intrinsic :: consts_mod, only : RP, IK, ZERO, ONE, TWO, TEN, TENTH, HUGENUM, EPS, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert, wassert
use, non_intrinsic :: infnan_mod, only : is_nan, is_finite
use, non_intrinsic :: linalg_mod, only : matprod, inprod, isorth, maximum, trueloc, norm
use, non_intrinsic :: powalg_mod, only : hess_mul, omega_col, calden

implicit none

! Inputs
integer(IK), intent(in) :: iact(:)  ! IACT(M)
integer(IK), intent(in) :: idz
integer(IK), intent(in) :: knew
integer(IK), intent(in) :: kopt
integer(IK), intent(in) :: nact
real(RP), intent(in) :: amat(:, :)  ! AMAT(N, M)
real(RP), intent(in) :: bmat(:, :)  ! BMAT(N, NPT+N)
real(RP), intent(in) :: delbar
real(RP), intent(in) :: qfac(:, :)  ! QFAC(N, N)
real(RP), intent(in) :: rescon(:)  ! RESCON(M)
real(RP), intent(in) :: xpt(:, :)  ! XPT(N, NPT)
real(RP), intent(in) :: zmat(:, :)  ! ZMAT(NPT, NPT-N-1)

! Outputs
logical, intent(out) :: feasible
real(RP), intent(out) :: s(:)  ! S(N)

! Local variables
character(len=*), parameter :: srname = 'GEOSTEP'
integer(IK) :: k
integer(IK) :: m
integer(IK) :: n
integer(IK) :: npt
integer(IK) :: rstat(size(amat, 2))
logical :: take_pgstp
real(RP) :: cstrv
real(RP) :: cvtol
real(RP) :: dderiv(size(xpt, 2))
real(RP) :: den(size(xpt, 2))
real(RP) :: denabs
real(RP) :: distsq(size(xpt, 2))
real(RP) :: glag(size(xpt, 1))
real(RP) :: gstp(size(xpt, 1))
real(RP) :: normg
real(RP) :: pglag(size(xpt, 1))
real(RP) :: pgstp(size(xpt, 1))
real(RP) :: pqlag(size(xpt, 2))
real(RP) :: stplen(size(xpt, 2))
real(RP) :: tol
real(RP) :: vlagabs(size(xpt, 2))
real(RP) :: xopt(size(xpt, 1))

! Sizes.
m = int(size(amat, 2), kind(m))
n = int(size(xpt, 1), kind(n))
npt = int(size(xpt, 2), kind(npt))

! Preconditions
if (DEBUGGING) then
    call assert(m >= 0, 'M >= 0', srname)
    call assert(n >= 1, 'N >= 1', srname)
    call assert(npt >= n + 2, 'NPT >= N+2', srname)
    call assert(nact >= 0 .and. nact <= min(m, n), '0 <= NACT <= MIN(M, N)', srname)
    call assert(size(iact) == m, 'SIZE(IACT) == M', srname)
    call assert(all(iact(1:nact) >= 1 .and. iact(1:nact) <= m), '1 <= IACT <= M', srname)
    call assert(idz >= 1 .and. idz <= npt - n, '1 <= IDZ <= NPT-N', srname)
    call assert(knew >= 1 .and. knew <= npt, '1 <= KNEW <= NPT', srname)
    call assert(kopt >= 1 .and. kopt <= npt, '1 <= KOPT <= NPT', srname)
    call assert(knew /= kopt, 'KNEW /= KOPT', srname)
    call assert(size(amat, 1) == n .and. size(amat, 2) == m, 'SIZE(AMAT) == [N, M]', srname)
    call assert(size(bmat, 1) == n .and. size(bmat, 2) == npt + n, 'SIZE(BMAT) == [N, NPT+N]', srname)
    call assert(delbar > 0, 'DELBAR> 0', srname)
    call assert(size(qfac, 1) == n .and. size(qfac, 2) == n, 'SIZE(QFAC) == [N, N]', srname)
    tol = max(1.0E-10_RP, min(1.0E-1_RP, 1.0E8_RP * EPS * real(n, RP)))
    call assert(isorth(qfac, tol), 'QFAC is orthogonal', srname)
    call assert(size(qfac, 1) == n .and. size(qfac, 2) == n, 'SIZE(QFAC) == [N, N]', srname)
    call assert(size(rescon) == m, 'SIZE(RESCON) == M', srname)
    call wassert(all(is_finite(xpt)), 'XPT is finite', srname)
    call assert(size(zmat, 1) == npt .and. size(zmat, 2) == npt - n - 1, 'SIZE(ZMAT) == [NPT, NPT- N-1]', srname)
end if

!====================!
! Calculation starts !
!====================!

! Read XOPT.
xopt = xpt(:, kopt)

! PQLAG contains the leading NPT elements of the KNEW-th column of H, and it provides the second
! derivative parameters of LFUNC. Set GLAG to the gradient of LFUNC at the trust region centre.
pqlag = omega_col(idz, zmat, knew)
glag = bmat(:, knew) + hess_mul(xopt, xpt, pqlag)

! Maximize |LFUNC| within the trust region on the lines through XOPT and other interpolation points,
! without considering the linear constraints. In the following, VLAGABS(K) is set to the maximum of
! |PHI_K(t)| subject to the trust-region constraint with PHI_K(t) = LFUNC((1-t)*XOPT + t*XPT(:, K)).
dderiv = matprod(glag, xpt) - inprod(glag, xopt) ! The derivatives PHI_K'(0).
distsq = sum((xpt - spread(xopt, dim=2, ncopies=npt))**2, dim=1)
! Set DISTSQ(KOPT) to a positive artificial value. Otherwise, the calculation of STPLEN will raise a
! floating point exception. This artificial value will not be used.
distsq(kopt) = HUGENUM
! For each K /= KNEW, |PHI_K(t)| is maximized by STPLEN(K), the maximum being VLAGABS(K). Note that
! PHI_K(t) is a quadratic function with PHI_K'(0) = DDERIV(K) and PHI_K(0) = 0 = PHI_K(1).
stplen = -delbar / sqrt(distsq)
vlagabs = abs(stplen * (ONE - stplen) * dderiv)
! The maximization of |PHI_K(t)| is as follows. Note that PHI_K(t) is a quadratic function with
! PHI_K'(0) = DDERIV(K), PHI_K(0) = 0, and PHI_K(1) = 1.
if (dderiv(knew) * (dderiv(knew) - ONE) < 0) then
    stplen(knew) = -stplen(knew)
end if
vlagabs(knew) = abs(stplen(knew) * dderiv(knew)) + stplen(knew)**2 * abs(dderiv(knew) - ONE)
! It does not make sense to consider "the straight line through XOPT and XPT(:, KOPT)". Thus we set
! VLAGABS(KOPT) to -1 so that KOPT is skipped when we maximize VLAGABS.
vlagabs(kopt) = -ONE
! Find K so that VLAGABS(K) is maximized. We define K in a way slightly different from Powell's
! code, which sets K to MAXLOC(VLAGABS) by comparing the entries of VLAGABS sequentially.
! 1. If VLAGABS contains only NaN, which can happen, Powell's code leaves K uninitialized.
! 2. If VLAGABS(KNEW) = MAXVAL(VLAGABS) = VLAGABS(K) and K < KNEW, Powell's code does not set K=KNEW.
k = knew
if (any(vlagabs > vlagabs(knew))) then
    k = maxloc(vlagabs, mask=(.not. is_nan(vlagabs)), dim=1)
    !!MATLAB: [~, k] = max(vlagabs, [], 'omitnan');
end if
! Set S to the step corresponding to VLAGABS(K), and calculate DENABS for it.
s = stplen(k) * (xpt(:, k) - xopt)
den = calden(kopt, bmat, s, xpt, zmat, idz)  ! Indeed, only DEN(KNEW) is needed.
denabs = abs(den(knew))

! Replace S with a steepest ascent step from XOPT if the latter provides a larger value of DENABS.
normg = sqrt(sum(glag**2))
if (normg > 0) then
    gstp = (delbar / normg) * glag
    if (inprod(gstp, hess_mul(gstp, xpt, pqlag)) < 0) then  ! <GSTP, HESS_LAG*GSTP> is negative
        gstp = -gstp
    end if
    den = calden(kopt, bmat, gstp, xpt, zmat, idz)  ! Indeed, only DEN(KNEW) is needed.
    if (abs(den(knew)) > denabs .or. is_nan(denabs)) then
        denabs = abs(den(knew))
        s = gstp
    end if
end if

! Set FEASIBLE for the calculated S. RSTAT identifies the constraints that need evaluation. RSTAT(J)
! is -1, 0, or 1 respectively means constraint J is irrelevant, active, or inactive and relevant.
! Do NOT change the order of the lines that set RSTAT, as the later lines override the earlier.
rstat = 1_IK
rstat(trueloc(abs(rescon) >= delbar)) = -1_IK
rstat(iact(1:nact)) = 0_IK
cstrv = maximum([ZERO, matprod(s, amat(:, trueloc(rstat >= 0))) - rescon(trueloc(rstat >= 0))])
feasible = (cstrv <= 0)

! If NACT <= 0 or NACT >= N, the calculation has finished. Otherwise, define PGSTP by maximizing
! |LFUNC| within the trust region from XOPT along the projection of GLAG onto the column space of
! QFAC(:, NACT+1:N), i.e., the orthogonal complement of the space spanned by the active gradients.
! In precise arithmetic, moving along PGSTP does not change the values of the active constraints.
! This projected gradient step is preferred and will override S if it renders a denominator not too
! small and leads to good feasibility. **This strategy is critical for the performance of LINCOA.**
pglag = matprod(qfac(:, nact + 1:n), matprod(glag, qfac(:, nact + 1:n)))
!!MATLAB: pglag = qfac(:, nact+1:n) * (glag' * qfac(:, nact+1:n))';
normg = sqrt(sum(pglag**2))
if (nact > 0 .and. nact < n .and. normg > 0) then
    pgstp = (delbar / normg) * pglag
    if (inprod(pgstp, hess_mul(pgstp, xpt, pqlag)) < 0) then  ! <PGSTP, HESS_LAG*PGSTP> is negative.
        pgstp = -pgstp
    end if

    ! Decide whether to replace S with PGSTP and set FEASIBLE accordingly.
    cstrv = maximum([ZERO, matprod(pgstp, amat(:, trueloc(rstat == 1))) - rescon(trueloc(rstat == 1))])
    ! The purpose of CVTOL below is to provide a check on feasibility that includes a tolerance for
    ! contributions from computer rounding errors. Note that CVTOL equals 0 in precise arithmetic.
    cvtol = min(0.01_RP * sqrt(sum(pgstp**2)), TEN * norm(matprod(pgstp, amat(:, iact(1:nact))), 'inf'))
    take_pgstp = .false.
    if (cstrv <= cvtol) then
        den = calden(kopt, bmat, pgstp, xpt, zmat, idz)  ! Indeed, only DEN(KNEW) is needed.
        take_pgstp = (abs(den(knew)) > TENTH * denabs)
    end if
    if (take_pgstp .or. is_nan(denabs)) then
        s = pgstp
        feasible = (cstrv <= cvtol)
    end if
end if

! In case S contains NaN entries, set them to zero.
s(trueloc(is_nan(s))) = ZERO

!====================!
!  Calculation ends  !
!====================!

! Postconditions
if (DEBUGGING) then
    call assert(size(s) == n, 'SIZE(S) == N', srname)
    call assert(all(is_finite(s)), 'S is finite', srname)
    ! In theory, |S| <= DELBAR, which may be false due to rounding, but |S| > 2*DELBAR is unlikely.
    call assert(norm(s) <= TWO * delbar, '|S| <= 2*DELBAR', srname)
end if

end subroutine geostep


end module geometry_mod
