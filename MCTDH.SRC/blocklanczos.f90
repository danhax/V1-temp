
#include "Definitions.INC"



subroutine blocklanczos( order,outvectors, outvalues,inprintflag,guessflag)
  use parameters
  implicit none 

  integer :: inprintflag,printflag,guessflag,order,maxdim,vdim,i,mytop,mybot, calcsize
  DATATYPE, intent(out) :: outvalues(order)
  DATATYPE :: outvectors(numconfig,numr,order)
  DATATYPE, allocatable :: tempoutvectorstr(:,:,:),outvectorstr(:,:,:), initvectors(:,:,:), outvectorsspin(:,:,:)

  external :: parblockconfigmult_transpose, parblockconfigmult_transpose_spin

  printflag=max(lanprintflag,inprintflag)

  if (allspinproject.ne.0) then
     calcsize=spintotrank;   mytop=spinend; mybot=spinstart
  else
     calcsize=numconfig;    mytop=topwalk; mybot=botwalk
  endif

  if (dfrestrictflag.eq.0) then
     maxdim=calcsize*numr
  else
     if (allspinproject.ne.0) then
        maxdim=spintotdfrank*numr
     else
        maxdim=numdfconfigs*numr
     endif
  endif


  vdim=(mytop-mybot+1)*numr

  allocate(tempoutvectorstr(numr,mybot:mytop,order),outvectorstr(numr,order,calcsize), initvectors(calcsize,numr,order), &
       outvectorsspin(calcsize,numr,order))

  tempoutvectorstr(:,:,:)=0d0

  if (guessflag.ne.0) then
     if (allspinproject.eq.0) then
        initvectors(:,:,:)=outvectors(:,:,:)  
     else
        call configspin_transformto(numr*order,outvectors,initvectors)
     endif
  
     do i=1,order
        tempoutvectorstr(:,:,i)=TRANSPOSE(initvectors(mybot:mytop,:,i))
     enddo
  endif

  if (allspinproject.eq.0) then
     call blocklanczos0(order,order,vdim,vdim,lanczosorder,maxdim,tempoutvectorstr,vdim,outvalues,printflag,guessflag,lancheckstep,lanthresh,parblockconfigmult_transpose,.true.)
  else
     call blocklanczos0(order,order,vdim,vdim,lanczosorder,maxdim,tempoutvectorstr,vdim,outvalues,printflag,guessflag,lancheckstep,lanthresh,parblockconfigmult_transpose_spin,.true.)
  endif

  outvectorstr(:,:,:)=0d0

  do i=1,order
     outvectorstr(:,i,mybot:mytop)=tempoutvectorstr(:,:,i)
  enddo

  if (allspinproject.eq.0) then

     call mpiallgather(outvectorstr,calcsize*numr*order,configsperproc*numr*order,maxconfigsperproc*numr*order)

     do i=1,order
        outvectors(:,:,i)=TRANSPOSE(outvectorstr(:,i,:))
     enddo
  else

     call mpiallgather(outvectorstr,calcsize*numr*order,allspinranks*numr*order,maxspinrank*numr*order)

     do i=1,order
        outvectorsspin(:,:,i)=TRANSPOSE(outvectorstr(:,i,:))
     enddo
     outvectors(:,:,:)=0d0
     call configspin_transformfrom(numr*order,outvectorsspin,outvectors)
  endif

  deallocate(tempoutvectorstr,outvectorstr, initvectors,       outvectorsspin)

end subroutine blocklanczos



function hdot(in,out,n,logpar)
  use parameters
  implicit none
  integer :: n
  logical :: logpar
  DATATYPE :: in(n),out(n),hdot
  hdot=DOT_PRODUCT(in,out)
  if (logpar) then
     call mympireduceone(hdot)
  endif
end function hdot

function thisdot(in,out,n,logpar)
  use parameters
  implicit none
  integer :: n
  logical :: logpar
  DATATYPE :: in(n),out(n),thisdot,dot
  thisdot=dot(in,out,n)
  if (logpar) then
     call mympireduceone(thisdot)
  endif
end function thisdot


subroutine allhdots(bravectors,ketvectors,n,lda,num1,num2,outdots,logpar)
  use parameters
  implicit none

  integer :: id,jd,num1,num2,lda,n
  logical :: logpar
  DATATYPE :: bravectors(lda,num1), ketvectors(lda,num2), outdots(num1,num2)


  do id=1,num1
     do jd=1,num2
        outdots(id,jd)= DOT_PRODUCT(bravectors(1:n,id),ketvectors(1:n,jd))
     enddo
  enddo

  if (logpar) then
     call mympireduce(outdots,num1*num2)
  endif
end subroutine allhdots





subroutine alldots(bravectors,ketvectors,n,lda,num1,num2,outdots,logpar)
  use parameters
  implicit none

  integer :: id,jd,num1,num2,lda,n
  logical :: logpar
  DATATYPE :: bravectors(lda,num1), ketvectors(lda,num2), outdots(num1,num2),dot


  do id=1,num1
     do jd=1,num2
        outdots(id,jd)= dot(bravectors(1:n,id),ketvectors(1:n,jd),n)
     enddo
  enddo

  if (logpar) then
     call mympireduce(outdots,num1*num2)
  endif
end subroutine alldots



subroutine myhgramschmidt_fast(n, m, lda, previous, vector,logpar)
  use fileptrmod
  implicit none
  
! n is the length of the vectors; m is how many to orthogonalize to

  integer :: n,m,lda
  DATATYPE :: previous(lda,m), vector(n),hdot, myhdots(m)
  integer :: i,j
  DATATYPE :: norm
  logical :: logpar

  do j=1,2

!!     call allhdots(lanvects(:,:,1),multvectors(:,:),lansize,maxlansize,lanblocknum,lanblocknum,alpha)
     if (m.ne.0) then
        call allhdots(previous(:,:),vector,n,lda,m,1,myhdots,logpar)
     endif

    do i=1,m
!       vector=vector-previous(1:n,i)* hdot(previous(1:n,i),vector,n) 
       vector=vector-previous(1:n,i)*myhdots(i)                            !! only the same with previous perfectly orth
    enddo
    norm=sqrt(hdot(vector,vector,n,logpar))
    vector=vector/norm
    if (abs(norm).lt.1e-7) then
       OFLWR "Gram schmidt norm",norm,m; CFL
    endif
  enddo

end subroutine myhgramschmidt_fast


!!$ subroutine mygramschmidt_fast(n, m, lda, previous, vector)
!!$   use fileptrmod
!!$   implicit none
!!$   
!!$ ! n is the length of the vectors; m is how many to orthogonalize to
!!$ 
!!$   integer :: n,m,lda
!!$   DATATYPE :: previous(lda,m), vector(n),thisdot, mydots(m)
!!$   integer :: i,j
!!$   DATATYPE :: norm
!!$ 
!!$   do j=1,2
!!$ 
!!$      if (m.ne.0) then
!!$         call alldots(previous(:,:),vector,n,lda,m,1,mydots)
!!$      endif
!!$ 
!!$     do i=1,m
!!$        vector=vector-previous(1:n,i)*mydots(i)                            !! only the same with previous perfectly orth
!!$     enddo
!!$     norm=sqrt(thisdot(vector,vector,n))
!!$     vector=vector/norm
!!$     if (abs(norm).lt.1e-9) then
!!$        OFLWR "Gram schmidt norm",norm,m; CFL
!!$     endif
!!$   enddo
!!$ 
!!$ end subroutine mygramschmidt_fast




!subroutine myhgramschmidt_old(n, m, lda, previous, vector)
!  use fileptrmod
!  implicit none
!  
!! n is the length of the vectors; m is how many to orthogonalize to
!
!  integer :: n,m,lda
!  DATATYPE :: previous(lda,m), vector(n),hdot
!  integer :: i,j
!  DATATYPE :: norm
!
!!???????  OFLWR "not supported" ; CFLST   ! (no spin proj)
!
!  do j=1,2
!    do i=1,m
!       vector=vector-previous(1:n,i)* hdot(previous(1:n,i),vector,n) 
!    enddo
!    norm=sqrt(hdot(vector,vector,n))
!    vector=vector/norm
!    if (abs(norm).lt.1e-7) then
!       OFLWR "Gram schmidt norm",norm,m; CFL
!    endif
!  enddo
!
!end subroutine myhgramschmidt_old





!! TAKES TRANSPOSES AS INPUT AND OUTPUT

subroutine parblockconfigmult_transpose(inavectortr,outavectortr)
  use parameters
  use mpimod
  use xxxmod
  implicit none

  DATATYPE :: inavectortr(numr,botwalk:topwalk), outavectortr(numr,botwalk:topwalk)
  integer,save :: allochere=0
  DATATYPE,save,allocatable :: intemptr(:,:), ttvector(:,:), ttvector2(:,:)
  integer :: ir

  if (allochere.eq.0) then
     allocate(intemptr(numr,numconfig), ttvector(numconfig,numr), ttvector2(botwalk:topwalk,numr))
  endif
  allochere=1

  if (sparseconfigflag.eq.0) then
     OFLWR "error, must use sparse for parblockconfigmult_transpose"; CFLST
  endif

  intemptr(:,:)=0d0;   intemptr(:,botwalk:topwalk)=inavectortr(:,:)

  call mpiallgather(intemptr,numconfig*numr,configsperproc*numr,maxconfigsperproc*numr)
  
  
  ttvector(:,:)=TRANSPOSE(intemptr(:,:))
  
  if (dfrestrictflag.ne.0) then
     call dfrestrict(ttvector,numr)
  endif

  call sparseconfigmult_nompi(ttvector,ttvector2, yyy%cptr(0), yyy%sptr(0), 1,1,1,0,0d0)

  if (mshift.ne.0d0) then 
     do ir=1,numr
        ttvector2(:,ir)=ttvector2(:,ir)+ ttvector(botwalk:topwalk,ir)*configmvals(botwalk:topwalk)*mshift
     enddo
  endif


  if (dfrestrictflag.ne.0) then
     call dfrestrict_par(ttvector2,numr)
  endif
  
  outavectortr(:,:)=TRANSPOSE(ttvector2(:,:))


end subroutine parblockconfigmult_transpose



subroutine parblockconfigmult_transpose_spin(inavectortrspin,outavectortrspin)
  use parameters
  use mpimod
  use xxxmod
  implicit none

  DATATYPE :: inavectortrspin(numr,spinrank), outavectortrspin(numr,spinrank)
  integer,save :: allochere=0
  DATATYPE,save,allocatable :: intemptr(:,:), ttvector(:,:), ttvector2(:,:), ttvectorspin(:,:), ttvector2spin(:,:)
  integer :: ir

  if (allochere.eq.0) then
     allocate(intemptr(numr,spintotrank), ttvector(numconfig,numr), ttvector2(botwalk:topwalk,numr), &
       ttvectorspin(spintotrank,numr), ttvector2spin(spinrank,numr))
  endif
  allochere=1

  if (sparseconfigflag.eq.0) then
     OFLWR "error, must use sparse for parblockconfigmult_transpose"; CFLST
  endif

  intemptr(:,:)=0d0;   intemptr(:,spinstart:spinend)=inavectortrspin(:,:)


  call mpiallgather(intemptr,spintotrank*numr,allspinranks*numr,maxspinrank*numr)

  ttvectorspin(:,:)=TRANSPOSE(intemptr(:,:))
  
  call configspin_transformfrom(numr,ttvectorspin,ttvector)

  if (dfrestrictflag.ne.0) then
     call dfrestrict(ttvector,numr)
  endif

  call sparseconfigmult_nompi(ttvector,ttvector2, yyy%cptr(0), yyy%sptr(0), 1,1,1,0,0d0)

  if (mshift.ne.0d0) then 
     do ir=1,numr
        ttvector2(:,ir)=ttvector2(:,ir)+ ttvector(botwalk:topwalk,ir)*configmvals(botwalk:topwalk)*mshift
     enddo
  endif
  
  if (dfrestrictflag.ne.0) then
     call dfrestrict_par(ttvector2,numr)
  endif

  call configspin_transformto_mine(numr,ttvector2,ttvector2spin)
  
  outavectortrspin(:,:)=TRANSPOSE(ttvector2spin(:,:))


end subroutine parblockconfigmult_transpose_spin






subroutine blocklanczos0( lanblocknum, numout, lansize,maxlansize,order,maxiter,  outvectors,outvectorlda, outvalues,inprintflag,guessflag,lancheckmod,lanthresh,multsub,logpar)
  use fileptrmod
  implicit none 

  logical :: logpar
  integer :: lansize,maxlansize,maxiter,lanblocknum,printflag,inprintflag,order,lancheckmod,outvectorlda,numout
  external :: multsub
  DATATYPE :: values(order*lanblocknum), thisdot  !! lastval
  DATATYPE, intent(out) :: outvalues(numout)  
  real*8 :: error(numout),lanthresh
  DATATYPE :: alpha(lanblocknum,lanblocknum),beta(lanblocknum,lanblocknum), &
       initvectors(maxlansize,lanblocknum),  invector(maxlansize), multvectors(maxlansize,lanblocknum), &
       lanham(lanblocknum,order,lanblocknum,order),&
       laneigvects(lanblocknum,order,order*lanblocknum),&
       lanvects(maxlansize,lanblocknum,order), tempvectors(maxlansize,numout), &
       lanmultvects(maxlansize,lanblocknum,order), tempvectors2(maxlansize,numout),csum
  DATATYPE, allocatable :: betas(:,:,:),betastr(:,:,:)
  DATATYPE :: outvectors(outvectorlda,numout), hdot
  DATATYPE :: lastvalue(numout), thisvalue(numout), valdot(numout),normsq(numout)

  real*8 :: stopsum,rsum,nextran
  integer ::  iorder,k,flag,j,id,nn,i,guessflag,thislanblocknum, thisdim,ii,nfirst,nlast,myrank,nprocs

  DATATYPE :: templanham(lanblocknum*order,lanblocknum*order)

  if (numout.lt.lanblocknum) then
     OFLWR "numout >= lanblocknum please",numout,lanblocknum; CFLST
  endif
  if (numout.gt.order*lanblocknum) then
     OFLWR "numout gt order*lanblocknum is impossible.",numout,order,lanblocknum; CFLST
  endif

  


  printflag=inprintflag


  alpha=0; beta=0;  values=0
  initvectors=0; invector=0; multvectors=0; 
  lanham=0;  laneigvects=0; lanvects=0d0;

  lastvalue(:)=1d10;  thisvalue(:)=1d9

  call rand_init(1731.d0) 

  if (guessflag==0) then
     initvectors(:,:)=0.0d0
     do k=1,lanblocknum

!! want to be sure to have exactly the same calc regardless of nprocs.
!!    but doesn't seem to work
!!

!! attempt to make runs exactly the same, for parorbsplit=3 (orbparflag in sincproject)
!!   regardless of nprocs

        if (logpar) then   
           call getmyranknprocs(myrank,nprocs)
           nfirst=myrank-1;           nlast=nprocs-myrank
        else
           nfirst=0; nlast=0
        endif

        do ii=1,nfirst
           do i=1,lansize
              csum=nextran() + (0d0,1d0) * nextran()
           enddo
        enddo
        do i=1,lansize
           initvectors(i,k)=nextran() + (0d0,1d0) * nextran()
        enddo
        do ii=1,nlast
           do i=1,lansize
              csum=nextran() + (0d0,1d0) * nextran()
           enddo
        enddo
     enddo
  else
        initvectors(1:lansize,:)=outvectors(1:lansize,1:lanblocknum)
  endif

  initvectors(lansize+1:,:)=0d0  ! why not

  flag=0
!  do while (flag==0)
  do while (flag.ne.1)
     flag=0

     lanvects(1:lansize,:,1)=initvectors(1:lansize,:)
     lanham(:,:,:,:)=0.0d0

     do i=1,lanblocknum
        call myhgramschmidt_fast(lansize, i-1, maxlansize, lanvects(:,:,1),lanvects(:,i,1),logpar)
!        call myhgramschmidt_old(lansize, i-1, maxlansize, lanvects(:,:,1),lanvects(:,i,1))
     enddo

     do j=1,lanblocknum
        call multsub(lanvects(:,j,1),multvectors(:,j))
        call multsub(multvectors(:,j),tempvectors2(:,j))
     enddo

     lanmultvects(:,:,1)=multvectors(:,:)

     call allhdots(lanvects(:,:,1),multvectors(:,:),lansize,maxlansize,lanblocknum,lanblocknum,alpha,logpar)


     lanham(:,1,:,1)= alpha(:,:)

     if (printflag.ne.0) then
        OFLWR "FIRST ALPHA ", alpha(1,1); CFL
     endif

     error(:)=1000d0

     do j=1,lanblocknum  !! not numout, don't have them yet.

        normsq(j)=hdot(lanvects(:,j,1),lanvects(:,j,1),lansize,logpar)  !! yes should be normed, whatever
        
        valdot(j)=hdot(lanvects(:,j,1),multvectors(:,j),lansize,logpar)
                 
        values(j)=valdot(j)/normsq(j)

        error(j)=abs(&
             valdot(j)**2 / normsq(j)**2 - &
             hdot(lanvects(:,j,1),tempvectors2(:,j),lansize,logpar)/normsq(j))
     enddo

     if (printflag.ne.0) then
        OFL; write(mpifileptr,'(A10,100E8.1)') " FIRST ERRORS ", error(1:numout); CFL
     endif

     if (numout.eq.lanblocknum) then
        stopsum=0d0
        do nn=1,numout
           if (error(nn).gt.stopsum) then
              stopsum=error(nn)
           endif
        enddo
        if (stopsum.lt.lanthresh) then
           OFLWR "Vectors converged on read",stopsum,lanthresh; CFL
           flag=1
        else
           if (printflag.ne.0) then
              OFLWR "MAX ERROR : ", stopsum, lanthresh; CFL
           endif
        endif
     endif

     iorder=1
     do while ( flag==0 )

        iorder=iorder+1
        if (iorder.eq.order) then
           flag=2
        endif
! each loop: multvector is h onto previous normalized vector

        lanvects(1:lansize,:,iorder)=multvectors(1:lansize,:)

        thislanblocknum=lanblocknum
        if (iorder*lanblocknum.ge.maxiter) then
           OFLWR "Max iters ",maxiter," reached, setting converged flag to 2"; CFL
           flag=2 
           thislanblocknum=maxiter-(iorder-1)*lanblocknum
        endif

        do i=1,thislanblocknum
           call myhgramschmidt_fast(lansize, (iorder-1)*lanblocknum+i-1, maxlansize, lanvects,lanvects(:,i,iorder),logpar)
!           call myhgramschmidt_old(lansize, (iorder-1)*lanblocknum+i-1, maxlansize, lanvects,lanvects(:,i,iorder))
        enddo

        multvectors(:,:)=0d0
        do j=1,thislanblocknum
           call multsub(lanvects(:,j,iorder),multvectors(:,j))
        enddo
        lanmultvects(:,:,iorder)=multvectors(:,:)

        call allhdots(lanvects(:,:,iorder),multvectors(:,:),lansize,maxlansize,lanblocknum,lanblocknum,alpha,logpar)
        lanham(:,iorder,:,iorder)=alpha(:,:)


        allocate(betas(lanblocknum,iorder-1,lanblocknum), betastr(lanblocknum,lanblocknum,iorder-1))
        call allhdots(lanvects(:,:,:),lanmultvects(:,:,iorder),lansize,maxlansize,lanblocknum*(iorder-1),lanblocknum,betas(:,:,:),logpar)

        call allhdots(lanvects(:,:,iorder),lanmultvects(:,:,:),lansize,maxlansize,lanblocknum,lanblocknum*(iorder-1),betastr(:,:,:),logpar)

!        call allhdots(lanvects(:,:,iorder),lanmultvects(:,:,iorder-1),lansize,maxlansize,lanblocknum,lanblocknum,betastr(:,:,iorder-1),logpar)

        do i=1,iorder-1
           lanham(:,i,:,iorder)=betas(:,i,:)
        enddo
        do i=1,iorder-1                !! not needed on paper (arnoldi), just iorder-1
!        do i=iorder-1,iorder-1
           lanham(:,iorder,:,i)=betastr(:,:,i)
        enddo

        deallocate(betas,betastr)



        if (mod(iorder,lancheckmod).eq.0.or.flag.ne.0) then  ! flag.ne.0 for maxiter, iorder
           
           templanham(:,:)=0d0
           templanham(1:lanblocknum*iorder,1:lanblocknum*iorder)=RESHAPE(lanham(:,1:iorder,:,1:iorder),(/lanblocknum*iorder,lanblocknum*iorder/))

           thisdim=min(maxiter,iorder*lanblocknum)

           call CONFIGEIG(templanham,thisdim,order*lanblocknum,laneigvects,values)

           outvalues(:)=values(1:numout)

           if (printflag.ne.0) then
              OFL; write(mpifileptr,'(A10,1000F19.12)') " ENERIGES ", values(1:numout); CFL
           endif

           thisvalue(:)=values(1:numout)

           stopsum=0d0
           do nn=1,numout
              rsum=abs(thisvalue(nn)-lastvalue(nn))
              if (rsum.gt.stopsum) then
                 stopsum=rsum
              endif
           enddo
           lastvalue(:)=thisvalue(:)

! so lanthresh is for error of HPsi...  empirically make guess as to 
!  when it might be converged based on change in energy

!!           if (stopsum.lt.lanthresh/10.or.flag.ne.0) then   ! flag=1 for maxiter,maxorder
           if (stopsum.lt.lanthresh/4.or.flag.ne.0) then   ! flag=1 for maxiter,maxorder
              if (printflag.ne.0) then
                 OFL; write(mpifileptr,'(A25,2E12.5,I10)')  "checking convergence.",stopsum,lanthresh/10,thisdim; CFL
              endif

              outvectors(:,:) = 0.0d0
              do  j=1, numout
                 do k=1, iorder
                    do id=1,lanblocknum
                       if ((k-1)*lanblocknum+id.le.maxiter) then
                          outvectors(1:lansize,j) = outvectors(1:lansize,j) + laneigvects(id,k,j) * lanvects(1:lansize,id,k)
                       endif
                    enddo
                 enddo
                 outvectors(:,j)=outvectors(:,j)/sqrt(thisdot(outvectors(:,j),outvectors(:,j),lansize,logpar))
              enddo
              
              tempvectors=0d0
              do j=1,numout
                 call multsub(outvectors(:,j),tempvectors(:,j))
                 call multsub(tempvectors(:,j),tempvectors2(:,j))
              enddo

              do j=1,numout

                 normsq(j)=hdot(outvectors(:,j),outvectors(:,j),lansize,logpar)

                 valdot(j)=hdot(outvectors(:,j),tempvectors(:,j),lansize,logpar)
                 
                 values(j)=valdot(j)/normsq(j)

                 error(j)=abs(&
                      valdot(j)**2 / normsq(j)**2 - &
                      hdot(outvectors(:,j),tempvectors2(:,j),lansize,logpar)/normsq(j))

!                 tempvectors(1:lansize,j) = tempvectors(1:lansize,j) - values(j) * outvectors(1:lansize,j)
!                 error(j)=sqrt(abs(hdot(tempvectors(:,j),tempvectors(:,j),lansize,logpar)))/ &
!                      sqrt(abs(hdot(outvectors(:,j),outvectors(:,j),lansize,logpar)))

              enddo

              if (printflag.ne.0) then
                 OFL; write(mpifileptr,'(A10,100E8.1)') " ERRORS ", error(1:numout); CFL
              endif
              
              stopsum=0d0
              do nn=1,numout
                 if (error(nn).gt.stopsum) then
                    stopsum=error(nn)
                 endif
              enddo
              if (stopsum.gt.lanthresh) then
                 if (printflag.ne.0) then
                    OFLWR "Not converged", stopsum, lanthresh; CFL
                 endif
                 if (thisdim.ge.maxiter) then
                    OFLWR "MAX DIM REACHED, NO CONVERGENCE -- THRESHOLDS TOO HIGH? BUG?",stopsum,lanthresh; CFLST
                 endif
              else
!                 if (printflag.ne.0) then
!                    OFLWR "Converged", stopsum, lanthresh; CFL
!                 endif
                 flag=1
              endif
           endif
        endif
     enddo

     if (flag==1) then
        if (printflag.ne.0) then
           OFLWR "Converged. ",stopsum,lanthresh  !!, "HDOTS:"
!           do i=1,numout
!              write(mpifileptr,'(10000F8.3)') (hdot(outvectors(:,i),outvectors(:,j),lansize,logpar),j=1,numout)
!           enddo
           CFL
        endif
     else
        flag=0
        OFLWR "  Not converged. restarting.", stopsum,lanthresh; CFL
     endif


     initvectors(:,:)=0d0
     initvectors(1:lansize,1:lanblocknum)=outvectors(1:lansize,1:lanblocknum)

  enddo
  call mpibarrier()
end subroutine blocklanczos0






