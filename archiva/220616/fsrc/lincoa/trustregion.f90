module trustregion_mod
!--------------------------------------------------------------------------------------------------!
! This module provides subroutines concerning the trust-region calculations of LINCOA.
!
! Coded by Zaikun ZHANG (www.zhangzk.net) based on Powell's code and the paper
!
! M. J. D. Powell, On fast trust region methods for quadratic models with linear constraints,
! Math. Program. Comput., 7:237--267, 2015
!
! Dedicated to late Professor M. J. D. Powell FRS (1936--2015).
!
! Started: February 2022
!
! Last Modified: Tuesday, May 31, 2022 AM08:40:33
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: trstep


contains


subroutine trstep(amat, delta, gq, hq, pq, rescon, xpt, iact, nact, qfac, rfac, ngetact, snorm, s)

! Generic modules
use, non_intrinsic :: consts_mod, only : RP, IK, ONE, ZERO, HALF, EPS, TINYCV, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert, wassert
use, non_intrinsic :: infnan_mod, only : is_finite, is_nan
use, non_intrinsic :: linalg_mod, only : matprod, inprod, solve, isorth, istriu, issymmetric, trueloc
use, non_intrinsic :: powalg_mod, only : hess_mul

! Solver-specific modules
use, non_intrinsic :: getact_mod, only : getact

implicit none

! Inputs
real(RP), intent(in) :: amat(:, :)  ! AMAT(N, M)
real(RP), intent(in) :: delta
real(RP), intent(in) :: gq(:)  ! GQ(N)
real(RP), intent(in) :: hq(:, :)  ! HQ(N, N)
real(RP), intent(in) :: pq(:)  ! PQ(NPT)
real(RP), intent(in) :: rescon(:)  ! RESCON(M)
real(RP), intent(in) :: xpt(:, :)  ! XPT(N, NPT)

! In-outputs
integer(IK), intent(inout) :: iact(:)  ! IACT(M); Will be updated in GETACT
integer(IK), intent(inout) :: nact  ! Will be updated in GETACT
real(RP), intent(inout) :: qfac(:, :)  ! QFAC(N, N); Will be updated in GETACT
real(RP), intent(inout) :: rfac(:, :)  ! RFAC(N, N); Will be updated in GETACT

! Outputs
integer(IK), intent(out) :: ngetact
real(RP), intent(out) :: snorm
real(RP), intent(out) :: s(:)  ! S(N)

! Local variables
logical :: get_act
character(len=*), parameter :: srname = 'TRSTEP'
real(RP) :: d(size(gq))
real(RP) :: dw(size(gq))
real(RP) :: gw(size(gq))
real(RP) :: resact(size(amat, 2))
real(RP) :: resnew(size(amat, 2))
real(RP) :: tol
real(RP) :: g(size(gq))
real(RP) :: vlam(size(gq))
real(RP) :: frac(size(amat, 2)), ad(size(amat, 2)), restmp(size(amat, 2)), alpbd, alpha, alphm, alpht, &
& beta, ctest, &
&        dd, dg, dgd, ds, bstep, reduct, rhs, scaling, snsq, ss, temp
integer(IK) :: icount, jsav
integer(IK) :: m
integer(IK) :: n
integer(IK) :: npt

! Sizes.
m = int(size(amat, 2), kind(m))
n = int(size(gq), kind(n))
npt = int(size(pq), kind(npt))

! Preconditions
if (DEBUGGING) then
    call assert(m >= 0, 'M >= 0', srname)
    call assert(n >= 1, 'N >= 1', srname)
    call assert(npt >= n + 2, 'NPT >= N+2', srname)
    call assert(size(amat, 1) == n .and. size(amat, 2) == m, 'SIZE(AMAT) == [N, M]', srname)
    call assert(size(hq, 1) == n .and. issymmetric(hq), 'HQ is n-by-n and symmetric', srname)

    call assert(size(rescon) == m, 'SIZE(RESCON) == M', srname)
    call assert(size(xpt, 1) == n .and. size(xpt, 2) == npt, 'SIZE(XPT) == [N, NPT]', srname)
    call wassert(all(is_finite(xpt)), 'XPT is finite', srname)
    call assert(nact >= 0 .and. nact <= min(m, n), '0 <= NACT <= MIN(M, N)', srname)
    call assert(size(iact) == m, 'SIZE(IACT) == M', srname)
    call assert(all(iact(1:nact) >= 1 .and. iact(1:nact) <= m), '1 <= IACT <= M', srname)
    call assert(size(qfac, 1) == n .and. size(qfac, 2) == n, 'SIZE(QFAC) == [N, N]', srname)
    tol = max(1.0E-10_RP, min(1.0E-1_RP, 1.0E8_RP * EPS * real(n, RP)))
    call assert(isorth(qfac, tol), 'QFAC is orthogonal', srname)
    call assert(size(rfac, 1) == n .and. size(rfac, 2) == n, 'SIZE(RFAC) == [N, N]', srname)
    call assert(istriu(rfac), 'RFAC is upper triangular', srname)
    call assert(size(qfac, 1) == n .and. size(qfac, 2) == n, 'SIZE(QFAC) == [N, N]', srname)
end if

g = gq

!
!     N, NPT, M, AMAT, B, XPT, HQ, PQ, NACT, IACT, RESCON, QFAC and RFAC
!       are the same as the terms with these names in LINCOB. If RESCON(J)
!       is negative, then |RESCON(J)| must be no less than the trust region
!       radius, so that the J-th constraint can be ignored.
!     SNORM is set to the trust region radius DELTA initially. On the
!       return, however, it is the length of the calculated S, which is
!       set to zero if the constraints prohibit a long enough step.
!     S is the total calculated step so far from the trust region centre,
!       its final value being given by the sequence of CG iterations, which
!       terminate if the trust region boundary is reached.
!     G must be set on entry to the gradient of the quadratic model at the
!       trust region centre. It is used as working space, however, and is
!       always the gradient of the model at the current S.
!     RESNEW, RESACT, D, DW and GW are used for working space. A negative
!       value of RESNEW(J) indicates that the J-th constraint does not
!       restrict the CG steps of the current trust region calculation, a
!       zero value of RESNEW(J) indicates that the J-th constraint is active,
!       and otherwise RESNEW(J) is set to the greater of TINYCV and the actual
!       residual of the J-th constraint for the current S. RESACT holds
!       the residuals of the active constraints, which may be positive.
!       D is the search direction of each line search. DW is either another
!       search direction or the change in gradient along D.
!
!     Set some numbers for the conjugate gradient iterations.
!
ctest = 0.01_RP
!--------------------------------------------------------------------------------------------------!
! Zaikun 20220302: The following line is added so that SNORM is INTENT(OUT) rather than
! INTNT(INOUT). Is SNORM really the norm of step, or just DELTA??? Check also GETACT.
snorm = delta
!--------------------------------------------------------------------------------------------------!
snsq = snorm * snorm

! Set the initial elements of RESNEW, RESACT and S.
! 1. RESNEW(J) < 0 indicates that the J-th constraint does not restrict the CG steps of the current
! trust region calculation. In other words, RESCON >= DELTA.
! 2. RESNEW(J) = 0 indicates that J is an entry of IACT(1:NACT).
! 3. RESNEW(J) > 0 means that RESNEW(J) = max(B(J) - AMAT(:, J)^T*(XOPT+D), TINYCV).
! N.B.: The order of the following lines is important, as the later ones override the earlier.
resnew = rescon
resnew(trueloc(rescon >= 0)) = max(TINYCV, rescon(trueloc(rescon >= 0)))
resnew(trueloc(rescon >= snorm)) = -ONE
!!MATLAB:
!!resnew = rescon; resnew(rescon >= 0) = max(TINYCV, rescon(rescon >= 0)); resnew(rescon >= snorm) = -1;
resnew(iact(1:nact)) = ZERO
resact(1:nact) = rescon(iact(1:nact))

s = ZERO
ss = ZERO
reduct = ZERO
ngetact = 0
get_act = .true.  ! Better name?

icount = -1_IK  ! Artificial value. Not used. To entertain compilers. To be removed.

do while (.true.)  !TODO: prevent infinite cycling
    if (get_act) then
        ! GETACT picks the active set for the current S. It also sets DW to the vector closest to -G
        ! that is orthogonal to the normals of the active constraints. DW is scaled to have length
        ! 0.2*SNORM, as then a move of DW from S is allowed by the linear constraints.
        ngetact = ngetact + 1
        call getact(amat, g, snorm, iact, nact, qfac, resact, resnew, rfac, dw)
        dd = inprod(dw, dw)
        if (.not. dd > 0) then
            exit
        end if
        scaling = 0.2_RP * snorm / sqrt(dd)
        dw = scaling * dw

        ! If the modulus of the residual of an active constraint is substantial, then set D to the
        ! shortest move from S to the boundaries of the active constraints.
        bstep = ZERO
        if (any(resact(1:nact) > 1.0E-4_RP * snorm)) then
            ! N.B.: We prefer `ANY(X > Y)` to `MAXVAL(X) > Y`, as Fortran standards do not specify
            ! MAXVAL(X) when X contains NaN, and MATLAB/Python/R/Julia behave differently in this
            ! respect. Moreover, MATLAB defines max(X) = [] if X == [], differing from mathematics
            ! and other languages.
            vlam(1:nact) = solve(transpose(rfac(1:nact, 1:nact)), resact(1:nact))
            !!MATLAB: vlam(1:nact) = rfac(1:nact, 1:nact)' \ resact(1:nact)
            d = matprod(qfac(:, 1:nact), vlam(1:nact))

            ! The vector D that has just been calculated is also the shortest move from S+DW to the
            ! boundaries of the active constraints. Set BSTEP to the greatest steplength of this
            ! move that satisfies the trust region bound.
            ds = inprod(d, s + dw)
            dd = sum(d**2)
            rhs = snsq - sum((s + dw)**2)  ! Calculation changed

            if (rhs > 0) then
                temp = sqrt(ds * ds + dd * rhs)
                if (ds <= 0) then
                    ! Zaikun 20210925: What if we are at the first iteration? BLEN = DELTA/|D|? See TRSAPP.F90 of NEWUOA.
                    bstep = (temp - ds) / dd
                else
                    bstep = rhs / (temp + ds)
                end if
            end if

            ! Reduce BSTEP if necessary so that the move along D also satisfies the linear constraints.
            ad = -ONE
            ad(trueloc(resnew > 0)) = matprod(d, amat(:, trueloc(resnew > 0)))
            frac = ONE
            restmp(trueloc(ad > 0)) = resnew(trueloc(ad > 0)) - matprod(dw, amat(:, trueloc(ad > 0)))
            frac(trueloc(ad > 0)) = restmp(trueloc(ad > 0)) / ad(trueloc(ad > 0))
            bstep = minval([bstep, ONE, frac])  ! BSTEP = MINVAL([BSTEP, ONE, FRAC(TRUELOC(AD>0))])
        end if

        ! Set the next direction for seeking a reduction in the model function subject to the trust
        ! region bound and the linear constraints.
        if (bstep > 0) then
            d = dw + bstep * d
            icount = nact - 1
        else
            d = dw
            icount = nact
        end if
        alpbd = ONE
    end if

    ! Set ALPHA to the steplength from S along D to the trust region boundary. Return if the first
    ! derivative term of this step is sufficiently small or if no further progress is possible.
    icount = icount + 1
    rhs = snsq - ss
    if (rhs <= 0) exit
    dg = inprod(d, g)
    ds = inprod(d, s)
    dd = inprod(d, d)
    if (dg >= 0) exit
    temp = sqrt(rhs * dd + ds * ds)
    if (ds <= 0) then
        alpha = (temp - ds) / dd
    else
        alpha = rhs / (temp + ds)
    end if
    if (-alpha * dg <= ctest * reduct) exit

    dw = hess_mul(d, xpt, pq, hq)

    ! Set DGD to the curvature of the model along D. Then reduce ALPHA if necessary to the value
    ! that minimizes the model.
    dgd = inprod(d, dw)
    alpht = alpha
    if (dg + alpha * dgd > 0) then
        alpha = -dg / dgd
    end if

    ! Make a further reduction in ALPHA if necessary to preserve feasibility, and put some scalar
    ! products of D with constraint gradients in W.
    alphm = alpha
    ad = -ONE
    ad(trueloc(resnew > 0)) = matprod(d, amat(:, trueloc(resnew > 0)))
    frac = alpha
    frac(trueloc(ad > 0)) = resnew(trueloc(ad > 0)) / ad(trueloc(ad > 0))
    frac(trueloc(is_nan(frac))) = alpha
    jsav = 0_IK
    if (any(frac < alpha)) then
        jsav = int(minloc(frac, dim=1), IK)
        alpha = frac(jsav)
    end if
    !----------------------------------------------------------------------------------------------!
    ! Alternatively, JSAV and ALPHA can be calculated as below.
    !JSAV = INT(MINLOC([ALPHA, FRAC], DIM=1), IK) - 1_IK
    !ALPHA = MINVAL([ALPHA, FRAC])  ! This line cannot be exchanged with the last.
    ! We prefer our implementation as the code is more explicit; in addition, it is more flexible:
    ! we can change the condition ANY(FRAC < ALPHA) to ANY(FRAC < (1 - EPS) * ALPHA) or
    ! ANY(FRAC < (1 + EPS) * ALPHA), depending on whether we believe a false positive or a false
    ! negative of JSAV > 0 is more harmful.
    !----------------------------------------------------------------------------------------------!

    alpha = min(max(alpha, alpbd), alphm)
    if (icount == nact) alpha = min(alpha, ONE)

    ! Update S, G, RESNEW, RESACT and REDUCT.
    s = s + alpha * d
    ss = sum(s**2)
    g = g + alpha * dw
    restmp = resnew - alpha * ad  ! Only RESTMP(TRUELOC(RESNEW > 0)) is needed.
    resnew(trueloc(resnew > 0)) = max(TINYCV, restmp(trueloc(resnew > 0)))
    !!MATLAB: mask = (resnew > 0); resnew(mask) = max(TINYCV, resnew(mask) - alpha * ad(mask));
    if (icount == nact) then
        resact(1:nact) = (ONE - bstep) * resact(1:nact)
    end if
    reduct = reduct - alpha * (dg + HALF * alpha * dgd)

    ! Test for termination. Branch to a new loop if there is a new active constraint and if the
    ! distance from S to the trust region boundary is at least 0.2*SNORM.

    ! Zaikun 2019-08-29: the code can encounter infinite cycling due to NaN values. Exit when
    ! NGETACT is large or NaN is detected.
    ! Caution: 1. MIN accepts only data with the same KIND; 2. Integer overflow.
    if (ngetact > min(10000, 100 * int(m + 1) * int(n)) .or.  &
    & alpha /= alpha .or. alpht /= alpht .or. &
    & alphm /= alphm .or. dgd /= dgd .or. dg /= dg .or. &
    & ss /= ss .or. snsq /= snsq .or. reduct /= reduct) then
        exit
    end if
    if (alpha == alpht) exit
    temp = -alphm * (dg + HALF * alphm * dgd)
    if (temp <= ctest * reduct) exit
    if (jsav > 0) then
        if (ss <= 0.64_RP * snsq) then
            get_act = .true.
            cycle
        else
            exit
        end if
    end if
    if (icount == n) exit

    ! Calculate the next search direction, which is conjugate to the previous one if ICOUNT /= NACT.
    ! N.B.: NACT < 0 is impossible unless GETACT is buggy; NACT = 0 can happen, particularly if
    ! there is no constraint. In theory, the code for the second case below covers the first as well.
    if (nact <= 0) then
        gw = g
    else
        gw = matprod(qfac(:, nact + 1:n), matprod(g, qfac(:, nact + 1:n)))
        !!MATLAB: gw = qfac(:, nact+1:n) * (g' * qfac(:, nact+1:n))';
    end if

    if (icount == nact) then
        beta = ZERO
    else
        beta = inprod(gw, dw) / dgd
    end if
    d = -gw + beta * d
    alpbd = ZERO
    get_act = .false.
end do

! Return from the subroutine.
snorm = ZERO
if (reduct > 0) snorm = sqrt(ss)

if (DEBUGGING) then
    call assert(nact >= 0 .and. nact <= min(m, n), '0 <= NACT <= MIN(M, N)', srname)
    call assert(size(qfac, 1) == n .and. size(qfac, 2) == n, 'SIZE(QFAC) == [N, N]', srname)
    call assert(isorth(qfac, tol), 'QFAC is orthogonal', srname)
    call assert(size(rfac, 1) == n .and. size(rfac, 2) == n, 'SIZE(RFAC) == [N, N]', srname)
    call assert(istriu(rfac), 'RFAC is upper triangular', srname)
end if

end subroutine trstep


end module trustregion_mod

!--------------------------------------------------------------------------------------------------!
! Zaikun 20220417:
! For GW, the schemes below work evidently worse than the one above in a test on 20220417. Why?
!-----------------------------------------------------------------------!
! VERSION 1:
!!gw = g - matprod(qfac(:, 1:nact), matprod(g, qfac(:, 1:nact)))
!-----------------------------------------------------------------------!
! VERSION 2:
!!if (2 * nact < n) then
!!    gw = g - matprod(qfac(:, 1:nact), matprod(g, qfac(:, 1:nact)))
!!else
!!    gw = matprod(qfac(:, nact + 1:n), matprod(g, qfac(:, nact + 1:n)))
!!end if
!-----------------------------------------------------------------------!
!--------------------------------------------------------------------------------------------------!
