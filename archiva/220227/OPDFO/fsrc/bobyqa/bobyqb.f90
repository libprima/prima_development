subroutine bobyqb(n, npt, x, xl, xu, rhobeg, rhoend, iprint, &
    & maxfun, xbase, xpt, fval, xopt, gopt, hq, pq, bmat, zmat, ndim, &
    & sl, su, xnew, xalt, d, vlag, w, f, info, ftarget)

use, non_intrinsic :: dirty_temporary_mod4powell_mod
implicit real(kind(0.0D0)) (a - h, o - z)
implicit integer(i - n)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
dimension x(*), xl(*), xu(*), xbase(*), xpt(npt, *), fval(*), &
& xopt(*), gopt(*), hq(*), pq(*), bmat(ndim, *), zmat(npt, *), &
& sl(*), su(*), xnew(*), xalt(*), d(*), vlag(*), w(*)
!
!     The arguments N, NPT, X, XL, XU, RHOBEG, RHOEND, IPRINT and MAXFUN
!       are identical to the corresponding arguments in SUBROUTINE BOBYQA.
!     XBASE holds a shift of origin that should reduce the contributions
!       from rounding errors to values of the model and Lagrange functions.
!     XPT is a two-dimensional array that holds the coordinates of the
!       interpolation points relative to XBASE.
!     FVAL holds the values of F at the interpolation points.
!     XOPT is set to the displacement from XBASE of the trust region centre.
!     GOPT holds the gradient of the quadratic model at XBASE+XOPT.
!     HQ holds the explicit second derivatives of the quadratic model.
!     PQ contains the parameters of the implicit second derivatives of the
!       quadratic model.
!     BMAT holds the last N columns of H.
!     ZMAT holds the factorization of the leading NPT by NPT submatrix of H,
!       this factorization being ZMAT times ZMAT^T, which provides both the
!       correct rank and positive semi-definiteness.
!     NDIM is the first dimension of BMAT and has the value NPT+N.
!     SL and SU hold the differences XL-XBASE and XU-XBASE, respectively.
!       All the components of every XOPT are going to satisfy the bounds
!       SL(I) .LEQ. XOPT(I) .LEQ. SU(I), with appropriate equalities when
!       XOPT is on a constraint boundary.
!     XNEW is chosen by SUBROUTINE TRSBOX or ALTMOV. Usually XBASE+XNEW is the
!       vector of variables for the next call of CALFUN. XNEW also satisfies
!       the SL and SU constraints in the way that has just been mentioned.
!     XALT is an alternative to XNEW, chosen by ALTMOV, that may replace XNEW
!       in order to increase the denominator in the updating of UPDATE.
!     D is reserved for a trial step from XOPT, which is usually XNEW-XOPT.
!     VLAG contains the values of the Lagrange functions at a new point X.
!       They are part of a product that requires VLAG to be of length NDIM.
!     W is a one-dimensional array that is used for working space. Its length
!       must be at least 3*NDIM = 3*(NPT+N).
!
!     Set some constants.
!
np = n + 1
nptm = npt - np
nh = (n * np) / 2
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     The call of PRELIM sets the elements of XBASE, XPT, FVAL, GOPT, HQ, PQ,
!     BMAT and ZMAT for the first iteration, with the corresponding values of
!     of NF and KOPT, which are the number of calls of CALFUN so far and the
!     index of the interpolation point at the trust region centre. Then the
!     initial XOPT is set too. The branch to label 720 occurs if MAXFUN is
!     less than NPT. GOPT will be updated if KOPT is different from KBASE.
!
call prelim(n, npt, x, xl, xu, rhobeg, iprint, maxfun, xbase, xpt, &
& fval, gopt, hq, pq, bmat, zmat, ndim, sl, su, nf, kopt, f, ftarget)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

xoptsq = zero
do i = 1, n
    xopt(i) = xpt(kopt, i)
    xoptsq = xoptsq + xopt(i)**2
end do
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Zaikun 2019-08-29: FSAVE is not needed any more. See line number 720.
!      FSAVE=FVAL(1)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     By Tom/Zaikun (on 04-06-2019/07-06-2019):
if (is_nan(f) .or. is_posinf(f)) then
    info = -2
    goto 720
end if
!     By Tom (on 04-06-2019):
!     If F reached the target function, PRELIM will stop and BOBYQB
!     should stop here.
if (f <= ftarget) then
    info = 1
    goto 736
end if
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
if (nf < npt) then
    info = 3
    goto 720
end if
kbase = 1
!
!     Complete the settings that are required for the iterative procedure.
!
rho = rhobeg
delta = rho
nresc = nf
ntrits = 0
diffa = zero
diffb = zero
itest = 0
nfsav = nf
!
!     Update GOPT if necessary before the first iteration and after each
!     call of RESCUE that makes a call of CALFUN.
!
20 if (kopt /= kbase) then
    ih = 0
    do j = 1, n
        do i = 1, j
            ih = ih + 1
            if (i < j) gopt(j) = gopt(j) + hq(ih) * xopt(i)
            gopt(i) = gopt(i) + hq(ih) * xopt(j)
        end do
    end do
    if (nf > npt) then
        do k = 1, npt
            temp = zero
            do j = 1, n
                temp = temp + xpt(k, j) * xopt(j)
            end do
            temp = pq(k) * temp
            do i = 1, n
                gopt(i) = gopt(i) + temp * xpt(k, i)
            end do
        end do
    end if
end if
!
!     Generate the next point in the trust region that provides a small value
!     of the quadratic model subject to the constraints on the variables.
!     The integer NTRITS is set to the number "trust region" iterations that
!     have occurred since the last "alternative" iteration. If the length
!     of XNEW-XOPT is less than HALF*RHO, however, then there is a branch to
!     label 650 or 680 with NTRITS=-1, instead of calculating F at XNEW.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Zaikun 2019-08-29: For ill-conditioned problems, NaN may occur in the
! models. In such a case, we terminate the code. Otherwise, the behavior
! of TRBOX, ALTMOV, or RESCUE is not predictable, and Segmentation Fault or
! infinite cycling may happen. This is because any equality/inequality
! comparison involving NaN returns FALSE, which can lead to unintended
! behavior of the code, including uninitialized indices.
!
!   60 CALL TRSBOX (N,NPT,XPT,XOPT,GOPT,HQ,PQ,SL,SU,DELTA,XNEW,D,
60 do i = 1, n
    if (gopt(i) /= gopt(i)) then
        info = -3
        goto 720
    end if
end do
do i = 1, nh
    if (hq(i) /= hq(i)) then
        info = -3
        goto 720
    end if
end do
do i = 1, npt
    if (pq(i) /= pq(i)) then
        info = -3
        goto 720
    end if
end do
call trsbox(n, npt, xpt, xopt, gopt, hq, pq, sl, su, delta, xnew, d, &
& w, w(np), w(np + n), w(np + 2 * n), w(np + 3 * n), dsq, crvmin)
dnorm = dmin1(delta, dsqrt(dsq))
if (dnorm < half * rho) then
    ntrits = -1
    distsq = (ten * rho)**2
    if (nf <= nfsav + 2) goto 650
!
!     The following choice between labels 650 and 680 depends on whether or
!     not our work with the current RHO seems to be complete. Either RHO is
!     decreased or termination occurs if the errors in the quadratic model at
!     the last three interpolation points compare favourably with predictions
!     of likely improvements to the model within distance HALF*RHO of XOPT.
!
    errbig = dmax1(diffa, diffb, diffc)
    frhosq = 0.125D0 * rho * rho
    if (crvmin > zero .and. errbig > frhosq * crvmin) goto 650
    bdtol = errbig / rho
    do j = 1, n
        bdtest = bdtol
        if (xnew(j) == sl(j)) bdtest = w(j)
        if (xnew(j) == su(j)) bdtest = -w(j)
        if (bdtest < bdtol) then
            curv = hq((j + j * j) / 2)
            do k = 1, npt
                curv = curv + pq(k) * xpt(k, j)**2
            end do
            bdtest = bdtest + half * curv * rho
            if (bdtest < bdtol) goto 650
        end if
    end do
    goto 680
end if
ntrits = ntrits + 1
!
!     Severe cancellation is likely to occur if XOPT is too far from XBASE.
!     If the following test holds, then XBASE is shifted so that XOPT becomes
!     zero. The appropriate changes are made to BMAT and to the second
!     derivatives of the current model, beginning with the changes to BMAT
!     that do not depend on ZMAT. VLAG is used temporarily for working space.
!
90 if (dsq <= 1.0D-3 * xoptsq) then
    fracsq = 0.25D0 * xoptsq
    sumpq = zero
    do k = 1, npt
        sumpq = sumpq + pq(k)
        sum = -half * xoptsq
        do i = 1, n
            sum = sum + xpt(k, i) * xopt(i)
        end do
        w(npt + k) = sum
        temp = fracsq - half * sum
        do i = 1, n
            w(i) = bmat(k, i)
            vlag(i) = sum * xpt(k, i) + temp * xopt(i)
            ip = npt + i
            do j = 1, i
                bmat(ip, j) = bmat(ip, j) + w(i) * vlag(j) + vlag(i) * w(j)
            end do
        end do
    end do
!
!     Then the revisions of BMAT that depend on ZMAT are calculated.
!
    do jj = 1, nptm
        sumz = zero
        sumw = zero
        do k = 1, npt
            sumz = sumz + zmat(k, jj)
            vlag(k) = w(npt + k) * zmat(k, jj)
            sumw = sumw + vlag(k)
        end do
        do j = 1, n
            sum = (fracsq * sumz - half * sumw) * xopt(j)
            do k = 1, npt
                sum = sum + vlag(k) * xpt(k, j)
            end do
            w(j) = sum
            do k = 1, npt
                bmat(k, j) = bmat(k, j) + sum * zmat(k, jj)
            end do
        end do
        do i = 1, n
            ip = i + npt
            temp = w(i)
            do j = 1, i
                bmat(ip, j) = bmat(ip, j) + temp * w(j)
            end do
        end do
    end do
!
!     The following instructions complete the shift, including the changes
!     to the second derivative parameters of the quadratic model.
!
    ih = 0
    do j = 1, n
        w(j) = -half * sumpq * xopt(j)
        do k = 1, npt
            w(j) = w(j) + pq(k) * xpt(k, j)
            xpt(k, j) = xpt(k, j) - xopt(j)
        end do
        do i = 1, j
            ih = ih + 1
            hq(ih) = hq(ih) + w(i) * xopt(j) + xopt(i) * w(j)
            bmat(npt + i, j) = bmat(npt + j, i)
        end do
    end do
    do i = 1, n
        xbase(i) = xbase(i) + xopt(i)
        xnew(i) = xnew(i) - xopt(i)
        sl(i) = sl(i) - xopt(i)
        su(i) = su(i) - xopt(i)
        xopt(i) = zero
    end do
    xoptsq = zero
end if
if (ntrits == 0) goto 210
goto 230
!
!     XBASE is also moved to XOPT by a call of RESCUE. This calculation is
!     more expensive than the previous shift, because new matrices BMAT and
!     ZMAT are generated from scratch, which may include the replacement of
!     interpolation points whose positions seem to be causing near linear
!     dependence in the interpolation conditions. Therefore RESCUE is called
!     only if rounding errors have reduced by at least a factor of two the
!     denominator of the formula for updating the H matrix. It provides a
!     useful safeguard, but is not invoked in most applications of BOBYQA.
!
190 nfsav = nf
kbase = kopt
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Zaikun 2019-08-29
! See the comments above line number 60.
do i = 1, n
    if (gopt(i) /= gopt(i)) then
        info = -3
        goto 720
    end if
end do
do i = 1, nh
    if (hq(i) /= hq(i)) then
        info = -3
        goto 720
    end if
end do
do i = 1, npt
    if (pq(i) /= pq(i)) then
        info = -3
        goto 720
    end if
end do
do j = 1, n
    do i = 1, ndim
        if (bmat(i, j) /= bmat(i, j)) then
            info = -3
            goto 720
        end if
    end do
end do
do j = 1, nptm
    do i = 1, npt
        if (zmat(i, j) /= zmat(i, j)) then
            info = -3
            goto 720
        end if
    end do
end do
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call rescue(n, npt, xl, xu, iprint, maxfun, xbase, xpt, fval, &
& xopt, gopt, hq, pq, bmat, zmat, ndim, sl, su, nf, delta, kopt, &
& vlag, w, w(n + np), w(ndim + np), f, ftarget)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     XOPT is updated now in case the branch below to label 720 is taken.
!     Any updating of GOPT occurs after the branch below to label 20, which
!     leads to a trust region iteration as does the branch to label 60.
!
xoptsq = zero
if (kopt /= kbase) then
    do i = 1, n
        xopt(i) = xpt(kopt, i)
        xoptsq = xoptsq + xopt(i)**2
    end do
end if
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     By Tom/Zaikun (on 04-06-2019/07-06-2019):
if (is_nan(f) .or. is_posinf(f)) then
    info = -2
    goto 720
end if
!     By Tom (on 04-06-2019):
!     If F reached the target function, RESCUE will stop and BOBYQB
!     should stop here.
if (f <= ftarget) then
    info = 1
    goto 736
end if
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if (nf < 0) then
    nf = maxfun
    info = 3
    goto 720
end if
nresc = nf
if (nfsav < nf) then
    nfsav = nf
    goto 20
end if
if (ntrits > 0) goto 60
!
!     Pick two alternative vectors of variables, relative to XBASE, that
!     are suitable as new positions of the KNEW-th interpolation point.
!     Firstly, XNEW is set to the point on a line through XOPT and another
!     interpolation point that minimizes the predicted value of the next
!     denominator, subject to ||XNEW - XOPT|| .LEQ. ADELT and to the SL
!     and SU bounds. Secondly, XALT is set to the best feasible point on
!     a constrained version of the Cauchy step of the KNEW-th Lagrange
!     function, the corresponding value of the square of this function
!     being returned in CAUCHY. The choice between these alternatives is
!     going to be made when the denominator is calculated.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  Zaikun 23-07-2019:
!  210 CALL ALTMOV (N,NPT,XPT,XOPT,BMAT,ZMAT,NDIM,SL,SU,KOPT,
!     1  KNEW,ADELT,XNEW,XALT,ALPHA,CAUCHY,W,W(NP),W(NDIM+1))
!
!  Although very rare, NaN can sometimes occur in BMAT or ZMAT. If it
!  happens, we terminate the code. See the comments above line number 60.
!  Indeed, if ALTMOV is called with such matrices, then altmov.f will
!  encounter a memory error at lines 173--174. This is because the first
!  value of PREDSQ in ALTOMOV (see line 159 of altmov.f) will be NaN, line
!  164 will not be reached, and hence no value will be assigned to IBDSAV.
!
!  Such an error was observed when BOBYQA was (mistakenly) tested on CUTEst
!  problem CONCON. CONCON is a nonlinearly constrained problem with
!  bounds. By mistake, BOBYQA was called to solve this problem,
!  neglecting all the constraints other than bounds. With only the bound
!  constraints, the objective function turned to be unbounded from
!  below, which led to abnormal values in BMAT (indeed, BETA defined in
!  lines 366--389 took NaN/infinite values).
!
210 do j = 1, n
    do i = 1, ndim
        if (bmat(i, j) /= bmat(i, j)) then
            info = -3
            goto 720
        end if
    end do
end do
do j = 1, nptm
    do i = 1, npt
        if (zmat(i, j) /= zmat(i, j)) then
            info = -3
            goto 720
        end if
    end do
end do
call altmov(n, npt, xpt, xopt, bmat, zmat, ndim, sl, su, kopt, &
& knew, adelt, xnew, xalt, alpha, cauchy, w, w(np), w(ndim + 1))
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
do i = 1, n
    d(i) = xnew(i) - xopt(i)
end do
!
!     Calculate VLAG and BETA for the current choice of D. The scalar
!     product of D with XPT(K,.) is going to be held in W(NPT+K) for
!     use when VQUAD is calculated.
!
230 do k = 1, npt
    suma = zero
    sumb = zero
    sum = zero
    do j = 1, n
        suma = suma + xpt(k, j) * d(j)
        sumb = sumb + xpt(k, j) * xopt(j)
        sum = sum + bmat(k, j) * d(j)
    end do
    w(k) = suma * (half * suma + sumb)
    vlag(k) = sum
    w(npt + k) = suma
end do
beta = zero
do jj = 1, nptm
    sum = zero
    do k = 1, npt
        sum = sum + zmat(k, jj) * w(k)
    end do
    beta = beta - sum * sum
    do k = 1, npt
        vlag(k) = vlag(k) + sum * zmat(k, jj)
    end do
end do
dsq = zero
bsum = zero
dx = zero
do j = 1, n
    dsq = dsq + d(j)**2
    sum = zero
    do k = 1, npt
        sum = sum + w(k) * bmat(k, j)
    end do
    bsum = bsum + sum * d(j)
    jp = npt + j
    do i = 1, n
        sum = sum + bmat(jp, i) * d(i)
    end do
    vlag(jp) = sum
    bsum = bsum + sum * d(j)
    dx = dx + d(j) * xopt(j)
end do
beta = dx * dx + dsq * (xoptsq + dx + dx + half * dsq) + beta - bsum
vlag(kopt) = vlag(kopt) + one
!
!     If NTRITS is zero, the denominator may be increased by replacing
!     the step D of ALTMOV by a Cauchy step. Then RESCUE may be called if
!     rounding errors have damaged the chosen denominator.
!
if (ntrits == 0) then
    denom = vlag(knew)**2 + alpha * beta
    if (denom < cauchy .and. cauchy > zero) then
        do i = 1, n
            xnew(i) = xalt(i)
            d(i) = xnew(i) - xopt(i)
        end do
        cauchy = zero
        go to 230
    end if
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!          IF (DENOM .LE. HALF*VLAG(KNEW)**2) THEN
    if (.not. (denom > half * vlag(knew)**2)) then
!111111111111111111111!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        if (nf > nresc) goto 190
        info = 4
        goto 720
    end if
!
!     Alternatively, if NTRITS is positive, then set KNEW to the index of
!     the next interpolation point to be deleted to make room for a trust
!     region step. Again RESCUE may be called if rounding errors have damaged
!     the chosen denominator, which is the reason for attempting to select
!     KNEW before calculating the next value of the objective function.
!
else
    delsq = delta * delta
    scaden = zero
    biglsq = zero
    knew = 0
    do k = 1, npt
        if (k == kopt) cycle
        hdiag = zero
        do jj = 1, nptm
            hdiag = hdiag + zmat(k, jj)**2
        end do
        den = beta * hdiag + vlag(k)**2
        distsq = zero
        do j = 1, n
            distsq = distsq + (xpt(k, j) - xopt(j))**2
        end do
        temp = dmax1(one, (distsq / delsq)**2)
        if (temp * den > scaden) then
            scaden = temp * den
            knew = k
            denom = den
        end if
        biglsq = dmax1(biglsq, temp * vlag(k)**2)
    end do
    if (scaden <= half * biglsq) then
        if (nf > nresc) goto 190
        info = 4
        goto 720
    end if
end if
!
!     Put the variables for the next calculation of the objective function
!       in XNEW, with any adjustments for the bounds.
!
!
!     Calculate the value of the objective function at XBASE+XNEW, unless
!       the limit on the number of calculations of F has been reached.
!
360 do i = 1, n
    x(i) = dmin1(dmax1(xl(i), xbase(i) + xnew(i)), xu(i))
    if (xnew(i) == sl(i)) x(i) = xl(i)
    if (xnew(i) == su(i)) x(i) = xu(i)
end do
if (nf >= maxfun) then
    info = 3
    goto 720
end if
nf = nf + 1
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
do i = 1, n
    if (x(i) /= x(i)) then
        f = x(i) ! set f to nan
        if (nf == 1) then
            fopt = f
            xopt(1:n) = zero
        end if
        info = -1
        goto 720
    end if
end do
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

call calfun(n, x, f)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     By Tom (on 04-06-2019):
if (is_nan(f) .or. is_posinf(f)) then
    if (nf == 1) then
        fopt = f
        xopt(1:n) = zero
    end if
    info = -2
    goto 720
end if
!     By Tom (on 04-06-2019):
!     If F achieves the function value, the algorithm exits.
if (f <= ftarget) then
    info = 1
    goto 736
end if
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if (ntrits == -1) then
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Zaikun 2019-08-29: FSAVE is not needed any more. See line number 720.
!          FSAVE=F
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    info = 0
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    goto 720
end if
!
!     Use the quadratic model to predict the change in F due to the step D,
!       and set DIFF to the error of this prediction.
!
fopt = fval(kopt)
vquad = zero
ih = 0
do j = 1, n
    vquad = vquad + d(j) * gopt(j)
    do i = 1, j
        ih = ih + 1
        temp = d(i) * d(j)
        if (i == j) temp = half * temp
        vquad = vquad + hq(ih) * temp
    end do
end do
do k = 1, npt
    vquad = vquad + half * pq(k) * w(npt + k)**2
end do
diff = f - fopt - vquad
diffc = diffb
diffb = diffa
diffa = dabs(diff)
if (dnorm > rho) nfsav = nf
!
!     Pick the next value of DELTA after a trust region step.
!
if (ntrits > 0) then
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!          IF (VQUAD .GE. ZERO) THEN
    if (.not. (vquad < zero)) then
        info = 2
        goto 720
    end if
    ratio = (f - fopt) / vquad
    if (ratio <= tenth) then
        delta = dmin1(half * delta, dnorm)
    else if (ratio <= 0.7D0) then
        delta = dmax1(half * delta, dnorm)
    else
        delta = dmax1(half * delta, dnorm + dnorm)
    end if
    if (delta <= 1.5D0 * rho) delta = rho
!
!     Recalculate KNEW and DENOM if the new F is less than FOPT.
!
    if (f < fopt) then
        ksav = knew
        densav = denom
        delsq = delta * delta
        scaden = zero
        biglsq = zero
        knew = 0
        do k = 1, npt
            hdiag = zero
            do jj = 1, nptm
                hdiag = hdiag + zmat(k, jj)**2
            end do
            den = beta * hdiag + vlag(k)**2
            distsq = zero
            do j = 1, n
                distsq = distsq + (xpt(k, j) - xnew(j))**2
            end do
            temp = dmax1(one, (distsq / delsq)**2)
            if (temp * den > scaden) then
                scaden = temp * den
                knew = k
                denom = den
            end if
            biglsq = dmax1(biglsq, temp * vlag(k)**2)
        end do
        if (scaden <= half * biglsq) then
            knew = ksav
            denom = densav
        end if
    end if
end if
!
!     Update BMAT and ZMAT, so that the KNEW-th interpolation point can be
!     moved. Also update the second derivative terms of the model.
!
call update(n, npt, bmat, zmat, ndim, vlag, beta, denom, knew, w)
ih = 0
pqold = pq(knew)
pq(knew) = zero
do i = 1, n
    temp = pqold * xpt(knew, i)
    do j = 1, i
        ih = ih + 1
        hq(ih) = hq(ih) + temp * xpt(knew, j)
    end do
end do
do jj = 1, nptm
    temp = diff * zmat(knew, jj)
    do k = 1, npt
        pq(k) = pq(k) + temp * zmat(k, jj)
    end do
end do
!
!     Include the new interpolation point, and make the changes to GOPT at
!     the old XOPT that are caused by the updating of the quadratic model.
!
fval(knew) = f
do i = 1, n
    xpt(knew, i) = xnew(i)
    w(i) = bmat(knew, i)
end do
do k = 1, npt
    suma = zero
    do jj = 1, nptm
        suma = suma + zmat(knew, jj) * zmat(k, jj)
    end do
    sumb = zero
    do j = 1, n
        sumb = sumb + xpt(k, j) * xopt(j)
    end do
    temp = suma * sumb
    do i = 1, n
        w(i) = w(i) + temp * xpt(k, i)
    end do
end do
do i = 1, n
    gopt(i) = gopt(i) + diff * w(i)
end do
!
!     Update XOPT, GOPT and KOPT if the new calculated F is less than FOPT.
!
if (f < fopt) then
    kopt = knew
    xoptsq = zero
    ih = 0
    do j = 1, n
        xopt(j) = xnew(j)
        xoptsq = xoptsq + xopt(j)**2
        do i = 1, j
            ih = ih + 1
            if (i < j) gopt(j) = gopt(j) + hq(ih) * d(i)
            gopt(i) = gopt(i) + hq(ih) * d(j)
        end do
    end do
    do k = 1, npt
        temp = zero
        do j = 1, n
            temp = temp + xpt(k, j) * d(j)
        end do
        temp = pq(k) * temp
        do i = 1, n
            gopt(i) = gopt(i) + temp * xpt(k, i)
        end do
    end do
end if
!
!     Calculate the parameters of the least Frobenius norm interpolant to
!     the current data, the gradient of this interpolant at XOPT being put
!     into VLAG(NPT+I), I=1,2,...,N.
!
if (ntrits > 0) then
    do k = 1, npt
        vlag(k) = fval(k) - fval(kopt)
        w(k) = zero
    end do
    do j = 1, nptm
        sum = zero
        do k = 1, npt
            sum = sum + zmat(k, j) * vlag(k)
        end do
        do k = 1, npt
            w(k) = w(k) + sum * zmat(k, j)
        end do
    end do
    do k = 1, npt
        sum = zero
        do j = 1, n
            sum = sum + xpt(k, j) * xopt(j)
        end do
        w(k + npt) = w(k)
        w(k) = sum * w(k)
    end do
    gqsq = zero
    gisq = zero
    do i = 1, n
        sum = zero
        do k = 1, npt
            sum = sum + bmat(k, i) * vlag(k) + xpt(k, i) * w(k)
        end do
        if (xopt(i) == sl(i)) then
            gqsq = gqsq + dmin1(zero, gopt(i))**2
            gisq = gisq + dmin1(zero, sum)**2
        else if (xopt(i) == su(i)) then
            gqsq = gqsq + dmax1(zero, gopt(i))**2
            gisq = gisq + dmax1(zero, sum)**2
        else
            gqsq = gqsq + gopt(i)**2
            gisq = gisq + sum * sum
        end if
        vlag(npt + i) = sum
    end do
!
!     Test whether to replace the new quadratic model by the least Frobenius
!     norm interpolant, making the replacement if the test is satisfied.
!
    itest = itest + 1
    if (gqsq < ten * gisq) itest = 0
    if (itest >= 3) then
        do i = 1, max0(npt, nh)
            if (i <= n) gopt(i) = vlag(npt + i)
            if (i <= npt) pq(i) = w(npt + i)
            if (i <= nh) hq(i) = zero
            itest = 0
        end do
    end if
end if
!
!     If a trust region step has provided a sufficient decrease in F, then
!     branch for another trust region calculation. The case NTRITS=0 occurs
!     when the new interpolation point was reached by an alternative step.
!
if (ntrits == 0) goto 60
if (f <= fopt + tenth * vquad) goto 60
!
!     Alternatively, find out if the interpolation points are close enough
!       to the best point so far.
!
distsq = dmax1((two * delta)**2, (ten * rho)**2)
650 knew = 0
do k = 1, npt
    sum = zero
    do j = 1, n
        sum = sum + (xpt(k, j) - xopt(j))**2
    end do
    if (sum > distsq) then
        knew = k
        distsq = sum
    end if
end do
!
!     If KNEW is positive, then ALTMOV finds alternative new positions for
!     the KNEW-th interpolation point within distance ADELT of XOPT. It is
!     reached via label 90. Otherwise, there is a branch to label 60 for
!     another trust region iteration, unless the calculations with the
!     current RHO are complete.
!
if (knew > 0) then
    dist = dsqrt(distsq)
    if (ntrits == -1) then
        delta = dmin1(tenth * delta, half * dist)
        if (delta <= 1.5D0 * rho) delta = rho
    end if
    ntrits = 0
    adelt = dmax1(dmin1(tenth * dist, delta), rho)
    dsq = adelt * adelt
    goto 90
end if
if (ntrits == -1) goto 680
if (ratio > zero) goto 60
if (dmax1(delta, dnorm) > rho) goto 60
!
!     The calculations with the current value of RHO are complete. Pick the
!       next values of RHO and DELTA.
!
680 if (rho > rhoend) then
    delta = half * rho
    ratio = rho / rhoend
    if (ratio <= 16.0D0) then
        rho = rhoend
    else if (ratio <= 250.0D0) then
        rho = dsqrt(ratio) * rhoend
    else
        rho = tenth * rho
    end if
    delta = dmax1(delta, rho)
    ntrits = 0
    nfsav = nf
    goto 60
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
else
    info = 0
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end if
!
!     Return from the calculation, after another Newton-Raphson step, if
!       it is too short to have been tried before.
!
if (ntrits == -1) goto 360
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  720 IF (FVAL(KOPT) .LE. FSAVE) THEN
!  Why update X only when FVAL(KOPT) .LE. FSAVE? This seems INCORRECT,
!  because it may lead to a return with F and X that are not the best
!  available.
720 if (fval(kopt) <= f .or. f /= f) then
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    do i = 1, n
        x(i) = dmin1(dmax1(xl(i), xbase(i) + xopt(i)), xu(i))
        if (xopt(i) == sl(i)) x(i) = xl(i)
        if (xopt(i) == su(i)) x(i) = xu(i)
    end do
    f = fval(kopt)
end if
736 return
end
