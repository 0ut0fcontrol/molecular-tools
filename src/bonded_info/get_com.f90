program get_centers_mg


    !==============================================================
    ! This code uses of MOLECULAR_TOOLS (version 1.0/March 2012)
    !==============================================================
    !
    ! Description:
    ! -----------
    ! Forms a gro structure with the one present in the fchk
    !
    ! Compilation instructions (for mymake script):
    !make$ echo "COMPILER: $FC"; sleep 1; $FC ../modules/alerts.f90 ../modules/structure_types_v2.f90 ../modules/line_preprocess.f90  ../modules/gro_manage_v2.f90 ../modules/pdb_manage_v2.f90 ../modules/constants_mod.f90 ../modules/gaussian_manage_v2.f90 ../modules/gaussian_fchk_manage_v2.f90 ../modules/xyz_manage.f90 ../modules/ff_build_module_v3.f90 fchk2gro_v2.1.f90 -o fchk2gro_v2.1.exe -cpp 
    !
    ! Change log:
    !
    ! TODO:
    ! ------
    !
    !============================================================================    

    use alerts
    use structure_types
    use line_preprocess
    use gro_manage
    use pdb_manage
    use gaussian_manage
    use gaussian_fchk_manage
    use xyz_manage
    use molcas_unsym_manage
    use ff_build
    use molecular_structure

    implicit none

    !====================== 
    !System variables
    type(str_resmol) :: molec, &
                        molec_aux
    !====================== 

    !=============
    !Counters and dummies
    integer :: i,j,k,l, jj,kk, iat
    character(len=1) :: null
    logical :: overwrite=.false.,&
               make_connect=.false.
    !Swap related counters
    integer :: iat_new, iat_orig, nswap
    !=============

    !================
    !I/O stuff 
    !units
    integer :: I_INP=10, &
               I_SWP=11, &
               O_OUT=20  
    !files
    character(len=5) :: resname="read"
    character(len=10) :: filetype_inp="guess",&
                         filetype_out="guess"
    character(len=200):: inpfile="input.fchk",&
                         outfile="default"   ,&
                         swapfile="none"  
    !status
    integer :: IOstatus
    character(len=7) :: stat="new" !do not overwrite when writting
    !===================


    ! 0. GET COMMAND LINE ARGUMENTS
    call parse_input(inpfile,filetype_inp)

 
    ! 1. READ INPUT
    ! ---------------------------------
    open(I_INP,file=inpfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile)) )

    if (adjustl(filetype_inp) == "guess") call split_line_back(inpfile,".",null,filetype_inp)
    call generic_strfile_read(I_INP,filetype_inp,molec)
    close(I_INP)
    !Option to specify the resname from command line
    if (adjustl(resname) /= "read") molec%atom(:)%resname=resname
    !Get massses
    call atname2element(molec)
    call assign_masses(molec)

    ! 2. MAKE THE THING
    ! ------------------------------
    call get_cog(molec)
    call get_com(molec)

    print*, "CENTER OF GEOMETRY"
    print*, molec%cogX, molec%cogY, molec%cogZ
    print*, "-"
    print*, "CENTER OF MASS"
    print*, molec%comX, molec%comY, molec%comZ

    stop


    !==============================================
    contains
    !=============================================

    subroutine parse_input(inpfile,filetype_inp)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: inpfile,filetype_inp
        ! Local
        logical :: argument_retrieved,  &
                   need_help = .false.
        integer:: i
        character(len=200) :: arg

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
                case ("-fti") 
                    call getarg(i+1, filetype_inp)
                    argument_retrieved=.true.
        
                case ("-h")
                    need_help=.true.

                case default
                    call alert_msg("fatal","Unkown command line argument: "//adjustl(arg))
            end select
        enddo 

        ! Some checks on the input
        !----------------------------

       !Print options (to stderr)
        write(0,'(/,A)') '--------------------------------------------------'
        write(0,'(/,A)') '        G  E T    C E N T E R S '    
        write(0,'(/,A)') '         Compute COM and COG'  
        write(0,'(/,A)') '        Revision: get_com-150119-1               '         
        write(0,'(/,A)') '--------------------------------------------------'
        write(0,*) '-f              ', trim(adjustl(inpfile))
        write(0,*) '-fti            ', trim(adjustl(filetype_inp))
        write(0,*) '-h             ',  need_help
        write(0,*) '--------------------------------------------------'
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input


    subroutine generic_strfile_read(unt,filetype,molec)

        integer, intent(in) :: unt
        character(len=*),intent(inout) :: filetype
        type(str_resmol),intent(inout) :: molec

        !Local
        type(str_molprops) :: props

        ! Predefined filetypes
        select case (adjustl(filetype))
            case("gro")
             call read_gro(unt,molec)
            case("pdb")
             call read_pdb_new(unt,molec)
            case("g96")
             call read_g96(unt,molec)
            case("xyz")
             call read_xyz(unt,molec)
            case("log")
             call parse_summary(unt,molec,props,"struct_only")
             molec%atom(:)%resname = "UNK"
             molec%atom(:)%resseq = 1
            case("stdori")
             call get_first_std_geom(unt,molec)
             molec%atom(:)%resname = "UNK"
             molec%atom(:)%resseq = 1
            case("inpori")
             call get_first_inp_geom(unt,molec)
             molec%atom(:)%resname = "UNK"
             molec%atom(:)%resseq = 1
            case("fchk")
             call read_fchk_geom(unt,molec)
             molec%atom(:)%resname = "UNK"
             molec%atom(:)%resseq = 1
            case("UnSym")
             call read_molcas_geom(unt,molec)
            case default
             call alert_msg("fatal","File type not supported: "//filetype)
        end select

        call atname2element(molec)

        return

    end subroutine generic_strfile_read


end program get_centers_mg

