


subroutine myclock(mytime)
  integer :: values(10),mytime
  integer, parameter :: fac(5:8)=(/60*60*1000,60*1000,1000,1/)  !! hour,minute,second,millisecond
  call date_and_time(values=values)
  mytime=values(8)+values(7)*fac(7)+values(6)*fac(6)+values(5)*fac(5)
end subroutine myclock


subroutine switchit(out,odddim,dim,howmany)
  implicit none
  integer, intent(in) :: odddim,dim,howmany
  complex*16 :: out(-dim:dim,howmany), outwork(-dim:dim,howmany)
  if (mod(odddim,2).ne.1) then
     print *, "Switchit error", odddim; stop
  endif

  outwork(0:dim,:)=out(-dim:0,:)
  outwork(-dim:-1,:)=out(1:dim,:)
  out(:,:)=outwork(:,:)

end subroutine switchit

subroutine switchit_3d(out,odddim,dim,howmany)
  implicit none
  integer, intent(in) :: odddim,dim,howmany
  complex*16 :: out(-dim:dim,-dim:dim,-dim:dim,howmany), outwork(-dim:dim,-dim:dim,-dim:dim,howmany)
  integer :: ii

  outwork(:,:,:,:)=out(:,:,:,:)
  do ii=1,3
     call switchit(outwork,odddim,dim,(2*dim+1)**2*howmany)
     call all3transpose(outwork,out,2*dim+1,howmany)         !! order doesn't matter
     outwork(:,:,:,:)=out(:,:,:,:)
  enddo
end subroutine switchit_3d




subroutine switch2(out,odddim,dim,howmany)
  implicit none
  integer, intent(in) :: odddim,dim,howmany
  complex*16 :: out(-dim:dim,howmany), outwork(-dim:dim,howmany)
  if (mod(odddim,2).ne.1) then
     print *, "Switchit error", odddim; stop
  endif

  outwork(1:dim,:)= out(0:dim,:)
  outwork(-dim:0,:)= out(-dim:-1,:)
  out(:,:)=outwork(:,:)

end subroutine switch2



subroutine switch2_3d(out,odddim,dim,howmany)
  implicit none
  integer, intent(in) :: odddim,dim,howmany
  complex*16 :: out(-dim:dim,-dim:dim,-dim:dim,howmany), outwork(-dim:dim,-dim:dim,-dim:dim,howmany)
  integer :: ii

  outwork(:,:,:,:)=out(:,:,:,:)
  do ii=1,3
     call switch2(outwork,odddim,dim,(2*dim+1)**2*howmany)
     call all3transpose(outwork,out,2*dim+1,howmany)         !! order doesn't matter
     outwork(:,:,:,:)=out(:,:,:,:)
  enddo
end subroutine switch2_3d


subroutine all3transpose(in,out,len,howmany)
  implicit none
  integer :: len,howmany,ii
  complex*16 :: out(len,len,len,howmany), in(len,len,len,howmany)
  do ii=1,len
     out(:,:,ii,:)=in(ii,:,:,:)
  enddo
end subroutine all3transpose







subroutine circ3d_sub_real(rbigcirc,rmultvector,rffback,totdim)
  implicit none
  integer :: totdim
  complex*16 :: multvector(2*totdim,2*totdim,2*totdim), ffback(2*totdim,2*totdim,2*totdim),&
       bigcirc(2*totdim,2*totdim,2*totdim)
  real*8 :: rmultvector(2*totdim,2*totdim,2*totdim), rffback(2*totdim,2*totdim,2*totdim),&
       rbigcirc(2*totdim,2*totdim,2*totdim)

  bigcirc(:,:,:)=rbigcirc(:,:,:)
  multvector(:,:,:)=rmultvector(:,:,:)
  call circ3d_sub(bigcirc,multvector,ffback,totdim)
  rffback(:,:,:)=real(ffback(:,:,:),8)
end subroutine circ3d_sub_real



subroutine circ3d_sub(bigcirc,multvector,ffback,totdim)
  implicit none
  integer :: totdim
  complex*16 :: multvector(2*totdim,2*totdim,2*totdim), ffmat(2*totdim,2*totdim,2*totdim),ffvec(2*totdim,2*totdim,2*totdim),&
       ffprod(2*totdim,2*totdim,2*totdim),ffback(2*totdim,2*totdim,2*totdim), ffwork(2*totdim,2*totdim,2*totdim)
  complex*16 ::        bigcirc(2*totdim,2*totdim,2*totdim,1,1,1)

#ifdef MPIFLAG
  call myzfft3d_mpiwrap(bigcirc(:,:,:,1,1,1),ffmat(:,:,:),2*totdim)
  call myzfft3d_mpiwrap(multvector(:,:,:),ffvec(:,:,:),2*totdim)
  
  ffprod(:,:,:)=ffvec(:,:,:)*ffmat(:,:,:)/(2*totdim)**3
  
  ffwork(:,:,:)=CONJG(ffprod(:,:,:))
  call myzfft3d_mpiwrap(ffwork(:,:,:),ffback(:,:,:),2*totdim)
  ffback(:,:,:)=CONJG(ffback(:,:,:))
#else
  call myzfft3d(bigcirc(:,:,:,1,1,1),ffmat(:,:,:),2*totdim)
  call myzfft3d(multvector(:,:,:),ffvec(:,:,:),2*totdim)
  
  ffprod(:,:,:)=ffvec(:,:,:)*ffmat(:,:,:)/(2*totdim)**3
  
  ffwork(:,:,:)=CONJG(ffprod(:,:,:))
  call myzfft3d(ffwork(:,:,:),ffback(:,:,:),2*totdim)
  ffback(:,:,:)=CONJG(ffback(:,:,:))
#endif
end subroutine circ3d_sub



subroutine circ3d_sub_real_mpi(rbigcirc,rmultvector,rffback,totdim,blocksize,times)
  implicit none
  integer :: totdim,blocksize,times(*),atime,btime
  complex*16 :: multvector(2*totdim,2*totdim,2*blocksize), ffback(2*totdim,2*totdim,2*blocksize),&
       bigcirc(2*totdim,2*totdim,2*blocksize)
  real*8 :: rmultvector(2*totdim,2*totdim,2*blocksize), rffback(2*totdim,2*totdim,2*blocksize),&
       rbigcirc(2*totdim,2*totdim,2*blocksize)

  call myclock(atime)
  bigcirc(:,:,:)=rbigcirc(:,:,:)
  multvector(:,:,:)=rmultvector(:,:,:)
  call myclock(btime); times(6)=times(6)+btime-atime

  call circ3d_sub_mpi(bigcirc,multvector,ffback,totdim,blocksize,times)

  call myclock(atime)
  rffback(:,:,:)=real(ffback(:,:,:),8)
  call myclock(btime); times(6)=times(6)+btime-atime

end subroutine circ3d_sub_real_mpi

!!! times(6) = circ math
!!! from myzfft3d_par:
!!! times(1) = zero   times(2)=fourier
!!! from mytranspose times(3) = transpose   times(4) = mpi  times(5) = copy

recursive subroutine circ3d_sub_mpi(bigcirc,multvector,ffback,totdim,blocksize,times)
  implicit none
  integer :: totdim,blocksize,times(*),atime,btime
  complex*16 :: multvector(2*totdim,2*totdim,2*blocksize), ffmat(2*totdim,2*totdim,2*blocksize),&
       ffvec(2*totdim,2*totdim,2*blocksize),  ffprod(2*totdim,2*totdim,2*blocksize),&
       ffback(2*totdim,2*totdim,2*blocksize), ffwork(2*totdim,2*totdim,2*blocksize)
  complex*16 ::        bigcirc(2*totdim,2*totdim,2*blocksize,1,1,1)

!$OMP PARALLEL
!$OMP MASTER
  multvector(1,1,1)=0; multvector(2*totdim,2*totdim,2*blocksize)=0
  ffmat(1,1,1)=0; ffmat(2*totdim,2*totdim,2*blocksize)=0
  ffvec(1,1,1)=0; ffvec(2*totdim,2*totdim,2*blocksize)=0
  ffback(1,1,1)=0; ffback(2*totdim,2*totdim,2*blocksize)=0
  ffwork(1,1,1)=0; ffwork(2*totdim,2*totdim,2*blocksize)=0
  ffprod(1,1,1)=0; ffprod(2*totdim,2*totdim,2*blocksize)=0
!$OMP END MASTER
!$OMP BARRIER
!$OMP END PARALLEL

#ifdef MPIFLAG

  call myzfft3d_par(bigcirc(:,:,:,1,1,1),ffmat(:,:,:),2*totdim,2*blocksize,times)
  call myzfft3d_par(multvector(:,:,:),ffvec(:,:,:),2*totdim,2*blocksize,times)

  call myclock(atime)
  ffprod(:,:,:)=ffvec(:,:,:)*ffmat(:,:,:)/(2*totdim)**3
  ffwork(:,:,:)=CONJG(ffprod(:,:,:))
  call myclock(btime); times(6)=times(6)+btime-atime

  call myzfft3d_par(ffwork(:,:,:),ffback(:,:,:),2*totdim,2*blocksize,times)

  call myclock(atime)
  ffback(:,:,:)=CONJG(ffback(:,:,:))
  call myclock(btime); times(6)=times(6)+btime-atime

#else
  print *, "ACKKKK!!! MPIFLAG NOT SET"; stop
#endif

end subroutine circ3d_sub_mpi





subroutine toeplitz1d_sub(bigvector,smallmultvector,outvector,totdim,howmany)
  implicit none
  integer :: totdim,howmany
  complex*16 :: multvector(2*totdim,howmany),&
       outvector(totdim,howmany),smallmultvector(totdim,howmany),&
       bigcirc(2*totdim,1), ffback(2*totdim,howmany), &
       bigvector(1-totdim:totdim-1)

  bigcirc(:,:)=0d0
  
  bigcirc(2:totdim*2,1)=bigvector(:)
  
  multvector(:,:)=0d0
  multvector(1:totdim,:)=smallmultvector(:,:)

  call circ1d_sub(bigcirc,multvector,ffback,totdim,howmany)

  outvector(:,:)=ffback(totdim+1:2*totdim,:)
  
end subroutine toeplitz1d_sub

subroutine toeplitz1d_sub_real(bigvector,smallmultvector,outvector,totdim,howmany)
  implicit none
  integer :: totdim,howmany
  real*8 :: bigvector(1-totdim:totdim-1), &
       outvector(totdim,howmany),smallmultvector(totdim,howmany)
  complex*16 :: multvector(2*totdim,howmany), &
       bigcirc(2*totdim,1), ffback(2*totdim,howmany)

  bigcirc(:,:)=0d0
  
  bigcirc(2:totdim*2,1)=bigvector(:)
  
  multvector(:,:)=0d0
  multvector(1:totdim,:)=smallmultvector(:,:)

  call circ1d_sub(bigcirc,multvector,ffback,totdim,howmany)

  outvector(:,:)=real(ffback(totdim+1:2*totdim,:),8)
  
end subroutine toeplitz1d_sub_real




subroutine circ1d_sub(bigcirc,multvector,ffback,totdim,howmany)
  implicit none
  integer :: totdim,howmany,ii
  complex*16 :: multvector(2*totdim,howmany), ffmat(2*totdim),ffvec(2*totdim,howmany),&
       ffprod(2*totdim,howmany),ffback(2*totdim,howmany), ffwork(2*totdim,howmany)
  complex*16 ::        bigcirc(2*totdim,1)
  
  call myzfft1d(bigcirc(:,:),ffmat(:),2*totdim,1)
  call myzfft1d(multvector(:,:),ffvec(:,:),2*totdim,howmany)

  do ii=1,howmany
     ffprod(:,ii)=ffvec(:,ii)*ffmat(:)/(2*totdim)
  enddo

  ffwork(:,:)=CONJG(ffprod(:,:))
  call myzfft1d(ffwork(:,:),ffback(:,:),2*totdim,howmany)
  ffback(:,:)=CONJG(ffback(:,:))
  
end subroutine circ1d_sub




!! OLD VERSION WITH SHIFT ATTE MPT AT BOTTOM OF FILE

!! myrank is indexed 1:nprocs

module bothblockmod
  integer :: nprocs=-1,dim=-1,myrank=-1,maxblocksize=-1
  integer, allocatable :: mpiblocks(:),mpiblockend(:),mpiblockstart(:)
end module bothblockmod



#ifdef FFTWFLAG


recursive subroutine myzfft1d(in,out,dim,howmany)
  implicit none
  integer, intent(in) :: dim,howmany
  complex*16, intent(in) :: in(dim,howmany)
  complex*16, intent(out) :: out(dim,howmany)

  call fftw1dfftsub(in,out,dim,howmany)

end subroutine myzfft1d


subroutine myzfft3d(in,out,indim)
  use bothblockmod
  implicit none
  complex*16, intent(in) :: in(dim,dim,dim)
  complex*16, intent(out) :: out(dim,dim,dim)
  integer :: indim

  if (dim.ne.indim) then
     print *, "WRONG INIT FFTW3D",dim,indim;stop
  endif

  call fftw3dfftsub(in,out)

end subroutine myzfft3d

#else




recursive subroutine myzfft1d(in,out,dim,howmany)
  implicit none
  integer, intent(in) :: dim,howmany
  integer :: k
  complex*16, intent(in) :: in(dim,howmany)
  complex*16, intent(out) :: out(dim,howmany)
!  complex*16 :: wsave(20*dim+100,howmany)
  complex*16 :: wsave(4*dim+15,howmany)
!  complex*16 :: wsave(5*dim+128,howmany)

  out(:,:)=in(:,:)

!$OMP PARALLEL DEFAULT(PRIVATE) SHARED(in,out,dim,howmany,wsave)
!$OMP DO
  do k=1,howmany
!!???     wsave(1,k)=0; wsave(4*dim+15,k)=0
     call zffti(dim,wsave(:,k))
     call zfftf(dim,out(:,k),wsave(:,k))
  enddo
!$OMP END DO
!$OMP END PARALLEL
end subroutine myzfft1d



subroutine myzfft3d(in,out,indim)
  use bothblockmod
  implicit none
  complex*16, intent(in) :: in(dim,dim,dim)
  complex*16, intent(out) :: out(dim,dim,dim)
  integer :: indim
  complex*16 :: work(dim,dim,dim)
  integer :: ii,i

  if (dim.ne.indim) then
     print *, "WRONG INIT",dim,indim;stop
  endif

  out(:,:,:)=in(:,:,:)

  do ii=1,3
     call myzfft3d_oneblock(out,work,dim)
     do i=1,dim
        out(:,:,i)=work(i,:,:)
     enddo
  enddo

end subroutine myzfft3d

#endif




module littlestartmod
 integer :: mystart=(-1),mysize=(-1)
end module littlestartmod


subroutine setblock(innprocs,inmyrank,indims)
  use bothblockmod
  use littlestartmod
  implicit none
  integer :: innprocs,inmyrank,indims(3),i
  if (dim.ne.-1) then
     print *, "CALLME ONCE ONLY"; stop
  endif
  nprocs=innprocs
  myrank=inmyrank
  if (myrank.eq.0) then
     print *, "WRONG CONVENTION."; stop
  endif

  if (indims(2).ne.indims(3).or.indims(1).ne.indims(2)) then
     print *, "Only all dims equal for now", indims; stop
  endif

  dim=indims(1)
  allocate(mpiblocks(nprocs),mpiblockend(nprocs),mpiblockstart(nprocs))
  mpiblockstart(1)=1
  do i=1,nprocs
     mpiblockend(i)=(i*dim/nprocs)*dim**2
     if (i.lt.nprocs) then
        mpiblockstart(i+1)=mpiblockend(i)+1
     endif
  enddo
  maxblocksize = (-1)
  do i=1,nprocs
     mpiblocks(i)=mpiblockend(i)-mpiblockstart(i)+1
     if (mpiblocks(i).gt.maxblocksize) then
        maxblocksize=mpiblocks(i)
     endif
  enddo


  mystart=mpiblockstart(myrank)
  mysize=mpiblocks(myrank)

end subroutine setblock


subroutine unsetblock()
  use bothblockmod
  implicit none
  if (dim.eq.(-1)) then
     if (myrank.eq.1) then 
        print *, "HMM UNSET ME BUT WHY?";
     endif
     return !!stop
  endif
!!  nprocs=(-1);  myrank=(-1);  
  dim=(-1)
  deallocate(mpiblocks,mpiblockend,mpiblockstart)
end subroutine unsetblock



recursive subroutine myzfft3d_oneblock(in,out,insize)
  use bothblockmod
  implicit none
  integer :: insize
  complex*16, intent(in) :: in(dim,dim,insize)
  complex*16, intent(out) :: out(dim,dim,insize)

  if (dim.eq.-1) then
     print *, "NEED TO INITIALIZE FFTBLOCK";stop
  endif

  call myzfft1d(in(:,:,:),out(:,:,:),dim,insize*dim)

end subroutine myzfft3d_oneblock



#ifdef FFTWFLAG


recursive subroutine fftw3dfftsub(in,out)
  use, intrinsic :: iso_c_binding
  use bothblockmod
  implicit none
  include "fftw3.f03"

  type(C_PTR),save :: plan
  integer,save :: icalled=0
  complex*16 :: in(dim,dim,dim),out(dim,dim,dim)

  if (icalled.eq.0) then
     plan=fftw_plan_dft_3d(dim,dim,dim,in,out,FFTW_FORWARD,FFTW_EXHAUSTIVE) 
  endif
  icalled=1

  call fftw_execute_dft(plan, in,out)

!!$  call fftw_destroy_plan(plan)

end subroutine fftw3dfftsub


#ifdef MPIFFTW

subroutine fftw3dfftsub_mpi(in,out,indim,insize)
  use, intrinsic :: iso_c_binding
  use mpi
  use bothblockmod
  use littlestartmod
  include 'fftw3-mpi.f03'

  integer :: indim,insize
  integer, save :: icalled=0
  integer(C_INTPTR_T) :: alloc_local,LL,MM,SS
  complex*16,intent(in) :: in(dim,dim,mysize/dim**2)
  complex*16,intent(out) :: out(dim,dim,mysize/dim**2)
  type(C_PTR),save :: plan, cdata
  complex(C_DOUBLE_COMPLEX), pointer :: data(:,:,:)

  if (myrank.eq.1) then
     print *, "GO FFTW MPI SUB."
  endif

  LL=dim;MM=mysize/dim**2;SS=(mystart-1)/dim**2

  if (indim.ne.dim.or.insize.ne.mysize/dim**2) then
     print *, "AUGH FFTW MPI FFT ",indim,dim,insize,mysize; stop
  endif

!print *, "LMS ", LL,MM,SS

  alloc_local = fftw_mpi_local_size_3d(LL,LL,LL, MPI_COMM_WORLD, MM, SS)

!print *, "LMSnow ", LL,MM,SS


  cdata = fftw_alloc_complex(alloc_local)

  call c_f_pointer(cdata, data, [LL,LL,MM])
     
  if (icalled.eq.0) then

     !   create MPI plan for in-place forward DFT (note dimension reversal)

     plan = fftw_mpi_plan_dft_3d(LL,LL,LL, data, data, MPI_COMM_WORLD, FFTW_FORWARD, FFTW_EXHAUSTIVE)
  endif
  icalled=1

     ! initialize data to some function my_function(i,j)

  data(:, :,:) = in(:,:,:)
     
  ! compute transform (as many times as desired)

  call fftw_mpi_execute_dft(plan, data, data)

!!  call fftw_execute_dft(plan, data, data)

  out(:,:,:)=data(:,:,:)

  if (myrank.eq.1) then
     print *, "ok done fftw3dfftsub_mpi"
  endif

end subroutine fftw3dfftsub_mpi

#endif

subroutine fftw1dfftsub(in,out,dim,howmany)
  use, intrinsic :: iso_c_binding
  implicit none
  include "fftw3.f03"

  integer, intent(in) :: dim,howmany
  type(C_PTR),save :: plan
  integer,save :: icalled=0
  complex*16 :: in(dim,howmany),out(dim,howmany)
  integer :: ostride,istride,onembed(1),inembed(1),idist,odist, dims(1)

  inembed(1)=dim; onembed(1)=dim; idist=dim; odist=dim; istride=1; ostride=1; dims(1)=dim

  if (icalled.eq.0) then
     plan = fftw_plan_many_dft(1,dims,howmany,in,inembed,istride,idist,out,onembed,ostride,odist,FFTW_FORWARD,FFTW_EXHAUSTIVE) 
  endif
  icalled=1    

  call fftw_execute_dft(plan, in,out)

!!$  call fftw_destroy_plan(plan)
end subroutine fftw1dfftsub


#endif


#ifdef MPIFLAG

module transposemod
!!
!! generalized transpose subroutine adapted from sinc DVR two-electron
!!     demonstration programs SamTranspose / BigTranspose
!!     sent to C Yang, JRJ, S Williams 5/22/2013
!!
!!  djh 01 12 2015
!!


!! This is, I don't know, a "generalized transpose"
!!
!!  M(a,b,c,d,e) -> m(e,a,b,c,d)   last index (e first, d second) is length myblocksize
!!     others are length isize
!!

!!   (blockdim,blockdim   ,myblocksize)  dimensions
!!   (blockdim,jblocksize, myblocksize)  send
!!   (blockdim,myblocksize,iblocksize)  receive 
!!   (blockdim,myblocksize,blockdim) assemble
!!   (blockdim,blockdim,myblocksize) transpose (1,2,3)->(3,1,2)

!! mytranspose subroutine below is not the best way.
!!    in fact maybe it is the worst way?
!! obv. I could be doing several at a time i.e. for e.g. 5 or 6
!! dimensions (ndim) I am doing 5 or 6 transposes whereas I
!! need only do two.  I would just need to make the inverse
!! of the following function for the second transpose.

contains

!! times(1) = transpose   times(2) = mpi  times(3) = copy


recursive subroutine mytranspose(in,out,blockistart,blocksizes,blockdim,xmiddledim,myblocksize,xmaxblocksize,myrank,nprocs,times)
  use mpi
  implicit none
  integer,intent(in) :: myrank,nprocs,blocksizes(nprocs),blockistart(nprocs),myblocksize,xmaxblocksize,blockdim,xmiddledim
  integer,intent(inout) :: times(3)
       
  complex*16,intent(in) :: in(blockdim,blockdim,myblocksize)
  complex*16 :: intranspose(blockdim,myblocksize,blockdim) ,outtemp(blockdim,myblocksize,myblocksize,nprocs)
  complex*16,intent(out) :: out(blockdim,blockdim,myblocksize)
  integer :: ierr=0,atime,btime
  integer :: i,count

  if (xmiddledim.ne.blockdim) then
     print *, "ONLY ALL SAME PLEASE middle",xmiddledim,blockdim;stop
  endif
  if (xmaxblocksize.ne.myblocksize) then
     print *, "ONLY ALL SAME PLEASE",myrank,xmaxblocksize,myblocksize; stop
  endif
  if (myblocksize*nprocs.ne.blockdim) then
     print *, "NOT UNDERSTAAND",nprocs,myblocksize,blockdim; stop
  endif




   
  call myclock(atime)

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,count,ierr)
!$OMP MASTER
intranspose(blockdim,myblocksize,blockdim)=0;  intranspose(1,1,1)=0
outtemp(blockdim,myblocksize,myblocksize,nprocs)=0; outtemp(1,1,1,1)=0
!$OMP END MASTER
!$OMP BARRIER

!! YEAH THIS OMP HELPS BIGTIME
!$OMP DO SCHEDULE(STATIC)
  do i=1,myblocksize
     intranspose(:,i,:)=transpose(in(:,:,i))
  enddo
!$OMP END DO
!$OMP BARRIER
  call myclock(btime); times(1)=times(1)+btime-atime; atime=btime

!$OMP MASTER
  count=myblocksize**2 * blockdim
  call mpi_alltoall(intranspose,count,MPI_DOUBLE_COMPLEX,outtemp,count,MPI_DOUBLE_COMPLEX,MPI_COMM_WORLD,ierr)
  if (ierr.ne.0) then
     print *, "ALLTOALL ERR ", ierr,myrank,nprocs;     stop
  endif
  call myclock(btime); times(2)=times(2)+btime-atime; atime=btime
  do i=1,nprocs
     out(:,(i-1)*myblocksize+1:i*myblocksize,:)=outtemp(:,:,:,i)
  enddo

  call myclock(btime); times(3)=times(3)+btime-atime;
!$OMP END MASTER
!$OMP BARRIER
!$OMP END PARALLEL



!!$ !! HELPS TOO, JUST A LITTLE BIT
!!$ !$OMP DO SCHEDULE(STATIC)
!!$   do i=1,nprocs
!!$      out(:,(i-1)*myblocksize+1:i*myblocksize,:)=outtemp(:,:,:,i)
!!$   enddo
!!$ !$OMP END DO
!!$ !$OMP BARRIER
!!$ !$OMP END PARALLEL
!!$   deallocate(intranspose,outtemp)
!!$   call myclock(btime); times(3)=times(3)+btime-atime;


end subroutine mytranspose

end module  


subroutine myzfft3d_mpiwrap(in,out,indim)
  use littlestartmod
  use bothblockmod
  implicit none
  integer :: indim,nulltimes(10)
  complex*16, intent(in) :: in(dim**3)
  complex*16, intent(out) :: out(dim**3)

#ifdef MPIFFTW
  call fftw3dfftsub_mpi(in(mystart),out(mystart),indim,mysize/dim**2)
  return
#else

  if (dim.ne.indim) then
     print *, "WRONG INIT",dim,indim;stop
  endif

!  if (dims(1).ne.indim1.or.dims(2).ne.indim2.or.dims(3).ne.indim3) then
!     print *, "WRONG INIT",dims,indim1,indim2,indim3;stop
!  endif

  call myzfft3d_par(in(mystart),out(mystart),indim,mysize/dim**2,nulltimes)

#define TENxxTEST
#ifdef TENTEST
  write(*,'(4E20.10,A10,I5)') DOT_PRODUCT(&
       in(mystart:mystart+mysize-1),&
       in(mystart:mystart+mysize-1)),&
       DOT_PRODUCT(&
       out(mystart:mystart+mysize-1),&
       out(mystart:mystart+mysize-1)), &
       "DDOTPAR",myrank
  call mybarrier()
  stop
#endif

!!$  call mygatherv_complex(out,dim**3,&
!!$       (mpiblockstart(myrank)-1)*dim**2+1,&
!!$       (mpiblockend(myrank))*dim**2,&
!!$       mpiblocks(:)*dim**2,&
!!$       (mpiblockstart(:)-1)*dim**2+1,nprocs,myrank)

  call mygatherv_complex(out(mpiblockstart(myrank)),out,dim**3,&
       mpiblockstart(myrank),&
       mpiblockend(myrank),&
       mpiblocks(:),&
       mpiblockstart(:),.true.)

#endif

end subroutine myzfft3d_mpiwrap


subroutine mygatherv_wrap(in,out)
  use bothblockmod
  implicit none
  complex*16, intent(in) :: in(dim**3)
  complex*16, intent(out) :: out(dim**3)

  out(:)=in(:) 

  call mygatherv_complex(out(mpiblockstart(myrank)),out,dim**3,&
       mpiblockstart(myrank),&
       mpiblockend(myrank),&
       mpiblocks(:),&
       mpiblockstart(:),.true.)

end subroutine mygatherv_wrap


!! adds to times

!!! times(1) = zero   times(2)=fourier
!!! from mytranspose times(3) = transpose   times(4) = mpi  times(5) = copy
  
recursive subroutine myzfft3d_par(in,out,indim,inblockdim,times)
  use transposemod
  use bothblockmod
  use littlestartmod
  implicit none
!  complex*16, intent(in) :: in(dims(1),dims(2),mysize/dims(1)/dims(2))
!  complex*16, intent(out) :: out(dims(1),dims(2),mysize/dims(1)/dims(2))

  complex*16, intent(in) :: in(dim,dim,mysize/dim**2)
  complex*16, intent(out) :: out(dim,dim,mysize/dim**2)

  integer, intent(inout) :: times(8)

  integer :: indim,inblockdim,atime,btime
  complex*16 :: mywork(dim,dim,mysize/dim**2),tempout(dim,dim,mysize/dim**2)
  integer :: ii

  call myclock(atime)

!!$  if (dims(1)*dims(2)*(mysize/dims(1)/dims(2)).ne.mysize) then
  if (dim**2*(mysize/dim**2).ne.mysize) then
     print *, "WTF!!! 5656578",dim,mysize; stop
  endif

  if (dim.ne.indim) then
     print *, "WRONG INIT",dim,indim;stop
  endif

  if (dim**2*inblockdim.ne.mysize) then
     print *, "WRONG BLOCK",dim,indim," ",mysize,inblockdim,dim;stop
  endif

  if (mysize.ne.mpiblocks(myrank)) then
     print *, "MYSIZE/blocks disagree",mysize,mpiblocks(myrank),myrank,nprocs;stop
  endif

#ifdef MPIFFTW
  call fftw3dfftsub_mpi(in,out,indim,mysize/dim**2)
  return
#else

!$OMP PARALLEL
!$OMP MASTER
mywork(1,1,1)=0; tempout(1,1,1)=0
mywork(dim,dim,mysize/dim**2)=0; tempout(dim,dim,mysize/dim**2)=0
!$OMP END MASTER
!$OMP BARRIER
!$OMP END PARALLEL

  tempout(:,:,:)=in(:,:,:)

  call myclock(btime); times(1)=times(1)+btime-atime;

  do ii=1,3

     call myclock(atime)

#ifndef TENTEST
     call myzfft3d_oneblock( tempout, mywork, mysize/dim**2)
#else
     mywork(:,:,:)=tempout(:,:,:)*10
#endif

  call myclock(btime); times(2)=times(2)+btime-atime; atime=btime

!!$     call mytranspose(&
!!$         mywork,  &
!!$         out,  &
!!$         mpiblockstart,&
!!$         mpiblocks,  &
!!$         dim,  &
!!$         dim,  &
!!$         mpiblocks(myrank),  &
!!$         maxblocksize,  &
!!$         myrank,  &
!!$         nprocs)

!!! from mytranspose times(3) = transpose   times(4) = mpi  times(5) = copy
     call mytranspose(&
         mywork,  &
         tempout,  &
         (mpiblockstart-1)/dim**2+1,&
         mpiblocks/dim**2,  &
         dim,  &
         dim,  &
         mpiblocks(myrank)/dim**2,  &
         maxblocksize/dim**2,  &
         myrank,  &
         nprocs,times(3))

!!     call myclock(btime); times(2)=times(2)+btime-atime; atime=btime

  enddo

  out(:,:,:)=tempout(:,:,:)

#endif

end subroutine myzfft3d_par


#endif




!!$ SHIFT ATTE MPT

!!$
!!$subroutine myzfft1d(in,out,dim)
!!$  implicit none
!!$  integer, intent(in) :: dim
!!$  complex*16, intent(in) :: in(dim)
!!$  complex*16, intent(out) :: out(dim)
!!$
!!$! FT(FT*) is identity and so is FT(FT(FT(FT))) 
!!$!           with options 1 2 3
!!$!  With options 2 and 3, FT(FT) is the circulant matrix corresponding to inversion
!!$!
!!$! (1) default.  DIDN'T GET OTHERS TO WORK.  would like to perform inverse FT by 
!!$!                pointwise inverting vectors not with conjugation (for learning, not
!!$!                for speed!)
!!$! 
!!$  call myzfft1d0(in,out,dim,0,0,0)
!!$
!!$! (2) PLUS SHAPE 
!!$! call myzfft1d0(in,out,dim,1,1-dim,1-dim)
!!$
!!$!   symmetric
!!$!  call myzfft1d0(in,out,dim,1,1,1)
!!$
!!$end subroutine myzfft1d
!!$
!!$subroutine myzfft1d0(in,out,dim,shiftflag,ashifttimestwo,bshifttimestwo)
!!$  implicit none
!!$  integer, intent(in) :: dim,shiftflag,ashifttimestwo,bshifttimestwo
!!$  integer :: k
!!$  complex*16, intent(in) :: in(dim)
!!$  complex*16, intent(out) :: out(dim)
!!$  complex*16 :: wsave(20*dim+100),aexp=1,bexp=1,abexp=1
!!$  real*8, parameter :: &
!!$       pi     = 3.14159265358979323844d0
!!$!       piover2= 1.57079632679489661922d0
!!$
!!$!!            c(j)=the sum from k=1,...,n of
!!$!!
!!$!!                 c(k)*exp(-i*(j-1)*(k-1)*2*pi/n)
!!$!!
!!$!!                       where i=sqrt(-1)
!!$
!!$  if (shiftflag.ne.0) then
!!$     bexp=exp((0d0,-1d0)*bshifttimestwo*pi/dim)
!!$     aexp=exp((0d0,-1d0)*ashifttimestwo*pi/dim)
!!$     abexp=exp((0d0,-1d0)*bshifttimestwo*ashifttimestwo*pi/dim/2)
!!$  endif
!!$
!!$  out(:)=in(:)
!!$  if (shiftflag.ne.0) then
!!$     do k=1,dim
!!$        out(k+1:)=out(k+1:)*bexp
!!$     enddo
!!$  endif
!!$
!!$  call zffti(dim,wsave)
!!$  call zfftf(dim,out,wsave)
!!$
!!$  if (shiftflag.ne.0) then
!!$     do k=1,dim
!!$        out(k+1:)=out(k+1:)*aexp
!!$     enddo
!!$     out(:)=out(:)*abexp
!!$  endif
!!$
!!$end subroutine myzfft1d0


