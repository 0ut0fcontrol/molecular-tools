program internal_duschinski


    !==============================================================
    ! This code uses of MOLECULAR_TOOLS (version 1.0/March 2012)
    !==============================================================
    !
    ! Version: internal_duschinski_v13
    !
    ! Description:
    ! -----------
    ! Program to analyse vibrations in term of internal coordinates.
    !
    ! NOTES
    ! For vertical, the analysis of the nm displacement can be done:
    !  * in the S-space (internal coordinates). Activated with -vert
    !  * in the Q-space (final state nm). Activated with -vert2
    ! The same convention is used to compute Er
    ! For AH, we always work in the S-space
    !==============================================================


    !*****************
    !   MODULE LOAD
    !*****************
    !============================================
    !   Generic
    !============================================
    use io
    use alerts
    use line_preprocess
    use constants 
    use verbosity
    use matrix
    use matrix_print
    !============================================
    !   Structure types module
    !============================================
    use structure_types
    !============================================
    !   File readers
    !============================================
    use generic_io
    use generic_io_molec
    !============================================
    !  Structure-related modules
    !============================================
    use molecular_structure
    use ff_build
    use atomic_geom
    use symmetry
    !============================================
    !  Internal thingies
    !============================================
    use internal_module
    use zmat_manage 
    use vibrational_analysis

    implicit none

    integer,parameter :: NDIM = 600

    !====================== 
    !Options 
    logical :: use_symmetry=.false.   ,&
               modred=.false.         ,&
               tswitch=.false.        ,&
               symaddapt=.false.      ,&
               vertical=.false.       ,&
               verticalQspace2=.false.,&
               verticalQspace1=.false.,&
               gradcorrectS1=.false.  ,&  
               gradcorrectS2=.false.  ,&
               same_red2nonred_rotation=.true., &
               analytic_Bder=.false., &
               check_symmetry=.true., &
               orthogonalize=.false., &
               original_internal=.false., &
               force_real=.false.
    character(len=4) :: def_internal='all'
    character(len=1) :: reference_frame='F'
    !======================

    !====================== 
    !System variables
    type(str_resmol) :: state1, state2
    integer,dimension(1:NDIM) :: isym
    integer,dimension(4,1:NDIM,1:NDIM) :: Osym
    integer :: Nsym
    integer :: Nat, Nvib, Ns, NNvib
    character(len=5) :: PG
    !Bonded info
    integer,dimension(1:NDIM,1:4) :: bond_s, angle_s, dihed_s
    !====================== 

    !====================== 
    !INTERNAL VIBRATIONAL ANALYSIS
    !MATRICES
    !B and G matrices
    real(8),dimension(NDIM,NDIM) :: B1, B2
    !Other arrays
    real(8),dimension(1:NDIM) :: Grad
    real(8),dimension(1:NDIM,1:NDIM) :: Hess, X, X1inv,X2inv, L1,L2,L1inv, &
                                        Asel1,Asel2,Asel1inv,Asel2inv
    real(8),dimension(1:NDIM,1:NDIM,1:NDIM) :: Bder
    !Duschisky
    real(8),dimension(NDIM,NDIM) :: G1, G2, Jdus
    !T0 - switching effects
    real(8),dimension(3,3) :: T
    !AUXILIAR MATRICES
    real(8),dimension(NDIM,NDIM) :: Aux, Aux2
    !Save definitio of the modes in character
    character(len=100),dimension(NDIM) :: ModeDef
    !VECTORS
    real(8),dimension(NDIM) :: Freq1, Freq2, S1, S2, Vec1, Vec2, Q0, FC
    integer,dimension(NDIM) :: S_sym, bond_sym,angle_sym,dihed_sym
    !Shifts
    real(8),dimension(NDIM) :: Delta
    real(8) :: Delta_p, Er
    !====================== 

    !====================== 
    !
    real(8),dimension(:),allocatable :: A
    integer :: error
    character(len=200) :: msg
    !====================== 

    !====================== 
    !Auxiliar variables
    character(1) :: null
    character(len=16) :: dummy_char
    real(8) :: Theta, Theta2, Theta3
    ! RMZ things
    character :: rm_type
    integer :: rm_zline, Nrm, nbonds_rm, nangles_rm, ndiheds_rm
    integer,dimension(100) :: bond_rm, angle_rm, dihed_rm
    !====================== 

    !=============
    !Counters
    integer :: i,j,k,l, ii,jj,kk, iat, k90,k95,k99, nn, imin, imax,&
               i1,i2,i3,i4, iop
    !=============

    !================
    !I/O stuff 
    !units
    integer :: I_INP=10,  &
               I_ZMAT=11, &
               I_SYM=12,  &
               I_RED=13,  &
               I_ADD=14,  &
               I_AD2=15,  &
               I_RMF=16,  &
               I_CNX=17,  &
               O_DUS=20,  &
               O_DIS=21,  &
               O_DMAT=22, &
               O_DUS2=23, &
               O_DIS2=24, &
               O_STAT=25
    !files
    character(len=10) :: ft ="guess",  ftg="guess",  fth="guess", &
                         ft2 ="guess", ftg2="guess", fth2="guess"
    character(len=200):: inpfile  ="state1.fchk", &
                         gradfile ="same", &
                         hessfile ="same", &
                         inpfile2 ="none", &
                         gradfile2="same", &
                         hessfile2="same", &
                         intfile  ="none", &
                         rmzfile  ="none", &
                         symm_file="none", &
                         cnx_file="guess"
    !status
    integer :: IOstatus
    !===================

    !===================
    !CPU time 
    real(8) :: ti, tf
    !===================

! (End of variables declaration) 
!==================================================================================

    call cpu_time(ti)

    !--------------------------
    ! Tune io
    !--------------------------
    ! Set unit for alert messages
    alert_unt=6
    !--------------------------

    ! 0. GET COMMAND LINE ARGUMENTS
    call parse_input(inpfile,ft,hessfile,fth,gradfile,ftg,&
                     inpfile2,ft2,hessfile2,fth2,gradfile2,ftg2,&
                     intfile,rmzfile,def_internal,use_symmetry,cnx_file, &
!                    tswitch,
                     symaddapt,same_red2nonred_rotation,analytic_Bder,&
                     vertical,verticalQspace2,verticalQspace1,&
                     gradcorrectS1,gradcorrectS2,&
                     orthogonalize,original_internal,force_real,reference_frame)
    call set_word_upper_case(def_internal)
    call set_word_upper_case(reference_frame)

    ! 1. INTERNAL VIBRATIONAL ANALYSIS ON STATE1 AND STATE2

    !===========
    !State 1
    !===========
    if (verbose>0) then
        print*, ""
        print*, "=========="
        print*, " STATE 1"
        print*, "=========="
    endif
 
    ! READ DATA (each element from a different file is possible)
    ! ---------------------------------
    !Guess filetypes
    if (ft == "guess") &
    call split_line_back(inpfile,".",null,ft)
    if (fth == "guess") &
    call split_line_back(hessfile,".",null,fth)
    if (ftg == "guess") &
    call split_line_back(gradfile,".",null,ftg)

    ! STRUCTURE FILE
    open(I_INP,file=inpfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile)) )
    call generic_strmol_reader(I_INP,ft,state1,error)
    if (error /= 0) call alert_msg("fatal","Error reading geometry (State1)")
    close(I_INP)
    ! Shortcuts
    Nat = state1%natoms

    ! HESSIAN FILE
    open(I_INP,file=hessfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(hessfile)) )
    allocate(A(1:3*Nat*(3*Nat+1)/2))
    call generic_Hessian_reader(I_INP,fth,Nat,A,error) 
    if (error /= 0) call alert_msg("fatal","Error reading Hessian (State1)")
    close(I_INP)
    ! Run vibrations_Cart to get the number of Nvib (to detect linear molecules)
    call vibrations_Cart(Nat,state1%atom(:)%X,state1%atom(:)%Y,state1%atom(:)%Z,state1%atom(:)%Mass,A,&
                         Nvib,L1,Freq1,error_flag=error)
    k=0
    do i=1,3*Nat
    do j=1,i
        k=k+1
        Hess(i,j) = A(k)
        Hess(j,i) = A(k)
    enddo 
    enddo
    deallocate(A)

    if (gradcorrectS1) then
        ! GRADIENT FILE
        open(I_INP,file=gradfile,status='old',iostat=IOstatus)
        if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(gradfile)) )
        call generic_gradient_reader(I_INP,ftg,Nat,Grad,error)
        close(I_INP)
    endif


    ! MANAGE INTERNAL COORDS
    ! ---------------------------------
    ! Get connectivity 
    if (cnx_file == "guess") then
        call guess_connect(state1)
    else
        print'(/,A,/)', "Reading connectivity from file: "//trim(adjustl(cnx_file))
        open(I_CNX,file=cnx_file,status='old')
        call read_connect(I_CNX,state1)
        close(I_CNX)
    endif

    ! Manage symmetry
    if (.not.use_symmetry) then
        state1%PG="C1"
    else if (trim(adjustl(symm_file)) /= "none") then
        msg = "Using custom symmetry file: "//trim(adjustl(symm_file)) 
        call alert_msg("note",msg)
        open(I_SYM,file=symm_file)
        do i=1,state1%natoms
            read(I_SYM,*) j, isym(j)
        enddo
        close(I_SYM)
        !Set PG to CUStom
        state1%PG="CUS"
    else
        state1%PG="XX"
        call symm_atoms(state1,isym)
    endif

    !Generate bonded info
    call gen_bonded(state1)

    ! Define internal set
    call define_internal_set(state1,def_internal,intfile,rmzfile,use_symmetry,isym, S_sym,Ns)

    !From now on, we'll use atomic units
    call set_geom_units(state1,"Bohr")


    ! INTERNAL COORDINATES

    !SOLVE GF METHOD TO GET NM AND FREQ
    call internal_Wilson(state1,Ns,S1,B1,ModeDef)
    call internal_Gmetric(Nat,Ns,state1%atom(:)%mass,B1,G1)
    if (gradcorrectS1) then
!         call NumBder(state1,Ns,Bder)
        call calc_BDer(state1,Ns,Bder,analytic_Bder)
    endif

    ! SET REDUNDANT/SYMETRIZED/CUSTOM INTERNAL SETS
!     if (symaddapt) then (implement in an analogous way as compared with the transformation from red to non-red
    if (original_internal.and.Nvib==Ns) then
        print*, "Using internal without linear combination"
        Asel1(1:Ns,1:Nvib) = 0.d0
        do i=1,Nvib
            Asel1(i,i) = 1.d0 
        enddo
        Asel1inv(1:Nvib,1:Ns) = Asel1(1:Ns,1:Nvib)
    else
        print*, "Using internal from eigevectors of G"
        call redundant2nonredundant(Ns,Nvib,G1,Asel1)
        ! Rotate Gmatrix
        G1(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Ns,Asel1(1:Ns,1:Nvib),G1,&
                                            counter=.true.)
        ! Check if we want orthogonalization
        if (orthogonalize) then
            print*, "Orthogonalyzing state1 internals..."
            X1inv(1:Nvib,1:Nvib) = 0.d0
            X(1:Nvib,1:Nvib)     = 0.d0
            do i=1,Nvib
                X1inv(i,i) = 1.d0/dsqrt(G1(i,i))
                X(i,i)     = dsqrt(G1(i,i))
            enddo
            ! Rotate Gmatrix (again)
            G1(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Nvib,X1inv(1:Nvib,1:Nvib),G1)
            ! Update Asel(inv)
            Asel1inv(1:Nvib,1:Ns) = matrix_product(Nvib,Ns,Nvib,X1inv,Asel1,tB=.true.)
            Asel1(1:Ns,1:Nvib)    = matrix_product(Ns,Nvib,Nvib,Asel1,X)
        else
            Asel1inv(1:Nvib,1:Ns) = transpose(Asel1(1:Ns,1:Nvib))
        endif
        ! Rotate Bmatrix
        B1(1:Nvib,1:3*Nat) = matrix_product(Nvib,3*Nat,Ns,Asel1inv,B1)
        ! Rotate Bders
        if (gradcorrectS1) then
            do j=1,3*Nat
                Bder(1:Nvib,j,1:3*Nat) =  matrix_product(Nvib,3*Nat,Ns,Asel1inv,Bder(1:Ns,j,1:3*Nat))
            enddo
        endif
    endif

    if (gradcorrectS1) then
        call HessianCart2int(Nat,Nvib,Hess,state1%atom(:)%mass,B1,G1,Grad,Bder)
        if (check_symmetry) then
            print'(/,X,A)', "---------------------------------------"
            print'(X,A  )', " Check effect of symmetry operations"
            print'(X,A  )', " on the correction term gs^t\beta"
            print'(X,A  )', "---------------------------------------"
            state1%PG="XX"
            call symm_atoms(state1,isym,Osym,rotate=.false.,nsym_ops=nsym)
            ! Check the symmetry of the correction term
            ! First compute the correction term
            do i=1,3*Nat
            do j=1,3*Nat
                Aux2(i,j) = 0.d0
                do k=1,Nvib
                    Aux2(i,j) = Aux2(i,j) + Bder(k,i,j)*Grad(k)
                enddo
            enddo
            enddo
            ! Print if verbose level is high
            if (verbose>2) &
                call MAT0(6,Aux2,3*Nat,3*Nat,"gs*Bder matrix")
            ! Check all detected symmetry ops
            do iop=1,Nsym
                Aux(1:3*Nat,1:3*Nat) = dfloat(Osym(iop,1:3*Nat,1:3*Nat))
                Aux(1:3*Nat,1:3*Nat) = matrix_basisrot(3*Nat,3*Nat,Aux,Aux2,counter=.true.)
                Theta=0.d0
                do i=1,3*Nat 
                do j=1,3*Nat 
                    if (Theta < abs(Aux(i,j)-Aux2(i,j))) then
                        Theta = abs(Aux(i,j)-Aux2(i,j))
                        Theta2=Aux2(i,j)
                    endif
                enddo
                enddo
                print'(X,A,I0)', "Symmetry operation :   ", iop
                print'(X,A,F10.6)',   " Max abs difference : ", Theta
                print'(X,A,F10.6,/)', " Value before sym op: ", Theta2
            enddo
            print'(X,A,/)', "---------------------------------------"
        endif
    else
        call HessianCart2int(Nat,Nvib,Hess,state1%atom(:)%mass,B1,G1)
        ! We need Grad in internal coordinates as well (ONLY IF HessianCart2int DOES NOT INCLUDE IT)
        call Gradcart2int(Nat,Nvib,Grad,state1%atom(:)%mass,B1,G1)
    endif
    call gf_method(Nvib,G1,Hess,L1,Freq1,X,X1inv)
    if (verbose>0) then
        ! Analyze normal modes in terms of the redundant set
! always do redundant2nonredundant
!         if (Nvib<Ns) then
            Aux(1:Ns,1:Nvib) = matrix_product(Ns,Nvib,Nvib,Asel1,L1)
!         else
!             Aux(1:Ns,1:Nvib) = L1(1:Ns,1:Nvib)
!         endif
        if (use_symmetry) then
            call analyze_internal(Nvib,Ns,Aux,Freq1,ModeDef,S_sym)
        else
            call analyze_internal(Nvib,Ns,Aux,Freq1,ModeDef)
        endif
    endif

    ! If only one state is give, exit now
    if (adjustl(inpfile2) == "none") stop

    !===========
    !State 2
    !===========
    if (verbose>0) then
        print*, ""
        print*, "=========="
        print*, " STATE 2"
        print*, "=========="
    endif
 
    ! READ DATA (each element from a different file is possible)
    ! ---------------------------------
    !Guess filetypes
    if (ft2 == "guess") &
    call split_line_back(inpfile2,".",null,ft2)
    if (fth2 == "guess") &
    call split_line_back(hessfile2,".",null,fth2)
    if (ftg2 == "guess") &
    call split_line_back(gradfile2,".",null,ftg2)

    ! STRUCTURE FILE
    open(I_INP,file=inpfile2,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile2)) )
    call generic_strmol_reader(I_INP,ft2,state2,error)
    if (error /= 0) call alert_msg("fatal","Error reading geometry (State2)")
    close(I_INP)
    ! Check that the structure is that of the State1 if vertical is used
    if (vertical) then
        call set_geom_units(state1,"Angs")
        Theta2=0.d0
        Theta3=0.d0
        do i=1,state1%natoms
            Theta  = calc_atm_dist(state1%atom(i),state2%atom(i))
            Theta2 = Theta2 + (Theta)**2
            Theta3 = max(Theta3,Theta)
        enddo
        Theta = sqrt(Theta2/state1%natoms)
        if (Theta3>1.d-4) then
            print'(X,A,X,F8.3)  ', "RMSD_struct (AA):", Theta
            print'(X,A,X,E10.3,/)', "Max Dist", Theta3
            call alert_msg("warning","vertical model is requested but State1 and State2 do not have the same structure")
        endif
        call set_geom_units(state1,"Bohr")
    endif
    ! Shortcuts
    if (Nat /= state2%natoms) call alert_msg("fatal","Initial and final states don't have the same number of atoms.")

    ! HESSIAN FILE
    open(I_INP,file=hessfile2,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(hessfile2)) )
    allocate(A(1:3*Nat*(3*Nat+1)/2))
    call generic_Hessian_reader(I_INP,fth2,Nat,A,error) 
    if (error /= 0) call alert_msg("fatal","Error reading Hessian (State2)")
    close(I_INP)
    ! Run vibrations_Cart to get the number of Nvib (to detect linear molecules)
    call vibrations_Cart(Nat,state2%atom(:)%X,state2%atom(:)%Y,state2%atom(:)%Z,state2%atom(:)%Mass,A,&
                         NNvib,L2,Freq2,error_flag=error)
    if (NNvib /= 3*Nat-6) call alert_msg("warning","Linear molecule (at state2). Things can go very bad.")
    if (NNvib > Nvib) then
        print'(/,A,/)', "Using reduced space from State1"
    endif
    k=0
    do i=1,3*Nat
    do j=1,i
        k=k+1
        Hess(i,j) = A(k)
        Hess(j,i) = A(k)
    enddo 
    enddo
    deallocate(A)

    if (vertical.or.gradcorrectS2) then
        ! GRADIENT FILE
        open(I_INP,file=gradfile2,status='old',iostat=IOstatus)
        if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(gradfile2)) )
        call generic_gradient_reader(I_INP,ftg2,Nat,Grad,error)
        if (error /= 0) call alert_msg("fatal","Error reading gradient (State2)")
        close(I_INP)
    endif


    ! MANAGE INTERNAL COORDS
    ! ---------------------------------
    ! Get connectivity 
    if (cnx_file == "guess") then
        call guess_connect(state2)
    else
        print'(/,A,/)', "Reading connectivity from file: "//trim(adjustl(cnx_file))
        open(I_CNX,file=cnx_file,status='old')
        call read_connect(I_CNX,state2)
        close(I_CNX)
    endif

    ! Manage symmetry
    if (.not.use_symmetry) then
        state2%PG="C1"
    else if (trim(adjustl(symm_file)) /= "none") then
        msg = "Using custom symmetry file: "//trim(adjustl(symm_file)) 
        call alert_msg("note",msg)
        open(I_SYM,file=symm_file)
        do i=1,state2%natoms
            read(I_SYM,*) j, isym(j)
        enddo
        close(I_SYM)
        !Set PG to CUStom
        state2%PG="CUS"
    else
        state2%PG="XX"
        call symm_atoms(state2,isym)
    endif
    if (state1%PG /= state2%PG) then
        if (.not.use_symmetry) then
            call alert_msg("note","Initial and final state have different symmetry")
        else
            call alert_msg("warning","Initial and final state have different symmetry")
        endif
    endif

    !Generate bonded info
    call gen_bonded(state2)

    ! Define internal set => taken from state1
    state2%geom = state1%geom

    !From now on, we'll use atomic units
    call set_geom_units(state2,"Bohr")


    ! INTERNAL COORDINATES

    !SOLVE GF METHOD TO GET NM AND FREQ
    call internal_Wilson(state2,Ns,S2,B2,ModeDef)
    call internal_Gmetric(Nat,Ns,state2%atom(:)%mass,B2,G2)
    if (gradcorrectS2) then
!         call NumBder(state2,Ns,Bder)
        call calc_BDer(state2,Ns,Bder,analytic_Bder)
    endif
    ! Handle redundant/symtrized sets
!     if (symaddapt) then (implement in an analogous way as compared with the transformation from red to non-red
    if (original_internal.and.Nvib==Ns) then
        print*, "Using internal without linear combination"
        Asel2(1:Ns,1:Nvib) = 0.d0
        do i=1,Nvib
            Asel2(i,i) = 1.d0 
        enddo
        Asel2inv(1:Nvib,1:Ns) = Asel2(1:Ns,1:Nvib)
    else
        if (same_red2nonred_rotation) then
            print*, "Using internal from eigevectors of G (state1)"
            ! Using Asel1 (from state1)
            Asel2(1:Ns,1:Nvib) = Asel1(1:Ns,1:Nvib)
            Asel2inv(1:Nvib,1:Ns) = Asel1inv(1:Nvib,1:Ns)
            ! Rotate Gmatrix
            G2(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Ns,Asel2inv(1:Nvib,1:Ns),G2)
        else
            print*, "Using internal from eigevectors of G (state2)"
            call redundant2nonredundant(Ns,Nvib,G2,Asel2)
            ! Rotate Gmatrix
            G2(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Ns,Asel2(1:Ns,1:Nvib),G2,&
                                                counter=.true.)
            if (orthogonalize) then
                print*, "Orthogonalyzing state2 internals..."
                X2inv(1:Nvib,1:Nvib) = 0.d0
                X(1:Nvib,1:Nvib)     = 0.d0
                do i=1,Nvib
                    X2inv(i,i) = 1.d0/dsqrt(G2(i,i))
                    X(i,i)     = dsqrt(G2(i,i))
                enddo
                ! Rotate Gmatrix (again)
                G2(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Nvib,X2inv(1:Nvib,1:Nvib),G2)
                ! Update Asel(inv)
                Asel2inv(1:Nvib,1:Ns) = matrix_product(Nvib,Ns,Nvib,X2inv,Asel2,tB=.true.)
                Asel2(1:Ns,1:Nvib)    = matrix_product(Ns,Nvib,Nvib,Asel2,X)
            else
                Asel2inv(1:Nvib,1:Ns) = transpose(Asel2(1:Ns,1:Nvib))
            endif
        endif
        ! Rotate Bmatrix
        B2(1:Nvib,1:3*Nat) = matrix_product(Nvib,3*Nat,Ns,Asel2inv,B2)
        ! Rotate Bders
        if (gradcorrectS2) then
            do j=1,3*Nat
                Bder(1:Nvib,j,1:3*Nat) =  matrix_product(Nvib,3*Nat,Ns,Asel2inv,Bder(1:Ns,j,1:3*Nat))
            enddo
        endif
    endif

    if (gradcorrectS2) then
        call HessianCart2int(Nat,Nvib,Hess,state2%atom(:)%mass,B2,G2,Grad,Bder)
        if (check_symmetry) then
            print'(/,X,A)', "---------------------------------------"
            print'(X,A  )', " Check effect of symmetry operations"
            print'(X,A  )', " on the correction term gs^t\beta"
            print'(X,A  )', "---------------------------------------"
            state2%PG="XX"
            call symm_atoms(state2,isym,Osym,rotate=.false.,nsym_ops=nsym)
            ! Check the symmetry of the correction term
            ! First compute the correction term
            do i=1,3*Nat
            do j=1,3*Nat
                Aux2(i,j) = 0.d0
                do k=1,Nvib
                    Aux2(i,j) = Aux2(i,j) + Bder(k,i,j)*Grad(k)
                enddo
            enddo
            enddo
            ! Print if verbose level is high
            if (verbose>2) &
                call MAT0(6,Aux2,3*Nat,3*Nat,"gs*Bder matrix")
            ! Check all detected symmetry ops
            do iop=1,Nsym
                Aux(1:3*Nat,1:3*Nat) = dfloat(Osym(iop,1:3*Nat,1:3*Nat))
                Aux(1:3*Nat,1:3*Nat) = matrix_basisrot(3*Nat,3*Nat,Aux,Aux2,counter=.true.)
                Theta=0.d0
                do i=1,3*Nat 
                do j=1,3*Nat 
                    if (Theta < abs(Aux(i,j)-Aux2(i,j))) then
                        Theta = abs(Aux(i,j)-Aux2(i,j))
                        Theta2=Aux2(i,j)
                    endif
                enddo
                enddo
                print'(X,A,I0)', "Symmetry operation :   ", iop
                print'(X,A,F10.6)',   " Max abs difference : ", Theta
                print'(X,A,F10.6,/)', " Value before sym op: ", Theta2
            enddo
            print'(X,A,/)', "---------------------------------------"
        endif
    else
        call HessianCart2int(Nat,Nvib,Hess,state2%atom(:)%mass,B2,G2)
        ! We need Grad in internal coordinates as well (ONLY IF HessianCart2int DOES NOT INCLUDE IT)
        call Gradcart2int(Nat,Nvib,Grad,state2%atom(:)%mass,B2,G2)
    endif
    call gf_method(Nvib,G2,Hess,L2,Freq2,X,X2inv)
    if (verbose>0) then
        ! Analyze normal modes in terms of the redundant set
! always do redundant2nonredundant
!         if (Nvib<Ns) then
            Aux(1:Ns,1:Nvib) = matrix_product(Ns,Nvib,Nvib,Asel2,L2)
!         else
!             Aux(1:Ns,1:Nvib) = L2(1:Ns,1:Nvib)
!         endif
        if (use_symmetry) then
            call analyze_internal(Nvib,Ns,Aux,Freq2,ModeDef,S_sym)
        else
            call analyze_internal(Nvib,Ns,Aux,Freq2,ModeDef)
        endif
    endif


    !==========================================
    ! CHECKS ON THE INTERNAL SETS
    !==========================================
    ! Evaluate orthogonality
    if (verbose>0) then
     print'(2/,X,A)', "============================================"
     print*,          " Internal Coordinates Orthogonality Checks  "
     print*,          "============================================"
     print*,          "Analysing: D = G1^1/2 G2^1/2"
    endif
    Aux(1:Nvib,1:Nvib) = matrix_product(Nvib,Nvib,Nvib,X1inv,X)
    open (O_DMAT,file="D_matrix_abs.dat",status="replace")
    do i=1,Nvib
        write(O_DMAT,'(600f8.2)') dabs(Aux(i,1:Nvib))
    enddo
    close(O_DMAT)
    open (O_DMAT,file="D_matrix.dat",status="replace")
    do i=1,Nvib
        write(O_DMAT,'(600f8.2)') Aux(i,1:Nvib)
    enddo
    close(O_DMAT)
    if (verbose>0) &
     print'(X,A,/)', "(D matrix written to files: D_matrix.dat and D_matrix_abs.dat)"
    
    if (verbose>0) then
        ! COMPUTE DETERMINANT AND TRACE OF D_matrix
        theta = 0.d0
        do i=1,Nvib
            theta = theta+Aux(i,i)
        enddo    
        print'(X,A,F8.2,A,I0,A)', "Trace", theta, "  (",Nvib,")"
        theta = -100.d0  !max
        theta2 = 100.d0  !min
        do i=1,Nvib
            if (Aux(i,i) > theta) then
                theta = Aux(i,i)
                imax = i
            endif
            if (Aux(i,i) < theta2) then
                theta2 = Aux(i,i)
                imin = i
            endif
        enddo 
        print*, "Min diagonal", theta2, trim(adjustl(ModeDef(imin)))
        print*, "Max diagonal", theta,  trim(adjustl(ModeDef(imax)))
        theta = -100.d0  !max
        theta2 = 100.d0  !min
        theta3 = 0.d0
        k=0
        do i=1,Nvib
        do j=1,Nvib
            if (i==j) cycle
            k=k+1
            theta3 = theta3 + dabs(Aux(i,j))
            theta  = max(theta, Aux(i,j))
            theta2 = min(theta2,Aux(i,j))
        enddo
        enddo 
        print*, "Min off-diagonal", theta2    
        print*, "Max off-diagonal", theta
        print*, "AbsDev off-diagonal sum", theta3
        print*, "AbsDev off-diagonal per element", theta3/dfloat(k)
        theta = determinant_realgen(Nvib,Aux)
        print*, "Determinant", theta
        print*, "-------------------------------------------------------"
        print*, ""
    endif


    ! ===========================================
    ! COMPUTE DUSCHINSKY MATRIX AND DISPLACEMENT VECTOR 
    ! ===========================================
    !--------------------------
    ! J-matrix (Duschinski)
    !--------------------------
    ! Orthogonal Duschinski (from orthogonalized ICs. Not used in this version)
    ! Get orthogonal modes:  L' = G^-1/2 L
    Aux(1:Nvib,1:Nvib)  = matrix_product(Nvib,Nvib,Nvib,X1inv,L1)
    Aux2(1:Nvib,1:Nvib) = matrix_product(Nvib,Nvib,Nvib,X2inv,L2)
    ! Duschinsky matrix (orth) stored in JdusO = L1'^t L2'
!     JdusO(1:Nvib,1:Nvib) = matrix_product(Nvib,Nvib,Nvib,Aux,Aux2,tA=.true.)
    !Store L1' in Aux2 to later be used to get the displacement
    Aux2(1:Nvib,1:Nvib)=Aux(1:Nvib,1:Nvib)

    ! Non-Orthogonal Duschinski (the one we use)
    if (verbose>0) &
     print*, "Calculating Duschisky..."
    !Inverse of L1 (and store in L1inv)
    L1inv(1:Nvib,1:Nvib) = inverse_realgen(Nvib,L1(1:Nvib,1:Nvib))
    ! Account for different rotations to non-redundant set 
    ! but preserve the inverse L1 matrix in L1
! always do redundant2nonredundant
!     if (Nvib<Ns .and. .not.same_red2nonred_rotation) then
    if (.not.same_red2nonred_rotation) then
        ! We need to include the fact that Asel1 /= Asel2, i.e.,
        ! rotate to the same redundant space L(red) = Asel * L(non-red)
        ! J = L1^-1 A1^-1 A2 L2
        ! so store in Aux the following part: [L1^-1 A1^-1 A2]
        Aux(1:Nvib,1:Nvib) = matrix_product(Nvib,Nvib,Ns,Asel1inv,Asel2)
        Aux(1:Nvib,1:Nvib) = matrix_product(Nvib,Nvib,Nvib,L1inv,Aux)
    else
        Aux(1:Nvib,1:Nvib) = L1inv(1:Nvib,1:Nvib)
    endif
    !J = L1^-1 [A1^t A2] L2 (stored in J).
    Jdus(1:Nvib,1:Nvib) = matrix_product(Nvib,Nvib,Nvib,Aux,L2)


    !--------------------------
    ! ICs displacement
    !--------------------------
    if (verbose>0) then
        print*, ""
        print*, "=========================="
        print*, " SHIFTS (internal coord)"
        print*, "=========================="
    endif
    if (vertical) then
        print*, "Vertical model"
        ! GET MINIMUM IN INTERNAL COORDINATES
        ! At this point
        !  * Hess has the Hessian  of State2 in internal coords (output from HessianCart2int)
        !  * Grad has the gradient of State2 in internal coords (output from HessianCart2int)
        ! Inverse of the Hessian
        Aux(1:Nvib,1:Nvib) = inverse_realgen(Nvib,Hess)
        ! DeltaS0 = -Hs^1 * gs
        do i=1,Nvib
            Delta(i)=0.d0
            do k=1,Nvib
                Delta(i) = Delta(i)-Aux(i,k) * Grad(k)
            enddo 
        enddo
! always do redundant2nonredundant
!         if (Nvib<Ns) then
            !Transform Delta' into Delta (for control purposes only)
            ! Delta = A Delta'
            do i=1,Ns
                Vec1(i) = 0.d0
                do k=1,Nvib
                    Vec1(i) = Vec1(i) + Asel1(i,k)*Delta(k)
                enddo
            enddo
!         else
!             Vec1(1:Nvib)=Delta(1:Nvib)
!         endif

        ! Get coordinates
        do i=1,Ns
            S2(i) = S1(i) + Vec1(i)
        enddo

    else ! Adiabatic case
        print*, "Adiabatic model"
        ! Bonds
        do i=1,state1%geom%nbonds
            Delta(i) = S2(i)-S1(i)
        enddo
        ! Angles
        do j=i,i+state1%geom%nangles-1
            Delta(j) = S2(j)-S1(j)
        enddo
        ! Dihedrals
        do k=j,j+state1%geom%ndihed-1
            Delta(k) = S2(k)-S1(k)
            Delta_p = S2(k)-S1(k)+2.d0*PI
            if (dabs(Delta_p) < dabs(Delta(k))) Delta(k)=Delta_p
            Delta_p = S2(k)-S1(k)-2.d0*PI
            if (dabs(Delta_p) < dabs(Delta(k))) Delta(k)=Delta_p
        enddo
        ! Impropers
        do i=k,k+state1%geom%nimprop-1
            Delta(i) = S2(i)-S1(i)
            Delta_p = S2(i)-S1(i)+2.d0*PI
            if (dabs(Delta_p) < dabs(Delta(i))) Delta(i)=Delta_p
            Delta_p = S2(i)-S1(i)-2.d0*PI
            if (dabs(Delta_p) < dabs(Delta(i))) Delta(i)=Delta_p
        enddo

        ! Store Deltas into the auxiliar vector Vec1
        Vec1(1:Ns) = Delta(1:Ns)
! always do redundant2nonredundant
!         if (Nvib<Ns) then
            ! Need to transform Deltas into the non-redundant coordinates set
            ! Delta' = A^-1 Delta
            do i=1,Nvib
                Vec2(i) = 0.d0
                do k=1,Ns
                    Vec2(i) = Vec2(i) + Asel1inv(i,k)*Delta(k)
                enddo
            enddo
            Delta(1:Nvib) = Vec2(1:Nvib)
!         endif

    endif

    if (verbose>0) then
        print*, "List of ICs and Deltas"
        if (state1%geom%nbonds /= 0) &
         print'(X,A,/,X,A)', "Bonds (Angs)",&
                             "  IC   Description      State2    State1     Delta"
        do i=1,state1%geom%nbonds
            print'(I5,X,A,X,3(F8.3,2X))', i,trim(ModeDef(i)),S2(i)*BOHRtoANGS,S1(i)*BOHRtoANGS,Vec1(i)*BOHRtoANGS
        enddo
        if (state1%geom%nangles /= 0) &
         print'(X,A,/,X,A)', "Angles (deg)",&
                             "  IC   Description                State2    State1     Delta"
        do j=i,i+state1%geom%nangles-1
            print'(I5,X,A,X,3(F8.2,2X))', j, trim(ModeDef(j)), S2(j)*180.d0/PI,S1(j)*180.d0/PI,Vec1(j)*180.d0/PI
        enddo
        if (state1%geom%ndihed /= 0) &
         print'(X,A,/,X,A)', "Dihedrals (deg)",&
                             "  IC   Description                          State2    State1     Delta"
        do k=j,j+state1%geom%ndihed-1
            print'(I5,X,A,X,3(F8.2,2X))', k, trim(ModeDef(k)), S2(k)*180.d0/PI,S1(k)*180.d0/PI,Vec1(k)*180.d0/PI
        enddo
        if (state1%geom%nimprop /= 0) &
         print'(X,A,/,X,A)', "Impropers (deg)",&
                             "  IC   Description                          State2    State1     Delta"
        do i=k,k+state1%geom%nimprop-1
            print'(I5,X,A,X,3(F8.2,2X))', i, trim(ModeDef(i)), S2(i)*180.d0/PI,S1(i)*180.d0/PI,Vec1(i)*180.d0/PI
        enddo
    endif


    !--------------------------
    ! K-vector (NM-shifts)
    !--------------------------
    if (verticalQspace2) then 
        ! Apply vertical model in the Qspace (get S2 equilibrium --Delta-- within the normal mode coordinate space)
        ! 
        ! K = -J * Lambda_f^-1 * L2^t * gs
        ! Convert Freq into FC. Store in FC for future use
        do i=1,Nvib
            FC(i) = sign((Freq2(i)*2.d0*pi*clight*1.d2)**2/HARTtoJ*BOHRtoM**2*AUtoKG,Freq2(i))
        enddo
        ! Lambda_f^-1 * L2^t
        do i=1,Nvib
            Aux(i,1:Nvib) = L2(1:Nvib,i) / FC(i)
        enddo
        ! -[Lambda_f^-1 * L2^t] * gs
        do i=1,Nvib
            Q0(i)=0.d0
            do k=1,Nvib
                Q0(i) = Q0(i) - Aux(i,k) * Grad(k)
            enddo
            ! Change imag to real if requested. This is done now, once the shift was computed
            ! So the displacement is anyway computed towards the stationary point of the quadratic PES
            ! It would be equivalent to also change the gradient if we did the change imag to real before 
            ! this point (hence the warning message)
            if (FC(i)<0) then
                print*, i, FC(i), Freq2(i)
                if (force_real) then 
                    FC(i)    = abs(FC(i))
                    Freq2(i) = abs(Freq2(i))
                    call alert_msg("warning","Negative FC turned real (Gradient also changed)")
                else
                    call alert_msg("warning","A negative FC found")
                endif
            endif
        enddo
        ! J * [-Lambda_f^-1 * L2^t * gs]
        do i=1,Nvib
            Vec1(i)=0.d0
            do k=1,Nvib
                Vec1(i) = Vec1(i) + Jdus(i,k) * Q0(k)
            enddo
        enddo

    elseif (verticalQspace1) then 
        ! Use the same strategy as in the Cartesian case: 1) normal modes at State1; 2) Rotate normal modes
        ! At this point
        !  * Hess has the Hessian  of State2 in internal coords (output from HessianCart2int)
        !  * Grad has the gradient of State2 in internal coords (output from HessianCart2int)
        !
        ! Rotate to Q1-space (IC)
        !
        ! HESIAN
        !  H_Q' = L^t Hs L (also H_Q' = L^-1 G Hs L)
        ! Note:
        !  * L1 contains the normal matrix (now the inverse is in L1inv)
        Hess(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Nvib,L1,Hess,counter=.true.)
        !
        ! GRADIENT
        !  g_Q' = L^t gs
        do i=1,Nvib
            Vec1(i) = 0.d0
            do k=1,Nvib
                Vec1(i) = Vec1(i) + Aux2(k,i) * Grad(k)
            enddo
        enddo
        Grad(1:Nvib) = Vec1

        ! Diagonalize Hessian in Q1-space to get State2 FC and Duschinski rotation
        call diagonalize_full(Hess(1:Nvib,1:Nvib),Nvib,Jdus(1:Nvib,1:Nvib),FC(1:Nvib),"lapack")
        Freq2(1:Nvib) = FC2Freq(Nvib,FC)
        call print_vector(6,Freq2,Nvib,"Frequencies (cm-1) -- from Q1-space")

        ! Get shift vector (also compute Qo'')
        ! First compute Qo''
        ! Q0 = - FC^-1 * J^t * gQ
        do i=1,Nvib
            Q0(i) = 0.d0
            do k=1,Nvib
                Q0(i) = Q0(i) - Jdus(k,i) * Grad(k)
            enddo
            Q0(i) = Q0(i) / FC(i)
            ! Change imag to real if requested. This is done now, once the shift was computed
            ! So the displacement is anyway computed towards the stationary point of the quadratic PES
            ! It would be equivalent to also change the gradient if we did the change imag to real before 
            ! this point (hence the warning message)
            if (FC(i)<0) then
                print*, i, FC(i), Freq2(i)
                if (force_real) then 
                    FC(i)    = abs(FC(i))
                    Freq2(i) = abs(Freq2(i))
                    call alert_msg("warning","Negative FC turned real (Gradient also changed)")
                else
                    call alert_msg("warning","A negative FC found")
                endif
             endif
        enddo
        if (verbose>2) then
            call print_vector(6,FC*1e5,Nvib,"FC - int")
            call print_vector(6,Grad*1e5,Nvib,"Grad - int")
            call print_vector(6,Q0,Nvib,"Q0 - int")
        endif
        ! K = J * Q0
        do i=1,Nvib
            Vec1(i) = 0.d0
            do k=1,Nvib
                Vec1(i) = Vec1(i) + Jdus(i,k) * Q0(k)
            enddo
        enddo

    else
        ! K = L1^-1 DeltaS (this is State 1 respect to state 2) . 
        ! Notes
        !   * L1inv stores the inverse
        !   * Delta in non-redundant IC set
        do i=1,Nvib
            Vec1(i) = 0.d0
            do k=1,Nvib
                Vec1(i) = Vec1(i) + L1inv(i,k)*Delta(k)
            enddo
        enddo
!         !Orthogonal: K=L1'^t DeltaS'
!         do i=1,Nvib
!             Vec2(i) = 0.d0
!             do k=1,Nvib
!                 Vec2(i) = Vec1(i) + Aux2(k,i)*Delta(k)
!             enddo
!         enddo
    endif

    if (verbose>2) then
        call MAT0(6,Jdus,Nvib,Nvib,"DUSCHINSKI MATRIX")
        call print_vector(6,Vec1,Nvib,"NORMAL MODE SHIFT")
    endif

    !Analyze Duschinsky matrix
    call analyze_duschinsky(6,Nvib,Jdus,Vec1,Freq1,Freq2)


    !===================================
    ! Reorganization energy
    !===================================
    print'(/,X,A)', "REORGANIZATION ENERGY"
    if (verticalQspace2) then
        print*, "Vertical model / Q2space"
        ! Normal-mode space
        ! Er = -L2^t gs * Q0 - 1/2 * Q0^t * Lambda_f * Q0
        ! At this point: 
        ! * Grad: in internal coords
        ! * Q0: DeltaQ in final state nm
        ! * FC: diagonal force constants for final state
        Er = 0.d0
        do i=1,Nvib
            ! Compute gQ(i) = L2^t * gs
            Theta = 0.d0
            do j=1,Nvib
                Theta =  Theta + L2(j,i)*Grad(j)
            enddo
            Er = Er - Theta * Q0(i) - 0.5d0 * FC(i) * Q0(i)**2
        enddo
    elseif (verticalQspace1) then
        print*, "Vertical model / Q1space"
        ! Normal-mode space
        ! Er = -L2^t gs * Q0 - 1/2 * Q0^t * Lambda_f * Q0
        ! At this point: 
        ! * Grad: in Q1-space
        ! * Q0: DeltaQ in final state nm
        ! * FC: diagonal force constants for final state
        Er = 0.d0
        do i=1,Nvib
            ! Get gradient in state2 Qspace
            ! gQ2 = J^t * gQ1
            Theta=0.d0
            do k=1,Nvib
                Theta = Theta + Jdus(k,i) * Grad(k)
            enddo
            Er = Er - Theta * Q0(i) - 0.5d0 * FC(i) * Q0(i)**2
        enddo
    elseif (vertical) then
        print*, "Vertical model / IC space"
        ! Internal-coordinates space
        ! Er = -gs * DeltaS - 1/2 DeltaS^t * Hs * DeltaS
        ! At this point (all data in the non-redundant IC space)
        ! * Grad: in internal coords
        ! * Delta: DeltaS 
        ! * Hess: Hessian in internal coords
        !
        ! Fisrt, compute DeltaS^t * Hs * DeltaS
        Theta=0.d0
        do j=1,Nvib
        do k=1,Nvib
            Theta = Theta + Delta(j)*Delta(k)*Hess(j,k)
        enddo
        enddo
        Er = -Theta*0.5d0
        do i=1,Nvib
            Er = Er - Grad(i)*Delta(i)
        enddo
    else ! Adiabatic
        print*, "Adiabatic model / IC space"
        ! Er = 1/2 DeltaS^t * Hs * DeltaS
        ! At this point (all data in the non-redundant IC space)
        ! * Grad: in internal coords
        ! * Delta: DeltaS 
        ! * Hess: Hessian in internal coords
        !
        ! Fisrt, compute DeltaS^t * Hs * DeltaS
        Theta=0.d0
        do j=1,Nvib
        do k=1,Nvib
            Theta = Theta + Delta(j)*Delta(k)*Hess(j,k)
        enddo
        enddo
        Er = Theta*0.5d0
    endif
    print'(X,A,F12.6)',   "Reorganization energy (AU) = ", Er
    print'(X,A,F12.6,/)', "Reorganization energy (eV) = ", Er*HtoeV


    ! ====================
    ! Print state files (better compute the dipole derivs directly in the Q-space) This also requires a change in FCclasses
    ! otherwise, the result will be approx, because FCclasses will first orthogonalize L1 and L2...
    ! ====================
    ! The L matrix obtained from Ls_to_Lcart is consistent with the  Cartesia geom of the state used. 
    ! In case the states are rotated, the above transformation should only be done on one of the states
    ! and the other must be obtained rotating the one transformed. Note that transformed one would be 
    ! consistent with the input geometries, and therefore, with the dipole derivatives
    if (reference_frame=="I".or.vertical) then
        print*, "Reference state to report statefiles: Initial"
        !HTi
        ! * L1: from Ls_to_Lcart
        call Ls_to_Lcart(Nat,Nvib,state1%atom(:)%mass,B1,G1,L1,L1,error)
        ! * L2: from rotation (Duschinski) of L1,   L2 = L1*J
        L2(1:3*Nat,1:Nvib) = matrix_product(3*Nat,Nvib,Nvib,L1,Jdus)
    else ! HTmode='F'
        print*, "Reference state to report statefiles: Final"
        ! HTf
        !  * L2: from Ls_to_Lcart
        call Ls_to_Lcart(Nat,Nvib,state2%atom(:)%mass,B2,G2,L2,L2,error)
        !  * L1: from rotation (Duschinski) of L2   L1 = L2*J^-1
        ! Need inverse of J
        Aux(1:Nvib,1:Nvib) = inverse_realgen(Nvib,Jdus)
        L1(1:3*Nat,1:Nvib) = matrix_product(3*Nat,Nvib,Nvib,L2,Aux)
    endif
    ! STATE1
    ! Compute new state_file
    ! T1(g09) = mu^1/2 m B^t G1^-1 L1
    !Print state
    open(O_STAT,file="state_file_1")
    call set_geom_units(state1,"Angs")
    do i=1,Nat
        write(O_STAT,*) state1%atom(i)%x
        write(O_STAT,*) state1%atom(i)%y
        write(O_STAT,*) state1%atom(i)%z
    enddo
    call Lcart_to_LcartNrm(Nat,Nvib,L1,Aux,error)
    do i=1,3*Nat
    do j=1,Nvib
        write(O_STAT,*) Aux(i,j)
    enddo
    enddo
    do j=1,Nvib
        if (force_real.and.Freq1(j)<0) then
            print*, Freq1(j)
            call alert_msg("warning","An imagainary frequency turned real (state1)")
            Freq1(j) = abs(Freq1(j))
        endif
        write(O_STAT,'(F12.5)') Freq1(j)
    enddo
    close(O_STAT)
    ! STATE2
    if (vertical) then
        ! Deactivate state2 coords to avoid confusion
        state2%atom(1:Nat)%x=0.d0
        state2%atom(1:Nat)%y=0.d0
        state2%atom(1:Nat)%z=0.d0
    endif
    !Print state
    open(O_STAT,file="state_file_2")
    call set_geom_units(state2,"Angs")
    ! Note that the geometry is the input one (not displaced for vertical)
    ! But it is ok for FCclasses (it is not using it AFIK) What about HT??
    do i=1,Nat
        write(O_STAT,*) state2%atom(i)%x
        write(O_STAT,*) state2%atom(i)%y
        write(O_STAT,*) state2%atom(i)%z
    enddo
    call Lcart_to_LcartNrm(Nat,Nvib,L2,Aux,error)
    do i=1,3*Nat
    do j=1,Nvib
        write(O_STAT,*) Aux(i,j)
    enddo
    enddo
    do j=1,Nvib
        if (force_real.and.Freq2(j)<0) then
            print*, Freq2(j)
            call alert_msg("warning","An imagainary frequency turned real (state2)")
            Freq2(j) = abs(Freq2(j))
        endif
        write(O_STAT,'(F12.5)') Freq2(j)
    enddo
    close(O_STAT)

    !============================================
    ! PRINT DUSCHINSKI AND DISPLACEMENT TO FILES
    !============================================
    print*, "Printing Duschinski matrix to 'duschinsky.dat'"
    open(O_DUS, file="duschinsky.dat")
!     open(O_DUS2,file="duschinsky_orth.dat")
    print'(X,A,/)', "Printing Shift vector to 'displacement.dat'"
    open(O_DIS, file="displacement.dat")
!     open(O_DIS2,file="displacement_orth.dat")
    do i=1,Nvib
    do j=1,Nvib
        write(O_DUS,*)  Jdus(i,j)
!         write(O_DUS2,*) JdusO(i,j)
    enddo 
        write(O_DIS,*)  Vec1(i)
!         write(O_DIS2,*) Vec2(i)
    enddo
    close(O_DUS)
!     close(O_DUS2)
    close(O_DIS)
!     close(O_DIS2)

    call summary_alerts

    call cpu_time(tf)
    write(6,'(A,F12.3)') "CPU (s) for internal vib analysis: ", tf-ti

    stop

    !==============================================
    contains
    !=============================================

    subroutine parse_input(inpfile,ft,hessfile,fth,gradfile,ftg,&
                           inpfile2,ft2,hessfile2,fth2,gradfile2,ftg2,&
                           intfile,rmzfile,def_internal,use_symmetry,cnx_file,&
!                          tswitch,
                           symaddapt,same_red2nonred_rotation,analytic_Bder,&
                           vertical,verticalQspace2,verticalQspace1,&
                           gradcorrectS1,gradcorrectS2,&
                           orthogonalize,original_internal,force_real,reference_frame)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: inpfile,ft,hessfile,fth,gradfile,ftg,&
                                          inpfile2,ft2,hessfile2,fth2,gradfile2,ftg2,&
                                          intfile,rmzfile,def_internal, cnx_file, reference_frame !, symfile
        logical,intent(inout)          :: use_symmetry, vertical, verticalQspace2, &
                                          verticalQspace1, &
                                          gradcorrectS1, gradcorrectS2, symaddapt, &
                                          same_red2nonred_rotation,analytic_Bder, &
                                          orthogonalize,original_internal,force_real
!         logical,intent(inout) :: tswitch

        ! Local
        logical :: argument_retrieved,  &
                   need_help = .false.
        integer:: i
        character(len=200) :: arg
        character(len=500) :: input_command
        character(len=10)  :: model="adia", MODEL_UPPER

        ! Tune defaults
        logical :: gradcorrectS1_default=.true., &
                   gradcorrectS2_default=.true.

        !Initialize input_command
        call getarg(0,input_command)
        !Get input flags
        do i=1,iargc()
            call getarg(i,arg)
            input_command = trim(adjustl(input_command))//" "//trim(adjustl(arg))
        enddo

        argument_retrieved=.false.
        do i=1,iargc()
            if (argument_retrieved) then
                argument_retrieved=.false.
                cycle
            endif
            call getarg(i, arg) 
            select case (adjustl(arg))
                case ("-f") 
                    call getarg(i+1, inpfile)
                    argument_retrieved=.true.
                case ("-ft") 
                    call getarg(i+1, ft)
                    argument_retrieved=.true.

                case ("-fhess") 
                    call getarg(i+1, hessfile)
                    argument_retrieved=.true.
                case ("-fth") 
                    call getarg(i+1, fth)
                    argument_retrieved=.true.

                case ("-fgrad") 
                    call getarg(i+1, gradfile)
                    argument_retrieved=.true.
                case ("-ftg") 
                    call getarg(i+1, ftg)
                    argument_retrieved=.true.

                case ("-f2") 
                    call getarg(i+1, inpfile2)
                    argument_retrieved=.true.
                case ("-ft2") 
                    call getarg(i+1, ft2)
                    argument_retrieved=.true.

                case ("-fhess2") 
                    call getarg(i+1, hessfile2)
                    argument_retrieved=.true.
                case ("-fth2") 
                    call getarg(i+1, fth2)
                    argument_retrieved=.true.

                case ("-fgrad2") 
                    call getarg(i+1, gradfile2)
                    argument_retrieved=.true.
                case ("-ftg2") 
                    call getarg(i+1, ftg2)
                    argument_retrieved=.true.

                case ("-cnx") 
                    call getarg(i+1, cnx_file)
                    argument_retrieved=.true.

                case ("-intfile") 
                    call getarg(i+1, intfile)
                    argument_retrieved=.true.

                case ("-rmzfile") 
                    call getarg(i+1, rmzfile)
                    argument_retrieved=.true.
                ! Kept for backward compatibility (but replaced by -rmzfile)
                case ("-rmz") 
                    call getarg(i+1, rmzfile)
                    argument_retrieved=.true.

                case ("-intmode")
                    call getarg(i+1, def_internal)
                    argument_retrieved=.true.
                ! Kept for backward compatibility (but replaced by -intmode)
                case ("-intset")
                    call getarg(i+1, def_internal)
                    argument_retrieved=.true.

                case ("-sym")
                    use_symmetry=.true.
                case ("-nosym")
                    use_symmetry=.false.

                case ("-symaddapt")
                    symaddapt=.true.

                case("-samerot")
                    same_red2nonred_rotation=.true.
                case("-nosamerot")
                    same_red2nonred_rotation=.false.

                ! Options to tune the model
                !================================================================
                ! This is the new (and now standard way to get the model)
                case ("-model")
                    call getarg(i+1, model)
                    argument_retrieved=.true.
                !The others are kept for backward compatibility
                case ("-vertQ1")
                    vertical=.true.
                    verticalQspace2=.false.
                    verticalQspace1=.true.
                case ("-vertQ2")
                    vertical=.true.
                    verticalQspace2=.true.
                    verticalQspace1=.false.
                case ("-vert")
                    vertical=.true.
                    verticalQspace2=.false.
                case ("-novert")
                    vertical=.false.
                    verticalQspace2=.false.
                !================================================================

                case ("-ref") 
                    call getarg(i+1, reference_frame)
                    argument_retrieved=.true.

                case ("-force-real")
                    force_real=.true.
                case ("-noforce-real")
                    force_real=.false.

                case ("-orth")
                    orthogonalize=.true.
                case ("-noorth")
                    orthogonalize=.false.
                    
                case ("-origint")
                    original_internal=.true.
                case ("-noorigint")
                    original_internal=.false.
        
                case ("-h")
                    need_help=.true.

                case ("-corrS2")
                    gradcorrectS2=.true.
                    gradcorrectS2_default=.false.
                case ("-nocorrS2")
                    gradcorrectS2=.false.
                    gradcorrectS2_default=.false.
                case ("-corrS1")
                    gradcorrectS1=.true.
                    gradcorrectS1_default=.false.
                case ("-nocorrS1")
                    gradcorrectS1=.false.
                    gradcorrectS1_default=.false.

                !HIDDEN

                case ("-anaBder")
                    analytic_Bder=.true.
                case ("-noanaBder")
                    analytic_Bder=.false.

                ! Control verbosity
                case ("-quiet")
                    verbose=0
                case ("-concise")
                    verbose=1
                case ("-v")
                    verbose=2
                case ("-vv")
                    verbose=3

                case default
                    call alert_msg("fatal","Unkown command line argument: "//adjustl(arg))
            end select
        enddo 

       ! Manage defaults
       ! If not declared, hessfile and gradfile are the same as inpfile
       if (adjustl(hessfile) == "same") then
           hessfile=inpfile
           if (adjustl(fth) == "guess")  fth=ft
       endif
       if (adjustl(gradfile) == "same") then
           gradfile=inpfile
           if (adjustl(ftg) == "guess")  ftg=ft
       endif
       if (adjustl(hessfile2) == "same") then
           hessfile2=inpfile2
           if (adjustl(fth2) == "guess")  fth2=ft2
       endif
       if (adjustl(gradfile2) == "same") then
           gradfile2=inpfile2
           if (adjustl(ftg2) == "guess")  ftg2=ft2
       endif

       ! Set old options for the model with the new input key
       MODEL_UPPER = adjustl(model)
       call set_word_upper_case(MODEL_UPPER)
       select case (adjustl(MODEL_UPPER))
           case ("ADIA") 
               vertical=.false.
               verticalQspace1=.false.
               verticalQspace2=.false.
           case ("VERT") 
               vertical=.true.
               verticalQspace1=.false.
               verticalQspace2=.false.
           case ("VERTQ1") 
               vertical=.true.
               verticalQspace1=.true.
               verticalQspace2=.false.
           case ("VERTQ2") 
               vertical=.true.
               verticalQspace1=.false.
               verticalQspace2=.true.
           case default
               call alert_msg("warning","Unkown model to describe PESs: "//adjustl(model))
               need_help=.true.
       end select

       if (gradcorrectS2_default) then
           ! All vertical models include the correction
           if (vertical) then
               gradcorrectS2=.true.
           else
               gradcorrectS2=.false.
           endif
       endif
       if (gradcorrectS1_default) then
           gradcorrectS1=.false.
       endif

       !Print options (to stdout)
        write(6,'(/,A)') '========================================================'
        write(6,'(/,A)') '        I N T E R N A L   D U S C H I N S K Y '    
        write(6,'(/,A)') '         Duschinski analysis for Adiabatic and    '
        write(6,'(A,/)') '        Vertical model in Cartesian coordinates          '   
        call print_version()
        write(6,'(/,A)') '========================================================'
        write(6,'(/,A)') '-------------------------------------------------------------------'
        write(6,'(A)')   ' Flag         Description                   Value'
        write(6,'(A)')   '-------------------------------------------------------------------'
        write(6,*) '-f           Input file (State1)           ', trim(adjustl(inpfile))
        write(6,*) '-ft          \_ FileType                   ', trim(adjustl(ft))
        write(6,*) '-fhess       Hessian(S1) file              ', trim(adjustl(hessfile))
        write(6,*) '-fth         \_ FileType                   ', trim(adjustl(fth))
        write(6,*) '-fgrad       Gradient(S1) file             ', trim(adjustl(gradfile))
        write(6,*) '-ftg         \_ FileType                   ', trim(adjustl(ftg))
        write(6,*) '-f2          Input file (State2)           ', trim(adjustl(inpfile2))
        write(6,*) '-ft2         \_ FileType                   ', trim(adjustl(ft2))
        write(6,*) '-fhess2      Hessian(S2) file              ', trim(adjustl(hessfile2))
        write(6,*) '-fth2        \_ FileType                   ', trim(adjustl(fth2))
        write(6,*) '-fgrad2      Gradient(S2) file             ', trim(adjustl(gradfile2))
        write(6,*) '-ftg2        \_ FileType                   ', trim(adjustl(ftg2))
        write(6,*) ''
        write(6,*) ' ** Options for state_files ** '
        write(6,*) '-ref         Reference state to output the ', reference_frame
        write(6,*) '             L matrices in its Cartesian '
        write(6,*) '             frame [I|F]'
        write(6,*) '-[no]force-real Turn imaginary frequences ', force_real
        write(6,*) '              to real (also affects Er)'
        write(6,*) '               '                       
        write(6,*) ' ** Options Internal Coordinates **           '
        write(6,*) '-cnx         Connectivity [filename|guess] ', trim(adjustl(cnx_file))
        write(6,*) '-intmode     Internal set:[zmat|sel|all]   ', trim(adjustl(def_internal))
        write(6,*) '-intfile     File with ICs (for "sel")     ', trim(adjustl(intfile))
        write(6,*) '-rmzfile     File deleting ICs from Zmat   ', trim(adjustl(rmzfile))
        write(6,*) '-[no]sym     Use symmetry to form Zmat    ',  use_symmetry
        write(6,*) '-[no]samerot Use S1 red->non-red rotation ',  same_red2nonred_rotation
        write(6,*) '             for S2'
        write(6,*) '-[no]orth    Use orthogonalized internals ',  orthogonalize
        write(6,*) '-[no]origint Use originally defined inter-',  original_internal
        write(6,*) '             nal w\o linear combinations  '
        write(6,*) '             (valid for non-redundant sets)'
        write(6,*) '               '
        write(6,*) ' ** Options Vertical Model **'
        write(6,*) '-model       Model for harmonic PESs       ', trim(adjustl(model))
        write(6,*) '             [vert|vertQ1|vertQ2|adia]     '
        write(6,*) '               '
        write(6,*) '-h           Display this help            ',  need_help
        write(6,'(A)') '-------------------------------------------------------------------'
        write(6,'(A)') 'Input command:'
        write(6,'(A)') trim(adjustl(input_command))   
        write(6,'(A)') '-------------------------------------------------------------------'
        write(6,'(X,A,I0)') &
                       'Verbose level:  ', verbose        
        write(6,'(A)') '-------------------------------------------------------------------'
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input


end program internal_duschinski

