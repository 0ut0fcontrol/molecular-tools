program normal_modes_animation


    !==============================================================
    ! This code uses of MOLECULAR_TOOLS (version 1.0/March 2012)
    !==============================================================
    !
    ! Description:
    ! -----------
    ! Program to analyse vibrations in term of internal coordinates.
    !
    ! Compilation instructions (for mymake script):
    !make$ echo "COMPILER: $FC"; sleep 1; $FC ../modules/alerts.f90 ../modules/structure_types_v3.f90 ../modules/line_preprocess.f90 ../modules/ff_build_module_v3.f90 ../modules/gro_manage_v2.f90 ../modules/pdb_manage_v2.f90 ../modules/constants_mod.f90 ../modules/atomic_geom_v2.f90 ../modules/gaussian_manage_v2.f90 ../modules/gaussian_fchk_manage_v2.f90 ../modules/symmetry_mod.f90 ../modules/MatrixMod.f90 internal_SR_v6.f90 internal_duschinski_v5.f90 -llapack -o internal_duschinski_v5.exe -cpp -DDOUBLE
    !
    ! Change log:
    !
    ! TODO:
    ! ------
    !
    ! History
    ! V3: Internal analysis is based on internal_duschinski_v5 (never finished...)
    ! V4: Internal analysis is based on internal_duschinski_v7
    !  V4b (not in the main streamline!): includes the generation of scans calc. for Gaussian.
    !  V4c: the same as 4b. Bug fixes on guess_connect (ff_build module_v3 was buggy)
    !
    !============================================================================    

!*****************
!   MODULE LOAD
!*****************
!============================================
!   Generic (structure_types independent)
!============================================
    use alerts
    use line_preprocess
    use constants
!   Matrix manipulation (i.e. rotation matrices)
    use MatrixMod
!============================================
!   Structure types module
!============================================
    use structure_types
!============================================
!   Structure dependent modules
!============================================
    use gro_manage
    use pdb_manage
    use gaussian_manage
    use gaussian_fchk_manage
    use xyz_manage
!   Structural parameters
    use molecular_structure
    use ff_build
!   Bond/angle/dihed meassurement
    use atomic_geom
!   Symmetry support
    use symmetry_mod
!   For internal thingies
    use internal_module
    use zmat_manage

    implicit none

    integer,parameter :: NDIM = 800

    !====================== 
    !Options 
    logical :: nosym=.true.   ,&
               zmat=.true.    ,&
               tswitch=.false.,&
               symaddapt=.false.
    !======================

    !====================== 
    !System variables
    type(str_resmol) :: molecule, molec_aux
    integer,dimension(1:NDIM) :: isym
    integer :: Nat, Nvib, Nred
    character(len=5) :: PG
    !Bonded info
    integer,dimension(1:NDIM,1:4) :: bond_s, angle_s, dihed_s
    !====================== 

    !====================== 
    !INTERNAL VIBRATIONAL ANALYSIS
    !MATRICES
    !B and G matrices
    real(8),dimension(1:NDIM,1:NDIM) :: B1, G1
    !Other matrices
    real(8),dimension(1:NDIM,1:NDIM) :: Hess, X1,X1inv, L1, Asel1, Asel
    !Save definitio of the modes in character
    character(len=100),dimension(NDIM) :: ModeDef
    !VECTORS
    real(8),dimension(NDIM) :: Freq, S1, Vec
    integer,dimension(NDIM) :: S_sym, bond_sym,angle_sym,dihed_sym
    !Shifts
    real(8),dimension(NDIM) :: Delta
    real(8) :: Delta_p
    !====================== 

    !====================== 
    !Read fchk auxiliars
    real(8),dimension(:),allocatable :: A
    integer,dimension(:),allocatable :: IA
    character(len=1) :: dtype
    integer :: error, N
    !Read gaussian log auxiliars
    type(str_molprops),allocatable :: props
    !====================== 

    !====================== 
    !Auxiliars for LAPACK matrix nversion
    integer :: info
    integer,dimension(NDIM) :: ipiv
    real(8),dimension(NDIM,NDIM) :: work
    !====================== 

    !====================== 
    !Auxiliar variables
    character(1) :: null
    character(len=16) :: dummy_char
    real(8) :: Theta, Theta2, dist
    !====================== 

    !=============
    !Counters
    integer :: i,j,k,l, ii,jj,kk, iat, nn, imin, imax, iii
    !=============

     !orientation things
    real(8),dimension(3,3) :: ori

    !NM stuff
    real(8) :: Amplitude = 1.d0, qcoord
    !Moving normal modes
    integer,dimension(1:1000) :: nm=0
    real(8) :: Qstep, d, rmsd1, rmsd2
    logical :: call_vmd = .false.
    character(len=10000) :: vmdcall
    integer :: Nsteps, Nsel, istep

    !================
    !I/O stuff 
    !units
    integer :: I_INP=10,  &
               I_ZMAT=11, &
               O_GRO=20,  &
               O_G09=21,  &
               O_Q  =22, &
               S_VMD=30
    !files
    character(len=10) :: filetype="guess"
    character(len=200):: inpfile ="input.fchk",  &
                         zmatfile="NO"
    character(len=100),dimension(1:1000) :: grofile
    character(len=100) :: nmfile='none', g09file,qfile
    !Control of stdout
    logical :: verbose=.false.
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

    ! 0. GET COMMAND LINE ARGUMENTS
    nm(1) = 0
    call parse_input(inpfile,nmfile,nm,Nsel,Amplitude,filetype,nosym,zmat,verbose,tswitch,symaddapt,zmatfile,call_vmd)

    ! 1. INTERNAL VIBRATIONAL ANALYSIS 
 
    ! 1. READ DATA
    ! ---------------------------------
    open(I_INP,file=inpfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile)) )

    !Read structure
    call generic_strfile_read(I_INP,filetype,molecule)
    !Shortcuts
    Nat = molecule%natoms
    Nvib = 3*Nat-6
    !Read the Hessian: only two possibilities supported
    if (adjustl(filetype) == "log") then
        !Gaussian logfile
        allocate(props)
        call parse_summary(I_INP,molecule,props,"read_hess")
        ! RECONSTRUCT THE FULL HESSIAN
        k=0
        do i=1,3*Nat
            do j=1,i
                k=k+1
                Hess(i,j) = props%H(k) 
                Hess(j,i) = Hess(i,j)
            enddo
        enddo
        deallocate(props)
    else if (adjustl(filetype) == "fchk") then
        !FCHK file    
        call read_fchk(I_INP,"Cartesian Force Constants",dtype,N,A,IA,error)
        close(I_INP)
        ! RECONSTRUCT THE FULL HESSIAN
        k=0
        do i=1,3*Nat
            do j=1,i
                k=k+1
                Hess(i,j) = A(k) 
                Hess(j,i) = Hess(i,j)
            enddo
        enddo
        deallocate(A)
    endif

    !NORMAL MODES SELECTION SWITCH
    if (Nsel == 0) then
        !The select them all
        Nsel = Nvib
        do i=1,Nsel
            nm(i) = i
        enddo
    endif
    if (Nsel > 1000) call alert_msg("fatal", "Too many normal modes. Dying")


    !====================================
    !INTERNAL COORDINATES MANAGEMENT
    !====================================
    ! Get connectivity from the residue (needs to be in ANGS, as it is -- default coord. output)
    ! Setting element from atom names is mandatory to use guess_connect
    call guess_connect(molecule)
    if (nosym) then
        PG="C1"
    else
        call symm_atoms(molecule,isym)
        PG=molecule%PG
    endif
    !From now on, we'll use atomic units
    molecule%atom(1:Nat)%x = molecule%atom(1:Nat)%x/BOHRtoANGS
    molecule%atom(1:Nat)%y = molecule%atom(1:Nat)%y/BOHRtoANGS
    molecule%atom(1:Nat)%z = molecule%atom(1:Nat)%z/BOHRtoANGS

    !Generate bonded info
    call gen_bonded(molecule)

    !GENERATE SET FOR INTERNAL COORDINATES FROM Z-MATRIX
    ! Store this info in molec%geom module
    if (zmat) then
        if (adjustl(zmatfile) == "NO") then
            call build_Z(molecule,bond_s,angle_s,dihed_s,PG,isym,bond_sym,angle_sym,dihed_sym)
        else
            open(I_ZMAT,file=zmatfile,status="old")
            print*, "Z-matrix read from "//trim(adjustl(zmatfile))
            call read_Z(molecule,bond_s,angle_s,dihed_s,PG,isym,bond_sym,angle_sym,dihed_sym,I_ZMAT)
            close(I_ZMAT)
            !Deactivate symaddapt (for the moment)
            PG = "C1"
        endif
        !Z-mat
        molecule%geom%bond(1:Nat-1,1:2) = bond_s(2:Nat,1:2)
        molecule%geom%angle(1:Nat-2,1:3) = angle_s(3:Nat,1:3)
        molecule%geom%dihed(1:Nat-3,1:4) = dihed_s(4:Nat,1:4)
        molecule%geom%nbonds  = Nat-1
        molecule%geom%nangles = Nat-2
        molecule%geom%ndihed  = Nat-3
    endif !otherwise all parameters from molec%geom are used

    ! SYMMETRIC 
    !Set symmetry of internal (only if symmetry is detected)
    if (adjustl(PG) == "C1") then
        S_sym(3*Nat) = 1
    else
        do i=1,Nat-1
            S_sym(i) = bond_sym(i+1)-1
        enddo
        do i=1,Nat-2
            S_sym(i+Nat-1) = angle_sym(i+2)+Nat-3
        enddo
        do i=1,Nat-3
            S_sym(i+2*Nat-3) = dihed_sym(i+3)+2*Nat-6
        enddo
    endif

    !We send the option -sa within S_sym (confflict with redundant coord!!)
    ! S_sym(3*Nat) =  1 (sa=true) / 0 (sa=false)
    if (symaddapt) then
        S_sym(3*Nat) = 1
    else
        S_sym(3*Nat) = 0
    endif

    !SOLVE GF METHOD TO GET NM AND FREQ
    !For redundant coordinates a non-redundant set is formed as a combination of
    !the redundant ones. The coefficients for the combination are stored in Asel
    !as they must be used for state 2 (not rederived!).
    Asel1(1,1) = 99.d0 !out-of-range, as Asel is normalized -- this option is not tested
    call internal_Wilson(molecule,S1,S_sym,ModeDef,B1,G1,Asel1,verbose)
    call gf_method(Hess,molecule,S_sym,ModeDef,L1,B1,G1,Freq,Asel1,X1,X1inv,verbose) 


     !Use force constant to get dimmension-less displacements
     Freq(1:Nvib) = dsqrt(dabs(Freq(1:Nvib)))


    !==========================================================0
    !  Normal mode displacements
    !==========================================================0
    !Initialize auxiliar states
    Nsteps = 100
    Qstep = Amplitude/float(Nsteps)*5d3
    if ( mod(Nsteps,2) /= 0 ) Nsteps = Nsteps + 1
    do jj=1,Nsel 
        k=0
        qcoord=0.d0
        molecule%atom(1:molecule%natoms)%resname = "RES"
        j = nm(jj)
        write(grofile(jj),*) j
        molecule%title = "Animation of normal mode "//trim(adjustl(grofile(jj)))
        g09file="Mode"//trim(adjustl(grofile(jj)))//"_int.com"
        qfile="Mode"//trim(adjustl(grofile(jj)))//"_int_steps.dat"
        grofile(jj) = "Mode"//trim(adjustl(grofile(jj)))//"_int.gro"
        print*, "Writting results to: "//trim(adjustl(grofile(jj)))
        open(O_GRO,file=grofile(jj))
        open(O_G09,file=g09file)
        open(O_Q  ,file=qfile)

        !===========================
        !Start from equilibrium. 
        !===========================
        print*, "STEP:", k
        call zmat2cart(molecule,bond_s,angle_s,dihed_s,S1,verbose)
        !Transform to AA and export coords and put back into BOHR
        molecule%atom(1:Nat)%x = molecule%atom(1:Nat)%x*BOHRtoAMS
        molecule%atom(1:Nat)%y = molecule%atom(1:Nat)%y*BOHRtoAMS
        molecule%atom(1:Nat)%z = molecule%atom(1:Nat)%z*BOHRtoAMS
        call write_gro(O_GRO,molecule)
        molec_aux=molecule
        !===========================
        !Half Forward oscillation
        !===========================
        !Initialize distacen criterion for new check_ori2b SR
        dist=0.d0
        do istep = 1,nsteps/2
            k=k+1
            qcoord = qcoord + Qstep/Freq(j)
            print*, "STEP:", k
            write(dummy_char,*) k
            molecule%title = trim(adjustl(grofile(jj)))//".step "//trim(adjustl(dummy_char))
!             print*, "Bonds"
            do i=1,molecule%geom%nbonds
                S1(i) = S1(i) + L1(i,j) * Qstep/Freq(j)
            enddo
!             print*, "Angles"
            do ii=i,i+molecule%geom%nangles-1
                S1(ii) = S1(ii) + L1(ii,j) * Qstep/Freq(j)
            enddo
!             print*, "Dihedrals"
            do iii=ii,ii+molecule%geom%ndihed-1
               S1(iii) = S1(iii) + L1(iii,j) * Qstep/Freq(j)
               if (S1(iii) > PI) S1(iii)=S1(iii)-2.d0*PI
               if (S1(iii) < -PI) S1(iii)=S1(iii)+2.d0*PI
            enddo
            call zmat2cart(molecule,bond_s,angle_s,dihed_s,S1,verbose)
            !Transform to AA and comparae with last step (stored in state) -- comparison in AA
            molecule%atom(1:Nat)%x = molecule%atom(1:Nat)%x*BOHRtoAMS
            molecule%atom(1:Nat)%y = molecule%atom(1:Nat)%y*BOHRtoAMS
            molecule%atom(1:Nat)%z = molecule%atom(1:Nat)%z*BOHRtoAMS
            !call check_ori3(state,ref): efficient but not always works. If so, it uses check_ori2(state,ref)
            call check_ori3(molecule,molec_aux,info)
            if (info /= 0 .or. istep==1) then
                call check_ori2b(molecule,molec_aux,dist)
                !The threshold in 5% avobe the last meassured distance
                dist = dist*1.05
            endif
            call write_gro(O_GRO,molecule)
            !Write the max amplitude step to G09 scan
            if (k==nsteps/2) then
                call write_gcom(O_G09,molecule)
                write(O_Q,*) qcoord
            endif
            !Save last step in molec_aux (in AA)
            molec_aux=molecule
        enddo
        !=======================================
        ! Reached amplitude. Back oscillation
        !=======================================
        do istep = 1,nsteps/2-2
            k=k+1
            qcoord = qcoord - Qstep/Freq(j)
            print*, "STEP:", k
            write(dummy_char,*) k
            molecule%title = trim(adjustl(grofile(jj)))//".step "//trim(adjustl(dummy_char))
!             print*, "Bonds"
            do i=1,molecule%geom%nbonds
                S1(i) = S1(i) - L1(i,j) * Qstep/Freq(j)
            enddo
!             print*, "Angles"
            do ii=i,i+molecule%geom%nangles-1
                S1(ii) = S1(ii) - L1(ii,j) * Qstep/Freq(j)
            enddo
!             print*, "Dihedrals"
            do iii=ii,ii+molecule%geom%ndihed-1
                S1(iii) = S1(iii) - L1(iii,j) * Qstep/Freq(j)
                if (S1(iii) > PI) S1(iii)=S1(iii)-2.d0*PI
                if (S1(iii) < -PI) S1(iii)=S1(iii)+2.d0*PI
            enddo
            call zmat2cart(molecule,bond_s,angle_s,dihed_s,S1,verbose)
            molecule%atom(1:Nat)%x = molecule%atom(1:Nat)%x*BOHRtoAMS
            molecule%atom(1:Nat)%y = molecule%atom(1:Nat)%y*BOHRtoAMS
            molecule%atom(1:Nat)%z = molecule%atom(1:Nat)%z*BOHRtoAMS

            call check_ori3(molecule,molec_aux,info)
            if (info /= 0) then
                call check_ori2b(molecule,molec_aux,dist)
                !The threshold in 5% avobe the last meassured distance
                dist = dist*1.05
            endif
            call write_gro(O_GRO,molecule)
            if (mod(k,10) == 0) then
                call write_gcom(O_G09,molecule)
                write(O_Q,*) qcoord
            endif
            !Save last step in molec_aux (in AA)
            molec_aux=molecule
        enddo
        !=======================================
        ! Reached equilibrium again
        !=======================================
        do istep = 1,3
            k=k+1
            qcoord = qcoord - Qstep/Freq(j)
            print*, "STEP:", k
            write(dummy_char,*) k
            molecule%title = trim(adjustl(grofile(jj)))//".step "//trim(adjustl(dummy_char))
!             print*, "Bonds"
            do i=1,molecule%geom%nbonds
                S1(i) = S1(i) - L1(i,j) * Qstep/Freq(j)
            enddo
!             print*, "Angles"
            do ii=i,i+molecule%geom%nangles-1
                S1(ii) = S1(ii) - L1(ii,j) * Qstep/Freq(j)
            enddo
!             print*, "Dihedrals"
            do iii=ii,ii+molecule%geom%ndihed-1
                S1(iii) = S1(iii) - L1(iii,j) * Qstep/Freq(j)
               if (S1(iii) > PI) S1(iii)=S1(iii)-2.d0*PI
                if (S1(iii) < -PI) S1(iii)=S1(iii)+2.d0*PI
            enddo
            call zmat2cart(molecule,bond_s,angle_s,dihed_s,S1,verbose)
            molecule%atom(1:Nat)%x = molecule%atom(1:Nat)%x*BOHRtoAMS
            molecule%atom(1:Nat)%y = molecule%atom(1:Nat)%y*BOHRtoAMS
            molecule%atom(1:Nat)%z = molecule%atom(1:Nat)%z*BOHRtoAMS

            call check_ori3(molecule,molec_aux,info)
            if (info /= 0) then
                call check_ori2b(molecule,molec_aux,dist)
                !The threshold in 5% avobe the last meassured distance
                dist = dist*1.05
            endif
            call write_gro(O_GRO,molecule)
            !This time write all three numbers
            call write_gcom(O_G09,molecule)
            write(O_Q,*) qcoord
            molec_aux=molecule
        enddo
        !=======================================
        ! Continue Back oscillation
        !=======================================
        do istep = 1,nsteps/2-1
            k=k+1
            qcoord = qcoord - Qstep/Freq(j)
            print*, "STEP:", k
            write(dummy_char,*) k
            molecule%title = trim(adjustl(grofile(jj)))//".step "//trim(adjustl(dummy_char))
!             print*, "Bonds"
            do i=1,molecule%geom%nbonds
                S1(i) = S1(i) - L1(i,j) * Qstep/Freq(j)
            enddo
!             print*, "Angles"
            do ii=i,i+molecule%geom%nangles-1
                S1(ii) = S1(ii) - L1(ii,j) * Qstep/Freq(j)
            enddo
!             print*, "Dihedrals"
            do iii=ii,ii+molecule%geom%ndihed-1
                S1(iii) = S1(iii) - L1(iii,j) * Qstep/Freq(j)
               if (S1(iii) > PI) S1(iii)=S1(iii)-2.d0*PI
                if (S1(iii) < -PI) S1(iii)=S1(iii)+2.d0*PI
            enddo
            call zmat2cart(molecule,bond_s,angle_s,dihed_s,S1,verbose)
            molecule%atom(1:Nat)%x = molecule%atom(1:Nat)%x*BOHRtoAMS
            molecule%atom(1:Nat)%y = molecule%atom(1:Nat)%y*BOHRtoAMS
            molecule%atom(1:Nat)%z = molecule%atom(1:Nat)%z*BOHRtoAMS

            call check_ori3(molecule,molec_aux,info)
            if (info /= 0) then
                call check_ori2b(molecule,molec_aux,dist)
                !The threshold in 5% avobe the last meassured distance
                dist = dist*1.05
            endif
            call write_gro(O_GRO,molecule)
            if (mod(k,10) == 0) then
                call write_gcom(O_G09,molecule)
                write(O_Q,*) qcoord
            endif
            molec_aux=molecule
        enddo
        !=======================================
        ! Reached amplitude. Half Forward oscillation (till equilibrium)
        !=======================================
        do istep = 1,nsteps/2-1
            k=k+1
            print*, "STEP:", k
!             print*, "Bonds"
            do i=1,molecule%geom%nbonds
                S1(i) = S1(i) + L1(i,j) * Qstep/Freq(j)
            enddo
!             print*, "Angles"
            do ii=i,i+molecule%geom%nangles-1
                S1(ii) = S1(ii) + L1(ii,j) * Qstep/Freq(j)
            enddo
!             print*, "Dihedrals"
            do iii=ii,ii+molecule%geom%ndihed-1
                S1(iii) = S1(iii) + L1(iii,j) * Qstep/Freq(j)
               if (S1(iii) > PI) S1(iii)=S1(iii)-2.d0*PI
                if (S1(iii) < -PI) S1(iii)=S1(iii)+2.d0*PI
            enddo
            call zmat2cart(molecule,bond_s,angle_s,dihed_s,S1,verbose)
            molecule%atom(1:Nat)%x = molecule%atom(1:Nat)%x*BOHRtoAMS
            molecule%atom(1:Nat)%y = molecule%atom(1:Nat)%y*BOHRtoAMS
            molecule%atom(1:Nat)%z = molecule%atom(1:Nat)%z*BOHRtoAMS

            call check_ori3(molecule,molec_aux,info)
            if (info /= 0) then
                call check_ori2b(molecule,molec_aux,dist)
                !The threshold in 5% avobe the last meassured distance
                dist = dist*1.05
            endif
            call write_gro(O_GRO,molecule)
            molec_aux=molecule
        enddo
        close(O_GRO)
        close(O_G09)
        close(O_Q)
    enddo

    if (call_vmd) then
        open(S_VMD,file="vmd_conf.dat",status="replace")
        !Set general display settings (mimic gv)
        write(S_VMD,*) "color Display Background iceblue"
        write(S_VMD,*) "color Name {C} silver"
        write(S_VMD,*) "axes location off"
        !Set molecule representation
        write(S_VMD,*) "molinfo ", 0, " set drawn 1"
        write(S_VMD,*) "mol representation CPK"
        write(S_VMD,*) "mol addrep 0"
        do i=1,Nsel-1
            vmdcall = trim(adjustl(vmdcall))//" "//trim(adjustl(grofile(i+1)))
            write(S_VMD,*) "molinfo ", i, " set drawn 0"
            write(S_VMD,*) "mol addrep ", i
        enddo
        close(S_VMD)
        !Call vmd
        vmdcall = 'vmd -m '
        do i=1,Nsel
        vmdcall = trim(adjustl(vmdcall))//" "//trim(adjustl(grofile(i)))
        enddo
        vmdcall = trim(adjustl(vmdcall))//" -e vmd_conf.dat"
        call system(vmdcall)
    endif
    
    call cpu_time(tf)
    write(0,'(/,A,X,F12.3,/)') "CPU time (s)", tf-ti

    stop


    !==============================================
    contains
    !=============================================

    subroutine parse_input(inpfile,nmfile,nm,Nsel,Amplitude,filetype,nosym,zmat,verbose,tswitch,symaddapt,zmatfile,call_vmd)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: inpfile,nmfile,filetype,zmatfile
        logical,intent(inout) :: nosym, verbose, zmat, tswitch, symaddapt, call_vmd
        integer,dimension(:),intent(inout) :: nm
        integer,intent(out) :: Nsel
        real(8),intent(out) :: Amplitude
        ! Local
        logical :: argument_retrieved,  &
                   need_help = .false.
        integer:: i
        character(len=200) :: arg

        !Prelimirary defaults
        Nsel = 0

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
                    call getarg(i+1, filetype)
                    argument_retrieved=.true.

                case ("-nm") 
                    call getarg(i+1, arg)
                    argument_retrieved=.true.
                    call string2vector_int(arg,nm,Nsel)

                case ("-nmf") 
                    call getarg(i+1, nmfile)
                    argument_retrieved=.true.

                case ("-maxd") 
                    call getarg(i+1, arg)
                    read(arg,*) Amplitude
                    argument_retrieved=.true.

                case ("-vmd")
                    call_vmd=.true.

                case ("-nosym")
                    nosym=.true.
                case ("-sym")
                    nosym=.false.

                case ("-sa")
                    symaddapt=.true.
                case ("-nosa")
                    symaddapt=.false.

                case ("-readz") 
                    call getarg(i+1, zmatfile)
                    argument_retrieved=.true.

                case ("-zmat")
                    zmat=.true.
                case ("-nozmat")
                    zmat=.false.

                case ("-tswitch")
                    tswitch=.true.

                case ("-v")
                    verbose=.true.
        
                case ("-h")
                    need_help=.true.

                case default
                    call alert_msg("fatal","Unkown command line argument: "//adjustl(arg))
            end select
        enddo 

        ! Some checks on the input
        !----------------------------
        if (symaddapt.and.nosym) then
            print*, ""
            print*, "Symmetry addapted internal coordintes implies -sym. Turning on..."
            print*, ""
            nosym=.false.
        endif

       !Print options (to stderr)
        write(6,'(/,A)') '--------------------------------------------------'
        write(6,'(/,A)') '          INTERNAL MODES ANIMATION '    
        write(6,'(/,A)') '      Perform vibrational analysis based on  '
        write(6,'(/,A)') '            internal coordinates (D-V7)'        
        write(6,'(/,A)') '--------------------------------------------------'
        write(6,*) '-f              ', trim(adjustl(inpfile))
        write(6,*) '-ft             ', trim(adjustl(filetype))
        write(6,*) '-nm            ', nm(1),"-",nm(Nsel)
!         write(0,*) '-nmf           ', nm(1:Nsel)
        write(6,*) '-vmd           ',  call_vmd
        write(6,*) '-maxd          ',  Amplitude
        if (nosym) dummy_char="NO "
        if (.not.nosym) dummy_char="YES"
        write(6,*) '-[no]sym        ', dummy_char
        if (zmat) dummy_char="YES"
        if (.not.zmat) dummy_char="NO "
        write(6,*) '-[no]zmat       ', dummy_char
        write(6,*) '-readz          ', trim(adjustl(zmatfile))
        if (tswitch) dummy_char="YES"
        if (.not.tswitch) dummy_char="NO "
        write(6,*) '-tswitch        ', dummy_char
        if (symaddapt) dummy_char="YES"
        if (.not.symaddapt) dummy_char="NO "
        write(6,*) '-sa             ', dummy_char
        write(6,*) '-v             ', verbose
        write(6,*) '-h             ',  need_help
        write(6,*) '--------------------------------------------------'
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input


    subroutine generic_strfile_read(unt,filetype,molec)

        integer, intent(in) :: unt
        character(len=*),intent(inout) :: filetype
        type(str_resmol),intent(inout) :: molec

        !local
        type(str_molprops) :: props

        if (adjustl(filetype) == "guess") then
        ! Guess file type
        call split_line(inpfile,".",null,filetype)
        select case (adjustl(filetype))
            case("gro")
             call read_gro(I_INP,molec)
             call atname2element(molec)
             call assign_masses(molec)
            case("pdb")
             call read_pdb_new(I_INP,molec)
             call atname2element(molec)
             call assign_masses(molec)
            case("log")
             call parse_summary(I_INP,molec,props,"struct_only")
             call atname2element(molec)
             call assign_masses(molec)
            case("fchk")
             call read_fchk_geom(I_INP,molec)
             call atname2element(molec)
!              call assign_masses(molec) !read_fchk_geom includes the fchk masses
            case default
             call alert_msg("fatal","Trying to guess, but file type but not known: "//adjustl(trim(filetype))&
                        //". Try forcing the filetype with -ft flag (available: log, fchk)")
        end select

        else
        ! Predefined filetypes
        select case (adjustl(filetype))
            case("gro")
             call read_gro(I_INP,molec)
             call atname2element(molec)
             call assign_masses(molec)
            case("pdb")
             call read_pdb_new(I_INP,molec)
             call atname2element(molec)
             call assign_masses(molec)
            case("log")
             call parse_summary(I_INP,molec,props,"struct_only")
             call atname2element(molec)
             call assign_masses(molec)
            case("fchk")
             call read_fchk_geom(I_INP,molec)
             call atname2element(molec)
!              call assign_masses(molec) !read_fchk_geom includes the fchk masses
            case default
             call alert_msg("fatal","File type not supported: "//filetype)
        end select
        endif


        return


    end subroutine generic_strfile_read
       

end program normal_modes_animation
