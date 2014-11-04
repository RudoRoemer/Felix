!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! felixsim
!
! Richard Beanland, Keith Evans, Rudolf A Roemer and Alexander Hubert
!
! (C) 2013/14, all right reserved
!
! Version: :VERSION:
! Date:    :DATE:
! Time:    :TIME:
! Status:  :RLSTATUS:
! Build:   :BUILD:
! Author:  :AUTHOR:
! 
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
!  This file is part of felixsim.
!
!  felixsim is free software: you can redistribute it and/or modify
!  it under the terms of the GNU General Public License as published by
!  the Free Software Foundation, either version 3 of the License, or
!  (at your option) any later version.
!  
!  felixsim is distributed in the hope that it will be useful,
!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!  GNU General Public License for more details.
!  
!  You should have received a copy of the GNU General Public License
!  along with felixsim.  If not, see <http://www.gnu.org/licenses/>.
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! $Id: FelixSim.f90,v 1.89 2014/04/28 12:26:19 phslaz Exp $
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

PROGRAM FelixSim
 
  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara

  USE IChannels

  USE MPI
  USE MyMPI

  !--------------------------------------------------------------------
  ! local variable definitions
  !--------------------------------------------------------------------
  
  IMPLICIT NONE

  REAL(RKIND) time, norm
  COMPLEX(CKIND) sumC, sumD
  
  !--------------------------------------------------------------------
  ! image related variables
  REAL(RKIND) Rx0,Ry0, RImageRadius,Rradius, RThickness
  
  INTEGER(IKIND) ILocalPixelCountMin, ILocalPixelCountMax
  !CKIND? was RKIND
  COMPLEX(CKIND) CVgij
  
  INTEGER(IKIND) ind,jnd,hnd,knd,pnd,gnd, &
       IHours,IMinutes,ISeconds
  INTEGER, DIMENSION(:), ALLOCATABLE :: &
       IWeakBeamVec,IDisplacements,ICount
  REAL(RKIND),DIMENSION(:,:,:),ALLOCATABLE :: &
       RIndividualReflectionsRoot
  REAL(RKIND),DIMENSION(:,:,:),ALLOCATABLE :: &
       RFinalMontageImageRoot
  REAL(RKIND),DIMENSION(:,:),ALLOCATABLE :: &
       RSymDiff
  COMPLEX(CKIND),DIMENSION(:,:,:), ALLOCATABLE :: &
       CAmplitudeandPhaseRoot
  INTEGER IRootArraySize, IPixelPerRank
  CHARACTER*40 surname 
  CHARACTER*25 CThickness 
  CHARACTER*25 CThicknessLength  
 
  INTEGER(IKIND),DIMENSION(2,2) :: ITest
  
  
  INTEGER(IKIND):: IErr, &
       IThicknessIndex, ILowerLimit, &
       IUpperLimit
  REAL(RKIND) StartTime, CurrentTime, Duration, TotalDurationEstimate
  

  !-------------------------------------------------------------------
  ! constants
  !-------------------------------------------------------------------

  CALL Init_Numbers
  
  !-------------------------------------------------------------------
  ! set the error value to zero, will change upon error
  !-------------------------------------------------------------------

  IErr=0

  !--------------------------------------------------------------------
  ! MPI initialization
  !--------------------------------------------------------------------

  ! Initialise MPI  
  CALL MPI_Init(IErr)  
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in MPI_Init()"
     GOTO 9999
  ENDIF

  ! Get the rank of the current process
  CALL MPI_Comm_rank(MPI_COMM_WORLD,my_rank,IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in MPI_Comm_rank()"
     GOTO 9999
  ENDIF

  ! Get the size of the current communicator
  CALL MPI_Comm_size(MPI_COMM_WORLD,p,IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in MPI_Comm_size()"
     GOTO 9999
  ENDIF

  !--------------------------------------------------------------------
  ! protocal feature startup
  !--------------------------------------------------------------------
  
  IF((IWriteFLAG.GE.0.AND.my_rank.EQ.0).OR.IWriteFLAG.GE.10) THEN
     PRINT*,"--------------------------------------------------------------"
     PRINT*,"FelixSim: ", RStr
     PRINT*,"          ", DStr
     PRINT*,"          ", AStr
     PRINT*,"          on rank= ", my_rank, " of ", p, " in total."
     PRINT*,"--------------------------------------------------------------"
  END IF

  !--------------------------------------------------------------------
  ! timing startup
  !--------------------------------------------------------------------

  CALL cpu_time(StartTime)

  !--------------------------------------------------------------------
  ! INPUT section 
  !--------------------------------------------------------------------
  
  ISoftwareMode = 0 ! felixsimmode
  
  !Read from input files
  CALL ReadInput (IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in ReadInput()"
     GOTO 9999
  ENDIF
     
  IF((IWriteFLAG.GE.1.AND.my_rank.EQ.0).OR.IWriteFLAG.GE.10) THEN
     PRINT*,"ITotalAtoms = ",ITotalAtoms
  END IF
  
  !--------------------------------------------------------------------
  ! open outfiles 
  !--------------------------------------------------------------------

  WRITE(surname,'(A1,I1.1,A1,I1.1,A1,I1.1,A2,I4.4)') &
       "S", IScatterFactorMethodFLAG, &
       "B", ICentralBeamFLAG, &
       "M", IMaskFLAG, &
       "_P", IPixelCount
  
  ! eigensystem - MPI Writing used to be here
  IF(IOutputFLAG.GE.1.AND.my_rank.EQ.ZERO) THEN
 !    CALL OpenData_MPI(IChOutES_MPI, "ES", surname, IErr)
  ENDIF
 
  
  ! UgMatEffective
  IF(IOutputFLAG.GE.2) THEN
 !    CALL OpenData_MPI(IChOutUM_MPI, "UM", surname, IErr)
  ENDIF
 

  !-------------------------------------------------------------------- 
  !Setup Experimental Variables
  !--------------------------------------------------------------------
  CALL ExperimentalSetup (IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in ExperimentalSetup()"
     GOTO 9999
  ENDIF


  !--------------------------------------------------------------------
  ! Setup Image
  !--------------------------------------------------------------------

  CALL ImageSetup( IErr )
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in ImageSetup()"
     GOTO 9999
  ENDIF

 
  !--------------------------------------------------------------------
  ! MAIN section
  !--------------------------------------------------------------------
 
  CALL StructureFactorSetup(IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in StructureFactorSetup()"
     GOTO 9999
  ENDIF


!!$  DO ind = 1,(SIZE(ISymmetryStrengthKey,DIM=1))
!!$     PRINT*,ISymmetryStrengthKey(ind,:),RUniqueUgPrimeValues(ind)
!!$  END DO

  

!!$  DO ind = 1,MAXVAL(ISymmetryRelations)
!!$     PRINT*,ISymmetryStrengthKey(ind,:),&
!!$          ISymmetryRelations(ISymmetryStrengthKey(ind,1),&
!!$          ISymmetryStrengthKey(ind,2))
!!$  END DO

  !PRINT*,"No. of Unique Ugs = ",MAXVAL(ISymmetryRelations)
     
!!$  DO ind = 1,50
!!$     PRINT*,CUgMatPrime(ind,1),CUgMat(1,ind)
!!$  END DO

  !GOTO 9999

  !!$ ! UgMatEffective - MPI Writing used to be here
  IF(IOutputFLAG.GE.2) THEN
    ! CALL WriteDataC_MPI(IChOutUM_MPI, ind,jnd, &
     !     CUgMatEffective(:,:), nBeams*nBeams, 1, IErr)
 
  ENDIF

  Deallocate( &
       RgMatMat,RgMatMag,STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in Deallocation of RgMat"
     GOTO 9999
  ENDIF
         
  !--------------------------------------------------------------------
  ! reserve memory for effective eigenvalue problem
  !--------------------------------------------------------------------

  !Kprime Vectors and Deviation Parameter
  
  ALLOCATE( &
       RDevPara(nReflections), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables RDevPara"
     GOTO 9999
  ENDIF

  ALLOCATE( &
       IStrongBeamList(nReflections), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables IStrongBeamList"
     GOTO 9999
  ENDIF

  ALLOCATE( &
       IWeakBeamList(nReflections), & 
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables IWeakBeamList"
     GOTO 9999
  ENDIF

  !--------------------------------------------------------------------
  ! MAIN LOOP: solve for each (ind,jnd) pixel
  !--------------------------------------------------------------------

  ILocalPixelCountMin= (IPixelTotal*(my_rank)/p)+1
  ILocalPixelCountMax= (IPixelTotal*(my_rank+1)/p) 

  IF((IWriteFLAG.GE.6.AND.my_rank.EQ.0).OR.IWriteFLAG.GE.10) THEN
     PRINT*,"FelixSim(", my_rank, "): starting the eigenvalue problem"
     PRINT*,"FelixSim(", my_rank, "): for lines ", ILocalPixelCountMin, &
          " to ", ILocalPixelCountMax
  ENDIF
  
  IThicknessCount= (RFinalThickness- RInitialThickness)/RDeltaThickness + 1

  IF(IImageFLAG.LE.2) THEN
     ALLOCATE( &
          RIndividualReflections(IReflectOut,IThicknessCount,&
          (ILocalPixelCountMax-ILocalPixelCountMin)+1),&
          STAT=IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables Individual Images"
        GOTO 9999
     ENDIF
     
     RIndividualReflections = ZERO
  ELSE
     ALLOCATE( &
          CAmplitudeandPhase(IReflectOut,IThicknessCount,&
          (ILocalPixelCountMax-ILocalPixelCountMin)+1),&
          STAT=IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " in ALLOCATE() of DYNAMIC variables Amplitude and Phase"
        GOTO 9999
     ENDIF
     CAmplitudeandPhase = CZERO
  END IF

  ALLOCATE( &
       CFullWaveFunctions(nReflections), & 
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables CFullWaveFunctions"
     GOTO 9999
  ENDIF
  
  ALLOCATE( &
       RFullWaveIntensity(nReflections), & 
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables RFullWaveIntensity"
     GOTO 9999
  ENDIF  

  IMAXCBuffer = 200000
  IPixelComputed= 0
  
  DEALLOCATE( &
       RScattFactors, &
       RrVecMat, Rsg, &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in DEALLOCATE() "
     GOTO 9999
  ENDIF
  
  IF((IWriteFLAG.GE.0.AND.my_rank.EQ.0).OR.IWriteFLAG.GE.6) THEN
     PRINT*,"FelixSim(",my_rank,") Entering BlochLoop()"
  END IF

  DO knd = ILocalPixelCountMin,ILocalPixelCountMax,1
     ind = IPixelLocations(knd,1)
     jnd = IPixelLocations(knd,2)
     CALL BlochCoefficientCalculation(ind,jnd,knd,ILocalPixelCountMin,IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " in BlochCofficientCalculation"
        GOTO 9999
     ENDIF
  END DO
  
  IF((IWriteFLAG.GE.6.AND.my_rank.EQ.0).OR.IWriteFLAG.GE.10) THEN
     PRINT*,"FelixSim : ",my_rank," is exiting calculation loop"
  END IF

  !--------------------------------------------------------------------
  ! close outfiles
  !--------------------------------------------------------------------
  
  ! eigensystem
  IF(IOutputFLAG.GE.1) THEN
     CALL MPI_FILE_CLOSE(IChOutES_MPI, IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " Closing IChOutES"
        GOTO 9999
     ENDIF     
  ENDIF
    
  ! UgMatEffective
  IF(IOutputFLAG.GE.2) THEN
     CALL MPI_FILE_CLOSE(IChOutUM_MPI, IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " Closing IChOutUM"
        GOTO 9999
     ENDIF     
  ENDIF

  ALLOCATE( &
       RIndividualReflectionsRoot(IReflectOut,IThicknessCount,IPixelTotal),&
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables Root Reflections"
     GOTO 9999
  ENDIF
  
  IF(IImageFLAG.GE.3) THEN
     ALLOCATE(&
          CAmplitudeandPhaseRoot(IReflectOut,IThicknessCount,IPixelTotal),&
          STAT=IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " in ALLOCATE() of DYNAMIC variables Root Amplitude and Phase"
        GOTO 9999
     ENDIF
     CAmplitudeandPhaseRoot = CZERO
  END IF

  RIndividualReflectionsRoot = ZERO
  
  IF(IWriteFLAG.GE.10) THEN
     
     PRINT*,"REDUCING Reflections",my_rank
     
  END IF

  ALLOCATE(&
       IDisplacements(p),ICount(p),&
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
          " In ALLOCATE"
     GOTO 9999
  ENDIF

  DO pnd = 1,p
     IDisplacements(pnd) = (IPixelTotal*(pnd-1)/p)
     ICount(pnd) = (((IPixelTotal*(pnd)/p) - (IPixelTotal*(pnd-1)/p)))*IReflectOut*IThicknessCount
          
  END DO
  
  DO ind = 1,p
        IDisplacements(ind) = (IDisplacements(ind))*IReflectOut*IThicknessCount
  END DO
  
  IF(IImageFLAG.LE.2) THEN
     CALL MPI_GATHERV(RIndividualReflections,ICount,&
          MPI_DOUBLE_PRECISION,RIndividualReflectionsRoot,&
          ICount,IDisplacements,MPI_DOUBLE_PRECISION,0,&
          MPI_COMM_WORLD,IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " In MPI_GATHERV"
        GOTO 9999
     ENDIF     
  ELSE     
     CALL MPI_GATHERV(CAmplitudeandPhase,ICount,&
          MPI_DOUBLE_COMPLEX,CAmplitudeandPhaseRoot,&
          ICount,IDisplacements,MPI_DOUBLE_COMPLEX,0, &
          MPI_COMM_WORLD,IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " In MPI_GATHERV"
        GOTO 9999
     ENDIF   
  END IF

  IF(IWriteFLAG.GE.10) THEN
     PRINT*,"REDUCED Reflections",my_rank
  END IF
  
  IF(IImageFLAG.GE.3) THEN
     DEALLOCATE(&
          CAmplitudeandPhase,STAT=IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " Deallocating CAmplitudePhase"
        GOTO 9999
     ENDIF   
  END IF
   
  IF(IImageFLAG.LE.2) THEN
     DEALLOCATE( &
          RIndividualReflections,STAT=IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " Deallocating RIndividualReflections"
        GOTO 9999
     ENDIF   
  END IF

  IF(my_rank.EQ.0) THEN
     ALLOCATE( &
          RFinalMontageImageRoot(MAXVAL(IImageSizeXY),&
          MAXVAL(IImageSizeXY),IThicknessCount),&
          STAT=IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " in ALLOCATE() of DYNAMIC variables Root Montage"
        GOTO 9999
     ENDIF

    RFinalMontageImageRoot = ZERO		
  END IF

  IF(my_rank.EQ.0.AND.IImageFLAG.GE.3) THEN
     RIndividualReflectionsRoot = &
          CAmplitudeandPhaseRoot * CONJG(CAmplitudeandPhaseRoot)
  END IF

  IF(my_rank.EQ.0) THEN
     DO IThicknessIndex =1,IThicknessCount
        DO knd = 1,IPixelTotal
           ind = IPixelLocations(knd,1)
           jnd = IPixelLocations(knd,2)
           CALL MakeMontagePixel(ind,jnd,IThicknessIndex,&
                RFinalMontageImageRoot,&
                RIndividualReflectionsRoot(:,IThicknessIndex,knd),IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
                   " in MakeMontagePixel"
              GOTO 9999
           ENDIF
        END DO
     END DO
  END IF

  !--------------------------------------------------------------------
  ! Write out Images
  !--------------------------------------------------------------------
  
  IF (my_rank.EQ.0) THEN

     CALL WriteOutput(CAmplitudeandPhaseRoot,RIndividualReflectionsRoot,RFinalMontageImageRoot,IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error ", IErr, &
             " in WriteOutput"
        GOTO 9999
     ENDIF
          
  END IF
  
  !--------------------------------------------------------------------
  ! free memory
  !--------------------------------------------------------------------
  
  !Dellocate Global Variables
  
  DEALLOCATE( &
       RgVecMatT, &
       Rhklpositions, RMask,STAT=IErr)       
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in Deallocation of RgVecMatT etc"
     GOTO 9999
  ENDIF
  DEALLOCATE( &
       CUgMat,IPixelLocations, &
       RDevPara,STAT=IErr)       
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in Deallocation of CUgmat etc"
     GOTO 9999
  ENDIF
  
  DEALLOCATE( &
       RIndividualReflectionsRoot,STAT=IErr)       
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error in Deallocation of RIndividualReflectionsRoot"
     GOTO 9999
  ENDIF
  
  IF(IImageFLAG.GE.3) THEN
     DEALLOCATE(&
          CAmplitudeandPhaseRoot,STAT=IErr) 
     
     IF( IErr.NE.0 ) THEN
        PRINT*,"FelixSim(", my_rank, ") error in Deallocation of CAmplitudeandPhase"
        GOTO 9999
     ENDIF
  END IF
  
  !--------------------------------------------------------------------
  ! finish off
  !--------------------------------------------------------------------
    
  CALL cpu_time(CurrentTime)
  Duration=(CurrentTime-StartTime)
  IHours = FLOOR(Duration/3600.0D0)
  IMinutes = FLOOR(MOD(Duration,3600.0D0)/60.0D0)
  ISeconds = MOD(Duration,3600.0D0)-IMinutes*60.0D0

  PRINT*, "FelixSim(", my_rank, ") ", RStr, ", used time=", IHours, "hrs ",IMinutes,"mins ",ISeconds,"Seconds "

  !--------------------------------------------------------------------
  ! Shut down MPI
  !--------------------------------------------------------------------W
9999 &
  CALL MPI_Finalize(IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"FelixSim(", my_rank, ") error ", IErr, " in MPI_Finalize()"
     STOP
  ENDIF

  ! clean shutdown
  STOP
  
!!$800 PRINT*,"FelixSim(", my_rank, "): ERR in CLOSE()"
!!$  IErr= 1
!!$  RETURN

END PROGRAM FelixSim