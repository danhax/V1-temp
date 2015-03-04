      SUBROUTINE SINT1(N,WAR,WAS,XH,X,IFAC)
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      DIMENSION WAR(*),WAS(*),X(*),XH(*),IFAC(*)
      DATA SQRT3 /1.73205080756887729352D0/
      DO 100 I=1,N
      XH(I) = WAR(I)
      WAR(I) = X(I)
  100 CONTINUE
      IF (N-2) 101,102,103
  101 XH(1) = XH(1)+XH(1)
      GO TO 106
  102 XHOLD = SQRT3*(XH(1)+XH(2))
      XH(2) = SQRT3*(XH(1)-XH(2))
      XH(1) = XHOLD
      GO TO 106
  103 NP1 = N+1
      NS2 = N/2
      X(1) = 0.0D0
      DO 104 K=1,NS2
         KC = NP1-K
         T1 = XH(K)-XH(KC)
         T2 = WAS(K)*(XH(K)+XH(KC))
         X(K+1) = T1+T2
         X(KC+1) = T2-T1
  104 CONTINUE
      MODN = MOD(N,2)
      IF (MODN .NE. 0) X(NS2+2) = 4.0D0*XH(NS2+1)
      CALL RFFTF1 (NP1,X,XH,WAR,IFAC)
      XH(1) = 0.5D0*X(1)
      DO 105 I=3,N,2
         XH(I-1) = -X(I)
         XH(I) = XH(I-2)+X(I-1)
  105 CONTINUE
      IF (MODN .NE. 0) GO TO 106
      XH(N) = -X(N+1)
  106 DO 107 I=1,N
      X(I) = WAR(I)
      WAR(I) = XH(I)
  107 CONTINUE
      RETURN
      END
