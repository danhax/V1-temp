
!! DENSITY MATRIX SUBROUTINES !!  
  
#include "Definitions.INC"
  

!! ASSUMES denmat,denvects is ready. 

subroutine output_denmat( incmf, time)
  use parameters
  use mpimod
  use xxxmod
  implicit none
  integer :: i,j, incmf, numcalledhere=0, mytimingout
  real*8 ::  rsum, rsum2, time, rsum3

  if (myrank.ne.1) then
     return
  endif
  numcalledhere=numcalledhere+1

  if (incmf==1) then
     mytimingout=1
  else
     mytimingout=timingout
  endif
  if (numcalledhere==1) then
     open(853,file=dendatfile,status="unknown");   write(853,*) ;           close(853)
     open(853,file=denrotfile,status="unknown");     write(853,*) ;           close(853)
  endif
  
  if (mod(numcalledhere,mytimingout).eq.0)  then
     rsum=0.d0;  rsum2=0.d0;  rsum3=0.d0
     do i=1,nspf
        do j=1,nspf
           if (i /= j) then
              rsum=rsum+abs(yyy%denmat(i,j,0)**2)
           else
              rsum2=rsum2+abs(yyy%denmat(i,j,0)**2)
           endif
           if (shells(i) /= shells(j)) then
              rsum3=rsum3+abs(yyy%denmat(i,j,0)**2)
           endif
        enddo
     enddo

     open(853,file=dendatfile,status="unknown", position="append")
     write(853,'(F17.8, 100E17.7)') time, yyy%denvals(1:nspf); close(853)

     open(853,file=denrotfile,status="unknown", position="append")
     write(853,'(100F23.14)') time, rsum/rsum2, rsum3/rsum2;     close(853)
           
!!$     if (cdenflag.ne.0.and.rdenflag.ne.0) then
!!$        !!     call openfile(); write(mpifileptr,*) "Calling schmidt check"; call closefile()
!!$        call schmidtcheck(1)
!!$     endif
  endif
end subroutine output_denmat


subroutine denprint(iprop)
  use parameters
  use xxxmod
  implicit none
  integer :: i,iprop
  CNORMTYPE ::  sum2

  sum2=0d0
  do i=1,nspf
     sum2=sum2+yyy%denvals(i)
  enddo
  if (sum2.eq.0.d0) then
     print *, "SUM2 ERR!!"
  endif
  if (iprop.eq.1) then
     OFL; WRFL "|-------Natural orbital occupation numbers for each state-------------------|"
  endif
  write(mpifileptr,'(100F9.5)') (abs(yyy%denvals(i)/sum2*numelec),i=1,nspf); CFL

end subroutine denprint

module natrepbiomod
  use biorthotypemod
  implicit none
  type(biorthotype),target :: natrepbiovar
end module

subroutine replace_withnat(printflag)
  use natrepbiomod
  use biorthomod
  use parameters
  use xxxmod
  implicit none

  DATATYPE :: outspfs(spfsize,nspf), nullspfs(spfsize,nspf)
  integer :: i,j,printflag,imc
  real*8 :: errorval
  DATATYPE,target :: smo(nspf,nspf)

  outspfs=0d0;nullspfs=0d0

  do j=1,nspf  ! which natorb
     do i=1,nspf  ! which original
        outspfs(:,j)=outspfs(:,j)+ &
             yyy%cmfpsivec(spfstart+(i-1)*spfsize:spfstart+i*spfsize-1,0)*yyy%denvects(i,j)
     enddo
  enddo

  call spf_orthogit(outspfs, errorval)
  if (errorval.gt.1d-7) then
     OFLWR "WTF!  ERROR IN REPLACENAT ", errorval; CFLST
  endif

  if (printflag==1) then
     OFLWR "REPLACING SPFS - DENMAT EIGS"
     do i=1,nspf
        write(mpifileptr,'(2E25.10)') yyy%denvals(i)/mcscfnum  !!!*numelec
     enddo
     WRFL; CFL
  endif

  call bioset(natrepbiovar,smo,numr)

  do imc=1,mcscfnum

!!$     tempavector(:)=yyy%cmfpsivec(astart(imc):aend(imc),0)

     call biotransform(yyy%cmfpsivec(spfstart,0),outspfs,yyy%cmfpsivec(astart(imc),0),natrepbiovar)

!!$! doesn't work.  permoverlaps broken presumably.
!!$#ifdef NOWAYDUDE
!!$     call autocorrelate_one(yyy%cmfpsivec(astart(imc),0), outspfs, yyy%cmfpsivec(spfstart,0), tempavector, sum,1)
!!$!! CHECK
!!$     tempavector2(:)=yyy%cmfpsivec(astart(imc):aend(imc),0)
!!$     call biotransform(outspfs,yyy%cmfpsivec(spfstart,0),tempavector2(:),natrepbiovar)
!!$     print *, DOT_PRODUCT(tempavector,tempavector),"AAAAAA"
!!$     tempavector2(:)=     tempavector2(:) - tempavector(:)
!!$     print *, DOT_PRODUCT(tempavector2,tempavector2),"BBBBB";
!!$     nullspfs(:,:)=0d0
!!$nullspfs(:,:)=nullspfs(:,:)-outspfs(:,:)
!!$print *, "BIOCHECK ", DOT_PRODUCT(RESHAPE(nullspfs, (/spfsize*nspf/)), RESHAPE(nullspfs, (/spfsize*nspf/)))
!!$!     call checkbio(yyy%cmfpsivec(spfstart,0),outspfs,tempavector,yyy%cmfpsivec(astart(imc),0))
!!$!     call checkbio(yyy%cmfpsivec(spfstart,0),nullspfs,tempavector,yyy%cmfpsivec(astart(imc),0))
!!$#endif

  enddo

  yyy%cmfpsivec(spfstart:spfend,0)=RESHAPE(outspfs,(/totspfdim/))

end subroutine replace_withnat



subroutine getdenmatx()
  use parameters
  use xxxmod
  implicit none

  call getdenmat0(yyy%cmfpsivec(astart(1),0), yyy%denmat(:,:,0) , yyy%invdenmat(:,:,0) , yyy%denvals(:) , yyy%denvects(:,:), numr, mcscfnum)

!!$  if (rdenflag==1) then
!!$     call getrdenmat()
!!$  endif
!!$  if (cdenflag==1) then
!!$     call getnatconfig()
!!$  endif
!!$  if (cdenflag==1.and.rdenflag==1) then
!!$     call schmidtcheck(0)
!!$  endif

end subroutine getdenmatx

!! denmat is the true denmat, not transposed.

subroutine getdenmat0(in_avector, denmat, invdenmat, denvals, denvects, numpoints,howmany)
  use parameters
  use walkmod
  implicit none

  integer,intent(in) ::  numpoints,howmany
  CNORMTYPE,intent(out) :: denvals(nspf)
  DATATYPE, intent(in) :: in_avector(numpoints,firstconfig:lastconfig,howmany)
  DATATYPE,intent(out) :: denmat(nspf,nspf),invdenmat(nspf,nspf),denvects(nspf,nspf)
  CNORMTYPE :: tempdenvals(nspf,numclasses)
  DATATYPE :: tempinvden(nspf,nspf,numclasses),tempdenvects(nspf,nspf,numclasses),&
       a1(numpoints,howmany), a2(numpoints,howmany), dot
  DATATYPE :: avector(numpoints,numconfig,howmany)   !! AUTOMATIC
  integer :: config1,config2,  ispf,jspf,  dirphase, iwalk,iclass

  avector(:,firstconfig:lastconfig,:) = in_avector(:,:,:)

!! DO SUMMA
  if (parconsplit.ne.0) then
     call mpiallgather(avector,numconfig*numpoints,configsperproc*numpoints,maxconfigsperproc*numpoints)
  endif

  denmat(:,:)=0.d0; denvects(:,:)=0d0; invdenmat(:,:)=0d0

  !! single off diagonal walks

  do config1=botconfig,topconfig

     a1(:,:)=avector(:,config1,:)
        
     do iwalk=1,numsinglewalks(config1)
        config2=singlewalk(iwalk,config1)
        dirphase=singlewalkdirphase(iwalk,config1)
        a2(:,:)=avector(:,config2,:)
        ispf=singlewalkopspf(1,iwalk,config1)  !! goes with config1
        jspf=singlewalkopspf(2,iwalk,config1)  !! goes with config2


        denmat(ispf,jspf)=denmat(ispf,jspf)+ &
             dot(a2(:,:),a1(:,:),numpoints*howmany)*dirphase

!!$!!  ONCE AND FOR ALL 2014           :                     RIGHT MULTIPLYING!!!
!!$           denmat(ispf,jspf)=denmat(ispf,jspf)+ &
!!$                dirphase*a1*CONJUGATE(a2)
!!$!! NOT
!!$!!           denmat(jspf,ispf)=denmat(jspf,ispf)+ &
!!$!!                dirphase*a1*CONJUGATE(a2)

     enddo
  enddo

  call mympireduce(denmat,nspf**2)

  tempinvden(:,:,:)=0d0; tempdenvals(:,:)=0d0; tempdenvects(:,:,:)=0d0; 

  do iclass=1,numclasses
     do ispf=1,nperclass(iclass)
        do jspf=1,nperclass(iclass)
           tempinvden(ispf,jspf,iclass)=denmat(classorb(ispf,iclass),classorb(jspf,iclass))
        enddo
     enddo
     tempinvden(:,:,iclass)= (-1) * tempinvden(:,:,iclass)
     call EIGEN(tempinvden(:,:,iclass),nperclass(iclass), nspf, tempdenvects(:,:,iclass),tempdenvals(:,iclass))
     tempinvden(:,:,iclass)= (-1) * tempinvden(:,:,iclass)
     tempdenvals(:,iclass)= (-1) * tempdenvals(:,iclass)

     call invmatsmooth(tempinvden(:,:,iclass),nperclass(iclass),nspf,denreg)
     do ispf=1,nperclass(iclass)
        denvals(classorb(ispf,iclass))=tempdenvals(ispf,iclass)
        do jspf=1,nperclass(iclass)
           denvects(classorb(ispf,iclass),classorb(jspf,iclass))=tempdenvects(ispf,jspf,iclass)
           invdenmat(classorb(ispf,iclass),classorb(jspf,iclass))=tempinvden(ispf,jspf,iclass)
        enddo
     enddo
  enddo


end subroutine getdenmat0


subroutine getoccupations(in_avector, numpoints, occupations)
  use parameters
  use walkmod
  implicit none

  integer,intent(in) ::  numpoints
  CNORMTYPE, intent(out) :: occupations(nspf)
  integer :: config1,  ispf,jspf,  iwalk,idiag
  DATATYPE, intent(in) :: in_avector(numpoints,firstconfig:lastconfig)
  DATATYPE :: dot
  DATATYPE :: avector(numpoints,numconfig)   !! AUTOMATIC

  avector(:,firstconfig:lastconfig) = in_avector(:,:)

!! DO SUMMA
  if (parconsplit.ne.0) then
     call mpiallgather(avector,numconfig*numpoints,configsperproc*numpoints,maxconfigsperproc*numpoints)
  endif

  occupations(:)=0d0

  do config1=botconfig,topconfig
     do idiag=1,numsinglediagwalks(config1)
        iwalk=singlediag(idiag,config1)

        ispf=singlewalkopspf(1,iwalk,config1)  !! goes with config1
        jspf=singlewalkopspf(2,iwalk,config1)  !! goes with config2

        occupations(ispf)=occupations(ispf) + dot(avector(:,config1),avector(:,config1),numpoints)

     enddo
  enddo

#ifndef REALGO
#ifndef CNORMFLAG
  call mympirealreduce(occupations,nspf)
#else
  call mympireduce(occupations,nspf)
#endif
#else
  call mympireduce(occupations,nspf)
#endif


end subroutine getoccupations


!!$subroutine getrdenmat()
!!$  use parameters
!!$  use xxxmod
!!$  implicit none
!!$
!!$  DATATYPE :: avector(numconfig,numr,mcscfnum), a1(mcscfnum), a2(mcscfnum), csum, csum2, sum,dot
!!$  integer ::     ii,jj, config1
!!$
!!$  avector(:,:,:)=RESHAPE(yyy%cmfpsivec(astart(1):aend(mcscfnum),0),(/numconfig,numr,mcscfnum/))
!!$  do ii=1,numr
!!$     do jj=1,numr
!!$        sum=0.d0
!!$        do config1=1,numconfig  !! ok walks
!!$           a1(:)=avector(config1,ii,:);           a2(:)=avector(config1,jj,:)
!!$           sum=sum+dot(a2(:),a1(:),mcscfnum)
!!$        enddo
!!$        yyy%rdenmat(ii,jj)=sum
!!$     enddo
!!$  enddo
!!$  
!!$  yyy%rdenmat=(-1)*yyy%rdenmat
!!$  call EIGEN(yyy%rdenmat,numr, numr, yyy%rdenvects(:,:), yyy%rdenvals(:))
!!$  yyy%rdenvals(:)=(-1)*yyy%rdenvals(:) ;  yyy%rdenmat=(-1)*yyy%rdenmat     
!!$  
!!$  do ii=1,numr
!!$     csum=0.d0;     csum2=0.d0
!!$     do jj=1,numr
!!$        
!!$!! 111510 this is just for output, no big deal, but rdenexpect should be CNORMTYPE, really DATATYPE if want complex expect for chmctdh
!!$
!!$        csum=csum+              ALLCON(yyy%rdenvects(jj,ii))*     yyy%rdenvects(jj,ii)  
!!$        csum2=csum2+ ALLCON(yyy%rdenvects(jj,ii))*yyy%rdenvects(jj,ii)*bondpoints(ii) 
!!$     enddo
!!$     yyy%rdenexpect(ii)=csum2/csum   !! ok for implicit conv (chmctdh, pmctdh, mctdh)
!!$  enddo
!!$
!!$end subroutine getrdenmat



subroutine get_constraint(time)
  use parameters
  use xxxmod
  implicit none
  real*8 :: time

  if (constraintflag.eq.1) then
     call get_denconstraint(time)
  else if (constraintflag.eq.2) then
  if (drivingflag.ne.0) then
     OFLWR "Driving with dfconstraint not implemented yet"; CFLST
  endif
     call get_dfconstraint(time)
  else 
     OFLWR "CONSTRAINTFLAG ERROR  ", constraintflag; CFLST
  endif

end subroutine get_constraint


subroutine get_denconstraint(time)
  use parameters
  implicit none
  real*8 :: time

  !! assume nothing, keep constant off block diag (lio solve)

  if (denmatfciflag.ne.0) then
!! "denmat FCI", wrong equation, as per restricted configuration paper
     call get_denconstraint1(2,time)    
  else
!! correct formula
     call new_get_denconstraint1(time)    
  endif

end subroutine get_denconstraint


!! lioden.    111510 WAS C-order.  1)  change refs to denmat because denmat is now denmat not transpose denmat
!!                                 2)  change C-order because think that also has to do with denmat transpose and not just internal to these subroutines
!!                                   
!! 111510 WAS function lind(ispf,jspf)

function lind(jspf,ispf)
  use parameters
  implicit none
  integer :: ispf,jspf,lind
  print *, "CHECK LIODEN CODE. (SEE COMMENTS)"
  stop
  if (jspf.gt.ispf) then
     lind=(ispf-1)*(nspf-1)+jspf-1
  else
     lind=(ispf-1)*(nspf-1)+jspf
  endif
end function lind


function llind(ispf,jspf)
  use parameters
  implicit none
  integer :: ispf,jspf,llind, lll, i

  lll=0
  do i=1,shells(ispf)-1
     lll=lll+ (nspf - allshelltop(i)+allshelltop(i-1)) * (allshelltop(i)-allshelltop(i-1))
  enddo

  lll=lll + (nspf-allshelltop(shells(ispf))+allshelltop(shells(ispf)-1)) * (ispf-allshelltop(shells(ispf)-1)-1) + jspf

  if (shells(jspf).gt.shells(ispf)) then
     lll=lll-(allshelltop(shells(ispf))-allshelltop(shells(ispf)-1))
  endif
  llind=lll

end function llind



subroutine get_denconstraint1(iwhich,time)
  use parameters
  use walkmod
  use xxxmod
  implicit none

  DATATYPE ::  a1(numr,mcscfnum), a2(numr,mcscfnum), a1p(numr,mcscfnum), a2p(numr,mcscfnum),&
       tempconmatels(nspf,nspf),dot
  DATATYPE :: bigavector(numr,numconfig,mcscfnum), bigavectorp(numr,numconfig,mcscfnum)
  DATATYPE :: avector(numr,firstconfig:lastconfig,mcscfnum), avectorp(numr,firstconfig:lastconfig,mcscfnum)
  integer ::  config1,config2,   ispf,jspf,  dirphase,  i,     iwalk, info, kspf, lspf, ind, jind, &
       lind, llind, flag, isize, iwhich,  iiyy,maxii,imc
  integer :: ipiv(liosize)
  real*8 :: denom,time,rsum,rsum2,maxval,maxanti
  DATATYPE :: liosolve(liosize),lioden(liosize, liosize),liodencopy(liosize,liosize),liosolvetemp(liosize)

  avector(:,:,:)=RESHAPE(yyy%cmfpsivec(astart(1):aend(mcscfnum),0),(/numr,localnconfig,mcscfnum/))

  yyy%cptr(0)%xconmatel(:,:)=0.d0;   yyy%cptr(0)%xconmatelxx(:,:)=0.d0;   yyy%cptr(0)%xconmatelyy(:,:)=0.d0;   yyy%cptr(0)%xconmatelzz(:,:)=0.d0

  if ((iwhich.eq.2).and.(numshells.eq.1)) then
     return
  endif
  if (real(timefac) /= 0.0) then
     OFLWR "Err, get_denconstraint1 (with lioden) can only be used for forward time propagation. "; CFLST
  endif

  lioden=0.d0

  do ispf=1,nspf
     do kspf=1,nspf
        do lspf=1,nspf
           flag=0
           select case (iwhich)
           case (1)
              if ((ispf/=lspf).and.(kspf/=lspf)) then
                 ind=lind(ispf,lspf);                 jind=lind(kspf,lspf);          flag=1
              endif
           case (2)
              if ( (shells(ispf).ne.shells(lspf) ) .and. (shells(kspf).ne.shells(lspf) ) ) then
                 ind=llind(ispf,lspf);             jind=llind(kspf,lspf);              flag=1
              endif
           case default
              ind=0;     jind=0
              call openfile(); write(mpifileptr,*) 
              OFLWR "get_denconstraint1 error"; CFLST
           end select

           if (flag==1) then
              lioden(ind, jind) = lioden(ind, jind) + &
!!PREV                   yyy%denmat(kspf,ispf,0)      * (0d0,1d0)          !!!!   NO, timefac goes in RHS   * CONJUGATE(timefac)
                   yyy%denmat(ispf,kspf,0)      * (0d0,1d0)          !!!!   NO, timefac goes in RHS   * CONJUGATE(timefac)
           endif
        enddo
     enddo
  enddo

  do jspf=1,nspf
     do kspf=1,nspf
        do lspf=1,nspf
           flag=0
           select case (iwhich)
           case (1)
              if ((kspf/=jspf).and.(kspf/=lspf)) then
                 ind=lind(kspf,jspf);                 jind=lind(kspf,lspf);                 flag=1
              endif
           case (2)
              if ( (shells(kspf).ne.shells(jspf) ) .and. (shells(kspf).ne.shells(lspf) ) ) then
                 ind=llind(kspf,jspf);                 jind=llind(kspf,lspf);                 flag=1
              endif
           case default
              ind=0
              jind=0
              OFLWR "get_denconstraint1 error"; CFLST
           end select

           if (flag==1) then
              lioden(ind,jind) = lioden(ind,jind) + &
!!PREV                   yyy%denmat(jspf,lspf,0)    * (0d0, -1d0)      !!!! NO, timefac goes in RHS  * timefac
                   yyy%denmat(lspf,jspf,0)    * (0d0, -1d0)      !!!! NO, timefac goes in RHS  * timefac
           endif
        enddo
     enddo
  enddo


  maxii=1
  if (tdflag.ne.0) then
     maxii=4
  endif

  do iiyy=1,maxii
     do imc=1,mcscfnum
        select case(iiyy)
        case(1)
           call sparseconfigmult(avector(:,:,imc),avectorp(:,:,imc),yyy%cptr(0),yyy%sptr(0),1,1,0,0,time)
        case default
           call sparseconfigpulsemult(avector(:,:,imc),avectorp(:,:,imc),yyy%cptr(0),yyy%sptr(0),iiyy-1)
           if (drivingflag.ne.0) then
              if (iiyy.eq.2) then
                 avectorp(:,:,imc)=avectorp(:,:,imc)+yyy%drivingavectorsxx(:,:,imc,0)
              else if (iiyy.eq.3) then
                 avectorp(:,:,imc)=avectorp(:,:,imc)+yyy%drivingavectorsyy(:,:,imc,0)
              else if (iiyy.eq.4) then
                 avectorp(:,:,imc)=avectorp(:,:,imc)+yyy%drivingavectorszz(:,:,imc,0)
              endif
           endif
        end select
     enddo

!! DO SUMMA
     bigavector(:,firstconfig:lastconfig,:)=avector(:,:,:)
     bigavectorp(:,firstconfig:lastconfig,:)=avectorp(:,:,:)

     if (parconsplit.ne.0) then
        do i=1,mcscfnum
           call mpiallgather(bigavector(:,:,i),numconfig*numr,configsperproc(:)*numr,maxconfigsperproc*numr)
           call mpiallgather(bigavectorp(:,:,i),numconfig*numr,configsperproc(:)*numr,maxconfigsperproc*numr)
        enddo
     endif

     liosolve=0.d0

  !! single off diagonal walks

     do config1=botconfig,topconfig

        a1(:,:)=avector(:,config1,:)
        a1p(:,:)=avectorp(:,config1,:)

        do iwalk=1,numsinglewalks(config1)
           
           config2=singlewalk(iwalk,config1)
           dirphase=singlewalkdirphase(iwalk,config1)
           a2(:,:)=bigavector(:,config2,:)
           a2p(:,:)=bigavectorp(:,config2,:)

           ispf=singlewalkopspf(1,iwalk,config1)
           jspf=singlewalkopspf(2,iwalk,config1)
              
           flag=0
           select case (iwhich)
           case (1)
              ind=lind(ispf,jspf) ; flag=1  !!unfuck this
           case (2)
              if (shells(ispf).ne.shells(jspf)) then
!! FIRSTWAY
                 ind=llind(ispf,jspf);                 flag=1
              endif
           case default
              ind=0
              OFLWR "get_denconstraint1 error"; CFLST
           end select

           if (flag==1) then
              liosolve(ind)=liosolve(ind)+                   dirphase*dot(a2p(:,:)*timefac,a1(:,:),numr*mcscfnum)
              liosolve(ind)=liosolve(ind)+                   dirphase*dot(a2(:,:),a1p(:,:)*timefac,numr*mcscfnum)
           endif
        enddo
     enddo

     call mympireduce(liosolve,liosize)

     select case (iwhich)
     case (1)
        isize=liosize
     case (2)
        isize=nspf**2
        do i=1,numshells
           isize=isize-(allshelltop(i)-allshelltop(i-1))**2
        enddo
     case default
        OFLWR "get_denconstraint1 error"; CFLST
     end select


     liodencopy(:,:)=lioden(:,:)
     if (lioreg.le.0.d0) then
        call MYGESV(isize, 1, liodencopy, liosize, ipiv, liosolve, liosize, info)
        if (info/=0) then
           OFLWR "Errx  mygesv lioden", info, " size ", liosize, isize ; CFLST
        endif
     else

        call invmatsmooth(liodencopy,liosize,liosize,lioreg)
        call MYGEMV('N',liosize,liosize,DATAONE,liodencopy,liosize,liosolve,1,DATAZERO,liosolvetemp,1)
        liosolve(:)=liosolvetemp(:)

!        mylwork=20*isize
!        allocate(sing(10*isize), rwork(50*isize), mywork(mylwork))
!#ifndef REALGO
!        call zgelss(isize,isize,1, liodencopy, liosize, liosolve, liosize, sing, lioreg, rank, mywork, mylwork, rwork, info)
!#else
!        call dgelss(isize,isize,1, liodencopy, liosize, liosolve, liosize, sing, lioreg, rank, mywork, mylwork, info)
!#endif
!        deallocate(sing,rwork,mywork)
!     if (info/=0) then
!        OFLWR "Errx  mygelss lioden", info, " size ", liosize, isize ; CFLST
!     endif

     endif

     
     tempconmatels(:,:)=0d0
     
     do ispf=1,nspf
        do jspf=1,nspf
           select case (iwhich)
           case (1)
              if (ispf/=jspf) then
                 ind=lind(ispf,jspf)   
                 tempconmatels(ispf,jspf)=liosolve(ind)
              endif
           case (2)
              if (shells(ispf)/=shells(jspf)) then
                 ind=llind(ispf,jspf)
                 tempconmatels(ispf,jspf)=liosolve(ind)
              endif
           case default
              OFLWR "get_denconstraint1 error"; CFLST
           end select
        enddo
     enddo
     

!! 111510   REGARDLESS!  #ifndef ECSFLAG
!! may require you to define constraint via hermitian part of hamiltonian for chmctdh.  Don't want conmatels to be non-antiherm (chmctdh) or non real (cmctdh)

     maxval=0d0
     maxanti=0d0

     do ispf=1,nspf
        do jspf=ispf+1,nspf
           
           rsum=abs(timefac*tempconmatels(ispf,jspf)+CONJUGATE(timefac*tempconmatels(jspf,ispf)))

           rsum2=max(abs(tempconmatels(ispf,jspf)),abs(tempconmatels(jspf,ispf)))

           denom=  max(1d-5,rsum2)

           if (rsum / denom .gt.1.d-6) then
              OFLWR "Err herm incmatel temp continue"
              WRFL ispf, jspf, rsum, denom,iiyy; WRFL; CFL !!ST
           endif

           if (rsum.gt.maxanti) then
              maxanti=rsum
           endif
           if (rsum2.gt.maxval) then
              maxval=rsum2
           endif
        enddo
     enddo

!!!     OFLWR "MAXVAL,MAXANTI",maxval,maxanti,iiyy; CFL

!! 070414     
     tempconmatels(:,:)=0.5d0*(tempconmatels(:,:)+TRANSPOSE(CONJUGATE(tempconmatels(:,:))))

     select case(iiyy)
     case(1)
        yyy%cptr(0)%xconmatel(:,:)=tempconmatels(:,:)
     case(2)
        yyy%cptr(0)%xconmatelxx(:,:)=tempconmatels(:,:)
     case(3)
        yyy%cptr(0)%xconmatelyy(:,:)=tempconmatels(:,:)
     case(4)
        yyy%cptr(0)%xconmatelzz(:,:)=tempconmatels(:,:)
     end select
     
  end do


end subroutine get_denconstraint1






subroutine new_get_denconstraint1(time)
  use parameters
  use walkmod
  use xxxmod
  use dfconmod
  implicit none

  integer :: ipairs(2,nspf*(nspf-1))
  DATATYPE ::  a1(mcscfnum), a2(mcscfnum), a1p(mcscfnum), a2p(mcscfnum),dot
  DATATYPE :: tempconmatels(nspf,nspf), rhomat(nspf,nspf,nspf,nspf)
  DATATYPE :: bigavector(numr,numconfig,mcscfnum), bigavectorp(numr,numconfig,mcscfnum)
  DATATYPE :: avector(numr,firstconfig:lastconfig,mcscfnum), avectorp(numr,firstconfig:lastconfig,mcscfnum)
  integer ::  config1,config2,   ispf,jspf,  dirphase,  i,  iwalk,ii,  info, kspf, &
       lspf, ind, jind, llind, flag, isize,   iiyy,maxii,imc,j
  integer,allocatable :: ipiv(:)
  real*8 :: denom,time,rsum,rsum2,maxval,maxanti
  DATATYPE, allocatable :: liosolve(:),lioden(:, :),liodencopy(:,:),liosolvetemp(:)

  yyy%cptr(0)%xconmatel(:,:)=0.d0;   yyy%cptr(0)%xconmatelxx(:,:)=0.d0;   yyy%cptr(0)%xconmatelyy(:,:)=0.d0;   yyy%cptr(0)%xconmatelzz(:,:)=0.d0

  if ((numshells.eq.1)) then
     return
  endif

  rhomat(:,:,:,:)=0d0

  avector(:,:,:)=RESHAPE(yyy%cmfpsivec(astart(1):aend(mcscfnum),0),(/numr,localnconfig,mcscfnum/))

  if (dfrestrictflag.gt.0) then
     call get_rhomat(avector,rhomat,numr,mcscfnum)
  endif


  isize=0
  do i=1,nspf
     do j=1,nspf
        if (shells(i).ne.shells(j)) then
           isize=isize+1
           ipairs(:,isize)=(/ i,j /)
        endif
     enddo
  enddo

  allocate(liosolve(isize),lioden(isize, isize),liodencopy(isize,isize),liosolvetemp(isize),ipiv(isize))  

  lioden=0.d0

  do ind=1,isize
     ispf=ipairs(1,ind)
     jspf=ipairs(2,ind)
     do jind=1,isize
        kspf=ipairs(1,jind)
        lspf=ipairs(2,jind)

        rsum= abs(rhomat(ispf,jspf,kspf,lspf)-CONJUGATE(rhomat(kspf,lspf,ispf,jspf)))
        if (rsum.gt.1d-10) then
           OFLWR "DOOG",rsum,rhomat(ispf,jspf,kspf,lspf),CONJUGATE(rhomat(kspf,lspf,ispf,jspf)); CFLST
        endif

!! rhomat included,excluded

        lioden(ind,jind)=  rhomat(kspf,lspf,ispf,jspf) - rhomat(jspf,ispf,lspf,kspf)   

        if (jspf.eq.lspf) then

           lioden(ind, jind) = lioden(ind, jind) - &
                yyy%denmat(ispf,kspf,0)  

        endif
        if (ispf.eq.kspf) then

           lioden(ind,jind) = lioden(ind,jind) + &
                yyy%denmat(lspf,jspf,0)  

        endif
     enddo
  enddo


  maxii=1
  if (tdflag.ne.0) then
     maxii=4
  endif

  do iiyy=1,maxii
     do imc=1,mcscfnum
        select case(iiyy)
        case(1)
           call sparseconfigmult(avector(:,:,imc),avectorp(:,:,imc),yyy%cptr(0),yyy%sptr(0),1,1,0,0,time)
        case default
           call sparseconfigpulsemult(avector(:,:,imc),avectorp(:,:,imc),yyy%cptr(0),yyy%sptr(0),iiyy-1)
           if (drivingflag.ne.0) then
              if (iiyy.eq.2) then
                 avectorp(:,:,imc)=avectorp(:,:,imc)+yyy%drivingavectorsxx(:,:,imc,0)
              else if (iiyy.eq.3) then
                 avectorp(:,:,imc)=avectorp(:,:,imc)+yyy%drivingavectorsyy(:,:,imc,0)
              else if (iiyy.eq.4) then
                 avectorp(:,:,imc)=avectorp(:,:,imc)+yyy%drivingavectorszz(:,:,imc,0)
              endif
           endif
        end select
     enddo

     if (dfrestrictflag.gt.0) then
        do imc=1,mcscfnum
           call dfrestrict(avectorp(:,:,imc),numr)
        enddo
     endif

!! DO SUMMA
     bigavector(:,firstconfig:lastconfig,:)=avector(:,:,:)
     bigavectorp(:,firstconfig:lastconfig,:)=avectorp(:,:,:)

     if (parconsplit.ne.0) then
        do i=1,mcscfnum
           call mpiallgather(bigavector(:,:,i),numconfig*numr,configsperproc(:)*numr,maxconfigsperproc*numr)
           call mpiallgather(bigavectorp(:,:,i),numconfig*numr,configsperproc(:)*numr,maxconfigsperproc*numr)
        enddo
     endif

     liosolve=0.d0

  !! single off diagonal walks
     do ii=1,numr

         do config1=botconfig,topconfig

           a1(:)=avector(ii,config1,:)
           a1p(:)=avectorp(ii,config1,:)
           
           do iwalk=1,numsinglewalks(config1)
              
              config2=singlewalk(iwalk,config1)
              dirphase=singlewalkdirphase(iwalk,config1)
              a2(:)=bigavector(ii,config2,:)
              a2p(:)=bigavectorp(ii,config2,:)
              
              ispf=singlewalkopspf(1,iwalk,config1)
              jspf=singlewalkopspf(2,iwalk,config1)
              
              flag=0
              if (shells(ispf).ne.shells(jspf)) then
!! FIRSTWAY
                 ind=llind(ispf,jspf);                 flag=1
              endif
              
              if (flag==1) then
                 
                 liosolve(ind)=liosolve(ind)+                   dirphase*dot(a2p(:)*timefac,a1(:),mcscfnum)
                 liosolve(ind)=liosolve(ind)+                   dirphase*dot(a2(:),a1p(:)*timefac,mcscfnum)
                 
              endif
           enddo
        enddo

     enddo

     call mympireduce(liosolve,isize)

     liodencopy(:,:)=lioden(:,:)       

     if (lioreg.le.0.d0) then
        call MYGESV(isize, 1, liodencopy, isize, ipiv, liosolve, isize, info)
        if (info/=0) then
           OFLWR "Errx  mygesv lioden", info, " size ", isize ; CFLST
        endif
     else

        call invmatsmooth(liodencopy,isize,isize,lioreg)
        call MYGEMV('N',isize,isize,DATAONE,liodencopy,isize,liosolve,1,DATAZERO,liosolvetemp,1)
        liosolve(:)=liosolvetemp(:)

     endif

     tempconmatels(:,:)=0d0
     
     do ispf=1,nspf
        do jspf=1,nspf
           if (shells(ispf)/=shells(jspf)) then
              ind=llind(ispf,jspf)
              tempconmatels(ispf,jspf)=liosolve(ind)/timefac 
           endif
        enddo
     enddo
     

!! 111510   REGARDLESS!  #ifndef ECSFLAG
!! may require you to define constraint via hermitian part of hamiltonian for chmctdh.  Don't want conmatels to be non-antiherm (chmctdh) or non real (cmctdh)

     maxval=0d0
     maxanti=0d0

     do ispf=1,nspf
        do jspf=ispf+1,nspf
           
           rsum=abs(tempconmatels(ispf,jspf)-CONJUGATE(tempconmatels(jspf,ispf)))

           rsum2=max(abs(tempconmatels(ispf,jspf)),abs(tempconmatels(jspf,ispf)))

           denom=  max(1d-5,rsum2)

           if (rsum / denom .gt.1.d-6) then
              OFLWR "Err herm incmatel temp continue"
              WRFL ispf, jspf, rsum, denom,iiyy; WRFL; CFL !!ST
           endif

           if (rsum.gt.maxanti) then
              maxanti=rsum
           endif
           if (rsum2.gt.maxval) then
              maxval=rsum2
           endif
        enddo
     enddo

!!!     OFLWR "MAXVAL,MAXANTI",maxval,maxanti,iiyy; CFL

!! 070414     
     tempconmatels(:,:)=0.5d0*(tempconmatels(:,:)+TRANSPOSE(CONJUGATE(tempconmatels(:,:))))

     select case(iiyy)
     case(1)
        yyy%cptr(0)%xconmatel(:,:)=tempconmatels(:,:)
     case(2)
        yyy%cptr(0)%xconmatelxx(:,:)=tempconmatels(:,:)
     case(3)
        yyy%cptr(0)%xconmatelyy(:,:)=tempconmatels(:,:)
     case(4)
        yyy%cptr(0)%xconmatelzz(:,:)=tempconmatels(:,:)
     end select
     
  end do


end subroutine new_get_denconstraint1



!!$  KEEPME KEEPME KEEMPE
!!$
!!$!! checks whether projections of natural configurations are proportional to natural orbitals in r
!!$!! only valid for mcscfnum=1....   projections are for each state, r natorbs are averaged
!!$
!!$subroutine schmidtcheck(schmidtprint)
!!$  use parameters
!!$  use xxxmod
!!$  use natprojmod
!!$  implicit none
!!$
!!$  DATATYPE :: dot
!!$  real*8 :: rsum
!!$  integer ::  i,j,ssize, schmidtprint
!!$  DATATYPE, allocatable :: schmidt(:,:)
!!$
!!$  if (numr.eq.1.or.mcscfnum.ne.1) then
!!$     return
!!$  endif
!!$  do i=1,numr
!!$     if (abs(yyy%rdenvals(i)).lt.1.d-8) then
!!$        exit
!!$     endif
!!$  enddo
!!$  ssize=i-1;  allocate(schmidt(ssize,ssize))
!!$  do i=1,ssize
!!$     do j=1,ssize
!!$        schmidt(i,j)=dot(natproj(:,i,1),yyy%rdenvects(:,j),numr)
!!$     enddo
!!$  enddo
!!$  if (schmidtprint.ne.0) then
!!$     call openfile()
!!$     write(mpifileptr,*) "------- Schmidt Overlaps ----------"
!!$     do i=1,ssize
!!$        write(mpifileptr,'(100E12.4)') schmidt(:,i)
!!$     enddo
!!$     write(mpifileptr,*) "-----------------------------------"
!!$  endif
!!$  do i=1,ssize
!!$     do j=1,ssize
!!$        rsum=abs(schmidt(i,j))**2
!!$        if (i==j) then 
!!$#ifndef CNORMFLAG
!!$           rsum=rsum-yyy%rdenvals(i)
!!$        endif
!!$#else
!!$        else
!!$#endif
!!$           if (abs(rsum).gt.1.d-12) then
!!$              OFLWR "WARNING!  Schmidt dot fail", rsum, i,j,schmidt(i,j),yyy%rdenvals(i);CFL
!!$           endif
!!$#ifdef CNORMFLAG
!!$        endif
!!$#endif
!!$     enddo
!!$  enddo
!!$
!!$  deallocate(schmidt)
!!$end subroutine schmidtcheck
!!$
!!$
!!$subroutine getnatconfig()
!!$  use parameters
!!$  use natprojmod
!!$  use xxxmod
!!$  implicit none
!!$
!!$  DATATYPE :: avector(numconfig,numr,mcscfnum), a1(mcscfnum), a2(mcscfnum),dot
!!$  integer ::  config1,config2,     ii,imc,i,ir,numvects
!!$  DATATYPE :: natmat(numconfig,numconfig), natvects(numconfig,numconfig)
!!$
!!$  avector(:,:,:)=RESHAPE(yyy%cmfpsivec(astart(1):aend(mcscfnum),0),(/numconfig,numr,mcscfnum/))
!!$
!!$  if (numconfig.gt.2000) then
!!$     OFLWR "Error: getting natconfigs but numconfig gt 2000: ", numconfig; CFLST
!!$  endif
!!$  natmat=0.d0
!!$  do ii=1,numr
!!$     do config1=1,numconfig    !! ok walks
!!$        a1(:)=avector(config1,ii,:)
!!$        do config2=1,numconfig !! ok walks
!!$           a2(:)=avector(config2,ii,:)
!!$           natmat(config1,config2) = natmat(config1,config2) + dot(a2,a1,mcscfnum)
!!$        enddo
!!$     enddo
!!$  enddo
!!$
!!$  natmat=(-1)*natmat
!!$  call EIGEN(natmat,numconfig, numconfig, natvects, natvals)
!!$
!!$  natmat=(-1)*natmat;  natvals=(-1)*natvals
!!$  numvects=min(numr,numconfig);  natconfigs=0.d0
!!$
!!$  do imc=1,mcscfnum
!!$     do i=1,numvects
!!$        do ir=1,numr
!!$           natproj(ir,i,imc)=dot(natvects(:,i),  & !! ok imp conv (p,ch)
!!$                avector(:,ir,imc),numconfig)
!!$        enddo
!!$        natdot(i,imc)=dot(natproj(:,i,imc),       & !! ok imp conv (p,ch)
!!$             natproj(:,i,imc),numr)
!!$     enddo
!!$  enddo
!!$
!!$  natconfigs(:,1:numvects)=natvects(:,1:numvects)
!!$
!!$end subroutine getnatconfig



