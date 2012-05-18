! Copyright 2011 Max-Planck-Institut für Eisenforschung GmbH
!
! This file is part of DAMASK,
! the Düsseldorf Advanced MAterial Simulation Kit.
!
! DAMASK is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! DAMASK is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with DAMASK. If not, see <http://www.gnu.org/licenses/>.
!
!##############################################################
!* $Id$
!************************************ 
!*  Module: CONSTITUTIVE_NONLOCAL   *
!************************************
!* contains:                        *
!* - constitutive equations         *
!* - parameters definition          *
!************************************


MODULE constitutive_nonlocal

!* Include other modules
use prec, only: pReal,pInt

implicit none
private


!* Definition of parameters

character (len=*), parameter, public :: &
constitutive_nonlocal_label = 'nonlocal'

character(len=22), dimension(10), parameter, private :: &
constitutive_nonlocal_listBasicStates = (/'rhoSglEdgePosMobile   ', &
                                          'rhoSglEdgeNegMobile   ', &
                                          'rhoSglScrewPosMobile  ', &
                                          'rhoSglScrewNegMobile  ', &
                                          'rhoSglEdgePosImmobile ', &
                                          'rhoSglEdgeNegImmobile ', &
                                          'rhoSglScrewPosImmobile', &
                                          'rhoSglScrewNegImmobile', &
                                          'rhoDipEdge            ', &
                                          'rhoDipScrew           ' /)! list of "basic" microstructural state variables that are independent from other state variables

character(len=16), dimension(3), parameter, private :: &
constitutive_nonlocal_listDependentStates = (/'rhoForest       ', &
                                              'tauThreshold    ', &
                                              'tauBack         ' /)  ! list of microstructural state variables that depend on other state variables

character(len=16), dimension(4), parameter, private :: &
constitutive_nonlocal_listOtherStates = (/'velocityEdgePos ', &
                                          'velocityEdgeNeg ', &
                                          'velocityScrewPos', &
                                          'velocityScrewNeg' /)      ! list of other dependent state variables that are not updated by microstructure

real(pReal), parameter, private :: &
kB = 1.38e-23_pReal                                                  ! Physical parameter, Boltzmann constant in J/Kelvin


!* Definition of global variables

integer(pInt), dimension(:), allocatable, public :: &
constitutive_nonlocal_sizeDotState, &                                ! number of dotStates = number of basic state variables
constitutive_nonlocal_sizeDependentState, &                          ! number of dependent state variables
constitutive_nonlocal_sizeState, &                                   ! total number of state variables
constitutive_nonlocal_sizePostResults                                ! cumulative size of post results

integer(pInt), dimension(:,:), allocatable, target, public :: &
constitutive_nonlocal_sizePostResult                                 ! size of each post result output

character(len=64), dimension(:,:), allocatable, target, public :: &
constitutive_nonlocal_output                                         ! name of each post result output

integer(pInt), dimension(:), allocatable, private :: &
constitutive_nonlocal_Noutput                                        ! number of outputs per instance of this plasticity 

character(len=32), dimension(:), allocatable, private :: &
constitutive_nonlocal_structureName                                  ! name of the lattice structure

integer(pInt), dimension(:), allocatable, public :: &
constitutive_nonlocal_structure                                      ! number representing the kind of lattice structure

integer(pInt), dimension(:), allocatable, private :: &
constitutive_nonlocal_totalNslip                                     ! total number of active slip systems for each instance

integer(pInt), dimension(:,:), allocatable, private :: &
constitutive_nonlocal_Nslip, &                                       ! number of active slip systems for each family and instance
constitutive_nonlocal_slipFamily, &                                  ! lookup table relating active slip system to slip family for each instance
constitutive_nonlocal_slipSystemLattice                              ! lookup table relating active slip system index to lattice slip system index for each instance

real(pReal), dimension(:), allocatable, private :: &
constitutive_nonlocal_CoverA, &                                      ! c/a ratio for hex type lattice
constitutive_nonlocal_C11, &                                         ! C11 element in elasticity matrix
constitutive_nonlocal_C12, &                                         ! C12 element in elasticity matrix
constitutive_nonlocal_C13, &                                         ! C13 element in elasticity matrix
constitutive_nonlocal_C33, &                                         ! C33 element in elasticity matrix
constitutive_nonlocal_C44, &                                         ! C44 element in elasticity matrix
constitutive_nonlocal_Gmod, &                                        ! shear modulus
constitutive_nonlocal_nu, &                                          ! poisson's ratio
constitutive_nonlocal_atomicVolume, &                                ! atomic volume
constitutive_nonlocal_Dsd0, &                                        ! prefactor for self-diffusion coefficient
constitutive_nonlocal_Qsd, &                                         ! activation enthalpy for diffusion
constitutive_nonlocal_aTolRho, &                                     ! absolute tolerance for dislocation density in state integration
constitutive_nonlocal_R, &                                           ! cutoff radius for dislocation stress
constitutive_nonlocal_doublekinkwidth, &                             ! width of a doubkle kink in multiples of the burgers vector length b
constitutive_nonlocal_solidSolutionEnergy, &                         ! activation energy for solid solution in J
constitutive_nonlocal_solidSolutionSize, &                           ! solid solution obstacle size in multiples of the burgers vector length
constitutive_nonlocal_solidSolutionConcentration, &                  ! concentration of solid solution in atomic parts
constitutive_nonlocal_p, &                                           ! parameter for kinetic law (Kocks,Argon,Ashby)
constitutive_nonlocal_q, &                                           ! parameter for kinetic law (Kocks,Argon,Ashby)
constitutive_nonlocal_viscosity, &                                   ! viscosity for dislocation glide in Pa s
constitutive_nonlocal_fattack, &                                     ! attack frequency in Hz
constitutive_nonlocal_rhoSglScatter, &                               ! standard deviation of scatter in initial dislocation density
constitutive_nonlocal_surfaceTransmissivity                          ! transmissivity at free surface

real(pReal), dimension(:,:,:), allocatable, private :: &
constitutive_nonlocal_Cslip_66                                       ! elasticity matrix in Mandel notation for each instance

real(pReal), dimension(:,:,:,:,:), allocatable, private :: &
constitutive_nonlocal_Cslip_3333                                     ! elasticity matrix for each instance

real(pReal), dimension(:,:), allocatable, private :: &
constitutive_nonlocal_rhoSglEdgePos0, &                              ! initial edge_pos dislocation density per slip system for each family and instance
constitutive_nonlocal_rhoSglEdgeNeg0, &                              ! initial edge_neg dislocation density per slip system for each family and instance
constitutive_nonlocal_rhoSglScrewPos0, &                             ! initial screw_pos dislocation density per slip system for each family and instance
constitutive_nonlocal_rhoSglScrewNeg0, &                             ! initial screw_neg dislocation density per slip system for each family and instance
constitutive_nonlocal_rhoDipEdge0, &                                 ! initial edge dipole dislocation density per slip system for each family and instance
constitutive_nonlocal_rhoDipScrew0, &                                ! initial screw dipole dislocation density per slip system for each family and instance
constitutive_nonlocal_lambda0PerSlipFamily, &                        ! mean free path prefactor for each family and instance
constitutive_nonlocal_lambda0, &                                     ! mean free path prefactor for each slip system and instance
constitutive_nonlocal_burgersPerSlipFamily, &                        ! absolute length of burgers vector [m] for each family and instance
constitutive_nonlocal_burgers, &                                     ! absolute length of burgers vector [m] for each slip system and instance
constitutive_nonlocal_interactionSlipSlip                            ! coefficients for slip-slip interaction for each interaction type and instance

real(pReal), dimension(:,:,:), allocatable, private :: &
constitutive_nonlocal_minimumDipoleHeightPerSlipFamily, &            ! minimum stable edge/screw dipole height for each family and instance
constitutive_nonlocal_minimumDipoleHeight, &                         ! minimum stable edge/screw dipole height for each slip system and instance
constitutive_nonlocal_peierlsStressPerSlipFamily, &                  ! Peierls stress (edge and screw) 
constitutive_nonlocal_peierlsStress                                  ! Peierls stress (edge and screw) 

real(pReal), dimension(:,:,:,:,:), allocatable, private :: &
constitutive_nonlocal_rhoDotFlux                                     ! dislocation convection term

real(pReal), dimension(:,:,:,:,:,:), allocatable, private :: &
constitutive_nonlocal_compatibility                                  ! slip system compatibility between me and my neighbors

real(pReal), dimension(:,:,:), allocatable, private :: &
constitutive_nonlocal_forestProjectionEdge, &                        ! matrix of forest projections of edge dislocations for each instance
constitutive_nonlocal_forestProjectionScrew, &                       ! matrix of forest projections of screw dislocations for each instance
constitutive_nonlocal_interactionMatrixSlipSlip                      ! interaction matrix of the different slip systems for each instance

real(pReal), dimension(:,:,:,:), allocatable, private :: &
constitutive_nonlocal_lattice2slip, &                                ! orthogonal transformation matrix from lattice coordinate system to slip coordinate system (passive rotation !!!)
constitutive_nonlocal_accumulatedShear                               ! accumulated shear per slip system up to the start of the FE increment

logical, dimension(:), allocatable, private :: &
constitutive_nonlocal_shortRangeStressCorrection                     ! flag indicating the use of the short range stress correction by a excess density gradient term

public :: &
constitutive_nonlocal_init, &
constitutive_nonlocal_stateInit, &
constitutive_nonlocal_aTolState, &
constitutive_nonlocal_homogenizedC, &
constitutive_nonlocal_microstructure, &
constitutive_nonlocal_LpAndItsTangent, &
constitutive_nonlocal_dotState, &
constitutive_nonlocal_deltaState, &
constitutive_nonlocal_dotTemperature, &
constitutive_nonlocal_updateCompatibility, &
constitutive_nonlocal_postResults

private :: &
constitutive_nonlocal_kinetics


CONTAINS

!**************************************
!*      Module initialization         *
!**************************************
subroutine constitutive_nonlocal_init(myFile)

use, intrinsic :: iso_fortran_env                                          ! to get compiler_version and compiler_options (at least for gfortran 4.6 at the moment)
use prec,     only: pInt, pReal
use math,     only: math_Mandel3333to66, & 
                    math_Voigt66to3333, & 
                    math_mul3x3, &
                    math_transpose33
use IO,       only: IO_lc, &
                    IO_getTag, &
                    IO_isBlank, &
                    IO_stringPos, &
                    IO_stringValue, &
                    IO_floatValue, &
                    IO_intValue, &
                    IO_error
use debug,    only: debug_what, &
                    debug_constitutive, &
                    debug_levelBasic
use mesh,     only: mesh_NcpElems, &
                    mesh_maxNips, &
                    FE_maxNipNeighbors
use material, only: homogenization_maxNgrains, &
                    phase_plasticity, &
                    phase_plasticityInstance, &
                    phase_Noutput
use lattice,  only: lattice_maxNslipFamily, &
                    lattice_maxNslip, &
                    lattice_maxNinteraction, &
                    lattice_NslipSystem, &
                    lattice_initializeStructure, &
                    lattice_sd, &
                    lattice_sn, &
                    lattice_st, &
                    lattice_interactionSlipSlip

!*** output variables

!*** input variables
integer(pInt), intent(in) ::                myFile

!*** local variables
integer(pInt), parameter ::                 maxNchunks = 21_pInt
integer(pInt), &
    dimension(1_pInt+2_pInt*maxNchunks) ::  positions
integer(pInt)                               section, &
                                            maxNinstance, &
                                            maxTotalNslip, &
                                            myStructure, &
                                            f, &                ! index of my slip family
                                            i, &                ! index of my instance of this plasticity
                                            j, &
                                            k, &
                                            l, &
                                            ns, &               ! short notation for total number of active slip systems for the current instance
                                            o, &                ! index of my output
                                            s, &                ! index of my slip system
                                            s1, &               ! index of my slip system
                                            s2, &               ! index of my slip system
                                            it, &               ! index of my interaction type
                                            mySize
character(len=64)                           tag
character(len=1024)                         line


!$OMP CRITICAL (write2out)
  write(6,*)
  write(6,*) '<<<+-  constitutive_',trim(constitutive_nonlocal_label),' init  -+>>>'
  write(6,*) '$Id$'
#include "compilation_info.f90"
!$OMP END CRITICAL (write2out)

maxNinstance = int(count(phase_plasticity == constitutive_nonlocal_label),pInt)
if (maxNinstance == 0) return                                                                                                       ! we don't have to do anything if there's no instance for this constitutive law

if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt) then
  !$OMP CRITICAL (write2out)
    write(6,'(a16,1x,i5)') '# instances:',maxNinstance
  !$OMP END CRITICAL (write2out)
endif


!*** space allocation for global variables

allocate(constitutive_nonlocal_sizeDotState(maxNinstance))
allocate(constitutive_nonlocal_sizeDependentState(maxNinstance))
allocate(constitutive_nonlocal_sizeState(maxNinstance))
allocate(constitutive_nonlocal_sizePostResults(maxNinstance))
allocate(constitutive_nonlocal_sizePostResult(maxval(phase_Noutput), maxNinstance))
allocate(constitutive_nonlocal_output(maxval(phase_Noutput), maxNinstance))
allocate(constitutive_nonlocal_Noutput(maxNinstance))
constitutive_nonlocal_sizeDotState = 0_pInt
constitutive_nonlocal_sizeDependentState = 0_pInt
constitutive_nonlocal_sizeState = 0_pInt
constitutive_nonlocal_sizePostResults = 0_pInt
constitutive_nonlocal_sizePostResult = 0_pInt
constitutive_nonlocal_output = ''
constitutive_nonlocal_Noutput = 0_pInt

allocate(constitutive_nonlocal_structureName(maxNinstance))
allocate(constitutive_nonlocal_structure(maxNinstance))
allocate(constitutive_nonlocal_Nslip(lattice_maxNslipFamily, maxNinstance))
allocate(constitutive_nonlocal_slipFamily(lattice_maxNslip, maxNinstance))
allocate(constitutive_nonlocal_slipSystemLattice(lattice_maxNslip, maxNinstance))
allocate(constitutive_nonlocal_totalNslip(maxNinstance))
constitutive_nonlocal_structureName = ''
constitutive_nonlocal_structure = 0_pInt
constitutive_nonlocal_Nslip = 0_pInt
constitutive_nonlocal_slipFamily = 0_pInt
constitutive_nonlocal_slipSystemLattice = 0_pInt
constitutive_nonlocal_totalNslip = 0_pInt

allocate(constitutive_nonlocal_CoverA(maxNinstance))
allocate(constitutive_nonlocal_C11(maxNinstance))
allocate(constitutive_nonlocal_C12(maxNinstance))
allocate(constitutive_nonlocal_C13(maxNinstance))
allocate(constitutive_nonlocal_C33(maxNinstance))
allocate(constitutive_nonlocal_C44(maxNinstance))
allocate(constitutive_nonlocal_Gmod(maxNinstance))
allocate(constitutive_nonlocal_nu(maxNinstance))
allocate(constitutive_nonlocal_atomicVolume(maxNinstance))
allocate(constitutive_nonlocal_Dsd0(maxNinstance))
allocate(constitutive_nonlocal_Qsd(maxNinstance))
allocate(constitutive_nonlocal_aTolRho(maxNinstance))
allocate(constitutive_nonlocal_Cslip_66(6,6,maxNinstance))
allocate(constitutive_nonlocal_Cslip_3333(3,3,3,3,maxNinstance))
allocate(constitutive_nonlocal_R(maxNinstance))
allocate(constitutive_nonlocal_doublekinkwidth(maxNinstance))
allocate(constitutive_nonlocal_solidSolutionEnergy(maxNinstance))
allocate(constitutive_nonlocal_solidSolutionSize(maxNinstance))
allocate(constitutive_nonlocal_solidSolutionConcentration(maxNinstance))
allocate(constitutive_nonlocal_p(maxNinstance))
allocate(constitutive_nonlocal_q(maxNinstance))
allocate(constitutive_nonlocal_viscosity(maxNinstance))
allocate(constitutive_nonlocal_fattack(maxNinstance))
allocate(constitutive_nonlocal_rhoSglScatter(maxNinstance))
allocate(constitutive_nonlocal_surfaceTransmissivity(maxNinstance))
allocate(constitutive_nonlocal_shortRangeStressCorrection(maxNinstance))
constitutive_nonlocal_CoverA = 0.0_pReal 
constitutive_nonlocal_C11 = 0.0_pReal
constitutive_nonlocal_C12 = 0.0_pReal
constitutive_nonlocal_C13 = 0.0_pReal
constitutive_nonlocal_C33 = 0.0_pReal
constitutive_nonlocal_C44 = 0.0_pReal
constitutive_nonlocal_Gmod = 0.0_pReal
constitutive_nonlocal_atomicVolume = 0.0_pReal
constitutive_nonlocal_Dsd0 = 0.0_pReal
constitutive_nonlocal_Qsd = 0.0_pReal
constitutive_nonlocal_aTolRho = 0.0_pReal
constitutive_nonlocal_nu = 0.0_pReal
constitutive_nonlocal_Cslip_66 = 0.0_pReal
constitutive_nonlocal_Cslip_3333 = 0.0_pReal
constitutive_nonlocal_R = -1.0_pReal
constitutive_nonlocal_doublekinkwidth = 0.0_pReal
constitutive_nonlocal_solidSolutionEnergy = 0.0_pReal
constitutive_nonlocal_solidSolutionSize = 0.0_pReal
constitutive_nonlocal_solidSolutionConcentration = 0.0_pReal
constitutive_nonlocal_p = 1.0_pReal
constitutive_nonlocal_q = 1.0_pReal
constitutive_nonlocal_viscosity = 0.0_pReal
constitutive_nonlocal_fattack = 0.0_pReal
constitutive_nonlocal_rhoSglScatter = 0.0_pReal
constitutive_nonlocal_surfaceTransmissivity = 1.0_pReal
constitutive_nonlocal_shortRangeStressCorrection = .true.

allocate(constitutive_nonlocal_rhoSglEdgePos0(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_nonlocal_rhoSglEdgeNeg0(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_nonlocal_rhoSglScrewPos0(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_nonlocal_rhoSglScrewNeg0(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_nonlocal_rhoDipEdge0(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_nonlocal_rhoDipScrew0(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_nonlocal_burgersPerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_nonlocal_Lambda0PerSlipFamily(lattice_maxNslipFamily,maxNinstance))
allocate(constitutive_nonlocal_interactionSlipSlip(lattice_maxNinteraction,maxNinstance))
constitutive_nonlocal_rhoSglEdgePos0 = -1.0_pReal
constitutive_nonlocal_rhoSglEdgeNeg0 = -1.0_pReal
constitutive_nonlocal_rhoSglScrewPos0 = -1.0_pReal
constitutive_nonlocal_rhoSglScrewNeg0 = -1.0_pReal
constitutive_nonlocal_rhoDipEdge0 = -1.0_pReal
constitutive_nonlocal_rhoDipScrew0 = -1.0_pReal
constitutive_nonlocal_burgersPerSlipFamily = 0.0_pReal
constitutive_nonlocal_lambda0PerSlipFamily = 0.0_pReal
constitutive_nonlocal_interactionSlipSlip = 0.0_pReal

allocate(constitutive_nonlocal_minimumDipoleHeightPerSlipFamily(lattice_maxNslipFamily,2,maxNinstance))
allocate(constitutive_nonlocal_peierlsStressPerSlipFamily(lattice_maxNslipFamily,2,maxNinstance))
constitutive_nonlocal_minimumDipoleHeightPerSlipFamily = 0.0_pReal
constitutive_nonlocal_peierlsStressPerSlipFamily = 0.0_pReal

!*** readout data from material.config file

rewind(myFile)
line = ''
section = 0_pInt

do while (IO_lc(IO_getTag(line,'<','>')) /= 'phase')                                                                               ! wind forward to <phase>
  read(myFile,'(a1024)',END=100) line
enddo

do                                                                                                                                 ! read thru sections of phase part
  read(myFile,'(a1024)',END=100) line
  if (IO_isBlank(line)) cycle                                                                                                      ! skip empty lines
  if (IO_getTag(line,'<','>') /= '') exit                                                                                          ! stop at next part
  if (IO_getTag(line,'[',']') /= '') then                                                                                          ! next section
    section = section + 1_pInt                                                                                                     ! advance section counter
    cycle
  endif
  if (section > 0_pInt .and. phase_plasticity(section) == constitutive_nonlocal_label) then                                        ! one of my sections
    i = phase_plasticityInstance(section)                                                                                          ! which instance of my plasticity is present phase
    positions = IO_stringPos(line,maxNchunks)
    tag = IO_lc(IO_stringValue(line,positions,1_pInt))                                                                             ! extract key
    select case(tag)
      case('plasticity','elasticity','/nonlocal/')
        cycle
      case ('(output)')
        constitutive_nonlocal_Noutput(i) = constitutive_nonlocal_Noutput(i) + 1_pInt
        constitutive_nonlocal_output(constitutive_nonlocal_Noutput(i),i) = IO_lc(IO_stringValue(line,positions,2_pInt))
      case ('lattice_structure')
        constitutive_nonlocal_structureName(i) = IO_lc(IO_stringValue(line,positions,2_pInt))
      case ('c/a_ratio','covera_ratio')
        constitutive_nonlocal_CoverA(i) = IO_floatValue(line,positions,2_pInt)
      case ('c11')
        constitutive_nonlocal_C11(i) = IO_floatValue(line,positions,2_pInt)
      case ('c12')
        constitutive_nonlocal_C12(i) = IO_floatValue(line,positions,2_pInt)
      case ('c13')
        constitutive_nonlocal_C13(i) = IO_floatValue(line,positions,2_pInt)
      case ('c33')
        constitutive_nonlocal_C33(i) = IO_floatValue(line,positions,2_pInt)
      case ('c44')
        constitutive_nonlocal_C44(i) = IO_floatValue(line,positions,2_pInt)
      case ('nslip')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_Nslip(f,i) = IO_intValue(line,positions,1_pInt+f)
      case ('rhosgledgepos0')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_rhoSglEdgePos0(f,i) = IO_floatValue(line,positions,1_pInt+f)
      case ('rhosgledgeneg0')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_rhoSglEdgeNeg0(f,i) = IO_floatValue(line,positions,1_pInt+f)
      case ('rhosglscrewpos0')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_rhoSglScrewPos0(f,i) = IO_floatValue(line,positions,1_pInt+f)
      case ('rhosglscrewneg0')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_rhoSglScrewNeg0(f,i) = IO_floatValue(line,positions,1_pInt+f)
      case ('rhodipedge0')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_rhoDipEdge0(f,i) = IO_floatValue(line,positions,1_pInt+f)
      case ('rhodipscrew0')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_rhoDipScrew0(f,i) = IO_floatValue(line,positions,1_pInt+f)
      case ('lambda0')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_lambda0PerSlipFamily(f,i) = IO_floatValue(line,positions,1_pInt+f)
      case ('burgers')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_burgersPerSlipFamily(f,i) = IO_floatValue(line,positions,1_pInt+f)
      case('cutoffradius','r')
        constitutive_nonlocal_R(i) = IO_floatValue(line,positions,2_pInt)
      case('minimumdipoleheightedge','ddipminedge')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_minimumDipoleHeightPerSlipFamily(f,1_pInt,i) = IO_floatValue(line,positions,1_pInt+f)
      case('minimumdipoleheightscrew','ddipminscrew')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_minimumDipoleHeightPerSlipFamily(f,2_pInt,i) = IO_floatValue(line,positions,1_pInt+f)
      case('atomicvolume')
        constitutive_nonlocal_atomicVolume(i) = IO_floatValue(line,positions,2_pInt)
      case('selfdiffusionprefactor','dsd0')
        constitutive_nonlocal_Dsd0(i) = IO_floatValue(line,positions,2_pInt)
      case('selfdiffusionenergy','qsd')
        constitutive_nonlocal_Qsd(i) = IO_floatValue(line,positions,2_pInt)
      case('atol_rho')
        constitutive_nonlocal_aTolRho(i) = IO_floatValue(line,positions,2_pInt)
      case ('interaction_slipslip')
        forall (it = 1_pInt:lattice_maxNinteraction) &
          constitutive_nonlocal_interactionSlipSlip(it,i) = IO_floatValue(line,positions,1_pInt+it)
      case('peierlsstressedge')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_peierlsStressPerSlipFamily(f,1_pInt,i) = IO_floatValue(line,positions,1_pInt+f)
      case('peierlsstressscrew')
        forall (f = 1_pInt:lattice_maxNslipFamily) &
          constitutive_nonlocal_peierlsStressPerSlipFamily(f,2_pInt,i) = IO_floatValue(line,positions,1_pInt+f)
      case('doublekinkwidth')
        constitutive_nonlocal_doublekinkwidth(i) = IO_floatValue(line,positions,2_pInt)
      case('solidsolutionenergy')
        constitutive_nonlocal_solidSolutionEnergy(i) = IO_floatValue(line,positions,2_pInt)
      case('solidsolutionsize')
        constitutive_nonlocal_solidSolutionSize(i) = IO_floatValue(line,positions,2_pInt)
      case('solidsolutionconcentration')
        constitutive_nonlocal_solidSolutionConcentration(i) = IO_floatValue(line,positions,2_pInt)
      case('p')
        constitutive_nonlocal_p(i) = IO_floatValue(line,positions,2_pInt)
      case('q')
        constitutive_nonlocal_q(i) = IO_floatValue(line,positions,2_pInt)
      case('viscosity','glideviscosity')
        constitutive_nonlocal_viscosity(i) = IO_floatValue(line,positions,2_pInt)
      case('attackfrequency','fattack')
        constitutive_nonlocal_fattack(i) = IO_floatValue(line,positions,2_pInt)
      case('rhosglscatter')
        constitutive_nonlocal_rhoSglScatter(i) = IO_floatValue(line,positions,2_pInt)
      case('surfacetransmissivity')
        constitutive_nonlocal_surfaceTransmissivity(i) = IO_floatValue(line,positions,2_pInt)
      case('shortrangestresscorrection')
        constitutive_nonlocal_shortRangeStressCorrection(i) = IO_floatValue(line,positions,2_pInt) > 0.0_pReal
      case default
        call IO_error(250_pInt,ext_msg=tag)
    end select
  endif
enddo


100 do i = 1_pInt,maxNinstance

  constitutive_nonlocal_structure(i) = &
    lattice_initializeStructure(constitutive_nonlocal_structureName(i), constitutive_nonlocal_CoverA(i))                            ! our lattice structure is defined in the material.config file by the structureName (and the c/a ratio)
  myStructure = constitutive_nonlocal_structure(i)
  
  
  !*** sanity checks
  
  if (myStructure < 1_pInt .or. myStructure > 3_pInt)                   call IO_error(205_pInt)
  if (sum(constitutive_nonlocal_Nslip(:,i)) <= 0_pInt)                  call IO_error(251_pInt,ext_msg='Nslip')
  do o = 1_pInt,maxval(phase_Noutput)
    if(len(constitutive_nonlocal_output(o,i)) > 64_pInt)                call IO_error(666_pInt)
  enddo
  do f = 1_pInt,lattice_maxNslipFamily
    if (constitutive_nonlocal_Nslip(f,i) > 0_pInt) then
      if (constitutive_nonlocal_rhoSglEdgePos0(f,i) < 0.0_pReal)        call IO_error(251_pInt,ext_msg='rhoSglEdgePos0')
      if (constitutive_nonlocal_rhoSglEdgeNeg0(f,i) < 0.0_pReal)        call IO_error(251_pInt,ext_msg='rhoSglEdgeNeg0')
      if (constitutive_nonlocal_rhoSglScrewPos0(f,i) < 0.0_pReal)       call IO_error(251_pInt,ext_msg='rhoSglScrewPos0')
      if (constitutive_nonlocal_rhoSglScrewNeg0(f,i) < 0.0_pReal)       call IO_error(251_pInt,ext_msg='rhoSglScrewNeg0')
      if (constitutive_nonlocal_rhoDipEdge0(f,i) < 0.0_pReal)           call IO_error(251_pInt,ext_msg='rhoDipEdge0')
      if (constitutive_nonlocal_rhoDipScrew0(f,i) < 0.0_pReal)          call IO_error(251_pInt,ext_msg='rhoDipScrew0')
      if (constitutive_nonlocal_burgersPerSlipFamily(f,i) <= 0.0_pReal) call IO_error(251_pInt,ext_msg='burgers')
      if (constitutive_nonlocal_lambda0PerSlipFamily(f,i) <= 0.0_pReal) call IO_error(251_pInt,ext_msg='lambda0')
      if (constitutive_nonlocal_minimumDipoleHeightPerSlipFamily(f,1,i) <= 0.0_pReal) &
                                                                        call IO_error(251_pInt,ext_msg='minimumDipoleHeightEdge')
      if (constitutive_nonlocal_minimumDipoleHeightPerSlipFamily(f,2,i) <= 0.0_pReal) &
                                                                        call IO_error(251_pInt,ext_msg='minimumDipoleHeightScrew')
      if (constitutive_nonlocal_peierlsStressPerSlipFamily(f,1,i) <= 0.0_pReal) call IO_error(251_pInt,ext_msg='peierlsStressEdge')
      if (constitutive_nonlocal_peierlsStressPerSlipFamily(f,2,i) <= 0.0_pReal) call IO_error(251_pInt,ext_msg='peierlsStressScrew')
    endif
  enddo
  if (any(constitutive_nonlocal_interactionSlipSlip(1:maxval(lattice_interactionSlipSlip(:,:,myStructure)),i) < 0.0_pReal)) &
                                                                        call IO_error(251_pInt,ext_msg='interaction_SlipSlip')
  if (constitutive_nonlocal_R(i) < 0.0_pReal)                           call IO_error(251_pInt,ext_msg='r')
  if (constitutive_nonlocal_atomicVolume(i) <= 0.0_pReal)               call IO_error(251_pInt,ext_msg='atomicVolume')
  if (constitutive_nonlocal_Dsd0(i) <= 0.0_pReal)                       call IO_error(251_pInt,ext_msg='selfDiffusionPrefactor')
  if (constitutive_nonlocal_Qsd(i) <= 0.0_pReal)                        call IO_error(251_pInt,ext_msg='selfDiffusionEnergy')
  if (constitutive_nonlocal_aTolRho(i) <= 0.0_pReal)                    call IO_error(251_pInt,ext_msg='aTol_rho')
  if (constitutive_nonlocal_doublekinkwidth(i) <= 0.0_pReal)            call IO_error(251_pInt,ext_msg='doublekinkwidth')
  if (constitutive_nonlocal_solidSolutionEnergy(i) <= 0.0_pReal)        call IO_error(251_pInt,ext_msg='solidSolutionEnergy')
  if (constitutive_nonlocal_solidSolutionSize(i) <= 0.0_pReal)          call IO_error(251_pInt,ext_msg='solidSolutionSize')
  if (constitutive_nonlocal_solidSolutionConcentration(i) <= 0.0_pReal) call IO_error(251_pInt,ext_msg='solidSolutionConcentration')
  if (constitutive_nonlocal_p(i) <= 0.0_pReal .or. constitutive_nonlocal_p(i) > 1.0_pReal) call IO_error(251_pInt,ext_msg='p')
  if (constitutive_nonlocal_q(i) < 1.0_pReal .or. constitutive_nonlocal_q(i) > 2.0_pReal) call IO_error(251_pInt,ext_msg='q')
  if (constitutive_nonlocal_viscosity(i) <= 0.0_pReal)                  call IO_error(251_pInt,ext_msg='viscosity')
  if (constitutive_nonlocal_fattack(i) <= 0.0_pReal)                    call IO_error(251_pInt,ext_msg='attackFrequency')
  if (constitutive_nonlocal_rhoSglScatter(i) < 0.0_pReal)               call IO_error(251_pInt,ext_msg='rhoSglScatter')
  if (constitutive_nonlocal_surfaceTransmissivity(i) < 0.0_pReal &
      .or. constitutive_nonlocal_surfaceTransmissivity(i) > 1.0_pReal)  call IO_error(251_pInt,ext_msg='surfaceTransmissivity')
  
  
  !*** determine total number of active slip systems
  
  constitutive_nonlocal_Nslip(1:lattice_maxNslipFamily,i) = min( lattice_NslipSystem(1:lattice_maxNslipFamily, myStructure), &
                                                                constitutive_nonlocal_Nslip(1:lattice_maxNslipFamily,i) )           ! we can't use more slip systems per family than specified in lattice 
  constitutive_nonlocal_totalNslip(i) = sum(constitutive_nonlocal_Nslip(1:lattice_maxNslipFamily,i))

enddo


!*** allocation of variables whose size depends on the total number of active slip systems

maxTotalNslip = maxval(constitutive_nonlocal_totalNslip)

allocate(constitutive_nonlocal_burgers(maxTotalNslip, maxNinstance))
constitutive_nonlocal_burgers = 0.0_pReal

allocate(constitutive_nonlocal_lambda0(maxTotalNslip, maxNinstance))
constitutive_nonlocal_lambda0 = 0.0_pReal

allocate(constitutive_nonlocal_minimumDipoleHeight(maxTotalNslip,2,maxNinstance))
constitutive_nonlocal_minimumDipoleHeight = 0.0_pReal

allocate(constitutive_nonlocal_forestProjectionEdge(maxTotalNslip, maxTotalNslip, maxNinstance))
constitutive_nonlocal_forestProjectionEdge = 0.0_pReal

allocate(constitutive_nonlocal_forestProjectionScrew(maxTotalNslip, maxTotalNslip, maxNinstance))
constitutive_nonlocal_forestProjectionScrew = 0.0_pReal

allocate(constitutive_nonlocal_interactionMatrixSlipSlip(maxTotalNslip, maxTotalNslip, maxNinstance))
constitutive_nonlocal_interactionMatrixSlipSlip = 0.0_pReal

allocate(constitutive_nonlocal_lattice2slip(1:3, 1:3, maxTotalNslip, maxNinstance))
constitutive_nonlocal_lattice2slip = 0.0_pReal

allocate(constitutive_nonlocal_accumulatedShear(maxTotalNslip, homogenization_maxNgrains, mesh_maxNips, mesh_NcpElems))
constitutive_nonlocal_accumulatedShear = 0.0_pReal

allocate(constitutive_nonlocal_rhoDotFlux(maxTotalNslip, 10, homogenization_maxNgrains, mesh_maxNips, mesh_NcpElems))
constitutive_nonlocal_rhoDotFlux = 0.0_pReal

allocate(constitutive_nonlocal_compatibility(2,maxTotalNslip, maxTotalNslip, FE_maxNipNeighbors, mesh_maxNips, mesh_NcpElems))
constitutive_nonlocal_compatibility = 0.0_pReal

allocate(constitutive_nonlocal_peierlsStress(maxTotalNslip,2,maxNinstance))
constitutive_nonlocal_peierlsStress = 0.0_pReal

do i = 1,maxNinstance
  
  myStructure = constitutive_nonlocal_structure(i)                                                                                  ! lattice structure of this instance
    

  !*** Inverse lookup of my slip system family and the slip system in lattice
  
  l = 0_pInt
  do f = 1_pInt,lattice_maxNslipFamily
    do s = 1_pInt,constitutive_nonlocal_Nslip(f,i)
      l = l + 1_pInt
      constitutive_nonlocal_slipFamily(l,i) = f
      constitutive_nonlocal_slipSystemLattice(l,i) = sum(lattice_NslipSystem(1:f-1_pInt, myStructure)) + s
  enddo; enddo
  
  
  !*** determine size of state array
  
  ns = constitutive_nonlocal_totalNslip(i)
  constitutive_nonlocal_sizeDotState(i) = int(size(constitutive_nonlocal_listBasicStates),pInt) * ns
  constitutive_nonlocal_sizeDependentState(i) = int(size(constitutive_nonlocal_listDependentStates),pInt) * ns
  constitutive_nonlocal_sizeState(i) = constitutive_nonlocal_sizeDotState(i) &
                                     + constitutive_nonlocal_sizeDependentState(i) &
                                     + int(size(constitutive_nonlocal_listOtherStates),pInt) * ns

  
  !*** determine size of postResults array
  
  do o = 1_pInt,constitutive_nonlocal_Noutput(i)
    select case(constitutive_nonlocal_output(o,i))
      case( 'rho', &
            'delta', &
            'rho_edge', &
            'rho_screw', &
            'rho_sgl', &
            'delta_sgl', &
            'rho_sgl_edge', &
            'rho_sgl_edge_pos', &
            'rho_sgl_edge_neg', &
            'rho_sgl_screw', &
            'rho_sgl_screw_pos', &
            'rho_sgl_screw_neg', &
            'rho_sgl_mobile', &
            'rho_sgl_edge_mobile', &
            'rho_sgl_edge_pos_mobile', &
            'rho_sgl_edge_neg_mobile', &
            'rho_sgl_screw_mobile', &
            'rho_sgl_screw_pos_mobile', &
            'rho_sgl_screw_neg_mobile', &
            'rho_sgl_immobile', &
            'rho_sgl_edge_immobile', &
            'rho_sgl_edge_pos_immobile', &
            'rho_sgl_edge_neg_immobile', &
            'rho_sgl_screw_immobile', &
            'rho_sgl_screw_pos_immobile', &
            'rho_sgl_screw_neg_immobile', &
            'rho_dip', &
            'delta_dip', &
            'rho_dip_edge', &
            'rho_dip_screw', &
            'excess_rho', &
            'excess_rho_edge', &
            'excess_rho_screw', &
            'rho_forest', &
            'shearrate', &
            'resolvedstress', &
            'resolvedstress_external', &
            'resolvedstress_back', &
            'resistance', &
            'rho_dot', &
            'rho_dot_sgl', &
            'rho_dot_dip', &
            'rho_dot_gen', &
            'rho_dot_gen_edge', &
            'rho_dot_gen_screw', &
            'rho_dot_sgl2dip', &
            'rho_dot_ann_ath', &
            'rho_dot_ann_the', &
            'rho_dot_flux', &
            'rho_dot_flux_edge', &
            'rho_dot_flux_screw', &
            'velocity_edge_pos', &
            'velocity_edge_neg', &
            'velocity_screw_pos', &
            'velocity_screw_neg', &
            'fluxdensity_edge_pos_x', &
            'fluxdensity_edge_pos_y', &
            'fluxdensity_edge_pos_z', &
            'fluxdensity_edge_neg_x', &
            'fluxdensity_edge_neg_y', &
            'fluxdensity_edge_neg_z', &
            'fluxdensity_screw_pos_x', &
            'fluxdensity_screw_pos_y', &
            'fluxdensity_screw_pos_z', &
            'fluxdensity_screw_neg_x', &
            'fluxdensity_screw_neg_y', &
            'fluxdensity_screw_neg_z', &
            'maximumdipoleheight_edge', &
            'maximumdipoleheight_screw', &
            'accumulatedshear' )
        mySize = constitutive_nonlocal_totalNslip(i)
      case('dislocationstress')
        mySize = 6_pInt
      case default
        call IO_error(252_pInt,ext_msg=constitutive_nonlocal_output(o,i))
    end select

    if (mySize > 0_pInt) then                                                                                                       ! any meaningful output found                               
      constitutive_nonlocal_sizePostResult(o,i) = mySize
      constitutive_nonlocal_sizePostResults(i)  = constitutive_nonlocal_sizePostResults(i) + mySize
    endif
  enddo
  
  
  !*** elasticity matrix and shear modulus according to material.config
  
  select case (myStructure)
    case(1_pInt:2_pInt)                                                                                                             ! cubic(s)
      forall(k=1_pInt:3_pInt)
        forall(j=1_pInt:3_pInt) constitutive_nonlocal_Cslip_66(k,j,i) = constitutive_nonlocal_C12(i)
        constitutive_nonlocal_Cslip_66(k,k,i) = constitutive_nonlocal_C11(i)
        constitutive_nonlocal_Cslip_66(k+3_pInt,k+3_pInt,i) = constitutive_nonlocal_C44(i)
      end forall
    case(3_pInt:)                                                                                                                   ! all hex
      constitutive_nonlocal_Cslip_66(1,1,i) = constitutive_nonlocal_C11(i)
      constitutive_nonlocal_Cslip_66(2,2,i) = constitutive_nonlocal_C11(i)
      constitutive_nonlocal_Cslip_66(3,3,i) = constitutive_nonlocal_C33(i)
      constitutive_nonlocal_Cslip_66(1,2,i) = constitutive_nonlocal_C12(i)
      constitutive_nonlocal_Cslip_66(2,1,i) = constitutive_nonlocal_C12(i)
      constitutive_nonlocal_Cslip_66(1,3,i) = constitutive_nonlocal_C13(i)
      constitutive_nonlocal_Cslip_66(3,1,i) = constitutive_nonlocal_C13(i)
      constitutive_nonlocal_Cslip_66(2,3,i) = constitutive_nonlocal_C13(i)
      constitutive_nonlocal_Cslip_66(3,2,i) = constitutive_nonlocal_C13(i)
      constitutive_nonlocal_Cslip_66(4,4,i) = constitutive_nonlocal_C44(i)
      constitutive_nonlocal_Cslip_66(5,5,i) = constitutive_nonlocal_C44(i)
      constitutive_nonlocal_Cslip_66(6,6,i) = 0.5_pReal*(constitutive_nonlocal_C11(i)- constitutive_nonlocal_C12(i))
  end select
  constitutive_nonlocal_Cslip_66(1:6,1:6,i) = math_Mandel3333to66(math_Voigt66to3333(constitutive_nonlocal_Cslip_66(1:6,1:6,i)))
  constitutive_nonlocal_Cslip_3333(1:3,1:3,1:3,1:3,i) = math_Voigt66to3333(constitutive_nonlocal_Cslip_66(1:6,1:6,i))

  constitutive_nonlocal_Gmod(i) = 0.2_pReal * ( constitutive_nonlocal_C11(i) - constitutive_nonlocal_C12(i) &
                                                + 3.0_pReal*constitutive_nonlocal_C44(i) )                                          ! (C11iso-C12iso)/2 with C11iso=(3*C11+2*C12+4*C44)/5 and C12iso=(C11+4*C12-2*C44)/5
  constitutive_nonlocal_nu(i) =   ( constitutive_nonlocal_C11(i) + 4.0_pReal*constitutive_nonlocal_C12(i) &
                                    - 2.0_pReal*constitutive_nonlocal_C44(i) ) &
                                / ( 4.0_pReal*constitutive_nonlocal_C11(i) + 6.0_pReal*constitutive_nonlocal_C12(i) &
                                    + 2.0_pReal*constitutive_nonlocal_C44(i) )                                                      ! C12iso/(C11iso+C12iso) with C11iso=(3*C11+2*C12+4*C44)/5 and C12iso=(C11+4*C12-2*C44)/5
  
  do s1 = 1_pInt,ns 
    f = constitutive_nonlocal_slipFamily(s1,i)
    
    !*** burgers vector, mean free path prefactor and minimum dipole distance for each slip system
  
    constitutive_nonlocal_burgers(s1,i) = constitutive_nonlocal_burgersPerSlipFamily(f,i)
    constitutive_nonlocal_lambda0(s1,i) = constitutive_nonlocal_lambda0PerSlipFamily(f,i)
    constitutive_nonlocal_minimumDipoleHeight(s1,1:2,i) = constitutive_nonlocal_minimumDipoleHeightPerSlipFamily(f,1:2,i)
    constitutive_nonlocal_peierlsStress(s1,1:2,i) = constitutive_nonlocal_peierlsStressPerSlipFamily(f,1:2,i)

    do s2 = 1_pInt,ns
      
      !*** calculation of forest projections for edge and screw dislocations. s2 acts as forest for s1

      constitutive_nonlocal_forestProjectionEdge(s1,s2,i) &
          = abs(math_mul3x3(lattice_sn(1:3,constitutive_nonlocal_slipSystemLattice(s1,i),myStructure), &
                            lattice_st(1:3,constitutive_nonlocal_slipSystemLattice(s2,i),myStructure)))                             ! forest projection of edge dislocations is the projection of (t = b x n) onto the slip normal of the respective slip plane
      
      constitutive_nonlocal_forestProjectionScrew(s1,s2,i) &
          = abs(math_mul3x3(lattice_sn(1:3,constitutive_nonlocal_slipSystemLattice(s1,i),myStructure), &
                            lattice_sd(1:3,constitutive_nonlocal_slipSystemLattice(s2,i),myStructure)))                             ! forest projection of screw dislocations is the projection of b onto the slip normal of the respective splip plane
  
      !*** calculation of interaction matrices

      constitutive_nonlocal_interactionMatrixSlipSlip(s1,s2,i) &
          = constitutive_nonlocal_interactionSlipSlip(lattice_interactionSlipSlip(constitutive_nonlocal_slipSystemLattice(s1,i), &
                                                                                  constitutive_nonlocal_slipSystemLattice(s2,i), &
                                                                                  myStructure), i)
  
    enddo

    !*** rotation matrix from lattice configuration to slip system

    constitutive_nonlocal_lattice2slip(1:3,1:3,s1,i) &
        = math_transpose33( reshape([ lattice_sd(1:3, constitutive_nonlocal_slipSystemLattice(s1,i), myStructure), &
                                      -lattice_st(1:3, constitutive_nonlocal_slipSystemLattice(s1,i), myStructure), &
                                       lattice_sn(1:3, constitutive_nonlocal_slipSystemLattice(s1,i), myStructure)], [3,3]))
  enddo
  
enddo

endsubroutine



!*********************************************************************
!* initial microstructural state (just the "basic" states)           *
!*********************************************************************
function constitutive_nonlocal_stateInit(myInstance)

use prec,     only: pReal, &
                    pInt
use lattice,  only: lattice_maxNslipFamily
use math,     only: math_sampleGaussVar

implicit none

!*** input variables
integer(pInt), intent(in) ::  myInstance                      ! number specifying the current instance of the plasticity

!*** output variables
real(pReal), dimension(constitutive_nonlocal_sizeState(myInstance)) :: &
                              constitutive_nonlocal_stateInit

!*** local variables
real(pReal), dimension(constitutive_nonlocal_totalNslip(myInstance)) :: &              
                              rhoSglEdgePos, &                ! positive edge dislocation density
                              rhoSglEdgeNeg, &                ! negative edge dislocation density
                              rhoSglScrewPos, &               ! positive screw dislocation density
                              rhoSglScrewNeg, &               ! negative screw dislocation density
                              rhoSglEdgePosUsed, &            ! used positive edge dislocation density
                              rhoSglEdgeNegUsed, &            ! used negative edge dislocation density
                              rhoSglScrewPosUsed, &           ! used positive screw dislocation density
                              rhoSglScrewNegUsed, &           ! used negative screw dislocation density
                              rhoDipEdge, &                   ! edge dipole dislocation density
                              rhoDipScrew                     ! screw dipole dislocation density
integer(pInt)                 ns, &                           ! short notation for total number of active slip systems 
                              f, &                            ! index of lattice family
                              from, &
                              upto, &
                              s, &                            ! index of slip system
                              i
real(pReal), dimension(2) ::  noise

constitutive_nonlocal_stateInit = 0.0_pReal
ns = constitutive_nonlocal_totalNslip(myInstance)

!*** set the basic state variables

do f = 1_pInt,lattice_maxNslipFamily
  from = 1_pInt + sum(constitutive_nonlocal_Nslip(1:f-1_pInt,myInstance))
  upto = sum(constitutive_nonlocal_Nslip(1:f,myInstance))
  do s = from,upto
    do i = 1_pInt,2_pInt
      noise(i) = math_sampleGaussVar(0.0_pReal, constitutive_nonlocal_rhoSglScatter(myInstance))
    enddo
    rhoSglEdgePos(s) = constitutive_nonlocal_rhoSglEdgePos0(f, myInstance) + noise(1)
    rhoSglEdgeNeg(s) = constitutive_nonlocal_rhoSglEdgeNeg0(f, myInstance) + noise(1)
    rhoSglScrewPos(s) = constitutive_nonlocal_rhoSglScrewPos0(f, myInstance) + noise(2)
    rhoSglScrewNeg(s) = constitutive_nonlocal_rhoSglScrewNeg0(f, myInstance) + noise(2)
  enddo 
  rhoSglEdgePosUsed(from:upto)  = 0.0_pReal
  rhoSglEdgeNegUsed(from:upto)  = 0.0_pReal
  rhoSglScrewPosUsed(from:upto) = 0.0_pReal
  rhoSglScrewNegUsed(from:upto) = 0.0_pReal
  rhoDipEdge(from:upto)  = constitutive_nonlocal_rhoDipEdge0(f, myInstance)
  rhoDipScrew(from:upto) = constitutive_nonlocal_rhoDipScrew0(f, myInstance)
enddo


!*** put everything together and in right order

constitutive_nonlocal_stateInit(      1:   ns) = rhoSglEdgePos
constitutive_nonlocal_stateInit(   ns+1: 2*ns) = rhoSglEdgeNeg
constitutive_nonlocal_stateInit( 2*ns+1: 3*ns) = rhoSglScrewPos
constitutive_nonlocal_stateInit( 3*ns+1: 4*ns) = rhoSglScrewNeg
constitutive_nonlocal_stateInit( 4*ns+1: 5*ns) = rhoSglEdgePosUsed
constitutive_nonlocal_stateInit( 5*ns+1: 6*ns) = rhoSglEdgeNegUsed
constitutive_nonlocal_stateInit( 6*ns+1: 7*ns) = rhoSglScrewPosUsed
constitutive_nonlocal_stateInit( 7*ns+1: 8*ns) = rhoSglScrewNegUsed
constitutive_nonlocal_stateInit( 8*ns+1: 9*ns) = rhoDipEdge
constitutive_nonlocal_stateInit( 9*ns+1:10*ns) = rhoDipScrew

endfunction



!*********************************************************************
!* absolute state tolerance                                          *
!*********************************************************************
pure function constitutive_nonlocal_aTolState(myInstance)

use prec,     only: pReal, &
                    pInt
implicit none

!*** input variables
integer(pInt), intent(in) ::  myInstance                      ! number specifying the current instance of the plasticity

!*** output variables
real(pReal), dimension(constitutive_nonlocal_sizeState(myInstance)) :: &
                              constitutive_nonlocal_aTolState ! absolute state tolerance for the current instance of this plasticity

!*** local variables

constitutive_nonlocal_aTolState = constitutive_nonlocal_aTolRho(myInstance)

endfunction



!*********************************************************************
!* calculates homogenized elacticity matrix                          *
!*********************************************************************
pure function constitutive_nonlocal_homogenizedC(state,g,ip,el)

use prec,     only: pReal, &
                    pInt, &
                    p_vec
use mesh,     only: mesh_NcpElems, &
                    mesh_maxNips
use material, only: homogenization_maxNgrains, &
                    material_phase, &
                    phase_plasticityInstance
implicit none

!*** input variables
integer(pInt), intent(in) ::    g, &                                ! current grain ID
                                ip, &                               ! current integration point
                                el                                  ! current element
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: state ! microstructural state

!*** output variables
real(pReal), dimension(6,6) ::  constitutive_nonlocal_homogenizedC  ! homogenized elasticity matrix

!*** local variables
integer(pInt)                   myInstance                          ! current instance of this plasticity

myInstance = phase_plasticityInstance(material_phase(g,ip,el))

constitutive_nonlocal_homogenizedC = constitutive_nonlocal_Cslip_66(1:6,1:6,myInstance)
 
endfunction



!*********************************************************************
!* calculates quantities characterizing the microstructure           *
!*********************************************************************
subroutine constitutive_nonlocal_microstructure(state, Temperature, Fe, Fp, g, ip, el)

use prec,     only: pReal, &
                    pInt, &
                    p_vec
use IO,       only: IO_error
use math,     only: math_Mandel33to6, &
                    math_mul33x33, &
                    math_mul33x3, &
                    math_mul3x3, &
                    math_norm3, &
                    math_inv33, &
                    math_invert33, &
                    math_transpose33, &
                    pi
use debug,    only: debug_what, &
                    debug_constitutive, &
                    debug_levelBasic, &
                    debug_levelSelective, &
                    debug_g, &
                    debug_i, &
                    debug_e
use mesh,     only: mesh_NcpElems, &
                    mesh_maxNips, &
                    mesh_element, &
                    FE_NipNeighbors, &
                    FE_maxNipNeighbors, &
                    mesh_ipNeighborhood, &
                    mesh_ipCenterOfGravity, &
                    mesh_ipVolume, &
                    mesh_ipAreaNormal
use material, only: homogenization_maxNgrains, &
                    material_phase, &
                    phase_localPlasticity, &
                    phase_plasticityInstance
use lattice,  only: lattice_sd, &
                    lattice_st

implicit none

!*** input variables
integer(pInt), intent(in) ::    g, &                          ! current grain ID
                                ip, &                         ! current integration point
                                el                            ! current element
real(pReal), intent(in) ::      Temperature                   ! temperature
real(pReal), dimension(3,3), intent(in) :: &
                                Fe, &                         ! elastic deformation gradient
                                Fp                            ! elastic deformation gradient

!*** input/output variables
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(inout) :: &
                                state                         ! microstructural state

!*** output variables

!*** local variables
integer(pInt)                   neighboring_el, &             ! element number of neighboring material point
                                neighboring_ip, &             ! integration point of neighboring material point
                                instance, &                   ! my instance of this plasticity
                                neighboring_instance, &       ! instance of this plasticity of neighboring material point
                                latticeStruct, &              ! my lattice structure
                                neighboring_latticeStruct, &  ! lattice structure of neighboring material point
                                phase, &
                                neighboring_phase, &
                                ns, &                         ! total number of active slip systems at my material point
                                neighboring_ns, &             ! total number of active slip systems at neighboring material point
                                c, &                          ! index of dilsocation character (edge, screw)
                                s, &                          ! slip system index
                                t, &                          ! index of dilsocation type (e+, e-, s+, s-, used e+, used e-, used s+, used s-)
                                dir, &
                                n
integer(pInt), dimension(2) ::  neighbor
real(pReal)                     nu, &                         ! poisson's ratio
                                mu, &
                                b, &
                                detFe, &
                                detFp, &
                                FVsize, &
                                temp
real(pReal), dimension(2) ::    rhoExcessGradient, &
                                rhoExcessGradient_over_rho, &
                                rhoTotal
real(pReal), dimension(3) ::    ipCoords, &
                                neighboring_ipCoords, &
                                rhoExcessDifferences
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                rhoForest, &                  ! forest dislocation density
                                tauBack, &                    ! back stress from pileup on same slip system
                                tauThreshold                  ! threshold shear stress
real(pReal), dimension(3,3) ::  invFe, &                      ! inverse of elastic deformation gradient
                                invFp, &                      ! inverse of plastic deformation gradient
                                connections, &
                                invConnections
real(pReal), dimension(3,FE_maxNipNeighbors) :: &
                                connection_latticeConf
real(pReal), dimension(2,constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                rhoExcess
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),2) :: &
                                rhoDip                        ! dipole dislocation density (edge, screw)
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),8) :: &
                                rhoSgl                        ! single dislocation density (edge+, edge-, screw+, screw-, used edge+, used edge-, used screw+, used screw-)
real(pReal), dimension(2,maxval(constitutive_nonlocal_totalNslip),FE_maxNipNeighbors) :: &
                                neighboring_rhoExcess         ! excess density at neighboring material point
real(pReal), dimension(3,constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),2) :: &
                                m                             ! direction of dislocation motion
logical                         inversionError


phase = material_phase(g,ip,el)
instance = phase_plasticityInstance(phase)
latticeStruct = constitutive_nonlocal_structure(instance)
ns = constitutive_nonlocal_totalNslip(instance)



!*** get basic states

forall (s = 1_pInt:ns, t = 1_pInt:4_pInt) &
  rhoSgl(s,t) = max(state(g,ip,el)%p((t-1_pInt)*ns+s), 0.0_pReal)                                                        ! ensure positive single mobile densities
forall (t = 5_pInt:8_pInt) & 
  rhoSgl(1:ns,t) = state(g,ip,el)%p((t-1_pInt)*ns+1_pInt:t*ns)
forall (s = 1_pInt:ns, c = 1_pInt:2_pInt) &
  rhoDip(s,c) = max(state(g,ip,el)%p((7_pInt+c)*ns+s), 0.0_pReal)                                                        ! ensure positive dipole densities



!*** calculate the forest dislocation density
!*** (= projection of screw and edge dislocations)

forall (s = 1_pInt:ns) &
  rhoForest(s) = dot_product((sum(abs(rhoSgl(1:ns,[1,2,5,6])),2) + rhoDip(1:ns,1)), &
                              constitutive_nonlocal_forestProjectionEdge(s,1:ns,instance)) & 
               + dot_product((sum(abs(rhoSgl(1:ns,[3,4,7,8])),2) + rhoDip(1:ns,2)), &
                              constitutive_nonlocal_forestProjectionScrew(s,1:ns,instance))



!*** calculate the threshold shear stress for dislocation slip 

forall (s = 1_pInt:ns) &
  tauThreshold(s) = constitutive_nonlocal_Gmod(instance) * constitutive_nonlocal_burgers(s,instance) &
                  * sqrt(dot_product((sum(abs(rhoSgl),2) + sum(abs(rhoDip),2)), &
                                      constitutive_nonlocal_interactionMatrixSlipSlip(s,1:ns,instance)))



!*** calculate the dislocation stress of the neighboring excess dislocation densities
!*** zero for material points of local plasticity

tauBack = 0.0_pReal

if (.not. phase_localPlasticity(phase) .and. constitutive_nonlocal_shortRangeStressCorrection(instance)) then
  call math_invert33(Fe, invFe, detFe, inversionError)
  call math_invert33(Fp, invFp, detFp, inversionError)
  ipCoords = mesh_ipCenterOfGravity(1:3,ip,el)
  rhoExcess(1,1:ns) = rhoSgl(1:ns,1) - rhoSgl(1:ns,2)
  rhoExcess(2,1:ns) = rhoSgl(1:ns,3) - rhoSgl(1:ns,4)
  FVsize = mesh_ipVolume(ip,el) ** (1.0_pReal/3.0_pReal)
  nu = constitutive_nonlocal_nu(instance)
  mu = constitutive_nonlocal_Gmod(instance)
  
  !* loop through my neighborhood and get the connection vectors (in lattice frame) and the excess densities
  
  do n = 1_pInt,FE_NipNeighbors(mesh_element(2,el))
    neighboring_el = mesh_ipNeighborhood(1,n,ip,el)
    neighboring_ip = mesh_ipNeighborhood(2,n,ip,el)
    if (neighboring_el > 0 .and. neighboring_ip > 0) then
      neighboring_phase = material_phase(g,neighboring_ip,neighboring_el)
      neighboring_instance = phase_plasticityInstance(neighboring_phase)
      neighboring_latticeStruct = constitutive_nonlocal_structure(neighboring_instance)
      neighboring_ns = constitutive_nonlocal_totalNslip(neighboring_instance)
      neighboring_ipCoords = mesh_ipCenterOfGravity(1:3,neighboring_ip,neighboring_el)
      if (.not. phase_localPlasticity(neighboring_phase) &
          .and. neighboring_latticeStruct == latticeStruct & 
          .and. neighboring_instance == instance) then
        if (neighboring_ns == ns) then
          if (neighboring_el /= el .or. neighboring_ip /= ip) then
            connection_latticeConf(1:3,n) = math_mul33x3(invFe, neighboring_ipCoords - ipCoords)
            forall (s = 1_pInt:ns, c = 1_pInt:2_pInt) &
              neighboring_rhoExcess(c,s,n) = state(g,neighboring_ip,neighboring_el)%p((2_pInt*c-2_pInt)*ns+s) &                     ! positive mobiles
                                           - state(g,neighboring_ip,neighboring_el)%p((2_pInt*c-1_pInt)*ns+s)                       ! negative mobiles
          else
            ! thats myself! probably using periodic images -> assume constant excess density
            connection_latticeConf(1:3,n) = math_mul33x3(math_transpose33(invFp), mesh_ipAreaNormal(1:3,n,ip,el))                   ! direction of area normal
            neighboring_rhoExcess(1:2,1:ns,n) = rhoExcess
          endif
        else
          ! different number of active slip systems
          call IO_error(-1_pInt,ext_msg='different number of active slip systems in neighboring IPs of same crystal structure')
        endif
      else
        ! local neighbor or different lattice structure or different constitution instance -> use central values instead
        connection_latticeConf(1:3,n) = 0.0_pReal
        neighboring_rhoExcess(1:2,1:ns,n) = rhoExcess
      endif
    else
      ! free surface -> use central values instead
      connection_latticeConf(1:3,n) = 0.0_pReal
      neighboring_rhoExcess(1:2,1:ns,n) = rhoExcess
    endif
  enddo
  

  !* loop through the slip systems and calculate the dislocation gradient by
  !* 1. interpolation of the excess density in the neighorhood
  !* 2. interpolation of the dead dislocation density in the central volume
  
  m(1:3,1:ns,1) =  lattice_sd(1:3, constitutive_nonlocal_slipSystemLattice(1:ns,instance), latticeStruct)
  m(1:3,1:ns,2) = -lattice_st(1:3, constitutive_nonlocal_slipSystemLattice(1:ns,instance), latticeStruct)

  do s = 1_pInt,ns
    
    !* gradient from interpolation of neighboring excess density

    do c = 1_pInt,2_pInt
      do dir = 1_pInt,3_pInt
        neighbor(1) = 2_pInt * dir - 1_pInt
        neighbor(2) = 2_pInt * dir
        connections(dir,1:3) = connection_latticeConf(1:3,neighbor(1)) - connection_latticeConf(1:3,neighbor(2))
        rhoExcessDifferences(dir) = neighboring_rhoExcess(c,s,neighbor(1)) - neighboring_rhoExcess(c,s,neighbor(2))
      enddo
      call math_invert33(connections,invConnections,temp,inversionError)
      if (inversionError) then
        call IO_error(-1_pInt,ext_msg='back stress calculation: inversion error')
      endif
      rhoExcessGradient(c) = math_mul3x3(math_mul33x3(invConnections, rhoExcessDifferences), m(1:3,s,c))
    enddo
      
    !* plus gradient from deads
    
    do t = 1_pInt,4_pInt
      c = (t - 1_pInt) / 2_pInt + 1_pInt
      rhoExcessGradient(c) = rhoExcessGradient(c) + rhoSgl(s,t+4_pInt) / FVsize
    enddo

    !* normalized with the total density
    
    rhoExcessGradient_over_rho = 0.0_pReal
    rhoTotal(1_pInt) = sum(abs(rhoSgl(s,[1_pInt,2_pInt,5_pInt,6_pInt]))) + rhoDip(s,1_pInt)
    rhoTotal(2_pInt) = sum(abs(rhoSgl(s,[3_pInt,4_pInt,7_pInt,8_pInt]))) + rhoDip(s,2_pInt)
    forall (c = 1_pInt:2_pInt, rhoTotal(c) > 0.0_pReal) &
      rhoExcessGradient_over_rho(c) = rhoExcessGradient(c) / rhoTotal(c)
    
    !* gives the local stress correction when multiplied with a factor

    b = constitutive_nonlocal_burgers(s,instance)
    tauBack(s) = - mu * b / (2.0_pReal * pi) * (rhoExcessGradient_over_rho(1) / (1.0_pReal - nu) + rhoExcessGradient_over_rho(2))

  enddo
endif


!*** set dependent states

state(g,ip,el)%p(10_pInt*ns+1:11_pInt*ns) = rhoForest
state(g,ip,el)%p(11_pInt*ns+1:12_pInt*ns) = tauThreshold
state(g,ip,el)%p(12_pInt*ns+1:13_pInt*ns) = tauBack


#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt &
      .and. ((debug_e == el .and. debug_i == ip .and. debug_g == g)&
             .or. .not. iand(debug_what(debug_constitutive),debug_levelSelective) /= 0_pInt)) then
    write(6,*)
    write(6,'(a,i8,1x,i2,1x,i1)') '<< CONST >> nonlocal_microstructure at el ip g',el,ip,g
    write(6,*)
    write(6,'(a,/,12x,12(e10.3,1x))') '<< CONST >> rhoForest', rhoForest
    write(6,'(a,/,12x,12(f10.5,1x))') '<< CONST >> tauThreshold / MPa', tauThreshold/1e6
    write(6,'(a,/,12x,12(f10.5,1x))') '<< CONST >> tauBack / MPa', tauBack/1e6
  endif
#endif

endsubroutine



!*********************************************************************
!* calculates kinetics                                               *
!*********************************************************************
subroutine constitutive_nonlocal_kinetics(v, tau, c, Temperature, state, g, ip, el, dv_dtau)

use prec,     only: pReal, &
                    pInt, &
                    p_vec
use debug,    only: debug_what, &
                    debug_constitutive, &
                    debug_levelBasic, &
                    debug_levelSelective, &
                    debug_g, &
                    debug_i, &
                    debug_e
use material, only: material_phase, &
                    phase_plasticityInstance

implicit none

!*** input variables
integer(pInt), intent(in) ::                g, &                        ! current grain number
                                            ip, &                       ! current integration point
                                            el, &                       ! current element number
                                            c                           ! dislocation character (1:edge, 2:screw)
real(pReal), intent(in) ::                  Temperature                 ! temperature
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))), &
             intent(in) ::                  tau                         ! resolved external shear stress (for bcc this already contains non Schmid effects)
type(p_vec), intent(in) ::                  state                       ! microstructural state

!*** input/output variables

!*** output variables
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))), &
                            intent(out) ::  v                           ! velocity
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))), &
                   intent(out), optional :: dv_dtau                     ! velocity derivative with respect to resolved shear stress

!*** local variables
integer(pInt)                               instance, &                 ! current instance of this plasticity
                                            ns, &                       ! short notation for the total number of active slip systems
                                            s                           ! index of my current slip system
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                            tauThreshold, &             ! threshold shear stress
                                            tauEff                      ! effective shear stress
real(pReal)                                 tauRel_P, & 
                                            tauRel_S, &
                                            tPeierls, &                 ! waiting time in front of a peierls barriers
                                            tSolidSolution, &           ! waiting time in front of a solid solution obstacle
                                            vViscous, &                 ! viscous glide velocity
                                            dtPeierls_dtau, &           ! derivative with respect to resolved shear stress
                                            dtSolidSolution_dtau, &     ! derivative with respect to resolved shear stress
                                            p, &                        ! shortcut to Kocks,Argon,Ashby parameter p
                                            q, &                        ! shortcut to Kocks,Argon,Ashby parameter q
                                            meanfreepath_S, &           ! mean free travel distance for dislocations between two solid solution obstacles
                                            meanfreepath_P, &           ! mean free travel distance for dislocations between two Peierls barriers
                                            jumpWidth_P, &              ! depth of activated area
                                            jumpWidth_S, &              ! depth of activated area
                                            activationLength_P, &       ! length of activated dislocation line
                                            activationLength_S, &       ! length of activated dislocation line
                                            activationVolume_P, &       ! volume that needs to be activated to overcome barrier
                                            activationVolume_S, &       ! volume that needs to be activated to overcome barrier
                                            activationEnergy_P, &       ! energy that is needed to overcome barrier
                                            activationEnergy_S, &       ! energy that is needed to overcome barrier
                                            criticalStress_P, &         ! maximum obstacle strength
                                            criticalStress_S, &         ! maximum obstacle strength
                                            mobility                    ! dislocation mobility


instance = phase_plasticityInstance(material_phase(g,ip,el))
ns = constitutive_nonlocal_totalNslip(instance)

tauThreshold = state%p(11_pInt*ns+1:12_pInt*ns)
tauEff = abs(tau) - tauThreshold

p = constitutive_nonlocal_p(instance)
q = constitutive_nonlocal_q(instance)

v = 0.0_pReal
if (present(dv_dtau)) dv_dtau = 0.0_pReal


if (Temperature > 0.0_pReal) then
  do s = 1_pInt,ns
    if (tauEff(s) > 0.0_pReal) then
      
      !* Peierls contribution
      !* The derivative only gives absolute values; the correct sign is taken care of in the formula for the derivative of the velocity
      
      meanfreepath_P = constitutive_nonlocal_burgers(s,instance)
      jumpWidth_P = constitutive_nonlocal_burgers(s,instance)
      activationLength_P = constitutive_nonlocal_doublekinkwidth(instance) * constitutive_nonlocal_burgers(s,instance)
      activationVolume_P = activationLength_P * jumpWidth_P * constitutive_nonlocal_burgers(s,instance)
      criticalStress_P = constitutive_nonlocal_peierlsStress(s,c,instance)
      activationEnergy_P = criticalStress_P * activationVolume_P
      tauRel_P = tauEff(s) / criticalStress_P
      tPeierls = 1.0_pReal / constitutive_nonlocal_fattack(instance) &
                           * exp(activationEnergy_P / (kB * Temperature) * (1.0_pReal - tauRel_P**p)**q)
      if (present(dv_dtau)) then
        dtPeierls_dtau = tPeierls * p * q * activationVolume_P / (kB * Temperature) &
                                  * (1.0_pReal - tauRel_P**p)**(q-1.0_pReal) * tauRel_P**(p-1.0_pReal) 
      endif


      !* Contribution from solid solution strengthening
      !* The derivative only gives absolute values; the correct sign is taken care of in the formula for the derivative of the velocity

      meanfreepath_S = constitutive_nonlocal_burgers(s,instance) / sqrt(constitutive_nonlocal_solidSolutionConcentration(instance))
      jumpWidth_S = constitutive_nonlocal_solidSolutionSize(instance) * constitutive_nonlocal_burgers(s,instance)
      activationLength_S = constitutive_nonlocal_burgers(s,instance) &
                         / sqrt(constitutive_nonlocal_solidSolutionConcentration(instance))
      activationVolume_S = activationLength_S * jumpWidth_S * constitutive_nonlocal_burgers(s,instance)
      activationEnergy_S = constitutive_nonlocal_solidSolutionEnergy(instance)
      criticalStress_S = activationEnergy_S / activationVolume_S
      tauRel_S = tauEff(s) / criticalStress_S
      tSolidSolution = 1.0_pReal / constitutive_nonlocal_fattack(instance) &
                                 * exp(activationEnergy_S / (kB * Temperature) * (1.0_pReal - tauRel_S**p)**q)
      if (present(dv_dtau)) then
        dtSolidSolution_dtau = tSolidSolution * p * q * activationVolume_S / (kB * Temperature) &
                                              * (1.0_pReal - tauRel_S**p)**(q-1.0_pReal) * tauRel_S**(p-1.0_pReal) 
      endif


      !* viscous glide velocity
      
      mobility = constitutive_nonlocal_burgers(s,instance) / constitutive_nonlocal_viscosity(instance)
      vViscous = mobility * tauEff(s)


      !* Mean velocity results from waiting time at peierls barriers and solid solution obstacles with respective meanfreepath of 
      !* free flight at glide velocity in between. Backward jumps at low stresses are considered only at peierls barriers,
      !* since those have the smallest activation volume, thus are decisive.
      
      v(s) = 1.0_pReal / (tPeierls / meanfreepath_P + tSolidSolution / meanfreepath_S + 1.0_pReal / vViscous) &
           * (1.0_pReal - exp(-tauEff(s) * activationVolume_P / (kB * Temperature)))
      v(s) = sign(v(s),tau(s))
      if (present(dv_dtau)) then
        dv_dtau(s) = 1.0_pReal / (tPeierls / meanfreepath_P + tSolidSolution / meanfreepath_S + 1.0_pReal / vViscous) &
                   * (abs(v(s)) * (dtPeierls_dtau + dtSolidSolution_dtau + 1.0_pReal / (mobility * tauEff(s)*tauEff(s))) &
                      + activationVolume_P / (kB * Temperature) * exp(-tauEff(s) * activationVolume_P / (kB * Temperature)))
      endif

    endif
  enddo
endif
    

#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt &
      .and. ((debug_e == el .and. debug_i == ip .and. debug_g == g)&
             .or. .not. iand(debug_what(debug_constitutive),debug_levelSelective) /= 0_pInt)) then
    write(6,*)
    write(6,'(a,i8,1x,i2,1x,i1)') '<< CONST >> nonlocal_kinetics at el ip g',el,ip,g
    write(6,*)
    write(6,'(a,/,12x,12(f12.5,1x))') '<< CONST >> tau / MPa', tau / 1e6_pReal
    write(6,'(a,/,12x,12(f12.5,1x))') '<< CONST >> tauEff / MPa', tauEff / 1e6_pReal
    write(6,'(a,/,12x,12(f12.5,1x))') '<< CONST >> v / 1e-3m/s', v * 1e3
  endif
#endif

endsubroutine



!*********************************************************************
!* calculates plastic velocity gradient and its tangent              *
!*********************************************************************
subroutine constitutive_nonlocal_LpAndItsTangent(Lp, dLp_dTstar99, Tstar_v, Temperature, state, g, ip, el)

use prec,     only: pReal, &
                    pInt, &
                    p_vec
use math,     only: math_Plain3333to99, &
                    math_mul6x6
use debug,    only: debug_what, &
                    debug_constitutive, &
                    debug_levelBasic, &
                    debug_levelSelective, &
                    debug_g, &
                    debug_i, &
                    debug_e
use material, only: homogenization_maxNgrains, &
                    material_phase, &
                    phase_plasticityInstance
use lattice,  only: lattice_Sslip, &
                    lattice_Sslip_v

implicit none

!*** input variables
integer(pInt), intent(in) ::                g, &                        ! current grain number
                                            ip, &                       ! current integration point
                                            el                          ! current element number
real(pReal), intent(in) ::                  Temperature                 ! temperature
real(pReal), dimension(6), intent(in) ::    Tstar_v                     ! 2nd Piola-Kirchhoff stress in Mandel notation

!*** input/output variables
type(p_vec), intent(inout) ::               state                       ! microstructural state

!*** output variables
real(pReal), dimension(3,3), intent(out) :: Lp                          ! plastic velocity gradient
real(pReal), dimension(9,9), intent(out) :: dLp_dTstar99                ! derivative of Lp with respect to Tstar (9x9 matrix)

!*** local variables
integer(pInt)                               myInstance, &               ! current instance of this plasticity
                                            myStructure, &              ! current lattice structure
                                            ns, &                       ! short notation for the total number of active slip systems
                                            c, &
                                            i, &
                                            j, &
                                            k, &
                                            l, &
                                            t, &                        ! dislocation type
                                            s, &                        ! index of my current slip system
                                            sLattice                    ! index of my current slip system according to lattice order
real(pReal), dimension(3,3,3,3) ::          dLp_dTstar3333              ! derivative of Lp with respect to Tstar (3x3x3x3 matrix)
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),4) :: &
                                            rhoSgl, &                   ! single dislocation densities (including used) 
                                            v, &                        ! velocity
                                            dv_dtau                     ! velocity derivative with respect to the shear stress
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                            tau, &                      ! resolved shear stress including non Schmid and backstress terms
                                            gdotTotal, &                ! shear rate
                                            dgdotTotal_dtau, &          ! derivative of the shear rate with respect to the shear stress
                                            tauBack                     ! back stress from dislocation gradients on same slip system


!*** initialize local variables

Lp = 0.0_pReal
dLp_dTstar3333 = 0.0_pReal

myInstance = phase_plasticityInstance(material_phase(g,ip,el))
myStructure = constitutive_nonlocal_structure(myInstance) 
ns = constitutive_nonlocal_totalNslip(myInstance)


!*** shortcut to state variables 

forall (s = 1_pInt:ns, t = 1_pInt:4_pInt) &
  rhoSgl(s,t) = max(state%p((t-1_pInt)*ns+s), 0.0_pReal)
tauBack = state%p(12_pInt*ns+1:13_pInt*ns)


!*** get effective resolved shear stress

do s = 1_pInt,ns
  tau(s) = math_mul6x6(Tstar_v, lattice_Sslip_v(:,constitutive_nonlocal_slipSystemLattice(s,myInstance),myStructure)) &
         + tauBack(s)
enddo


!*** get dislocation velocity and its tangent and store the velocity in the state array

if (myStructure == 1_pInt) then   ! for fcc all velcities are equal
  call constitutive_nonlocal_kinetics(v(1:ns,1), tau, 1_pInt, Temperature, state, g, ip, el, dv_dtau(1:ns,1))
  do t = 1_pInt,4_pInt
    v(1:ns,t) = v(1:ns,1)
    dv_dtau(1:ns,t) = dv_dtau(1:ns,1)
    state%p((12_pInt+t)*ns+1:(13_pInt+t)*ns) = v(1:ns,1)
  enddo
else                              ! for all other lattice structures the velcities may vary with character and sign
  do t = 1_pInt,4_pInt
    c = (t-1_pInt)/2_pInt+1_pInt
    call constitutive_nonlocal_kinetics(v(1:ns,t), tau, c, Temperature, state, g, ip, el, dv_dtau(1:ns,t))
    state%p((12+t)*ns+1:(13+t)*ns) = v(1:ns,t)
  enddo
endif


!*** Bauschinger effect

forall (s = 1_pInt:ns, t = 5_pInt:8_pInt, state%p((t-1)*ns+s) * v(s,t-4_pInt) < 0.0_pReal) &
  rhoSgl(s,t-4_pInt) = rhoSgl(s,t-4_pInt) + abs(state%p((t-1_pInt)*ns+s))


!*** Calculation of gdot and its tangent

gdotTotal = sum(rhoSgl * v, 2) * constitutive_nonlocal_burgers(1:ns,myInstance)
dgdotTotal_dtau = sum(rhoSgl * dv_dtau, 2) * constitutive_nonlocal_burgers(1:ns,myInstance) 


!*** Calculation of Lp and its tangent

do s = 1_pInt,ns
  sLattice = constitutive_nonlocal_slipSystemLattice(s,myInstance)  
  Lp = Lp + gdotTotal(s) * lattice_Sslip(1:3,1:3,sLattice,myStructure)
  forall (i=1_pInt:3_pInt,j=1_pInt:3_pInt,k=1_pInt:3_pInt,l=1_pInt:3_pInt) &
    dLp_dTstar3333(i,j,k,l) = dLp_dTstar3333(i,j,k,l) + dgdotTotal_dtau(s) * lattice_Sslip(i,j, sLattice,myStructure) &
                                                                           * lattice_Sslip(k,l, sLattice,myStructure) 
enddo
dLp_dTstar99 = math_Plain3333to99(dLp_dTstar3333)


#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt &
      .and. ((debug_e == el .and. debug_i == ip .and. debug_g == g)&
             .or. .not. iand(debug_what(debug_constitutive),debug_levelSelective) /= 0_pInt )) then
    write(6,*)
    write(6,'(a,i8,1x,i2,1x,i1)') '<< CONST >> nonlocal_LpandItsTangent at el ip g ',el,ip,g
    write(6,*)
    write(6,'(a,/,12x,12(f12.5,1x))') '<< CONST >> gdot total / 1e-3',gdotTotal*1e3_pReal
    write(6,'(a,/,3(12x,3(f12.7,1x),/))') '<< CONST >> Lp',Lp
  endif
#endif

endsubroutine



!*********************************************************************
!* incremental change of microstructure                              *
!*********************************************************************
function constitutive_nonlocal_deltaState(Tstar_v, Temperature, state, g,ip,el)

use prec,     only: pReal, &
                    pInt, &
                    p_vec
use debug,    only: debug_what, &
                    debug_constitutive, &
                    debug_levelBasic, &
                    debug_levelSelective, &
                    debug_g, &
                    debug_i, &
                    debug_e
use mesh,     only: mesh_NcpElems, &
                    mesh_maxNips
use material, only: homogenization_maxNgrains, &
                    material_phase, &
                    phase_plasticityInstance

implicit none

!*** input variables
integer(pInt), intent(in) ::                g, &                      ! current grain number
                                            ip, &                     ! current integration point
                                            el                        ! current element number
real(pReal), intent(in) ::                  Temperature               ! temperature
real(pReal), dimension(6), intent(in) ::    Tstar_v                   ! current 2nd Piola-Kirchhoff stress in Mandel notation
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: &
                                            state                     ! current microstructural state

!*** output variables
real(pReal), dimension(constitutive_nonlocal_sizeDotState(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                            constitutive_nonlocal_deltaState ! change of state variables / microstructure
 
!*** local variables
integer(pInt)                               myInstance, &             ! current instance of this plasticity
                                            myStructure, &            ! current lattice structure
                                            ns, &                     ! short notation for the total number of active slip systems
                                            c, &                      ! character of dislocation
                                            n, &                      ! index of my current neighbor
                                            t, &                      ! type of dislocation
                                            s                         ! index of my current slip system
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),10) :: &
                                            deltaRho, &                     ! density increment
                                            deltaRhoRemobilization          ! density increment by remobilization
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),8) :: &
                                            rhoSgl                        ! current single dislocation densities (positive/negative screw and edge without dipoles)
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),4) :: &
                                            v                             ! dislocation glide velocity
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),2) :: &
                                            rhoDip                        ! current dipole dislocation densities (screw and edge dipoles)


#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt &
      .and. ((debug_e == el .and. debug_i == ip .and. debug_g == g)&
             .or. .not. iand(debug_what(debug_constitutive),debug_levelSelective) /= 0_pInt)) then
    write(6,*)
    write(6,'(a,i8,1x,i2,1x,i1)') '<< CONST >> nonlocal_dotState at el ip g ',el,ip,g
    write(6,*)
  endif
#endif

myInstance = phase_plasticityInstance(material_phase(g,ip,el))
myStructure = constitutive_nonlocal_structure(myInstance) 
ns = constitutive_nonlocal_totalNslip(myInstance)


!*** shortcut to state variables 

forall (s = 1_pInt:ns, t = 1_pInt:4_pInt) &
  rhoSgl(s,t) = max(state(g,ip,el)%p((t-1_pInt)*ns+s), 0.0_pReal)
forall (s = 1_pInt:ns, t = 5_pInt:8_pInt) &
  rhoSgl(s,t) = state(g,ip,el)%p((t-1_pInt)*ns+s)
forall (s = 1_pInt:ns, c = 1_pInt:2_pInt) &
  rhoDip(s,c) = max(state(g,ip,el)%p((7_pInt+c)*ns+s), 0.0_pReal)
forall (t = 1_pInt:4_pInt) &
  v(1_pInt:ns,t) = state(g,ip,el)%p((12_pInt+t)*ns+1_pInt:(13_pInt+t)*ns)



!****************************************************************************
!*** dislocation remobilization (bauschinger effect)

deltaRhoRemobilization = 0.0_pReal
do t = 1_pInt,4_pInt
  do s = 1_pInt,ns
    if (rhoSgl(s,t+4_pInt) * v(s,t) < 0.0_pReal) then
      deltaRhoRemobilization(s,t) = abs(rhoSgl(s,t+4_pInt))
      rhoSgl(s,t) = rhoSgl(s,t) + abs(rhoSgl(s,t+4_pInt))
      deltaRhoRemobilization(s,t+4_pInt) = - rhoSgl(s,t+4_pInt)
      rhoSgl(s,t+4_pInt) = 0.0_pReal
    endif
  enddo
enddo



!****************************************************************************
!*** assign the rates of dislocation densities to my dotState
!*** if evolution rates lead to negative densities, a cutback is enforced

deltaRho = 0.0_pReal
deltaRho = deltaRhoRemobilization

constitutive_nonlocal_deltaState = reshape(deltaRho,(/10_pInt*ns/))



#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt &
      .and. ((debug_e == el .and. debug_i == ip .and. debug_g == g)&
             .or. .not. iand(debug_what(debug_constitutive),debug_levelSelective) /= 0_pInt )) then
    write(6,'(a,/,8(12x,12(e12.5,1x),/))') '<< CONST >> dislocation remobilization', deltaRhoRemobilization(1:ns,1:8)
    write(6,*)
  endif
#endif

endfunction



!*********************************************************************
!* rate of change of microstructure                                  *
!*********************************************************************
function constitutive_nonlocal_dotState(Tstar_v, Fe, Fp, Temperature, state, timestep, orientation, g,ip,el)

use prec,     only: pReal, &
                    pInt, &
                    p_vec, &
                    DAMASK_NaN
use numerics, only: numerics_integrationMode
use IO,       only: IO_error
use debug,    only: debug_what, &
                    debug_constitutive, &
                    debug_levelBasic, &
                    debug_levelSelective, &
                    debug_g, &
                    debug_i, &
                    debug_e
use math,     only: math_norm3, &
                    math_mul6x6, &
                    math_mul3x3, &
                    math_mul33x3, &
                    math_mul33x33, &
                    math_inv33, &
                    math_det33, &
                    math_transpose33, &  
                    pi                
use mesh,     only: mesh_NcpElems, &
                    mesh_maxNips, &
                    mesh_element, &
                    FE_NipNeighbors, &
                    mesh_ipNeighborhood, &
                    mesh_ipVolume, &
                    mesh_ipArea, &
                    mesh_ipAreaNormal
use material, only: homogenization_maxNgrains, &
                    material_phase, &
                    phase_plasticityInstance, &
                    phase_localPlasticity, &
                    phase_plasticity
use lattice,  only: lattice_Sslip_v, &
                    lattice_sd, &
                    lattice_st

implicit none

!*** input variables
integer(pInt), intent(in) ::                g, &                      ! current grain number
                                            ip, &                     ! current integration point
                                            el                        ! current element number
real(pReal), intent(in) ::                  Temperature, &            ! temperature
                                            timestep                  ! substepped crystallite time increment
real(pReal), dimension(6), intent(in) ::    Tstar_v                   ! current 2nd Piola-Kirchhoff stress in Mandel notation
real(pReal), dimension(3,3,homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: &
                                            Fe, &                     ! elastic deformation gradient
                                            Fp                        ! plastic deformation gradient
real(pReal), dimension(4,homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: &
                                            orientation               ! crystal lattice orientation
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: &
                                            state                     ! current microstructural state
!*** input/output variables
 
!*** output variables
real(pReal), dimension(constitutive_nonlocal_sizeDotState(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                            constitutive_nonlocal_dotState ! evolution of state variables / microstructure
 
!*** local variables
integer(pInt)                               myInstance, &             ! current instance of this plasticity
                                            myStructure, &            ! current lattice structure
                                            ns, &                     ! short notation for the total number of active slip systems
                                            c, &                      ! character of dislocation
                                            n, &                      ! index of my current neighbor
                                            neighboring_el, &         ! element number of my neighbor
                                            neighboring_ip, &         ! integration point of my neighbor
                                            neighboring_n, &          ! neighbor index pointing to me when looking from my neighbor
                                            opposite_n, &             ! index of my opposite neighbor
                                            opposite_ip, &            ! ip of my opposite neighbor
                                            opposite_el, &            ! element index of my opposite neighbor
                                            t, &                      ! type of dislocation
                                            topp, &                   ! type of dislocation with opposite sign to t
                                            s, &                      ! index of my current slip system
                                            sLattice, &               ! index of my current slip system according to lattice order
                                            deads
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),10) :: &
                                            rhoDot, &                     ! density evolution
                                            rhoDotMultiplication, &       ! density evolution by multiplication
                                            rhoDotFlux, &                 ! density evolution by flux
                                            rhoDotSingle2DipoleGlide, &   ! density evolution by dipole formation (by glide)
                                            rhoDotAthermalAnnihilation, & ! density evolution by athermal annihilation
                                            rhoDotThermalAnnihilation     ! density evolution by thermal annihilation
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),8) :: &
                                            neighboring_rhoSgl, &         ! current single dislocation densities (positive/negative screw and edge without dipoles)
                                            rhoSgl                        ! current single dislocation densities (positive/negative screw and edge without dipoles)
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),4) :: &
                                            v, &                          ! dislocation glide velocity
                                            neighboring_v, &              ! dislocation glide velocity
                                            gdot                          ! shear rates
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                            rhoForest, &                  ! forest dislocation density
                                            tauThreshold, &               ! threshold shear stress
                                            tau, &                        ! current resolved shear stress
                                            tauBack, &                    ! current back stress from pileups on same slip system
                                            vClimb                        ! climb velocity of edge dipoles
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),2) :: &
                                            rhoDip, &                     ! current dipole dislocation densities (screw and edge dipoles)
                                            dLower, &                     ! minimum stable dipole distance for edges and screws
                                            dUpper                        ! current maximum stable dipole distance for edges and screws
real(pReal), dimension(3,constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),4) :: &
                                            m                             ! direction of dislocation motion
real(pReal), dimension(3,3) ::              my_F, &                       ! my total deformation gradient
                                            neighboring_F, &              ! total deformation gradient of my neighbor
                                            my_Fe, &                      ! my elastic deformation gradient
                                            neighboring_Fe, &             ! elastic deformation gradient of my neighbor
                                            Favg                          ! average total deformation gradient of me and my neighbor
real(pReal), dimension(3) ::                normal_neighbor2me, &         ! interface normal pointing from my neighbor to me in neighbor's lattice configuration
                                            normal_neighbor2me_defConf, & ! interface normal pointing from my neighbor to me in shared deformed configuration
                                            normal_me2neighbor, &         ! interface normal pointing from me to my neighbor in my lattice configuration
                                            normal_me2neighbor_defConf    ! interface normal pointing from me to my neighbor in shared deformed configuration
real(pReal)                                 area, &                       ! area of the current interface
                                            transmissivity, &             ! overall transmissivity of dislocation flux to neighboring material point
                                            lineLength, &                 ! dislocation line length leaving the current interface
                                            D                             ! self diffusion
logical                                     considerEnteringFlux, &
                                            considerLeavingFlux

#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt &
      .and. ((debug_e == el .and. debug_i == ip .and. debug_g == g)&
             .or. .not. iand(debug_what(debug_constitutive),debug_levelSelective) /= 0_pInt)) then
    write(6,*)
    write(6,'(a,i8,1x,i2,1x,i1)') '<< CONST >> nonlocal_dotState at el ip g ',el,ip,g
    write(6,*)
  endif
#endif


myInstance = phase_plasticityInstance(material_phase(g,ip,el))
myStructure = constitutive_nonlocal_structure(myInstance) 
ns = constitutive_nonlocal_totalNslip(myInstance)

tau = 0.0_pReal
gdot = 0.0_pReal
dLower = 0.0_pReal
dUpper = 0.0_pReal


!*** shortcut to state variables 

forall (s = 1_pInt:ns, t = 1_pInt:4_pInt) &
  rhoSgl(s,t) = max(state(g,ip,el)%p((t-1_pInt)*ns+s), 0.0_pReal)
forall (s = 1_pInt:ns, t = 5_pInt:8_pInt) &
  rhoSgl(s,t) = state(g,ip,el)%p((t-1_pInt)*ns+s)
forall (s = 1_pInt:ns, c = 1_pInt:2_pInt) &
  rhoDip(s,c) = max(state(g,ip,el)%p((7_pInt+c)*ns+s), 0.0_pReal)
rhoForest = state(g,ip,el)%p(10_pInt*ns+1:11_pInt*ns)
tauThreshold = state(g,ip,el)%p(11_pInt*ns+1_pInt:12_pInt*ns)
tauBack = state(g,ip,el)%p(12_pInt*ns+1:13_pInt*ns)
forall (t = 1_pInt:4_pInt) &
  v(1_pInt:ns,t) = state(g,ip,el)%p((12_pInt+t)*ns+1_pInt:(13_pInt+t)*ns)


!*** sanity check for timestep

if (timestep <= 0.0_pReal) then                                                                                                     ! if illegal timestep...
  constitutive_nonlocal_dotState = 0.0_pReal                                                                                        ! ...return without doing anything (-> zero dotState)
  return
endif



!****************************************************************************
!*** Calculate shear rate

forall (t = 1_pInt:4_pInt) &
  gdot(1_pInt:ns,t) = rhoSgl(1_pInt:ns,t) * constitutive_nonlocal_burgers(1:ns,myInstance) * v(1:ns,t)

#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt &
      .and. ((debug_e == el .and. debug_i == ip .and. debug_g == g)&
             .or. .not. iand(debug_what(debug_constitutive),debug_levelSelective) /= 0_pInt )) then
    write(6,'(a,/,10(12x,12(e12.5,1x),/))') '<< CONST >> rho / 1/m^2', rhoSgl, rhoDip
    write(6,'(a,/,4(12x,12(e12.5,1x),/))') '<< CONST >> gdot / 1/s',gdot
  endif
#endif



!****************************************************************************
!*** check CFL (Courant-Friedrichs-Lewy) condition for flux

if (any(abs(gdot) > 0.0_pReal .and. 2.0_pReal * abs(v) * timestep > mesh_ipVolume(ip,el) / maxval(mesh_ipArea(:,ip,el)))) then      ! safety factor 2.0 (we use the reference volume and are for simplicity here)
#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt) then 
    write(6,'(a,i5,a,i2)') '<< CONST >> CFL condition not fullfilled at el ',el,' ip ',ip
    write(6,'(a,e10.3,a,e10.3)') '<< CONST >> velocity is at  ',maxval(abs(v)),' at a timestep of ',timestep
    write(6,'(a)') '<< CONST >> enforcing cutback !!!'
  endif
#endif
  constitutive_nonlocal_dotState = DAMASK_NaN
  return
endif



!****************************************************************************
!*** calculate limits for stable dipole height

do s = 1_pInt,ns   ! loop over slip systems
  sLattice = constitutive_nonlocal_slipSystemLattice(s,myInstance)  
  tau(s) = math_mul6x6(Tstar_v, lattice_Sslip_v(1:6,sLattice,myStructure)) + tauBack(s)
  if (abs(tau(s)) < 1.0e-15_pReal) tau(s) = 1.0e-15_pReal
enddo

dLower = constitutive_nonlocal_minimumDipoleHeight(1:ns,1:2,myInstance)
dUpper(1:ns,2) = min( 1.0_pReal / sqrt( sum(abs(rhoSgl),2)+sum(rhoDip,2) ), &
                      constitutive_nonlocal_Gmod(myInstance) * constitutive_nonlocal_burgers(1:ns,myInstance) &
                                                             / ( 8.0_pReal * pi * abs(tau) ) )
dUpper(1:ns,1) = dUpper(1:ns,2) / ( 1.0_pReal - constitutive_nonlocal_nu(myInstance) )



!****************************************************************************
!*** calculate dislocation multiplication

rhoDotMultiplication = 0.0_pReal
where (rhoSgl(1:ns,3:4) > 0.0_pReal) &
  rhoDotMultiplication(1:ns,1:2) = spread(0.5_pReal * sum(abs(gdot(1:ns,3:4)),2) * sqrt(rhoForest)  &
                                                    / constitutive_nonlocal_lambda0(1:ns,myInstance) &
                                                    / constitutive_nonlocal_burgers(1:ns,myInstance), 2, 2)
rhoDotMultiplication(1:ns,3:4) = rhoDotMultiplication(1:ns,1:2)



!****************************************************************************
!*** calculate dislocation fluxes (only for nonlocal plasticity)

rhoDotFlux = 0.0_pReal

if (.not. phase_localPlasticity(material_phase(g,ip,el))) then                                                                    ! only for nonlocal plasticity
  
  !*** take care of the definition of lattice_st = lattice_sd x lattice_sn !!!
  !*** opposite sign to our p vector in the (s,p,n) triplet !!!
  
  m(1:3,1:ns,1) =  lattice_sd(1:3, constitutive_nonlocal_slipSystemLattice(1:ns,myInstance), myStructure)
  m(1:3,1:ns,2) = -lattice_sd(1:3, constitutive_nonlocal_slipSystemLattice(1:ns,myInstance), myStructure)
  m(1:3,1:ns,3) = -lattice_st(1:3, constitutive_nonlocal_slipSystemLattice(1:ns,myInstance), myStructure)
  m(1:3,1:ns,4) =  lattice_st(1:3, constitutive_nonlocal_slipSystemLattice(1:ns,myInstance), myStructure)
  
  my_Fe = Fe(1:3,1:3,g,ip,el)
  my_F = math_mul33x33(my_Fe, Fp(1:3,1:3,g,ip,el))
  
  do n = 1_pInt,FE_NipNeighbors(mesh_element(2,el))                                                                                 ! loop through my neighbors
    neighboring_el = mesh_ipNeighborhood(1,n,ip,el)
    neighboring_ip = mesh_ipNeighborhood(2,n,ip,el)
    if (neighboring_el > 0_pInt .and. neighboring_ip > 0_pInt) then                                                                 ! if neighbor exists ...
      do neighboring_n = 1_pInt,FE_NipNeighbors(mesh_element(2,neighboring_el))                                                     ! find neighboring index that points from my neighbor to myself
        if (      el == mesh_ipNeighborhood(1,neighboring_n,neighboring_ip,neighboring_el) &
            .and. ip == mesh_ipNeighborhood(2,neighboring_n,neighboring_ip,neighboring_el)) then                                    ! possible candidate
          if (math_mul3x3(mesh_ipAreaNormal(1:3,n,ip,el),&
                          mesh_ipAreaNormal(1:3,neighboring_n,neighboring_ip,neighboring_el)) < 0.0_pReal) then                     ! area normals have opposite orientation (we have to check that because of special case for single element with two ips and periodicity. In this case the neighbor is identical in two different directions.)
            exit
          endif
        endif
      enddo
    endif
  
    opposite_n = n + mod(n,2_pInt) - mod(n+1_pInt,2_pInt)
    opposite_el = mesh_ipNeighborhood(1,opposite_n,ip,el)
    opposite_ip = mesh_ipNeighborhood(2,opposite_n,ip,el)
  
    if (neighboring_el > 0_pInt .and. neighboring_ip > 0_pInt) then                                                                 ! if neighbor exists, average deformation gradient
      neighboring_Fe = Fe(1:3,1:3,g,neighboring_ip,neighboring_el)
      neighboring_F = math_mul33x33(neighboring_Fe, Fp(1:3,1:3,g,neighboring_ip,neighboring_el))
      Favg = 0.5_pReal * (my_F + neighboring_F)
    else                                                                                                                            ! if no neighbor, take my value as average
      Favg = my_F
    endif
    

    !* FLUX FROM MY NEIGHBOR TO ME
    !* This is only considered, if I have a neighbor of nonlocal plasticity (also nonlocal constitutive law with local properties) that is at least a little bit compatible.
    !* If it's not at all compatible, no flux is arriving, because everything is dammed in front of my neighbor's interface.
    !* The entering flux from my neighbor will be distributed on my slip systems according to the compatibility
    
    considerEnteringFlux = .false.
    neighboring_v = 0.0_pReal        ! needed for check of sign change in flux density below 
    neighboring_rhoSgl = 0.0_pReal
    if (neighboring_el > 0_pInt .or. neighboring_ip > 0_pInt) then
      if (phase_plasticity(material_phase(1,neighboring_ip,neighboring_el)) == constitutive_nonlocal_label &
          .and. any(constitutive_nonlocal_compatibility(:,:,:,n,ip,el) > 0.0_pReal)) &
        considerEnteringFlux = .true.
    endif
    
    if (considerEnteringFlux) then
      forall (t = 1_pInt:4_pInt) &
        neighboring_v(1_pInt:ns,t) = state(g,neighboring_ip,neighboring_el)%p((12_pInt+t)*ns+1_pInt:(13_pInt+t)*ns)
      forall (t = 1_pInt:4_pInt) &
        neighboring_rhoSgl(1_pInt:ns,t) = max(state(g,neighboring_ip,neighboring_el)%p((t-1_pInt)*ns+1_pInt:t*ns), 0.0_pReal)
      forall (t = 5_pInt:8_pInt) &
        neighboring_rhoSgl(1_pInt:ns,t) = state(g,neighboring_ip,neighboring_el)%p((t-1_pInt)*ns+1_pInt:t*ns)
      normal_neighbor2me_defConf = math_det33(Favg) &
                  * math_mul33x3(math_inv33(transpose(Favg)), mesh_ipAreaNormal(1:3,neighboring_n,neighboring_ip,neighboring_el))   ! calculate the normal of the interface in (average) deformed configuration (now pointing from my neighbor to me!!!)
      normal_neighbor2me = math_mul33x3(transpose(neighboring_Fe), normal_neighbor2me_defConf) / math_det33(neighboring_Fe)         ! interface normal in the lattice configuration of my neighbor
      area = mesh_ipArea(neighboring_n,neighboring_ip,neighboring_el) * math_norm3(normal_neighbor2me)
      normal_neighbor2me = normal_neighbor2me / math_norm3(normal_neighbor2me)                                                      ! normalize the surface normal to unit length
      do s = 1_pInt,ns
        do t = 1_pInt,4_pInt
          c = (t + 1_pInt) / 2
          topp = t + mod(t,2_pInt) - mod(t+1_pInt,2_pInt)
          if (neighboring_v(s,t) * math_mul3x3(m(1:3,s,t), normal_neighbor2me) > 0.0_pReal &                                        ! flux from my neighbor to me == entering flux for me
              .and. v(s,t) * neighboring_v(s,t) >= 0.0_pReal ) then                                                                 ! ... only if no sign change in flux density  
            do deads = 0_pInt,4_pInt,4_pInt
              lineLength = abs(neighboring_rhoSgl(s,t+deads)) * neighboring_v(s,t) &
                         * math_mul3x3(m(1:3,s,t), normal_neighbor2me) * area                                                       ! positive line length that wants to enter through this interface
              where (constitutive_nonlocal_compatibility(c,1_pInt:ns,s,n,ip,el) > 0.0_pReal) &                                      ! positive compatibility...
                rhoDotFlux(1_pInt:ns,t) = rhoDotFlux(1_pInt:ns,t) + lineLength / mesh_ipVolume(ip,el) &                             ! ... transferring to equally signed mobile dislocation type
                                        * constitutive_nonlocal_compatibility(c,1_pInt:ns,s,n,ip,el) ** 2.0_pReal
              where (constitutive_nonlocal_compatibility(c,1_pInt:ns,s,n,ip,el) < 0.0_pReal) &                                      ! ..negative compatibility...
                rhoDotFlux(1_pInt:ns,topp) = rhoDotFlux(1_pInt:ns,topp) + lineLength / mesh_ipVolume(ip,el) &                       ! ... transferring to opposite signed mobile dislocation type
                                           * constitutive_nonlocal_compatibility(c,1_pInt:ns,s,n,ip,el) ** 2.0_pReal
            enddo
          endif
        enddo
      enddo
    endif
   
 
    !* FLUX FROM ME TO MY NEIGHBOR
    !* This is not considered, if my opposite neighbor has a different constitutive law than nonlocal (still considered for nonlocal law with lcal properties). 
    !* Then, we assume, that the opposite(!) neighbor sends an equal amount of dislocations to me.
    !* So the net flux in the direction of my neighbor is equal to zero:
    !*    leaving flux to neighbor == entering flux from opposite neighbor
    !* In case of reduced transmissivity, part of the leaving flux is stored as dead dislocation density.
    !* That means for an interface of zero transmissivity the leaving flux is fully converted to dead dislocations.
    
    considerLeavingFlux = .true.
    if (opposite_el > 0_pInt .and. opposite_ip > 0_pInt) then
      if (phase_plasticity(material_phase(1,opposite_ip,opposite_el)) /= constitutive_nonlocal_label) &
        considerLeavingFlux = .false.
    endif

    if (considerLeavingFlux) then
      normal_me2neighbor_defConf = math_det33(Favg) * math_mul33x3(math_inv33(math_transpose33(Favg)), & 
                                                                   mesh_ipAreaNormal(1:3,n,ip,el))                                  ! calculate the normal of the interface in (average) deformed configuration (pointing from me to my neighbor!!!)
      normal_me2neighbor = math_mul33x3(math_transpose33(my_Fe), normal_me2neighbor_defConf) / math_det33(my_Fe)                    ! interface normal in my lattice configuration
      area = mesh_ipArea(n,ip,el) * math_norm3(normal_me2neighbor)
      normal_me2neighbor = normal_me2neighbor / math_norm3(normal_me2neighbor)                                                      ! normalize the surface normal to unit length    
      do s = 1_pInt,ns
        do t = 1_pInt,4_pInt
          c = (t + 1_pInt) / 2_pInt        
          if (v(s,t) * math_mul3x3(m(1:3,s,t), normal_me2neighbor) > 0.0_pReal ) then                                               ! flux from me to my neighbor == leaving flux for me (might also be a pure flux from my mobile density to dead density if interface not at all transmissive)
            if (v(s,t) * neighboring_v(s,t) >= 0.0_pReal) then                                                                      ! no sign change in flux density
              transmissivity = sum(constitutive_nonlocal_compatibility(c,1_pInt:ns,s,n,ip,el)**2.0_pReal)                           ! overall transmissivity from this slip system to my neighbor
            else                                                                                                                    ! sign change in flux density means sign change in stress which does not allow for dislocations to arive at the neighbor
              transmissivity = 0.0_pReal
            endif
            lineLength = rhoSgl(s,t) * v(s,t) * math_mul3x3(m(1:3,s,t), normal_me2neighbor) * area                                  ! positive line length of mobiles that wants to leave through this interface
            rhoDotFlux(s,t) = rhoDotFlux(s,t) - lineLength / mesh_ipVolume(ip,el)                                                   ! subtract dislocation flux from current type
            rhoDotFlux(s,t+4_pInt) = rhoDotFlux(s,t+4_pInt) + lineLength / mesh_ipVolume(ip,el) * (1.0_pReal - transmissivity) &
                                                             * sign(1.0_pReal, v(s,t))                                              ! dislocation flux that is not able to leave through interface (because of low transmissivity) will remain as immobile single density at the material point
            lineLength = rhoSgl(s,t+4_pInt) * v(s,t) * math_mul3x3(m(1:3,s,t), normal_me2neighbor) * area                           ! positive line length of deads that wants to leave through this interface
            rhoDotFlux(s,t+4_pInt) = rhoDotFlux(s,t+4_pInt) - lineLength / mesh_ipVolume(ip,el) * transmissivity                    ! dead dislocations leaving through this interface
          endif
        enddo
      enddo
    endif    
    
  enddo ! neighbor loop  
endif

if (numerics_integrationMode == 1_pInt) then
  constitutive_nonlocal_rhoDotFlux(1:ns,1:10,g,ip,el) = rhoDotFlux(1:ns,1:10)                                                       ! save flux calculation for output (if in central integration mode)
endif



!****************************************************************************
!*** calculate dipole formation and annihilation

!*** formation by glide

do c = 1_pInt,2_pInt

  rhoDotSingle2DipoleGlide(1:ns,2*c-1) = -2.0_pReal * dUpper(1:ns,c) / constitutive_nonlocal_burgers(1:ns,myInstance) &
                                                    * (rhoSgl(1:ns,2*c-1) * abs(gdot(1:ns,2*c)) &                                   ! negative mobile --> positive mobile
                                                       + rhoSgl(1:ns,2*c) * abs(gdot(1:ns,2*c-1)) &                                 ! positive mobile --> negative mobile
                                                       + abs(rhoSgl(1:ns,2*c+4)) * abs(gdot(1:ns,2*c-1)))                           ! positive mobile --> negative immobile

  rhoDotSingle2DipoleGlide(1:ns,2*c) = -2.0_pReal * dUpper(1:ns,c) / constitutive_nonlocal_burgers(1:ns,myInstance) &
                                                  * (rhoSgl(1:ns,2*c-1) * abs(gdot(1:ns,2*c)) &                                     ! negative mobile --> positive mobile
                                                     + rhoSgl(1:ns,2*c) * abs(gdot(1:ns,2*c-1)) &                                   ! positive mobile --> negative mobile
                                                     + abs(rhoSgl(1:ns,2*c+3)) * abs(gdot(1:ns,2*c)))                               ! negative mobile --> positive immobile

  rhoDotSingle2DipoleGlide(1:ns,2*c+3) = -2.0_pReal * dUpper(1:ns,c) / constitutive_nonlocal_burgers(1:ns,myInstance) &
                                                    * rhoSgl(1:ns,2*c+3) * abs(gdot(1:ns,2*c))                                      ! negative mobile --> positive immobile

  rhoDotSingle2DipoleGlide(1:ns,2*c+4) = -2.0_pReal * dUpper(1:ns,c) / constitutive_nonlocal_burgers(1:ns,myInstance) &
                                                    * rhoSgl(1:ns,2*c+4) * abs(gdot(1:ns,2*c-1))                                    ! positive mobile --> negative immobile

  rhoDotSingle2DipoleGlide(1:ns,c+8) = - rhoDotSingle2DipoleGlide(1:ns,2*c-1) - rhoDotSingle2DipoleGlide(1:ns,2*c) &
                                       + abs(rhoDotSingle2DipoleGlide(1:ns,2*c+3)) + abs(rhoDotSingle2DipoleGlide(1:ns,2*c+4))
enddo


!*** athermal annihilation

rhoDotAthermalAnnihilation = 0.0_pReal

forall (c=1_pInt:2_pInt) &  
  rhoDotAthermalAnnihilation(1:ns,c+8_pInt) = -2.0_pReal * dLower(1:ns,c) / constitutive_nonlocal_burgers(1:ns,myInstance) &
               * (  2.0_pReal * (rhoSgl(1:ns,2*c-1) * abs(gdot(1:ns,2*c)) + rhoSgl(1:ns,2*c) * abs(gdot(1:ns,2*c-1))) &             ! was single hitting single
                  + 2.0_pReal * (abs(rhoSgl(1:ns,2*c+3)) * abs(gdot(1:ns,2*c)) + abs(rhoSgl(1:ns,2*c+4)) * abs(gdot(1:ns,2*c-1))) & ! was single hitting immobile single or was immobile single hit by single
                  + rhoDip(1:ns,c) * (abs(gdot(1:ns,2*c-1)) + abs(gdot(1:ns,2*c))))                                                 ! single knocks dipole constituent
  
  
!*** thermally activated annihilation of dipoles

rhoDotThermalAnnihilation = 0.0_pReal

D = constitutive_nonlocal_Dsd0(myInstance) * exp(-constitutive_nonlocal_Qsd(myInstance) / (kB * Temperature))

vClimb =  constitutive_nonlocal_atomicVolume(myInstance) * D / ( kB * Temperature ) &
          * constitutive_nonlocal_Gmod(myInstance) / ( 2.0_pReal * pi * (1.0_pReal-constitutive_nonlocal_nu(myInstance)) ) &
          * 2.0_pReal / ( dUpper(1:ns,1) + dLower(1:ns,1) )
          
rhoDotThermalAnnihilation(1:ns,9) = - 4.0_pReal * rhoDip(1:ns,1) * vClimb / (dUpper(1:ns,1) - dLower(1:ns,1))                       ! edge climb
rhoDotThermalAnnihilation(1:ns,10) = 0.0_pReal                                                                                      !!! cross slipping still has to be implemented !!!


!****************************************************************************
!*** assign the rates of dislocation densities to my dotState
!*** if evolution rates lead to negative densities, a cutback is enforced

rhoDot = 0.0_pReal
rhoDot = rhoDotFlux &
       + rhoDotMultiplication &
       + rhoDotSingle2DipoleGlide &
       + rhoDotAthermalAnnihilation &
       + rhoDotThermalAnnihilation 

if (    any(rhoSgl(1:ns,1:4) + rhoDot(1:ns,1:4) * timestep < - constitutive_nonlocal_aTolRho(myInstance)) &
   .or. any(rhoDip(1:ns,1:2) + rhoDot(1:ns,9:10) * timestep < - constitutive_nonlocal_aTolRho(myInstance))) then
#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt) then 
    write(6,'(a,i5,a,i2)') '<< CONST >> evolution rate leads to negative density at el ',el,' ip ',ip
    write(6,'(a)') '<< CONST >> enforcing cutback !!!'
  endif
#endif
  constitutive_nonlocal_dotState = DAMASK_NaN
  return
else
  constitutive_nonlocal_dotState(1:10_pInt*ns) = reshape(rhoDot,(/10_pInt*ns/))
endif



#ifndef _OPENMP
  if (iand(debug_what(debug_constitutive),debug_levelBasic) /= 0_pInt &
      .and. ((debug_e == el .and. debug_i == ip .and. debug_g == g)&
             .or. .not. iand(debug_what(debug_constitutive),debug_levelSelective) /= 0_pInt )) then
    write(6,'(a,/,4(12x,12(e12.5,1x),/))') '<< CONST >> dislocation multiplication', rhoDotMultiplication(1:ns,1:4) * timestep
    write(6,'(a,/,8(12x,12(e12.5,1x),/))') '<< CONST >> dislocation flux', rhoDotFlux(1:ns,1:8) * timestep
    write(6,'(a,/,10(12x,12(e12.5,1x),/))') '<< CONST >> dipole formation by glide', rhoDotSingle2DipoleGlide * timestep
    write(6,'(a,/,2(12x,12(e12.5,1x),/))') '<< CONST >> athermal dipole annihilation', &
                                            rhoDotAthermalAnnihilation(1:ns,1:2) * timestep
    write(6,'(a,/,2(12x,12(e12.5,1x),/))') '<< CONST >> thermally activated dipole annihilation', &
                                            rhoDotThermalAnnihilation(1:ns,9:10) * timestep
    write(6,'(a,/,10(12x,12(e12.5,1x),/))') '<< CONST >> total density change', rhoDot * timestep
    write(6,'(a,/,10(12x,12(f12.7,1x),/))') '<< CONST >> relative density change', &
                                            rhoDot(1:ns,1:8) * timestep / (abs(rhoSgl)+1.0e-10), &
                                            rhoDot(1:ns,9:10) * timestep / (rhoDip+1.0e-10)
    write(6,*)
  endif
#endif

endfunction



!*********************************************************************
!* COMPATIBILITY UPDATE                                              *
!* Compatibility is defined as normalized product of signed cosine   *
!* of the angle between the slip plane normals and signed cosine of  *
!* the angle between the slip directions. Only the largest values    *
!* that sum up to a total of 1 are considered, all others are set to *
!* zero.                                                             *
!*********************************************************************
subroutine constitutive_nonlocal_updateCompatibility(orientation,i,e)

use prec,     only:   pReal, &
                      pInt
use math, only:       math_QuaternionDisorientation, &
                      math_mul3x3, &
                      math_qRot
use material, only:   material_phase, &
                      phase_localPlasticity, &
                      phase_plasticityInstance, &
                      homogenization_maxNgrains
use mesh, only:       mesh_element, &
                      mesh_ipNeighborhood, &
                      FE_NipNeighbors, &
                      mesh_maxNips, &
                      mesh_NcpElems
use lattice, only:    lattice_sn, &
                      lattice_sd

implicit none

!* input variables
integer(pInt), intent(in) ::                    i, &                          ! ip index
                                                e                             ! element index
real(pReal), dimension(4,homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: &
                                                orientation                   ! crystal orientation in quaternions
                                            
!* output variables

!* local variables
integer(pInt)                                   Nneighbors, &                 ! number of neighbors
                                                n, &                          ! neighbor index 
                                                neighboring_e, &              ! element index of my neighbor
                                                neighboring_i, &              ! integration point index of my neighbor
                                                my_phase, &
                                                neighboring_phase, &
                                                my_structure, &               ! lattice structure
                                                my_instance, &                ! instance of plasticity
                                                ns, &                         ! number of active slip systems
                                                s1, &                         ! slip system index (me)
                                                s2                            ! slip system index (my neighbor)
real(pReal), dimension(4) ::                    absoluteMisorientation        ! absolute misorientation (without symmetry) between me and my neighbor
real(pReal), dimension(2,constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(1,i,e))),&
                         constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(1,i,e))),&
                         FE_NipNeighbors(mesh_element(2,e))) :: &  
                                                compatibility                 ! compatibility for current element and ip
real(pReal), dimension(3,constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(1,i,e)))) :: &  
                                                slipNormal, &
                                                slipDirection
real(pReal)                                     compatibilitySum, &
                                                thresholdValue, &
                                                nThresholdValues
logical, dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(1,i,e)))) :: & 
                                                belowThreshold


Nneighbors = FE_NipNeighbors(mesh_element(2,e))
my_phase = material_phase(1,i,e)
my_instance = phase_plasticityInstance(my_phase)
my_structure = constitutive_nonlocal_structure(my_instance)
ns = constitutive_nonlocal_totalNslip(my_instance)
slipNormal(1:3,1:ns) =    lattice_sn(1:3, constitutive_nonlocal_slipSystemLattice(1:ns,my_instance), my_structure)
slipDirection(1:3,1:ns) = lattice_sd(1:3, constitutive_nonlocal_slipSystemLattice(1:ns,my_instance), my_structure)


!*** start out fully compatible

compatibility = 0.0_pReal
forall(s1 = 1_pInt:ns) &
  compatibility(1:2,s1,s1,1:Nneighbors) = 1.0_pReal


!*** Loop thrugh neighbors and check whether there is any compatibility.

do n = 1_pInt,Nneighbors
  neighboring_e = mesh_ipNeighborhood(1,n,i,e)
  neighboring_i = mesh_ipNeighborhood(2,n,i,e)
  
  
  !* FREE SURFACE
  !* Set surface transmissivity to the value specified in the material.config
  
  if (neighboring_e <= 0_pInt .or. neighboring_i <= 0_pInt) then
    forall(s1 = 1_pInt:ns) &
      compatibility(1:2,s1,s1,n) = sqrt(constitutive_nonlocal_surfaceTransmissivity(my_instance))
    cycle
  endif
  
  
  !* PHASE BOUNDARY
  !* If we encounter a different nonlocal "cpfem" phase at the neighbor, 
  !* we consider this to be a real "physical" phase boundary, so completely incompatible.
  !* If the neighboring "cpfem" phase has a local plasticity, 
  !* we do not consider this to be a phase boundary, so completely compatible.
  
  neighboring_phase = material_phase(1,neighboring_i,neighboring_e)
  if (neighboring_phase /= my_phase) then
    if (.not. phase_localPlasticity(neighboring_phase)) then
      forall(s1 = 1_pInt:ns) &
        compatibility(1:2,s1,s1,n) = 0.0_pReal ! = sqrt(0.0)
    endif
    cycle
  endif

    
  !* GRAIN BOUNDARY ?
  !* The compatibility value is defined as the product of the slip normal projection and the slip direction projection.
  !* Its sign is always positive for screws, for edges it has the same sign as the slip normal projection. 
  !* Since the sum for each slip system can easily exceed one (which would result in a transmissivity larger than one), 
  !* only values above or equal to a certain threshold value are considered. This threshold value is chosen, such that
  !* the number of compatible slip systems is minimized with the sum of the original compatibility values exceeding one. 
  !* Finally the smallest compatibility value is decreased until the sum is exactly equal to one. 
  !* All values below the threshold are set to zero.
  
  absoluteMisorientation = math_QuaternionDisorientation(orientation(1:4,1,i,e), &
                                                         orientation(1:4,1,neighboring_i,neighboring_e), &
                                                         0_pInt)      ! no symmetry
                                                         
  do s1 = 1_pInt,ns    ! my slip systems
    do s2 = 1_pInt,ns  ! my neighbor's slip systems
      compatibility(1,s2,s1,n) =     math_mul3x3(slipNormal(1:3,s1), math_qRot(absoluteMisorientation, slipNormal(1:3,s2))) &
                               * abs(math_mul3x3(slipDirection(1:3,s1), math_qRot(absoluteMisorientation, slipDirection(1:3,s2))))
      compatibility(2,s2,s1,n) = abs(math_mul3x3(slipNormal(1:3,s1), math_qRot(absoluteMisorientation, slipNormal(1:3,s2)))) &
                               * abs(math_mul3x3(slipDirection(1:3,s1), math_qRot(absoluteMisorientation, slipDirection(1:3,s2))))
    enddo
    
    compatibilitySum = 0.0_pReal
    belowThreshold = .true.
    do while (compatibilitySum < 1.0_pReal .and. any(belowThreshold(1:ns)))
      thresholdValue = maxval(compatibility(2,1:ns,s1,n), belowThreshold(1:ns))              ! screws always positive
      nThresholdValues = real(count(compatibility(2,1:ns,s1,n) == thresholdValue),pReal)
      where (compatibility(2,1:ns,s1,n) >= thresholdValue) &
        belowThreshold(1:ns) = .false.
      if (compatibilitySum + thresholdValue * nThresholdValues > 1.0_pReal) &
        where (abs(compatibility(1:2,1:ns,s1,n)) == thresholdValue) &
          compatibility(1:2,1:ns,s1,n) = sign((1.0_pReal - compatibilitySum) / nThresholdValues, compatibility(1:2,1:ns,s1,n))
      compatibilitySum = compatibilitySum + nThresholdValues * thresholdValue
    enddo
    where (belowThreshold(1:ns)) compatibility(1,1:ns,s1,n) = 0.0_pReal
    where (belowThreshold(1:ns)) compatibility(2,1:ns,s1,n) = 0.0_pReal
  enddo ! my slip systems cycle
enddo   ! neighbor cycle

constitutive_nonlocal_compatibility(1:2,1:ns,1:ns,1:Nneighbors,i,e) = compatibility

endsubroutine 



!*********************************************************************
!* rate of change of temperature                                     *
!*********************************************************************
pure function constitutive_nonlocal_dotTemperature(Tstar_v,Temperature,state,g,ip,el)

use prec,     only: pReal, &
                    pInt, &
                    p_vec
use mesh,     only: mesh_NcpElems, &
                    mesh_maxNips
use material, only: homogenization_maxNgrains
implicit none

!* input variables
integer(pInt), intent(in) ::              g, &              ! current grain ID
                                          ip, &             ! current integration point
                                          el                ! current element
real(pReal), intent(in) ::                Temperature       ! temperature
real(pReal), dimension(6), intent(in) ::  Tstar_v           ! 2nd Piola-Kirchhoff stress in Mandel notation
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: & 
                                          state             ! microstructural state

!* output variables
real(pReal) constitutive_nonlocal_dotTemperature            ! evolution of Temperature

!* local variables
   
constitutive_nonlocal_dotTemperature = 0.0_pReal

endfunction




!*********************************************************************
!* calculates quantities characterizing the microstructure           *
!*********************************************************************
function constitutive_nonlocal_dislocationstress(state, Fe, g, ip, el)

use prec,     only: pReal, &
                    pInt, &
                    p_vec
use math,     only: math_mul33x33, &
                    math_mul33x3, &
                    math_invert33, &
                    math_transpose33, &
                    pi
use mesh,     only: mesh_NcpElems, &
                    mesh_maxNips, &
                    mesh_element, &
                    mesh_node0, &
                    FE_Nips, &
                    mesh_ipCenterOfGravity, &
                    mesh_ipVolume, &
                    mesh_periodicSurface
use material, only: homogenization_maxNgrains, &
                    material_phase, &
                    phase_localPlasticity, &
                    phase_plasticityInstance

implicit none


!*** input variables
integer(pInt), intent(in) ::    g, &                          ! current grain ID
                                ip, &                         ! current integration point
                                el                            ! current element
real(pReal), dimension(3,3,homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: &
                                Fe                            ! elastic deformation gradient
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: &
                                state                         ! microstructural state

!*** input/output variables

!*** output variables
real(pReal), dimension(3,3) ::  constitutive_nonlocal_dislocationstress

!*** local variables
integer(pInt)                   neighboring_el, &             ! element number of neighboring material point
                                neighboring_ip, &             ! integration point of neighboring material point
                                instance, &                   ! my instance of this plasticity
                                neighboring_instance, &       ! instance of this plasticity of neighboring material point
                                latticeStruct, &              ! my lattice structure
                                neighboring_latticeStruct, &  ! lattice structure of neighboring material point
                                phase, &
                                neighboring_phase, &
                                ns, &                         ! total number of active slip systems at my material point
                                neighboring_ns, &             ! total number of active slip systems at neighboring material point
                                c, &                          ! index of dilsocation character (edge, screw)
                                s, &                          ! slip system index
                                t, &                          ! index of dilsocation type (e+, e-, s+, s-, used e+, used e-, used s+, used s-)
                                dir, &
                                deltaX, deltaY, deltaZ, &
                                side, &
                                j
integer(pInt), dimension(2,3) :: periodicImages
real(pReal)                     nu, &                         ! poisson's ratio
                                x, y, z, &                    ! coordinates of connection vector in neighboring lattice frame
                                xsquare, ysquare, zsquare, &  ! squares of respective coordinates
                                distance, &                   ! length of connection vector
                                segmentLength, &              ! segment length of dislocations
                                lambda, &
                                R, Rsquare, Rcube, &
                                denominator, &
                                flipSign, &
                                neighboring_ipVolumeSideLength, &
                                detFe
real(pReal), dimension(3) ::    connection, &                 ! connection vector between me and my neighbor in the deformed configuration
                                connection_neighboringLattice, & ! connection vector between me and my neighbor in the lattice configuration of my neighbor
                                connection_neighboringSlip, & ! connection vector between me and my neighbor in the slip system frame of my neighbor
                                maxCoord, minCoord, &
                                meshSize, &
                                ipCoords, &
                                neighboring_ipCoords
real(pReal), dimension(3,3) ::  sigma, &                      ! dislocation stress for one slip system in neighboring material point's slip system frame
                                Tdislo_neighboringLattice, &  ! dislocation stress as 2nd Piola-Kirchhoff stress at neighboring material point
                                invFe, &                      ! inverse of my elastic deformation gradient
                                neighboring_invFe, &
                                neighboringLattice2myLattice  ! mapping from neighboring MPs lattice configuration to my lattice configuration
real(pReal), dimension(2,2,maxval(constitutive_nonlocal_totalNslip)) :: &
                                neighboring_rhoExcess         ! excess density at neighboring material point (edge/screw,mobile/dead,slipsystem)
real(pReal), dimension(2,maxval(constitutive_nonlocal_totalNslip)) :: &
                                rhoExcessDead
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),8) :: &
                                rhoSgl                        ! single dislocation density (edge+, edge-, screw+, screw-, used edge+, used edge-, used screw+, used screw-)
logical                         inversionError

phase = material_phase(g,ip,el)
instance = phase_plasticityInstance(phase)
latticeStruct = constitutive_nonlocal_structure(instance)
ns = constitutive_nonlocal_totalNslip(instance)



!*** get basic states

forall (s = 1_pInt:ns, t = 1_pInt:4_pInt) &
  rhoSgl(s,t) = max(state(g,ip,el)%p((t-1_pInt)*ns+s), 0.0_pReal)                                                        ! ensure positive single mobile densities
forall (t = 5_pInt:8_pInt) & 
  rhoSgl(1:ns,t) = state(g,ip,el)%p((t-1_pInt)*ns+1_pInt:t*ns)



!*** calculate the dislocation stress of the neighboring excess dislocation densities
!*** zero for material points of local plasticity

constitutive_nonlocal_dislocationstress = 0.0_pReal

if (.not. phase_localPlasticity(phase)) then
  call math_invert33(Fe(1:3,1:3,g,ip,el), invFe, detFe, inversionError)
!  if (inversionError) then
!    return
!  endif

  !* in case of periodic surfaces we have to find out how many periodic images in each direction we need
  
  do dir = 1_pInt,3_pInt
    maxCoord(dir) = maxval(mesh_node0(dir,:))
    minCoord(dir) = minval(mesh_node0(dir,:))
  enddo
  meshSize = maxCoord - minCoord
  ipCoords = mesh_ipCenterOfGravity(1:3,ip,el)
  periodicImages = 0_pInt
  do dir = 1_pInt,3_pInt
    if (mesh_periodicSurface(dir)) then
      periodicImages(1,dir) =   floor((ipCoords(dir) - constitutive_nonlocal_R(instance) - minCoord(dir)) / meshSize(dir), pInt)
      periodicImages(2,dir) = ceiling((ipCoords(dir) + constitutive_nonlocal_R(instance) - maxCoord(dir)) / meshSize(dir), pInt)
    endif
  enddo

      
  !* loop through all material points (also through their periodic images if present), 
  !* but only consider nonlocal neighbors within a certain cutoff radius R
  
  do neighboring_el = 1_pInt,mesh_NcpElems
ipLoop: do neighboring_ip = 1_pInt,FE_Nips(mesh_element(2,neighboring_el))
      neighboring_phase = material_phase(g,neighboring_ip,neighboring_el)
      if (phase_localPlasticity(neighboring_phase)) then
        cycle
      endif
      neighboring_instance = phase_plasticityInstance(neighboring_phase)
      neighboring_latticeStruct = constitutive_nonlocal_structure(neighboring_instance)
      neighboring_ns = constitutive_nonlocal_totalNslip(neighboring_instance)
      call math_invert33(Fe(1:3,1:3,1,neighboring_ip,neighboring_el), neighboring_invFe, detFe, inversionError)
!      if (inversionError) then
!        return
!      endif
      neighboring_ipVolumeSideLength = mesh_ipVolume(neighboring_ip,neighboring_el) ** (1.0_pReal/3.0_pReal) ! reference volume used here
      forall (s = 1_pInt:neighboring_ns, c = 1_pInt:2_pInt) &
        neighboring_rhoExcess(c,1,s) = state(g,neighboring_ip,neighboring_el)%p((2_pInt*c-2_pInt)*neighboring_ns+s) &  ! positive mobiles
                                     - state(g,neighboring_ip,neighboring_el)%p((2_pInt*c-1_pInt)*neighboring_ns+s)    ! negative mobiles
      forall (s = 1_pInt:neighboring_ns, c = 1_pInt:2_pInt) &
        neighboring_rhoExcess(c,2,s) = abs(state(g,neighboring_ip,neighboring_el)%p((2_pInt*c+2_pInt)*neighboring_ns+s)) & ! positive deads
                                     - abs(state(g,neighboring_ip,neighboring_el)%p((2_pInt*c+3_pInt)*neighboring_ns+s))   ! negative deads
      nu = constitutive_nonlocal_nu(neighboring_instance)
      Tdislo_neighboringLattice = 0.0_pReal
      do deltaX = periodicImages(1,1),periodicImages(2,1)
        do deltaY = periodicImages(1,2),periodicImages(2,2)
          do deltaZ = periodicImages(1,3),periodicImages(2,3)
            
            
            !* regular case
            
            if (neighboring_el /= el .or. neighboring_ip /= ip &
                .or. deltaX /= 0_pInt .or. deltaY /= 0_pInt .or. deltaZ /= 0_pInt) then
            
              neighboring_ipCoords = mesh_ipCenterOfGravity(1:3,neighboring_ip,neighboring_el) &
                                   + (/real(deltaX,pReal), real(deltaY,pReal), real(deltaZ,pReal)/) * meshSize
              connection = neighboring_ipCoords - ipCoords
              distance = sqrt(sum(connection * connection))
              if (distance > constitutive_nonlocal_R(instance)) then
                cycle
              endif
                

              !* the segment length is the minimum of the third root of the control volume and the ip distance
              !* this ensures, that the central MP never sits on a neighboring dislocation segment
              
              connection_neighboringLattice = math_mul33x3(neighboring_invFe, connection)
              segmentLength = min(neighboring_ipVolumeSideLength, distance)
      

              !* loop through all slip systems of the neighboring material point
              !* and add up the stress contributions from egde and screw excess on these slip systems (if significant)
      
              do s = 1_pInt,neighboring_ns
                if (all(abs(neighboring_rhoExcess(:,:,s)) < constitutive_nonlocal_aTolRho(instance))) then
                  cycle                                                                             ! not significant
                endif
                
                
                !* map the connection vector from the lattice into the slip system frame
                
                connection_neighboringSlip = math_mul33x3(constitutive_nonlocal_lattice2slip(1:3,1:3,s,neighboring_instance), &
                                                          connection_neighboringLattice)
                
                
                !* edge contribution to stress
                sigma = 0.0_pReal
                
                x = connection_neighboringSlip(1)
                y = connection_neighboringSlip(2)
                z = connection_neighboringSlip(3)
                xsquare = x * x
                ysquare = y * y
                zsquare = z * z

                do j = 1_pInt,2_pInt
                  if (abs(neighboring_rhoExcess(1,j,s)) < constitutive_nonlocal_aTolRho(instance)) then
                    cycle 
                  elseif (j > 1_pInt) then
                    x = connection_neighboringSlip(1) + sign(0.5_pReal * segmentLength, &
                                                               state(g,neighboring_ip,neighboring_el)%p(4*neighboring_ns+s) &
                                                             - state(g,neighboring_ip,neighboring_el)%p(5*neighboring_ns+s))
                    xsquare = x * x
                  endif
                   
                  flipSign = sign(1.0_pReal, -y)
                  do side = 1_pInt,-1_pInt,-2_pInt
                    lambda = real(side,pReal) * 0.5_pReal * segmentLength - y
                    R = sqrt(xsquare + zsquare + lambda * lambda)
                    Rsquare = R * R
                    Rcube = Rsquare * R 
                    denominator = R * (R + flipSign * lambda)
                    if (denominator == 0.0_pReal) then
                      exit ipLoop
                    endif
                      
                    sigma(1,1) = sigma(1,1) - real(side,pReal) * flipSign * z / denominator &
                                                               * (1.0_pReal + xsquare / Rsquare + xsquare / denominator) &
                                                               * neighboring_rhoExcess(1,j,s)
                    sigma(2,2) = sigma(2,2) - real(side,pReal) * (flipSign * 2.0_pReal * nu * z / denominator + z * lambda / Rcube)&
                                                               * neighboring_rhoExcess(1,j,s)
                    sigma(3,3) = sigma(3,3) + real(side,pReal) * flipSign * z / denominator &
                                                               * (1.0_pReal - zsquare / Rsquare - zsquare / denominator) &
                                                               * neighboring_rhoExcess(1,j,s)
                    sigma(1,2) = sigma(1,2) + real(side,pReal) * x * z / Rcube * neighboring_rhoExcess(1,j,s)
                    sigma(1,3) = sigma(1,3) + real(side,pReal) * flipSign * x / denominator &
                                                               * (1.0_pReal - zsquare / Rsquare - zsquare / denominator) &
                                                               * neighboring_rhoExcess(1,j,s)
                    sigma(2,3) = sigma(2,3) - real(side,pReal) * (nu / R - zsquare / Rcube) * neighboring_rhoExcess(1,j,s)
                  enddo
                enddo 
                
                !* screw contribution to stress
                
                x = connection_neighboringSlip(1)   ! have to restore this value, because position might have been adapted for edge deads before
                do j = 1_pInt,2_pInt
                  if (abs(neighboring_rhoExcess(2,j,s)) < constitutive_nonlocal_aTolRho(instance)) then
                    cycle 
                  elseif (j > 1_pInt) then
                    y = connection_neighboringSlip(2) + sign(0.5_pReal * segmentLength, &
                                                               state(g,neighboring_ip,neighboring_el)%p(6_pInt*neighboring_ns+s) &
                                                             - state(g,neighboring_ip,neighboring_el)%p(7_pInt*neighboring_ns+s))
                    ysquare = y * y
                  endif

                  flipSign = sign(1.0_pReal, x)
                  do side = 1_pInt,-1_pInt,-2_pInt
                    lambda = x + real(side,pReal) * 0.5_pReal * segmentLength
                    R = sqrt(ysquare + zsquare + lambda * lambda)
                    Rsquare = R * R
                    Rcube = Rsquare * R 
                    denominator = R * (R + flipSign * lambda)
                    if (denominator == 0.0_pReal) then
                      exit ipLoop
                    endif
                    
                    sigma(1,2) = sigma(1,2) - real(side,pReal) * flipSign * z * (1.0_pReal - nu) / denominator &
                                                                              * neighboring_rhoExcess(2,j,s)
                    sigma(1,3) = sigma(1,3) + real(side,pReal) * flipSign * y * (1.0_pReal - nu) / denominator &
                                                                              * neighboring_rhoExcess(2,j,s)
                  enddo
                enddo
               
                if (all(abs(sigma) < 1.0e-10_pReal)) then ! SIGMA IS NOT A REAL STRESS, THATS WHY WE NEED A REALLY SMALL VALUE HERE
                  cycle
                endif

                !* copy symmetric parts
                
                sigma(2,1) = sigma(1,2)
                sigma(3,1) = sigma(1,3)
                sigma(3,2) = sigma(2,3)

                
                !* scale stresses and map them into the neighboring material point's lattice configuration
                
                sigma = sigma * constitutive_nonlocal_Gmod(neighboring_instance) &
                              * constitutive_nonlocal_burgers(s,neighboring_instance) &
                              / (4.0_pReal * pi * (1.0_pReal - nu)) &
                              * mesh_ipVolume(neighboring_ip,neighboring_el) / segmentLength      ! reference volume is used here (according to the segment length calculation)
                Tdislo_neighboringLattice = Tdislo_neighboringLattice &
                      + math_mul33x33(math_transpose33(constitutive_nonlocal_lattice2slip(1:3,1:3,s,neighboring_instance)), &
                        math_mul33x33(sigma, constitutive_nonlocal_lattice2slip(1:3,1:3,s,neighboring_instance)))
                                            
              enddo ! slip system loop


            !* special case of central ip volume
            !* only consider dead dislocations
            !* we assume that they all sit at a distance equal to half the third root of V
            !* in direction of the according slip direction
            
            else
              
              forall (s = 1_pInt:ns, c = 1_pInt:2_pInt) &
                rhoExcessDead(c,s) = state(g,ip,el)%p((2_pInt*c+2_pInt)*ns+s) &  ! positive deads (here we use symmetry: if this has negative sign it is treated as negative density at positive position instead of positive density at negative position)
                                   + state(g,ip,el)%p((2_pInt*c+3_pInt)*ns+s)    ! negative deads (here we use symmetry: if this has negative sign it is treated as positive density at positive position instead of negative density at negative position)

              do s = 1_pInt,ns
                if (all(abs(rhoExcessDead(:,s)) < constitutive_nonlocal_aTolRho(instance))) then
                  cycle                                                                             ! not significant
                endif
                sigma = 0.0_pReal                                                                   ! all components except for sigma13 are zero
                sigma(1,3) = - (rhoExcessDead(1,s) + rhoExcessDead(2,s) * (1.0_pReal - nu)) * neighboring_ipVolumeSideLength &
                             * constitutive_nonlocal_Gmod(instance) * constitutive_nonlocal_burgers(s,instance) &
                             / (sqrt(2.0_pReal) * pi * (1.0_pReal - nu))
                sigma(3,1) = sigma(1,3)
                
                Tdislo_neighboringLattice = Tdislo_neighboringLattice &
                                      + math_mul33x33(math_transpose33(constitutive_nonlocal_lattice2slip(1:3,1:3,s,instance)), &
                                                      math_mul33x33(sigma, constitutive_nonlocal_lattice2slip(1:3,1:3,s,instance)))
                                            
              enddo ! slip system loop

            endif

          enddo ! deltaZ loop
        enddo ! deltaY loop
      enddo ! deltaX loop


      !* map the stress from the neighboring MP's lattice configuration into the deformed configuration 
      !* and back into my lattice configuration

      neighboringLattice2myLattice = math_mul33x33(invFe, Fe(1:3,1:3,1,neighboring_ip,neighboring_el))
      constitutive_nonlocal_dislocationstress = constitutive_nonlocal_dislocationstress &
                                              + math_mul33x33(neighboringLattice2myLattice, &
                                                math_mul33x33(Tdislo_neighboringLattice, &
                                                math_transpose33(neighboringLattice2myLattice)))
                        
    enddo ipLoop
  enddo ! element loop
    
endif

endfunction


!*********************************************************************
!* return array of constitutive results                              *
!*********************************************************************
function constitutive_nonlocal_postResults(Tstar_v, Fe, Temperature, dt, state, dotState, g,ip,el)

use prec,     only: pReal, &
                    pInt, &
                    p_vec
use math,     only: math_mul6x6, &
                    math_mul33x3, &
                    math_mul33x33, &
                    pi
use mesh,     only: mesh_NcpElems, &
                    mesh_maxNips
use material, only: homogenization_maxNgrains, &
                    material_phase, &
                    phase_plasticityInstance, &
                    phase_Noutput
use lattice,  only: lattice_Sslip_v, &
                    lattice_sd, &
                    lattice_st

implicit none

!*** input variables
integer(pInt), intent(in) ::                g, &                      ! current grain number
                                            ip, &                     ! current integration point
                                            el                        ! current element number
real(pReal), intent(in) ::                  Temperature, &            ! temperature
                                            dt                        ! time increment
real(pReal), dimension(6), intent(in) ::    Tstar_v                   ! current 2nd Piola-Kirchhoff stress in Mandel notation
real(pReal), dimension(3,3,homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) ::  &
                                            Fe                        ! elastic deformation gradient
type(p_vec), dimension(homogenization_maxNgrains,mesh_maxNips,mesh_NcpElems), intent(in) :: &
                                            state                     ! current microstructural state
type(p_vec), intent(in) ::                  dotState                  ! evolution rate of microstructural state

!*** output variables
real(pReal), dimension(constitutive_nonlocal_sizePostResults(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                            constitutive_nonlocal_postResults

!*** local variables
integer(pInt)                               myInstance, &             ! current instance of this plasticity
                                            myStructure, &            ! current lattice structure
                                            ns, &                     ! short notation for the total number of active slip systems
                                            c, &                      ! character of dislocation
                                            cs, &                     ! constitutive result index
                                            o, &                      ! index of current output
                                            t, &                      ! type of dislocation
                                            s, &                      ! index of my current slip system
                                            sLattice                  ! index of my current slip system according to lattice order
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),8) :: &
                                            rhoSgl, &                 ! current single dislocation densities (positive/negative screw and edge without dipoles)
                                            rhoDotSgl                 ! evolution rate of single dislocation densities (positive/negative screw and edge without dipoles)
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),4) :: &
                                            gdot, &                   ! shear rates
                                            v                         ! velocities
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el)))) :: &
                                            rhoForest, &              ! forest dislocation density
                                            tauThreshold, &           ! threshold shear stress
                                            tau, &                    ! current resolved shear stress
                                            tauBack, &                ! back stress from pileups on same slip system
                                            vClimb                    ! climb velocity of edge dipoles
real(pReal), dimension(constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),2) :: &
                                            rhoDip, &                 ! current dipole dislocation densities (screw and edge dipoles)
                                            rhoDotDip, &              ! evolution rate of dipole dislocation densities (screw and edge dipoles)
                                            dLower, &                 ! minimum stable dipole distance for edges and screws
                                            dUpper                    ! current maximum stable dipole distance for edges and screws
real(pReal), dimension(3,constitutive_nonlocal_totalNslip(phase_plasticityInstance(material_phase(g,ip,el))),2) :: &
                                            m, &                      ! direction of dislocation motion for edge and screw (unit vector)
                                            m_currentconf             ! direction of dislocation motion for edge and screw (unit vector) in current configuration
real(pReal)                                 D                         ! self diffusion
real(pReal), dimension(3,3) ::              sigma

myInstance = phase_plasticityInstance(material_phase(g,ip,el))
myStructure = constitutive_nonlocal_structure(myInstance) 
ns = constitutive_nonlocal_totalNslip(myInstance)

cs = 0_pInt
constitutive_nonlocal_postResults = 0.0_pReal


!* short hand notations for state variables

forall (t = 1_pInt:8_pInt) rhoSgl(1:ns,t) = state(g,ip,el)%p((t-1_pInt)*ns+1_pInt:t*ns)
forall (c = 1_pInt:2_pInt) rhoDip(1:ns,c) = state(g,ip,el)%p((7_pInt+c)*ns+1_pInt:(8_pInt+c)*ns)
rhoForest = state(g,ip,el)%p(10_pInt*ns+1:11_pInt*ns)
tauThreshold = state(g,ip,el)%p(11_pInt*ns+1:12_pInt*ns)
tauBack = state(g,ip,el)%p(12_pInt*ns+1:13_pInt*ns)
forall (t = 1_pInt:8_pInt) rhoDotSgl(1:ns,t) = dotState%p((t-1_pInt)*ns+1_pInt:t*ns)
forall (c = 1_pInt:2_pInt) rhoDotDip(1:ns,c) = dotState%p((7_pInt+c)*ns+1_pInt:(8_pInt+c)*ns)
forall (t = 1_pInt:4_pInt) v(1:ns,t) = state(g,ip,el)%p((12_pInt+t)*ns+1_pInt:(13_pInt+t)*ns)


!* Calculate shear rate

do t = 1_pInt,4_pInt
  do s = 1_pInt,ns
    if (rhoSgl(s,t+4_pInt) * v(s,t) < 0.0_pReal) then
      rhoSgl(s,t) = rhoSgl(s,t) + abs(rhoSgl(s,t+4_pInt))                                                                  ! remobilization of immobile singles for changing sign of v (bauschinger effect)
      rhoSgl(s,t+4_pInt) = 0.0_pReal                                                                                       ! remobilization of immobile singles for changing sign of v (bauschinger effect)
    endif
  enddo
enddo

forall (t = 1_pInt:4_pInt) &
  gdot(1:ns,t) = rhoSgl(1:ns,t) * constitutive_nonlocal_burgers(1:ns,myInstance) * v(1:ns,t)
  

!* calculate limits for stable dipole height

do s = 1_pInt,ns
  sLattice = constitutive_nonlocal_slipSystemLattice(s,myInstance)
  tau(s) = math_mul6x6(Tstar_v, lattice_Sslip_v(1:6,sLattice,myStructure)) + tauBack(s)
enddo

dLower = constitutive_nonlocal_minimumDipoleHeight(1:ns,1:2,myInstance)
dUpper(1:ns,2) = min( constitutive_nonlocal_Gmod(myInstance) * constitutive_nonlocal_burgers(1:ns,myInstance) &
                                                             / (8.0_pReal * pi * abs(tau)), &
                      1.0_pReal / sqrt(sum(abs(rhoSgl),2)+sum(rhoDip,2)) )
dUpper(1:ns,1) = dUpper(1:ns,2) / (1.0_pReal - constitutive_nonlocal_nu(myInstance))


!*** dislocation motion

m(1:3,1:ns,1) = lattice_sd(1:3,constitutive_nonlocal_slipSystemLattice(1:ns,myInstance),myStructure)
m(1:3,1:ns,2) = -lattice_st(1:3,constitutive_nonlocal_slipSystemLattice(1:ns,myInstance),myStructure)
forall (c = 1_pInt:2_pInt, s = 1_pInt:ns) &
  m_currentconf(1:3,s,c) = math_mul33x3(Fe, m(1:3,s,c))


do o = 1_pInt,phase_Noutput(material_phase(g,ip,el))
  select case(constitutive_nonlocal_output(o,myInstance))
    
    case ('rho')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(abs(rhoSgl),2) + sum(rhoDip,2)
      cs = cs + ns
      
    case ('rho_sgl')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(abs(rhoSgl),2)
      cs = cs + ns
      
    case ('rho_sgl_mobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(abs(rhoSgl(1:ns,1:4)),2)
      cs = cs + ns
      
    case ('rho_sgl_immobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoSgl(1:ns,5:8),2)
      cs = cs + ns
      
    case ('rho_dip')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoDip,2)
      cs = cs + ns
      
    case ('rho_edge')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(abs(rhoSgl(1:ns,(/1,2,5,6/))),2) + rhoDip(1:ns,1)
      cs = cs + ns
      
    case ('rho_sgl_edge')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(abs(rhoSgl(1:ns,(/1,2,5,6/))),2)
      cs = cs + ns
      
    case ('rho_sgl_edge_mobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoSgl(1:ns,1:2),2)
      cs = cs + ns
      
    case ('rho_sgl_edge_immobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoSgl(1:ns,5:6),2)
      cs = cs + ns
      
    case ('rho_sgl_edge_pos')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,1) + abs(rhoSgl(1:ns,5))
      cs = cs + ns
      
    case ('rho_sgl_edge_pos_mobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,1)
      cs = cs + ns
      
    case ('rho_sgl_edge_pos_immobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,5)
      cs = cs + ns
      
    case ('rho_sgl_edge_neg')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,2) + abs(rhoSgl(1:ns,6))
      cs = cs + ns
      
    case ('rho_sgl_edge_neg_mobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,2)
      cs = cs + ns
      
    case ('rho_sgl_edge_neg_immobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,6)
      cs = cs + ns
      
    case ('rho_dip_edge')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoDip(1:ns,1)
      cs = cs + ns
      
    case ('rho_screw')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(abs(rhoSgl(1:ns,(/3,4,7,8/))),2) + rhoDip(1:ns,2)
      cs = cs + ns
      
    case ('rho_sgl_screw')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(abs(rhoSgl(1:ns,(/3,4,7,8/))),2)
      cs = cs + ns
            
    case ('rho_sgl_screw_mobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoSgl(1:ns,3:4),2)
      cs = cs + ns
      
    case ('rho_sgl_screw_immobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoSgl(1:ns,7:8),2)
      cs = cs + ns
      
    case ('rho_sgl_screw_pos')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,3) + abs(rhoSgl(1:ns,7))
      cs = cs + ns
      
    case ('rho_sgl_screw_pos_mobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,3)
      cs = cs + ns
      
    case ('rho_sgl_screw_pos_immobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,7)
      cs = cs + ns
      
    case ('rho_sgl_screw_neg')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,4) + abs(rhoSgl(1:ns,8))
      cs = cs + ns

    case ('rho_sgl_screw_neg_mobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,4)
      cs = cs + ns

    case ('rho_sgl_screw_neg_immobile')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,8)
      cs = cs + ns

    case ('rho_dip_screw')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoDip(1:ns,2)
      cs = cs + ns
      
    case ('excess_rho')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = (rhoSgl(1:ns,1) + abs(rhoSgl(1:ns,5))) &
                                                         - (rhoSgl(1:ns,2) + abs(rhoSgl(1:ns,6))) &
                                                         + (rhoSgl(1:ns,3) + abs(rhoSgl(1:ns,7))) &
                                                         - (rhoSgl(1:ns,4) + abs(rhoSgl(1:ns,8)))
      cs = cs + ns
      
    case ('excess_rho_edge')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = (rhoSgl(1:ns,1) + abs(rhoSgl(1:ns,5))) &
                                                         - (rhoSgl(1:ns,2) + abs(rhoSgl(1:ns,6)))
      cs = cs + ns
      
    case ('excess_rho_screw')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = (rhoSgl(1:ns,3) + abs(rhoSgl(1:ns,7))) &
                                                         - (rhoSgl(1:ns,4) + abs(rhoSgl(1:ns,8)))
      cs = cs + ns
      
    case ('rho_forest')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoForest
      cs = cs + ns
    
    case ('delta')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = 1.0_pReal / sqrt(sum(abs(rhoSgl),2) + sum(rhoDip,2))
      cs = cs + ns
      
    case ('delta_sgl')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = 1.0_pReal / sqrt(sum(abs(rhoSgl),2))
      cs = cs + ns
      
    case ('delta_dip')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = 1.0_pReal / sqrt(sum(rhoDip,2))
      cs = cs + ns
      
    case ('shearrate')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(gdot,2)
      cs = cs + ns
      
    case ('resolvedstress')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = tau
      cs = cs + ns
      
    case ('resolvedstress_back')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = tauBack
      cs = cs + ns
      
    case ('resolvedstress_external')
      do s = 1_pInt,ns  
        sLattice = constitutive_nonlocal_slipSystemLattice(s,myInstance)
        constitutive_nonlocal_postResults(cs+s) = math_mul6x6(Tstar_v, lattice_Sslip_v(1:6,sLattice,myStructure))
      enddo
      cs = cs + ns
      
    case ('resistance')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = tauThreshold
      cs = cs + ns
    
    case ('rho_dot')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoDotSgl,2) + sum(rhoDotDip,2)
      cs = cs + ns
      
    case ('rho_dot_sgl')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoDotSgl,2)
      cs = cs + ns
      
    case ('rho_dot_dip')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(rhoDotDip,2)
      cs = cs + ns
    
    case ('rho_dot_gen')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) =   sum(abs(gdot),2) * sqrt(rhoForest)  &
                                                      / constitutive_nonlocal_lambda0(1:ns,myInstance) &
                                                      / constitutive_nonlocal_burgers(1:ns,myInstance)
      cs = cs + ns

    case ('rho_dot_gen_edge')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) =   sum(abs(gdot(1:ns,3:4)),2) * sqrt(rhoForest)  &
                                                      / constitutive_nonlocal_lambda0(1:ns,myInstance) &
                                                      / constitutive_nonlocal_burgers(1:ns,myInstance)
      cs = cs + ns

    case ('rho_dot_gen_screw')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) =   sum(abs(gdot(1:ns,1:2)),2) * sqrt(rhoForest)  &
                                                      / constitutive_nonlocal_lambda0(1:ns,myInstance) &
                                                      / constitutive_nonlocal_burgers(1:ns,myInstance)
      cs = cs + ns
      
    case ('rho_dot_sgl2dip')
      do c=1_pInt,2_pInt                                                                                                                      ! dipole formation by glide
        constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = constitutive_nonlocal_postResults(cs+1:cs+ns) + &
            2.0_pReal * dUpper(1:ns,c) / constitutive_nonlocal_burgers(1:ns,myInstance) &
                      * (  2.0_pReal * (  rhoSgl(1:ns,2_pInt*c-1_pInt) * abs(gdot(1:ns,2*c)) &
                                        + rhoSgl(1:ns,2_pInt*c) * abs(gdot(1:ns,2_pInt*c-1_pInt))) &                                               ! was single hitting single
                         + 2.0_pReal * (  abs(rhoSgl(1:ns,2_pInt*c+3_pInt)) * abs(gdot(1:ns,2_pInt*c)) &
                                        + abs(rhoSgl(1:ns,2_pInt*c+4_pInt)) * abs(gdot(1:ns,2_pInt*c-1_pInt))))                                         ! was single hitting immobile/used single
      enddo
      cs = cs + ns
    
    case ('rho_dot_ann_ath')
      do c=1_pInt,2_pInt
        constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = constitutive_nonlocal_postResults(cs+1:cs+ns) + &
            2.0_pReal * dLower(1:ns,c) / constitutive_nonlocal_burgers(1:ns,myInstance) &
                      * (  2.0_pReal * (  rhoSgl(1:ns,2_pInt*c-1_pInt) * abs(gdot(1:ns,2_pInt*c)) &
                                        + rhoSgl(1:ns,2_pInt*c) * abs(gdot(1:ns,2_pInt*c-1_pInt))) &                                               ! was single hitting single
                         + 2.0_pReal * (  abs(rhoSgl(1:ns,2_pInt*c+3_pInt)) * abs(gdot(1:ns,2_pInt*c)) &
                                        + abs(rhoSgl(1:ns,2_pInt*c+4_pInt)) * abs(gdot(1:ns,2_pInt*c-1_pInt))) &                                        ! was single hitting immobile/used single
                         + rhoDip(1:ns,c) * (abs(gdot(1:ns,2_pInt*c-1_pInt)) + abs(gdot(1:ns,2_pInt*c))))                                          ! single knocks dipole constituent
      enddo
      cs = cs + ns
      
    case ('rho_dot_ann_the') 
      D = constitutive_nonlocal_Dsd0(myInstance) * exp(-constitutive_nonlocal_Qsd(myInstance) / (kB * Temperature))

      vClimb =  constitutive_nonlocal_atomicVolume(myInstance) * D / (kB * Temperature) &
          * constitutive_nonlocal_Gmod(myInstance) / (2.0_pReal * pi * (1.0_pReal-constitutive_nonlocal_nu(myInstance))) &
          * 2.0_pReal / (dUpper(1:ns,1) + dLower(1:ns,1))
          
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = 4.0_pReal * rhoDip(1:ns,1) * vClimb / (dUpper(1:ns,1) - dLower(1:ns,1))
      ! !!! cross-slip of screws missing !!!
      cs = cs + ns

    case ('rho_dot_flux')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(constitutive_nonlocal_rhoDotFlux(1:ns,1:4,g,ip,el),2) &
                                                      + sum(abs(constitutive_nonlocal_rhoDotFlux(1:ns,5:8,g,ip,el)),2)
      cs = cs + ns
    
    case ('rho_dot_flux_edge')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(constitutive_nonlocal_rhoDotFlux(1:ns,1:2,g,ip,el),2) &
                                                      + sum(abs(constitutive_nonlocal_rhoDotFlux(1:ns,5:6,g,ip,el)),2)
      cs = cs + ns
      
    case ('rho_dot_flux_screw')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = sum(constitutive_nonlocal_rhoDotFlux(1:ns,3:4,g,ip,el),2) &
                                                      + sum(abs(constitutive_nonlocal_rhoDotFlux(1:ns,7:8,g,ip,el)),2)
      cs = cs + ns
            
    case ('velocity_edge_pos')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = v(1:ns,1)
      cs = cs + ns
    
    case ('velocity_edge_neg')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = v(1:ns,2)
      cs = cs + ns
    
    case ('velocity_screw_pos')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = v(1:ns,3)
      cs = cs + ns
    
    case ('velocity_screw_neg')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = v(1:ns,4)
      cs = cs + ns
    
    case ('fluxdensity_edge_pos_x')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,1) * v(1:ns,1) * m_currentconf(1,1:ns,1)
      cs = cs + ns
    
    case ('fluxdensity_edge_pos_y')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,1) * v(1:ns,1) * m_currentconf(2,1:ns,1)
      cs = cs + ns
    
    case ('fluxdensity_edge_pos_z')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,1) * v(1:ns,1) * m_currentconf(3,1:ns,1)
      cs = cs + ns
    
    case ('fluxdensity_edge_neg_x')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = - rhoSgl(1:ns,2) * v(1:ns,2) * m_currentconf(1,1:ns,1)
      cs = cs + ns
    
    case ('fluxdensity_edge_neg_y')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = - rhoSgl(1:ns,2) * v(1:ns,2) * m_currentconf(2,1:ns,1)
      cs = cs + ns
    
    case ('fluxdensity_edge_neg_z')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = - rhoSgl(1:ns,2) * v(1:ns,2) * m_currentconf(3,1:ns,1)
      cs = cs + ns
    
    case ('fluxdensity_screw_pos_x')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,3) * v(1:ns,3) * m_currentconf(1,1:ns,2)
      cs = cs + ns
    
    case ('fluxdensity_screw_pos_y')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,3) * v(1:ns,3) * m_currentconf(2,1:ns,2)
      cs = cs + ns
    
    case ('fluxdensity_screw_pos_z')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = rhoSgl(1:ns,3) * v(1:ns,3) * m_currentconf(3,1:ns,2)
      cs = cs + ns
    
    case ('fluxdensity_screw_neg_x')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = - rhoSgl(1:ns,4) * v(1:ns,4) * m_currentconf(1,1:ns,2)
      cs = cs + ns
    
    case ('fluxdensity_screw_neg_y')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = - rhoSgl(1:ns,4) * v(1:ns,4) * m_currentconf(2,1:ns,2)
      cs = cs + ns
    
    case ('fluxdensity_screw_neg_z')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = - rhoSgl(1:ns,4) * v(1:ns,4) * m_currentconf(3,1:ns,2)
      cs = cs + ns
    
    case ('maximumdipoleheight_edge')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = dUpper(1:ns,1)
      cs = cs + ns
      
    case ('maximumdipoleheight_screw')
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = dUpper(1:ns,2)
      cs = cs + ns
    
    case('dislocationstress')
      sigma = constitutive_nonlocal_dislocationstress(state, Fe, g, ip, el)
      constitutive_nonlocal_postResults(cs+1_pInt) = sigma(1,1)
      constitutive_nonlocal_postResults(cs+2_pInt) = sigma(2,2)
      constitutive_nonlocal_postResults(cs+3_pInt) = sigma(3,3)
      constitutive_nonlocal_postResults(cs+4_pInt) = sigma(1,2)
      constitutive_nonlocal_postResults(cs+5_pInt) = sigma(2,3)
      constitutive_nonlocal_postResults(cs+6_pInt) = sigma(3,1)
      cs = cs + 6_pInt
    
    case('accumulatedshear')
      constitutive_nonlocal_accumulatedShear(1:ns,g,ip,el) = constitutive_nonlocal_accumulatedShear(1:ns,g,ip,el) + sum(gdot,2)*dt
      constitutive_nonlocal_postResults(cs+1_pInt:cs+ns) = constitutive_nonlocal_accumulatedShear(1:ns,g,ip,el)
      cs = cs + ns

 end select
enddo

endfunction

END MODULE
