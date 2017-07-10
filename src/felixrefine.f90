!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! felixrefine
!
! Richard Beanland, Keith Evans, Rudolf A Roemer and Alexander Hubert
!
! (C) 2013/14/15/16, all rights reserved
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
!  This file is part of felixrefine.
!
!  felixrefine is free software: you can redistribute it and/or modify
!  it under the terms of the GNU General Public License as published by
!  the Free Software Foundation, either version 3 of the License, or
!  (at your option) any later version.
!  
!  felixrefine is distributed in the hope that it will be useful,
!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!  GNU General Public License for more details.
!  
!  You should have received a copy of the GNU General Public License
!  along with felixrefine.  If not, see <http://www.gnu.org/licenses/>.
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

PROGRAM Felixrefine
 
  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara

  USE IChannels

  USE MPI
  USE MyMPI

  !--------------------------------------------------------------------
  ! local variable definitions
  IMPLICIT NONE

  INTEGER(IKIND) :: IErr,IIterationFLAG,ind,jnd,knd,lnd,mnd,nnd,ICalls,Iter,ICutOff,IHOLZgPoolMag,&
	   IBSMaxLocGVecAmp,ILaueLevel,INumTotalReflections,ITotalLaueZoneLevel,INhkl,IExitFLAG,ICycle,&
	   INumInitReflections,IZerothLaueZoneLevel,INumFinalReflections,IThicknessIndex,IVariableType
  INTEGER(IKIND) :: IHours,IMinutes,ISeconds,IMilliSeconds,IStartTime,ICurrentTime,IRate
  INTEGER(IKIND),DIMENSION(:),ALLOCATABLE :: IOriginGVecIdentifier
  REAL(RKIND) :: StartTime, CurrentTime, Duration, TotalDurationEstimate,RANDOMNUMBER,&
       RHOLZAcceptanceAngle,RLaueZoneGz,RMaxGMag,RPvecMag,RScale,RMaxUgStep,Rdx
  REAL(RKIND) :: RBCASTREAL,RStandardDeviation,RMean,RGzUnitVec,RMinLaueZoneValue,Rdf,RLastFit,RBestFit,&
       RMaxLaueZoneValue,RMaxAcceptanceGVecMag,RLaueZoneElectronWaveVectorMag,RvarMin,RfitMin,RFit0,Rconvex,Rtest
  REAL(RKIND),DIMENSION(:),ALLOCATABLE :: RSimplexFoM,RIndependentVariable,RCurrentVar,RVar0,RLastVar,RPvec,RFitVec
  REAL(RKIND),DIMENSION(ITHREE) :: R3var,R3fit
  REAL(RKIND),DIMENSION(:,:),ALLOCATABLE :: RSimplexVariable,RgDummyVecMat,RgPoolMagLaue,RTestImage,&
       ROnes,RVarMatrix,RSimp
  CHARACTER*40 :: my_rank_string
  CHARACTER*20 :: Snd,h,k,l
  CHARACTER*200 :: SPrintString

  !-------------------------------------------------------------------
  ! constants
  CALL Init_Numbers
  
  !-------------------------------------------------------------------
  ! set the error value to zero, will change upon error
  IErr=0
  IInitialSimulationFLAG = 1

  !--------------------------------------------------------------------
  ! MPI initialization
  CALL MPI_Init(IErr)  
  IF( IErr.NE.0 ) THEN
     PRINT*,"Felixrefine(", my_rank, ") error in MPI_Init()"
     GOTO 9999
  END IF

  ! Get the rank of the current process
  CALL MPI_Comm_rank(MPI_COMM_WORLD,my_rank,IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"Felixrefine(", my_rank, ") error in MPI_Comm_rank()"
     GOTO 9999
  END IF

  ! Get the size of the current communicator
  CALL MPI_Comm_size(MPI_COMM_WORLD,p,IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"Felixrefine(", my_rank, ") error in MPI_Comm_size()"
     GOTO 9999
  END IF

  !--------------------------------------------------------------------
  ! startup
  IF(my_rank.EQ.0) THEN
     PRINT*,"--------------------------------------------------------------"
     PRINT*,"felixrefine: ", RStr
     PRINT*,"             ", DStr
     PRINT*,"             ", AStr
     PRINT*,"    on rank= ", my_rank, " of ", p, " in total."
     PRINT*,"--------------------------------------------------------------"
  END IF

  !--------------------------------------------------------------------
  ! timing startup
  CALL SYSTEM_CLOCK(count_rate=IRate)
  CALL SYSTEM_CLOCK(IStarttime)

  !--------------------------------------------------------------------
  ! INPUT section 
  !felix.inp
  CALL ReadInpFile(IErr)
  IF( IErr.NE.0 ) THEN
    PRINT*,"felixrefine(",my_rank,")error reading felix.inp"
    GOTO 9999
  END IF
  !felix.cif
  CALL ReadCif(IErr)!branch in here depending on ISoftwareMode, needs to be taken out
  IF( IErr.NE.0 ) THEN
    PRINT*,"felixrefine(",my_rank,")error reading felix.cif"
    GOTO 9999
  END IF
  !felix.hkl
  CALL ReadHklFile(IErr)!the list of hkl's to input/output
  IF( IErr.NE.0 ) THEN
    PRINT*,"felixrefine(",my_rank,")error reading felix.hkl"
    GOTO 9999
  END IF
  
  IF (ISimFLAG.EQ.0) THEN!it's a refinement
    !read experimental images
    ALLOCATE(RImageExpi(2*IPixelCount,2*IPixelCount,INoOfLacbedPatterns),STAT=IErr)  
    IF( IErr.NE.0 ) THEN
      PRINT*,"felixrefine(",my_rank,")error allocating RImageExpi"
      GOTO 9999
    END IF
    CALL ReadExperimentalImages(IErr)
    IF( IErr.NE.0 ) THEN
      PRINT*,"felixrefine(",my_rank,") error in ReadExperimentalImages"
      GOTO 9999
    END IF
  ELSE IF(my_rank.EQ.0) THEN
    PRINT*,"Simulation only"
  END IF
  !--------------------------------------------------------------------
  ! Scattering factors
  CALL ScatteringFactors(IScatterFactorMethodFLAG,IErr)
  IF( IErr.NE.0 ) THEN
    PRINT*,"felixrefine(",my_rank,") error in ScatteringFactors"
    GOTO 9999
  END IF
  !Electron velocity in metres per second
  RElectronVelocity=RSpeedOfLight*SQRT(ONE-((RElectronMass*RSpeedOfLight**2)/ &
    (RElectronCharge*RAcceleratingVoltage*THOUSAND+RElectronMass*RSpeedOfLight**2) )**2 )
  !Electron wavelength in Angstroms
  RElectronWaveLength= RPlanckConstant / &
    ( SQRT(TWO*RElectronMass*RElectronCharge*RAcceleratingVoltage*THOUSAND) * &
      SQRT(ONE + (RElectronCharge*RAcceleratingVoltage*THOUSAND) / &
      (TWO*RElectronMass*RSpeedOfLight**2) ))* RAngstromConversion
  !(NB k=2pi/lambda and exp(i*k.r), physics convention)
  RElectronWaveVectorMagnitude=TWOPI/RElectronWaveLength
  RRelativisticCorrection= ONE/SQRT( ONE - (RElectronVelocity/RSpeedOfLight)**2 )
  RRelativisticMass= RRelativisticCorrection*RElectronMass
  !Reciprocal lattice
  CALL ReciprocalLattice(IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine(",my_rank,")error in ReciprocalLattice"
     GOTO 9999
  END IF

  !Total possible atoms/unit cell
  IMaxPossibleNAtomsUnitCell=SIZE(RBasisAtomPosition,1)*SIZE(RSymVec,1)
  !The following are over-allocated since the actual size is not known before the calculation of unique positions
  !AtomPosition is in fractional unit cell coordinates, like BasisAtomPosition
  ALLOCATE(RAtomPosition(IMaxPossibleNAtomsUnitCell,ITHREE),STAT=IErr)
  !AtomCoordinate is in the microscope reference frame in Angstrom units
  ALLOCATE(RAtomCoordinate(IMaxPossibleNAtomsUnitCell,ITHREE),STAT=IErr)
  ALLOCATE(SAtomLabel(IMaxPossibleNAtomsUnitCell),STAT=IErr)!Atom label
  ALLOCATE(SAtomName(IMaxPossibleNAtomsUnitCell),STAT=IErr)!Atom name
  ALLOCATE(RIsoDW(IMaxPossibleNAtomsUnitCell),STAT=IErr)!Isotropic Debye-Waller factor
  ALLOCATE(ROccupancy(IMaxPossibleNAtomsUnitCell),STAT=IErr)
  ALLOCATE(IAtomicNumber(IMaxPossibleNAtomsUnitCell),STAT=IErr)
  ALLOCATE(RAnisoDW(IMaxPossibleNAtomsUnitCell),STAT=IErr)  !Anisotropic Debye-Waller factor (why is it an integer????)
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine(",my_rank,")error in atom position allocations"
     GOTO 9999
  END IF
  CALL UniqueAtomPositions(IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine(",my_rank,")error in UniqueAtomPositions"
     GOTO 9999
  END IF
  !Perhaps should now re-allocate RAtomPosition,SAtomName,RIsoDW,ROccupancy,IAtomicNumber,RAnisoDW to match INAtomsUnitCell???

!-----------------------------------------
! set up reflection pool
  RHOLZAcceptanceAngle=TWODEG2RADIAN!RB seems way too low?
  IHKLMAXValue = 5!RB starting value, increments in loop below
! Count the reflections that make up the pool of g-vectors
!Note the application of acceptance angle is incorrect since it uses hkl;
!it should use the reciprocal lattice vectors as calculated in RgPool
  CALL HKLCount(IHKLMAXValue,RZDirC,INhkl,RHOLZAcceptanceAngle,IErr)
  DO WHILE (INhkl.LT.IMinReflectionPool) 
     IHKLMAXValue = IHKLMAXValue*2
     CALL HKLCount(IHKLMAXValue,RZDirC,INhkl,RHOLZAcceptanceAngle,IErr)
  END DO
  ! Fill the list of reflections Rhkl
  ! N.B. Rhkl are in integer form [h,k,l] but are REAL to allow dot products etc.
  ALLOCATE(Rhkl(INhkl,ITHREE),STAT=IErr)
  CALL HKLMake(IHKLMAXValue,RZDirC,RHOLZAcceptanceAngle,IErr)
  IF (my_rank.EQ.0.AND.IWriteFLAG.EQ.7) THEN
    DO ind=1,INhkl
     PRINT*,ind,":",NINT(Rhkl(ind,:))
    END DO
  END IF    
  
  ! sort them in descending order of magnitude
  ! may result in an error when the reflection pool does not reach the highest hkl of the experimental data? 
  CALL SortHKL(Rhkl,INhkl,IErr) 
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine(",my_rank,")error in SortHKL"
     GOTO 9999
  END IF

  !Assign numbers to the different reflections in IOutputReflections
  CALL SpecificReflectionDetermination (IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine(",my_rank,")error in SpecificReflectionDetermination"
     GOTO 9999
  END IF

  !RgPool is a list of 2pi*g-vectors in the microscope ref frame, units of 1/A (NB exp(-i*q.r),  physics negative convention)
  ALLOCATE(RgPool(INhkl,ITHREE),STAT=IErr)
  ALLOCATE(RgDummyVecMat(INhkl,ITHREE),STAT=IErr)
  IF(IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,")error allocating RgPool"
     GOTO 9999
  END IF
 
  !Calculate the g vector list RgPool in reciprocal angstrom units in the microscope reference frame
  ICutOff = 1
  DO ind=1,INhkl
    DO jnd=1,ITHREE
      RgPool(ind,jnd)= Rhkl(ind,1)*RarVecM(jnd) + &
        Rhkl(ind,2)*RbrVecM(jnd) + Rhkl(ind,3)*RcrVecM(jnd)
      !this is just a duplicate of RgPool, why?
      RgDummyVecMat(ind,jnd)=RgPool(ind,jnd)
     ENDDO
	 !If a g-vector has a non-zero z-component it is not in the ZOLZ
     IF(ABS(RgPool(ind,3)).GT.TINY.AND.ICutOff.NE.0) THEN
        RGzUnitVec=ABS(RgPool(ind,3))
        ICutOff=0
     END IF
  ENDDO
  !No higher order Laue Zones with ZOLZFlag switched on
  IF(ICutOff.EQ.1) THEN
     RGzUnitVec=ZERO
  END IF
  
  !sort into Laue Zones 
  WHERE(ABS(RgPool(:,3)).GT.TINY)
     RgDummyVecMat(:,3)=RgDummyVecMat(:,3)/RGzUnitVec!possible divide by zero from line 265?
  END WHERE
  !min&max Laue Zones 
  RMaxLaueZoneValue=MAXVAL(RgDummyVecMat(:,3),DIM=1)
  RMinLaueZoneValue=MINVAL(RgDummyVecMat(:,3),DIM=1)
  ITotalLaueZoneLevel=NINT(RMaxLaueZoneValue+ABS(RMinLaueZoneValue)+1,IKIND)
  !doing what, here? More sorting inlo Laue zones? 
  !deallocation
  DEALLOCATE(RgDummyVecMat)
  ALLOCATE(RgPoolMagLaue(INhkl,ITotalLaueZoneLevel),STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine(",my_rank,")error allocating RgPoolMagLaue"
     GOTO 9999
  END IF
  IF(RAcceptanceAngle.NE.ZERO.AND.IHOLZFLAG.EQ.1) THEN
    INumtotalReflections=0
    DO ind=1,ITotalLaueZoneLevel
      ILaueLevel=ind-IZerothLaueZoneLevel
      RLaueZoneGz=RGzUnitVec*ILaueLevel
      DO jnd=1,INhkl
        IF(RgPool(jnd,3).GE.(RLaueZoneGz-TINY).AND. &
             RgPool(jnd,3).LE.(RLaueZoneGz+TINY)) THEN
          RgPoolMagLaue(jnd,ind)=SQRT((RgPool(jnd,1)**2)+(RgPool(jnd,2)**2))              
        ELSE
          RgPoolMagLaue(jnd,ind)=NEGHUGE
        END IF
      END DO
      INumInitReflections=COUNT(RgPoolMagLaue(:,ind).NE.NEGHUGE)
      RLaueZoneElectronWaveVectorMag=RElectronWaveVectorMagnitude-ABS(RLaueZoneGz)           
      RMaxAcceptanceGVecMag=(RLaueZoneElectronWaveVectorMag*TAN(RAcceptanceAngle*DEG2RADIAN))
      WHERE(ABS(RgPoolMagLaue(:,ind)).GT.RMaxAcceptanceGVecMag)
        RgPoolMagLaue(:,ind)=NEGHUGE
      END WHERE
      INumFinalReflections=COUNT(RgPoolMagLaue(:,ind).NE.NEGHUGE)
      INumTotalReflections=INumTotalReflections+INumInitReflections
    END DO
    knd=0
    DO ind=1,INhkl
      IF(SUM(RgPoolMagLaue(ind,:))/REAL(ITotalLaueZoneLevel,RKIND).GT.NEGHUGE) THEN
        knd=knd+1
      END IF
    END DO
    IHOLZgPoolMag=knd
    ALLOCATE(IOriginGVecIdentifier(IHOLZgPoolMag),STAT=IErr)
    IF( IErr.NE.0 ) THEN
      PRINT*,"felixrefine(",my_rank,")error allocating IOriginGVecIdentifier"
      GOTO 9999
    END IF
    IOriginGVecIdentifier=0
    knd=1
    DO ind=1,INhkl
      IF((SUM(RgPoolMagLaue(ind,:))/REAL(ITotalLaueZoneLevel,RKIND)).GT.NEGHUGE) THEN
        IOriginGVecIdentifier(knd)=ind
        knd=knd+1
      END IF
    END DO
  END IF

  !calculate 2pi*g vector magnitudes for the reflection pool RgPoolMag
  !in reciprocal Angstrom units, in the Microscope reference frame
  ALLOCATE(RgPoolMag(INhkl),STAT=IErr)
  IF(IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,")error allocating RgPoolMag"
     GOTO 9999
  END IF
  DO ind=1,INhkl
     RgPoolMag(ind)= SQRT(DOT_PRODUCT(RgPool(ind,:),RgPool(ind,:)))
  END DO
  IF(IWriteFLAG.EQ.7.AND.my_rank.EQ.0) THEN
    DO ind =1,INhkl
	 WRITE(SPrintString,FMT='(I4,A4,3(I4,1X),A12,F7.4,A4)') ind,": g=",NINT(Rhkl(ind,:)),", magnitude ",RgPoolMag(ind)," 1/A"
     PRINT*,TRIM(ADJUSTL(SPrintString))
    END DO
  END IF

  !g-vector components parallel to the surface unit normal
  ALLOCATE(RgDotNorm(INhkl),STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine(",my_rank,") error allocating RgDotNorm"
     GOTO 9999
  END IF
  DO ind =1,INhkl
    RgDotNorm(ind) = DOT_PRODUCT(RgPool(ind,:),RNormDirM)
  END DO
  IF(IWriteFLAG.EQ.7) THEN
    DO ind =1,INhkl
	 WRITE(SPrintString,FMT='(I4,A4,3(I4,1X),A7,E8.1,A4)') ind,": g=",NINT(Rhkl(ind,:)),", g.n= ",RgDotNorm(ind)," 1/A"
     IF (my_rank.EQ.0) PRINT*,TRIM(ADJUSTL(SPrintString))
    END DO
  END IF
  RMinimumGMag = RgPoolMag(2)

!-----------------------------------------
  ! resolution in k space
  RDeltaK = RMinimumGMag*RConvergenceAngle/REAL(IPixelCount,RKIND)
  !acceptance angle
  IF(RAcceptanceAngle.NE.ZERO.AND.IHOLZFLAG.EQ.0) THEN
     RMaxAcceptanceGVecMag=(RElectronWaveVectorMagnitude*TAN(RAcceptanceAngle*DEG2RADIAN))
     IF(RgPoolMag(IMinReflectionPool).GT.RMaxAcceptanceGVecMag) THEN
        RMaxGMag = RMaxAcceptanceGVecMag 
     ELSE
        RMaxGMag = RgPoolMag(IMinReflectionPool)
     END IF
  ELSEIF(RAcceptanceAngle.NE.ZERO.AND.IHOLZFLAG.EQ.1) THEN
     IBSMaxLocGVecAmp=MAXVAL(IOriginGVecIdentifier)
     RMaxGMag=RgPoolMag(IBSMaxLocGVecAmp)
     IF(RgPoolMag(IBSMaxLocGVecAmp).LT.RgPoolMag(IMinreflectionPool)) THEN

     ELSE
        RMaxGMag = RgPoolMag(IMinReflectionPool)
     END IF
  ELSE
     RMaxGMag = RgPoolMag(IMinReflectionPool)
  END IF
  
  !count reflections up to cutoff magnitude
  nReflections=0_IKIND
  DO ind=1,INhkl
    IF (ABS(RgPoolMag(ind)).LE.RMaxGMag) nReflections=nReflections+1
  ENDDO
  IF (nReflections.LT.INoOfLacbedPatterns) nReflections = INoOfLacbedPatterns
  
  !deallocation
  DEALLOCATE(RgPoolMagLaue)!
  IF (RAcceptanceAngle.NE.ZERO.AND.IHOLZFLAG.EQ.1) THEN
    DEALLOCATE(IOriginGVecIdentifier)
  END IF

  !Calculate Ug matrix etc.--------------------------------------------------------
  ALLOCATE(CUgMatNoAbs(nReflections,nReflections),STAT=IErr)  !RB Ug Matrix without absorption
  ALLOCATE(CUgMatPrime(nReflections,nReflections),STAT=IErr)  !RB U'g Matrix of just absorption  
  ALLOCATE(CUgMat(nReflections,nReflections),STAT=IErr)  !RB Ug+U'g Matrix, including absorption
  ALLOCATE(RgMatrix(nReflections,nReflections,ITHREE),STAT=IErr)  !Matrix of 2pi*g-vectors that corresponds to the CUgMatNoAbs matrix
  ALLOCATE(RgMatrixMagnitude(nReflections,nReflections),STAT=IErr)  !Matrix of their magnitudes
  ALLOCATE(RgSumMat(nReflections,nReflections),STAT=IErr)  !Matrix of sums of indices - for symmetry equivalence  in the Ug matrix
  ALLOCATE(ISymmetryRelations(nReflections,nReflections),STAT=IErr)!Matrix with numbers marking equivalent Ug's
  IF (IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,") error allocating CUgMat or its components"
     GOTO 9999
  END IF
  
  !--------------------------------------------------------------------
  ! Calculate Reflection Matrix
  IThicknessCount= (RFinalThickness-RInitialThickness)/RDeltaThickness + 1
  DO ind=1,nReflections
     DO jnd=1,nReflections
        RgMatrix(ind,jnd,:)= RgPool(ind,:)-RgPool(jnd,:)
        RgMatrixMagnitude(ind,jnd)= SQRT(DOT_PRODUCT(RgMatrix(ind,jnd,:),RgMatrix(ind,jnd,:)))
     ENDDO
  ENDDO
  IF(IWriteFLAG.EQ.3.AND.my_rank.EQ.0) THEN
	PRINT*,"g-vector magnitude matrix (2pi/A)"
	DO ind =1,16
     WRITE(SPrintString,FMT='(16(1X,F5.2))') RgMatrixMagnitude(ind,1:8)
     PRINT*,TRIM(ADJUSTL(SPrintString))
    END DO
	PRINT*,"first column of g-vectors"
	DO ind =1,16
     WRITE(SPrintString,FMT='(3(1X,F5.2))') RgMatrix(ind,1,:)
     PRINT*,TRIM(ADJUSTL(SPrintString))
    END DO
  END IF
  !Calculate Ug matrix for each individual enry in CUgMatNoAbs(1:nReflections,1:nReflections)
  CALL StructureFactorInitialisation (IErr)!NB IEquivalentUgKey and CUniqueUg allocated in here
  IF(IWriteFLAG.EQ.3.AND.my_rank.EQ.0) PRINT*,"Starting absorption calculation",SIZE(IEquivalentUgKey),"beams"
  CALL Absorption (IErr)
  IF( IErr.NE.0) THEN
     PRINT*,"StructureFactorSetup(",my_rank,")error in StructureFactorInitialisation"
     GOTO 9999
  END IF
  CALL SYSTEM_CLOCK(ICurrentTime)
  Duration=REAL(ICurrentTime-IStartTime)/REAL(IRate)
  IHours = FLOOR(Duration/3600.0D0)
  IMinutes = FLOOR(MOD(Duration,3600.0D0)/60.0D0)
  ISeconds = INT(MOD(Duration,3600.0D0)-IMinutes*60)
  WRITE(SPrintString,FMT='(A24,I3,A5,I2,A6,I2,A4)')&
    "Absorption completed in ",IHours," hrs ",IMinutes," mins ",ISeconds," sec"
  IF(my_rank.EQ.0) PRINT*,TRIM(ADJUSTL(SPrintString))

  !--------------------------------------------------------------------
  ! Set up Ug refinement variables
  !--------------------------------------------------------------------
  IF(IRefineMode(1).EQ.1) THEN !It's a Ug refinement, A
	IUgOffset=1!choose how many Ug's to skip in the refinement, 1 is the inner potential...
    !Count the number of Independent Variables
    jnd=1
    DO ind = 1+IUgOffset,INoofUgs+IUgOffset !=== comment out !=== for real part only***
      IF ( ABS(REAL(CUniqueUg(ind),RKIND)).GE.RTolerance ) jnd=jnd+1!===
      IF ( ABS(AIMAG(CUniqueUg(ind))).GE.RTolerance ) jnd=jnd+1!===
    END DO
    IF (IAbsorbFLAG.EQ.1) THEN!proportional absorption
      INoOfVariables = jnd!the last variable is for absorption
	ELSE
      INoOfVariables = jnd-1
    END IF
    
    IF(my_rank.EQ.0) THEN
      IF ( INoOfVariables.EQ.1 ) THEN 
        PRINT*,"Only one independent variable"
	  ELSE
        WRITE(SPrintString,FMT='(I3,1X,A21)') INoOfVariables,"independent variables"
        PRINT*,TRIM(ADJUSTL(SPrintString))
      END IF
    END IF
	
    ALLOCATE(RIndependentVariable(INoOfVariables),STAT=IErr)  
    IF( IErr.NE.0 ) THEN
      PRINT*,"felixrefine(",my_rank,")error allocating RIndependentVariable"
      GOTO 9999
    END IF
    !Fill up the IndependentVariable list with CUgMatNoAbs components
    jnd=1
    DO ind = 1+IUgOffset,INoofUgs+IUgOffset !comment out !=== for real part only***
      IF ( ABS(REAL(CUniqueUg(ind),RKIND)).GE.RTolerance ) THEN
        RIndependentVariable(jnd) = REAL(CUniqueUg(ind),RKIND)
        jnd=jnd+1
	  END IF
      IF ( ABS(AIMAG(CUniqueUg(ind))).GE.RTolerance ) THEN!===
        RIndependentVariable(jnd) = AIMAG(CUniqueUg(ind))!===
        jnd=jnd+1!===
      END IF!===
    END DO
	IF (IAbsorbFLAG.EQ.1) RIndependentVariable(jnd) = RAbsorptionPercentage!Proportional absorption included in structure factor refinement as last variable

  END IF
 
  !--------------------------------------------------------------------
  ! Set up other variables
  !--------------------------------------------------------------------
  IF(IRefineMode(2).EQ.1) THEN !It's an atom coordinate refinement, B
    CALL SetupAtomicVectorMovements(IErr)
    IF(IErr.NE.0) THEN
      PRINT*,"felixrefine(",my_rank,")error in SetupAtomicVectorMovements"
      GOTO 9999
    END IF
  END IF
  IF(IRefineMode(1).EQ.0) THEN !It's not a Ug refinement, so we need to count variables
    INoofElementsForEachRefinementType(2)=IRefineMode(2)*IAllowedVectors!Atomic coordinates, B
    INoofElementsForEachRefinementType(3)=IRefineMode(3)*SIZE(IAtomicSitesToRefine)!Occupancy, C
    INoofElementsForEachRefinementType(4)=IRefineMode(4)*SIZE(IAtomicSitesToRefine)!Isotropic DW, D
    INoofElementsForEachRefinementType(5)=IRefineMode(5)*SIZE(IAtomicSitesToRefine)*6!Anisotropic DW, E
    INoofElementsForEachRefinementType(6)=IRefineMode(6)*3!Unit cell dimensions, F
    INoofElementsForEachRefinementType(7)=IRefineMode(7)*3!Unit cell angles, G
    INoofElementsForEachRefinementType(8)=IRefineMode(8)!Convergence angle, H
    INoofElementsForEachRefinementType(9)=IRefineMode(9)!Percentage Absorption, I
    INoofElementsForEachRefinementType(10)=IRefineMode(10)!kV, J
    !Number of independent variables
    INoOfVariables = SUM(INoofElementsForEachRefinementType)
    IF(INoOfVariables.EQ.0) THEN !there's no refinement requested, say so and quit (could be done when reading felix.inp)
      IF (my_rank.EQ.0) PRINT*,"No refinement variables! Check IRefineModeFLAG in felix.inp"
      IF (my_rank.EQ.0) PRINT*,"Valid refine modes are A,B,C,D,E,F,G,H,I,J,S"
      GOTO 9999
    END IF
    !--------------------------------------------------------------------
    ALLOCATE(RIndependentVariable(INoOfVariables),STAT=IErr)
	!Fill up the IndependentVariable list 
    ind=1
    IF(IRefineMode(3).EQ.1) THEN!Occupancy, C
	  DO jnd=1,SIZE(IAtomicSitesToRefine)
        RIndependentVariable(ind)=RBasisOccupancy(IAtomicSitesToRefine(jnd))
        ind=ind+1
	  END DO
	END IF
    IF(IRefineMode(4).EQ.1) THEN!Isotropic DW, D
	  DO jnd=1,SIZE(IAtomicSitesToRefine)
        RIndependentVariable(ind)=RIsoDW(IAtomicSitesToRefine(jnd))
        ind=ind+1
	  END DO
	END IF
    IF(IRefineMode(8).EQ.1) THEN!Convergence angle, H
      RIndependentVariable(ind)=RConvergenceAngle
      ind=ind+1
	END IF
    !Assign IDs - not needed for a Ug refinement
    ALLOCATE(IIterativeVariableUniqueIDs(INoOfVariables,5),STAT=IErr)
    IF( IErr.NE.0 ) THEN
      PRINT*,"felixrefine(",my_rank,")error allocating IIterativeVariableUniqueIDs"
      GOTO 9999
    END IF
    IIterativeVariableUniqueIDs = 0
    knd = 0
    DO ind = 2,IRefinementVariableTypes !Loop over iterative variables apart from Ug's
      IF(IRefineMode(ind).EQ.1) THEN
        DO jnd = 1,INoofElementsForEachRefinementType(ind)
          knd = knd + 1
          IIterativeVariableUniqueIDs(knd,1) = knd!elements (:,1) just have the number of the index in, pointless and never used
          CALL AssignArrayLocationsToIterationVariables(ind,jnd,IIterativeVariableUniqueIDs,IErr)
        END DO
      END IF
    END DO 
  END IF

  !--------------------------------------------------------------------
  ! Set up images for output
  ALLOCATE(RhklPositions(nReflections,2),STAT=IErr)
  IF( IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,") error allocating RhklPositions"
     GOTO 9999
  END IF
  CALL ImageSetup(IErr)!what does this do?
  IF( IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,") error in ImageSetup"
     GOTO 9999
  END IF 
  !All the individual calculations go into RSimulatedPatterns later with MPI_GATHERV
  !(Note that RSimulatedPatterns is a vector with respect to pixels, not a 2D image)
  ALLOCATE(RSimulatedPatterns(INoOfLacbedPatterns,IThicknessCount,IPixelTotal),STAT=IErr)
  !Images to match RImageExpi (NB there are other variables called RImageSim, be careful!)
  ALLOCATE(RImageSimi(2*IPixelCount,2*IPixelCount,INoOfLacbedPatterns,IThicknessCount),STAT=IErr)
  IF (ICorrelationFLAG.EQ.3) THEN!allocate images for the mask
    !Baseline Images to calculate mask
    ALLOCATE(RImageBase(2*IPixelCount,2*IPixelCount,INoOfLacbedPatterns,IThicknessCount),STAT=IErr)
    !Average Images to calculate mask
    ALLOCATE(RImageAvi(2*IPixelCount,2*IPixelCount,INoOfLacbedPatterns,IThicknessCount),STAT=IErr)
    RImageAvi=ZERO
    !Mask Images
    ALLOCATE(RImageMask(2*IPixelCount,2*IPixelCount,INoOfLacbedPatterns),STAT=IErr)
  END IF
  IF( IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,") error allocating simulated patterns"
     GOTO 9999
  END IF
  RSimulatedPatterns = ZERO
  !The pixels to be calculated by this core  
  ILocalPixelCountMin= (IPixelTotal*(my_rank)/p)+1
  ILocalPixelCountMax= (IPixelTotal*(my_rank+1)/p) 
  ALLOCATE(RIndividualReflections(INoOfLacbedPatterns,IThicknessCount,&
         (ILocalPixelCountMax-ILocalPixelCountMin)+1),STAT=IErr)
  !position of pixels calculated by this core, IDisplacements and ICount are global variables
  ALLOCATE(IDisplacements(p),ICount(p),STAT=IErr)
  IF( IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,")error in local allocations for MPI"
     GOTO 9999
  END IF
  DO ind = 1,p
     IDisplacements(ind) = (IPixelTotal*(ind-1)/p)*INoOfLacbedPatterns*IThicknessCount
     ICount(ind) = (((IPixelTotal*(ind)/p) - (IPixelTotal*(ind-1)/p)))*INoOfLacbedPatterns*IThicknessCount    
  END DO

  !--------------------------------------------------------------------
  ! Weighting parameter
  ALLOCATE(RWeightingCoefficients(INoOfLacbedPatterns),STAT=IErr) 
  SELECT CASE (IWeightingFLAG)
  CASE(0)!uniform weighting
     RWeightingCoefficients = ONE
  CASE(1)!smaller g's more important
     DO ind = 1,INoOfLacbedPatterns!NB untested, does RgPoolMag(ind)match output reflection (ind)???
        RWeightingCoefficients(ind) = RgPoolMag(ind)/MAXVAL(RgPoolMag)
     END DO
  CASE(2)!larger g's more important
     DO ind = 1,INoOfLacbedPatterns
        RWeightingCoefficients(ind) = MAXVAL(RgPoolMag)/RgPoolMag(ind)
     END DO
  END SELECT

  !--------------------------------------------------------------------
  ! Allocate memory for deviation parameter and bloch calc here in main loop
  ALLOCATE(RDevPara(nReflections),STAT=IErr)
  ALLOCATE(IStrongBeamList(nReflections),STAT=IErr)
  ALLOCATE(IWeakBeamList(nReflections),STAT=IErr)
  ALLOCATE(CFullWaveFunctions(nReflections),STAT=IErr)
  ALLOCATE(RFullWaveIntensity(nReflections),STAT=IErr)
  IF (IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,") error in allocations for Bloch calculation"
     GOTO 9999
  END IF
  !--------------------------------------------------------------------
  !baseline simulation
  RFigureofMerit=666.666!Inital large value,diabolically
  Iter = 0
  CALL FelixFunction(IErr) ! Simulate !! 
  IF (IErr.NE.0) THEN
     PRINT*,"felixrefine(",my_rank,")error",IErr,"in FelixFunction"
     GOTO 9999
  END IF

  !--------------------------------------------------------------------
  !timing
  CALL SYSTEM_CLOCK(ICurrentTime)
  Duration=REAL(ICurrentTime-IStartTime)/REAL(IRate)
  IHours = FLOOR(Duration/3600.0D0)
  IMinutes = FLOOR(MOD(Duration,3600.0D0)/60.0D0)
  ISeconds = INT(MOD(Duration,3600.0D0)-IMinutes*60)
  IF (my_rank.EQ.0) THEN
    WRITE(SPrintString,FMT='(A24,I3,A5,I2,A6,I2,A4)')&
    "Simulation completed in ",IHours," hrs ",IMinutes," mins ",ISeconds," sec"
    PRINT*,TRIM(ADJUSTL(SPrintString))
  END IF

  !--------------------------------------------------------------------
  !Baseline output, core 0 only
  IExitFLAG = 0 !Do not exit
  IPreviousPrintedIteration = 0!RB ensuring baseline simulation is printed
  IF (ISimFLAG.EQ.1) THEN !Sim mode - All Thicknesses Output     
    IF(my_rank.EQ.0) THEN
      WRITE(SPrintString,FMT='(A24,I3,A12)')&
           "Writing simulations for ", IThicknessCount," thicknesses"
      PRINT*,TRIM(ADJUSTL(SPrintString))
      DO IThicknessIndex = 1,IThicknessCount
        CALL WriteIterationOutput(Iter,IThicknessIndex,IExitFLAG,IErr)
        IF( IErr.NE.0 ) THEN
          PRINT*,"felixrefine(0) error in WriteIterationOutput"
          GOTO 9999
        END IF
      END DO
    END IF
    !felixsim program skips to end
    GOTO 8888    
  ELSE!Refine Mode, only one thickness output 
    IF(my_rank.EQ.0) THEN
      !Figure of merit is passed back as a global variable
      CALL CalculateFigureofMeritandDetermineThickness(Iter,IThicknessIndex,IErr)
      IF( IErr.NE.0 ) THEN
        PRINT*,"felixrefine(0) error",IErr,"in CalculateFigureofMeritandDetermineThickness"
        GOTO 9999
      END IF
      !Keep baseline simulation for masked correlation
      IF (ICorrelationFLAG.EQ.3) THEN
        RImageBase=RImageSimi  
        RImageAvi=RImageSimi 
      END IF        
      CALL WriteIterationOutput(Iter,IThicknessIndex,IExitFLAG,IErr)
      IF( IErr.NE.0 ) THEN
        PRINT*,"Error in WriteIterationOutput"
        GOTO 9999
      END IF
    END IF
    !=====================================!Send the fit index to all cores
    CALL MPI_BCAST(RFigureofMerit,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,IErr)
    !=====================================
  END IF
  
  !--------------------------------------------------------------------
  !Branch depending upon refinement method
  !We have INoOfVariables to refine, held in RIndependentVariable(1:INoOfVariables)
  !For single variables, their type is held in IIterativeVariableUniqueIDs(1:INoOfVariables,2)
  SELECT CASE(IMethodFLAG)
  CASE(1)!Simplex
    ALLOCATE(RSimplexVariable(INoOfVariables+1,INoOfVariables), STAT=IErr)  
    ALLOCATE(RSimplexFoM(INoOfVariables+1),STAT=IErr)  
    IF(my_rank.EQ.0) THEN!NB Since simplex is not random, could be calculated by all cores
	  ALLOCATE(ROnes(INoOfVariables+1,INoOfVariables), STAT=IErr)!matrix of ones
	  ALLOCATE(RSimp(INoOfVariables+1,INoOfVariables), STAT=IErr)!matrix of one +/-RSimplexLengthScale
	  ALLOCATE(RVarMatrix(INoOfVariables,INoOfVariables), STAT=IErr)!diagonal matrix of variables as rows
      IF( IErr.NE.0 ) THEN
        PRINT*,"felixrefine(",my_rank,")error allocating simplex variables"
        GOTO 9999
      END IF
	  ROnes=ONE
	  RSimp=ONE
	  RVarMatrix=ZERO
	  FORALL(ind = 1:INoOfVariables) RSimp(ind,ind) = -1.0
	  RSimp=RSimp*RSimplexLengthScale + ROnes
	  FORALL(ind = 1:INoOfVariables) RVarMatrix(ind,ind) = RIndependentVariable(ind)
	  RSimplexVariable=MATMUL(RSimp,RVarMatrix)
    END IF
    !=====================================send RSimplexVariable out to all cores
    CALL MPI_BCAST(RSimplexVariable,(INoOfVariables+1)*(INoOfVariables),MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,IErr)
    !=====================================
    ! Perform initial simplex simulations
    DO ind = 1,(INoOfVariables+1)
      IF(my_rank.EQ.0) THEN
        PRINT*,"--------------------------------"
        WRITE(SPrintString,FMT='(A8,I2,A4,I3)') "Simplex ",ind," of ",INoOfVariables+1
        PRINT*,TRIM(ADJUSTL(SPrintString))
        PRINT*,"--------------------------------"
      END IF
      CALL SimulateAndFit(RSimplexVariable(ind,:),Iter,0,IErr)!Working as iteration 0
      IF( IErr.NE.0 ) THEN
        PRINT*,"SimplexInitialisation(",my_rank,") error in SimulateAndFit"
        GOTO 9999
      END IF
      RSimplexFoM(ind)=RFigureofMerit!RFigureofMerit is returned as a global variable
      !For masked correlation, add to 'average' (extreme difference from baseline)
      IF(my_rank.EQ.0.AND.ICorrelationFLAG.EQ.3) THEN!NB will need to be moved.redone for parabolic
        WHERE (ABS(RImageSimi-RImageBase).GT.ABS(RImageAvi-RImageBase))!replace pixels that are the most different from baseline
          RImageAvi=RImageSimi
        END WHERE
      END IF
    END DO
   !--------------------------------------------------------------------
   !set up masked fitting using the simplex setup
   IF (my_rank.EQ.0.AND.ICorrelationFLAG.EQ.3) THEN
      !Simple start, just take thickness 1 
      RImageMask=RImageAvi(:,:,:,1)-RImageBase(:,:,:,1)
      DO ind = 1,INoOfLacbedPatterns!mask each pattern individually
        !***top 90% threshold (to start with, may change or become user defined?)
        WHERE (ABS(RImageMask(:,:,ind)).GT.0.1*MAXVAL(ABS(RImageMask(:,:,ind))))
          RImageMask(:,:,ind)=ONE
        ELSEWHERE
          RImageMask(:,:,ind)=ZERO
        END WHERE
      END DO
    
      !flagged output to have a look at the masks
      IF (IWriteFLAG.EQ.6) THEN
        ALLOCATE(RTestImage(2*IPixelCount,2*IPixelCount),STAT=IErr)
        DO ind = 1,INoOfLacbedPatterns
          RTestImage=RImageMask(:,:,ind)
          WRITE(h,*)  NINT(Rhkl(IOutPutReflections(ind),1))
          WRITE(k,*)  NINT(Rhkl(IOutPutReflections(ind),2))
          WRITE(l,*)  NINT(Rhkl(IOutPutReflections(ind),3))
          WRITE(SPrintString,*) TRIM(ADJUSTL(h)),TRIM(ADJUSTL(k)),TRIM(ADJUSTL(l)),".mask"
          OPEN(UNIT=IChOutWIImage, ERR=10, STATUS= 'UNKNOWN', FILE=SPrintString,&!
          FORM='UNFORMATTED',ACCESS='DIRECT',IOSTAT=IErr,RECL=2*IPixelCount*8)!??Does the 8=IByteSize???
          DO jnd = 1,2*IPixelCount
            WRITE(IChOutWIImage,rec=jnd) RTestImage(jnd,:)
          END DO
          CLOSE(IChOutWIImage,IOSTAT=IErr)
        END DO
        DEALLOCATE(RTestImage)
      END IF
    END IF
    !--------------------------------------------------------------------    
    ! Apply Simplex Method and iterate
    Iter = 1  
    CALL NDimensionalDownhillSimplex(RSimplexVariable,RSimplexFoM,&
       INoOfVariables+1,INoOfVariables,INoOfVariables,&
       RExitCriteria,Iter,RStandardDeviation,RMean,IErr)
    IF( IErr.NE.0 ) THEN
      PRINT*,"felixrefine(",my_rank,")error in NDimensionalDownhillSimplex"
      GOTO 9999
    END IF
  
  CASE(2)!Maximum gradient
    ALLOCATE(RVar0(INoOfVariables),STAT=IErr)!incoming set of variables
    ALLOCATE(RCurrentVar(INoOfVariables),STAT=IErr)!set of variables to send out for simulations
    ALLOCATE(RLastVar(INoOfVariables),STAT=IErr)!set of variables updated each cycle
    ALLOCATE(RPVec(INoOfVariables),STAT=IErr)!the vector describing the current line in parameter space
    ALLOCATE(RFitVec(INoOfVariables),STAT=IErr)!the list of fit indices resulting from small changes Rdf for each variable in RPVec
    IF( IErr.NE.0 ) THEN
      PRINT*,"felixrefine(",my_rank,")error allocating max gradient variables"
      GOTO 9999
    END IF
    RBestFit=RFigureofMerit
    RLastFit=RBestFit
    RLastVar=RIndependentVariable
    RCurrentVar=ONE
    Rdf=ONE
    Iter=1
    RScale=RSimplexLengthScale
    nnd=0!max/min gradient flag
    DO WHILE (Rdf.GE.RExitCriteria)
      RVar0=RIndependentVariable!incoming point in n-dimensional parameter space
      RFit0=RFigureofMerit!incoming fit
      IF (nnd.EQ.0) THEN!max gradient
        DO ind=1,INoOfVariables!calculate individual gradients
          IVariableType=IIterativeVariableUniqueIDs(ind,2)!The type of variable being refined 
          IF (my_rank.EQ.0) THEN!print to screen
           SELECT CASE(IVariableType)
            CASE(1)
              PRINT*,"Ug refinement"
            CASE(2)
              PRINT*,"Atomic coordinate refinement"
            CASE(3)
              PRINT*,"Occupancy refinement"
            CASE(4)
              PRINT*,"Isotropic Debye-Waller factor refinement"
            CASE(5)
              PRINT*,"Convergence angle refinement"
           END SELECT
          END IF
          IF (RCurrentVar(ind).LE.TINY.AND.IVariableType.EQ.4) THEN!skip zero DW factor
            RPVec(ind)=TINY
            CYCLE
          END IF
          WRITE(SPrintString,FMT='(A17,I2,A3,I3)') "Finding gradient,",ind," of",INoOfVariables
          IF (my_rank.EQ.0) PRINT*, TRIM(ADJUSTL(SPrintString))
          CALL SYSTEM_CLOCK(mnd)!Use system clock to make a random number and vary the sign of dx
          Rdx=(REAL(MOD(mnd,10))/TEN)-0.45!numbers 0-4 give minus, 5-9 give plus
          Rdx=0.1*Rdx*RScale/ABS(Rdx)!small change in current variable (RScale/10)is dx
          RCurrentVar=RVar0
          RCurrentVar(ind)=RCurrentVar(ind)+Rdx
          CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
          !BestFitCheck copies RCurrentVar into RIndependentVariable and updates RBestFit if the fit is better
          CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
          RFitVec(ind)=RFigureofMerit
          RPVec(ind)=(RFit0-RFigureofMerit)/Rdx!-df/dx: need the dx to keep track of sign
        END DO
        nnd=1!do min gradient next time
      ELSE!min gradient - to explore along a valley
        DO ind=1,INoOfVariables!invert gradient
          IF (ABS(RPVec(ind)).GT.TINY) THEN!don't invert zeros
            RPVec(ind)=1/RPVec(ind)
          ELSE!just make them quite big
            RPVec(ind)=TEN
          END IF
        END DO
        IF (my_rank.EQ.0) PRINT*, "Checking minimum gradient"
        nnd=0!do max gradient next time
      END IF
      RPvecMag=ZERO!RPvecMag is used here to normalise the max gradient vector RPvec
      DO ind=1,INoOfVariables
        RPvecMag=RPvecMag+RPvec(ind)**2
      END DO
      IF (RPvecMag-ONE.EQ.RPvecMag.OR.RPvecMag.NE.RPvecMag) THEN!Infinity and NaN check
        WRITE(SPrintString,FMT='(A27,20(F6.3,1X))') "Error in refinement vector ",RPvec
        IF (my_rank.EQ.0) PRINT*, TRIM(ADJUSTL(SPrintString))
        EXIT
      END IF
      RPvec=RPvec/SQRT(RPvecMag)!unity vector along direction of max gradient
      WRITE(SPrintString,FMT='(A20,20(F6.3,1X))') "Refinement vector = ",RPvec
      IF (my_rank.EQ.0) PRINT*, TRIM(ADJUSTL(SPrintString))
      RVar0=RIndependentVariable!the best point of gradient calculation
      RFigureofMerit=RBestFit!the best fit so far
      !three points to find the miniimum
      R3var(1)=RVar0(1)!first point is current value
      R3fit(1)=RFigureofMerit!point 1 is the incoming simulation and fit index
      RPvecMag=RVar0(1)*RScale!RPvecMag is used here to give the magnitude of vector in parameter space 
      RCurrentVar=RVar0+RPvec*RPvecMag!Update the parameters to simulate
      R3var(2)=RCurrentVar(1)!second point 
      IF (my_rank.EQ.0) PRINT*,"Refining, point 2 of 3"
      CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
      CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
      R3fit(2)=RFigureofMerit
      !third point
      IF (R3fit(2).GT.R3fit(1)) THEN!new 2 is not better than 1, go the other way
        RPvecMag=-RPvecMag
      ELSE!it is better, so keep going
        RVar0=RCurrentVar
      END IF
      RCurrentVar=RVar0+RPvec*RPvecMag
      R3var(3)=RCurrentVar(1)!third point
      IF (my_rank.EQ.0) PRINT*,"Refining, point 3 of 3"
      CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
      CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
      R3fit(3)=RFigureofMerit
      !check the three points make a concave set
      jnd=MAXLOC(R3var,1)!highest x
      knd=MINLOC(R3var,1)!lowest x
      lnd=6-jnd-knd!the mid x
      Rtest=-ABS(R3fit(jnd)-R3fit(knd))!Rtest=0.0 would be a straight line, >0=convex, <0=concave
      !Rconvex is the calculated fit index at the mid x, if ithere was a straight line between lowest and highest x
      Rconvex=R3fit(lnd)-(R3fit(knd)+(R3var(lnd)-R3var(knd))*(R3fit(jnd)-R3fit(knd))/(R3var(jnd)-R3var(knd)))
      DO WHILE (Rconvex.GT.0.1*Rtest)!if it isn't more than 10% concave, keep going until it is sufficiently concave
        IF(my_rank.EQ.0) PRINT*,"Convex, continuing"
        jnd=MAXLOC(R3fit,1)!worst fit
        knd=MINLOC(R3fit,1)!best fit
        lnd=6-jnd-knd!the mid fit
        !replace mid point with a step on from best point
        !RPvecMag=(R3var(knd)-RVar0(1))*(0.5+SQRT(5.0)/2.0)/RPvec(1)!increase the step size by the golden ratio
        RPvecMag=TWO*RPvecMag!double the step size
        IF (ABS(RPvecMag).GT.RMaxUgStep.AND.IRefineMode(1).EQ.1) RPvecMag=SIGN(RMaxUgStep,RPvecMag)!maximum step in Ug is RMaxUgStep
        RCurrentVar=RVar0+RPvec*RPvecMag
        R3var(lnd)=RCurrentVar(1)!next point
        CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
        CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
        R3fit(lnd)=RFigureofMerit
        jnd=MAXLOC(R3var,1)!highest x
        knd=MINLOC(R3var,1)!lowest x
        lnd=6-jnd-knd!the mid x
        Rconvex=R3fit(lnd)-(R3fit(knd)+(R3var(lnd)-R3var(knd))*(R3fit(jnd)-R3fit(knd))/(R3var(jnd)-R3var(knd)))
        Rtest=-ABS(R3fit(jnd)-R3fit(knd))
      END DO
      !now make a prediction
      CALL Parabo3(R3var,R3fit,RvarMin,RfitMin,IErr)
      IF (my_rank.EQ.0) THEN
        WRITE(SPrintString,FMT='(A32,F7.4,A16,F6.4)') &
           "Concave set, predict minimum at ",RvarMin," with fit index ",RfitMin
        PRINT*,TRIM(ADJUSTL(SPrintString))
      END IF
      RCurrentVar=RVar0+RPvec*(RvarMin-RVar0(1))/RPvec(1)!Put prediction into RCurrentVar
      CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
      CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
      !check where we go next and update last fit etc.
      IF (nnd.EQ.0) THEN!only update LastFit after a max gradient refinement
        Rdf=RLastFit-RBestFit 
        RLastFit=RBestFit
        IF(my_rank.EQ.0) THEN
          PRINT*,"--------------------------------"
          WRITE(SPrintString,FMT='(A19,F8.6,A15,F8.6)') "Improvement in fit ",Rdf,", will stop at ",RExitCriteria
          PRINT*,TRIM(ADJUSTL(SPrintString))
        END IF
      END IF
      !shrink length scale as we progress, by a smaller amount depending on the no of variables: 1->1/2; 2->3/4; 3->5/6; 4->7/8; 5->9/10;
      RScale=RScale*(ONE-ONE/(TWO*REAL(INoOfVariables)))
    END DO    
    !We are done, simulate and output the best fit
    IExitFLAG=1
    CALL SimulateAndFit(RIndependentVariable,Iter,IExitFLAG,IErr)
    DEALLOCATE(RVar0,RCurrentVar,RLastVar,RPVec,RFitVec,STAT=IErr)    
    
  CASE(3)!Parabola
    ALLOCATE(RVar0(INoOfVariables),STAT=IErr)!incoming set of variables
    ALLOCATE(RCurrentVar(INoOfVariables),STAT=IErr)!set of variables to send out for simulations
    ALLOCATE(RLastVar(INoOfVariables),STAT=IErr)!set of variables updated each cycle
    ALLOCATE(RPVec(INoOfVariables),STAT=IErr)!the vector describing the current line in parameter space
    IF( IErr.NE.0 ) THEN
      PRINT*,"felixrefine(",my_rank,")error allocating parabola variables"
      GOTO 9999
    END IF
    RLastFit=RFigureofMerit
    RLastVar=RIndependentVariable
    RBestFit=RFigureofMerit
    Rdf=RFigureofMerit
    Iter=1
    ICycle=0!Each time we do a complete cycle we will have a look down the average refinement direction
    RScale=RSimplexLengthScale
    RMaxUgStep=0.005!maximum step in Ug is 0.5 nm^-2, 0.005 A^-2
    DO WHILE (Rdf.GE.RExitCriteria)
      !loop over variables
      DO ind=1,INoOfVariables
        !The type of variable being refined 
        IVariableType=IIterativeVariableUniqueIDs(ind,2)
        IF (my_rank.EQ.0) THEN!print to screen
        SELECT CASE(IVariableType)
          CASE(1)
            PRINT*,"Ug refinement"
          CASE(2)
            PRINT*,"Atomic coordinate refinement"
          CASE(3)
            PRINT*,"Occupancy refinement"
          CASE(4)
            PRINT*,"Isotropic Debye-Waller factor refinement"
          CASE(5)
            PRINT*,"Convergence angle refinement"
        END SELECT
          IF (INoOfVariables.GT.1) THEN
            IF (ICycle.EQ.1) THEN
              PRINT*,"Refining all variables"
            ELSE
              PRINT*,"Refining pairs of variables"
            END IF
          END IF
        END IF
        RVar0=RIndependentVariable!incoming point in n-dimensional parameter space
        RPvec=ZERO!Vector in n-dimensional parameter space for this refinement
        !IF (my_rank.EQ.0) PRINT*, "Current parameters=",RIndependentVariable
        IF (ICycle.EQ.1) THEN!look down the average refinement direction
          RPvec=(RCurrentVar-RLastVar)/(RCurrentVar(1)-RLastVar(1))
          RPvecMag=ZERO
          DO jnd=1,INoOfVariables
            RPvecMag=RPvecMag+RPvec(jnd)**2
          END DO
          RPvec=RPvec/SQRT(RPvecMag)!unity vector
          RLastVar=RCurrentVar
        ELSE IF (INoOfVariables.GT.1) THEN!pair-wise maximum gradient
          IF (ind.EQ.INoOfVariables) EXIT!skip the last variable
          WRITE(SPrintString,FMT='(A38,I3,A4,I3)') "Finding maximum gradient for variables",ind," and",ind+1
          IF (my_rank.EQ.0) PRINT*, TRIM(ADJUSTL(SPrintString))
          !NB R3fit contains the three fit indices
          R3fit(1)=RFigureofMerit!point 1 is the incoming simulation and fit index
          RPvec(ind)=RScale/5.0!small change in current variable for second point
          RCurrentVar=RVar0+RPvec!second point
          CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
          CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
          R3fit(2)=RFigureofMerit
          RPvec(ind+1)=RScale/5.0!now look along combination of 2 parameters for third point
          RCurrentVar=RVar0+RPvec!Update the parameters to simulate
          WRITE(SPrintString,FMT='(A38,I3,A4,I3)') "Finding maximum gradient for variables",ind," and",ind+1
          IF (my_rank.EQ.0) PRINT*, TRIM(ADJUSTL(SPrintString))
          CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
          CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
          R3fit(3)=RFigureofMerit
          !optimum gradient vector from the three points, magnitude unity
          RPvec=ZERO!reset
          RPvecMag=SQRT((R3fit(1)-R3fit(2))**2+(R3fit(2)-R3fit(3))**2)
          RPvec(ind)=(R3fit(1)-R3fit(2))/RPvecMag
          RPvec(ind+1)=(R3fit(2)-R3fit(3))/RPvecMag
        END IF
        WRITE(SPrintString,FMT='(A20,20(F6.3,1X))') "Refinement vector = ",RPvec
        IF (my_rank.EQ.0) PRINT*, TRIM(ADJUSTL(SPrintString))
        IF (ABS(SUM(RPvec))-1.GT.ABS(SUM(RPvec)).OR.ABS(SUM(RPvec)).NE.ABS(SUM(RPvec))) EXIT!Infinity and NaN check
        RVar0=RIndependentVariable!the best point of the three
        RFigureofMerit=MINVAL(R3fit)!the best fit of the three
        ! Small DW factor (<0.1) check
        IF (IVariableType.EQ.4.AND.RVar0(ind).LE.0.1) THEN
          IF(my_rank.EQ.0) PRINT*,"Small Debye Waller factor, resetting to 0.1"
          RVar0(ind)=0.1
          RCurrentVar=RVar0
          RPvecMag=RScale
          CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
          !update RIndependentVariable if necessary
          CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
        END IF
        R3var(1)=RVar0(ind)!first point is current value
        R3fit(1)=RFigureofMerit!with the current fit index
        !IF (my_rank.EQ.0) PRINT*,"point 1",R3var(1),"fit",R3fit(1)
        !magnitude of vector in parameter space
        RPvecMag=RVar0(ind)*RScale
        !IF (my_rank.EQ.0) PRINT*, "RPvecMag=",RPvecMag
        RCurrentVar=RVar0+RPvec*RPvecMag!Update the parameters to simulate
        R3var(2)=RCurrentVar(ind)!second point 
        CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
        CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
        R3fit(2)=RFigureofMerit
        !IF (my_rank.EQ.0) PRINT*,"point 2",R3var(2),"fit",R3fit(2)
        !third point
        IF (R3fit(2).GT.R3fit(1)) THEN!new 2 is not better than 1, go the other way
          RPvecMag=-RPvecMag
          RCurrentVar=RVar0+RPvec*RPvecMag
        ELSE!it is better, so keep going
          RCurrentVar=RVar0+TWO*RPvec*RPvecMag
        END IF
        R3var(3)=RCurrentVar(ind)!third point
        CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
        CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
        R3fit(3)=RFigureofMerit
        !IF (my_rank.EQ.0) PRINT*,"point 3",R3var(3),"fit",R3fit(3)
        !check the three points make a concave set
        jnd=MAXLOC(R3var,1)!highest x
        knd=MINLOC(R3var,1)!lowest x
        lnd=6-jnd-knd!the mid x
        IF (jnd.EQ.knd) lnd=jnd!covering the unlikely scenario that all simulations have the same fit index
        Rtest=-ABS(R3fit(jnd)-R3fit(knd))!Rtest=0.0 would be a straight line, >0=convex, <0=concave
        !Rconvex is the calculated fit index at the mid x, if ithere was a straight line between lowest and highest x
        Rconvex=R3fit(lnd)-(R3fit(knd)+(R3var(lnd)-R3var(knd))*(R3fit(jnd)-R3fit(knd))/(R3var(jnd)-R3var(knd)))
        DO WHILE (Rconvex.GT.0.1*Rtest)!if it isn't more than 10% concave, keep going until it is sufficiently concave
          IF(my_rank.EQ.0) PRINT*,"Convex, continuing"
          jnd=MAXLOC(R3fit,1)!worst fit
          knd=MINLOC(R3fit,1)!best fit
          lnd=6-jnd-knd!the mid fit
          !replace mid point with a step on from best point
          RPvecMag=(R3var(knd)-RVar0(ind))*(0.5+SQRT(5.0)/2.0)/RPvec(ind)!increase the step size by the golden ratio
          IF (ABS(RPvecMag).GT.RMaxUgStep.AND.IRefineMode(1).EQ.1) RPvecMag=SIGN(RMaxUgStep,RPvecMag)!maximum step in Ug is RMaxUgStep
          RCurrentVar=RVar0+RPvec*RPvecMag
          R3var(lnd)=RCurrentVar(ind)!next point
          IF (R3var(lnd).LE.ZERO.AND.IVariableType.EQ.4) THEN!less than zero DW is requested
            R3var(lnd)=ZERO!limit it to 0.0
            RCurrentVar=RVar0-RPvec*RVar0(ind)!and set up for simulation outside the loop
            EXIT
          END IF
          CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
          CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
          R3fit(lnd)=RFigureofMerit
          jnd=MAXLOC(R3var,1)!highest x
          knd=MINLOC(R3var,1)!lowest x
          lnd=6-jnd-knd!the mid x
          Rconvex=R3fit(lnd)-(R3fit(knd)+(R3var(lnd)-R3var(knd))*(R3fit(jnd)-R3fit(knd))/(R3var(jnd)-R3var(knd)))
          Rtest=-ABS(R3fit(jnd)-R3fit(knd))
        END DO
        !now make a prediction
        IF (RCurrentVar(ind).LE.TINY.AND.IVariableType.EQ.4) THEN!We reached zero D-W factor in convexity test, skip the prediction
          CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
          CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
          IF (my_rank.EQ.0) PRINT*,"Using zero Debye Waller factor, refining next variable"
        ELSE
          CALL Parabo3(R3var,R3fit,RvarMin,RfitMin,IErr)
          IF (my_rank.EQ.0) THEN
            WRITE(SPrintString,FMT='(A32,F7.4,A16,F6.4)') &
               "Concave set, predict minimum at ",RvarMin," with fit index ",RfitMin
            PRINT*,TRIM(ADJUSTL(SPrintString))
          END IF
          jnd=MAXLOC(R3fit,1)!worst point
          knd=MINLOC(R3fit,1)!best point
          !replace worst point with prediction and put into RIndependentVariable
          IF (RvarMin.LT.ZERO.AND.IVariableType.EQ.4) RvarMin=ZERO!We have reached zero D-W factor
          RCurrentVar=RVar0+RPvec*(RvarMin-RVar0(ind))/RPvec(ind)
          !R3var(jnd)=RCurrentVar(ind)!do I need this?
          CALL SimulateAndFit(RCurrentVar,Iter,IExitFLAG,IErr)
          CALL BestFitCheck(RFigureofMerit,RBestFit,RCurrentVar,RIndependentVariable,IErr)
        END IF
        IF (ICycle.EQ.1) EXIT!we have just done an average direction refinement, quit the NoOfVariables loop
      END DO
      !We have refined all variables, check where we go next and update last fit etc.
      IF (INoOfVariables.GT.2) THEN!refining multiple variables
        IF (ICycle.EQ.0) THEN!we haven't done an average direction refinement, set the flag
          ICycle=1
        ELSE!we just did an average direction refinement, go back to pairwise and update RLastFit and Rdf
          ICycle=0
          Rdf=RLastFit-RBestFit 
          RLastFit=RBestFit
          IF(my_rank.EQ.0) THEN
            PRINT*,"--------------------------------"
            WRITE(SPrintString,FMT='(A19,F8.6,A15,F8.6)') "Improvement in fit ",Rdf,", will stop at ",RExitCriteria
            PRINT*,TRIM(ADJUSTL(SPrintString))
          END IF
        END IF
      ELSE!refining just one variable
        IF (RBestFit.LT.RLastFit) THEN
          Rdf=RLastFit-RBestFit 
          RLastFit=RBestFit
          IF(my_rank.EQ.0) THEN
            PRINT*,"--------------------------------"
            WRITE(SPrintString,FMT='(A19,F8.6,A15,F8.6)') "Improvement in fit ",Rdf,", will stop at ",RExitCriteria
            PRINT*,TRIM(ADJUSTL(SPrintString))
          END IF
        END IF
      END IF
      !shrink length scale as we progress, by a smaller amount depending on the no of variables: 1->1/2; 2->3/4; 3->5/6; 4->7/8; 5->9/10;
      RScale=RScale*(ONE-ONE/(TWO*REAL(INoOfVariables)))
    END DO
    !We are done, finallly simulate and output the best fit
    IExitFLAG=1
    CALL SimulateAndFit(RIndependentVariable,Iter,IExitFLAG,IErr)
    DEALLOCATE(RVar0,RCurrentVar,RLastVar,RPVec,STAT=IErr)    
   
  CASE DEFAULT!Simulation only, should never happen
    IF (my_rank.EQ.0) THEN
      PRINT*,"No refinement, simulation only"
    END IF
      
  END SELECT 

  !--------------------------------------------------------------------
  ! Deallocate Memory
  !--------------------------------------------------------------------
8888  DEALLOCATE(CUgMat,STAT=IErr)!FelixSim comes here to finish off  
  DEALLOCATE(CUgMatNoAbs,STAT=IErr)
  DEALLOCATE(CUgMatPrime,STAT=IErr)
  DEALLOCATE(RWeightingCoefficients,STAT=IErr)
  DEALLOCATE(ISymmetryRelations,STAT=IErr)
  DEALLOCATE(IEquivalentUgKey,STAT=IErr)
  DEALLOCATE(CUniqueUg,STAT=IErr)
  DEALLOCATE(RIndividualReflections,STAT=IErr)
  DEALLOCATE(IDisplacements,STAT=IErr)
  DEALLOCATE(ICount,STAT=IErr)
  DEALLOCATE(Rhkl,STAT=IErr)
  DEALLOCATE(RgPoolMag,STAT=IErr)
  DEALLOCATE(RgPool,STAT=IErr)
  DEALLOCATE(RgMatrix,STAT=IErr)
  DEALLOCATE(RgSumMat,STAT=IErr)
  DEALLOCATE(RSimulatedPatterns,STAT=IErr)
  DEALLOCATE(RAtomPosition,STAT=IErr)
  DEALLOCATE(SAtomName,STAT=IErr)
  DEALLOCATE(RIsoDW,STAT=IErr)
  DEALLOCATE(ROccupancy,STAT=IErr)
  DEALLOCATE(IAtomicNumber,STAT=IErr)
  DEALLOCATE(RAnisoDW,STAT=IErr)
  DEALLOCATE(RAtomCoordinate,STAT=IErr)
  DEALLOCATE(RgMatrixMagnitude,STAT=IErr)
  DEALLOCATE(CPseudoAtom,STAT=IErr)
  DEALLOCATE(CPseudoScatt,STAT=IErr)
  IF (IRefineMode(1).EQ.0) THEN
  	DEALLOCATE(IIterativeVariableUniqueIDs,STAT=IErr)
  END IF
  IF (ISimFLAG.EQ.0) THEN
    DEALLOCATE(RImageExpi,STAT=IErr)  
  END IF  
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine(",my_rank,")error in final deallocations"
     GOTO 9999
  END IF
  
  !--------------------------------------------------------------------
  ! finish off
  WRITE(my_rank_string,*) my_rank
  CALL SYSTEM_CLOCK(ICurrentTime)
  Duration=REAL(ICurrentTime-IStartTime)/REAL(IRate)
  IHours = FLOOR(Duration/3600.0D0)
  IMinutes = FLOOR(MOD(Duration,3600.0D0)/60.0D0)
  ISeconds = INT(MOD(Duration,3600.0D0)-IMinutes*60)
  IMilliSeconds = INT((Duration-(IHours*3600+IMinutes*60+ISeconds))*1000,IKIND)

  IF(my_rank.EQ.0) THEN
    PRINT*,"--------------------------------"
    WRITE(SPrintString,FMT='(A25,I3,A5,I2,A6,I2,A4)')&
    "Calculation completed in ",IHours," hrs ",IMinutes," mins ",ISeconds," sec"
    PRINT*,TRIM(ADJUSTL(SPrintString))
    PRINT*,"--------------------------------"
    PRINT*,"||||||||||||||||||||||||||||||||"
  END IF
  !--------------------------------------------------------------------
  ! Shut down MPI
  !--------------------------------------------------------------------

9999 CALL MPI_Finalize(IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"Felixrefine(", my_rank, ") error ", IErr, " in MPI_Finalize()"
     STOP
  END IF
  
  ! clean shutdown
  STOP
  
10  GOTO 9999  

END PROGRAM Felixrefine
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SUBROUTINE AssignArrayLocationsToIterationVariables(IIterativeVariableType,IVariableNo,IArrayToFill,IErr)
!NB IArrayToFill here is equivalent to IIterativeVariableUniqueIDs outside this subroutine
  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara

  USE IChannels

  USE MPI
  USE MyMPI
  
  IMPLICIT NONE

  INTEGER(IKIND) :: IIterativeVariableType,IVariableNo,IErr,IArrayIndex,&
       IAnisotropicDebyeWallerFactorElementNo
  INTEGER(IKIND),DIMENSION(INoOfVariables,5),INTENT(OUT) :: IArrayToFill  

!!$  Calculate How Many of Each Variable Type There are
!  CALL DetermineNumberofRefinementVariablesPerType(INoofElementsForEachRefinementType,IErr)
  
!!$  Where am I in the Array Right Now?
  IArrayIndex = SUM(INoofElementsForEachRefinementType(:(IIterativeVariableType-1)))+IVariableNo

  SELECT CASE(IIterativeVariableType)

  CASE(1) ! Ugs, A
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType
     IArrayToFill(IArrayIndex,3) = &
          NINT(REAL(INoofUgs,RKIND)*(REAL(IVariableNo/REAL(INoofUgs,RKIND),RKIND)-&
          CEILING(REAL(IVariableNo/REAL(INoofUgs,RKIND),RKIND)))+REAL(INoofUgs,RKIND))

  CASE(2) ! Coordinates (x,y,z), B
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType
     IArrayToFill(IArrayIndex,3) = IVariableNo

  CASE(3) ! Occupancies, C
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType
     IArrayToFill(IArrayIndex,3) = IAtomicSitesToRefine(IVariableNo)

  CASE(4) ! Isotropic Debye Waller Factors , D
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType
     IArrayToFill(IArrayIndex,3) = IAtomicSitesToRefine(IVariableNo)

  CASE(5) ! Anisotropic Debye Waller Factors (a11-a33), E
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType
     IArrayToFill(IArrayIndex,3) = IAtomicSitesToRefine(INT(CEILING(REAL(IVariableNo/6.0D0,RKIND))))
     IAnisotropicDebyeWallerFactorElementNo = &
          NINT(6.D0*(REAL(IVariableNo/6.0D0,RKIND)-CEILING(REAL(IVariableNo/6.0D0,RKIND)))+6.0D0)

     SELECT CASE(IAnisotropicDebyeWallerFactorElementNo)

        CASE(1)
           IArrayToFill(IArrayIndex,4:5) = [1,1]
        CASE(2)
           IArrayToFill(IArrayIndex,4:5) = [2,1]
        CASE(3)
           IArrayToFill(IArrayIndex,4:5) = [2,2]
        CASE(4)
           IArrayToFill(IArrayIndex,4:5) = [3,1]
        CASE(5)
           IArrayToFill(IArrayIndex,4:5) = [3,2]
        CASE(6)
           IArrayToFill(IArrayIndex,4:5) = [3,3]

        END SELECT

  CASE(6) ! Lattice Parameters, E
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType
     IArrayToFill(IArrayIndex,3) = &
          NINT(3.D0*(REAL(IVariableNo/3.0D0,RKIND)-CEILING(REAL(IVariableNo/3.0D0,RKIND)))+3.0D0)
     
  CASE(7) ! Lattice Angles, F
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType
     IArrayToFill(IArrayIndex,3) = &
          NINT(3.D0*(REAL(IVariableNo/3.0D0,RKIND)-CEILING(REAL(IVariableNo/3.0D0,RKIND)))+3.0D0)

  CASE(8) !Convergence angle, H
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType

  CASE(9)  !Percentage Absorption, I
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType

  CASE(10)!kV, J
     IArrayToFill(IArrayIndex,2) = IIterativeVariableType

  END SELECT
  
END SUBROUTINE AssignArrayLocationsToIterationVariables

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SUBROUTINE RefinementVariableSetup(RIndependentVariable,IErr)
!This is redundant  
  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara
  
  USE IChannels
  
  USE MPI
  USE MyMPI
  
  IMPLICIT NONE
  
  INTEGER(IKIND) :: IErr,ind,IVariableType
  REAL(RKIND),DIMENSION(INoOfVariables),INTENT(OUT) :: RIndependentVariable
  
  IF((IWriteFLAG.GE.10.AND.my_rank.EQ.0).OR.IWriteFLAG.GE.10) THEN
     PRINT*,"RefinementVariableSetup(",my_rank,")"
  END IF
  
!!$  Fill the Independent Value array with values

  DO ind = 1,INoOfVariables
     IVariableType = IIterativeVariableUniqueIDs(ind,2)
     SELECT CASE (IVariableType)
     CASE(1)
	    !Structure factor refinement, define in SymmetryRelatedStructureFactorDetermination
    CASE(2)
        RIndependentVariable(ind) = RAllowedVectorMagnitudes(IIterativeVariableUniqueIDs(ind,3))
     CASE(3)
        RIndependentVariable(ind) = RBasisOccupancy(IIterativeVariableUniqueIDs(ind,3))
     CASE(4)
        RIndependentVariable(ind) = RBasisIsoDW(IIterativeVariableUniqueIDs(ind,3))
     CASE(5)
        RIndependentVariable(ind) = RAnisotropicDebyeWallerFactorTensor(&
             IIterativeVariableUniqueIDs(ind,3),&
             IIterativeVariableUniqueIDs(ind,4),&
             IIterativeVariableUniqueIDs(ind,5))
     CASE(6)
        SELECT CASE(IIterativeVariableUniqueIDs(ind,3))
        CASE(1)
           RIndependentVariable(ind) = RLengthX
        CASE(2)
           RIndependentVariable(ind) = RLengthY
        CASE(3)
           RIndependentVariable(ind) = RLengthZ
        END SELECT
     CASE(7)
        SELECT CASE(IIterativeVariableUniqueIDs(ind,3))
        CASE(1)
           RIndependentVariable(ind) = RAlpha
        CASE(2)
           RIndependentVariable(ind) = RBeta
        CASE(3)
           RIndependentVariable(ind) = RGamma
        END SELECT
     CASE(8)
        RIndependentVariable(ind) = RConvergenceAngle
     CASE(9)
        RIndependentVariable(ind) = RAbsorptionPercentage
     CASE(10)
        RIndependentVariable(ind) = RAcceleratingVoltage
     CASE(11)
        RIndependentVariable(ind) = RRSoSScalingFactor
     CASE(12)
	    !Structure factor refinement, define in SymmetryRelatedStructureFactorDetermination
     END SELECT
  END DO

END SUBROUTINE RefinementVariableSetup

!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SUBROUTINE InitialiseAtomicVectorMagnitudes(IVariableID,RCorrectedMovement,IErr)
  
!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!!$  % Creates pseudo random movements of atoms using allowed vectors
!!$  % to initialise the simplex, proposed movements which exit the unit
!!$  $ cell are corrected to bring the atom back in on the opposite side
!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara
  
  USE IChannels
  
  USE MPI
  USE MyMPI
  
  IMPLICIT NONE

  INTEGER(IKIND) :: IErr,ind,IVariableID
  REAL(RKIND) :: RNegativeMovement,RPositiveMovement,RCorrectedMovement,RANDOMNUMBER

  RNegativeMovement = RSimplexLengthScale*(-1.0_RKIND)
  RPositiveMovement = RSimplexLengthScale
!RB this check can be done in less lines than it takes to call the subroutine
  IF(RANDOMNUMBER(IVariableID,IErr).LT.0.5_RKIND) THEN
     CALL OutofUnitCellCheck(IVariableID,RNegativeMovement,RCorrectedMovement,IErr)
  ELSE
     CALL OutofUnitCellCheck(IVariableID,RPositiveMovement,RCorrectedMovement,IErr)
  END IF

END SUBROUTINE InitialiseAtomicVectorMagnitudes

!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SUBROUTINE RandomSequence(RRandomSequence,IRandomSequenceLength,ISeedModifier,IErr)
!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!!$  % Sets up a pseudo random sequence and selects a number

  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara

  USE IChannels

  USE MPI
  USE MyMPI

  IMPLICIT NONE

  INTEGER(IKIND) :: IErr,Ivalues(1:8), k,IRandomSequenceLength,ISeedModifier
  INTEGER(IKIND), DIMENSION(:), ALLOCATABLE :: seed
  REAL(RKIND),DIMENSION(IRandomSequenceLength) :: RRandomSequence
  
  CALL DATE_AND_TIME(VALUES=Ivalues)

  IValues = IValues*ISeedModifier
!!$  CALL SYSTEM_CLOCK(
  IF (IRandomFLAG.EQ.0) THEN
     CALL RANDOM_SEED(size=k)
     allocate(seed(1:k))
     seed(:) = Ivalues(8)
     CALL RANDOM_SEED(put=seed)
  ELSE
     CALL RANDOM_SEED(size=k)
     ALLOCATE(seed(1:k))
     seed(:) = IFixedSeed*ISeedModifier
     CALL RANDOM_SEED(put=seed)
  END IF
   
  DEALLOCATE(seed)

  CALL RANDOM_NUMBER(RRandomSequence)
  
!!$  RANDOMSEQUENCE = RRandomNumberSequence(IRequestedNumber)
  
END SUBROUTINE  RANDOMSEQUENCE

!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

REAL(RKIND) FUNCTION RANDOMNUMBER(IRequestedNumber,IErr)
!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!!$  % Sets up a pseudo random sequence and selects a number
!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara

  USE IChannels

  USE MPI
  USE MyMPI

  IMPLICIT NONE

  INTEGER(IKIND) :: IErr,values(1:8), k,IRequestedNumber
  INTEGER(IKIND), DIMENSION(:), ALLOCATABLE :: seed
  REAL(RKIND),DIMENSION(IRequestedNumber) :: RRandomNumberSequence
  
  CALL DATE_AND_TIME(values=values)
  
  IF (IRandomFLAG.EQ.0) THEN
     CALL RANDOM_SEED(size=k)
     allocate(seed(1:k))
     seed(:) = values(8)
     CALL RANDOM_SEED(put=seed)
  ELSE
     CALL RANDOM_SEED(size=k)
     ALLOCATE(seed(1:k))
     seed(:) = IFixedSeed*IRequestedNumber
     CALL RANDOM_SEED(put=seed)
  END IF
   
  CALL RANDOM_NUMBER(RRandomNumberSequence)
  
  RANDOMNUMBER = RRandomNumberSequence(IRequestedNumber)
  
END FUNCTION RANDOMNUMBER

!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SUBROUTINE OutofUnitCellCheck(IVariableID,RProposedMovement,RCorrectedMovement,IErr)
!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!!$  % Checks that vector movement applied by the simplex initialisation
!!$  % does not move an atom out fo the unit cell, and if it does
!!$  % the atom is moved back into the unit cell on the opposite side
!!$  % as if the atom had moved from one unit cell into the neighbouring one
!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

!!!Can't this just be done in one line with MODULO???!!!
  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara

  USE IChannels

  USE MPI
  USE MyMPI

  IMPLICIT NONE
  
  INTEGER(IKIND) :: ind,IErr,IVariableID,IAtomID,IVectorID
  REAL(RKIND),DIMENSION(ITHREE) :: RProposedAtomicCoordinate,RDummyMovement
  REAL(RKIND),INTENT(IN) :: RProposedMovement
  REAL(RKIND),INTENT(OUT) :: RCorrectedMovement
  
  IVectorID = IIterativeVariableUniqueIDs(IVariableID,3)
  
  IAtomID = IAllowedVectorIDs(IVectorID)
 
  RProposedAtomicCoordinate(:) = RBasisAtomPosition(IAtomID,:) + &
       RProposedMovement*RAllowedVectors(IVectorID,:)

  RDummyMovement = RProposedMovement

  IF(ANY(RProposedAtomicCoordinate.GT.ONE).OR.ANY(RProposedAtomicCoordinate.LT.ZERO)) THEN
     DO ind = 1,ITHREE
        IF (RProposedAtomicCoordinate(ind).GT.ONE) THEN
           RDummyMovement(ind) = (ONE-RBasisAtomPosition(IAtomID,ind))/RAllowedVectors(IVectorID,ind)
        ELSEIF(RProposedAtomicCoordinate(ind).LT.ZERO) THEN
           RDummyMovement(ind) = (-RBasisAtomPosition(IAtomID,ind))/RAllowedVectors(IVectorID,ind)
        ELSE
           RDummyMovement(ind) = RProposedMovement
        END IF
     END DO
  END IF

  IF(RProposedMovement.LT.ZERO) THEN
     RCorrectedMovement = MAXVAL(RDummyMovement)
  ELSE
     RCorrectedMovement = MINVAL(RDummyMovement)
  END IF

END SUBROUTINE OutofUnitCellCheck

!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SUBROUTINE RecoverSavedSimplex(RSimplexVariable,RSimplexFoM,RStandardDeviation,RMean,Iter,IErr)

!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!!$  % This Subroutine reads the fr-simplex.txt file from a previous
!!$  % refinement run, and recreates the simplex volume and tolerances
!!$  % allowing for the continuation of a previous refinement
!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara

  USE IChannels

  USE MPI
  USE MyMPI

  IMPLICIT NONE

  INTEGER(IKIND) :: &
       IErr,ind,Iter
  REAL(RKIND),DIMENSION(INoOfVariables+1,INoOfVariables) :: RSimplexVariable
  REAL(RKIND),DIMENSION(INoOfVariables+1) :: RSimplexFoM
  REAL(RKIND) :: RStandardDeviation,RMean
  CHARACTER*200 :: CSizeofData,SFormatString,filename

  WRITE(filename,*) "fr-Simplex.txt"

  OPEN(UNIT=IChOutSimplex,STATUS='UNKNOWN',&
        FILE=TRIM(ADJUSTL(filename)))
  
  WRITE(CSizeofData,*) INoOfVariables+1
  WRITE(SFormatString,*) "("//TRIM(ADJUSTL(CSizeofData))//"(1F6.3,1X),A1)"

  DO ind = 1,(INoOfVariables+1)
     READ(IChOutSimplex,FMT=SFormatString) RSimplexVariable(ind,:),RSimplexFoM(ind)
  END DO
    
  READ(IChOutSimplex,FMT="(2(1F6.3,1X),I5.1,I5.1,A1)") RStandardDeviation,RMean,IStandardDeviationCalls,Iter

  CLOSE(IChOutSimplex)

END SUBROUTINE RecoverSavedSimplex

!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SUBROUTINE SetupAtomicVectorMovements(IErr)

  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara

  USE IChannels

  USE MPI
  USE MyMPI
  
  IMPLICIT NONE

  INTEGER(IKIND) :: IErr,knd,jnd,ind,ISpaceGrp
  INTEGER(IKIND),DIMENSION(:),ALLOCATABLE :: IVectors
  
  CALL ConvertSpaceGroupToNumber(ISpaceGrp,IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"SetupAtomicVectorMovements(",my_rank,")error in ConvertSpaceGroupToNumber"
     RETURN
  END IF

  ALLOCATE(IVectors(SIZE(SWyckoffSymbols)),STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"felixrefine (", my_rank, ") error in Allocation() of IVectors"
     RETURN
  END IF
  
  DO ind = 1,SIZE(SWyckoffSymbols)!NB SIZE(SWyckoffSymbols)=IAtomicSitesToRefine?
     CALL CountAllowedMovements(ISpaceGrp,SWyckoffSymbols(ind),IVectors(ind),IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"SetupAtomicVectorMovements(",my_rank,")error in CountAllowedMovements "
        RETURN
     END IF    
  END DO
  
  IAllowedVectors = SUM(IVectors)
  
  ALLOCATE(IAllowedVectorIDs(IAllowedVectors),STAT=IErr)
  ALLOCATE(RAllowedVectors(IAllowedVectors,ITHREE),STAT=IErr)
  ALLOCATE(RAllowedVectorMagnitudes(IAllowedVectors),STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"SetupAtomicVectorMovements(",my_rank,")error in allocation"
     RETURN
  END IF
  
  knd = 0
  DO ind = 1,SIZE(SWyckoffSymbols)
    DO jnd = 1,IVectors(ind)
      knd = knd + 1
      IAllowedVectorIDs(knd) = IAtomicSitesToRefine(ind)
    END DO
  END DO
  
  RAllowedVectorMagnitudes = ZERO
  DO ind = 1,SIZE(SWyckoffSymbols)
    CALL DetermineAllowedMovements(ISpaceGrp,SWyckoffSymbols(ind),&
         RAllowedVectors(SUM(IVectors(:(ind-1)))+1:SUM(IVectors(:(ind))),:),&
         IVectors(ind),IErr)
    IF( IErr.NE.0 ) THEN
      PRINT*,"SetupAtomicVectorMovements(",my_rank,")error in DetermineAllowedMovements"
      RETURN
    END IF
  END DO
  
  ALLOCATE(RInitialAtomPosition(SIZE(RBasisAtomPosition,1),ITHREE),STAT=IErr)
  IF( IErr.NE.0 ) THEN
    PRINT*,"SetupAtomicVectorMovements(",my_rank,")error ALLOCATE RInitialAtomPosition "
    RETURN
  END IF
  RInitialAtomPosition = RBasisAtomPosition
END SUBROUTINE SetupAtomicVectorMovements

!!$  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SUBROUTINE BestFitCheck(RFoM,RBest,RCurrent,RIndependentVariable,IErr)

  USE MyNumbers
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara
  USE BlochPara
  USE IChannels
  USE MPI
  USE MyMPI
  
  IMPLICIT NONE
  
  REAL(RKIND) :: RFoM,RBest!current figure of merit and the best figure of merit
  REAL(RKIND),DIMENSION(INoOfVariables) :: RCurrent,RIndependentVariable!current and best set of variables
  INTEGER(IKIND) :: IErr
  CHARACTER*200 :: SPrintString  

  IF (RFoM.LT.RBest) THEN
    RBest=RFoM
    RIndependentVariable=RCurrent
  END IF
  IF(my_rank.EQ.0) THEN
    WRITE(SPrintString,FMT='(A18,F8.6)') "Best fit so far = ",RBest
    PRINT*,TRIM(ADJUSTL(SPrintString))
  END IF
        
END SUBROUTINE BestFitCheck
