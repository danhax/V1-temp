

!!!  EXTRA COORINATE SPECIFIC ROUTINES INCLUDING DIATOMSTATS FOR EXPECTATION VALUES (DiatomStats.Dat)


#include "Definitions.INC"

!! boxes subroutine getmyparams(inmpifileptr,inpfile,spfdims,outnumsh ells,outdim)

subroutine getmyparams(inmpifileptr,inpfile,spfdims,spfdimtype,reducedpotsize,outnumr,outnucrepulsion,nonuc_checkflag)
  use myparams
  use pfileptrmod
  use pmpimod
  implicit none

  integer :: spfdims(3),spfdimtype(3),inmpifileptr,nonuc_checkflag,myiostat, reducedpotsize, outnumr,&
       nargs, idim ,i,j,len,getlen
  integer :: toepflag  !! toepflag deprecated; dummy
  character :: inpfile*(*)
  real*8 :: outnucrepulsion, rsq(griddim)
  character (len=200) :: buffer
  character (len=200) :: nullbuff="                                                                                "
  NAMELIST /sincparinp/        numpoints,spacing,griddim,notwoflag,nuccharges,orblanthresh, &
       numcenters,centershift,orblanorder,nonucrepflag,debugflag, &
       toothnbig, toothnsmall, orbparflag,num_skip_orbs,orb_skip,orblancheckmod,zke_paropt,&
       capflag,capstrength,capstart,cappower,fft_mpi_inplaceflag, fft_ct_paropt,fft_batchdim,&
       fft_circbatchdim,maxcap,mincap,capmode, maskflag, masknumpoints,&
       scalingflag,scalingdistance,smoothness,scalingtheta,scalingorder,tinv_tol,&
       orbparlevel, &
       toepflag  !! toepflag deprecated


!!$  ,scalingorders,&
!!$       scalingterms,scalingdflag,scalingdconst,tinv_tol

#ifdef PGFFLAG
  integer :: myiargc
  nargs=myiargc()
#else
  nargs=iargc()
#endif
  mpifileptr=inmpifileptr

  call getmyranknprocs(myrank,nprocs)

  nonuc_checkflag=1
  outnumr=1

  if (griddim.ne.3) then
     OFLWR "Griddim .ne. 3 not debugged.  checkme",griddim; CFLST
  endif

  open(971,file=inpfile, status="old", iostat=myiostat)

  if (myiostat/=0) then
     OFLWR "No Input.Inp found, not reading sincparams. iostat=",myiostat;CFL
  else
     read(971,nml=sincparinp)
     close(971)

!! enforce defaults that depend on other variables
!! (none currently)

     open(971,file=inpfile, status="old", iostat=myiostat)
     read(971,nml=sincparinp)
     close(971)

  endif


  call openfile()
  do i=1,nargs
     buffer=nullbuff
     call getarg(i,buffer)
     len=getlen(buffer)
     if (buffer(1:2) .eq. 'N=') then
        read(buffer(3:len),*) numpoints(1)
        write(mpifileptr, *) "numpoints set to ", numpoints(1)
     endif
     if (buffer(1:9) .eq. 'Batchdim=') then
        read(buffer(10:len),*) fft_batchdim
        write(mpifileptr, *) "fft_batchdim set to ", fft_batchdim
     endif
     if (buffer(1:10) .eq. 'Circbatch=') then
        read(buffer(11:len),*) fft_circbatchdim
        write(mpifileptr, *) "fft_circbatchdim set to ", fft_circbatchdim
     endif
     if (buffer(1:6) .eq. 'SDebug') then
        if (.not.(buffer(1:7) .eq. 'SDebug=')) then
           write(mpifileptr,*) "Please set SDebug= not SDebug as command line option"; CFLST
        endif
        read(buffer(8:len),*) debugflag
        write(mpifileptr, *) "Debugflag for sinc dvr set to ",debugflag," by command line option"
     endif
  enddo
  call closefile()


  if (myrank.eq.1.and.debugflag.ne.0) then
     call ftset(1,mpifileptr)
  else
     call ftset(0,-99)
  endif

  numpoints(:)=numpoints(1); nbox(:)=1

  if (orbparflag) then

     if (orbparlevel.ne.3) then
        OFLWR "Error, orbparlevel=3 only allowed right now",orbparlevel; CFLST
     endif

     select case (orbparlevel)
     case (3)
        if (mod(numpoints(3),nprocs).ne.0) then
           OFLWR "ACK, orbparlevel=3, but numpoints is not divisible by nprocs",numpoints(3),nprocs; CFLST
        endif
        numpoints(3)=numpoints(3)/nprocs
        nbox(3)=nprocs
     case (2)
        sqnprocs=floor(real(nprocs)**(0.500000001d0))
        if (sqnprocs**2 .ne. nprocs) then
           OFLWR "ACK, orbparlevel=2, but it looks like nprocs is not square",sqnprocs**2,nprocs; CFLST
        endif
        if (mod(numpoints(3),sqnprocs).ne.0) then
           OFLWR "ACK, orbparlevel=2, but numpoints is not divisible by sqrt(nprocs)",numpoints(3),sqnprocs; CFLST
        endif
        numpoints(2:3)=numpoints(2:3)/sqnprocs
        nbox(2:3)=sqnprocs
     case(1)
        cbnprocs=floor(real(nprocs)**(0.333333334d0))
        if (cbnprocs**3 .ne. nprocs) then
           OFLWR "ACK, orbparlevel=1, but it looks like nprocs is not cubic",cbnprocs**3,nprocs; CFLST
        endif
        if (mod(numpoints(3),cbnprocs).ne.0) then
           OFLWR "ACK, orbparlevel=1, but numpoints is not divisible by cbrt(nprocs)",numpoints(3),cbnprocs; CFLST
        endif
        numpoints(1:3)=numpoints(1:3)/cbnprocs
        nbox(1:3)=cbnprocs
     case default
        OFLWR "orbparlevel not allowed", orbparlevel; CFLST
     end select
  endif

  numpoints(griddim+1:)=1

!! NBOX HARDWIRE 1 BUT FOR PAR.

  totpoints=1
  do idim=1,griddim
     totpoints=totpoints*numpoints(idim)
     gridpoints(idim)=nbox(idim)*numpoints(idim)
  enddo

  maxgridpoints=0
  do idim=1,griddim
     maxgridpoints=max(gridpoints(idim),maxgridpoints)
  enddo

  if (griddim.gt.3) then
     OFLWR "redim spfdims"; CFLST
  endif

  spfdims(:)=1
  spfdims(1:griddim)=numpoints(1:griddim)

  spfdimtype(:)=1   !! [ -inf...inf  variable range ]

  reducedpotsize=1
  do idim=1,griddim
     reducedpotsize=reducedpotsize*numpoints(idim)
  enddo

  sumcharge=0d0
  do i=1,numcenters
     sumcharge=sumcharge+nuccharges(i)
  enddo

  nucrepulsion=0d0

  if (griddim.eq.3) then
     if (nonucrepflag.eq.0) then
        do i=1,numcenters
           do j=i+1,numcenters
              rsq(:)=((centershift(:,i)-centershift(:,j))*spacing/2 )**2 
              nucrepulsion=nucrepulsion +  nuccharges(i)*nuccharges(j)/sqrt(rsq(1)+rsq(2)+rsq(3))
           enddo
        enddo
     endif
     
  endif

!  print *, "NUCREPULSION", nucrepulsion; stop

  outnucrepulsion=nucrepulsion

end subroutine getmyparams


subroutine printmyopts()
  use myparams
  use pfileptrmod
  implicit none
  integer :: ii

!!no  OFLWR
  WRFL "********  SINC DVR PARAMS ******** " 
  WRFL "griddim,spacing",griddim,spacing
  WRFL "numpoints",numpoints(1:griddim)
  WRFL "numcenters",numcenters
  do ii=1,numcenters
     WRFL "nuccharge",nuccharges(ii)
     WRFL "centershift",centershift(:,ii)*0.5d0
  enddo
  WRFL "orblanorder,orblanthresh",orblanorder,orblanthresh
  WRFL "notwoflag",notwoflag
  WRFL "nonucrepflag",nonucrepflag
  WRFL "toothnbig, toothnsmall",toothnbig, toothnsmall
  WRFL "orbparflag, orbparlevel",orbparflag, orbparlevel
  WRFL "zke_paropt",zke_paropt
  WRFL "fft_mpi_inplaceflag",fft_mpi_inplaceflag
  if (fft_mpi_inplaceflag==0) then
     WRFL "   --> fft_ct_paropt",fft_ct_paropt
  endif
  WRFL "fft_batchdim",fft_batchdim
  WRFL "fft_circbatchdim",fft_circbatchdim
  WRFL "  -----  "
  WRFL "NBOX ", nbox(1:griddim)
  WRFL "totpoints",totpoints
  WRFL "**********************************"
!!no  CFL
  
end subroutine printmyopts

subroutine checkmyopts()
end subroutine checkmyopts



function cylindricalvalue() !radpoint, thetapoint,nullrvalue,mvalue, invector)
  DATATYPE :: cylindricalvalue
  cylindricalvalue=0d0
print *, "DOME CYLINDRICAL VALUE SINC (what?)"; stop
end function cylindricalvalue

subroutine get_maxsparse() !nx,ny,nz,xvals,yvals,zvals, maxsparse,povsparse)
  print *, "DOME get_maxsparse SINC"; STOP
end subroutine get_maxsparse
subroutine get_sphericalsparse() !nx,ny,nz,xvals,yvals,zvals, maxsparse,sparsetransmat,sparsestart,sparseend,sparsexyz,povsparse)
  print *, "DOME get_sphericalsparse SINC"; STOP
end subroutine get_sphericalsparse
