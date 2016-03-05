!! PARAMETERS FILE FOR SINC DVR POLYATOMIC BASIS AND HAMILTONIAN:
!!            sincparinp namelist input.

#include "Definitions.INC"

module myparams
implicit none

DATATYPE :: twostrength=1d0  !! 1d0 = repulsive 0d0 = no interaction etc.
integer :: twotype = 1       !!  1 = short range sech^2 interaction  0 = constant interaction

DATATYPE :: harmstrength=1d0   !! harmonic potential

!! FOR KE MULT IN 1D, toepflag.ne.0 does single toeplitz matvec
integer :: toepflag=0

!! FOR TOTAL ORBITAL PARALLELIZATION, SET orbparflag=.true., AND parorbsplit=3 in &parinp
logical :: orbparflag=.false.

!! THE FOLLOWING FLAG IS THEN RELEVANT.  Option for parallel KE matvec, rate limiting step.
integer :: zke_paropt=1   !! 0=sendrecv 1=SUMMA (bcast before) 2=reduce after

!! fft_batchdim: determines batch size for matrix elements and 
!! fft_circbatchdim: determines sub batch size for FFT 
!!    defaults set small (less memory, more MPI messages) to avoid MPI problems when doing large 
!!    calculations.  Otherwise bigger values will be faster.  There is a message size sweet spot
!!    on many machines.
integer :: fft_batchdim=1     !! 1 = do nspf matrix elements in nspf batches (less memory)
                              !! 2 = do nspf^2 in one batch (faster unless MPI problems)
integer :: fft_circbatchdim=1 !! 0,1,2, circbatchdim < batchdim; larger faster unless MPI problems
integer :: fft_ct_paropt=1           !! fft_ct_paropt,
                                     !!    like zke_paropt: 0 = sendrecv 1 = summa
integer :: num_skip_orbs=0
integer :: orb_skip(200)=-1

integer :: numcenters=1
integer :: centershift(100)=0       !! grid point index for each center
real*8 :: nuccharges(100)=2d0       !! sech potential
real*8 :: softness(100)=1d0         !! sech potential

integer :: numpoints=15
real*8 :: spacing=0.25d0

integer :: orblanorder=500         !! krylov order for block lanczos orbital calculation
integer :: orblancheckmod=10       !! check every
real*8 :: orblanthresh=1d-4

integer :: capflag=0               !! Number of complex absorbing potentials
integer :: capmode=0               !! Capmode=1 is 
integer :: cappower(100)=2         !!   v_i(r)= capstrength_i*(r/capstart_i)^cappower_i
real*8 :: capstart(100)=0.001d0    !! Capmode=0 is    
real*8 :: capstrength(100)=0.01d0  !!   v_i(r)= capstrength_i*max(0,r-capstart_i)^cappower_i
real*8 :: mincap=0d0 , maxcap=1d30 !! V_CAP = -i* max(mincap,min(maxcap,sum_i v_i))

integer :: scalingflag=0           !! 1 = SMOOTH EXTERIOR COMPLEX SCALING
real*8 :: scalingdistance=10000d0  !! atomic units (bohr)
real*8 :: smoothness=5             !! atomic units (bohr)
real*8 :: scalingtheta=0d0         !! scaling angle
real*8 :: scalingstretch=1d0         !! stretching factor

!! construct virtual orbtials using density based on loaded orbitals
integer :: ivoflag=0
real*8 :: loadedocc(200)=2d0
!! XXSNIPXX 
!! INTERNAL

integer :: orbtargetflag=0
DATATYPE :: orbtarget=DATAZERO

integer :: numspf=-1
integer :: nbox=1  !! BOXES FOR PAR.
integer :: qbox=1

integer :: gridpoints=10

integer, parameter :: numr=1,bornopflag=1

!! internal

integer :: totpoints=(-1)
integer :: nonucrepflag=0
real*8 :: sumcharge, nucrepulsion
integer :: debugflag=0


end module myparams


