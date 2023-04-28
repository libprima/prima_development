subroutine newuob (n,npt,x,rhobeg,rhoend,iprint,maxfun,xbase, xopt,xnew,xpt,fval,gq,hq,pq,bmat,zmat,ndim,d,vlag,w,f,info,ftarget)

implicit real(kind(0.0d0)) (a-h,o-z)
implicit integer (i-n)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
dimension x(*),xbase(*),xopt(*),xnew(*),xpt(npt,*),fval(*),gq(*),hq(*),pq(*),bmat(ndim,*),zmat(npt,*),d(*),vlag(*),w(*)
!
!     The arguments N, NPT, X, RHOBEG, RHOEND, IPRINT and MAXFUN are identical
! to the corresponding arguments in SUBROUTINE NEWUOA.
!     XBASE will hold a shift of origin that should reduce the contributions
! from rounding errors to values of the model and Lagrange functions.
!     XOPT will be set to the displacement from XBASE of the vector of
! variables that provides the least calculated F so far.
!     XNEW will be set to the displacement from XBASE of the vector of
! variables for the current calculation of F.
!     XPT will contain the interpolation point coordinates relative to XBASE.
!     FVAL will hold the values of F at the interpolation points.
!     GQ will hold the gradient of the quadratic model at XBASE.
!     HQ will hold the explicit second derivatives of the quadratic model.
!     PQ will contain the parameters of the implicit second derivatives of
! the quadratic model.
!     BMAT will hold the last N columns of H.
!     ZMAT will hold the factorization of the leading NPT by NPT submatrix of
! H, this factorization being ZMAT times Diag(DZ) times ZMAT^T, where
! the elements of DZ are plus or minus one, as specified by IDZ.
!     NDIM is the first dimension of BMAT and has the value NPT+N.
!     D is reserved for trial steps from XOPT.
!     VLAG will contain the values of the Lagrange functions at a new point X.
! They are part of a product that requires VLAG to be of length NDIM.
!     The array W will be used for working space. Its length must be at least
! 10*NDIM = 10*(NPT+N).
!
!     Set some constants.
!
half=0.5d0
one=1.0d0
tenth=0.1d0
zero=0.0d0
np=n+1
nh=(n*np)/2
nptm=npt-np
nftest=max0(maxfun,1)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
almost_infinity=huge(0.0d0)/2.0d0
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     Set the initial elements of XPT, BMAT, HQ, PQ and ZMAT to zero.
!
do j=1,n
    xbase(j)=x(j)
    do k=1,npt
 xpt(k,j)=zero
    end do
    do i=1,ndim
 bmat(i,j)=zero
    end do
end do
do ih=1,nh
    hq(ih)=zero
end do
do k=1,npt
    pq(k)=zero
    do j=1,nptm
 zmat(k,j)=zero
    end do
end do
!
!     Begin the initialization procedure. NF becomes one more than the number
!     of function values so far. The coordinates of the displacement of the
!     next initial interpolation point from XBASE are set in XPT(NF,.).
!
rhosq=rhobeg*rhobeg
recip=one/rhosq
reciq=dsqrt(half)/rhosq
nf=0
   50 nfm=nf
nfmm=nf-n
nf=nf+1
if (nfm <= 2*n) then
    if (nfm >= 1 .and. nfm <= n) then
 xpt(nf,nfm)=rhobeg
    else if (nfm > n) then
 xpt(nf,nfmm)=-rhobeg
    end if
else
    itemp=(nfmm-1)/n
    jpt=nfm-itemp*n-n
    ipt=jpt+itemp
    if (ipt > n) then
 itemp=jpt
 jpt=ipt-n
 ipt=itemp
    end if
    xipt=rhobeg
    if (fval(ipt+np) < fval(ipt+1)) xipt=-xipt
    xjpt=rhobeg
    if (fval(jpt+np) < fval(jpt+1)) xjpt=-xjpt
    xpt(nf,ipt)=xipt
    xpt(nf,jpt)=xjpt
end if
!
!     Calculate the next value of F, label 70 being reached immediately
!     after this calculation. The least function value so far and its index
!     are required.
!
do j=1,n
    x(j)=xpt(nf,j)+xbase(j)
end do
goto 310
   70 fval(nf)=f
if (nf == 1) then
    fbeg=f
    fopt=f
    kopt=1
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     By Zaikun (commented on 02-06-2019; implemented in 2016):
!     The following line is to make sure that XOPT is always 
!     up to date even if the first model has not been built yet 
!     (i.e., NF<NPT). This is necessary because the code may exit before
!     the first model is built due to an NaN or nearly infinity value of
!     F occurs. 
    do i = 1, n
 xopt(i)=xpt(1, i)
    end do
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
else if (f < fopt) then
    fopt=f
    kopt=nf
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     By Zaikun (commented on 02-06-2019; implemented in 2016):
!     The following line is to make sure that XOPT is always 
!     up to date even if the first model has not been built yet 
!     (i.e., NF<NPT). This is necessary because the code may exit before
!     the first model is built due to an NaN or nearly infinity value of
    do i = 1, n
 xopt(i)=xpt(nf, i)
    end do
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end if
!
!     Set the nonzero initial elements of BMAT and the quadratic model in
!     the cases when NF is at most 2*N+1.
!
if (nfm <= 2*n) then
    if (nfm >= 1 .and. nfm <= n) then
 gq(nfm)=(f-fbeg)/rhobeg
 if (npt < nf+n) then
     bmat(1,nfm)=-one/rhobeg
     bmat(nf,nfm)=one/rhobeg
     bmat(npt+nfm,nfm)=-half*rhosq
 end if
    else if (nfm > n) then
 bmat(nf-n,nfmm)=half/rhobeg
 bmat(nf,nfmm)=-half/rhobeg
 zmat(1,nfmm)=-reciq-reciq
 zmat(nf-n,nfmm)=reciq
 zmat(nf,nfmm)=reciq
 ih=(nfmm*(nfmm+1))/2
 temp=(fbeg-f)/rhobeg
 hq(ih)=(gq(nfmm)-temp)/rhobeg
 gq(nfmm)=half*(gq(nfmm)+temp)
    end if
!
!     Set the off-diagonal second derivatives of the Lagrange functions and
!     the initial quadratic model.
!
else
    ih=(ipt*(ipt-1))/2+jpt
    if (xipt < zero) ipt=ipt+n
    if (xjpt < zero) jpt=jpt+n
    zmat(1,nfmm)=recip
    zmat(nf,nfmm)=recip
    zmat(ipt+1,nfmm)=-recip
    zmat(jpt+1,nfmm)=-recip
    hq(ih)=(fbeg-fval(ipt+1)-fval(jpt+1)+f)/(xipt*xjpt)
end if
if (nf < npt) goto 50
!
!     Begin the iterative procedure, because the initial model is complete.
!
rho=rhobeg
delta=rho
idz=1
diffa=zero
diffb=zero
itest=0
xoptsq=zero
do i=1,n
    xopt(i)=xpt(kopt,i)
    xoptsq=xoptsq+xopt(i)**2
end do
   90 nfsav=nf
!
!     Generate the next trust region step and test its length. Set KNEW
!     to -1 if the purpose of the next F will be to improve the model.
!
  100 knew=0
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Zaikun 2019-08-29: For ill-conditioned problems, NaN may occur in the
! models. In such a case, we terminate the code. Otherwise, the behavior
! of TRSAPP, BIGDEN, or BIGLAG is not predictable, and Segmentation Fault 
! or infinite cycling may happen. This is because any equality/inequality
! comparison involving NaN returns FALSE, which can lead to unintended
! behavior of the code, including uninitialized indices.
do i = 1, n
    if (gq(i) /= gq(i)) then
 info = -3
 goto 530
    end if 
end do
do i = 1, nh
    if (hq(i) /= hq(i)) then
 info = -3
 goto 530
    end if 
end do 
do i = 1, npt
    if (pq(i) /= pq(i)) then
 info = -3
 goto 530
    end if
end do
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call trsapp (n,npt,xopt,xpt,gq,hq,pq,delta,d,w,w(np),w(np+n),w(np+2*n),crvmin)
dsq=zero
do i=1,n
    dsq=dsq+d(i)**2
end do
dnorm=dmin1(delta,dsqrt(dsq))
if (dnorm < half*rho) then
    knew=-1
    delta=tenth*delta
    ratio=-1.0d0
    if (delta <= 1.5d0*rho) delta=rho
    if (nf <= nfsav+2) goto 460
    temp=0.125d0*crvmin*rho*rho
    if (temp <= dmax1(diffa,diffb,diffc)) goto 460
    goto 490
end if
!
!     Shift XBASE if XOPT may be too far from XBASE. First make the changes
!     to BMAT that do not depend on ZMAT.
!
  120 if (dsq <= 1.0d-3*xoptsq) then
    tempq=0.25d0*xoptsq
    do k=1,npt
 sum=zero
 do i=1,n
     sum=sum+xpt(k,i)*xopt(i)
 end do
 temp=pq(k)*sum
 sum=sum-half*xoptsq
 w(npt+k)=sum
 do i=1,n
     gq(i)=gq(i)+temp*xpt(k,i)
     xpt(k,i)=xpt(k,i)-half*xopt(i)
     vlag(i)=bmat(k,i)
     w(i)=sum*xpt(k,i)+tempq*xopt(i)
     ip=npt+i
     do j=1,i
  bmat(ip,j)=bmat(ip,j)+vlag(i)*w(j)+w(i)*vlag(j)
     end do
 end do
    end do
!
!     Then the revisions of BMAT that depend on ZMAT are calculated.
!
    do k=1,nptm
 sumz=zero
 do i=1,npt
     sumz=sumz+zmat(i,k)
     w(i)=w(npt+i)*zmat(i,k)
 end do
 do j=1,n
     sum=tempq*sumz*xopt(j)
     do i=1,npt
  sum=sum+w(i)*xpt(i,j)
     end do
     vlag(j)=sum
     if (k < idz) sum=-sum
     do i=1,npt
  bmat(i,j)=bmat(i,j)+sum*zmat(i,k)
     end do
 end do
 do i=1,n
     ip=i+npt
     temp=vlag(i)
     if (k < idz) temp=-temp
     do j=1,i
  bmat(ip,j)=bmat(ip,j)+temp*vlag(j)
     end do
 end do
    end do
!
!     The following instructions complete the shift of XBASE, including
!     the changes to the parameters of the quadratic model.
!
    ih=0
    do j=1,n
 w(j)=zero
 do k=1,npt
     w(j)=w(j)+pq(k)*xpt(k,j)
     xpt(k,j)=xpt(k,j)-half*xopt(j)
 end do
 do i=1,j
     ih=ih+1
     if (i < j) gq(j)=gq(j)+hq(ih)*xopt(i)
     gq(i)=gq(i)+hq(ih)*xopt(j)
     hq(ih)=hq(ih)+w(i)*xopt(j)+xopt(i)*w(j)
     bmat(npt+i,j)=bmat(npt+j,i)
 end do
    end do
    do j=1,n
 xbase(j)=xbase(j)+xopt(j)
 xopt(j)=zero
    end do
    xoptsq=zero
end if
!
!     Pick the model step if KNEW is positive. A different choice of D
!     may be made later, if the choice of D by BIGLAG causes substantial
!     cancellation in DENOM.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Zaikun 2019-08-29: See the comments below line number 100
do j = 1, n
    do i = 1, ndim
 if (bmat(i,j) /= bmat(i,j)) then
     info = -3
     goto 530
 end if
    end do
end do
do j = 1, nptm
    do i = 1, npt
 if (zmat(i,j) /= zmat(i,j)) then
     info = -3
     goto 530
 end if
    end do
end do
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
if (knew > 0) then
    call biglag (n,npt,xopt,xpt,bmat,zmat,idz,ndim,knew,dstep, d,alpha,vlag,vlag(npt+1),w,w(np),w(np+n))
end if
!
!     Calculate VLAG and BETA for the current choice of D. The first NPT
!     components of W_check will be held in W.
!
do k=1,npt
    suma=zero
    sumb=zero
    sum=zero
    do j=1,n
 suma=suma+xpt(k,j)*d(j)
 sumb=sumb+xpt(k,j)*xopt(j)
 sum=sum+bmat(k,j)*d(j)
    end do
    w(k)=suma*(half*suma+sumb)
    vlag(k)=sum
end do
beta=zero
do k=1,nptm
    sum=zero
    do i=1,npt
 sum=sum+zmat(i,k)*w(i)
    end do
    if (k < idz) then
 beta=beta+sum*sum
 sum=-sum
    else
 beta=beta-sum*sum
    end if
    do i=1,npt
 vlag(i)=vlag(i)+sum*zmat(i,k)
    end do
end do
bsum=zero
dx=zero
do j=1,n
    sum=zero
    do i=1,npt
 sum=sum+w(i)*bmat(i,j)
    end do
    bsum=bsum+sum*d(j)
    jp=npt+j
    do k=1,n
 sum=sum+bmat(jp,k)*d(k)
    end do
    vlag(jp)=sum
    bsum=bsum+sum*d(j)
    dx=dx+d(j)*xopt(j)
end do
beta=dx*dx+dsq*(xoptsq+dx+dx+half*dsq)+beta-bsum
vlag(kopt)=vlag(kopt)+one
!
!     If KNEW is positive and if the cancellation in DENOM is unacceptable,
!     then BIGDEN calculates an alternative model step, XNEW being used for
!     working space.
!
if (knew > 0) then
    temp=one+alpha*beta/vlag(knew)**2
    if (dabs(temp) <= 0.8d0) then
 call bigden (n,npt,xopt,xpt,bmat,zmat,idz,ndim,kopt,knew,d,w,vlag,beta,xnew,w(ndim+1),w(6*ndim+1))
    end if
end if
!
!     Calculate the next value of the objective function.
!
  290 do i=1,n
    xnew(i)=xopt(i)+d(i)
    x(i)=xbase(i)+xnew(i)
end do
nf=nf+1
  310 if (nf > nftest) then
    nf=nf-1
    if (iprint > 0) print 320
  320     FORMAT (/4X,'Return from NEWUOA because CALFUN has been called MAXFUN times.')
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    info=3
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    goto 530
end if

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     By Zaikun (commented on 02-06-2019; implemented in 2016):
!     Exit if an NaN occurs in X. 
!     It is necessary to set F to NaN, so that GOTO 530 will lead the
!     code to 540 (i.e., update X and F).  
!     If this happends at the very first function evaluation (i.e.,
!     NF=1), then it is necessary to set FOPT and XOPT before going to
!     530, because these two variables have not been set yet (line 70
!     will not be reached.
do i=1,n
    if (x(i) /= x(i)) then
 f=x(i) ! set f to nan
 if (nf == 1) then
     fopt=f
     do j = 1, n
  xopt(j) = zero
     end do
 end if
 info=-1
 goto 530
    end if
end do
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

call calfun (n,x,f)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     By Zaikun (commented on 02-06-2019; implemented in 2016):
!     Exit if F has an NaN or almost infinite value.
!     If this happends at the very first function evaluation (i.e.,
!     NF=1), then it is necessary to set FOPT and XOPT before going to
!     530, because these two variables have not been set yet (line 70
!     will not be reached.
if (f /= f .or. f > almost_infinity) then
    if (nf == 1) then
 fopt=f
 do i = 1, n
     xopt(i) = zero
 end do
    end if
    info=-2
    goto 530
end if
!     By Zaikun (commented on 02-06-2019; implemented in 2016):
!     Exit if F .LE. FTARGET.
if (f <= ftarget) then
    info=1
    goto 546
end if
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if (iprint == 3) then
    print 330, nf,f,(x(i),i=1,n)
  330 FORMAT (/4X,'Function number',I6,'    F =', 1PD18.10, '    The corresponding X is:'/(2X,5D15.6))
end if
if (nf <= npt) goto 70
if (knew == -1) goto 530
!
!     Use the quadratic model to predict the change in F due to the step D,
!     and set DIFF to the error of this prediction.
!
vquad=zero
ih=0
do j=1,n
    vquad=vquad+d(j)*gq(j)
    do i=1,j
 ih=ih+1
 temp=d(i)*xnew(j)+d(j)*xopt(i)
 if (i == j) temp=half*temp
 vquad=vquad+temp*hq(ih)
    end do
end do
do k=1,npt
    vquad=vquad+pq(k)*w(k)
end do
diff=f-fopt-vquad
diffc=diffb
diffb=diffa
diffa=dabs(diff)
if (dnorm > rho) nfsav=nf
!
!     Update FOPT and XOPT if the new F is the least value of the objective
!     function so far. The branch when KNEW is positive occurs if D is not
!     a trust region step.
!
fsave=fopt
if (f < fopt) then
    fopt=f
    xoptsq=zero
    do i=1,n
 xopt(i)=xnew(i)
 xoptsq=xoptsq+xopt(i)**2
    end do
end if
ksave=knew
if (knew > 0) goto 410
!
!     Pick the next value of DELTA after a trust region step.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!IF (VQUAD .GE. ZERO) THEN
if (.not. (vquad < zero)) then
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if (iprint > 0) print 370
  370     FORMAT (/4X,'Return from NEWUOA because a trust region step has failed to reduce Q.')
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    info=2
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    goto 530
end if
ratio=(f-fsave)/vquad
if (ratio <= tenth) then
    delta=half*dnorm
else if (ratio <= 0.7d0) then
    delta=dmax1(half*delta,dnorm)
else
    delta=dmax1(half*delta,dnorm+dnorm)
end if
if (delta <= 1.5d0*rho) delta=rho
!
!     Set KNEW to the index of the next interpolation point to be deleted.
!
rhosq=dmax1(tenth*delta,rho)**2
ktemp=0
detrat=zero
if (f >= fsave) then
    ktemp=kopt
    detrat=one
end if
do k=1,npt
    hdiag=zero
    do j=1,nptm
 temp=one
 if (j < idz) temp=-one
 hdiag=hdiag+temp*zmat(k,j)**2
    end do
    temp=dabs(beta*hdiag+vlag(k)**2)
    distsq=zero
    do j=1,n
 distsq=distsq+(xpt(k,j)-xopt(j))**2
    end do
    if (distsq > rhosq) temp=temp*(distsq/rhosq)**3
    if (temp > detrat .and. k /= ktemp) then
 detrat=temp
 knew=k
    end if
end do
if (knew == 0) goto 460
!
!     Update BMAT, ZMAT and IDZ, so that the KNEW-th interpolation point
!     can be moved. Begin the updating of the quadratic model, starting
!     with the explicit second derivative term.
!
  410 call update (n,npt,bmat,zmat,idz,ndim,vlag,beta,knew,w)
fval(knew)=f
ih=0
do i=1,n
    temp=pq(knew)*xpt(knew,i)
    do j=1,i
 ih=ih+1
 hq(ih)=hq(ih)+temp*xpt(knew,j)
    end do
end do
pq(knew)=zero
!
!     Update the other second derivative parameters, and then the gradient
!     vector of the model. Also include the new interpolation point.
!
do j=1,nptm
    temp=diff*zmat(knew,j)
    if (j < idz) temp=-temp
    do k=1,npt
 pq(k)=pq(k)+temp*zmat(k,j)
    end do
end do
gqsq=zero
do i=1,n
    gq(i)=gq(i)+diff*bmat(knew,i)
    gqsq=gqsq+gq(i)**2
    xpt(knew,i)=xnew(i)
end do
!
!     If a trust region step makes a small change to the objective function,
!     then calculate the gradient of the least Frobenius norm interpolant at
!     XBASE, and store it in W, using VLAG for a vector of right hand sides.
!
if (ksave == 0 .and. delta == rho) then
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Zaikun 2019-08-26: It is observed in Zhang Zaikun's PhD thesis
! (Section 3.3.2) that it is more reasonable and more efficient to
! check the value of RATIO instead of DABS(RATIO).
!    IF (DABS(RATIO) .GT. 1.0D-2) THEN
    if (ratio > 1.0d-2) then
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 itest=0
    else
 do k=1,npt
     vlag(k)=fval(k)-fval(kopt)
 end do
 gisq=zero
 do i=1,n
     sum=zero
     do k=1,npt
  sum=sum+bmat(k,i)*vlag(k)
     end do
     gisq=gisq+sum*sum
     w(i)=sum
 end do
!
!     Test whether to replace the new quadratic model by the least Frobenius
!     norm interpolant, making the replacement if the test is satisfied.
!
 itest=itest+1
 if (gqsq < 1.0d2*gisq) itest=0
 if (itest >= 3) then
     do i=1,n
  gq(i)=w(i)
     end do
     do ih=1,nh
  hq(ih)=zero
     end do
     do j=1,nptm
  w(j)=zero
  do k=1,npt
w(j)=w(j)+vlag(k)*zmat(k,j)
  end do
  if (j < idz) w(j)=-w(j)
     end do
     do k=1,npt
  pq(k)=zero
  do j=1,nptm
pq(k)=pq(k)+zmat(k,j)*w(j)
  end do
     end do
     itest=0
 end if
    end if
end if
if (f < fsave) kopt=knew
!
!     If a trust region step has provided a sufficient decrease in F, then
!     branch for another trust region calculation. The case KSAVE>0 occurs
!     when the new function value was calculated by a model step.
!
if (f <= fsave+tenth*vquad) goto 100
if (ksave > 0) goto 100
!
!     Alternatively, find out if the interpolation points are close enough
!     to the best point so far.
!
knew=0
  460 distsq=4.0d0*delta*delta
do k=1,npt
    sum=zero
    do j=1,n
 sum=sum+(xpt(k,j)-xopt(j))**2
    end do
    if (sum > distsq) then
 knew=k
 distsq=sum
    end if
end do
!
!     If KNEW is positive, then set DSTEP, and branch back for the next
!     iteration, which will generate a "model step".
!
if (knew > 0) then
    dstep=dmax1(dmin1(tenth*dsqrt(distsq),half*delta),rho)
    dsq=dstep*dstep
    goto 120
end if
if (ratio > zero) goto 100
if (dmax1(delta,dnorm) > rho) goto 100
!
!     The calculations with the current value of RHO are complete. Pick the
!     next values of RHO and DELTA.
!
  490 if (rho > rhoend) then
    delta=half*rho
    ratio=rho/rhoend
    if (ratio <= 16.0d0) then
 rho=rhoend
    else if (ratio <= 250.0d0) then
 rho=dsqrt(ratio)*rhoend
    else
 rho=tenth*rho
    end if
    delta=dmax1(delta,rho)
    if (iprint >= 2) then
 if (iprint >= 3) print 500
  500   FORMAT (5X)
 print 510, rho,nf
  510   FORMAT (/4X,'New RHO =',1PD11.4,5X,'Number of function values =',I6)
 print 520, fopt,(xbase(i)+xopt(i),i=1,n)
  520   FORMAT (4X,'Least value of F =',1PD23.15,9X, 'The corresponding X is:'/(2X,5D15.6))
    end if
    goto 90
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
else
    info=0
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end if
!
!     Return from the calculation, after another Newton-Raphson step, if
!     it is too short to have been tried before.
!
if (knew == -1) goto 290
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     By Zaikun (commented on 02-06-2019; implemented in 2016):
!     Note that (FOPT .LE. F) is FALSE if F is NaN; When F is NaN, it is
!     also necessary to update X and F.
!  530 IF (FOPT .LE. F) THEN
  530 if (fopt <= f .or. f /= f) then
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    do i=1,n
 x(i)=xbase(i)+xopt(i)
    end do
    f=fopt
end if
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!IF (IPRINT .GE. 1) THEN
  546 if (iprint >= 1) then
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    print 550, nf
  550     FORMAT (/4X,'At the return from NEWUOA',5X, 'Number of function values =',I6)
    print 520, f,(x(i),i=1,n)
end if
return
end
