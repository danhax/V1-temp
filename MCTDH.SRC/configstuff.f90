
#include "Definitions.INC"

subroutine printconfig(thisconfig,www)
  use walkmod
  use fileptrmod
  implicit none

  type(walktype),intent(in) :: www
  integer,intent(in) :: thisconfig(www%ndof)
  character (len=4) :: mslabels(2) =["a ","b "]
  integer :: i

  write(mpifileptr,'(100(I3,A2))') (thisconfig((i-1)*2+1), mslabels(thisconfig(i*2)), i=1,www%numelec)

end subroutine printconfig


!! NOT - this uses stopthresh as threshold to pass to laneigen.  is called for mcscf, and improved.


subroutine myconfigeig(www,dfww,cptr,thisconfigvects,thisconfigvals,order,printflag, guessflag,time,numshift)
  use fileptrmod
  use r_parameters
  use sparse_parameters
  use mpimod
  use configptrmod
  use walkmod
  implicit none
  type(walktype),intent(in) :: www,dfww
  type(CONFIGPTR),intent(in) :: cptr
  integer,intent(in) :: order,printflag,guessflag,numshift
  DATATYPE,intent(out) :: thisconfigvects(www%totadim,order)
  DATAECS,intent(out) :: thisconfigvals(order)
  real*8,intent(in) :: time
  real*8,allocatable :: realconfigvect(:)
  DATATYPE, allocatable :: fullconfigmatel(:,:), fullconfigvects(:,:), &
       tempconfigvects(:,:)
  DATAECS, allocatable :: fullconfigvals(:)
  DATAECS ::  tempconfigvals(order+numshift)
  DATATYPE :: lastval,dot
  integer :: i,flag

  if (order+numshift.gt.www%numconfig*numr) then
     OFLWR "Error, want ",order," plus ",numshift," vectors but totadim= ",www%numconfig*numr;CFLST
  endif
  if (numshift.lt.0) then
     OFLWR "GG ERROR.", numshift,guessflag; CFLST
  endif

  if (www%numdfbasis.ne.dfww%numdfbasis) then
     OFLWR "ERROR DF SETS MYCONFIGEIG",www%numdfbasis,dfww%numdfbasis; CFLST
  endif

  if (sparseconfigflag/=0) then
     
     allocate(tempconfigvects(www%totadim,order+numshift))
     tempconfigvects(:,:)=0d0
     if (guessflag.ne.0) then
        allocate(realconfigvect(www%totadim))
        do i=1,numshift
           call RANDOM_NUMBER(realconfigvect(:))
           tempconfigvects(:,i)=realconfigvect(:)
        enddo
        tempconfigvects(:,numshift+1:order+numshift)=thisconfigvects(:,1:order)
        deallocate(realconfigvect)
     endif
     call blocklanczos(order+numshift,tempconfigvects,tempconfigvals,printflag,guessflag)
     
        !! so if guessflag=1, numshift is 0.

     thisconfigvals(1:order)=tempconfigvals(numshift+1:numshift+order)
     thisconfigvects(:,1:order)=tempconfigvects(:,numshift+1:numshift+order)
     deallocate(tempconfigvects)

  else

     if (printflag.ne.0) then
        OFLWR "Construct big matrix:  ", www%numdfbasis*numr; CFL
     endif
     allocate(fullconfigvals(www%numdfbasis*numr))
     allocate(fullconfigmatel(www%numdfbasis*numr,www%numdfbasis*numr), fullconfigvects(www%numconfig*numr,www%numdfbasis*numr))
     allocate(tempconfigvects(www%numdfbasis*numr,www%numdfbasis*numr))
     fullconfigmatel=0.d0; fullconfigvects=0d0; fullconfigvals=0d0; tempconfigvects=0d0

     call assemble_dfbasismat(dfww,fullconfigmatel,cptr,1,1,0,0, time,-1)

     if (printflag.ne.0) then
        OFLWR " Call eig ",www%numdfbasis*numr; CFL
     endif
     if (myrank.eq.1) then
        call CONFIGEIG(fullconfigmatel(:,:),www%numdfbasis*numr,www%numdfbasis*numr, tempconfigvects, fullconfigvals)
     endif

     call mympibcast(tempconfigvects,1,www%numdfbasis*numr*www%numdfbasis*numr)
#ifndef ECSFLAG
#ifndef REALGO
     call mympirealbcast(fullconfigvals,1,www%numdfbasis*numr)
#else
     call mympibcast(fullconfigvals,1,www%numdfbasis*numr)
#endif
#else
     call mympibcast(fullconfigvals,1,www%numdfbasis*numr)
#endif
     do i=1,www%numdfbasis*numr
        call basis_transformfrom_all(www,numr,tempconfigvects(:,i),fullconfigvects(:,i))
     enddo

     call mpibarrier()

     if (printflag.ne.0) then
        OFLWR "  -- Nonsparse eigenvals --"
        do i=1,min(www%numdfbasis*numr,numshift+order+10)
           WRFL "   ", fullconfigvals(i)
        enddo
        CFL
     endif

     thisconfigvects(:,1:order) = fullconfigvects(:,1+numshift:order+numshift)
     thisconfigvals(1:order) = fullconfigvals(1+numshift:order+numshift)

     lastval = -99999999d0
     flag=0
     do i=1,order
        thisconfigvects(:,i)=thisconfigvects(:,i) / sqrt(dot(thisconfigvects(:,i),thisconfigvects(:,i),www%totadim))
        if (abs(thisconfigvals(i)-lastval).lt.1d-7) then
           flag=flag+1
           call gramschmidt(www%totadim,flag,www%totadim,thisconfigvects(:,i-flag),thisconfigvects(:,i),.false.)
        else
           flag=0
        endif
        lastval=thisconfigvals(i)
     enddo

     deallocate(fullconfigmatel, fullconfigvects, fullconfigvals,tempconfigvects)

  endif

!!$ REMOVED THIS FOR PARCONSPLIT 12-2015 v1.16 REINSTATE?
!!$  
!!$  !! this is called from either eigs (for which is irrelevant) or from 
!!$  !! config_eigen, which is used to start avectors as improved relax or at
!!$  !! start of prop with eigenflag.  Leave as c-normed; in config_eigen, 
!!$  !! herm-norm.
!!$  !! fix phase for chmctdh/pmctdh debug check
!!$  
!!$    l=-99
!!$    do i=1,order
!!$       sum=(-999d0)
!!$       do k=1,www%totadim
!!$          if (abs(thisconfigvects(k,i)).gt.sum) then
!!$             sum=abs(thisconfigvects(k,i));           l=k
!!$          endif
!!$       enddo
!!$       thisconfigvects(:,i)=thisconfigvects(:,i)*abs(thisconfigvects(l,i))/thisconfigvects(l,i)
!!$    enddo

end subroutine myconfigeig



!! PROPAGATE A-VECTOR .  CALLED WITHIN LITTLESTEPS LOOP

subroutine myconfigprop(www,dfww,avectorin,avectorout,time,imc,numiters)
  use r_parameters
  use sparse_parameters
  use walkmod 
  implicit none
  type(walktype),intent(in) :: www,dfww
  integer,intent(in) :: imc
  integer,intent(out) :: numiters
  real*8,intent(in) :: time
  DATATYPE,intent(in) :: avectorin(www%totadim)
  DATATYPE,intent(out) :: avectorout(www%totadim)

  numiters=0
  if (sparseconfigflag/=0) then
     call exposparseprop(www,avectorin,avectorout,time,imc,numiters)
  else
     call nonsparseprop(www,dfww,avectorin,avectorout,time,imc)
  endif

  call basis_project(www,numr,avectorout)

end subroutine myconfigprop


subroutine nonsparseprop(www,dfww,avectorin,avectorout,time,imc)
  use fileptrmod
  use sparse_parameters
  use ham_parameters
  use r_parameters
  use mpimod
  use configpropmod
  use walkmod
  implicit none
  type(walktype),intent(in) :: www,dfww
  integer, intent(in) :: imc
  DATATYPE,intent(in) :: avectorin(www%totadim)
  DATATYPE,intent(out) :: avectorout(www%totadim)
  DATATYPE :: avectortemp(www%numdfbasis*numr), avectortemp2(www%numdfbasis*numr) !! AUTOMATIC
  DATATYPE, allocatable :: bigconfigmatel(:,:), bigconfigvects(:,:) !!,bigconfigvals(:)
#ifndef REALGO
  real*8, allocatable :: realbigconfigmatel(:,:,:,:)
#endif
  integer, allocatable :: iiwork(:)
  integer :: iflag
  real*8 :: time

  if (sparseconfigflag/=0) then
     OFLWR "Error, nonsparseprop called but sparseconfigflag= ", sparseconfigflag; CFLST
  endif
  if (drivingflag.ne.0) then
     OFLWR "Driving flag not implemented for nonsparse"; CFLST
  endif

  if (www%numdfbasis.ne.dfww%numdfbasis) then
     OFLWR "ERROR DF SETS NONSPARSEOPROP",www%numdfbasis,dfww%numdfbasis; CFLST
  endif

  allocate(iiwork(www%numdfbasis*numr*2))

  allocate(bigconfigmatel(www%numdfbasis*numr,www%numdfbasis*numr), bigconfigvects(www%numdfbasis*numr,2*(www%numdfbasis*numr+2)))

  call assemble_dfbasismat(dfww,bigconfigmatel, workconfigpointer,1,1,1,1, time,imc)

  bigconfigmatel=bigconfigmatel*timefac

  call basis_transformto_all(www,numr,avectorin,avectortemp)

  if (myrank.eq.1) then
     if (nonsparsepropmode.eq.1) then
        avectortemp2(:)=avectortemp(:)
        call expmat(bigconfigmatel,www%numdfbasis*numr) 
        call MYGEMV('N',www%numdfbasis*numr,www%numdfbasis*numr,DATAONE,bigconfigmatel,www%numdfbasis*numr,avectortemp2,1,DATAZERO,avectortemp,1)
#ifndef REALGO
     else if (nonsparsepropmode.eq.2) then
        allocate(realbigconfigmatel(2,www%numdfbasis*numr,2,www%numdfbasis*numr))
        call assigncomplexmat(realbigconfigmatel,bigconfigmatel,www%numdfbasis*numr,www%numdfbasis*numr)
        call DGCHBV(www%numdfbasis*numr*2, 1.d0, realbigconfigmatel, www%numdfbasis*numr*2, avectortemp, bigconfigvects, iiwork, iflag)           
        deallocate(realbigconfigmatel)
#endif
     else
        call EXPFULL(www%numdfbasis*numr, DATAONE, bigconfigmatel, www%numdfbasis*numr, avectortemp, bigconfigvects, iiwork, iflag)
        
        if (iflag.ne.0) then
           OFLWR "Expo error A ", iflag; CFLST
        endif
     endif
  endif

  call mympibcast(avectortemp,1,www%numdfbasis*numr)

  call basis_transformfrom_all(www,numr,avectortemp,avectorout)

  deallocate(iiwork,bigconfigmatel,bigconfigvects)

end subroutine nonsparseprop




!! MULTIPLY BY A-VECTOR HAMILTONIAN MATRIX

!! NOTE BOUNDS !!  PADDED

subroutine parconfigexpomult_padded(inavector,outavector)
  use fileptrmod
  use r_parameters
  use sparse_parameters
  use ham_parameters   !! timefac
  use mpimod
  use configexpotimemod
  use configpropmod
  use configmod
  implicit none
  DATATYPE,intent(in) :: inavector(numr,www%botdfbasis:www%botdfbasis+www%maxdfbasisperproc-1)
  DATATYPE,intent(out) :: outavector(numr,www%botdfbasis:www%botdfbasis+www%maxdfbasisperproc-1)

#ifdef MPIFLAG
  select case (sparsesummaflag)
  case(0)
#endif
     if (use_dfwalktype) then
        call parconfigexpomult_padded0_gather(dwwptr,workconfigpointer,workdfsparsepointer,inavector,outavector)
     else
        call parconfigexpomult_padded0_gather(dwwptr,workconfigpointer,worksparsepointer,inavector,outavector)
     endif

#ifdef MPIFLAG
  case(1)
     if (use_dfwalktype) then
        call parconfigexpomult_padded0_summa(dwwptr,workconfigpointer,workdfsparsepointer,inavector,outavector)
     else
        call parconfigexpomult_padded0_summa(dwwptr,workconfigpointer,worksparsepointer,inavector,outavector)
     endif
  case(2)
     if (use_dfwalktype) then
        call parconfigexpomult_padded0_circ(dwwptr,workconfigpointer,workdfsparsepointer,inavector,outavector)
     else
        call parconfigexpomult_padded0_circ(dwwptr,workconfigpointer,worksparsepointer,inavector,outavector)
     endif
  case default
     OFLWR "Error sparsesummaflag ",sparsesummaflag; CFLST
  end select
#endif

end subroutine parconfigexpomult_padded



subroutine parconfigexpomult_padded0_gather(www,workconfigpointer,worksparsepointer,inavector,outavector)
  use fileptrmod
  use r_parameters
  use sparse_parameters
  use ham_parameters   !! timefac
  use mpimod
  use configexpotimemod
  use walkmod
  use configptrmod
  use sparseptrmod
  implicit none
  type(walktype),intent(in) :: www
  type(CONFIGPTR),intent(in) :: workconfigpointer
  type(SPARSEPTR),intent(in) :: worksparsepointer
  DATATYPE,intent(in) :: inavector(numr,www%botdfbasis:www%botdfbasis+www%maxdfbasisperproc-1)
  DATATYPE,intent(out) :: outavector(numr,www%botdfbasis:www%botdfbasis+www%maxdfbasisperproc-1)
  DATATYPE,allocatable :: intemp(:,:)
  DATATYPE :: outtemp(numr,www%botconfig:www%topconfig)  !! AUTOMATIC

  call avectortime(3)

  if (sparseconfigflag.eq.0) then
     OFLWR "error, must use sparse for parconfigexpomult"; CFLST
  endif
  
  allocate(intemp(numr,www%numconfig))
  intemp(:,:)=0d0

!! transform second to reduce communication?
!!   no, spin transformations done locally now.

  if (www%topconfig-www%botconfig+1 .ne. 0) then
     call basis_transformfrom_local(www,numr,inavector,intemp(:,www%botconfig:www%topconfig))
  endif

  call mpiallgather(intemp,www%numconfig*numr,www%configsperproc(:)*numr,www%maxconfigsperproc*numr)

  call sparseconfigmult_byproc(1,nprocs,www,intemp,outtemp, workconfigpointer, worksparsepointer, 1,1,1,1,configexpotime,0,1,numr,0,imc)
     
  outavector(:,:)=0d0   !! PADDED

  call basis_transformto_local(www,numr,outtemp,outavector)

  outavector=outavector*timefac

  deallocate(intemp)

  call avectortime(2)

end subroutine parconfigexpomult_padded0_gather



#ifdef MPIFLAG

subroutine parconfigexpomult_padded0_summa(www,workconfigpointer,worksparsepointer,inavector,outavector)
  use fileptrmod
  use r_parameters
  use sparse_parameters
  use ham_parameters   !! timefac
  use mpimod
  use configexpotimemod
  use walkmod
  use configptrmod
  use sparseptrmod
  implicit none
  type(walktype),intent(in) :: www
  type(CONFIGPTR),intent(in) :: workconfigpointer
  type(SPARSEPTR),intent(in) :: worksparsepointer
  DATATYPE,intent(in) :: inavector(numr,www%botdfbasis:www%botdfbasis+www%maxdfbasisperproc-1)
  DATATYPE,intent(out) :: outavector(numr,www%botdfbasis:www%botdfbasis+www%maxdfbasisperproc-1)
  DATATYPE :: intemp(numr,www%maxconfigsperproc), outwork(numr,www%botconfig:www%topconfig),&
       outtemp(numr,www%botconfig:www%topconfig)   !! AUTOMATIC
  integer :: iproc

  call avectortime(3)

  if (sparseconfigflag.eq.0) then
     OFLWR "error, must use sparse for parconfigexpomult"; CFLST
  endif
  
  outwork(:,:)=0d0

  do iproc=1,nprocs

!! transform second to reduce communication?
!!   no, spin transformations done locally now.

     if (myrank.eq.iproc) then
        call basis_transformfrom_local(www,numr,inavector,intemp)
     endif

     call mympibcast(intemp,iproc,(www%alltopconfigs(iproc)-www%allbotconfigs(iproc)+1)*numr)

     call sparseconfigmult_byproc(iproc,iproc,www,intemp,outtemp, workconfigpointer, worksparsepointer, 1,1,1,1,configexpotime,0,1,numr,0,imc)
     
     outwork(:,:)=outwork(:,:)+outtemp(:,:)

  enddo

  outavector(:,:)=0d0   !! PADDED

  call basis_transformto_local(www,numr,outwork,outavector)

  outavector=outavector*timefac
  
  call avectortime(2)

end subroutine parconfigexpomult_padded0_summa



subroutine parconfigexpomult_padded0_circ(www,workconfigpointer,worksparsepointer,inavector,outavector)
  use fileptrmod
  use r_parameters
  use sparse_parameters
  use ham_parameters   !! timefac
  use mpimod
  use configexpotimemod
  use walkmod
  use configptrmod
  use sparseptrmod
  implicit none
  type(walktype),intent(in) :: www
  type(CONFIGPTR),intent(in) :: workconfigpointer
  type(SPARSEPTR),intent(in) :: worksparsepointer
  DATATYPE,intent(in) :: inavector(numr,www%botdfbasis:www%botdfbasis+www%maxdfbasisperproc-1)
  DATATYPE,intent(out) :: outavector(numr,www%botdfbasis:www%botdfbasis+www%maxdfbasisperproc-1)
  DATATYPE :: workvector(numr,www%maxconfigsperproc), workvector2(numr,www%maxconfigsperproc),&
       outwork(numr,www%botconfig:www%topconfig),  outtemp(numr,www%botconfig:www%topconfig)  !! AUTOMATIC
  integer :: iproc,prevproc,nextproc,deltaproc

  call avectortime(3)

  if (sparseconfigflag.eq.0) then
     OFLWR "error, must use sparse for parconfigexpomult"; CFLST
  endif

!! doing circ mult slightly different than e.g. SINCDVR/coreproject.f90 and ftcore.f90, 
!!     holding hands in a circle, prevproc and nextproc, each chunk gets passed around the circle
  prevproc=mod(nprocs+myrank-2,nprocs)+1
  nextproc=mod(myrank,nprocs)+1

  outwork(:,:)=0d0

  call basis_transformfrom_local(www,numr,inavector,workvector)

  do deltaproc=0,nprocs-1

!! PASSING BACKWARD (plus deltaproc)
     iproc=mod(myrank-1+deltaproc,nprocs)+1

     call sparseconfigmult_byproc(iproc,iproc,www,workvector,outtemp, workconfigpointer, worksparsepointer, &
          1,1,1,1,configexpotime,0,1,numr,0,imc)
     
     outwork(:,:)=outwork(:,:)+outtemp(:,:)

!! PASSING BACKWARD
!! mympisendrecv(sendbuf,recvbuf,dest,source,...)

     call mympisendrecv(workvector,workvector2,prevproc,nextproc,deltaproc,&
          numr * www%maxconfigsperproc)
     workvector(:,:)=workvector2(:,:)

  enddo

  outavector(:,:)=0d0   !! PADDED

  call basis_transformto_local(www,numr,outwork,outavector)

  outavector=outavector*timefac
  
  call avectortime(2)

end subroutine parconfigexpomult_padded0_circ


#endif




