!-----------------------------------------------------------------------
      SUBROUTINE GRIBIT(F,LBM,IDRT,IM,JM,MXBIT,COLAT1,
     &                  ILPDS,IPTV,ICEN,IGEN,IBMS,IPU,ITL,IL1,IL2,
     &                  IYR,IMO,IDY,IHR,IFTU,IP1,IP2,ITR,INA,INM,IDS,
     &                  XLAT1,XLON1,XLAT2,XLON2,DELX,DELY,ORTRU,PROJ,
     &                  GRIDNO,
     &                  GRIB,LGRIB,IERR)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:    GRIBIT      CREATE GRIB MESSAGE
!   PRGMMR: IREDELL          ORG: W/NMC23    DATE: 92-10-31
!   Modified by R. Grumbine       W/NMC21    DATE: 95-06-29
!
! ABSTRACT: CREATE A GRIB MESSAGE FROM A FULL FIELD.
!   AT PRESENT, ONLY GLOBAL LATLON GRIDS AND GAUSSIAN GRIDS ARE ALLOWED.
!
! PROGRAM HISTORY LOG:
!   92-10-31  IREDELL
!   94-05-04  JUANG (FOR GSM AND RSM USE)
!   95-06-29  Grumbine (arbitrary lat-long grids)
!   97-06-04  Grumbine (send grid number as argument)
!   98-07-21  Grumbine Y2K fix on century usage
! 2006-08-31  Unchanged since at least this date (noted on 22 Dec 2015)
!
! USAGE:    CALL GRIBIT(F,LBM,IDRT,IM,JM,MXBIT,COLAT1,
!    &                  ILPDS,IPTV,ICEN,IGEN,IBMS,IPU,ITL,IL1,IL2,
!    &                  IYR,IMO,IDY,IHR,IFTU,IP1,IP2,ITR,INA,INM,IDS,
!    &                  XLAT1,XLON1,XLAT2,XLON2,DELX,DELY,ORTRU,PROJ,
!    &                  GRIB,LGRIB,IERR)
!   INPUT ARGUMENT LIST:
!     F        - REAL (IM*JM) FIELD DATA TO PACK INTO GRIB MESSAGE
!     LBM      - LOGICAL (IM*JM) BITMAP TO USE IF IBMS=1
!     IDRT     - INTEGER DATA REPRESENTATION TYPE
!                  -- 0 FOR LATLON 
!                  -- 1 FOR Mercator
!                  -- 4 FOR GAUSSIAN
!                  -- 5 FOR Polar Stereographic
!                  -- 6 FOR Hycom native
!     IM       - INTEGER LONGITUDINAL DIMENSION
!     JM       - INTEGER LATITUDINAL DIMENSION
!     MXBIT    - INTEGER MAXIMUM NUMBER OF BITS TO USE (0 FOR NO LIMIT)
!     COLAT1   - REAL FIRST COLATITUDE OF GAUSSIAN GRID IF IDRT=4
!     ILPDS    - INTEGER LENGTH OF THE PDS (USUALLY 28)
!     IPTV     - INTEGER PARAMETER TABLE VERSION (USUALLY 1)
!     ICEN     - INTEGER FORECAST CENTER (USUALLY 7)
!     IGEN     - INTEGER MODEL GENERATING CODE
!     IBMS     - INTEGER BITMAP FLAG (0 FOR NO BITMAP)
!     IPU      - INTEGER PARAMETER AND UNIT INDICATOR
!     ITL      - INTEGER TYPE OF LEVEL INDICATOR
!     IL1      - INTEGER FIRST LEVEL VALUE (0 FOR SINGLE LEVEL)
!     IL2      - INTEGER SECOND LEVEL VALUE
!    &                  IYR,IMO,IDY,IHR,IFTU,IP1,IP2,ITR,INA,INM,IDS,
!    &                  GRIB,LGRIB,IERR)
!     IYR      - INTEGER YEAR -- 4 digits 7/21/1998
!     IMO      - INTEGER MONTH
!     IDY      - INTEGER DAY
!     IHR      - INTEGER HOUR
!     IFTU     - INTEGER FORECAST TIME UNIT (1 FOR HOUR)
!     IP1      - INTEGER FIRST TIME PERIOD
!     IP2      - INTEGER SECOND TIME PERIOD (0 FOR SINGLE PERIOD)
!     ITR      - INTEGER TIME RANGE INDICATOR (10 FOR SINGLE PERIOD)
!     INA      - INTEGER NUMBER INCLUDED IN AVERAGE
!     INM      - INTEGER NUMBER MISSING FROM AVERAGE
!     IDS      - INTEGER DECIMAL SCALING
!    &                  XLAT1,XLON1,DELX,DELY,ORTRU,PROJ,
!     XLAT1    - FIRST POINT OF REGIOANL LATITUDE
!     XLON1    - FIRST POINT OF REGIONAL LONGITUDE
!     XLAT2    - LAST POINT OF REGIOANL LATITUDE
!     XLON2    - LAST POINT OF REGIONAL LONGITUDE
!     DELX     - DX IN METER ON 60N FOR REGIONAL
!     DELY     - DY IN METER ON 60N FOR REGIONAL
!     PROJ     - POLAR PROJECTION FLAG 0 FOR NORTH 128 FOR SOUTH
!     ORTRU   - ORIENTATION OF LONGITUDE FOR POLAR PROJECTION
!                OR TRUTH OF LATITUDE FOR MERCATER PROJECTION
!     GRIDNO  - NCEP Grib table Grib number.
!
!   OUTPUT ARGUMENT LIST:
!     GRIB     - CHARACTER (LGRIB) GRIB MESSAGE
!     LGRIB    - INTEGER LENGTH OF GRIB MESSAGE
!                (NO MORE THAN 100+ILPDS+IM*JM*(MXBIT+1)/8)
!     IERR     - INTEGER ERROR CODE (0 FOR SUCCESS)
!
! SUBPROGRAMS CALLED:
!   GTBITS     - COMPUTE NUMBER OF BITS AND ROUND DATA APPROPRIATELY
!   W3FI72     - ENGRIB DATA INTO A GRIB1 MESSAGE
!
! ATTRIBUTES:
!   LANGUAGE: CRAY FORTRAN
!
!$$$
      IMPLICIT NONE
!     Declare argument list:
      INTEGER ILPDS, IPTV, ICEN, IGEN, IBMS, IPU, ITL, IL1, IL2
      INTEGER IYR, IMO, IDY, IHR, IFTU, IP1, IP2, ITR, INA, INM, IDS
      REAL XLAT1, XLON1, XLAT2, XLON2, DELX, DELY, ORTRU, PROJ
      REAL colat1
      INTEGER iresfl, iscan, nbit, igrid, mxbit, ierr, lgrib
      INTEGER IDRT, IM, JM
!     Declare local variables:
      INTEGER IGDS10, IGDS11, IGDS12, IGDS13, IGDS14, IGDS09
      INTEGER i, NF, NBM
      INTEGER lat1, lon1, lati, loni
!     Arguments returned by GETBIT
      REAL FMIN, FMAX
!     Arguments returned by W3FI72
      REAL NFO


      REAL F(IM*JM)
      LOGICAL LBM(IM*JM)
      CHARACTER GRIB(*)
      INTEGER IBM(IM*JM*IBMS+1-IBMS),IPDS(25),IGDS(18),IBDS(9)
      REAL FROUND(IM*JM)
      CHARACTER PDS(ILPDS)
      INTEGER GRIDNO
      INTEGER IBS


      NF=IM*JM
      IF(IDRT.EQ.0) THEN
        IF(IM.EQ.144.AND.JM.EQ.73) THEN
          IGRID=2
        ELSEIF(IM.EQ.360.AND.JM.EQ.181) THEN
          IGRID=3
        ELSE
          IGRID=GRIDNO
        ENDIF
        IRESFL=128
        ISCAN=0
!O        LAT1=NINT(90.E3)
!O        LON1=0
!O        lati=NINT(180.E3/(JM-1))
!O        loni=NINT(360.E3/IM)
        LAT1 = NINT(XLAT1*1000.)
        LON1 = NINT(XLON1*1000.)
        lati = NINT( (XLAT2-XLAT1)/(JM-1) * 1000.)
        loni = NINT( (XLON2-XLON1)/(IM-1) * 1000.)  
        IGDS09=-LAT1
        IGDS10=-LON1  !was loni
        IGDS11=lati
        IGDS12=loni
        IGDS13=ISCAN
      ELSEIF(IDRT.EQ.4) THEN
        IGRID=GRIDNO
        IRESFL=128
        ISCAN=0
        LAT1=NINT(90.E3-180.E3/ACOS(-1.)*COLAT1)
        LON1=0
        lati=JM/2
        loni=NINT(360.E3/IM)
        IGDS09=-LAT1
        IGDS10=-loni
        IGDS11=lati
        IGDS12=loni
        IGDS13=ISCAN
      ELSEIF(IDRT.EQ.5) THEN    ! POLAR PROJECTION
        IGRID=GRIDNO
        LAT1=NINT(180.E3/ACOS(-1.) * XLAT1)
        LON1=NINT(180.E3/ACOS(-1.) * XLON1)
        IRESFL=0
        IGDS09=NINT(ORTRU*1.E3)
        IGDS10=DELX  
        IGDS11=DELY
        IF( NINT(PROJ).EQ.1  ) IGDS12=0        ! NORTH POLAR PROJ
        IF( NINT(PROJ).EQ.-1 ) IGDS12=128    ! SOUTH POLAT PROJ
        ISCAN=64
        IGDS13=ISCAN
      ELSEIF(IDRT.EQ.1) THEN    ! MERCATER PROJECTION
        IGRID=GRIDNO
        LAT1=NINT(180.E3/ACOS(-1.) * XLAT1)
        LON1=NINT(180.E3/ACOS(-1.) * XLON1)
        IRESFL=0
        IGDS09=NINT(180.E3/ACOS(-1.) * XLAT2)
        IGDS10=NINT(180.E3/ACOS(-1.) * XLON2)
        IGDS11=DELX
        IGDS12=DELY
        IGDS13=NINT(ORTRU*1.E3)
        ISCAN=64
        IGDS14=ISCAN
      ELSE
        IERR=40
        RETURN
      ENDIF
      IPDS(01)=ILPDS   ! LENGTH OF PDS
      IPDS(02)=IPTV    ! PARAMETER TABLE VERSION ID
      IPDS(03)=ICEN    ! CENTER ID
      IPDS(04)=IGEN    ! GENERATING MODEL ID
      IPDS(05)=IGRID   ! GRID ID
      IPDS(06)=1       ! GDS FLAG
      IPDS(07)=IBMS    ! BMS FLAG
      IPDS(08)=IPU     ! PARAMETER UNIT ID
      IPDS(09)=ITL     ! TYPE OF LEVEL ID
      IPDS(10)=IL1     ! LEVEL 1 OR 0
      IPDS(11)=IL2     ! LEVEL 2
      IPDS(23)=1 + (IYR-1)/100            ! CENTURY
      IPDS(12)=IYR - 100*(IPDS(23) - 1) ! YEAR
      IPDS(13)=IMO    ! MONTH
      IPDS(14)=IDY    ! DAY
      IPDS(15)=IHR    ! HOUR
      IPDS(16)=0      ! MINUTE
      IPDS(17)=IFTU   ! FORECAST TIME UNIT ID
      IPDS(18)=IP1    ! TIME PERIOD 1
      IPDS(19)=IP2    ! TIME PERIOD 2 OR 0
      IPDS(20)=ITR    ! TIME RANGE INDICATOR
      IPDS(21)=INA    ! NUMBER IN AVERAGE
      IPDS(22)=INM    ! NUMBER MISSING
      IPDS(24)=0      ! RESERVED
      IPDS(25)=IDS    ! DECIMAL SCALING
      IGDS(01)=0      ! NUMBER OF VERTICAL COORDS
      IGDS(02)=255    ! VERTICAL COORD FLAG
      IGDS(03)=IDRT   ! DATA REPRESENTATION TYPE
      IGDS(04)=IM     ! EAST-WEST POINTS
      IGDS(05)=JM     ! NORTH-SOUTH POINTS
      IGDS(06)=LAT1   ! LATITUDE OF ORIGIN
      IGDS(07)=LON1   ! LONGITUDE OF ORIGIN
      IGDS(08)=IRESFL    ! RESOLUTION FLAG
      IGDS(09)=IGDS09    ! LATITUDE OF END OR ORIENTATION
      IGDS(10)=IGDS10    ! LONGITUDE OF END OR DX IN METER ON 60N
      IGDS(11)=IGDS11    ! LAT INCREMENT OR GAUSSIAN LATS OR DY IN METER ON 60N
      IGDS(12)=IGDS12    ! LONGITUDE INCREMENT OR PROJECTION
      IGDS(13)=IGDS13   ! SCANNING MODE OR LAT OF INTERCUT ON EARTH FOR MERCATER
      IGDS(14)=IGDS14    ! NOT USED OR SCANNING MODE FOR MERCATER
      IGDS(15)=0    ! NOT USED 
      IGDS(16)=0    ! NOT USED
      IGDS(17)=0    ! NOT USED
      IGDS(18)=0    ! NOT USED

      IBDS(1)=0   ! BDS FLAGS
      IBDS(2)=0   ! BDS FLAGS
      IBDS(3)=0   ! BDS FLAGS
      IBDS(4)=0   ! BDS FLAGS
      IBDS(5)=0   ! BDS FLAGS
      IBDS(6)=0   ! BDS FLAGS
      IBDS(7)=0   ! BDS FLAGS
      IBDS(8)=0   ! BDS FLAGS
      IBDS(9)=0   ! BDS FLAGS

      NBM=NF
      IF(IBMS.NE.0) THEN
        NBM=0
        DO I=1,NF
          IF(LBM(I)) THEN
            IBM(I)=1
            NBM=NBM+1
          ELSE
            IBM(I)=0
          ENDIF
        ENDDO
        IF(NBM.EQ.NF) IPDS(7)=0
      ENDIF
      IF(NBM.EQ.0) THEN
        DO I=1,NF
          FROUND(I)=0.
        ENDDO
        NBIT=0
      ELSE
!D        CALL GETBIT(IBM,IBS,IDS,LEN,MG,G,GROUND,GMIN,GMAX,NBIT)
!OLD        CALL GTBITS(IPDS(7),IDS,NF,IBM,F,FR,FMIN,FMAX,NBIT)
          IBS = 0
          CALL GETBIT(IBMS,IBS,IDS,NF,IBM,F,FROUND,FMIN,FMAX,NBIT)
        IF(MXBIT.GT.0) NBIT=MIN(NBIT,MXBIT)
      ENDIF
      CALL W3FI72(0,FROUND,0,NBIT,0,IPDS,PDS,
     &            1,255,IGDS,0,0,IBM,NF,IBDS,
     &            NFO,GRIB,LGRIB,IERR)
      RETURN
      END
