

#include "Definitions.INC"


function ffunct(xval)
  use myparams
  implicit none
  real*8, intent(in) :: xval
  DATATYPE :: ffunct, fac
  real*8 :: fscaled, xx

  fac=exp((0d0,1d0)*scalingtheta)*scalingstretch

  if (xval.le.(-1)*(scalingdistance+smoothness)) then
     ffunct=xval + (fac-1)*(xval+scalingdistance+smoothness/2d0)
  else if (xval.ge.scalingdistance+smoothness) then
     ffunct=xval + (fac-1)*(xval-scalingdistance-smoothness/2d0)
  else if (abs(xval).le.scalingdistance) then
     ffunct=xval
  else if (xval.ge.scalingdistance) then
     xx = (xval-scalingdistance)/smoothness
     ffunct = xval + (fac-1) * smoothness * fscaled(xx)
  else if (xval.le.(-1)*scalingdistance) then
     xx = (-xval-scalingdistance)/smoothness
     ffunct = xval - (fac-1) * smoothness * fscaled(xx)
  else
     print *, "OOGABLAH0"; stop
  endif
end function ffunct


function jfunct(xval)
  use myparams
  implicit none
  real*8, intent(in) :: xval
  DATATYPE :: jfunct, fac
  real*8 :: jscaled, xx

  fac=exp((0d0,1d0)*scalingtheta)*scalingstretch

  if (xval.le.(-1)*(scalingdistance+smoothness)) then
     jfunct=fac
  else if (xval.ge.scalingdistance+smoothness) then
     jfunct=fac
  else if (abs(xval).le.scalingdistance) then
     jfunct=1d0
  else if (xval.ge.scalingdistance) then
     xx = (xval-scalingdistance)/smoothness
     jfunct = 1d0 + (fac-1d0) * jscaled(xx) 
  else if (xval.le.(-1)*scalingdistance) then
     xx = (-xval-scalingdistance)/smoothness
     jfunct = 1d0 + (fac-1d0) * jscaled(xx) 
  else
     print *, "OOGABLAHd"; stop
  endif
end function jfunct


function djfunct(xval)
  use myparams
  implicit none
  real*8, intent(in) :: xval
  DATATYPE :: djfunct, fac
  real*8 :: djscaled, xx

  fac=exp((0d0,1d0)*scalingtheta)*scalingstretch

  if (xval.le.(-1)*(scalingdistance+smoothness)) then
     djfunct=0
  else if (xval.ge.scalingdistance+smoothness) then
     djfunct=0
  else if (abs(xval).le.scalingdistance) then
     djfunct=0
  else if (xval.ge.scalingdistance) then
     xx = (xval-scalingdistance)/smoothness
     djfunct = (fac-1d0) * djscaled(xx) / smoothness
  else if (xval.le.(-1)*scalingdistance) then
     xx = (-xval-scalingdistance)/smoothness
     djfunct = (1d0-fac) * djscaled(xx) / smoothness
  else
     print *, "OOGABLAHd"; stop
  endif
end function djfunct


function ddjfunct(xval)
  use myparams
  implicit none
  real*8, intent(in) :: xval
  DATATYPE :: ddjfunct, fac
  real*8 :: ddjscaled, xx

  fac=exp((0d0,1d0)*scalingtheta)*scalingstretch

  if (xval.le.(-1)*(scalingdistance+smoothness)) then
     ddjfunct=0
  else if (xval.ge.scalingdistance+smoothness) then
     ddjfunct=0
  else if (abs(xval).le.scalingdistance) then
     ddjfunct=0
  else if (xval.ge.scalingdistance) then
     xx = (xval-scalingdistance)/smoothness
     ddjfunct = (fac-1d0) * ddjscaled(xx) / smoothness**2
  else if (xval.le.(-1)*scalingdistance) then
     xx = (-xval-scalingdistance)/smoothness
     ddjfunct = (fac-1d0) * ddjscaled(xx) / smoothness**2
  else
     print *, "OOGABLAHd"; stop
  endif
end function ddjfunct

!! f happens to go from 0 to 1/2 on (0,1)

function fscaled(xval)
  implicit none
  real*8 :: fscaled,xval,pixval
  real*8, parameter :: pi = 3.14159265358979323844d0 !!TEMP

  if (xval.lt.0d0.or.xval.gt.1d0) then
     print *, "SCALEDERR F",xval; stop
  endif
  pixval=pi*xval
  fscaled = (-1d0)/12d0/pi * sin(pixval)**3 - 1d0/2d0/pi * sin(pixval) + xval/2d0
end function fscaled

function jscaled(xval)
  implicit none
  real*8 :: jscaled,xval,pixval
  real*8, parameter :: pi = 3.14159265358979323844d0 !!TEMP

  if (xval.lt.0d0.or.xval.gt.1d0) then
     print *, "SCALEDERR F",xval; stop
  endif
  pixval=pi*xval
  jscaled = 1d0/4d0 * cos(pixval)**3 - 3d0/4d0 * cos(pixval) + 0.5d0
end function jscaled

function djscaled(xval)
  implicit none
  real*8 :: djscaled,xval,pixval
  real*8, parameter :: pi = 3.14159265358979323844d0 !!TEMP

  if (xval.lt.0d0.or.xval.gt.1d0) then
     print *, "SCALEDERR F",xval; stop
  endif
  pixval=pi*xval
  djscaled = 0.75d0 * pi * sin(pixval)**3 

end function djscaled

function ddjscaled(xval)
  implicit none
  real*8 :: ddjscaled,xval,pixval
  real*8, parameter :: pi = 3.14159265358979323844d0 !!TEMP

  if (xval.lt.0d0.or.xval.gt.1d0) then
     print *, "SCALEDERR F",xval; stop
  endif
  pixval=pi*xval
  ddjscaled = 9d0/4d0*pi**2 * sin(pixval)**2 * cos(pixval)
end function ddjscaled




subroutine init_project(inspfs,spfsloaded,pot,halfniumpot,rkemod,proderivmod,skipflag,&
     bondpoints,bondweights,elecweights,elecradii,notused )
  use myparams
  use pmpimod
  use pfileptrmod
  use myprojectmod
  implicit none
  integer, intent(in) :: skipflag,notused
  integer ::  i,   spfsloaded,j,ii,jj,k,l,idim,ilow(3),ihigh(3)
  DATATYPE :: inspfs(totpoints, numspf),pot(totpoints),proderivmod(numr,numr),rkemod(numr,numr),&
       bondpoints(numr),bondweights(numr), elecweights(totpoints),elecradii(totpoints),&
       halfniumpot(totpoints)
#ifndef REALGO
  real*8 :: temppot(totpoints) !! AUTOMATIC
#endif
  real*8 :: rsum,pi
  character (len=2) :: th(4)

!! smooth exterior scaling
  DATATYPE :: scalefunction(totpoints,3), djacobian(totpoints,3), ddjacobian(totpoints,3)
  DATATYPE :: ffunct, djfunct, ddjfunct, jfunct

  if (fft_mpi_inplaceflag.eq.0) then
     call ct_init(fft_ct_paropt)
  endif

  rkemod(:,:)=0d0; proderivmod(:,:)=0d0; bondpoints(:)=1d0; bondweights(:)=1d0

  elecweights(:)=(1d0/spacing)**griddim

  do idim=1,griddim

     call sineDVR(kevect(idim)%rmat(:),fdvect(idim)%rmat(:), sinepoints(idim)%mat(:,:),gridpoints(idim),spacing)

     kevect(idim)%cmat(:)=kevect(idim)%rmat(:)
     fdvect(idim)%cmat(:)=fdvect(idim)%rmat(:)

     ii=0
     do i=1,nbox(idim)
        do j=1,numpoints(idim)
           ii=ii+1
           jj=0
           do k=1,nbox(idim)
              do l=1,numpoints(idim)
                 jj=jj+1
                 ketot(idim)%mat(l,k,j,i)=kevect(idim)%rmat(ii-jj)
                 fdtot(idim)%mat(l,k,j,i)=fdvect(idim)%rmat(ii-jj)
              enddo
           enddo
        enddo
     enddo
  enddo

  th=(/ "st", "nd", "rd", "th" /)

!!$  if (skipflag.gt.1) then
!!$     return
!!$  endif

  call get_dipoles()


  if (scalingflag.ne.0) then

     if (debugflag.eq.54321) then
        OFLWR "#Testing scaling..."; CFL
        if (myrank.eq.1) then
           open(76333,file="Contour.Dat",status="unknown")
           do i=-100,100
              rsum=i/100d0*spacing*gridpoints(1)/2d0
              write(76333,'(100F12.5)') rsum, ffunct(rsum), jfunct(rsum), djfunct(rsum), ddjfunct(rsum)
           enddo
           close(76333)
        endif
        call mpibarrier()
        OFLWR "#Done testing scaling"; CFLST
     endif

     OFLWR "Getting scaling..."; CFL

     do idim=1,3
        do i=1,totpoints
           scalefunction(i,idim)=ffunct(real(dipoles(i,idim),8))
           jacobian(i,idim)=jfunct(real(dipoles(i,idim),8))
           djacobian(i,idim)=djfunct(real(dipoles(i,idim),8))
           ddjacobian(i,idim)=ddjfunct(real(dipoles(i,idim),8))
        enddo
     enddo

     invjacobian(:,:)=1d0/jacobian(:,:)

     invsqrtjacobian(:,:)=sqrt(invjacobian(:,:))

     invsqrtscaleweights(:) = sqrt(invjacobian(:,1)) * sqrt(invjacobian(:,2)) *  sqrt(invjacobian(:,3))

     scaleweights13(:) = (jacobian(:,1))**(1d0/3d0) * (jacobian(:,2))**(1d0/3d0) * (jacobian(:,3))**(1d0/3d0)
     invscaleweights13(:) = 1d0/scaleweights13(:)

     scaleweights16(:)=sqrt(scaleweights13(:))
     invscaleweights16(:)=sqrt(invscaleweights13(:))

!!     scaleweights13(:) = 1d0
!!     invscaleweights13(:) = 1d0

     scalediag(:)=0d0
     do jj=1,3
        scalediag(:)=scalediag(:) + 3d0/8d0 * invjacobian(:,jj)**4 * djacobian(:,jj)**2 &
             - 1d0/4d0 * invjacobian(:,jj)**3 * ddjacobian(:,jj)
     enddo

     elecweights(:)=elecweights(:)*jacobian(:,1)*jacobian(:,2)*jacobian(:,3)

     dipoles(:,:)=scalefunction(:,:)
     OFLWR "    ....Ok got scaling."; CFL
  endif

  elecradii(:)=sqrt( dipoles(:,1)**2 + dipoles(:,2)**2 + dipoles(:,3)**2)
   
  call get_twoe_new(pot)

  if (debugflag .eq. 4040) then
     pot(:) = 0.35d0 * elecradii(:)**2 * ( &
          exp((-0.13d0)*(dipoles(:,1)**2+dipoles(:,2)**2+(dipoles(:,3)-2d0)**2)) + &
          exp((-0.13d0)*(dipoles(:,1)**2+dipoles(:,2)**2+(dipoles(:,3)+2d0)**2)) )
     threed_two(:,:,:)=0d0
  else if (debugflag .eq. 4242) then
     pot(:) = 7.5d0 * elecradii(:)**2 * exp((-1)*elecradii(:))
     threed_two(:,:,:)=0d0
  else if (debugflag.eq.4343) then
     pot(:) = 4.5d0 * elecradii(:)**2 
     threed_two(:,:,:)=0d0
  endif

#ifndef REALGO

  if (capflag.gt.0) then
     temppot(:)=0d0
     do i=1,capflag
        if (capmode.eq.1) then
           temppot(:)=temppot(:) + capstrength(i)*( real(elecradii(:),8)/capstart(i) )**cappower(i)
        else
           temppot(:)=temppot(:) + capstrength(i)*( max(0d0,real(elecradii(:),8)-capstart(i)) )**cappower(i)
        endif
     enddo
     temppot(:)= min(maxcap,max(mincap,temppot(:)))
     pot(:)=pot(:) + (0d0,-1d0) * temppot(:)
  endif
#endif

  ilow(1:3)=1
  ihigh(1:3)=gridpoints(1:3)

  if (orbparflag) then
     ilow(orbparlevel:3)=(boxrank(orbparlevel:3)-1)*numpoints(orbparlevel:3)+1
     ihigh(orbparlevel:3)=boxrank(orbparlevel:3)*numpoints(orbparlevel:3)
  endif

  pi=4d0*atan(1d0)

  if (maskflag.ne.0) then
     do jj=1,3
        maskfunction(jj)%rmat(:)=1d0
        do ii=1,masknumpoints

           rsum=( 1d0 + cos(pi*ii/(masknumpoints+1)) ) / 2d0

           i=masknumpoints+1-ii

           if (i.ge.ilow(jj).and.i.le.ihigh(jj)) then
              maskfunction(jj)%rmat(i+1-ilow(jj)) = maskfunction(jj)%rmat(i+1-ilow(jj)) * rsum
           endif

           i=gridpoints(jj)-masknumpoints+ii

           if (i.ge.ilow(jj).and.i.le.ihigh(jj)) then
              maskfunction(jj)%rmat(i+1-ilow(jj)) = maskfunction(jj)%rmat(i+1-ilow(jj)) * rsum
           endif
        enddo
     enddo
  endif

  halfniumpot(:)=pot(:)/sumcharge

  if (spfsloaded.lt.numspf) then
     call frozen_matels()
     call init_spfs(inspfs(:,:),spfsloaded)
  endif

  spfsloaded=numspf   !! for mcscf... really just for BO curve to skip eigen

  if (debugflag.eq.90210) then
     OFLWR "TEMPSTOP init_project debugflag 90210"; CFLST
  endif

end subroutine init_project


subroutine mult_bigspf(inbigspf,outbigspf)
  use myparams
  implicit none
  DATATYPE,intent(in) :: inbigspf(totpoints)
  DATATYPE, intent(out) :: outbigspf(totpoints)
  if (ivoflag.eq.0) then
     call mult_bigspf0(inbigspf,outbigspf)
  else
     call mult_bigspf_ivo(inbigspf,outbigspf)
  endif
end subroutine mult_bigspf


subroutine mult_bigspf0(inbigspf,outbigspf)
  use myparams
  implicit none
  DATATYPE,intent(in) :: inbigspf(totpoints)
  DATATYPE, intent(out) :: outbigspf(totpoints)
  DATATYPE :: tempspf(totpoints)

  call mult_ke(inbigspf(:),outbigspf(:),1,"booga",2)
  call mult_pot(inbigspf(:),tempspf(:))
  outbigspf(:)=outbigspf(:)+tempspf(:)

end subroutine mult_bigspf0


function ivodot(inbra,inket,size)
  use myparams
  implicit none
  integer,intent(in) :: size 
  DATATYPE,intent(in) :: inbra(size),inket(size)
  DATATYPE :: ivodot,csum
  csum=DOT_PRODUCT(inbra,inket)
  if (orbparflag) then
     call mympireduceone(csum)
  endif
  ivodot=csum
end function ivodot


module ivopotmod
  implicit none
  integer :: numocc=(-1)
  DATATYPE, allocatable :: ivopot(:),ivo_occupied(:,:)
end module ivopotmod


subroutine ivo_project(inbigspf,outbigspf)
  use myparams
  use ivopotmod
  implicit none
  DATATYPE,intent(in) :: inbigspf(totpoints)
  DATATYPE, intent(out) :: outbigspf(totpoints)
  DATATYPE :: ivodot
  integer :: ii
  outbigspf(:)=0d0
  do ii=1,numocc
     outbigspf(:)=outbigspf(:) + ivo_occupied(:,ii) * ivodot(ivo_occupied(:,ii),inbigspf(:),totpoints)
  enddo
end subroutine ivo_project

  
subroutine mult_bigspf_ivo(inbigspf,outbigspf)
  use myparams
  use ivopotmod
  implicit none
  DATATYPE,intent(in) :: inbigspf(totpoints)
  DATATYPE, intent(out) :: outbigspf(totpoints)
  DATATYPE :: tempspf(totpoints),inwork(totpoints),inwork2(totpoints),&
       workspf(totpoints)

  call ivo_project(inbigspf,outbigspf)
  call project_onfrozen(inbigspf,workspf)
  outbigspf=outbigspf+workspf

  inwork2(:)=inbigspf(:)-outbigspf(:)

  outbigspf(:)=outbigspf(:) * (1d2)

  call mult_ke(inwork2(:),inwork(:),1,"booga",2)

  call mult_pot(inwork2(:),tempspf(:))

  inwork(:) = inwork(:) + tempspf(:) + ivopot(:)*inwork2(:)

  call ivo_project(inwork,inwork2)
  call project_onfrozen(inwork,workspf)
  inwork2=inwork2+workspf

  outbigspf(:) = outbigspf(:) + inwork(:) - inwork2(:)


end subroutine mult_bigspf_ivo



subroutine init_spfs(inspfs,numloaded)
  use myparams
  use pmpimod
  use pfileptrmod
  use ivopotmod
  use twoemod
  implicit none
  DATATYPE :: inspfs(totpoints,numspf)
  DATATYPE,allocatable :: lanspfs(:,:),density(:), energies(:)
  integer, intent(in) :: numloaded
  integer :: ibig,iorder,ispf,ppfac,ii,jj,kk,olist(numspf),flag
  integer :: null1,null2,null3,null4,null10(10),numcompute
  external :: mult_bigspf

  if (ivoflag.ne.0) then
     if (numloaded.le.0) then
        OFLWR "error, for ivo must load orbitals",numloaded; CFLST
     endif
     numcompute = numspf + max(0,num_skip_orbs) - numloaded
  else
     numcompute = numspf + num_skip_orbs
  endif

  if (numcompute.lt.0) then
     OFLWR "error numcompute lt 0 ", numloaded,numspf; CFLST
  endif
  if (numcompute.eq.0) then
     OFLWR "numcompute eq 0 RETURN"; CFL
     return
  endif
  if (numspf-numloaded.le.0) then
     OFLWR "numget eq 0 return", numspf-numloaded; CFL
     return
  endif

  if (ivoflag.ne.0) then
     kk=0
  else
     if (num_skip_orbs.lt.0) then
        kk=numloaded+num_skip_orbs
     else
        kk=numloaded
     endif
  endif

  ii=1
  do while (ii.le.numspf-numloaded)
     kk=kk+1
     flag=0
     do jj=1,num_skip_orbs
        if (orb_skip(jj).eq.kk) then
           flag=1
           exit
        endif
     enddo
     if (flag.eq.0) then
        olist(ii)=kk
        ii=ii+1
     endif
  enddo

  if (kk.gt.numcompute) then
     OFLWR "FSFFD EEEEE 555",kk,numspf,num_skip_orbs; CFLST
  endif

  if (ivoflag.ne.0) then
     OFLWR "getting IVO pot.  occupations are "
     WRFL loadedocc(1:numloaded); CFL

     allocate(ivopot(totpoints), density(totpoints),ivo_occupied(totpoints,numloaded))
     ivopot(:)=0d0; density(:)=0d0

     numocc=numloaded
     ivo_occupied(:,:)=inspfs(:,1:numloaded)
     do ispf=1,numloaded

        call myhgramschmidt_fast(totpoints,ispf-1,totpoints,ivo_occupied(:,:),ivo_occupied(:,ispf),orbparflag)

        density(:)=density(:)+abs(ivo_occupied(:,ispf)**2)*loadedocc(ispf)
     enddo
     call op_tinv(density,ivopot,1,1,null1,null2,null3,null4,null10)
     deallocate(density)

     ivopot(:)=ivopot(:)+frozenreduced(:)*2

  endif

  allocate(lanspfs(totpoints,numcompute),energies(numcompute))

  ibig=totpoints
  iorder=min(ibig,orblanorder)
  ppfac=1
  if (orbparflag) then
     ppfac=nprocs
  endif

  OFLWR "CALL BLOCK LAN FOR ORBS, ",numcompute," VECTORS"; CFL

  call blocklanczos0(min(3,numspf),numcompute,ibig,ibig,iorder,ibig*ppfac,lanspfs,ibig,energies,1,0,orblancheckmod,orblanthresh,mult_bigspf,orbparflag,orbtargetflag,orbtarget)

  if (ivoflag.ne.0) then
     deallocate(ivopot,ivo_occupied)
  endif
  
  OFLWR "BL CALLED. ENERGIES: ";CFL
  do ispf=1,numcompute
     OFLWR ispf,energies(ispf); CFL
  enddo
  OFLWR;  CFL

  do ispf=1,numspf-numloaded
     inspfs(:,ispf+numloaded)=lanspfs(:,olist(ispf))
  enddo

  deallocate(lanspfs,energies)

end subroutine init_spfs

!! fixed nuclei only for now

subroutine nucdipvalue(notused,dipoles)
  use myparams
  implicit none
  DATATYPE :: notused(1),dipoles(3)
  integer :: i
  dipoles(:)=0d0
  do i=1,numcenters
     dipoles(:)=dipoles(:) + nuccharges(i) * centershift(:,i)/2d0 * spacing
  enddo
end subroutine nucdipvalue

